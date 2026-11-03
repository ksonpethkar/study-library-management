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
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/message_template_service.dart';
import 'package:intl/intl.dart';
import 'package:study_library/services/student_provisioning_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/error/error_handler.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';

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

        setState(() {
          _requestData = reqData;
          _liveStudent = liveStudent;
          _liveSeatLabel = liveSeatLabel;
          _liveSectionName = liveSectionName;
          _currentPlanName = currentPlanName;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
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
      final type = (data['type'] as String? ?? 'registration').toLowerCase();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
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

                      // 3. Requested Plan & Membership Cycle Card (For Renewals)
                      if (isRenewal) ...[
                        _buildRenewalPlanCard(theme: theme, data: data),
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
            : (type == 'profile_update' ? 'Profile Update' : 'New Registration'));

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
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
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
                          child: Image(
                            image: ImageService.getImageProvider(paymentProofUrl)!,
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
              ...((data['proposedData'] as Map)['customFields'] as Map).entries.map((e) {
                final curMap = (data['currentData'] as Map?)?['customFields'] as Map?;
                final curVal = curMap?[e.key];
                return _buildDiffRow(e.key.toString(), curVal, e.value);
              }),
            ],
          ],
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
              ],
            ),
            const Divider(height: 24),

            // Section 1: Personal & Guardian
            _buildSubheading('Personal & Guardian Details'),
            if (studentData['fatherName'] != null)
              _buildRow("Father / Guardian", studentData['fatherName'].toString()),
            if (studentData['gender'] != null)
              _buildRow("Gender", studentData['gender'].toString().toUpperCase()),
            if (studentData['dob'] != null)
              _buildRow("Date of Birth", studentData['dob'].toString()),
            if (studentData['bloodGroup'] != null && studentData['bloodGroup'].toString().isNotEmpty)
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

            const SizedBox(height: 12),
            // Section 3: Education & Goals
            _buildSubheading('Education & Target Goals'),
            if (studentData['college'] != null && studentData['college'].toString().isNotEmpty)
              _buildRow("College / Institute", studentData['college'].toString()),
            if (studentData['course'] != null && studentData['course'].toString().isNotEmpty)
              _buildRow("Course / Degree", studentData['course'].toString()),
            if (studentData['year'] != null && studentData['year'].toString().isNotEmpty)
              _buildRow("Year / Semester", studentData['year'].toString()),
            if (studentData['rollNumber'] != null && studentData['rollNumber'].toString().isNotEmpty)
              _buildRow("Roll / Enroll Number", studentData['rollNumber'].toString()),
            if (studentData['examTarget'] != null && studentData['examTarget'].toString().isNotEmpty)
              _buildRow("Target Exam", studentData['examTarget'].toString()),

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
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (frontUrl.isNotEmpty)
                      Expanded(
                        child: _buildDocPreview(title: 'Front ID', imageUrl: frontUrl),
                      ),
                    if (frontUrl.isNotEmpty && backUrl.isNotEmpty)
                      const SizedBox(width: 12),
                    if (backUrl.isNotEmpty)
                      Expanded(
                        child: _buildDocPreview(title: 'Back ID (Optional)', imageUrl: backUrl),
                      ),
                  ],
                ),
              ],
            ],

            // Section 5: Custom Fields
            if (studentData['customFields'] is Map && (studentData['customFields'] as Map).isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSubheading('Custom Information'),
              ...((studentData['customFields'] as Map).entries.map((e) {
                return _buildRow(e.key.toString(), e.value?.toString() ?? '—');
              })),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocPreview({required String title, required String imageUrl}) {
    return InkWell(
      onTap: () {
        ImageService.showImageViewer(
          context,
          imageUrl: imageUrl,
          title: title,
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
                child: Image(
                  image: ImageService.getImageProvider(imageUrl)!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

              if (occupant.isEmpty || occupant == studentId || seatStatus == 'available') {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment recording failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _offerWhatsAppWelcome(
    String studentId,
    String studentName,
    String studentPhone,
    double amount,
    String paymentMethod, {
    DateTime? planEndDate,
  }) {
    if (!mounted) return;

    final library = ref.read(currentLibraryProvider).value;
    final rawTemplate = library?.whatsappWelcomeTemplate ?? '';
    final template = rawTemplate.isNotEmpty ? rawTemplate : MessageTemplateService.defaultWelcomeTemplate;

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
