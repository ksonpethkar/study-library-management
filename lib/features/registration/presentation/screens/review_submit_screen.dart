import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../providers/registration_provider.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/core/router/app_router.dart';

class ReviewSubmitScreen extends ConsumerStatefulWidget {
  const ReviewSubmitScreen({super.key});

  @override
  ConsumerState<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends ConsumerState<ReviewSubmitScreen> {
  bool _agreedToRules = false;
  bool _isSubmitting = false;
  String _statusMessage = 'Submitting request...';
  bool _submitted = false;
  String? _requestId;
  
  int _submitAttempts = 0;
  static const _maxAttempts = 3;

  /// Converts DD/MM/YYYY display format (used by date picker) to ISO 8601 string.
  /// StudentModel._parseDate() uses DateTime.tryParse which requires ISO 8601.
  static String? _parseDobToIso(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    // Already ISO format
    if (DateTime.tryParse(dob) != null) return dob;
    // DD/MM/YYYY format
    final parts = dob.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day).toIso8601String();
      }
    }
    return dob; // return as-is if cannot parse
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    if (!_agreedToRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please read and agree to the library rules before submitting.')),
      );
      return;
    }

    final regData = ref.read(registrationNotifierProvider);
    final studentName = (regData['name'] as String?)?.trim() ?? '';
    final studentPhone = (regData['phone'] as String?)?.trim() ?? '';

    if (studentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student name is required. Please go back to fill in your personal details.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (studentPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number is required. Please go back to fill in your personal details.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    var libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) {
      libraryId = CurrentLibraryNotifier.defaultLibraryId;
      ref.read(currentLibraryIdProvider.notifier).set(libraryId);
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Uploading profile photo...';
    });

    try {
      final regData = ref.read(registrationNotifierProvider);
      final photoPath = regData['photoPath'] as String?;
      String photoUrl = '';

      if (photoPath != null && photoPath.isNotEmpty) {
        final photoFile = File(photoPath);
        if (photoFile.existsSync()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          try {
            photoUrl = await ImageService.uploadToStorage(
              file: photoFile,
              path: 'libraries/$libraryId/requests/photos/req_$timestamp.jpg',
            );
          } catch (e) {
            debugPrint('Error uploading request photo: $e');
          }
        }
      }

      setState(() => _statusMessage = 'Sending registration request to admin...');

      final currentUser = FirebaseAuth.instance.currentUser;
      final selectedPlanId = ref.read(selectedPlanProvider);

      // Create request doc in Firestore
      final requestRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc();

      final studentData = {
        'name': regData['name'] ?? '',
        'fatherName': regData['fatherName'] ?? '',
        'phone': regData['phone'] ?? '',
        'email': regData['email'] ?? '',
        'gender': regData['gender'] ?? 'male',
        'address': regData['address'] ?? '',
        'pincode': regData['pincode'] ?? '',           // fixed: was missing
        'govIdType': regData['govIdType'] ?? 'aadhaar',
        'govIdNumber': regData['govIdNumber'] ?? '',
        'college': regData['college'] ?? '',
        'course': regData['course'] ?? '',
        'year': regData['year'] ?? '',                // fixed: was missing
        'emergencyContact': regData['emergencyContact'] ?? '', // fixed: was missing
        'bloodGroup': regData['bloodGroup'] ?? '',    // fixed: was missing
        'rollNumber': regData['rollNumber'] ?? '',    // fixed: was missing
        // dob: stored as ISO string so _parseDate can parse it correctly
        'dob': _parseDobToIso(regData['dob'] as String?),
        'photoUrl': photoUrl,
        'planId': selectedPlanId,
        'userId': currentUser?.uid,
      };

      await requestRef.set({
        'id': requestRef.id,
        'type': 'registration',
        'status': 'pending',
        'studentName': regData['name'] ?? 'New Student',
        'studentPhone': regData['phone'] ?? '',
        'studentId': currentUser?.uid ?? '',
        'studentData': studentData,
        'planId': selectedPlanId,
        'message': 'New student registration request submitted via app',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify admin via Firestore notification queue (triggers push on their device)
      try {
        final sName = (regData['name'] as String?)?.trim() ?? 'A student';
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('admin_notifications')
            .add({
          'type': 'new_registration',
          'title': '📋 New Registration Request',
          'body': '$sName submitted a registration application. Please review and approve.',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'requestId': requestRef.id,
        });
      } catch (_) {}

      // Clear registration state
      ref.read(registrationNotifierProvider.notifier).clear();
      ref.read(ocrResultProvider.notifier).clear();
      ref.read(selectedPlanProvider.notifier).clear();

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
          _requestId = requestRef.id;
        });
      }
    } catch (e) {
      _submitAttempts++;
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      
      String message = 'Submission failed. Please try again.';
      if (e.toString().contains('network') || e.toString().contains('unavailable') || 
          e.toString().contains('UNAVAILABLE')) {
        message = 'No internet connection. Please check your network and retry.';
      } else if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        message = 'Permission denied. Please sign in again.';
      } else if (_submitAttempts >= _maxAttempts) {
        message = 'Submission failed after $_maxAttempts attempts. Please contact the library admin.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          backgroundColor: Colors.red.shade700,
          action: _submitAttempts < _maxAttempts
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: _handleSubmit,
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regData = ref.watch(registrationNotifierProvider);
    final selectedPlanId = ref.watch(selectedPlanProvider);
    final photoPath = regData['photoPath'] as String?;
    final photoFile = (photoPath != null && photoPath.isNotEmpty) ? File(photoPath) : null;

    final plansAsync = ref.watch(plansStreamProvider);
    final selectedPlan = plansAsync.value?.where((p) => p.id == selectedPlanId).firstOrNull;

    if (_submitted) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.pending_actions_rounded, size: 56,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Application Submitted! 🎉',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            color: Colors.amber.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Status: Under Review',
                            style: TextStyle(
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your registration application has been submitted successfully.\n\nThe library administrator will review your details and confirm your membership. You will receive a notification once approved.\n\nThis usually takes less than 24 hours. 😊',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.6),
                  ),
                  if (_requestId != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reference: ${_requestId!.length >= 8 ? _requestId!.substring(0, 8).toUpperCase() : _requestId!.toUpperCase()}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.go(Routes.login),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Done — I will wait for confirmation'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }


    return Scaffold(
      appBar: AppBar(title: const Text('Review & Submit')),
      body: Column(
        children: [
          const LinearProgressIndicator(value: 5 / 5),
          Expanded(
            child: _isSubmitting
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20.0),
                    children: [
                      // Photo & Name Banner
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (photoFile != null && photoFile.existsSync()) {
                                  ImageService.showImageViewer(
                                    context,
                                    imageFile: photoFile,
                                    title: regData['name'] ?? 'Profile Photo',
                                  );
                                }
                              },
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 46,
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                    backgroundImage:
                                        (photoFile != null && photoFile.existsSync()) ? FileImage(photoFile) : null,
                                    child: (photoFile == null || !photoFile.existsSync())
                                        ? const Icon(Icons.person_rounded, size: 46)
                                        : null,
                                  ),
                                  if (photoFile != null && photoFile.existsSync())
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: theme.colorScheme.primary,
                                        child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              regData['name'] ?? 'Student Name',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              regData['phone'] ?? '',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Personal Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Personal & Academic Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const Divider(height: 20),
                              if (regData['fatherName'] != null && regData['fatherName'].isNotEmpty)
                                _buildSummaryRow('Father / Guardian', regData['fatherName']),
                              if (regData['gender'] != null)
                                _buildSummaryRow('Gender', regData['gender'].toString().toUpperCase()),
                              if (regData['email'] != null && regData['email'].isNotEmpty)
                                _buildSummaryRow('Email', regData['email']),
                              if (regData['govIdNumber'] != null && regData['govIdNumber'].isNotEmpty)
                                _buildSummaryRow('Government ID', '${(regData['govIdType'] ?? 'ID').toString().toUpperCase()} - ${regData['govIdNumber']}'),
                              if (regData['college'] != null && regData['college'].isNotEmpty)
                                _buildSummaryRow('College', regData['college']),
                              if (regData['course'] != null && regData['course'].isNotEmpty)
                                _buildSummaryRow('Course', regData['course']),
                              if (regData['address'] != null && regData['address'].isNotEmpty)
                                _buildSummaryRow('Address', regData['address']),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected Plan Card
                      Card(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Selected Membership Plan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const Divider(height: 20),
                              if (selectedPlan != null) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(selectedPlan.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('₹${selectedPlan.price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: theme.colorScheme.primary)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Duration: ${selectedPlan.duration} ${selectedPlan.durationUnit.name}', style: TextStyle(color: Colors.grey.shade700)),
                              ] else ...[
                                const Text('No plan selected. Administrator will assign one on approval.'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Rules Agreement Checkbox
                      CheckboxListTile(
                        value: _agreedToRules,
                        onChanged: (val) => setState(() => _agreedToRules = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'I have read and agree to all Cozy Corner Study Library rules and regulations.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Navigation Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton(
                            onPressed: () => ref.read(registrationStepProvider.notifier).goTo(4),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                            child: const Text('Back'),
                          ),
                          FilledButton.icon(
                            onPressed: (_agreedToRules && !_isSubmitting) ? _handleSubmit : null,
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Submit Application'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
