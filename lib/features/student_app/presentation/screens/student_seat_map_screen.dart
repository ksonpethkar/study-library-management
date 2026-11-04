import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class StudentSeatMapScreen extends ConsumerStatefulWidget {
  const StudentSeatMapScreen({super.key});

  @override
  ConsumerState<StudentSeatMapScreen> createState() => _StudentSeatMapScreenState();
}

class _StudentSeatMapScreenState extends ConsumerState<StudentSeatMapScreen> {
  String? _expandedSectionId;

  bool _isEligibleForGender(
    StudentModel student,
    SectionModel section,
    SeatModel seat,
  ) {
    final studentGender = student.gender;
    final sectionGender = (section.genderRestriction ?? 'any').toLowerCase().trim();
    final seatGender = seat.genderRestriction;

    if (studentGender == Gender.male) {
      // Male student cannot take female-only section or female-only seat
      if (sectionGender == 'female' || sectionGender == 'girls') return false;
      if (seatGender == GenderRestriction.female) return false;
      return true;
    } else if (studentGender == Gender.female) {
      // Female student cannot take male-only section or male-only seat
      if (sectionGender == 'male' || sectionGender == 'boys') return false;
      if (seatGender == GenderRestriction.male) return false;
      return true;
    }

    return true; // Gender.other or unisex
  }

