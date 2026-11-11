import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/services/image_service.dart';
import 'package:intl/intl.dart';
import 'package:study_library/services/student_provisioning_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/error/error_handler.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/models/seat_model.dart';
import '../widgets/admin_document_studio_dialog.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/services/app_notification_service.dart';

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
  StudentModel? _liveStudent;
  String? _liveSeatLabel;
  String? _liveSectionName;
  String? _currentPlanName;
  bool _showGovId = false;
  bool _isRequestedSeatOccupied = false;
  String? _occupyingStudentName;
  String? _occupyingStudentId;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
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
        final reqData = doc.data();
        StudentModel? liveStudent;
        String? liveSeatLabel;
        String? liveSectionName;
        String? currentPlanName;

        final studentId = (reqData?['studentId'] ?? '').toString();
        if (studentId.isNotEmpty) {
          try {
            final sDoc = await FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('students')
                .doc(studentId)
                .get();

            if (sDoc.exists) {
              final student = StudentModel.fromJson({'id': sDoc.id, ...sDoc.data()!});
              liveStudent = student;

              final seatId = student.seatId;
              if (seatId != null && seatId.isNotEmpty) {
                final seatDoc = await FirebaseFirestore.instance
                    .collection('libraries')
                    .doc(libraryId)
                    .collection('seats')
                    .doc(seatId)
                    .get();

                if (seatDoc.exists) {
                  final sMap = seatDoc.data()!;
                  liveSeatLabel = sMap['label']?.toString() ?? sMap['number']?.toString();
                  final secId = sMap['sectionId']?.toString();
                  if (secId != null && secId.isNotEmpty) {
                    final secDoc = await FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('sections')
                        .doc(secId)
                        .get();
                    if (secDoc.exists) {
                      liveSectionName = secDoc.data()?['name']?.toString();
                    }
                  }
                }
              }

              final planId = student.planId;
              if (planId != null && planId.isNotEmpty) {
                final pDoc = await FirebaseFirestore.instance
                    .collection('libraries')
                    .doc(libraryId)
                    .collection('plans')
                    .doc(planId)
                    .get();
                if (pDoc.exists) {
                  currentPlanName = pDoc.data()?['name']?.toString();
                }
              }
            }
          } catch (e) {
            debugPrint('Error fetching live student context: $e');
          }
        }

        // ── Phase 2: Live Desk Collision & Availability Detection ─────────────
        final studentDataMap = (reqData?['studentData'] as Map?)?.cast<String, dynamic>() ?? {};
        final reqSeatId = (reqData?['requestedSeatId'] ?? studentDataMap['requestedSeatId'] ?? studentDataMap['seatId'] ?? reqData?['seatId'])?.toString();
        final reqSecId = (reqData?['requestedSectionId'] ?? studentDataMap['requestedSectionId'] ?? studentDataMap['sectionId'] ?? reqData?['sectionId'])?.toString();
        final applicantUid = (reqData?['userId'] ?? studentDataMap['userId'] ?? '').toString();

        bool isSeatOccupied = false;
        String? occupantName;
        String? occupantId;

        if (reqSeatId != null &&
            reqSeatId.isNotEmpty &&
            reqSecId != null &&
            reqSecId.isNotEmpty &&
            !reqSeatId.toLowerCase().contains('auto')) {
          try {
            final seatDoc = await FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('sections')
                .doc(reqSecId)
                .collection('seats')
                .doc(reqSeatId)
                .get();

            if (seatDoc.exists) {
              final seatMap = seatDoc.data() ?? {};
              final seatStatus = (seatMap['status'] ?? '').toString().toLowerCase();
              final currentOccupant = (seatMap['studentId'] ?? '').toString();

              if (seatStatus == 'occupied' &&
                  currentOccupant.isNotEmpty &&
                  currentOccupant != applicantUid &&
                  currentOccupant != studentId) {
                isSeatOccupied = true;
                occupantId = currentOccupant;
                try {
                  final occDoc = await FirebaseFirestore.instance
                      .collection('libraries')
                      .doc(libraryId)
                      .collection('students')
                      .doc(currentOccupant)
                      .get();
                  if (occDoc.exists) {
                    occupantName = occDoc.data()?['name']?.toString() ?? 'Enrolled Student';
                  }
                } catch (_) {}
              }
            }
          } catch (seatErr) {
            debugPrint('Error validating requested seat availability: $seatErr');
          }
        }

        setState(() {
          _requestData = reqData;
          _liveStudent = liveStudent;
          _liveSeatLabel = liveSeatLabel;
          _liveSectionName = liveSectionName;
          _currentPlanName = currentPlanName;
          _isRequestedSeatOccupied = isSeatOccupied;
          _occupyingStudentName = occupantName;
          _occupyingStudentId = occupantId;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveRequest({
    bool allowSharedGovId = false,
    bool allowSharedPhone = false,
    bool mergeExistingPhone = true,
  }) async {
    final String libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty || _requestData == null) return;

    setState(() => _isProcessing = true);

    try {
      final data = _requestData!;
      final type = (data['type'] as String? ?? 'registration').toLowerCase();
      final studentData = (data['studentData'] as Map?)?.cast<String, dynamic>() ?? {};

      // ── Phase 2: Desk Collision Guard on Approval ───────────────────────────
      if (_isRequestedSeatOccupied &&
          (type == 'registration' ||
              type == 'newregistration' ||
              type == 'seat_change' ||
              type == 'seatchange')) {
        setState(() => _isProcessing = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Desk Collision Conflict'),
                ],
              ),
              content: Text(
                'The requested desk is currently occupied by ${_occupyingStudentName ?? "another student"}${_occupyingStudentId != null ? " (ID: $_occupyingStudentId)" : ""}.\n\n'
                'To prevent allocation conflicts, please pick an available vacant desk or switch to Auto-Assign before approving.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _switchToAutoAssign(data, studentData);
                  },
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Auto-Assign'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showChangeDeskSheet(data, studentData);
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Pick Another Desk'),
                ),
              ],
            ),
          );
        }
        return;
      }

      DateTime? finalPlanStartDate;
      DateTime? finalPlanEndDate;
      String? renewalPlanId;

      if (type == 'registration' || type == 'newregistration') {
        _newCreatedStudentId = await StudentProvisioningService.approveAndProvisionRequest(
          libraryId: libraryId,
          requestId: widget.requestId,
          preloadedData: data,
          allowSharedGovId: allowSharedGovId,
          allowSharedPhone: allowSharedPhone,
          mergeExistingPhone: mergeExistingPhone,
        );

        // Fetch newly provisioned student data to resolve exact plan dates
        if (_newCreatedStudentId != null) {
          try {
            final sDoc = await FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('students')
                .doc(_newCreatedStudentId!)
                .get();
            if (sDoc.exists && sDoc.data() != null) {
              final sData = sDoc.data()!;
              finalPlanStartDate = StudentModel.parseDateStatic(sData['planStartDate']) ?? DateTime.now();
              finalPlanEndDate = StudentModel.parseDateStatic(sData['planEndDate']);
            }
          } catch (_) {}
        }

        // Guaranteed fallback calculation if student plan dates were not yet committed
        if (finalPlanEndDate == null) {
          finalPlanStartDate ??= DateTime.now();
          final planId = (data['planId'] ?? (data['studentData'] as Map?)?['planId'])?.toString();
          if (planId != null && planId.isNotEmpty) {
            final plans = ref.read(plansStreamProvider).value ?? [];
            final matchedPlan = plans.where((p) => p.id == planId).firstOrNull;
            if (matchedPlan != null) {
              if (matchedPlan.durationUnit == DurationUnit.months) {
                finalPlanEndDate = DateTime(finalPlanStartDate.year, finalPlanStartDate.month + matchedPlan.duration, finalPlanStartDate.day);
              } else {
                finalPlanEndDate = finalPlanStartDate.add(Duration(days: matchedPlan.duration));
              }
            }
          }
          finalPlanEndDate ??= finalPlanStartDate.add(const Duration(days: 30));
        }
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

            finalPlanStartDate = newStartDate;
            finalPlanEndDate = newEndDate;
            renewalPlanId = requestedPlanId;
          }
        }
      } else if (type == 'freeze') {
        final studentId = (data['studentId'] ?? '').toString();
        final rawProjectedEnd = data['projectedEndDate'];
        final freezeDays = (data['freezeDays'] as num?)?.toInt() ?? 0;
        final freezeStartStr = data['freezeStartDate'];
        final freezeEndStr = data['freezeEndDate'];

        if (studentId.isNotEmpty && rawProjectedEnd != null) {
          final newEnd = DateTime.parse(rawProjectedEnd.toString());
          final freezeStartDt = freezeStartStr != null ? DateTime.tryParse(freezeStartStr.toString()) : null;
          final freezeEndDt = freezeEndStr != null ? DateTime.tryParse(freezeEndStr.toString()) : null;
          final freezeReason = data['reason']?.toString() ?? 'Study Freeze';

          await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(studentId)
              .update({
            'planEndDate': Timestamp.fromDate(newEnd),
            'validTo': Timestamp.fromDate(newEnd),
            'isFrozen': true,
            'freezeStartDate': freezeStartDt != null ? Timestamp.fromDate(freezeStartDt) : null,
            'freezeEndDate': freezeEndDt != null ? Timestamp.fromDate(freezeEndDt) : null,
            'freezeReason': freezeReason,
            'lastFreezeDays': freezeDays,
            'lastFreezeStartDate': freezeStartDt != null ? Timestamp.fromDate(freezeStartDt) : null,
            'lastFreezeEndDate': freezeEndDt != null ? Timestamp.fromDate(freezeEndDt) : null,
            'freezeStatus': 'approved',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Dispatch in-app notification to student
          AppNotificationService.sendNotification(
            libraryId: libraryId,
            targetUserId: studentId,
            targetRole: 'student',
            title: 'Study Freeze Approved! ❄️',
            body: 'Your study freeze for $freezeDays days has been approved. Your pass validity has been extended to ${DateFormat('dd MMM yyyy').format(newEnd)}.',
            type: 'admission',
          ).ignore();

          AuditLogger().log(
            action: AuditAction.updated,
            entityType: AuditEntity.student,
            libraryId: libraryId,
            entityId: studentId,
            details: {
              'action': 'study_freeze_approved',
              'freezeDays': freezeDays,
              'extendedEndDate': newEnd.toIso8601String(),
            },
          ).ignore();
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
                : (type == 'freeze'
                    ? 'Study vacation freeze approved! Plan validity extended.'
                    : (type == 'renewal'
                        ? 'Renewal approved! Please record payment to extend validity.'
                        : 'Request approved! Please record payment to activate pass.')));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
        );

        final studentName = _requestData?['studentName'] ??
            (_requestData?['studentData'] as Map<String, dynamic>?)?['name'] ??
            _liveStudent?.name ??
            'Student';
        final studentPhone = ((_requestData?['studentData'] as Map<String, dynamic>?)?['phone'] ??
                _requestData?['studentPhone'] ??
                _liveStudent?.phone ??
                '')
            .toString();
        final studentUserId = ((_requestData?['studentData'] as Map<String, dynamic>?)?['userId'] ??
                _requestData?['studentId'] ??
                _liveStudent?.userId ??
                '')
            .toString();

        if ((type == 'registration' || type == 'newregistration') && _newCreatedStudentId != null) {
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
          final sId = (_requestData?['studentId'] ?? _liveStudent?.id ?? '').toString();
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
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('phone number is already registered to student')) {
          final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
          final studentData = (_requestData?['studentData'] as Map<String, dynamic>?) ?? {};
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.phone_in_talk_rounded, color: Colors.amber.shade800, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Existing Student / Shared Phone', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanMsg,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This student may have enrolled previously, or two siblings are sharing a guardian phone.\n\n'
                    '• "Merge & Update Profile": Links this admission to the existing student record, updates their seat & plan, and activates their pass.\n'
                    '• "Allow Shared Phone": Creates a new student record sharing this family mobile number.\n'
                    '• "Edit Phone": Corrects any phone number typing error.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditApplicantDialog(studentData);
                  },
                  child: const Text('Edit Phone'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _approveRequest(allowSharedPhone: true);
                  },
                  child: const Text('Allow Shared Phone'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Merge & Approve'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _approveRequest(mergeExistingPhone: true);
                  },
                ),
              ],
            ),
          );
          return;
        }

        if (errStr.contains('government id') && errStr.contains('already registered to student')) {
          final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
          final studentData = (_requestData?['studentData'] as Map<String, dynamic>?) ?? {};
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.family_restroom_rounded, color: Colors.amber.shade800, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Shared Family / Sibling ID', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanMsg,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'In family registrations, siblings or dependents often share a guardian ID proof.\n\n'
                    '• Choose "Edit ID Proof" to enter their personal Aadhaar or PAN card number.\n'
                    '• Choose "Allow Sibling ID & Approve" to approve admission with the shared ID.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditApplicantDialog(studentData);
                  },
                  child: const Text('Edit ID Proof'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Allow Sibling ID & Approve'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _approveRequest(allowSharedGovId: true);
                  },
                ),
              ],
            ),
          );
          return;
        }
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'request');
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please specify a reason for rejecting this request:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'e.g. Seats full, incorrect payment UTR, blurry ID proof...',
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

      // Release soft-locked desk if this was an admission with a reserved desk
      final reqSeatId = (_requestData?['requestedSeatId'] ?? _requestData?['seatId'])?.toString();
      final reqSecId = (_requestData?['requestedSectionId'] ?? _requestData?['sectionId'])?.toString();
      if (reqSeatId != null && reqSeatId.isNotEmpty && reqSecId != null && reqSecId.isNotEmpty) {
        try {
          await ref.read(seatRepositoryProvider).releaseSoftLock(
            libraryId: libraryId,
            sectionId: reqSecId,
            seatId: reqSeatId,
          );
        } catch (_) {}
      }

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
          const SnackBar(content: Text('Request marked as rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ErrorHandler.handleError(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reopenRequest() async {
    final String libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reopen Admission Request?'),
        content: const Text(
          'This will reset the application status back to "Pending Verification", allowing you to edit applicant details and approve admission.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reopen Application'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(widget.requestId)
          .update({
        'status': 'pending',
        'reopenedAt': FieldValue.serverTimestamp(),
        'rejectionReason': FieldValue.delete(),
      });

      AuditLogger().log(
        action: AuditAction.updated,
        entityType: AuditEntity.request,
        libraryId: libraryId,
        entityId: widget.requestId,
        details: {'action': 'request_reopened'},
      ).ignore();

      await _loadRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request reset to Pending! You can now edit details and approve.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'request');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) {
      try {
        return DateTime.parse(val);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatDate(DateTime? dt, {bool withTime = false}) {
    if (dt == null) return '—';
    if (withTime) {
      return DateFormat('dd MMM yyyy • hh:mm a').format(dt);
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildBackButton() {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/admin/requests');
          }
        },
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: buildBackButton(),
          title: const Text('Request Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_requestData == null) {
      return Scaffold(
        appBar: AppBar(
          leading: buildBackButton(),
          title: const Text('Request Details'),
        ),
        body: const Center(child: Text('Request not found or has been deleted.')),
      );
    }

    final data = _requestData!;
    final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};
    final type = (data['type'] as String? ?? 'registration').toLowerCase();
    final status = (data['status'] as String? ?? 'pending').toLowerCase().trim();
    final isPending = status == 'pending' ||
        status == 'desk_payment_pending' ||
        status == 'payment_pending' ||
        status == 'submitted' ||
        status == 'open' ||
        status.contains('pending');

    final photoUrl = (studentData['photoUrl'] ?? _liveStudent?.photoUrl ?? data['photoUrl'] ?? '').toString();
    final studentName = (studentData['name'] ?? data['studentName'] ?? _liveStudent?.name ?? 'Student').toString();
    final studentPhone = (studentData['phone'] ?? data['studentPhone'] ?? _liveStudent?.phone ?? '').toString();
    final studentEmail = (studentData['email'] ?? _liveStudent?.email ?? data['studentEmail'] ?? '').toString();

    final amountNum = data['amount'] as num?;
    final amount = amountNum?.toDouble();
    final origPriceNum = data['originalPrice'] as num?;
    final origPrice = origPriceNum?.toDouble();
    final paymentMethod = (data['paymentMethod'] ?? data['paymentModeLabel'] ?? '').toString();
    final refNumber = (data['referenceNumber'] ?? '').toString().trim();
    final paymentProofUrl = (data['paymentProofUrl'] ?? '').toString().trim();
    final notes = (data['notes'] ?? studentData['notes'] ?? '').toString().trim();
    final createdAt = _parseDate(data['createdAt']);
    final isDeskCash = status == 'desk_payment_pending' ||
        paymentMethod.toLowerCase().contains('cash') ||
        (data['paymentModeLabel'] ?? '').toString().toLowerCase().contains('desk');

    final isRenewal = type == 'renewal';
    final isRegistration = type == 'registration' || type == 'newregistration';
    final hasRequestedSeat = data['requestedSeatId'] != null ||
        data['requestedSeatLabel'] != null ||
        studentData['seatId'] != null ||
        studentData['requestedSeatLabel'] != null;
    final hasPaymentInfo = amount != null || paymentMethod.isNotEmpty || refNumber.isNotEmpty || paymentProofUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        leading: buildBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
            onPressed: _loadRequest,
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header Profile Banner
                      _buildHeaderBanner(
                        theme: theme,
                        photoUrl: photoUrl,
                        studentName: studentName,
                        studentPhone: studentPhone,
                        studentEmail: studentEmail,
                        status: status,
                        type: type,
                        isDeskCash: isDeskCash,
                        studentId: (_liveStudent?.id ?? data['studentId'])?.toString(),
                      ),
                      const SizedBox(height: 20),

                      // Rejection Alert if already rejected
                      if (status == 'rejected' && data['rejectionReason'] != null) ...[
                        _buildRejectionNotice(theme, data['rejectionReason'].toString()),
                        const SizedBox(height: 16),
                      ],

                      // 2. Payment & Verification Ledger Card
                      if (hasPaymentInfo) ...[
                        _buildPaymentLedgerCard(
                          theme: theme,
                          amount: amount,
                          originalPrice: origPrice,
                          paymentMethod: paymentMethod,
                          refNumber: refNumber,
                          paymentProofUrl: paymentProofUrl,
                          isDeskCash: isDeskCash,
                          createdAt: createdAt,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. Requested Plan & Membership Cycle Card (For Renewals or Registrations)
                      if (isRenewal) ...[
                        _buildRenewalPlanCard(theme: theme, data: data),
                        const SizedBox(height: 16),
                      ] else if (isRegistration) ...[
                        _buildRegistrationPlanCard(theme: theme, data: data, studentData: studentData),
                        const SizedBox(height: 16),
                      ],

                      // 4. Student Remarks / Notes
                      if (notes.isNotEmpty) ...[
                        _buildRemarksCard(theme: theme, notes: notes),
                        const SizedBox(height: 16),
                      ],

                      // 5. Seat Change Comparison Card
                      if (type == 'seat_change' || type == 'seatchange') ...[
                        _buildSeatChangeCard(theme: theme, data: data),
                        const SizedBox(height: 16),
                      ],

                      // 6. Profile Update Diff Card
                      if (type == 'profile_update') ...[
                        _buildProfileUpdateCard(theme: theme, data: data),
                        const SizedBox(height: 16),
                      ],

                      // 6.2 Study Vacation / Freeze Details Card
                      if (type == 'freeze') ...[
                        _buildFreezeDetailsCard(theme: theme, data: data),
                        const SizedBox(height: 16),
                      ],

                      // 6.5 Requested Study Desk Allocation Card
                      if (hasRequestedSeat || isRegistration) ...[
                        _buildRequestedSeatCard(
                          theme: theme,
                          data: data,
                          studentData: studentData,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 7. Complete Applicant Biodata (For Registrations)
                      if (type == 'registration' || type == 'newregistration') ...[
                        _buildApplicantBiodataCard(theme: theme, studentData: studentData),
                        const SizedBox(height: 16),
                      ],

                      // View Created Student Button (if already approved & provisioned)
                      if (data['createdStudentId'] != null) ...[
                        FilledButton.icon(
                          onPressed: () => context.go('/admin/students/${data['createdStudentId']}'),
                          icon: const Icon(Icons.badge_rounded),
                          label: const Text('View Student Profile & Pass'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 8. Action Buttons (Reject & Approve)
                      if (isPending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _rejectRequest,
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Reject Request', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                onPressed: _approveRequest,
                                icon: const Icon(Icons.check_circle_rounded),
                                label: Text(
                                  isRenewal
                                      ? 'Approve Renewal'
                                      : (type == 'seat_change' || type == 'seatchange'
                                          ? 'Approve Seat Change'
                                          : 'Approve & Activate Pass'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 9. Reopen Action for Rejected Requests
                      if (data['status'] == 'rejected') ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _reopenRequest,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reopen Request / Reset to Pending',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderBanner({
    required ThemeData theme,
    required String photoUrl,
    required String studentName,
    required String studentPhone,
    required String studentEmail,
    required String status,
    required String type,
    required bool isDeskCash,
    required String? studentId,
  }) {
    Color badgeBg;
    Color badgeFg;
    String badgeText;

    if (status == 'approved') {
      badgeBg = Colors.green.shade100;
      badgeFg = Colors.green.shade900;
      badgeText = 'APPROVED';
    } else if (status == 'rejected') {
      badgeBg = Colors.red.shade100;
      badgeFg = Colors.red.shade900;
      badgeText = 'REJECTED';
    } else if (isDeskCash) {
      badgeBg = Colors.amber.shade100;
      badgeFg = Colors.amber.shade900;
      badgeText = 'DESK CASH PENDING';
    } else {
      badgeBg = Colors.orange.shade100;
      badgeFg = Colors.orange.shade900;
      badgeText = 'PENDING VERIFICATION';
    }

    final typeLabel = type == 'renewal'
        ? 'Membership Renewal'
        : (type == 'seat_change' || type == 'seatchange'
            ? 'Seat Relocation'
            : (type == 'freeze'
                ? 'Study Vacation / Freeze'
                : (type == 'profile_update' ? 'Profile Update' : 'New Registration')));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (photoUrl.isNotEmpty) {
                ImageService.showImageViewer(
                  context,
                  imageUrl: photoUrl,
                  title: '$studentName Photo',
                );
              }
            },
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: photoUrl.isNotEmpty ? ImageService.getImageProvider(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Icon(Icons.person, size: 48, color: theme.colorScheme.onPrimaryContainer)
                      : null,
                ),
                if (photoUrl.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Icon(Icons.zoom_in_rounded, size: 16, color: theme.colorScheme.primary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            studentName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.brightness == Brightness.dark ? Colors.white12 : const Color(0xFFCBD5E1), width: 0.8),
                ),
                child: Text(
                  typeLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Action Bar
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (studentPhone.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.call_rounded, size: 16, color: Colors.green),
                  label: Text(studentPhone),
                  onPressed: () {
                    final cleanPhone = studentPhone.replaceAll(RegExp(r'[^0-9]'), '');
                    launchUrl(Uri.parse('tel:$cleanPhone'));
                  },
                ),
              if (studentPhone.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.chat_rounded, size: 16, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp'),
                  onPressed: () {
                    final cleanPhone = studentPhone.replaceAll(RegExp(r'[^0-9]'), '');
                    final fullPhone = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';
                    final msg = Uri.encodeComponent(
                      'Hello $studentName, this is regarding your Cozy Corner Study Library $typeLabel request.',
                    );
                    launchUrl(Uri.parse('https://wa.me/$fullPhone?text=$msg'), mode: LaunchMode.externalApplication);
                  },
                ),
              if (studentId != null && studentId.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.person_outline_rounded, size: 16),
                  label: const Text('View Profile'),
                  onPressed: () => context.go('/admin/students/$studentId'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionNotice(ThemeData theme, String reason) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Application Rejected',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentLedgerCard({
    required ThemeData theme,
    required double? amount,
    required double? originalPrice,
    required String paymentMethod,
    required String refNumber,
    required String paymentProofUrl,
    required bool isDeskCash,
    required DateTime? createdAt,
  }) {
    String formattedAmount = amount != null ? NumberFormat('#,##,###').format(amount) : '—';
    String? formattedOriginal = originalPrice != null ? NumberFormat('#,##,###').format(originalPrice) : null;
    final hasDiscount = originalPrice != null && amount != null && originalPrice > amount;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment & Verification Ledger',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Financial transaction records submitted by student',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Desk Cash Alert Banner
            if (isDeskCash) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.payments_rounded, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Desk Payment — Physical Cash Verification Required',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'The student opted to deposit cash at the reception desk. Please confirm the physical cash is received in hand before clicking "Approve".',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Amount Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Payable Amount',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹$formattedAmount',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          if (hasDiscount && formattedOriginal != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '₹$formattedOriginal',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Save ₹${(originalPrice - amount).toInt()}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Payment Mode Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDeskCash
                          ? Colors.amber.shade50
                          : (paymentMethod.toLowerCase().contains('bank') ? Colors.blue.shade50 : Colors.purple.shade50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDeskCash
                            ? Colors.amber.shade300
                            : (paymentMethod.toLowerCase().contains('bank') ? Colors.blue.shade300 : Colors.purple.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDeskCash
                              ? Icons.money_rounded
                              : (paymentMethod.toLowerCase().contains('bank')
                                  ? Icons.account_balance_rounded
                                  : Icons.qr_code_2_rounded),
                          size: 16,
                          color: isDeskCash
                              ? Colors.amber.shade900
                              : (paymentMethod.toLowerCase().contains('bank') ? Colors.blue.shade900 : Colors.purple.shade900),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          paymentMethod.isNotEmpty ? paymentMethod.toUpperCase() : (isDeskCash ? 'CASH AT DESK' : 'UPI'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDeskCash
                                ? Colors.amber.shade900
                                : (paymentMethod.toLowerCase().contains('bank') ? Colors.blue.shade900 : Colors.purple.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // UTR / Reference Row
            if (refNumber.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'UTR / TRANSACTION REFERENCE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          SelectableText(
                            refNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy UTR Number',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: refNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('UTR $refNumber copied to clipboard!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Payment Proof Screenshot Thumbnail
            if (paymentProofUrl.isNotEmpty) ...[
              const Text(
                'Payment Receipt Screenshot:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  ImageService.showImageViewer(
                    context,
                    imageUrl: paymentProofUrl,
                    title: 'Payment Proof Screenshot',
                  );
                },
                child: Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.black12,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: ImageService.buildImageWidget(
                            paymentProofUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Tap to View Full Payment Receipt',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Submission Timestamp
            if (createdAt != null)
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Submitted on ${_formatDate(createdAt, withTime: true)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenewalPlanCard({required ThemeData theme, required Map<String, dynamic> data}) {
    final planName = (data['requestedPlanName'] ?? data['planName'] ?? 'Standard Pass').toString();
    final cycleStart = _parseDate(data['cycleStartDate']);
    final cycleEnd = _parseDate(data['cycleEndDate']);
    final isAdvance = data['isAdvanceRenewal'] == true;
    final keepSeat = data['keepSeat'] == true;

    final durationDays = (cycleStart != null && cycleEnd != null)
        ? cycleEnd.difference(cycleStart).inDays
        : null;

    final liveExpiry = _liveStudent?.planEndDate;
    final isExpired = liveExpiry != null && liveExpiry.isBefore(DateTime.now());
    final daysRemaining = liveExpiry?.difference(DateTime.now()).inDays;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.autorenew_rounded, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requested Plan & Membership Cycle',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Extension schedule & seat allocation preference',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            _buildRow('Requested Plan', planName, isBold: true),
            if (cycleStart != null && cycleEnd != null)
              _buildRow(
                'Validity Cycle',
                '${_formatDate(cycleStart)}  →  ${_formatDate(cycleEnd)}${durationDays != null ? " ($durationDays Days)" : ""}',
                color: const Color(0xFF1565C0),
                isBold: true,
              ),
            _buildRow(
              'Renewal Mode',
              isAdvance
                  ? '🔄 Advance Renewal (Extends continuously after current expiry)'
                  : '⚡ Immediate Activation (Starts today)',
            ),
            _buildRow(
              'Desk Assignment',
              keepSeat
                  ? '🪑 Retain Current Desk (Seat #${_liveSeatLabel ?? data['currentSeatId'] ?? 'Current'})'
                  : '🔄 Request New Desk / Open Seating',
            ),

            // Live Student Membership Comparison Box
            if (_liveStudent != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        const Text(
                          'Current Active Membership Details:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (liveExpiry != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isExpired ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isExpired
                                  ? 'EXPIRED (${liveExpiry.difference(DateTime.now()).inDays.abs()}d ago)'
                                  : 'ACTIVE (${daysRemaining}d left)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isExpired ? Colors.red.shade900 : Colors.green.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCompactRow('Current Plan', _currentPlanName ?? 'Standard Pass'),
                    _buildCompactRow('Current Expiry', _formatDate(liveExpiry)),
                    _buildCompactRow(
                      'Assigned Desk',
                      _liveSeatLabel != null
                          ? 'Seat #$_liveSeatLabel${_liveSectionName != null ? " ($_liveSectionName)" : ""}'
                          : 'Unassigned',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationPlanCard({
    required ThemeData theme,
    required Map<String, dynamic> data,
    required Map<String, dynamic> studentData,
  }) {
    final planName = (data['planName'] ?? studentData['planName'] ?? 'Cozy Study Plan').toString();
    final planId = (data['planId'] ?? studentData['planId'])?.toString();

    double? proratedFee = (data['proratedFee'] as num?)?.toDouble() ??
        (studentData['proratedFee'] as num?)?.toDouble();
    double? fullPlanPrice = (data['planPrice'] as num?)?.toDouble() ??
        (studentData['planPrice'] as num?)?.toDouble();
    int? daysRemaining = (data['daysRemaining'] as num?)?.toInt() ??
        (studentData['daysRemaining'] as num?)?.toInt();
    final cycleStartStr = (data['cycleStartDate'] ?? studentData['cycleStartDate']) as String?;
    final cycleEndStr = (data['cycleEndDate'] ?? studentData['cycleEndDate']) as String?;
    DateTime? cycleStart = cycleStartStr != null ? DateTime.tryParse(cycleStartStr) : null;
    DateTime? cycleEnd = cycleEndStr != null ? DateTime.tryParse(cycleEndStr) : null;

    if ((proratedFee == null || fullPlanPrice == null) && planId != null && planId.isNotEmpty) {
      final plans = ref.watch(plansStreamProvider).value ?? [];
      final matchedPlan = plans.where((p) => p.id == planId).firstOrNull;
      if (matchedPlan != null) {
        final calc = PlanCalculatorService.calculateSmartPlan(plan: matchedPlan);
        proratedFee ??= calc.proratedPrice;
        fullPlanPrice ??= matchedPlan.price;
        daysRemaining ??= calc.daysRemaining;
        cycleStart ??= calc.startDate;
        cycleEnd ??= calc.endDate;
      }
    }

    final isProrated = proratedFee != null && fullPlanPrice != null && proratedFee < fullPlanPrice;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1.2),
      ),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.point_of_sale_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requested Study Pass & Desk Collection',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Prorated calendar cycle fee payable upon student arrival',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showChangePlanDialog(data, studentData),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Change Plan'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
                if (proratedFee != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '₹${proratedFee.toStringAsFixed(0)} Due',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16A34A), fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 24),
            _buildRow('Selected Plan', planName, isBold: true),
            if (fullPlanPrice != null)
              _buildRow('Standard Monthly Rate', '₹${fullPlanPrice.toStringAsFixed(0)} / month'),
            if (cycleStart != null && cycleEnd != null)
              _buildRow(
                'Current Billing Cycle',
                '${_formatDate(cycleStart)}  →  ${_formatDate(cycleEnd)}${daysRemaining != null ? " ($daysRemaining Days Remaining)" : ""}',
                color: const Color(0xFF1565C0),
                isBold: true,
              ),
            _buildRow(
              'Amount Payable at Reception',
              '₹${(proratedFee ?? fullPlanPrice ?? 0).toStringAsFixed(0)} ${isProrated ? "(Fair Pro-rata applied)" : "(Full Month)"}',
              color: const Color(0xFF16A34A),
              isBold: true,
            ),
            _buildRow(
              'Payment Settlement',
              '🏢 Front Desk (Collect via Cash or UPI when activating admission)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarksCard({required ThemeData theme, required String notes}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.format_quote_rounded, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Student Remarks & Special Requests',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Text(
                notes,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatChangeCard({required ThemeData theme, required Map<String, dynamic> data}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.airline_seat_recline_extra_rounded, color: Colors.teal, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requested Seat Relocation',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Member desk swap request',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildRow(
              'Current Seat',
              '${SeatHelper.formatSeatLabel(seatId: data['currentSeatId'] as String?, rawLabel: data['currentSeatLabel'] as String?)} (${data['currentSectionName'] ?? "Current Section"})',
            ),
            _buildRow(
              'Target Seat',
              '${SeatHelper.formatSeatLabel(seatId: data['targetSeatId'] as String?, rawLabel: data['targetSeatLabel'] as String?)} (${data['targetSectionName'] ?? "Target Section"})',
              color: Colors.green,
              isBold: true,
            ),
            if (data['reason'] != null && data['reason'].toString().isNotEmpty)
              _buildRow('Reason for Shift', data['reason'].toString()),
            if (data['studentGender'] != null)
              _buildRow('Student Gender', data['studentGender'].toString().toUpperCase()),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileUpdateCard({required ThemeData theme, required Map<String, dynamic> data}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.manage_accounts_rounded, color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requested Profile Updates',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Compare existing student record with proposed values',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDiffRow('Emergency Contact', (data['currentData'] as Map?)?['emergencyContact'], (data['proposedData'] as Map?)?['emergencyContact']),
            _buildDiffRow('College / Institution', (data['currentData'] as Map?)?['college'], (data['proposedData'] as Map?)?['college']),
            _buildDiffRow('Course', (data['currentData'] as Map?)?['course'], (data['proposedData'] as Map?)?['course']),
            _buildDiffRow('Year / Semester', (data['currentData'] as Map?)?['year'], (data['proposedData'] as Map?)?['year']),
            if ((data['proposedData'] as Map?)?['customFields'] is Map) ...[
              ...((data['proposedData'] as Map)['customFields'] as Map)
                  .entries
                  .where((e) => !_isInternalKey(e.key.toString()))
                  .map((e) {
                final curMap = (data['currentData'] as Map?)?['customFields'] as Map?;
                final curVal = curMap?[e.key];
                return _buildDiffRow(_formatFieldKey(e.key.toString()), curVal, e.value);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFreezeDetailsCard({required ThemeData theme, required Map<String, dynamic> data}) {
    final freezeStart = data['freezeStartDate'] != null ? DateTime.tryParse(data['freezeStartDate'].toString()) : null;
    final freezeEnd = data['freezeEndDate'] != null ? DateTime.tryParse(data['freezeEndDate'].toString()) : null;
    final projEnd = data['projectedEndDate'] != null ? DateTime.tryParse(data['projectedEndDate'].toString()) : null;
    final currentEnd = data['currentPlanEndDate'] != null ? DateTime.tryParse(data['currentPlanEndDate'].toString()) : null;
    final freezeDays = data['freezeDays'] ?? 0;
    final reason = data['reason']?.toString() ?? 'None provided';
    final fmt = DateFormat('dd MMM yyyy');

    return Card(
      elevation: 0,
      color: Colors.blue.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade300.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.ac_unit_rounded, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requested Study Vacation / Freeze',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Temporary pause to extend membership validity',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(12)),
                  child: Text('$freezeDays Days', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 24),
            if (freezeStart != null && freezeEnd != null)
              _buildDiffRow(
                'Vacation Period',
                null,
                '${fmt.format(freezeStart)} – ${fmt.format(freezeEnd)}',
              ),
            if (currentEnd != null) ...[
              const SizedBox(height: 8),
              _buildDiffRow(
                'Current Expiry',
                null,
                fmt.format(currentEnd),
              ),
            ],
            if (projEnd != null) ...[
              const SizedBox(height: 8),
              _buildDiffRow(
                'Projected Extended Expiry',
                null,
                fmt.format(projEnd),
              ),
            ],
            const SizedBox(height: 8),
            _buildDiffRow(
              'Student Reason',
              null,
              reason,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestedSeatCard({
    required ThemeData theme,
    required Map<String, dynamic> data,
    required Map<String, dynamic> studentData,
  }) {
    final seatLabel = (data['requestedSeatLabel'] ??
            studentData['requestedSeatLabel'] ??
            data['requestedSeatId'] ??
            studentData['seatId'] ??
            '')
        .toString();
    final sectionName = (data['requestedSectionName'] ??
            studentData['requestedSectionName'] ??
            'Cozy Hall')
        .toString();
    final isAuto = seatLabel.toLowerCase().contains('auto') || seatLabel.isEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAuto
                        ? Colors.amber.withValues(alpha: 0.12)
                        : Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isAuto ? Icons.bolt_rounded : Icons.event_seat_rounded,
                    color: isAuto ? Colors.amber.shade900 : Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requested Study Desk',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isAuto
                            ? 'Student opted for auto-assignment by library staff'
                            : 'Desk preference selected on interactive map',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showChangeDeskSheet(data, studentData),
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                  label: const Text('Change Desk'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (isAuto) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300, width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚡ Auto-Assign Desk',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Approving will let you allocate any currently vacant desk in $sectionName.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Desk #$seatLabel',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 16, color: Color(0xFF15803D)),
                        const SizedBox(width: 6),
                        Text(
                          sectionName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isRequestedSeatOccupied)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Desk Collision Alert: Desk #$seatLabel is Occupied!',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This desk is currently allocated to ${_occupyingStudentName ?? "another enrolled student"}. Approving now will create an allocation conflict.',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showChangeDeskSheet(data, studentData),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                            label: const Text('Pick Another Desk'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _switchToAutoAssign(data, studentData),
                            icon: const Icon(Icons.bolt_rounded, size: 16),
                            label: const Text('Switch to Auto-Assign'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.blue),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ready to Allocate: Tapping "Approve" will automatically assign this desk to the student profile.',
                          style: TextStyle(fontSize: 11.5, color: Colors.blue, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDob(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return DateFormat('dd MMM yyyy').format(dt);
      }
      if (RegExp(r'^\d{2}[/\-.]\d{2}[/\-.]\d{4}$').hasMatch(s)) {
        final sep = s.contains('/') ? '/' : (s.contains('-') ? '-' : '.');
        final parts = s.split(sep);
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateFormat('dd MMM yyyy').format(DateTime(year, month, day));
        }
      }
    } catch (_) {}
    return s;
  }

  Future<void> _showChangePlanDialog(Map<String, dynamic> data, Map<String, dynamic> studentData) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final plans = ref.read(plansStreamProvider).value ?? [];
    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active membership plans found in library.')),
      );
      return;
    }

    final currentPlanId = (studentData['planId'] ?? data['planId'])?.toString();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day + 1;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.swap_horiz_rounded, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Change Study Plan & Shift', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a new plan. Pro-rata desk fee will be automatically calculated for the remaining $daysRemaining days of this month.',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final plan = plans[i];
                    final isSelected = plan.id == currentPlanId;
                    final double rawProrated = plan.price * (daysRemaining / daysInMonth);
                    final double proratedFee = ((rawProrated / 10).ceil() * 10).toDouble();

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = true);
                        try {
                          final updatedStudentData = Map<String, dynamic>.from(studentData);
                          updatedStudentData['planId'] = plan.id;
                          updatedStudentData['planName'] = plan.name;
                          updatedStudentData['planPrice'] = plan.price;
                          updatedStudentData['proratedFee'] = proratedFee;
                          updatedStudentData['isProrated'] = true;

                          await FirebaseFirestore.instance
                              .collection('libraries')
                              .doc(libraryId)
                              .collection('requests')
                              .doc(widget.requestId)
                              .set({
                            'planId': plan.id,
                            'planName': plan.name,
                            'planPrice': plan.price,
                            'originalPrice': plan.price,
                            'proratedFee': proratedFee,
                            'amount': proratedFee,
                            'studentData': updatedStudentData,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          if (mounted) {
                            await _loadRequest();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Plan changed to "${plan.name}" (₹${proratedFee.toStringAsFixed(0)} due at desk).'),
                                backgroundColor: const Color(0xFF16A34A),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(AppErrorFormatter.toUserFriendly(e, actionContext: 'request')),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? theme.colorScheme.primary : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected ? theme.colorScheme.primary : null,
                                    ),
                                  ),
                                  Text(
                                    'Standard: ₹${plan.price.toStringAsFixed(0)}/mo',
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '₹${proratedFee.toStringAsFixed(0)} Pro-rata',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _showChangeDeskSheet(Map<String, dynamic> data, Map<String, dynamic> studentData) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final sections = ref.read(sectionsProvider).value ?? [];
    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hall sections configured in library.')),
      );
      return;
    }

    final currentSeatId = (studentData['seatId'] ?? data['requestedSeatId'])?.toString();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        return DefaultTabController(
          length: sections.length,
          child: DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollCtrl) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.chair_alt_rounded, color: Colors.purple, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Assign Available Desk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.bolt_rounded, size: 16),
                          label: const Text('Auto-Assign'),
                          onPressed: () async {
                            Navigator.pop(sheetCtx);
                            await _saveDeskAssignment(
                              seatId: null,
                              seatLabel: 'Auto-Assign',
                              sectionId: sections.first.id,
                              sectionName: sections.first.name,
                              studentData: studentData,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    isScrollable: sections.length > 2,
                    tabs: sections.map((s) => Tab(text: s.name)).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: sections.map((sec) {
                        return Consumer(
                          builder: (context, ref, _) {
                            final seatsAsync = ref.watch(seatsProvider(sec.id));
                            return seatsAsync.when(
                              data: (seats) {
                                final available = seats.where((s) => s.status == SeatStatus.available).toList()
                                  ..sort(SeatHelper.compareSeats);
                                if (available.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.event_seat_rounded, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          Text('No available seats in ${sec.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return GridView.builder(
                                  controller: scrollCtrl,
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 80,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 1.0,
                                  ),
                                  itemCount: available.length,
                                  itemBuilder: (gridCtx, idx) {
                                    final seat = available[idx];
                                    final isChosen = currentSeatId == seat.id;

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        Navigator.pop(sheetCtx);
                                        await _saveDeskAssignment(
                                          seatId: seat.id,
                                          seatLabel: seat.label,
                                          sectionId: sec.id,
                                          sectionName: sec.name,
                                          studentData: studentData,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isChosen ? Colors.purple : const Color(0xFFD1FAE5),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isChosen ? Colors.purple : const Color(0xFF10B981),
                                            width: isChosen ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.chair_rounded,
                                              size: 20,
                                              color: isChosen ? Colors.white : const Color(0xFF065F46),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '#${seat.label}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: isChosen ? Colors.white : const Color(0xFF065F46),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('Error: $e')),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _saveDeskAssignment({
    required String? seatId,
    required String seatLabel,
    required String sectionId,
    required String sectionName,
    required Map<String, dynamic> studentData,
  }) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final updatedStudentData = Map<String, dynamic>.from(studentData);
      updatedStudentData['seatId'] = seatId;
      updatedStudentData['requestedSeatLabel'] = seatLabel;
      updatedStudentData['sectionId'] = sectionId;
      updatedStudentData['requestedSectionName'] = sectionName;

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(widget.requestId)
          .set({
        'requestedSeatId': seatId,
        'requestedSeatLabel': seatLabel,
        'requestedSectionId': sectionId,
        'requestedSectionName': sectionName,
        'studentData': updatedStudentData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        await _loadRequest();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(seatId != null
                  ? 'Desk assigned to Seat #$seatLabel ($sectionName).'
                  : 'Desk assignment set to Auto-Assign.'),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'request');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _switchToAutoAssign(Map<String, dynamic> data, Map<String, dynamic> studentData) async {
    final sections = ref.read(sectionsProvider).value ?? [];
    final firstSec = sections.isNotEmpty ? sections.first : null;
    await _saveDeskAssignment(
      seatId: null,
      seatLabel: 'Auto-Assign',
      sectionId: firstSec?.id ?? '',
      sectionName: firstSec?.name ?? 'Cozy Hall',
      studentData: studentData,
    );
  }

  Future<void> _showEditApplicantDialog(Map<String, dynamic> studentData) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    // Personal & Contact Controllers
    final nameCtrl = TextEditingController(text: (studentData['name'] ?? _requestData?['studentName'] ?? '').toString());
    final fatherCtrl = TextEditingController(text: (studentData['fatherName'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (studentData['phone'] ?? _requestData?['studentPhone'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (studentData['email'] ?? _requestData?['studentEmail'] ?? '').toString());
    final dobCtrl = TextEditingController(text: _formatDob(studentData['dob']));
    final addressCtrl = TextEditingController(text: (studentData['address'] ?? '').toString());
    final pincodeCtrl = TextEditingController(text: (studentData['pincode'] ?? '').toString());
    final emergencyCtrl = TextEditingController(text: (studentData['emergencyContact'] ?? '').toString());

    // Education & Goals Controllers
    final collegeCtrl = TextEditingController(text: (studentData['college'] ?? '').toString());
    final courseCtrl = TextEditingController(text: (studentData['course'] ?? '').toString());
    final yearCtrl = TextEditingController(text: (studentData['year'] ?? '').toString());
    final rollNoCtrl = TextEditingController(text: (studentData['rollNumber'] ?? '').toString());
    final examTargetCtrl = TextEditingController(text: (studentData['examTarget'] ?? '').toString());

    // Identity & Gov ID
    final govIdCtrl = TextEditingController(text: (studentData['govIdNumber'] ?? '').toString());

    String rawGender = (studentData['gender'] ?? 'male').toString().toLowerCase();
    String selectedGender = rawGender.contains('female') ? 'female' : (rawGender.contains('other') ? 'other' : 'male');
    String rawGovIdType = (studentData['govIdType'] ?? 'pan').toString().toLowerCase();
    String selectedGovIdType = ['aadhaar', 'pan', 'driving_license', 'voter_id', 'passport', 'other'].contains(rawGovIdType)
        ? rawGovIdType
        : 'pan';
    String? selectedBloodGroup = studentData['bloodGroup']?.toString();
    DateTime? pickedDob;

    // Document image states
    String? currentFrontUrl = (studentData['govIdImageUrl'] ?? studentData['govIdFrontUrl'] ?? _requestData?['govIdImageUrl'])?.toString();
    String? currentBackUrl = (studentData['govIdBackImageUrl'] ?? studentData['govIdBackUrl'] ?? _requestData?['govIdBackImageUrl'])?.toString();
    String? currentPhotoUrl = (studentData['photoUrl'] ?? _requestData?['photoUrl'])?.toString();

    bool isUploadingPhoto = false;
    bool isUploadingFront = false;
    bool isUploadingBack = false;

    final theme = Theme.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => DefaultTabController(
          length: 3,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.manage_accounts_rounded, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Applicant Verification Studio',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Review & correct any fields, replace blurry documents or capture student photo.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 540,
              child: Column(
                children: [
                  TabBar(
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: theme.colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(icon: Icon(Icons.person_rounded, size: 18), text: 'Personal & Contact'),
                      Tab(icon: Icon(Icons.school_rounded, size: 18), text: 'Education & Goals'),
                      Tab(icon: Icon(Icons.badge_rounded, size: 18), text: 'Gov ID & Photos'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // TAB 1: Personal & Contact
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 8, right: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name *',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: fatherCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Father / Guardian Name',
                                  prefixIcon: Icon(Icons.family_restroom_rounded),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedGender,
                                      decoration: const InputDecoration(
                                        labelText: 'Gender *',
                                        prefixIcon: Icon(Icons.people_outline_rounded),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'male', child: Text('Male')),
                                        DropdownMenuItem(value: 'female', child: Text('Female')),
                                        DropdownMenuItem(value: 'other', child: Text('Other')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setDialogState(() => selectedGender = v);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: ['A+', 'B+', 'O+', 'AB+', 'A-', 'B-', 'O-', 'AB-'].contains(selectedBloodGroup)
                                          ? selectedBloodGroup
                                          : null,
                                      decoration: const InputDecoration(
                                        labelText: 'Blood Group',
                                        prefixIcon: Icon(Icons.water_drop_outlined),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      hint: const Text('Select'),
                                      items: const [
                                        DropdownMenuItem(value: 'A+', child: Text('A+')),
                                        DropdownMenuItem(value: 'B+', child: Text('B+')),
                                        DropdownMenuItem(value: 'O+', child: Text('O+')),
                                        DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                                        DropdownMenuItem(value: 'A-', child: Text('A-')),
                                        DropdownMenuItem(value: 'B-', child: Text('B-')),
                                        DropdownMenuItem(value: 'O-', child: Text('O-')),
                                        DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                                      ],
                                      onChanged: (v) => setDialogState(() => selectedBloodGroup = v),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final initial = pickedDob ?? DateTime.tryParse(studentData['dob']?.toString() ?? '') ?? DateTime(2000, 1, 1);
                                  final selected = await showDatePicker(
                                    context: ctx,
                                    initialDate: initial.isBefore(now) ? initial : DateTime(2000, 1, 1),
                                    firstDate: DateTime(1940),
                                    lastDate: now,
                                  );
                                  if (selected != null) {
                                    setDialogState(() {
                                      pickedDob = selected;
                                      dobCtrl.text = DateFormat('dd MMM yyyy').format(selected);
                                    });
                                  }
                                },
                                child: AbsorbPointer(
                                  child: TextField(
                                    controller: dobCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Date of Birth',
                                      prefixIcon: Icon(Icons.cake_rounded),
                                      suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        labelText: 'Mobile Phone *',
                                        prefixIcon: Icon(Icons.phone_outlined),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: emergencyCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        labelText: 'Emergency Contact',
                                        prefixIcon: Icon(Icons.contact_phone_outlined),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: addressCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Residential Address',
                                        prefixIcon: Icon(Icons.home_outlined),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: pincodeCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Pincode',
                                        prefixIcon: Icon(Icons.pin_drop_outlined),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // TAB 2: Education & Goals
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 8, right: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: collegeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'College / Institute Name',
                                  prefixIcon: Icon(Icons.account_balance_outlined),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: courseCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Course / Degree',
                                        prefixIcon: Icon(Icons.menu_book_rounded),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: yearCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Year / Semester',
                                        prefixIcon: Icon(Icons.calendar_month_outlined),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: rollNoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Roll / Enrollment Number',
                                  prefixIcon: Icon(Icons.numbers_rounded),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: examTargetCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Target Exam / Competitive Goal',
                                  prefixIcon: Icon(Icons.flag_outlined),
                                  hintText: 'e.g. UPSC, MPSC, NEET, JEE, CA, Banking...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // TAB 3: Gov ID & Photos
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 8, right: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 150,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedGovIdType,
                                      decoration: const InputDecoration(
                                        labelText: 'Gov ID Type',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'aadhaar', child: Text('Aadhaar')),
                                        DropdownMenuItem(value: 'pan', child: Text('PAN Card')),
                                        DropdownMenuItem(value: 'driving_license', child: Text('License')),
                                        DropdownMenuItem(value: 'voter_id', child: Text('Voter ID')),
                                        DropdownMenuItem(value: 'passport', child: Text('Passport')),
                                        DropdownMenuItem(value: 'other', child: Text('Other')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setDialogState(() => selectedGovIdType = v);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: govIdCtrl,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: const InputDecoration(
                                        labelText: 'Gov ID Number',
                                        prefixIcon: Icon(Icons.badge_outlined),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Student Photo Section
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      backgroundImage: currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty
                                          ? ImageService.getImageProvider(currentPhotoUrl!)
                                          : null,
                                      child: isUploadingPhoto
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                          : (currentPhotoUrl == null || currentPhotoUrl!.isEmpty
                                              ? const Icon(Icons.person_rounded, size: 28)
                                              : null),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Student Profile Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(
                                            currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty
                                                ? 'Photo attached to student pass'
                                                : 'No photo uploaded yet',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: isUploadingPhoto
                                          ? null
                                          : () async {
                                              setDialogState(() => isUploadingPhoto = true);
                                              try {
                                                final url = await ImageService.pickAndUploadImage(
                                                  context: ctx,
                                                  folder: 'student_photos',
                                                  canRemove: currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty,
                                                );
                                                setDialogState(() => currentPhotoUrl = url);
                                              } catch (e) {
                                                if (ctx.mounted) {
                                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                                    SnackBar(content: Text('Upload failed: $e')),
                                                  );
                                                }
                                              } finally {
                                                setDialogState(() => isUploadingPhoto = false);
                                              }
                                            },
                                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                      label: Text(currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty ? 'Change' : 'Upload'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Gov ID Front Section
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade400),
                                        image: (currentFrontUrl != null && currentFrontUrl!.isNotEmpty && ImageService.getImageProvider(currentFrontUrl!) != null)
                                            ? DecorationImage(
                                                image: ImageService.getImageProvider(currentFrontUrl!)!,
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: isUploadingFront
                                          ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                          : (currentFrontUrl == null || currentFrontUrl!.isEmpty
                                              ? const Icon(Icons.credit_card_rounded, color: Colors.grey)
                                              : null),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Gov ID Front Side', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(
                                            currentFrontUrl != null && currentFrontUrl!.isNotEmpty ? 'Document verified & uploaded' : 'Missing front proof',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: isUploadingFront
                                          ? null
                                          : () async {
                                              setDialogState(() => isUploadingFront = true);
                                              try {
                                                final url = await ImageService.pickAndUploadImage(
                                                  context: ctx,
                                                  folder: 'requests_gov_ids',
                                                  canRemove: currentFrontUrl != null && currentFrontUrl!.isNotEmpty,
                                                );
                                                setDialogState(() => currentFrontUrl = url);
                                              } catch (e) {
                                                if (ctx.mounted) {
                                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                                    SnackBar(content: Text('Upload failed: $e')),
                                                  );
                                                }
                                              } finally {
                                                setDialogState(() => isUploadingFront = false);
                                              }
                                            },
                                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                                      label: Text(currentFrontUrl != null && currentFrontUrl!.isNotEmpty ? 'Replace' : 'Upload'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Gov ID Back Section
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade400),
                                        image: (currentBackUrl != null && currentBackUrl!.isNotEmpty && ImageService.getImageProvider(currentBackUrl!) != null)
                                            ? DecorationImage(
                                                image: ImageService.getImageProvider(currentBackUrl!)!,
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: isUploadingBack
                                          ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                          : (currentBackUrl == null || currentBackUrl!.isEmpty
                                              ? const Icon(Icons.flip_to_back_rounded, color: Colors.grey)
                                              : null),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Gov ID Back / Address Side', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(
                                            currentBackUrl != null && currentBackUrl!.isNotEmpty ? 'Address proof attached' : 'Optional back side',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: isUploadingBack
                                          ? null
                                          : () async {
                                              setDialogState(() => isUploadingBack = true);
                                              try {
                                                final url = await ImageService.pickAndUploadImage(
                                                  context: ctx,
                                                  folder: 'requests_gov_ids',
                                                  canRemove: currentBackUrl != null && currentBackUrl!.isNotEmpty,
                                                );
                                                setDialogState(() => currentBackUrl = url);
                                              } catch (e) {
                                                if (ctx.mounted) {
                                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                                    SnackBar(content: Text('Upload failed: $e')),
                                                  );
                                                }
                                              } finally {
                                                setDialogState(() => isUploadingBack = false);
                                              }
                                            },
                                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                                      label: Text(currentBackUrl != null && currentBackUrl!.isNotEmpty ? 'Replace' : 'Upload'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final newName = nameCtrl.text.trim();
                  final newFather = fatherCtrl.text.trim();
                  final newPhone = phoneCtrl.text.trim();
                  final newEmail = emailCtrl.text.trim();
                  final newAddress = addressCtrl.text.trim();
                  final newPincode = pincodeCtrl.text.trim();
                  final newEmergency = emergencyCtrl.text.trim();
                  final newCollege = collegeCtrl.text.trim();
                  final newCourse = courseCtrl.text.trim();
                  final newYear = yearCtrl.text.trim();
                  final newRollNo = rollNoCtrl.text.trim();
                  final newExamTarget = examTargetCtrl.text.trim();
                  final newGovId = govIdCtrl.text.trim().toUpperCase();
                  final newDob = pickedDob != null
                      ? pickedDob!.toIso8601String()
                      : (studentData['dob']?.toString() ?? dobCtrl.text.trim());

                  if (newName.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Full Name cannot be empty')),
                    );
                    return;
                  }

                  if (newPhone.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Mobile Phone cannot be empty')),
                    );
                    return;
                  }

                  Navigator.of(ctx).pop();

                  try {
                    final updatedStudentData = Map<String, dynamic>.from(studentData);
                    updatedStudentData['name'] = newName;
                    updatedStudentData['fatherName'] = newFather;
                    updatedStudentData['gender'] = selectedGender;
                    updatedStudentData['dob'] = newDob;
                    if (selectedBloodGroup != null) updatedStudentData['bloodGroup'] = selectedBloodGroup;
                    updatedStudentData['phone'] = newPhone;
                    updatedStudentData['email'] = newEmail;
                    updatedStudentData['address'] = newAddress;
                    updatedStudentData['pincode'] = newPincode;
                    updatedStudentData['emergencyContact'] = newEmergency;
                    updatedStudentData['college'] = newCollege;
                    updatedStudentData['course'] = newCourse;
                    updatedStudentData['year'] = newYear;
                    updatedStudentData['rollNumber'] = newRollNo;
                    updatedStudentData['examTarget'] = newExamTarget;
                    updatedStudentData['govIdType'] = selectedGovIdType;
                    updatedStudentData['govIdNumber'] = newGovId;
                    if (currentFrontUrl != null) updatedStudentData['govIdImageUrl'] = currentFrontUrl;
                    if (currentBackUrl != null) updatedStudentData['govIdBackImageUrl'] = currentBackUrl;
                    if (currentPhotoUrl != null) updatedStudentData['photoUrl'] = currentPhotoUrl;

                    await FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('requests')
                        .doc(widget.requestId)
                        .set({
                      'studentData': updatedStudentData,
                      'studentName': newName,
                      'studentPhone': newPhone,
                      'studentEmail': newEmail,
                      ...currentPhotoUrl != null ? {'photoUrl': currentPhotoUrl} : {},
                      ...currentFrontUrl != null ? {'govIdImageUrl': currentFrontUrl} : {},
                      ...currentBackUrl != null ? {'govIdBackImageUrl': currentBackUrl} : {},
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (mounted) {
                      await _loadRequest();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                                SizedBox(width: 8),
                                Text('Applicant details & documents updated successfully!'),
                              ],
                            ),
                            backgroundColor: Color(0xFF1E293B),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'request');
                    }
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicantBiodataCard({required ThemeData theme, required Map<String, dynamic> studentData}) {
    final govIdNum = studentData['govIdNumber']?.toString() ?? '';
    final govIdType = studentData['govIdType']?.toString() ?? 'Govt ID';
    final frontUrl = studentData['govIdImageUrl']?.toString() ?? '';
    final backUrl = studentData['govIdBackImageUrl']?.toString() ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.brown.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.badge_rounded, color: Colors.brown, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Applicant Biodata & Documents',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Full student profile details submitted via registration',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showEditApplicantDialog(studentData),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Edit Info'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Section 1: Personal & Guardian
            _buildSubheading('Personal & Guardian Details'),
            Builder(
              builder: (_) {
                final fn = (studentData['fatherName'] ?? '').toString().trim();
                return _buildRow("Father / Guardian", fn.isNotEmpty ? fn : "— (Not Provided)");
              },
            ),
            if (studentData['gender'] != null && studentData['gender'].toString().trim().isNotEmpty)
              _buildRow("Gender", studentData['gender'].toString().toUpperCase()),
            if (studentData['dob'] != null && studentData['dob'].toString().trim().isNotEmpty)
              _buildRow("Date of Birth", _formatDob(studentData['dob'])),
            if (studentData['bloodGroup'] != null && studentData['bloodGroup'].toString().trim().isNotEmpty)
              _buildRow("Blood Group", studentData['bloodGroup'].toString()),

            const SizedBox(height: 12),
            // Section 2: Contact & Residence
            _buildSubheading('Contact & Residence'),
            if (studentData['phone'] != null)
              _buildRow("Mobile Phone", studentData['phone'].toString()),
            if (studentData['email'] != null && studentData['email'].toString().isNotEmpty)
              _buildRow("Email Address", studentData['email'].toString()),
            if (studentData['address'] != null && studentData['address'].toString().isNotEmpty)
              _buildRow("Residential Address", studentData['address'].toString()),
            if (studentData['pincode'] != null && studentData['pincode'].toString().isNotEmpty)
              _buildRow("Pincode", studentData['pincode'].toString()),
            if (studentData['emergencyContact'] != null && studentData['emergencyContact'].toString().isNotEmpty)
              _buildRow("Emergency Contact", studentData['emergencyContact'].toString()),

            // Section 3: Education & Goals (Only rendered when at least one field has content)
            Builder(
              builder: (_) {
                final college = (studentData['college'] ?? '').toString().trim();
                final course = (studentData['course'] ?? '').toString().trim();
                final year = (studentData['year'] ?? '').toString().trim();
                final rollNumber = (studentData['rollNumber'] ?? '').toString().trim();
                final examTarget = (studentData['examTarget'] ?? '').toString().trim();
                final hasEducation = college.isNotEmpty ||
                    course.isNotEmpty ||
                    year.isNotEmpty ||
                    rollNumber.isNotEmpty ||
                    examTarget.isNotEmpty;
                if (!hasEducation) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildSubheading('Education & Target Goals'),
                    if (college.isNotEmpty) _buildRow("College / Institute", college),
                    if (course.isNotEmpty) _buildRow("Course / Degree", course),
                    if (year.isNotEmpty) _buildRow("Year / Semester", year),
                    if (rollNumber.isNotEmpty) _buildRow("Roll / Enroll Number", rollNumber),
                    if (examTarget.isNotEmpty) _buildRow("Target Exam", examTarget),
                  ],
                );
              },
            ),

            // Section 4: Govt ID & Documents
            if (govIdNum.isNotEmpty || frontUrl.isNotEmpty || backUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSubheading('Government ID & Documents'),
              if (govIdNum.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          govIdType,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              _showGovId ? govIdNum : (govIdNum.length > 4 ? '••••••${govIdNum.substring(govIdNum.length - 4)}' : '••••'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                            ),
                            IconButton(
                              icon: Icon(_showGovId ? Icons.visibility_off : Icons.visibility, size: 16),
                              onPressed: () => setState(() => _showGovId = !_showGovId),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (frontUrl.isNotEmpty || backUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    const Text(
                      'Government ID Documents',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        AdminDocumentStudioDialog.show(
                          context,
                          documentTitle: 'Govt ID Document Studio',
                          imageUrl: frontUrl.isNotEmpty ? frontUrl : backUrl,
                          backImageUrl: backUrl.isNotEmpty ? backUrl : null,
                          initialGovIdType: govIdType,
                          initialGovIdNumber: govIdNum,
                          libraryId: ref.read(currentLibraryIdProvider) ?? '',
                          requestId: widget.requestId,
                          onDocumentUpdated: _loadRequest,
                        );
                      },
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                      label: const Text('Open Document Studio', style: TextStyle(fontSize: 11.5)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (frontUrl.isNotEmpty)
                      Expanded(
                        child: _buildDocPreview(
                          title: 'Front ID (Tap to Inspect / Edit)',
                          imageUrl: frontUrl,
                          backUrl: backUrl,
                          govIdType: govIdType,
                          govIdNum: govIdNum,
                        ),
                      ),
                    if (frontUrl.isNotEmpty && backUrl.isNotEmpty)
                      const SizedBox(width: 12),
                    if (backUrl.isNotEmpty)
                      Expanded(
                        child: _buildDocPreview(
                          title: 'Back ID (Tap to Inspect / Edit)',
                          imageUrl: backUrl,
                          backUrl: backUrl,
                          govIdType: govIdType,
                          govIdNum: govIdNum,
                        ),
                      ),
                  ],
                ),
              ],
            ],

            // Section 5: Additional Information
            if (studentData['customFields'] is Map) ...[
              () {
                final cfMap = (studentData['customFields'] as Map)
                    .entries
                    .where((e) => !_isInternalKey(e.key.toString()) && e.value != null && e.value.toString().trim().isNotEmpty)
                    .toList();
                if (cfMap.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildSubheading('Additional Information'),
                    ...cfMap.map((e) => _buildRow(_formatFieldKey(e.key.toString()), e.value.toString())),
                  ],
                );
              }(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocPreview({
    required String title,
    required String imageUrl,
    String? backUrl,
    required String govIdType,
    required String govIdNum,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        AdminDocumentStudioDialog.show(
          context,
          documentTitle: title,
          imageUrl: imageUrl,
          backImageUrl: backUrl,
          initialGovIdType: govIdType,
          initialGovIdNumber: govIdNum,
          libraryId: ref.read(currentLibraryIdProvider) ?? '',
          requestId: widget.requestId,
          onDocumentUpdated: _loadRequest,
        );
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.black12,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: ImageService.buildImageWidget(
                  imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app_rounded, color: Colors.white70, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubheading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.4),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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

    final data = _requestData ?? {};
    final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};
    final effectivePlanId = planId ?? (studentData['planId'] ?? data['planId'])?.toString();

    double defaultAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    if (defaultAmount <= 0) {
      final proratedFee = (data['proratedFee'] as num?)?.toDouble() ??
          (studentData['proratedFee'] as num?)?.toDouble();
      if (proratedFee != null && proratedFee > 0) {
        defaultAmount = proratedFee;
      }
    }
    if (defaultAmount <= 0 && effectivePlanId != null && effectivePlanId.isNotEmpty) {
      final plans = ref.read(plansStreamProvider).value ?? [];
      final matchedPlan = plans.where((p) => p.id == effectivePlanId).firstOrNull;
      if (matchedPlan != null) {
        final smartCalc = PlanCalculatorService.calculateSmartPlan(plan: matchedPlan);
        defaultAmount = smartCalc.proratedPrice;
      }
    }

    final amountController = TextEditingController(
      text: defaultAmount > 0 ? defaultAmount.toStringAsFixed(0) : '',
    );

    final reqMethod = (data['paymentMethod'] ?? data['paymentModeLabel'] ?? '').toString().toLowerCase();
    String paymentMethod = 'Cash';
    if (reqMethod.contains('upi')) {
      paymentMethod = 'UPI';
    } else if (reqMethod.contains('bank')) {
      paymentMethod = 'Bank Transfer';
    } else if (reqMethod.contains('card')) {
      paymentMethod = 'Card';
    }

    final studentRef = (data['referenceNumber'] ?? '').toString().trim();

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
              if (studentRef.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Student Ref / UTR: $studentRef',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                  DropdownMenuItem(value: 'Card', child: Text('Debit/Credit Card')),
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
                DateTime? recordedEnd = planEndDate;
                if (amount > 0) {
                  recordedEnd = await _recordPaymentAndReceipt(
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
                  _offerWhatsAppWelcome(studentId, studentName, studentPhone, amount, paymentMethod, planEndDate: recordedEnd ?? planEndDate);
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

    final reqMethod = (_requestData?['paymentMethod'] ?? _requestData?['paymentModeLabel'] ?? '').toString().toLowerCase();
    String paymentMethod = 'UPI';
    if (reqMethod.contains('cash')) {
      paymentMethod = 'Cash';
    } else if (reqMethod.contains('bank')) {
      paymentMethod = 'Bank Transfer';
    } else if (reqMethod.contains('card')) {
      paymentMethod = 'Card';
    }

    final studentRef = (_requestData?['referenceNumber'] ?? '').toString().trim();

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
              if (studentRef.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tag_rounded, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Student Ref / UTR: $studentRef',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  DropdownMenuItem(value: 'Cash', child: Text('Cash at Desk')),
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
                DateTime? recordedEnd = planEndDate;
                if (amount > 0) {
                  recordedEnd = await _recordPaymentAndReceipt(
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
                if (mounted && studentPhone.isNotEmpty) {
                  _offerWhatsAppWelcome(studentId, studentName, studentPhone, amount, paymentMethod, planEndDate: recordedEnd ?? planEndDate);
                }
              },
              child: const Text('Record Payment & Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _recordPaymentAndReceipt(
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
      final receiptNum = 'REC${DateTime.now().year}${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';
      final receiptRef = FirebaseFirestore.instance.collection('libraries').doc(libraryId).collection('receipts').doc();

      final paymentRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('payments')
          .doc();

      final studentRef = (_requestData?['referenceNumber'] ?? '').toString().trim();

      final paymentData = {
        'id': paymentRef.id,
        'studentId': studentId,
        'amount': amount,
        'method': paymentMethod,
        'referenceNumber': studentRef.isNotEmpty ? studentRef : null,
        'status': 'paid',
        'date': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'recordedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
        'receiptId': receiptRef.id,
      };

      await paymentRef.set(paymentData);

      // Subcollection copy for backwards compatibility
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(studentId)
          .collection('payments')
          .doc(paymentRef.id)
          .set(paymentData);

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

      // Auto-seat allocation & retention engine upon renewal payment
      String? assignedSeatId;
      String? assignedSectionId;

      final bool retainSeatRequested = _requestData?['retainSeat'] ?? true;
      final requestedDesk = (_requestData?['currentSeatId'] ??
              _requestData?['requestedSeatId'] ??
              _requestData?['seatId'] ??
              (studentDoc.exists ? (studentDoc.data()?['seatId'] ?? studentDoc.data()?['previousSeatId']) : null))
          ?.toString();

      if (retainSeatRequested && requestedDesk != null && requestedDesk.trim().isNotEmpty) {
        String? targetSecId = (_requestData?['sectionId'] ??
                _requestData?['requestedSectionId'] ??
                (studentDoc.exists ? (studentDoc.data()?['sectionId'] ?? studentDoc.data()?['previousSectionId']) : null))
            ?.toString();

        try {
          if (targetSecId == null || targetSecId.trim().isEmpty) {
            final sectionsSnap = await FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('sections')
                .get();

            for (final sec in sectionsSnap.docs) {
              final seatSnap = await sec.reference.collection('seats').doc(requestedDesk).get();
              if (seatSnap.exists) {
                targetSecId = sec.id;
                break;
              }
            }
          }

          if (targetSecId != null && targetSecId.isNotEmpty) {
            final seatRef = FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('sections')
                .doc(targetSecId)
                .collection('seats')
                .doc(requestedDesk);

            final seatDoc = await seatRef.get();
            if (seatDoc.exists) {
              final seatData = seatDoc.data() ?? {};
              final occupant = (seatData['studentId'] ?? '').toString();
              final seatStatus = (seatData['status'] ?? 'available').toString();
              final resExpiresRaw = seatData['reservationExpiresAt'];
              DateTime? resExpires;
              if (resExpiresRaw is Timestamp) {
                resExpires = resExpiresRaw.toDate();
              } else if (resExpiresRaw is String) {
                resExpires = DateTime.tryParse(resExpiresRaw);
              }
              final isExpiredReservation = seatStatus == 'reserved' &&
                  (resExpires == null || resExpires.isBefore(DateTime.now()));

              if (occupant.isEmpty || occupant == studentId || seatStatus == 'available' || isExpiredReservation) {
                final seatRepo = ref.read(seatRepositoryProvider);
                await seatRepo.assignStudent(libraryId, targetSecId, requestedDesk, studentId);
                assignedSeatId = requestedDesk;
                assignedSectionId = targetSecId;
              }
            }
          }
        } catch (seatErr) {
          debugPrint('Error auto-retaining seat during renewal payment: $seatErr');
        }
      }

      // Activate the student upon recorded payment with seat restoration
      final Map<String, dynamic> studentUpdates = {
        'membershipStatus': MembershipStatus.active.name,
        'planStartDate': Timestamp.fromDate(effectiveStartDate),
        'planEndDate': Timestamp.fromDate(effectiveEndDate),
        if (effectivePlanId.isNotEmpty) 'planId': effectivePlanId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (assignedSeatId != null) {
        studentUpdates['seatId'] = assignedSeatId;
        studentUpdates['sectionId'] = assignedSectionId;
        studentUpdates['previousSeatId'] = assignedSeatId;
        studentUpdates['previousSectionId'] = assignedSectionId;
      } else if (requestedDesk != null && requestedDesk.trim().isNotEmpty) {
        studentUpdates['previousSeatId'] = requestedDesk;
        if (studentDoc.exists && studentDoc.data()?['previousSectionId'] != null) {
          studentUpdates['previousSectionId'] = studentDoc.data()?['previousSectionId'];
        }
      }

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(studentId)
          .update(studentUpdates);

      await receiptRef.set({
        'id': receiptRef.id,
        'receiptNumber': receiptNum,
        'studentId': studentId,
        'studentUserId': studentUserId,
        'studentName': studentName,
        'studentPhone': studentPhone,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'referenceNumber': studentRef.isNotEmpty ? studentRef : null,
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
          'referenceNumber': studentRef,
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
      return effectiveEndDate;
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'payment');
      }
      return planEndDate;
    }
  }

  String _formatFriendlySeatLabel(String? rawLabel, String? rawSeatId) {
    String label = (rawLabel ?? '').trim();
    if (label.isEmpty || label.toLowerCase() == 'null' || label.toLowerCase().contains('auto')) {
      if (rawSeatId != null && rawSeatId.isNotEmpty) {
        label = rawSeatId.trim();
      }
    }

    if (label.contains('_r') && label.contains('_c')) {
      // E.g. "1790647291016_r0_c6" -> row 0, col 6 -> Desk #7
      final colPart = label.split('_c').last;
      final colNum = int.tryParse(colPart);
      if (colNum != null) {
        return 'Desk #${colNum + 1}';
      }
    }

    if (label.isNotEmpty && !label.toLowerCase().startsWith('desk') && !label.toLowerCase().startsWith('seat')) {
      final isDigits = RegExp(r'^\d+$').hasMatch(label);
      if (isDigits) {
        return 'Desk #$label';
      }
    }

    return label.isNotEmpty ? label : 'To be assigned';
  }

  Future<void> _offerWhatsAppWelcome(
    String studentId,
    String studentName,
    String studentPhone,
    double amount,
    String paymentMethod, {
    DateTime? planEndDate,
  }) async {
    if (!mounted) return;

    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    LibraryModel? library = ref.read(currentLibraryProvider).value;

    // Guaranteed fallback if library provider was not yet loaded into memory
    if (library == null && libraryId.isNotEmpty) {
      try {
        final libDoc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).get();
        if (libDoc.exists && libDoc.data() != null) {
          library = LibraryModel.fromJson({...libDoc.data()!, 'id': libDoc.id});
        }
      } catch (_) {}
    }

    final data = _requestData ?? {};
    final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};

    // 1. Resolve student record from Firestore if available
    Map<String, dynamic> liveStudentData = {};
    if (libraryId.isNotEmpty && studentId.isNotEmpty) {
      try {
        final sDoc = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .doc(studentId)
            .get();
        if (sDoc.exists && sDoc.data() != null) {
          liveStudentData = sDoc.data()!;
        }
      } catch (_) {}
    }

    // 2. Resolve Admission / Member ID (prefer clean official membership number e.g. CC20260014)
    final membershipId = (liveStudentData['membershipNumber'] ??
            liveStudentData['rollNumber'] ??
            studentData['membershipNumber'] ??
            studentId)
        .toString();

    // 3. Resolve Human-Readable Seat Label (prevent raw Firestore database doc IDs)
    String? rawSeatLabel = (data['requestedSeatLabel'] ??
            studentData['requestedSeatLabel'] ??
            liveStudentData['seatNumber'] ??
            liveStudentData['seatLabel'] ??
            data['seatLabel'])
        ?.toString();
    final rawSeatId = (studentData['seatId'] ?? liveStudentData['seatId'] ?? data['requestedSeatId'])?.toString();
    final rawSecId = (studentData['sectionId'] ?? liveStudentData['sectionId'] ?? data['requestedSectionId'] ?? data['sectionId'])?.toString();

    if ((rawSeatLabel == null || rawSeatLabel.isEmpty || rawSeatLabel.contains('_r')) &&
        libraryId.isNotEmpty &&
        rawSeatId != null &&
        rawSeatId.isNotEmpty &&
        rawSecId != null &&
        rawSecId.isNotEmpty) {
      try {
        final seatDoc = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('sections')
            .doc(rawSecId)
            .collection('seats')
            .doc(rawSeatId)
            .get();
        if (seatDoc.exists && seatDoc.data() != null) {
          final sLabel = seatDoc.data()!['label']?.toString();
          if (sLabel != null && sLabel.isNotEmpty) {
            rawSeatLabel = sLabel;
          }
        }
      } catch (_) {}
    }
    final friendlySeatLabel = _formatFriendlySeatLabel(rawSeatLabel, rawSeatId);

    // 4. Resolve Plan Name
    final rawPlanId = (studentData['planId'] ?? liveStudentData['planId'] ?? data['planId'])?.toString();
    String resolvedPlanName = (liveStudentData['customPlanName'] ??
            data['planName'] ??
            studentData['planName'])
        ?.toString()
        .trim() ?? '';

    if (resolvedPlanName.isEmpty && rawPlanId != null && rawPlanId.isNotEmpty) {
      final plans = ref.read(plansStreamProvider).value ?? [];
      resolvedPlanName = plans.where((p) => p.id == rawPlanId).firstOrNull?.name ?? '';
      if (resolvedPlanName.isEmpty && libraryId.isNotEmpty) {
        try {
          final planDoc = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('plans')
              .doc(rawPlanId)
              .get();
          if (planDoc.exists && planDoc.data() != null) {
            resolvedPlanName = (planDoc.data()!['name'] ?? '').toString();
          }
        } catch (_) {}
      }
    }
    if (resolvedPlanName.isEmpty) {
      resolvedPlanName = 'Monthly Full-Day';
    }

    // 5. Resolve Expiry Date
    DateTime? effectiveEnd = planEndDate;
    if (effectiveEnd == null && liveStudentData['planEndDate'] != null) {
      effectiveEnd = StudentModel.parseDateStatic(liveStudentData['planEndDate']);
    }
    if (effectiveEnd == null && liveStudentData['validTo'] != null) {
      effectiveEnd = StudentModel.parseDateStatic(liveStudentData['validTo']);
    }
    effectiveEnd ??= DateTime.now().add(const Duration(days: 30));
    final formattedExpiry = DateFormat('dd MMM yyyy').format(effectiveEnd);

    // 6. Resolve Library Details
    final libraryName = (library?.name != null && library!.name.trim().isNotEmpty)
        ? library.name.trim()
        : 'The Cozy Corner Study Centre';
    final libraryAddress = (library?.address != null && library!.address.trim().isNotEmpty)
        ? library.address.trim()
        : 'Front Of Reliance Fashion Factory, Nath Road, Parli-431515';
    final libraryHelpline = (library?.helplineNumber != null && library!.helplineNumber.trim().isNotEmpty)
        ? library.helplineNumber.trim()
        : ((library?.contact != null && library!.contact.trim().isNotEmpty)
            ? library.contact.trim()
            : '9403243830');

    // 7. Dispatch via WhatsAppService with interactive preview sheet and clean UTF-8
    if (!mounted) return;
    await WhatsAppService().sendWelcomeMessage(
      studentPhone,
      studentName,
      libraryName,
      membershipId: membershipId,
      planName: resolvedPlanName,
      seatLabel: friendlySeatLabel,
      expiryDate: formattedExpiry,
      amount: amount > 0 ? amount.toStringAsFixed(0) : '0',
      paymentMethod: paymentMethod.isNotEmpty ? paymentMethod : 'Cash',
      libraryAddress: libraryAddress,
      libraryHelpline: libraryHelpline,
      adminTemplate: library?.whatsappWelcomeTemplate ?? '',
      context: context,
    );
  }

  static bool _isInternalKey(String key) {
    final k = key.trim().toLowerCase();
    return k.startsWith('_') ||
        const {
          'note',
          'notes',
          'originalrequestid',
          'requestid',
          'admissionrequestid',
          'shift',
          'shiftname',
          'studentuserid',
          'userid',
          'libraryid',
          'deletedat',
          'adminnotes',
          'isrefund',
          'planname',
          'planid',
          'customplanname',
          'systemaudit',
          'fcmtoken',
          'fcmtokens',
          'deviceinfo',
          'status',
          'type',
        }.contains(k);
  }

  static String _formatFieldKey(String key) {
    if (key.isEmpty) return key;
    final spaced = key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    if (spaced.isEmpty) return key;
    return spaced
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
