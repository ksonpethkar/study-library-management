import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/message_template_service.dart';
import 'package:intl/intl.dart';
import 'package:study_library/services/student_provisioning_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/error/error_handler.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _requestData;
  String? _newCreatedStudentId;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(widget.requestId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _requestData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveRequest() async {
    final String libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty || _requestData == null) return;

    setState(() => _isProcessing = true);

    try {
      final data = _requestData!;
      final type = data['type'] as String? ?? 'registration';
      DateTime? finalPlanStartDate;
      DateTime? finalPlanEndDate;
      String? renewalPlanId;

      if (type == 'registration' || type == 'newregistration') {
        _newCreatedStudentId = await StudentProvisioningService.approveAndProvisionRequest(
          libraryId: libraryId,
          requestId: widget.requestId,
          preloadedData: data,
        );
      } else if (type == 'seat_change' || type == 'seatchange') {
        _newCreatedStudentId = await StudentProvisioningService.approveAndProvisionRequest(
          libraryId: libraryId,
          requestId: widget.requestId,
          preloadedData: data,
        );
      } else if (type == 'profile_update') {
        final studentId = (data['studentId'] ?? '').toString();
        final proposedData = (data['proposedData'] as Map<String, dynamic>?) ?? {};
        if (studentId.isNotEmpty && proposedData.isNotEmpty) {
          final Map<String, dynamic> updateFields = {
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (proposedData.containsKey('emergencyContact')) {
            updateFields['emergencyContact'] = proposedData['emergencyContact'];
          }
          if (proposedData.containsKey('college')) {
            updateFields['college'] = proposedData['college'];
          }
          if (proposedData.containsKey('course')) {
            updateFields['course'] = proposedData['course'];
          }
          if (proposedData.containsKey('year')) {
            updateFields['year'] = proposedData['year'];
          }
          if (proposedData.containsKey('customFields') && proposedData['customFields'] is Map) {
            final customMap = Map<String, dynamic>.from(proposedData['customFields'] as Map);
            for (final entry in customMap.entries) {
              updateFields['customFields.${entry.key}'] = entry.value;
            }
          }
          await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(studentId)
              .update(updateFields);

          AuditLogger().log(
            action: AuditAction.updated,
            entityType: AuditEntity.student,
            libraryId: libraryId,
            entityId: studentId,
            details: {'action': 'profile_update_approved', ...proposedData},
          ).ignore();
        }
      } else if (type == 'renewal') {
        final studentId = (data['studentId'] ?? '').toString();
        final requestedPlanId = (data['requestedPlanId'] ?? '').toString();

        if (studentId.isNotEmpty && requestedPlanId.isNotEmpty) {
          final studentDoc = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(studentId)
              .get();

          if (studentDoc.exists) {
            final sData = studentDoc.data()!;
            final currentPlanEndDate = StudentModel.parseDateStatic(sData['planEndDate']);

            final plansAsync = ref.read(plansStreamProvider);
            final plans = plansAsync.value ?? [];
            final plan = plans.where((p) => p.id == requestedPlanId).firstOrNull;

            DateTime newStartDate;
            DateTime newEndDate;

            if (currentPlanEndDate != null && currentPlanEndDate.isAfter(DateTime.now())) {
              newStartDate = currentPlanEndDate;
            } else {
              newStartDate = DateTime.now();
            }

            if (plan != null) {
              if (plan.durationUnit.name == 'months') {
                newEndDate = DateTime(newStartDate.year, newStartDate.month + plan.duration, newStartDate.day);
              } else {
                newEndDate = newStartDate.add(Duration(days: plan.duration));
              }
            } else {
              newEndDate = newStartDate.add(const Duration(days: 30));
            }

            // Invariant: Do not prematurely activate or extend dates before payment!
            finalPlanStartDate = newStartDate;
            finalPlanEndDate = newEndDate;
            renewalPlanId = requestedPlanId;
          }
        }
      }

      // Mark request approved
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(widget.requestId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'createdStudentId': _newCreatedStudentId,
      });

      AuditLogger().log(
        action: AuditAction.approved,
        entityType: AuditEntity.request,
        libraryId: libraryId,
        entityId: widget.requestId,
        details: {'libraryId': libraryId},
      ).ignore();

      ref.invalidate(studentsStreamProvider);
      await _loadRequest();

      if (mounted) {
        final successMsg = type == 'profile_update'
            ? 'Profile update approved and applied successfully!'
            : (type == 'seat_change' || type == 'seatchange'
                ? 'Seat change approved and allocated successfully!'
                : (type == 'renewal'
                    ? 'Renewal approved! Please record payment to extend validity.'
                    : 'Request approved! Please record payment to activate pass.'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
        );
        final studentName = _requestData?['studentName'] ?? (_requestData?['studentData'] as Map<String, dynamic>?)?['name'] ?? 'Student';
        final studentPhone = ((_requestData?['studentData'] as Map<String, dynamic>?)?['phone'] ?? _requestData?['studentPhone'] ?? '').toString();
        final studentUserId = ((_requestData?['studentData'] as Map<String, dynamic>?)?['userId'] ?? _requestData?['studentId'] ?? '').toString();
        if (type == 'registration' && _newCreatedStudentId != null) {
          _promptPaymentAfterApproval(
            libraryId,
            _newCreatedStudentId!,
            studentUserId,
            studentName.toString(),
            studentPhone,
            planStartDate: finalPlanStartDate,
            planEndDate: finalPlanEndDate,
          );
        } else if (type == 'renewal') {
          final sId = (_requestData?['studentId'] ?? '').toString();
          final planAmt = (_requestData?['amount'] as num?)?.toDouble() ?? 0.0;
          _promptRenewalPaymentAfterApproval(
            libraryId,
            sId,
            studentUserId,
            studentName.toString(),
            studentPhone,
            planAmt,
            planId: renewalPlanId,
            planStartDate: finalPlanStartDate,
            planEndDate: finalPlanEndDate,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectRequest() async {
    final reasonController = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please specify a reason for rejecting this request:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'e.g. Seats currently full, blurry ID photo...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Application'),
          ),
        ],
      ),
    );

    if (shouldReject != true) return;

    final String libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(widget.requestId)
          .update({
        'status': 'rejected',
        'rejectionReason': reasonController.text.trim().isNotEmpty
            ? reasonController.text.trim()
            : 'Application could not be approved at this time.',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      AuditLogger().log(
        action: AuditAction.rejected,
        entityType: AuditEntity.request,
        libraryId: libraryId,
        entityId: widget.requestId,
        details: {'libraryId': libraryId},
      ).ignore();

      await _loadRequest();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_requestData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: Text('Request not found or has been deleted.')),
      );
    }

    final data = _requestData!;
    final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final isPending = status == 'pending';
    final photoUrl = studentData['photoUrl'] as String? ?? '';
    final studentName = studentData['name'] ?? data['studentName'] ?? 'Student';
    final studentPhone = studentData['phone'] ?? data['studentPhone'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/admin/requests');
            }
          },
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (photoUrl.isNotEmpty) {
                              ImageService.showImageViewer(
                                context,
                                imageUrl: photoUrl,
                                title: studentName,
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.isEmpty
                                ? const Icon(Icons.person, size: 48)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(studentName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(studentPhone, style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 12),
                        Chip(
                          label: Text(status.toUpperCase()),
                          backgroundColor: status == 'approved'
                              ? Colors.green.shade100
                              : status == 'rejected'
                                  ? Colors.red.shade100
                                  : Colors.orange.shade100,
                          labelStyle: TextStyle(
                            color: status == 'approved'
                                ? Colors.green.shade900
                                : status == 'rejected'
                                    ? Colors.red.shade900
                                    : Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (data['type'] == 'profile_update') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Requested Profile Updates', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Compare existing record with proposed updates:', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                            const Divider(height: 20),
                            _buildDiffRow('Emergency Contact', (data['currentData'] as Map?)?['emergencyContact'], (data['proposedData'] as Map?)?['emergencyContact']),
                            _buildDiffRow('College / Institution', (data['currentData'] as Map?)?['college'], (data['proposedData'] as Map?)?['college']),
                            _buildDiffRow('Course', (data['currentData'] as Map?)?['course'], (data['proposedData'] as Map?)?['course']),
                            _buildDiffRow('Year / Semester', (data['currentData'] as Map?)?['year'], (data['proposedData'] as Map?)?['year']),
                            if ((data['proposedData'] as Map?)?['customFields'] is Map) ...[
                              ...((data['proposedData'] as Map)['customFields'] as Map).entries.map((e) {
                                final curMap = (data['currentData'] as Map?)?['customFields'] as Map?;
                                final curVal = curMap?[e.key];
                                return _buildDiffRow(e.key.toString(), curVal, e.value);
                              }),
                            ],
                            if (data['rejectionReason'] != null)
                              _buildRow('Rejection Reason', data['rejectionReason'], color: Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ] else if (data['type'] == 'seat_change' || data['type'] == 'seatchange') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Requested Seat Change', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Review member move request:', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                            const Divider(height: 20),
                            _buildRow('Current Seat', '${SeatHelper.formatSeatLabel(seatId: data['currentSeatId'] as String?, rawLabel: data['currentSeatLabel'] as String?)} (${data['currentSectionName'] ?? "Current Section"})'),
                            _buildRow('Target Seat', '${SeatHelper.formatSeatLabel(seatId: data['targetSeatId'] as String?, rawLabel: data['targetSeatLabel'] as String?)} (${data['targetSectionName'] ?? "Target Section"})', color: Colors.green),
                            if (data['reason'] != null && data['reason'].toString().isNotEmpty)
                              _buildRow('Reason', data['reason'].toString()),
                            if (data['studentGender'] != null)
                              _buildRow('Student Gender', data['studentGender'].toString().toUpperCase()),
                            if (data['rejectionReason'] != null)
                              _buildRow('Rejection Reason', data['rejectionReason'].toString(), color: Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Submitted Details Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Application Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const Divider(height: 20),
                            _buildRow('Request Type', (data['type'] ?? 'Registration').toString().toUpperCase()),
                            if (studentData['fatherName'] != null)
                              _buildRow("Father's Name", studentData['fatherName']),
                            if (studentData['gender'] != null)
                              _buildRow('Gender', studentData['gender'].toString().toUpperCase()),
                            if (studentData['email'] != null && studentData['email'].isNotEmpty)
                              _buildRow('Email', studentData['email']),
                            if (studentData['govIdNumber'] != null && studentData['govIdNumber'].isNotEmpty)
                              _buildRow('Govt ID', studentData['govIdNumber']),
                            if ((studentData['govIdImageUrl'] != null && studentData['govIdImageUrl'].toString().isNotEmpty) ||
                                (studentData['govIdBackImageUrl'] != null && studentData['govIdBackImageUrl'].toString().isNotEmpty)) ...[
                              const SizedBox(height: 8),
                              const Text('Uploaded Identity Documents:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (studentData['govIdImageUrl'] != null && studentData['govIdImageUrl'].toString().isNotEmpty)
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => ImageService.showImageViewer(
                                          context,
                                          imageUrl: studentData['govIdImageUrl'].toString(),
                                          title: 'Front ID Document',
                                        ),
                                        child: Container(
                                          height: 90,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade300),
                                            image: DecorationImage(
                                              image: ImageService.getImageProvider(studentData['govIdImageUrl'].toString())!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            width: double.infinity,
                                            color: Colors.black54,
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: const Text('Front Side', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if ((studentData['govIdImageUrl'] != null && studentData['govIdImageUrl'].toString().isNotEmpty) &&
                                      (studentData['govIdBackImageUrl'] != null && studentData['govIdBackImageUrl'].toString().isNotEmpty))
                                    const SizedBox(width: 8),
                                  if (studentData['govIdBackImageUrl'] != null && studentData['govIdBackImageUrl'].toString().isNotEmpty)
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => ImageService.showImageViewer(
                                          context,
                                          imageUrl: studentData['govIdBackImageUrl'].toString(),
                                          title: 'Back ID Document',
                                        ),
                                        child: Container(
                                          height: 90,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade300),
                                            image: DecorationImage(
                                              image: ImageService.getImageProvider(studentData['govIdBackImageUrl'].toString())!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            width: double.infinity,
                                            color: Colors.black54,
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: const Text('Back Side', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10)),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            if (studentData['college'] != null && studentData['college'].isNotEmpty)
                              _buildRow('College', studentData['college']),
                            if (studentData['course'] != null && studentData['course'].isNotEmpty)
                              _buildRow('Course', studentData['course']),
                            if (studentData['address'] != null && studentData['address'].isNotEmpty)
                              _buildRow('Address', studentData['address']),
                            if (data['rejectionReason'] != null)
                              _buildRow('Rejection Reason', data['rejectionReason'], color: Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (data['createdStudentId'] != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/admin/students/${data['createdStudentId']}'),
                      icon: const Icon(Icons.badge_rounded),
                      label: const Text('View Created Student Profile'),
                    ),
                  ],

                  if (data['type'] == 'profile_update' && data['studentId'] != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/admin/students/${data['studentId']}'),
                      icon: const Icon(Icons.person_rounded),
                      label: const Text('View Student Profile'),
                    ),
                  ],

                  if (isPending) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _rejectRequest,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject Request'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _approveRequest,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve & Add'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
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
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffRow(String field, dynamic oldVal, dynamic newVal) {
    final oldStr = (oldVal ?? '').toString().trim();
    final newStr = (newVal ?? '').toString().trim();
    final isChanged = oldStr != newStr;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current', style: TextStyle(fontSize: 10, color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        oldStr.isEmpty ? '—' : oldStr,
                        style: TextStyle(
                          fontSize: 12,
                          decoration: isChanged && oldStr.isNotEmpty ? TextDecoration.lineThrough : null,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proposed', style: TextStyle(fontSize: 10, color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        newStr.isEmpty ? '—' : newStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isChanged ? FontWeight.bold : FontWeight.normal,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _promptPaymentAfterApproval(
    String libraryId,
    String studentId,
    String studentUserId,
    String studentName,
    String studentPhone, {
    String? planId,
    DateTime? planStartDate,
    DateTime? planEndDate,
  }) {
    if (!mounted) return;

    // Lookup plan price from plansStreamProvider or requestData
    final data = _requestData ?? {};
    final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};
    final effectivePlanId = planId ?? (studentData['planId'] ?? data['planId'])?.toString();

    double defaultAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    if (defaultAmount <= 0 && effectivePlanId != null && effectivePlanId.isNotEmpty) {
      final plans = ref.read(plansStreamProvider).value ?? [];
      final matchedPlan = plans.where((p) => p.id == effectivePlanId).firstOrNull;
      if (matchedPlan != null) {
        defaultAmount = matchedPlan.price.toDouble();
      }
    }

    final amountController = TextEditingController(
      text: defaultAmount > 0 ? defaultAmount.toStringAsFixed(0) : '',
    );
    String paymentMethod = 'Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          icon: const Icon(Icons.celebration_rounded, color: Colors.green, size: 36),
          title: const Text('Registration Approved! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$studentName has been approved. Record payment to activate their pass and generate a receipt.'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (v) => setDs(() => paymentMethod = v ?? 'Cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$studentName remains inactive until fee payment is recorded.'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                  if (studentPhone.isNotEmpty) {
                    _offerWhatsAppWelcome(studentId, studentName, studentPhone, 0, 'None', planEndDate: planEndDate);
                  }
                }
              },
              child: const Text('Skip Payment'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? defaultAmount;
                Navigator.of(ctx).pop();
                if (amount > 0) {
                  await _recordPaymentAndReceipt(
                    libraryId,
                    studentId,
                    studentUserId,
                    studentName,
                    studentPhone,
                    amount,
                    paymentMethod,
                    planId: effectivePlanId,
                    planStartDate: planStartDate,
                    planEndDate: planEndDate,
                  );
                }
                if (mounted && studentPhone.isNotEmpty) {
                  _offerWhatsAppWelcome(studentId, studentName, studentPhone, amount, paymentMethod, planEndDate: planEndDate);
                }
              },
              child: const Text('Confirm & Generate Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  void _promptRenewalPaymentAfterApproval(
    String libraryId,
    String studentId,
    String studentUserId,
    String studentName,
    String studentPhone,
    double renewalAmount, {
    String? planId,
    DateTime? planStartDate,
    DateTime? planEndDate,
  }) {
    if (!mounted) return;
    final amountController = TextEditingController(text: renewalAmount > 0 ? renewalAmount.toStringAsFixed(0) : '');
    String paymentMethod = 'UPI';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          icon: const Icon(Icons.autorenew_rounded, color: Colors.blue, size: 36),
          title: const Text('Renewal Approved! 🔄'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$studentName\'s renewal request has been approved. Record payment to extend their validity and generate receipt.'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Renewal Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Card', child: Text('Debit/Credit Card')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (v) => setDs(() => paymentMethod = v ?? 'UPI'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Renewal approved. $studentName will be activated once payment is recorded.'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                }
              },
              child: const Text('Record Later'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? renewalAmount;
                Navigator.of(ctx).pop();
                if (amount > 0) {
                  await _recordPaymentAndReceipt(
                    libraryId,
                    studentId,
                    studentUserId,
                    studentName,
                    studentPhone,
                    amount,
                    paymentMethod,
                    planId: planId,
                    planStartDate: planStartDate,
                    planEndDate: planEndDate,
                  );
                }
              },
              child: const Text('Record Payment & Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPaymentAndReceipt(
    String libraryId,
    String studentId,
    String studentUserId,
    String studentName,
    String studentPhone,
    double amount,
    String paymentMethod, {
    String? planId,
    DateTime? planStartDate,
    DateTime? planEndDate,
  }) async {
    try {
      final receiptNum = 'REC${DateTime.now().year}${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5,'0')}';
      final receiptRef = FirebaseFirestore.instance.collection('libraries').doc(libraryId).collection('receipts').doc();

      final paymentRef = FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('payments').doc();

      final paymentData = {
        'id': paymentRef.id,
        'studentId': studentId,
        'amount': amount,
        'method': paymentMethod,
        'status': 'paid',
        'date': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'recordedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
        'receiptId': receiptRef.id,
      };

      await paymentRef.set(paymentData);

      // Also copy to subcollection for legacy compatibility
      await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students').doc(studentId)
          .collection('payments').doc(paymentRef.id)
          .set(paymentData);

      // Resolve plan and validity dates
      DateTime effectiveStartDate = planStartDate ?? DateTime.now();
      DateTime? effectiveEndDate = planEndDate;
      String effectivePlanId = planId ?? '';

      final studentDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(studentId)
          .get();

      if (studentDoc.exists) {
        final sData = studentDoc.data() ?? {};
        if (effectivePlanId.isEmpty) {
          effectivePlanId = (sData['planId'] ?? '').toString();
        }

        if (effectiveEndDate == null && effectivePlanId.isNotEmpty) {
          final plans = ref.read(plansStreamProvider).value ?? [];
          final matchedPlan = plans.where((p) => p.id == effectivePlanId).firstOrNull;
          if (matchedPlan != null) {
            final currentEnd = StudentModel.parseDateStatic(sData['planEndDate']);
            if (currentEnd != null && currentEnd.isAfter(DateTime.now())) {
              effectiveStartDate = currentEnd;
            }
            if (matchedPlan.durationUnit == DurationUnit.months) {
              effectiveEndDate = DateTime(
                effectiveStartDate.year,
                effectiveStartDate.month + matchedPlan.duration,
                effectiveStartDate.day,
              );
            } else {
              effectiveEndDate = effectiveStartDate.add(Duration(days: matchedPlan.duration));
            }
          } else {
            effectiveEndDate = effectiveStartDate.add(const Duration(days: 30));
          }
        }
      }

      effectiveEndDate ??= effectiveStartDate.add(const Duration(days: 30));

      // CRITICAL FIX: Activate the student upon recorded payment!
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(studentId)
          .update({
        'membershipStatus': MembershipStatus.active.name,
        'planStartDate': Timestamp.fromDate(effectiveStartDate),
        'planEndDate': Timestamp.fromDate(effectiveEndDate),
        if (effectivePlanId.isNotEmpty) 'planId': effectivePlanId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await receiptRef.set({
        'id': receiptRef.id,
        'receiptNumber': receiptNum,
        'studentId': studentId,
        'studentUserId': studentUserId,
        'studentName': studentName,
        'studentPhone': studentPhone,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'status': 'active',
        'validFrom': Timestamp.fromDate(effectiveStartDate),
        'validTo': Timestamp.fromDate(effectiveEndDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'libraryId': libraryId,
        'planId': effectivePlanId,
        'customFields': {},
      });

      AuditLogger().log(
        action: AuditAction.created,
        entityType: AuditEntity.payment,
        libraryId: libraryId,
        entityId: paymentRef.id,
        entityName: studentName,
        details: {
          'amount': amount,
          'method': paymentMethod,
          'receiptNumber': receiptNum,
          'planStartDate': effectiveStartDate.toIso8601String(),
          'planEndDate': effectiveEndDate.toIso8601String(),
        },
      ).ignore();

      ref.invalidate(studentsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment recorded & Receipt $receiptNum generated ✓ Student is now Active!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red));
    }
  }

  void _offerWhatsAppWelcome(String studentId, String studentName, String studentPhone, double amount, String paymentMethod, {DateTime? planEndDate}) {
    if (!mounted) return;

    final library = ref.read(currentLibraryProvider).value;
    final rawTemplate = library?.whatsappWelcomeTemplate ?? '';
    final template = rawTemplate.isNotEmpty ? rawTemplate : MessageTemplateService.defaultWelcomeTemplate;
    
    // Attempt to get more student info from requestData or providers
    final data = _requestData ?? {};
    final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};
    final seatId = studentData['seatId'] ?? data['requestedSeatId'];
    final planId = studentData['planId'] ?? data['planId'];
    
    String planName = '';
    if (planId != null) {
      final plans = ref.read(plansStreamProvider).value ?? [];
      planName = plans.where((p) => p.id == planId).firstOrNull?.name ?? '';
    }

    final messageStr = MessageTemplateService.substitute(
      template,
      studentName: studentName,
      planName: planName,
      expiryDate: planEndDate != null ? DateFormat('dd MMM yyyy').format(planEndDate) : 'N/A',
      membershipId: studentId,
      seatLabel: seatId ?? 'To be assigned',
      libraryName: library?.name ?? '',
      amount: amount > 0 ? amount.toStringAsFixed(0) : '0',
      paymentMethod: paymentMethod,
      phone: studentPhone,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send WhatsApp Welcome?'),
        content: Text('Send a welcome message to $studentName via WhatsApp?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Skip')),
          FilledButton.icon(
            icon: const Icon(Icons.chat_rounded),
            label: const Text('Send WhatsApp'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () {
              Navigator.of(ctx).pop();
              final cleanPhone = studentPhone.replaceAll(RegExp(r'[^0-9]'), '');
              final fullPhone = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';
              final message = Uri.encodeComponent(messageStr);
              launchUrl(Uri.parse('https://wa.me/$fullPhone?text=$message'), mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }
}