  void _showGenderRestrictionNotice(
    BuildContext context,
    StudentModel student,
    SeatModel seat,
    SectionModel section,
  ) {
    HapticFeedback.lightImpact();
    final isMale = student.gender == Gender.male;
    final reservedFor = isMale ? 'Female / Girls' : 'Male / Boys';
    final allowedFor = isMale ? 'Male or Unisex' : 'Female or Unisex';
    final accentColor = isMale ? Colors.pink.shade700 : Colors.blue.shade700;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 28,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                child: Icon(Icons.lock_person_rounded, size: 30, color: accentColor),
              ),
              const SizedBox(height: 12),
              Text(
                'Reserved for $reservedFor',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Seat #${seat.label} in ${section.name} is reserved for $reservedFor students only.\n\n'
                'As a ${student.gender.name.toUpperCase()} student, you can only allocate or request $allowedFor seats.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Understood'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelPendingRequest(String libraryId, String requestId) async {
    HapticFeedback.mediumImpact();
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFFEE2E2),
                child: Icon(Icons.cancel_outlined, size: 30, color: Colors.red),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cancel Seat Change Request?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to cancel your pending seat change request? You will be able to select another available seat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cancel Request'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep Current Request'),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('requests')
            .doc(requestId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seat change request cancelled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
        }
      }
    }
  }

  void _showPendingWarning(
    BuildContext context,
    String libraryId,
    String requestId,
    Map<String, dynamic> pendingData,
  ) {
    HapticFeedback.lightImpact();
    final targetLabel = SeatHelper.formatSeatLabel(rawLabel: pendingData['targetSeatLabel'] as String?);
    final targetSec = pendingData['targetSectionName'] ?? 'Assigned Section';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 30),
              ),
              const SizedBox(height: 12),
              const Text(
                'Seat Change Already In Progress',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You already have an active request to move to $targetLabel in $targetSec.\n\n'
                'Please wait for library administration to review your request, or cancel it to pick another seat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Keep Current Request'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _cancelPendingRequest(libraryId, requestId);
                },
                child: const Text('Cancel & Pick New Seat'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthlyLimitDialog(
    BuildContext context,
    DateTime approvedDate,
    DateTime nextEligibleDate,
    String? contactPhone,
  ) {
    HapticFeedback.lightImpact();
    final dateFormat = DateFormat('dd MMM yyyy');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.calendar_month_rounded, color: Theme.of(context).colorScheme.primary, size: 30),
              ),
              const SizedBox(height: 12),
              const Text(
                'Monthly Seat Change Limit',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Library guidelines allow only 1 seat change per 30 days to avoid desk conflicts and ensure equal access.\n\n'
                '• Last seat change: ${dateFormat.format(approvedDate)}\n'
                '• Next eligible request: ${dateFormat.format(nextEligibleDate)}\n\n'
                'If you have an urgent necessity, please contact library reception.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Understood'),
              ),
              if (contactPhone != null && contactPhone.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: const Text('Call Reception'),
                  onPressed: () async {
                    final url = Uri.parse('tel:$contactPhone');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSeatChangeRequestSheet({
    required BuildContext context,
    required String libraryId,
    required StudentModel student,
    required SectionModel targetSection,
    required SeatModel targetSeat,
    required String currentSectionName,
  }) {
    HapticFeedback.mediumImpact();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            final theme = Theme.of(dialogCtx);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.swap_horiz_rounded, color: theme.colorScheme.primary, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                'Request Seat Change',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Seat Comparison Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            // Current Seat
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CURRENT SEAT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    student.seatId != null ? SeatHelper.formatSeatLabel(seatId: student.seatId) : 'None',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    currentSectionName,
                                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary),
                            // Target Seat
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'TARGET SEAT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    SeatHelper.formatSeatLabel(
                                      seatId: targetSeat.id,
                                      rawLabel: targetSeat.label,
                                      cols: targetSection.cols,
                                    ),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                  ),
                                  Text(
                                    targetSection.name,
                                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Reason for Change (Optional)',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Near power socket, quieter reading spot, closer to AC...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(isSubmitting ? 'Submitting...' : 'Submit Request to Admin'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() => isSubmitting = true);

                                  try {
                                    // Pre-submission server guard: Check if user already has an active pending request
                                    final curUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                                    final pendingCheck = await FirebaseFirestore.instance
                                        .collection('libraries')
                                        .doc(libraryId)
                                        .collection('requests')
                                        .where('userId', isEqualTo: curUid.isNotEmpty ? curUid : (student.userId ?? ''))
                                        .where('type', isEqualTo: 'seat_change')
                                        .where('status', isEqualTo: 'pending')
                                        .get();

                                    final activeDoc = pendingCheck.docs.where((d) {
                                      final dData = d.data();
                                      final sId = (dData['studentId'] ?? '').toString();
                                      final sUid = (dData['studentUserId'] ?? dData['userId'] ?? '').toString();
                                      final sEmail = (dData['studentEmail'] ?? '').toString().toLowerCase().trim();
                                      final curUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                                      final curEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';
                                      return (sId == student.id) ||
                                          (curUid.isNotEmpty && sUid == curUid) ||
                                          (curEmail.isNotEmpty && sEmail == curEmail);
                                    }).firstOrNull;

                                    if (activeDoc != null) {
                                      if (dialogCtx.mounted) {
                                        if (Navigator.of(dialogCtx, rootNavigator: true).canPop()) {
                                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                                        } else if (Navigator.of(dialogCtx).canPop()) {
                                          Navigator.of(dialogCtx).pop();
                                        }
                                      }
                                      if (mounted) {
                                        _showPendingWarning(this.context, libraryId, activeDoc.id, activeDoc.data());
                                      }
                                      return;
                                    }

                                    await FirebaseFirestore.instance
                                        .collection('libraries')
                                        .doc(libraryId)
                                        .collection('requests')
                                        .add({
                                      'type': 'seat_change',
                                      'status': 'pending',
                                      'studentId': student.id,
                                      'studentUserId': student.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
                                      'userId': FirebaseAuth.instance.currentUser?.uid ?? student.userId ?? '',
                                      'studentEmail': student.email,
                                      'studentName': student.name,
                                      'studentPhone': student.phone,
                                      'studentGender': student.gender.name,
                                      'currentSeatId': student.seatId ?? '',
                                      'currentSeatLabel': SeatHelper.formatSeatLabel(seatId: student.seatId, cols: targetSection.cols),
                                      'currentSectionId': student.sectionId ?? '',
                                      'currentSectionName': currentSectionName,
                                      'targetSeatId': targetSeat.id,
                                      'targetSeatLabel': SeatHelper.formatSeatLabel(rawLabel: targetSeat.label, includePrefix: false),
                                      'targetSectionId': targetSection.id,
                                      'targetSectionName': targetSection.name,
                                      'reason': reasonController.text.trim(),
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    // Dispatch admin in-app notification
                                    AppNotificationService.sendNotification(
                                      libraryId: libraryId,
                                      title: 'Seat Change Requested 🪑',
                                      body: '${student.name} requested desk change from Desk #${student.seatId ?? "None"} to Desk #${targetSeat.label}.',
                                      type: 'seat_change',
                                      targetRole: 'admin',
                                      actionRoute: Routes.adminRequests,
                                    ).ignore();

                                    // Industry Best Practice (Delta/BookMyShow/WeWork): Automatically close popup on submission success
                                    if (dialogCtx.mounted) {
                                      if (Navigator.of(dialogCtx, rootNavigator: true).canPop()) {
                                        Navigator.of(dialogCtx, rootNavigator: true).pop();
                                      } else if (Navigator.of(dialogCtx).canPop()) {
                                        Navigator.of(dialogCtx).pop();
                                      }
                                    }

                                    if (mounted) {
                                      HapticFeedback.heavyImpact();
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, color: Colors.white),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Seat change request for Desk #${targetSeat.label} submitted to management!',
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.green.shade700,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      AppErrorFormatter.showErrorSnackBar(this.context, e, actionContext: 'seat');
                                    }
                                  } finally {
                                    if (dialogCtx.mounted) {
                                      setSheetState(() => isSubmitting = false);
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final libraryId = ref.watch(currentLibraryIdProvider);
    final sectionsAsync = ref.watch(sectionsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.studentHome),
        ),
        title: const Text('Seat Map & Desk Change'),
        centerTitle: true,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null || libraryId == null || libraryId.isEmpty) {
            return const Center(child: Text('No student or library found.'));
          }

          return sectionsAsync.when(
            data: (sections) {
              if (sections.isEmpty) {
                return const Center(child: Text('No library sections configured.'));
              }

              // Determine current section name
              final currentSection = sections.where((s) => s.id == student.sectionId).firstOrNull;
              final currentSectionName = currentSection?.name ?? 'Assigned Section';

              // Expand first section or student's section by default
              _expandedSectionId ??= student.sectionId ?? sections.first.id;

              final curAuthUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final effectiveUserId = curAuthUid.isNotEmpty ? curAuthUid : (student.userId ?? '');

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: effectiveUserId.isEmpty
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('requests')
                        .where('userId', isEqualTo: effectiveUserId)
                        .where('type', isEqualTo: 'seat_change')
                        .snapshots(),
                builder: (context, reqSnap) {
                  final allReqDocs = reqSnap.data?.docs ?? [];
                  final myReqDocs = allReqDocs.where((d) {
                    final data = d.data();
                    final sId = (data['studentId'] ?? '').toString();
                    final sUid = (data['studentUserId'] ?? data['userId'] ?? '').toString();
                    final sEmail = (data['studentEmail'] ?? '').toString().toLowerCase().trim();
                    final sPhone = (data['studentPhone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
                    final myPhone = student.phone.replaceAll(RegExp(r'\D'), '');
                    final curUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    final curEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';
                    final myStudentUserId = (student.userId ?? '').toString();

                    if (sId == student.id) return true;
                    if (curUid.isNotEmpty && (sUid == curUid || sId == curUid)) return true;
                    if (myStudentUserId.isNotEmpty && (sUid == myStudentUserId || sId == myStudentUserId)) return true;
                    if (curEmail.isNotEmpty && sEmail.isNotEmpty && curEmail == sEmail) return true;
                    if (student.email.isNotEmpty && sEmail.isNotEmpty && student.email.toLowerCase().trim() == sEmail) return true;
                    if (myPhone.isNotEmpty && sPhone.isNotEmpty && (myPhone == sPhone || myPhone.endsWith(sPhone) || sPhone.endsWith(myPhone))) return true;
                    return false;
                  }).toList();

                  myReqDocs.sort((a, b) {
                    final tA = a.data()['createdAt'] as Timestamp?;
                    final tB = b.data()['createdAt'] as Timestamp?;
                    if (tA != null && tB != null) return tB.compareTo(tA);
                    return 0;
                  });

                  final pendingReqDoc = myReqDocs
                      .where((d) => (d.data()['status'] as String? ?? 'pending').toLowerCase() == 'pending')
                      .firstOrNull;
                  final lastApprovedDoc = myReqDocs
                      .where((d) => (d.data()['status'] as String? ?? '').toLowerCase() == 'approved')
                      .firstOrNull;

                  DateTime? approvedDate;
                  DateTime? nextEligibleDate;
                  bool isWithinMonth = false;
                  if (lastApprovedDoc != null) {
                    final approvedTs = lastApprovedDoc.data()['approvedAt'] as Timestamp? ??
                        lastApprovedDoc.data()['createdAt'] as Timestamp?;
                    approvedDate = approvedTs?.toDate();
                    if (approvedDate != null) {
                      final daysSinceApproved = DateTime.now().difference(approvedDate).inDays;
                      if (daysSinceApproved < 30) {
                        isWithinMonth = true;
                        nextEligibleDate = approvedDate.add(const Duration(days: 30));
                      }
                    }
                  }

                  final pendingData = pendingReqDoc?.data();
                  final pendingTargetLabel = pendingData?['targetSeatLabel'] as String?;
                  final pendingTargetSection = pendingData?['targetSectionName'] as String?;
                  final pendingReason = pendingData?['reason'] as String?;
                  final pendingCreated = (pendingData?['createdAt'] as Timestamp?)?.toDate();

                  final libraryAsync = ref.watch(currentLibraryProvider);
                  final library = libraryAsync.value;

                  return Column(
                    children: [
                      // Current Desk & Gender Info Banner
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  radius: 22,
                                  child: const Icon(Icons.event_seat_rounded, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            student.seatId != null
                                                ? 'Your Desk: ${SeatHelper.formatSeatLabel(seatId: student.seatId, cols: currentSection?.cols)}'
                                                : 'No Desk Assigned',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: student.gender == Gender.male
                                                  ? Colors.blue.shade100
                                                  : Colors.pink.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              student.gender == Gender.male ? '♂ MALE' : '♀ FEMALE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: student.gender == Gender.male
                                                    ? Colors.blue.shade900
                                                    : Colors.pink.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        student.seatId != null
                                            ? '$currentSectionName • Tap any available green seat below to request a change'
                                            : 'Browse sections and tap any available green seat to request allocation',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Interactive Legend Bar
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildLegendItem(
                                  context,
                                  const Color(0xFF7C3AED),
                                  'My Seat',
                                  icon: Icons.stars_rounded,
                                  tooltip: 'Your currently assigned library desk.',
                                ),
                                _buildLegendItem(
                                  context,
                                  const Color(0xFF10B981),
                                  'Available',
                                  icon: Icons.event_seat_rounded,
                                  tooltip: 'Vacant desk. Tap to request an instant desk change.',
                                ),
                                if (pendingReqDoc != null)
                                  _buildLegendItem(
                                    context,
                                    const Color(0xFFF59E0B),
                                    'Requested',
                                    icon: Icons.hourglass_top_rounded,
                                    tooltip: 'Awaiting administrator review.',
                                  ),
                                _buildLegendItem(
                                  context,
                                  Colors.grey.shade500,
                                  'Occupied',
                                  icon: Icons.person_rounded,
                                  tooltip: 'Currently assigned to another enrolled student.',
                                ),
                                _buildLegendItem(
                                  context,
                                  student.gender == Gender.male ? const Color(0xFFF472B6) : const Color(0xFF60A5FA),
                                  'Gender Locked',
                                  icon: Icons.lock_outline_rounded,
                                  tooltip: student.gender == Gender.male
                                      ? 'Reserved exclusively for female students.'
                                      : 'Reserved exclusively for male students.',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // In-Progress Seat Change Request Banner
                      if (pendingReqDoc != null) ...[
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB), // Amber 50
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309), size: 22),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Seat Change Request In Progress',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF78350F)),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDE68A),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'WAITING FOR ADMIN',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF78350F)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Requested Desk: ${SeatHelper.formatSeatLabel(rawLabel: pendingTargetLabel)} (${pendingTargetSection ?? "Selected Section"})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF92400E)),
                              ),
                              if (pendingReason != null && pendingReason.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Reason: "$pendingReason"',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                                ),
                              ],
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFFDE68A)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    pendingCreated != null
                                        ? 'Submitted: ${DateFormat("dd MMM, hh:mm a").format(pendingCreated)}'
                                        : 'Request submitted to admin',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: Colors.red.shade700,
                                    ),
                                    icon: const Icon(Icons.cancel_outlined, size: 16),
                                    label: const Text('Cancel Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () => _cancelPendingRequest(libraryId, pendingReqDoc.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else if (isWithinMonth) ...[
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Colors.blue.shade800, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Monthly Policy: 1 seat change allowed every 30 days. Last changed on ${DateFormat('dd MMM').format(approvedDate!)}. Next change eligible on ${DateFormat('dd MMM yyyy').format(nextEligibleDate!)}.',
                                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Section List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: sections.length,
                          itemBuilder: (context, index) {
                            final section = sections[index];
                            final isExpanded = _expandedSectionId == section.id;
                            final sectionColor = Color(section.color != 0 ? section.color : 0xFF5D4037);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              elevation: isExpanded ? 2 : 0.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isExpanded
                                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                                  width: isExpanded ? 1.5 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: ExpansionTile(
                                key: PageStorageKey('section_tile_${section.id}'),
                                initiallyExpanded: isExpanded,
                                onExpansionChanged: (expanded) {
                                  if (expanded) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _expandedSectionId = section.id);
                                  }
                                },
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: sectionColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 18),
                                ),
                                title: Row(
                                  children: [
                                    Text(section.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(width: 8),
                                    if (section.genderRestriction != null &&
                                        section.genderRestriction != 'any') ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: section.genderRestriction == 'female'
                                              ? Colors.pink.shade50
                                              : Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: section.genderRestriction == 'female'
                                                ? Colors.pink.shade300
                                                : Colors.blue.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          section.genderRestriction == 'female' ? 'Girls Only' : 'Boys Only',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: section.genderRestriction == 'female'
                                                ? Colors.pink.shade800
                                                : Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '${section.capacity} seats • Floor: ${section.floor ?? "Ground"}',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                                children: [
                                  if (isExpanded)
                                    _buildSectionSeatsGrid(
                                      context: context,
                                      theme: theme,
                                      libraryId: libraryId,
                                      student: student,
                                      section: section,
                                      currentSectionName: currentSectionName,
                                      pendingReqDoc: pendingReqDoc,
                                      pendingData: pendingData,
                                      isWithinMonth: isWithinMonth,
                                      approvedDate: approvedDate,
                                      nextEligibleDate: nextEligibleDate,
                                      contactPhone: library?.contact,
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  AppErrorFormatter.toUserFriendly(err, actionContext: 'section'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              AppErrorFormatter.toUserFriendly(err, actionContext: 'student'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    Color color,
    String label, {
    IconData? icon,
    String? tooltip,
  }) {
    return PressableScale(
      scaleFactor: 0.94,
      onTap: () {
        HapticFeedback.selectionClick();
        if (tooltip != null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(icon ?? Icons.info_outline_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tooltip,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 2200),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: icon != null ? Icon(icon, size: 10, color: Colors.white) : null,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSeatsGrid({
    required BuildContext context,
    required ThemeData theme,
    required String libraryId,
    required StudentModel student,
    required SectionModel section,
    required String currentSectionName,
    required DocumentSnapshot<Map<String, dynamic>>? pendingReqDoc,
    required Map<String, dynamic>? pendingData,
    required bool isWithinMonth,
    required DateTime? approvedDate,
    required DateTime? nextEligibleDate,
    required String? contactPhone,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('sections')
          .doc(section.id)
          .collection('seats')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('No seats created in this section yet.'),
          );
        }

        final seats = docs
            .map((d) => SeatModel.fromJson({...d.data(), 'id': d.id}))
            .where((s) => s.deletedAt == null)
            .toList();

        // Sort by row and col
        seats.sort((a, b) {
          final rowCmp = a.row.compareTo(b.row);
          if (rowCmp != 0) return rowCmp;
          return a.col.compareTo(b.col);
        });

        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = screenWidth > 800 ? 8 : (screenWidth > 500 ? 6 : (screenWidth < 440 ? 3 : 4));

        return Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.pinch_rounded, size: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Pinch to zoom & inspect desks',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InteractiveViewer(
                minScale: 0.65,
                maxScale: 2.8,
                clipBehavior: Clip.none,
                boundaryMargin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: SizedBox(
                  width: math.max(screenWidth - 32, crossAxisCount * 54.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: GridView.builder(
              key: ValueKey('grid_${section.id}_${seats.length}'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: seats.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: screenWidth < 440 ? 1.08 : 1.0,
              ),
              itemBuilder: (context, sIndex) {
                final seat = seats[sIndex];

                final isMySeat = seat.id == student.seatId ||
                    (student.seatId != null && seat.label == student.seatId);

                final seatFormatted = SeatHelper.formatSeatLabel(
                  seatId: seat.id,
                  rawLabel: seat.label,
                  cols: section.cols,
                  includePrefix: false,
                );
                final pendingTargetFormatted = SeatHelper.formatSeatLabel(
                  rawLabel: pendingData?['targetSeatLabel'] as String?,
                  includePrefix: false,
                );
                final isPendingTarget = pendingData != null &&
                    (seat.id == pendingData['targetSeatId'] ||
                        (pendingTargetFormatted.isNotEmpty && seatFormatted == pendingTargetFormatted));

                final isOccupied = !isMySeat && !isPendingTarget &&
                    (seat.status == SeatStatus.occupied ||
                        (seat.studentId != null && seat.studentId!.isNotEmpty));

                final isMaintenance = seat.status == SeatStatus.maintenance;

                final isGenderAllowed = _isEligibleForGender(student, section, seat);

                return RepaintBoundary(
                  key: ValueKey(seat.id),
                  child: _StudentSeatTile(
                    seat: seat,
                    isMySeat: isMySeat,
                    isPendingTarget: isPendingTarget,
                    isOccupied: isOccupied,
                    isMaintenance: isMaintenance,
                    isGenderAllowed: isGenderAllowed,
                    student: student,
                    section: section,
                    onTap: () {
                      if (isMySeat) {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Text('${SeatHelper.formatSeatLabel(rawLabel: seat.label)} is your currently assigned desk!'),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else if (isPendingTarget || pendingReqDoc != null) {
                        HapticFeedback.lightImpact();
                        _showPendingWarning(context, libraryId, pendingReqDoc!.id, pendingData!);
                      } else if (isWithinMonth) {
                        HapticFeedback.lightImpact();
                        _showMonthlyLimitDialog(context, approvedDate!, nextEligibleDate!, contactPhone);
                      } else if (isOccupied) {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.person_rounded, color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                Text('${SeatHelper.formatSeatLabel(rawLabel: seat.label)} is currently occupied by another student.'),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else if (isMaintenance) {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.build_rounded, color: Colors.amber, size: 18),
                                const SizedBox(width: 8),
                                Text('${SeatHelper.formatSeatLabel(rawLabel: seat.label)} is currently under maintenance.'),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else if (!isGenderAllowed) {
                        HapticFeedback.lightImpact();
                        _showGenderRestrictionNotice(context, student, seat, section);
                      } else {
                        // Available & Gender-compliant -> open seat change sheet!
                        HapticFeedback.selectionClick();
                        _showSeatChangeRequestSheet(
                          context: context,
                          libraryId: libraryId,
                          student: student,
                          targetSection: section,
                          targetSeat: seat,
                          currentSectionName: currentSectionName,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ],
    ),
  );
},
    );
  }
}

class _StudentSeatTile extends StatelessWidget {
  final SeatModel seat;
  final bool isMySeat;
  final bool isPendingTarget;
  final bool isOccupied;
  final bool isMaintenance;
  final bool isGenderAllowed;
  final StudentModel student;
  final SectionModel section;
  final VoidCallback onTap;

  const _StudentSeatTile({
    required this.seat,
    required this.isMySeat,
    required this.isPendingTarget,
    required this.isOccupied,
    required this.isMaintenance,
    required this.isGenderAllowed,
    required this.student,
    required this.section,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMaleStudent = student.gender == Gender.male;

    // Visual styling palette
    Gradient? gradient;
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    List<BoxShadow>? shadows;
    double borderWidth = 1.0;

    if (isMySeat) {
      gradient = const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      bgColor = const Color(0xFF7C3AED);
      borderColor = const Color(0xFFC4B5FD);
      borderWidth = 1.8;
      textColor = Colors.white;
      icon = Icons.stars_rounded;
      shadows = [
        BoxShadow(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
          blurRadius: 8,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isPendingTarget) {
      gradient = const LinearGradient(
        colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFF59E0B);
      borderWidth = 1.8;
      textColor = const Color(0xFF92400E);
      icon = Icons.hourglass_top_rounded;
      shadows = [
        BoxShadow(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isOccupied) {
      bgColor = isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6);
      borderColor = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB);
      textColor = isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF);
      icon = Icons.person_rounded;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 2,
        ),
      ];
    } else if (isMaintenance) {
      gradient = const LinearGradient(
        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFD97706);
      borderWidth = 1.2;
      textColor = const Color(0xFFB45309);
      icon = Icons.build_rounded;
    } else if (!isGenderAllowed) {
      // Gender restricted
      gradient = LinearGradient(
        colors: isMaleStudent
            ? const [Color(0xFFFDF2F8), Color(0xFFFCE7F3)]
            : const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      bgColor = isMaleStudent ? const Color(0xFFFDF2F8) : const Color(0xFFEFF6FF);
      borderColor = isMaleStudent ? const Color(0xFFF472B6) : const Color(0xFF60A5FA);
      borderWidth = 1.2;
      textColor = isMaleStudent ? const Color(0xFFBE185D) : const Color(0xFF1D4ED8);
      icon = Icons.lock_outline_rounded;
    } else {
      // Available & Eligible
      gradient = const LinearGradient(
        colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      bgColor = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFF10B981);
      borderWidth = 1.2;
      textColor = const Color(0xFF065F46);
      icon = Icons.event_seat_rounded;
      shadows = [
        BoxShadow(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    }

    final seatLabel = SeatHelper.formatSeatLabel(
      seatId: seat.id,
      rawLabel: seat.label,
      cols: section.cols,
      includePrefix: false,
    );

    return PressableScale(
      scaleFactor: 0.92,
      duration: const Duration(milliseconds: 90),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: gradient == null ? bgColor : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadows,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top Right Pill / Indicator for Special States
            if (isMySeat)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6D28D9),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              )
            else if (isPendingTarget)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'REQ',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              )
            else if (!isGenderAllowed)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  isMaleStudent ? Icons.female_rounded : Icons.male_rounded,
                  size: 11,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),

            // Center Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: textColor),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    seatLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      color: textColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
