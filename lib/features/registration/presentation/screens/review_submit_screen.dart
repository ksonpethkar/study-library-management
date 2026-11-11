import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/registration_provider.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';

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

  Future<bool> _promptSignInDialog() async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_person_rounded, color: Colors.brown),
            SizedBox(width: 10),
            Text('Sign In Required'),
          ],
        ),
        content: const Text(
          'Please sign in with Google to securely submit your admission application. '
          'This connects your application to your account so you can track admission approval, view receipts, and access your digital ID card.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                final authRepo = ref.read(authRepositoryProvider);
                await authRepo.signInWithGoogle();
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  AppErrorFormatter.showErrorSnackBar(ctx, e, actionContext: 'auth');
                }
              }
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign In with Google'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _showRulesDialog(BuildContext context, String libraryId, String libraryName) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('libraries').doc(libraryId).get(),
        builder: (context, snapshot) {
          String rules =
              '1. Maintain complete silence in all study areas and reading halls.\n\n'
              '2. Mobile phones must be kept on silent/vibrate mode at all times.\n\n'
              '3. Seat allocation is strictly individual and non-transferable.\n\n'
              '4. Outside food and beverages (except water) are prohibited inside study rooms.\n\n'
              '5. Keep study cabins clean, tidy, and avoid damaging library property.\n\n'
              '6. Carry your digital student ID card or attendance QR at all times.';

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() ?? {};
            final customRules = (data['rulesText'] as String?) ?? (data['rules'] as String?);
            if (customRules != null && customRules.trim().isNotEmpty) {
              rules = customRules.trim();
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Colors.brown),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$libraryName Rules',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Text(
                  rules,
                  style: const TextStyle(height: 1.5, fontSize: 14),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _agreedToRules = true);
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('I Read & Agree to Rules'),
              ),
            ],
          );
        },
      ),
    );
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

    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      final signedIn = await _promptSignInDialog();
      if (!signedIn) return;
      currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
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
      String photoUrl = (regData['photoDataUrl'] as String?) ??
          (regData['photoUrl'] as String?) ?? '';

      final photoPath = regData['photoPath'] as String?;
      if (photoUrl.isEmpty && photoPath != null && photoPath.isNotEmpty) {
        if (photoPath.startsWith('data:image') || photoPath.startsWith('http')) {
          photoUrl = photoPath;
        } else if (!kIsWeb) {
          try {
            final photoFile = File(photoPath);
            if (photoFile.existsSync()) {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              try {
                photoUrl = await ImageService.uploadToStorage(
                  file: photoFile,
                  path: 'libraries/$libraryId/requests/photos/req_$timestamp.jpg',
                );
              } catch (e) {
                if (kDebugMode) debugPrint('Error uploading request photo: $e');
              }
            }
          } catch (_) { /* intentionally silent */ }
        }
      }

      String govIdImageUrl = (regData['govIdImageUrl'] ?? regData['govIdDataUrl'] ?? regData['govIdFrontUrl'] ?? '') as String;
      final govIdPath = regData['govIdImagePath'] as String?;
      if (govIdImageUrl.isEmpty && govIdPath != null && govIdPath.isNotEmpty) {
        if (govIdPath.startsWith('data:image') || govIdPath.startsWith('http')) {
          govIdImageUrl = govIdPath;
        } else if (!kIsWeb) {
          try {
            final govIdFile = File(govIdPath);
            if (govIdFile.existsSync()) {
              final b = await govIdFile.readAsBytes();
              govIdImageUrl = 'data:image/jpeg;base64,${base64Encode(b)}';
            }
          } catch (_) { /* intentionally silent */ }
        }
      }

      String govIdBackImageUrl = (regData['govIdBackImageUrl'] ?? regData['govIdBackDataUrl'] ?? regData['govIdBackUrl'] ?? '') as String;
      final govIdBackPath = regData['govIdBackImagePath'] as String?;
      if (govIdBackImageUrl.isEmpty && govIdBackPath != null && govIdBackPath.isNotEmpty) {
        if (govIdBackPath.startsWith('data:image') || govIdBackPath.startsWith('http')) {
          govIdBackImageUrl = govIdBackPath;
        } else if (!kIsWeb) {
          try {
            final govIdBackFile = File(govIdBackPath);
            if (govIdBackFile.existsSync()) {
              final b = await govIdBackFile.readAsBytes();
              govIdBackImageUrl = 'data:image/jpeg;base64,${base64Encode(b)}';
            }
          } catch (_) { /* intentionally silent */ }
        }
      }

      setState(() => _statusMessage = 'Validating request status...');

      // S4 FIX: Rate limiting & duplicate prevention
      // 1. Check if user is already an active student
      QuerySnapshot? existingStudent;
      try {
        existingStudent = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .where('userId', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
      } catch (e) {
        if (kDebugMode) debugPrint('Student duplicate pre-check skipped: $e');
      }
      if (existingStudent != null && existingStudent.docs.isNotEmpty) {
        throw Exception('You are already registered as a student in this library! Please return to student home.');
      }

      // 2. Check if user already has a pending registration request
      QuerySnapshot? existingPending;
      try {
        existingPending = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('requests')
            .where('studentId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
      } catch (e) {
        if (kDebugMode) debugPrint('Pending request pre-check skipped: $e');
      }
      if (existingPending != null && existingPending.docs.isNotEmpty) {
        throw Exception('You already have a pending registration request for this library. Please wait for admin approval.');
      }

      // 3. Check if phone number is already registered to an active student (L6 Fix)
      if (studentPhone.isNotEmpty) {
        QuerySnapshot? existingPhone;
        try {
          existingPhone = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .where('phone', isEqualTo: studentPhone)
              .limit(1)
              .get();
        } catch (e) {
          if (kDebugMode) debugPrint('Phone duplicate pre-check skipped: $e');
        }
        if (existingPhone != null && existingPhone.docs.isNotEmpty) {
          throw Exception('A student with mobile number $studentPhone is already registered in this library. If this is you, please log in.');
        }
      }

      setState(() => _statusMessage = 'Sending registration request to admin...');

      final selectedPlanId = ref.read(selectedPlanProvider);
      final plans = ref.read(plansStreamProvider).value ?? [];
      final resolvedPlanName = plans.where((p) => p.id == selectedPlanId).firstOrNull?.name ?? 'Monthly Full-Day';
      final seatDetails = ref.read(selectedSeatDetailsProvider);

      // Create request doc in Firestore
      final requestRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc();

      final allPlans = ref.read(plansStreamProvider).value ?? [];
      final selectedPlan = allPlans.where((p) => p.id == selectedPlanId).firstOrNull;
      final smartCalc = selectedPlan != null
          ? PlanCalculatorService.calculateSmartPlan(plan: selectedPlan)
          : null;

      final studentData = {
        'name': regData['name'] ?? '',
        'fatherName': regData['fatherName'] ?? '',
        'phone': regData['phone'] ?? '',
        'email': (regData['email'] != null && regData['email'].toString().isNotEmpty)
            ? regData['email']
            : (currentUser.email ?? ''),
        'gender': regData['gender'] ?? 'male',
        'address': regData['address'] ?? '',
        'pincode': regData['pincode'] ?? regData['pinCode'] ?? '',
        'govIdType': regData['govIdType'] ?? 'aadhaar',
        'govIdNumber': regData['govIdNumber'] ?? '',
        'college': regData['college'] ?? '',
        'course': regData['course'] ?? '',
        'year': regData['year'] ?? '',
        'emergencyContact': regData['emergencyContact'] ?? '',
        'bloodGroup': regData['bloodGroup'] ?? '',
        'rollNumber': regData['rollNumber'] ?? '',
        'prep': regData['prep'] ?? '',
        'dob': _parseDobToIso(regData['dob'] as String?),
        'photoUrl': photoUrl,
        'govIdImageUrl': govIdImageUrl,
        if (govIdBackImageUrl.isNotEmpty) 'govIdBackImageUrl': govIdBackImageUrl,
        'customFields': regData['customFields'] ?? {},
        'planId': selectedPlanId,
        'planName': resolvedPlanName,
        'proratedFee': smartCalc?.proratedPrice,
        'planPrice': selectedPlan?.price,
        'daysRemaining': smartCalc?.daysRemaining,
        'cycleStartDate': smartCalc?.startDate.toIso8601String(),
        'cycleEndDate': smartCalc?.endDate.toIso8601String(),
        'isProrated': smartCalc?.isProrated ?? false,
        'paymentMode': 'desk_collection',
        'userId': currentUser.uid,
        'requestedSeatId': seatDetails.isAutoAssign ? null : seatDetails.seatId,
        'requestedSeatLabel': seatDetails.isAutoAssign ? 'Auto-Assign' : seatDetails.seatLabel,
        'requestedSectionId': seatDetails.sectionId,
        'requestedSectionName': seatDetails.sectionName,
        'seatId': seatDetails.isAutoAssign ? null : seatDetails.seatId,
        'sectionId': seatDetails.sectionId,
      };

      await requestRef.set({
        'id': requestRef.id,
        'type': 'registration',
        'status': 'pending',
        'studentName': regData['name'] ?? currentUser.displayName ?? 'New Student',
        'studentPhone': regData['phone'] ?? '',
        'studentId': currentUser.uid,
        'studentData': studentData,
        'planId': selectedPlanId,
        'planName': resolvedPlanName,
        'proratedFee': smartCalc?.proratedPrice,
        'planPrice': selectedPlan?.price,
        'daysRemaining': smartCalc?.daysRemaining,
        'cycleStartDate': smartCalc?.startDate.toIso8601String(),
        'cycleEndDate': smartCalc?.endDate.toIso8601String(),
        'isProrated': smartCalc?.isProrated ?? false,
        'paymentMode': 'desk_collection',
        'requestedSeatId': seatDetails.isAutoAssign ? null : seatDetails.seatId,
        'requestedSeatLabel': seatDetails.isAutoAssign ? 'Auto-Assign' : seatDetails.seatLabel,
        'requestedSectionId': seatDetails.sectionId,
        'requestedSectionName': seatDetails.sectionName,
        'seatId': seatDetails.isAutoAssign ? null : seatDetails.seatId,
        'sectionId': seatDetails.sectionId,
        'message': 'New student registration request submitted via app',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Place 60-min soft-lock on the desk so other applicants or walk-ins cannot claim it while under review
      if (seatDetails.hasSelection && !seatDetails.isAutoAssign && (seatDetails.seatId?.isNotEmpty == true) && (seatDetails.sectionId?.isNotEmpty == true)) {
        try {
          await ref.read(seatRepositoryProvider).softLockSeat(
            libraryId: libraryId,
            sectionId: seatDetails.sectionId!,
            seatId: seatDetails.seatId!,
            candidateId: currentUser.uid,
            candidateName: regData['name'] ?? 'Applicant',
            duration: const Duration(minutes: 60),
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Seat soft-lock error (proceeding anyway): $e');
        }
      }

      // Notify admin via unified notification service & queue
      try {
        final sName = (regData['name'] as String?)?.trim() ?? 'A student';
        final seatSnippet = seatDetails.hasSelection
            ? (seatDetails.isAutoAssign ? ' (Auto-Assign Desk)' : ' (Desk #${seatDetails.seatLabel})')
            : '';
        await AppNotificationService.sendNotification(
          libraryId: libraryId,
          title: '📋 New Registration Request',
          body: '$sName submitted an admission application$seatSnippet. Please review and approve.',
          type: 'admission',
          targetRole: 'admin',
          actionRoute: Routes.adminRequests,
          metadata: {
            'requestId': requestRef.id,
            'studentName': sName,
            'studentPhone': regData['phone'] ?? '',
            'planId': selectedPlanId,
            'requestedSeatLabel': seatDetails.isAutoAssign ? 'Auto-Assign' : seatDetails.seatLabel,
          },
        );
        // Also persist to admin_notifications queue for backward compatibility
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('admin_notifications')
            .add({
          'type': 'new_registration',
          'title': '📋 New Registration Request',
          'body': '$sName submitted an admission application$seatSnippet. Please review and approve.',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'requestId': requestRef.id,
        });
      } catch (_) { /* intentionally silent */ }

      // Clear registration state
      ref.read(registrationNotifierProvider.notifier).clear();
      ref.read(ocrResultProvider.notifier).clear();
      ref.read(selectedPlanProvider.notifier).clear();
      ref.read(selectedSeatDetailsProvider.notifier).clear();
      ref.read(selectedSeatProvider.notifier).clear();

      // P8: Track registration submitted in Analytics
      if (!kIsWeb) {
        FirebaseAnalytics.instance.logEvent(name: 'registration_submitted').ignore();
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
          _requestId = requestRef.id;
        });
      }
    } catch (e, stack) {
      // S9: Report registration failures to Crashlytics
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'registration_submit_failed', fatal: false);
      }
      _submitAttempts++;
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      
      String message = e.toString().replaceFirst('Exception: ', '');
      if (e.toString().contains('network') || e.toString().contains('unavailable') || 
          e.toString().contains('UNAVAILABLE')) {
        message = 'No internet connection. Please check your network and retry.';
      } else if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        if (FirebaseAuth.instance.currentUser == null) {
          message = 'Session expired. Please sign in with Google to continue.';
        } else {
          message = 'Permission error while submitting request. Please try again or contact library admin.';
        }
      } else if (_submitAttempts >= _maxAttempts) {
        message = 'Submission failed after $_maxAttempts attempts. Please contact library admin.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _handleSubmit,
          ),
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

    final plansAsync = ref.watch(plansStreamProvider);
    final selectedPlan = plansAsync.value?.where((p) => p.id == selectedPlanId).firstOrNull;

    if (_submitted) {
      return Scaffold(
        body: SafeArea(
          child: _SubmissionSuccessView(
            requestId: _requestId,
            onDone: () => context.go(Routes.login),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width < 380 ? 14.0 : 20.0,
                      vertical: 20.0,
                    ),
                    children: [
                      // Photo & Name Banner
                      Center(
                        child: Column(
                          children: [
                            Builder(
                              builder: (ctx) {
                                final photoUrlOrData = (regData['photoDataUrl'] as String?) ??
                                    (regData['photoUrl'] as String?) ??
                                    (regData['photoPath'] as String?);
                                final imgProvider = ImageService.getImageProvider(photoUrlOrData);
                                return CircleAvatar(
                                  radius: 46,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  backgroundImage: imgProvider,
                                  child: imgProvider == null
                                      ? const Icon(Icons.person_rounded, size: 46)
                                      : null,
                                );
                              },
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
                              if (regData['dob'] != null && regData['dob'].toString().trim().isNotEmpty)
                                _buildSummaryRow('Date of Birth', regData['dob'].toString()),
                              if (regData['gender'] != null && regData['gender'].toString().trim().isNotEmpty)
                                _buildSummaryRow('Gender', regData['gender'].toString().toUpperCase()),
                              if (regData['bloodGroup'] != null && regData['bloodGroup'].toString().trim().isNotEmpty)
                                _buildSummaryRow('Blood Group', regData['bloodGroup'].toString()),
                              if (regData['email'] != null && regData['email'].isNotEmpty)
                                _buildSummaryRow('Email', regData['email']),
                              if (regData['emergencyContact'] != null && regData['emergencyContact'].toString().trim().isNotEmpty)
                                _buildSummaryRow('Emergency Contact', regData['emergencyContact'].toString()),
                              if (regData['govIdNumber'] != null && regData['govIdNumber'].isNotEmpty)
                                _buildSummaryRow('Government ID', '${(regData['govIdType'] ?? 'ID').toString().toUpperCase()} - ${regData['govIdNumber']}'),
                              if (regData['address'] != null && regData['address'].isNotEmpty)
                                _buildSummaryRow('Address', regData['address']),
                              if (regData['pincode'] != null && regData['pincode'].toString().trim().isNotEmpty)
                                _buildSummaryRow('PIN Code', regData['pincode'].toString()),
                              if (regData['prep'] != null && regData['prep'].toString().trim().isNotEmpty)
                                _buildSummaryRow('Target Goal / Exam', regData['prep'].toString()),
                              if (regData['college'] != null && regData['college'].isNotEmpty)
                                _buildSummaryRow('College', regData['college']),
                              if (regData['course'] != null && regData['course'].isNotEmpty)
                                _buildSummaryRow('Course', regData['course']),
                              if (regData['year'] != null && regData['year'].toString().trim().isNotEmpty)
                                _buildSummaryRow('Study Year / Semester', regData['year'].toString()),
                              if (regData['rollNumber'] != null && regData['rollNumber'].toString().trim().isNotEmpty)
                                _buildSummaryRow('Roll Number', regData['rollNumber'].toString()),
                              Builder(
                                builder: (ctx) {
                                  final custom = regData['customFields'] as Map?;
                                  if (custom == null || custom.isEmpty) return const SizedBox.shrink();
                                  final formConfigAsync = ref.watch(formConfigStreamProvider);
                                  final fieldsList = formConfigAsync.value ?? [];
                                  final nonEmpties = custom.entries.where(
                                    (e) => e.value != null && e.value.toString().trim().isNotEmpty,
                                  ).toList();
                                  if (nonEmpties.isEmpty) return const SizedBox.shrink();

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      const Divider(height: 16),
                                      Text(
                                        'Additional Information',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...nonEmpties.map((e) {
                                        final label = FormConfigService.getFieldLabel(
                                          fieldsList,
                                          e.key.toString(),
                                          e.key.toString(),
                                        );
                                        return _buildSummaryRow(label, e.value.toString());
                                      }),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected Plan Card
                      Builder(
                        builder: (context) {
                          final allPlans = plansAsync.value ?? [];
                          final baseMonthly = PlanCalculatorService.getBaseMonthlyPrice(allPlans);
                          final origPrice = selectedPlan?.getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthly);
                          final discPercent = selectedPlan?.getDiscountPercent(baseMonthlyPrice: baseMonthly);
                          final saved = selectedPlan?.getSavingsAmount(baseMonthlyPrice: baseMonthly);
                          final hasDiscount = origPrice != null && selectedPlan != null && origPrice > selectedPlan.price;
                          final dailyRate = selectedPlan != null ? PlanCalculatorService.getDailyRate(selectedPlan) : 0.0;
                          final smartCalc = selectedPlan != null ? PlanCalculatorService.calculateSmartPlan(plan: selectedPlan) : null;
                          final now = DateTime.now();

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.workspace_premium_rounded, color: theme.colorScheme.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Selected Membership Plan',
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  if (selectedPlan != null) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                selectedPlan.displayName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${selectedPlan.duration} ${selectedPlan.durationUnit.name}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                              if (selectedPlan.isFeatured)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade600,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'POPULAR',
                                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (smartCalc != null && smartCalc.isProrated) ...[
                                              Text(
                                                'Full Plan: ₹${selectedPlan.price.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  decoration: TextDecoration.lineThrough,
                                                  decorationColor: Colors.grey.shade500,
                                                  color: Colors.grey.shade500,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  fontFeatures: const [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                              Text(
                                                smartCalc.formattedProratedPrice,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 22,
                                                  color: theme.colorScheme.primary,
                                                  fontFeatures: const [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ] else ...[
                                              if (hasDiscount)
                                                Text(
                                                  '₹${origPrice.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    decoration: TextDecoration.lineThrough,
                                                    decorationColor: Colors.grey.shade500,
                                                    color: Colors.grey.shade500,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    fontFeatures: const [FontFeature.tabularFigures()],
                                                  ),
                                                ),
                                              Text(
                                                '₹${selectedPlan.price.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 22,
                                                  color: hasDiscount ? Colors.green.shade800 : theme.colorScheme.primary,
                                                  fontFeatures: const [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ],
                                            Container(
                                              margin: const EdgeInsets.only(top: 3),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.brown.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.brown.shade200, width: 0.8),
                                              ),
                                              child: Text(
                                                'Pay at Desk',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.brown.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (selectedPlan.description.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        selectedPlan.description.trim(),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        if (hasDiscount)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.green.shade300, width: 0.8),
                                            ),
                                            child: Text(
                                              '🎉 ${discPercent ?? 0}% OFF • You save ₹${saved?.toStringAsFixed(0) ?? '0'}',
                                              style: TextStyle(
                                                color: Colors.green.shade800,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                fontFeatures: const [FontFeature.tabularFigures()],
                                              ),
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.7),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.grey.shade300, width: 0.8),
                                          ),
                                          child: Text(
                                            '⚡ Effective Rate: ₹${dailyRate.toStringAsFixed(1)} / day',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade800,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ),
                                        if (selectedPlan.gracePeriodDays > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.blue.shade200, width: 0.8),
                                            ),
                                            child: Text(
                                              '+${selectedPlan.gracePeriodDays}d Grace Period',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (smartCalc != null && smartCalc.isProrated) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.amber.shade300, width: 0.8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_month_rounded, size: 16, color: Colors.amber.shade900),
                                                const SizedBox(width: 6),
                                                Text(
                                                   'Active Cycle: Today (${DateFormat('dd MMM').format(now)}) → ${DateFormat('dd MMM').format(smartCalc.endDate)}',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '• ${smartCalc.daysRemaining} days remaining in ${smartCalc.cycleLabel}.\n'
                                              '• Amount Due at Reception Desk: ${smartCalc.formattedProratedPrice} (Cash / UPI on physical arrival).',
                                              style: TextStyle(fontSize: 11.5, height: 1.4, color: Colors.brown.shade800),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ] else ...[
                                    const Text('No plan selected. Administrator will assign one on approval.'),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Selected Study Desk Card
                      Builder(
                        builder: (ctx) {
                          final seatDetails = ref.watch(selectedSeatDetailsProvider);
                          final hasSeat = seatDetails.hasSelection;
                          final isAuto = seatDetails.isAutoAssign;
                          final isDark = theme.brightness == Brightness.dark;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: hasSeat
                                    ? (isAuto ? Colors.amber.shade300 : const Color(0xFFC4B5FD))
                                    : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                              ),
                            ),
                            color: hasSeat
                                ? (isAuto
                                    ? (isDark ? const Color(0xFF261904) : Colors.amber.shade50.withValues(alpha: 0.5))
                                    : (isDark ? const Color(0xFF1E172E) : const Color(0xFFF5F3FF)))
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isAuto ? Colors.amber.shade100 : const Color(0xFFEDE9FE),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isAuto ? Icons.bolt_rounded : Icons.event_seat_rounded,
                                          size: 20,
                                          color: isAuto ? const Color(0xFFB45309) : const Color(0xFF6D28D9),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Selected Study Desk',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            Text(
                                              isAuto ? 'Auto-assign by library management' : 'Dedicated desk preference',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => ref.read(registrationStepProvider.notifier).goTo(5),
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        label: const Text('Change'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (isAuto) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF3B2308) : Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.amber.shade300, width: 0.8),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFD97706)),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '⚡ Auto-Assign: Any best available desk will be allocated by library staff upon admission approval.',
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (hasSeat) ...[
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Desk #${seatDetails.seatLabel}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            seatDetails.sectionName ?? 'Cozy Hall',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    const Text('No desk selected. Auto-assign will be used.'),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Rules Agreement Card with Clickable Dialog
                      Builder(
                        builder: (ctx) {
                          final lib = ref.watch(currentLibraryProvider).value;
                          final libName = lib?.name.isNotEmpty == true ? lib!.name : 'Study Library';
                          final libId = ref.watch(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _agreedToRules
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CheckboxListTile(
                                  value: _agreedToRules,
                                  onChanged: (val) => setState(() => _agreedToRules = val ?? false),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  title: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'I agree to all $libName rules and regulations',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _showRulesDialog(context, libId, libName),
                                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                        label: const Text('View Rules', style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(40, 0, 8, 8),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 2,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'By submitting, you also agree to our',
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      InkWell(
                                        onTap: () => context.push(Routes.terms, extra: libId),
                                        child: Text(
                                          'Terms of Service',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      Text('&', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                                      InkWell(
                                        onTap: () => context.push(Routes.privacyPolicy, extra: libId),
                                        child: Text(
                                          'Privacy Policy',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Navigation Buttons (Responsive layout)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isSmallPhone = constraints.maxWidth < 360 ||
                              MediaQuery.of(context).size.width < 380;
                          if (isSmallPhone) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.icon(
                                  onPressed: (_agreedToRules && !_isSubmitting) ? _handleSubmit : null,
                                  icon: const Icon(Icons.send_rounded),
                                  label: const Text('Submit Application'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton(
                                  onPressed: () => ref.read(registrationStepProvider.notifier).goTo(5),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Back'),
                                ),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton(
                                onPressed: () => ref.read(registrationStepProvider.notifier).goTo(5),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                                child: const Text('Back'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: (_agreedToRules && !_isSubmitting) ? _handleSubmit : null,
                                  icon: const Icon(Icons.send_rounded),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Submit Application'),
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 320;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ),
              Expanded(
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CELEBRATION & SUBMISSION SUCCESS VIEW (SPRING BOUNCE + CONFETTI CANNON)
// ─────────────────────────────────────────────────────────────────────────────

class _SubmissionSuccessView extends StatefulWidget {
  final String? requestId;
  final VoidCallback onDone;

  const _SubmissionSuccessView({
    required this.requestId,
    required this.onDone,
  });

  @override
  State<_SubmissionSuccessView> createState() => _SubmissionSuccessViewState();
}

class _SubmissionSuccessViewState extends State<_SubmissionSuccessView>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _badgeController;
  late final AnimationController _pulseController;
  late final AnimationController _contentController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _ringScaleAnimation;
  late final Animation<double> _ringOpacityAnimation;
  late final Animation<double> _pulseAnimation;

  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();

    // 1. Badge Spring Bounce (0 -> 1 with elastic bounce)
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticOut,
    );

    // Radiating ring wave
    _ringScaleAnimation = Tween<double>(begin: 0.8, end: 1.6).animate(
      CurvedAnimation(
        parent: _badgeController,
        curve: const Interval(0.18, 0.9, curve: Curves.easeOutQuad),
      ),
    );
    _ringOpacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(
        parent: _badgeController,
        curve: const Interval(0.18, 0.9, curve: Curves.easeOutQuad),
      ),
    );

    // 2. Confetti Particle System (2.6 seconds burst)
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    final rng = math.Random();
    const colors = [
      Color(0xFFF59E0B), // Warm Amber / Gold
      Color(0xFF10B981), // Emerald Green
      Color(0xFF0D9488), // Teal
      Color(0xFFF43F5E), // Rose Coral
      Color(0xFF8B5CF6), // Royal Purple
      Color(0xFF3B82F6), // Sky Blue
    ];

    _particles = List.generate(55, (i) {
      // Shoot predominantly upwards and outwards (-160 to -20 degrees)
      final angle = (-math.pi * 0.9) + rng.nextDouble() * (math.pi * 0.8);
      final speed = 240.0 + rng.nextDouble() * 420.0;
      return _ConfettiParticle(
        color: colors[rng.nextInt(colors.length)],
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: 6.0 + rng.nextDouble() * 6.0,
        rotation: rng.nextDouble() * math.pi * 2,
        rotationSpeed: (rng.nextDouble() - 0.5) * 12.0,
        isCircle: rng.nextBool(),
      );
    });

    // 3. Staggered Content Fade & Slide
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 4. Subtle Breathing Pulse for "Under Review" Badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Launch animations
    _badgeController.forward();
    _confettiController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _confettiController.dispose();
    _pulseController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Widget _buildStaggeredItem({
    required double startInterval,
    required double endInterval,
    required Widget child,
  }) {
    final fade = CurvedAnimation(
      parent: _contentController,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
    ));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Confetti Canvas Layer (in front of background, behind modal content if pressed)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConfettiPainter(
                    progress: _confettiController.value,
                    particles: _particles,
                  ),
                );
              },
            ),
          ),
        ),

        // Main Celebratory Content
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Badge with Radiating Ripple Wave
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radiating Pulse Ring
                      AnimatedBuilder(
                        animation: _badgeController,
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _ringScaleAnimation.value,
                            child: Opacity(
                              opacity: _ringOpacityAnimation.value,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF10B981),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Elastic Bouncing Icon
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.38),
                                blurRadius: 24,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. Headline
                _buildStaggeredItem(
                  startInterval: 0.0,
                  endInterval: 0.45,
                  child: Column(
                    children: [
                      Text(
                        'Application Submitted! 🎉',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Welcome to the Cozy Corner family!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 2. Pulsing Status Badge
                _buildStaggeredItem(
                  startInterval: 0.2,
                  endInterval: 0.65,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.hourglass_top_rounded,
                            color: Color(0xFFD97706),
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status: Under Review',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // 3. Information Card
                _buildStaggeredItem(
                  startInterval: 0.4,
                  endInterval: 0.85,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your registration application has been submitted successfully.\n\n'
                          'The library administrator will review your details and confirm your membership. '
                          'You will receive a notification once approved.\n\n'
                          'This usually takes less than 24 hours. 😊',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                        if (widget.requestId != null && widget.requestId!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tag_rounded, size: 14, color: theme.colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(
                                  'Application ID: ${widget.requestId!.length >= 8 ? widget.requestId!.substring(0, 8).toUpperCase() : widget.requestId!.toUpperCase()}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 4. Primary Done Action Button
                _buildStaggeredItem(
                  startInterval: 0.6,
                  endInterval: 1.0,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onDone,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        'Done — Return to Home',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiParticle {
  final Color color;
  final double vx;
  final double vy;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final bool isCircle;

  const _ConfettiParticle({
    required this.color,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    final centerX = size.width / 2;
    // Launch origin from behind the bouncing badge
    final startY = size.height * 0.32;
    final t = progress * 2.6; // elapsed seconds

    final opacity = (1.0 - math.pow(progress, 3)).clamp(0.0, 1.0).toDouble();
    final gravity = 480.0; // px/s^2

    for (final p in particles) {
      final x = centerX + p.vx * t;
      final y = startY + p.vy * t + 0.5 * gravity * t * t;

      // Skip offscreen particles
      if (y > size.height + 20 || x < -20 || x > size.width + 20) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotationSpeed * t);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size * 1.6, height: p.size * 0.9),
            const Radius.circular(2),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
