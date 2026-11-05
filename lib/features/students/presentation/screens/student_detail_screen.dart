import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/payments/presentation/screens/record_payment_screen.dart';
import 'package:study_library/features/payments/presentation/screens/edit_payment_screen.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:study_library/features/id_cards/presentation/screens/id_card_preview_screen.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/payment_model.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:flutter/services.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:study_library/services/soundbox_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/services/sms_service.dart';
import 'package:study_library/services/telegram_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/services/messaging_hub_service.dart';
import 'package:study_library/features/receipts/presentation/screens/receipt_preview_screen.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';
import 'package:study_library/features/requests/presentation/widgets/admin_document_studio_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/services/waiting_list_promotion_service.dart';
import 'package:study_library/models/waiting_list_model.dart';

class StudentDetailScreen extends ConsumerStatefulWidget {
  final String studentId;
  final bool isEmbeddedInSplitView;

  const StudentDetailScreen({
    super.key,
    required this.studentId,
    this.isEmbeddedInSplitView = false,
  });

  @override
  ConsumerState<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> with SecureScreenMixin {
  StudentModel? student;
  bool isLoading = true;
  bool _isGovIdVisible = false;
  String seatLabel = '';
  String sectionName = '';
  String planName = '';
  double planPrice = 0;

  @override
  void initState() {
    super.initState();
    final initialLibId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    _loadStudent(overrideLibId: initialLibId);
  }

  Future<void> _loadStudent({String? overrideLibId}) async {
    final libraryId = overrideLibId ?? ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    if (libraryId.isEmpty || widget.studentId.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawGovId = data['govIdNumber']?.toString() ?? '';
        final decryptedGovId = EncryptionService.safeDecryptGovId(rawGovId, libraryId);
        final s = StudentModel.fromJson({
          ...data,
          'id': doc.id,
          'govIdNumber': decryptedGovId,
        });
        
        // Load seat + section names safely
        String loadedSeatLabel = '';
        String loadedSectionName = '';
        if (s.seatId != null && s.seatId!.isNotEmpty) {
          String? effectiveSectionId = s.sectionId;
          if (effectiveSectionId == null || effectiveSectionId.isEmpty) {
            try {
              final secSnap = await FirebaseFirestore.instance
                  .collection('libraries').doc(libraryId)
                  .collection('sections').get();
              for (final sec in secSnap.docs) {
                final seatDoc = await sec.reference.collection('seats').doc(s.seatId).get();
                if (seatDoc.exists) {
                  effectiveSectionId = sec.id;
                  loadedSectionName = sec.data()['name'] ?? 'Section';
                  loadedSeatLabel = seatDoc.data()?['label'] ?? 'Seat';
                  doc.reference.update({'sectionId': effectiveSectionId}).ignore();
                  break;
                }
              }
            } catch (_) {}
          } else {
            try {
              final sectionDoc = await FirebaseFirestore.instance
                  .collection('libraries').doc(libraryId)
                  .collection('sections').doc(effectiveSectionId)
                  .get();
              if (sectionDoc.exists) {
                loadedSectionName = sectionDoc.data()?['name'] ?? 'Unknown Section';
              }
            } catch (_) {}
            
            try {
              final seatDoc = await FirebaseFirestore.instance
                  .collection('libraries').doc(libraryId)
                  .collection('sections').doc(effectiveSectionId)
                  .collection('seats').doc(s.seatId)
                  .get();
              if (seatDoc.exists) {
                loadedSeatLabel = seatDoc.data()?['label'] ?? 'Unknown Seat';
              }
            } catch (_) {}
          }
        }

        // Load plan name safely
        String loadedPlanName = '';
        double loadedPlanPrice = 0;
        if (s.planId != null && s.planId!.isNotEmpty) {
          if (s.planId == 'custom') {
            loadedPlanName = s.customPlanName?.isNotEmpty == true ? s.customPlanName! : 'Custom Plan';
            loadedPlanPrice = s.customPlanFee ?? 0;
          } else {
            try {
              final planDoc = await FirebaseFirestore.instance
                  .collection('libraries').doc(libraryId)
                  .collection('plans').doc(s.planId)
                  .get();
              if (planDoc.exists) {
                loadedPlanName = planDoc.data()?['name'] ?? 'Unknown Plan';
                loadedPlanPrice = (planDoc.data()?['price'] ?? 0).toDouble();
              }
            } catch (_) {}
          }
        }

        if (mounted) {
          setState(() {
            student = s;
            seatLabel = loadedSeatLabel;
            sectionName = loadedSectionName;
            planName = loadedPlanName;
            planPrice = loadedPlanPrice;
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading student: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Color _getStatusColor(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.active:
        return Colors.green;
      case MembershipStatus.expired:
      case MembershipStatus.blocked:
        return Colors.red;
      case MembershipStatus.grace:
        return Colors.orange;
      case MembershipStatus.pending:
        return Colors.blue;
      case MembershipStatus.inactive:
      case MembershipStatus.archived:
        return Colors.grey;
    }
  }

  void _showWhatsAppSheet(BuildContext context, StudentModel s) {
    final library = ref.read(currentLibraryProvider).value;
    final libraryName = library?.name ?? '';
    final whatsapp = ref.read(whatsappServiceProvider);

    final daysLeft = s.planEndDate?.difference(DateTime.now()).inDays;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                  const SizedBox(width: 8),
                  Text('WhatsApp: ${s.name}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCF8C6),
                child: Icon(Icons.waving_hand_rounded, color: Color(0xFF25D366)),
              ),
              title: const Text('Send Welcome Message'),
              subtitle: const Text('Greet new member with library details'),
              onTap: () {
                Navigator.pop(ctx);
                whatsapp.sendWelcomeMessage(
                  s.phone,
                  s.name,
                  libraryName,
                  adminTemplate: library?.effectiveWelcomeTemplate ?? '',
                  membershipId: s.id,
                  planName: s.planId ?? '',
                  seatLabel: seatLabel,
                  expiryDate: s.planEndDate != null ? DateFormat('dd MMM yyyy').format(s.planEndDate!) : '',
                  libraryAddress: library?.address ?? '',
                  libraryHelpline: library?.phone ?? '',
                  context: context,
                );
              },
            ),
            if (daysLeft != null)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3CD),
                  child: Icon(Icons.schedule_rounded, color: Colors.orange),
                ),
                title: Text(daysLeft >= 0
                    ? 'Send Renewal Reminder ($daysLeft days left)'
                    : 'Send Expired Notice'),
                subtitle: const Text('Notify student about plan status'),
                onTap: () {
                  Navigator.pop(ctx);
                  whatsapp.sendExpiryReminder(
                    s.phone,
                    s.name,
                    daysLeft,
                    libraryName: libraryName,
                    seatLabel: seatLabel,
                    expiryDate: s.planEndDate != null ? DateFormat('dd MMM yyyy').format(s.planEndDate!) : null,
                    libraryHelpline: library?.phone,
                    libraryUpiId: library?.upiId,
                    adminTemplate: library?.effectiveExpiryReminderTemplate,
                    context: context,
                  );
                },
              ),
            if (seatLabel.isNotEmpty)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.chair_rounded, color: Colors.green),
                ),
                title: const Text('Send Seat Assignment Info'),
                subtitle: Text('Section: $sectionName · Seat: $seatLabel'),
                onTap: () {
                  Navigator.pop(ctx);
                  whatsapp.sendSeatAssigned(s.phone, s.name, seatLabel, sectionName, libraryName: libraryName, context: context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _assignSequentialId(StudentModel s) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Membership ID'),
        content: Text('Generate and assign the next sequential membership ID to ${s.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final nextId = await ref.read(studentRepositoryProvider).assignSequentialId(libraryId, s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned ID: $nextId'), backgroundColor: Colors.green),
      );
      _loadStudent();
    } catch (e) {
      if (!mounted) return;
      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'student');
    }
  }

  void _showAssignSeatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final sectionsAsync = ref.watch(sectionsProvider);
                return sectionsAsync.when(
                  data: (sections) {
                    if (sections.isEmpty) {
                      return const Center(child: Text('No sections available'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return _SectionItem(
                          section: section,
                          studentId: widget.studentId,
                          onSeatAssigned: () {
                            Navigator.pop(context);
                            _loadStudent(); // Reload student data
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openRenewalFlow(BuildContext context, StudentModel s, double planPrice) {
    final due = s.pendingDueBalance ?? 0.0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordPaymentScreen(
          studentId: widget.studentId,
          studentName: s.name,
          studentPhone: s.phone,
          planPrice: planPrice > 0 ? planPrice : (due > 0 ? due : 0.0),
          pendingDue: due,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _loadStudent();
      }
    });
  }

  Future<void> _showFreezeMembershipDialog(BuildContext context, StudentModel s) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    if (s.planEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student has no active plan to freeze.')),
      );
      return;
    }

    final origEnd = s.planEndDate!;
    final now = DateTime.now();
    DateTime freezeStart = DateTime(now.year, now.month, now.day);
    // Minimum 10 consecutive days
    DateTime freezeEnd = freezeStart.add(const Duration(days: 9));
    final reasonCtrl = TextEditingController(text: 'University semester exams / Study vacation');
    bool sendWhatsApp = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final theme = Theme.of(context);
          final freezeCalc = PlanCalculatorService.calculateMembershipFreeze(
            student: s,
            freezeStartDate: freezeStart,
            freezeEndDate: freezeEnd,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.ac_unit_rounded, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Freeze Membership (10+ Days)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Approve a study vacation / exam break. Per library policy, freeze is permitted for 10 or more consecutive days only.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Original Plan Expiry:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(DateFormat('dd MMM yyyy').format(origEnd), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: freezeStart,
                                      firstDate: DateTime(now.year, now.month - 1),
                                      lastDate: origEnd.add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDlgState(() {
                                        freezeStart = picked;
                                        if (freezeEnd.isBefore(freezeStart)) {
                                          freezeEnd = freezeStart.add(const Duration(days: 9));
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Freeze Start', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                        Text(DateFormat('dd MMM yyyy').format(freezeStart), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: freezeEnd,
                                      firstDate: freezeStart,
                                      lastDate: origEnd.add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDlgState(() => freezeEnd = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Freeze End', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                        Text(DateFormat('dd MMM yyyy').format(freezeEnd), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Chip(
                              label: Text('${freezeCalc.freezeDays} Days Selected'),
                              backgroundColor: freezeCalc.isValid ? Colors.blue.shade50 : Colors.red.shade50,
                              labelStyle: TextStyle(
                                color: freezeCalc.isValid ? Colors.blue.shade900 : Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        labelText: 'Reason / Notes',
                        hintText: 'e.g. University practicals / visiting hometown',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: freezeCalc.isValid ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: freezeCalc.isValid ? Colors.green.shade300 : Colors.red.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            freezeCalc.isValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                            color: freezeCalc.isValid ? Colors.green.shade700 : Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              freezeCalc.message,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: freezeCalc.isValid ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: sendWhatsApp,
                      onChanged: (val) => setDlgState(() => sendWhatsApp = val ?? true),
                      title: const Text('Send WhatsApp freeze confirmation', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Dispatches itemized vacation dates and extended expiry.', style: TextStyle(fontSize: 11)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                icon: const Icon(Icons.ac_unit_rounded, size: 16),
                label: const Text('Confirm Freeze & Extend'),
                onPressed: !freezeCalc.isValid
                    ? null
                    : () async {
                        try {
                          final batch = FirebaseFirestore.instance.batch();
                          final studentRef = FirebaseFirestore.instance
                              .collection('libraries')
                              .doc(libraryId)
                              .collection('students')
                              .doc(s.id);

                          batch.update(studentRef, {
                            'isFrozen': true,
                            'freezeStartDate': Timestamp.fromDate(freezeStart),
                            'freezeEndDate': Timestamp.fromDate(freezeEnd),
                            'freezeReason': reasonCtrl.text.trim(),
                            'planEndDate': Timestamp.fromDate(freezeCalc.newEndDate),
                            'notes': '${(s.notes != null && s.notes!.isNotEmpty) ? "${s.notes}\n" : ""}[Freeze] Study Vacation: ${freezeCalc.freezeDays}d (${DateFormat('dd MMM').format(freezeStart)} - ${DateFormat('dd MMM').format(freezeEnd)}). Expiry extended to ${DateFormat('dd MMM yyyy').format(freezeCalc.newEndDate)}.',
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          // Update assigned seat reservationType to 'study_leave' so Seat Map badges in Amber
                          if (s.seatId != null && s.sectionId != null) {
                            final seatRef = FirebaseFirestore.instance
                                .collection('libraries')
                                .doc(libraryId)
                                .collection('sections')
                                .doc(s.sectionId!)
                                .collection('seats')
                                .doc(s.seatId!);
                            batch.update(seatRef, {
                              'reservationType': 'study_leave',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          }

                          await batch.commit();

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            final seatLabel = SeatHelper.formatSeatLabel(
                              seatId: s.seatId,
                              rawLabel: s.seatId,
                            );
                            final libName = ref.read(currentLibraryProvider).value?.name ?? 'Study Library';
                            final helpline = ref.read(currentLibraryProvider).value?.helplineNumber;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Membership freeze applied ✓ Plan extended to ${DateFormat('dd MMM yyyy').format(freezeCalc.newEndDate)}'),
                                backgroundColor: Colors.green,
                                action: SnackBarAction(
                                  label: 'WhatsApp Notice',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    ref.read(whatsappServiceProvider).sendMembershipFreezeNotice(
                                      phone: s.phone,
                                      studentName: s.name,
                                      libraryName: libName,
                                      freezeDays: freezeCalc.freezeDays,
                                      freezeStartDate: freezeStart,
                                      freezeEndDate: freezeEnd,
                                      newExpiryDate: freezeCalc.newEndDate,
                                      seatLabel: seatLabel,
                                      reason: reasonCtrl.text.trim(),
                                      libraryHelpline: helpline,
                                      context: context,
                                    );
                                  },
                                ),
                              ),
                            );

                            if (sendWhatsApp) {
                              ref.read(whatsappServiceProvider).sendMembershipFreezeNotice(
                                phone: s.phone,
                                studentName: s.name,
                                libraryName: libName,
                                freezeDays: freezeCalc.freezeDays,
                                freezeStartDate: freezeStart,
                                freezeEndDate: freezeEnd,
                                newExpiryDate: freezeCalc.newEndDate,
                                seatLabel: seatLabel,
                                reason: reasonCtrl.text.trim(),
                                libraryHelpline: helpline,
                                context: context,
                              );
                            }

                            _loadStudent();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'student');
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showUnfreezeMembershipDialog(BuildContext context, StudentModel s) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentEnd = s.planEndDate ?? today;
    bool sendWhatsApp = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final theme = Theme.of(context);
          final seatLabel = SeatHelper.formatSeatLabel(
            seatId: s.seatId,
            rawLabel: s.seatId,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.shade50,
                  child: const Icon(Icons.wb_sunny_rounded, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Resume Pass / Unfreeze', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reactivate ${s.name}\'s membership pass today. This will restore the desk status from Study Leave back to Active.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Reserved Desk:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(seatLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Current Expiry:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(DateFormat('dd MMM yyyy').format(currentEnd), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: sendWhatsApp,
                      onChanged: (val) => setDlgState(() => sendWhatsApp = val ?? true),
                      title: const Text('Send WhatsApp Welcome Back notice', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Sends a confirmation message to student that their pass and desk are active.', style: TextStyle(fontSize: 11)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                icon: const Icon(Icons.wb_sunny_rounded, size: 16),
                label: const Text('Confirm & Reactivate Pass'),
                onPressed: () async {
                  try {
                    final batch = FirebaseFirestore.instance.batch();
                    final studentRef = FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('students')
                        .doc(s.id);

                    batch.update(studentRef, {
                      'isFrozen': false,
                      'freezeStartDate': FieldValue.delete(),
                      'freezeEndDate': FieldValue.delete(),
                      'freezeReason': FieldValue.delete(),
                      'notes': '${(s.notes != null && s.notes!.isNotEmpty) ? "${s.notes}\n" : ""}[Unfreeze] Resumed from study leave on ${DateFormat('dd MMM yyyy').format(today)}.',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (s.seatId != null && s.sectionId != null) {
                      final seatRef = FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('sections')
                          .doc(s.sectionId!)
                          .collection('seats')
                          .doc(s.seatId!);
                      batch.update(seatRef, {
                        'reservationType': FieldValue.delete(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    }

                    await batch.commit();

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      final libName = ref.read(currentLibraryProvider).value?.name ?? 'Study Library';
                      final helpline = ref.read(currentLibraryProvider).value?.helplineNumber;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Membership reactivated ✓ ${s.name} is now Active.'),
                          backgroundColor: Colors.green,
                          action: SnackBarAction(
                            label: 'WhatsApp',
                            textColor: Colors.white,
                            onPressed: () {
                              ref.read(whatsappServiceProvider).sendMembershipUnfreezeNotice(
                                phone: s.phone,
                                studentName: s.name,
                                libraryName: libName,
                                resumeDate: today,
                                expiryDate: currentEnd,
                                seatLabel: seatLabel,
                                libraryHelpline: helpline,
                                context: context,
                              );
                            },
                          ),
                        ),
                      );

                      if (sendWhatsApp) {
                        ref.read(whatsappServiceProvider).sendMembershipUnfreezeNotice(
                          phone: s.phone,
                          studentName: s.name,
                          libraryName: libName,
                          resumeDate: today,
                          expiryDate: currentEnd,
                          seatLabel: seatLabel,
                          libraryHelpline: helpline,
                          context: context,
                        );
                      }

                      _loadStudent();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'student');
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEarlyExitDialog(BuildContext context, StudentModel s) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    if (s.planStartDate == null || s.planEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active membership cycle found for early exit.')),
      );
      return;
    }

    // Fetch library-configured cancellation fee
    double defaultCancellationFee = 100.0;
    bool autoReleaseSeat = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('cancellation_policy')
          .get();
      if (doc.exists && doc.data() != null) {
        defaultCancellationFee = (doc.data()!['cancellationFee'] as num?)?.toDouble() ?? 100.0;
        autoReleaseSeat = doc.data()!['autoReleaseSeat'] as bool? ?? true;
      }
    } catch (_) {}

    final effectivePlan = PlanModel(
      id: s.planId ?? 'plan',
      libraryId: libraryId,
      name: planName.isNotEmpty ? planName : 'Standard Plan',
      price: planPrice > 0 ? planPrice : (s.customPlanFee ?? 700.0),
      duration: 1,
      durationUnit: DurationUnit.months,
      description: '',
      gracePeriodDays: 0,
      isActive: true,
      isFeatured: false,
      displayOrder: 0,
    );

    final feeCtrl = TextEditingController(text: defaultCancellationFee.toStringAsFixed(0));
    final exitDate = DateTime.now();
    final double totalPaid = s.customPlanFee ?? effectivePlan.price;
    final paidCtrl = TextEditingController(text: totalPaid.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Early exit requested by student');
    String refundMethod = 'UPI';
    bool releaseSeat = autoReleaseSeat && s.seatId != null && s.seatId!.isNotEmpty;
    bool sendWhatsApp = true;
    bool isProcessing = false;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: !isProcessing,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final processingFee = double.tryParse(feeCtrl.text.trim()) ?? defaultCancellationFee;
          final curPaid = double.tryParse(paidCtrl.text.trim()) ?? totalPaid;

          final exitCalc = PlanCalculatorService.calculateExitSettlement(
            startDate: s.planStartDate!,
            originalEndDate: s.planEndDate!,
            exitDate: exitDate,
            totalPaid: curPaid,
            plan: effectivePlan,
            processingFee: processingFee,
          );

          final hasSeat = s.seatId != null && s.seatId!.isNotEmpty;
          final formattedSeatLabel = seatLabel.isNotEmpty ? seatLabel : SeatHelper.formatSeatLabel(seatId: s.seatId);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepOrange.shade50,
                  child: const Icon(Icons.exit_to_app_rounded, color: Colors.deepOrange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Early Exit & Refund Wizard', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Pro-rata ledger settlement & seat vacate', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Header Tile
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 18, color: Colors.deepOrange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${s.name} • ${s.phone}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          if (hasSeat)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                'Desk $formattedSeatLabel',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Inputs for Total Paid & Processing Fee
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: paidCtrl,
                            keyboardType: TextInputType.number,
                            enabled: !isProcessing,
                            decoration: const InputDecoration(
                              labelText: 'Total Fee Paid (₹)',
                              prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: feeCtrl,
                            keyboardType: TextInputType.number,
                            enabled: !isProcessing,
                            decoration: const InputDecoration(
                              labelText: 'Cancellation Fee (₹)',
                              prefixIcon: Icon(Icons.handyman_rounded, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Settlement Math Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Membership Cycle (${exitCalc.totalCycleDays} days):', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '${DateFormat('dd MMM').format(s.planStartDate!)} → ${DateFormat('dd MMM').format(s.planEndDate!)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Exit Date (Used ${exitCalc.usedDays}d • Unused ${exitCalc.unusedDays}d):', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(DateFormat('dd MMM yyyy').format(exitDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Fair Usage Charge:', style: TextStyle(fontSize: 13)),
                              Text('₹${exitCalc.fairUsageFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Gross Refund:', style: TextStyle(fontSize: 13)),
                              Text(exitCalc.formattedGrossRefund, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Less Processing/Seat Fee:', style: TextStyle(fontSize: 13, color: Colors.red)),
                              Text('-₹${processingFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.red)),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Net Refund Due to Student:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                exitCalc.formattedNetRefund,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: exitCalc.netRefund > 0 ? Colors.green : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Refund Payment Method Selection (if netRefund > 0)
                    if (exitCalc.netRefund > 0) ...[
                      const Text('Refund Payout Method:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('UPI'),
                            avatar: const Icon(Icons.qr_code_rounded, size: 16),
                            selected: refundMethod == 'UPI',
                            onSelected: isProcessing ? null : (_) => setDlgState(() => refundMethod = 'UPI'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Cash'),
                            avatar: const Icon(Icons.money_rounded, size: 16),
                            selected: refundMethod == 'Cash',
                            onSelected: isProcessing ? null : (_) => setDlgState(() => refundMethod = 'Cash'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Bank Transfer'),
                            avatar: const Icon(Icons.account_balance_rounded, size: 16),
                            selected: refundMethod == 'Bank Transfer',
                            onSelected: isProcessing ? null : (_) => setDlgState(() => refundMethod = 'Bank Transfer'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (refundMethod != 'Cash')
                        TextField(
                          controller: refCtrl,
                          enabled: !isProcessing,
                          decoration: const InputDecoration(
                            labelText: 'Reference ID / UTR Number (Optional)',
                            hintText: 'e.g. UPI Ref / Cheque No.',
                            prefixIcon: Icon(Icons.tag_rounded, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

                    // Exit Reason field
                    TextField(
                      controller: reasonCtrl,
                      enabled: !isProcessing,
                      decoration: const InputDecoration(
                        labelText: 'Exit Reason / Settlement Note',
                        hintText: 'e.g. Relocating, Exams Over, Personal Reasons',
                        prefixIcon: Icon(Icons.edit_note_rounded, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Desk Vacate & Waiting List Cascade Option
                    if (hasSeat)
                      CheckboxListTile(
                        value: releaseSeat,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Vacate Desk $formattedSeatLabel & Alert Waiting List', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Releases seat instantly and offers a 2-hour priority hold to candidate #1.', style: TextStyle(fontSize: 11.5)),
                        onChanged: isProcessing ? null : (val) => setDlgState(() => releaseSeat = val ?? true),
                      ),

                    // WhatsApp Settlement Voucher Option
                    CheckboxListTile(
                      value: sendWhatsApp,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Send WhatsApp Settlement Voucher to ${s.phone}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Dispatches itemized pro-rata breakdown, refund voucher number, and exit confirmation.', style: TextStyle(fontSize: 11.5)),
                      onChanged: isProcessing ? null : (val) => setDlgState(() => sendWhatsApp = val ?? true),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.exit_to_app_rounded, size: 16),
                label: Text(
                  isProcessing
                      ? 'Processing Settlement...'
                      : (exitCalc.netRefund > 0
                          ? 'Issue ₹${exitCalc.netRefund.toStringAsFixed(0)} Refund & Exit'
                          : 'Confirm Early Exit'),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setDlgState(() => isProcessing = true);
                        try {
                          WaitingListEntry? cascadedCandidate;

                          // 1. Release allocated seat if releaseSeat is true
                          if (releaseSeat && s.seatId != null && s.sectionId != null) {
                            try {
                              final seatRepo = ref.read(seatRepositoryProvider);
                              await seatRepo.unassignStudent(
                                libraryId: libraryId,
                                sectionId: s.sectionId!,
                                seatId: s.seatId!,
                                studentId: s.id,
                              );

                              // Trigger Waiting List priority cascade
                              final waitlistService = ref.read(waitingListPromotionServiceProvider);
                              final libModel = ref.read(currentLibraryProvider).value;
                              cascadedCandidate = await waitlistService.handleSeatReleaseCascade(
                                libraryId: libraryId,
                                sectionId: s.sectionId!,
                                seatId: s.seatId!,
                                seatLabel: formattedSeatLabel,
                                libraryName: libModel?.name ?? 'The Cozy Corner Study Centre',
                              );
                            } catch (e) {
                              debugPrint('Could not unassign seat or cascade waitlist: $e');
                            }
                          }

                          // 2. Generate official Refund Voucher / Settlement Receipt & record negative ledger payment
                          String? voucherNumber;
                          if (exitCalc.netRefund > 0) {
                            final receiptRepo = ReceiptRepository();
                            voucherNumber = await receiptRepo.getNextReceiptNumber(libraryId);

                            final receiptDoc = FirebaseFirestore.instance
                                .collection('libraries')
                                .doc(libraryId)
                                .collection('receipts')
                                .doc();

                            final settlementReceipt = ReceiptModel(
                              id: receiptDoc.id,
                              libraryId: libraryId,
                              receiptNumber: voucherNumber,
                              studentId: s.id,
                              studentUserId: s.userId,
                              planId: s.planId ?? 'early_exit',
                              amount: exitCalc.netRefund,
                              paymentMethod: refundMethod,
                              validFrom: s.planStartDate!,
                              validTo: exitDate,
                              status: ReceiptStatus.active,
                              customFields: {
                                'isRefund': true,
                                'isEarlyExitSettlement': true,
                                'usedDays': exitCalc.usedDays,
                                'totalCycleDays': exitCalc.totalCycleDays,
                                'unusedDays': exitCalc.unusedDays,
                                'fairUsageFee': exitCalc.fairUsageFee,
                                'processingFee': processingFee,
                                'totalPaid': curPaid,
                                'netRefund': exitCalc.netRefund,
                                'refundMethod': refundMethod,
                                'exitReason': reasonCtrl.text.trim(),
                                if (refCtrl.text.trim().isNotEmpty) 'referenceNumber': refCtrl.text.trim(),
                                'exitDate': exitDate.toIso8601String(),
                              },
                              createdAt: exitDate,
                            );
                            await receiptDoc.set(settlementReceipt.toJson());

                            // Create matching negative refund payment in ledger
                            final payDoc = FirebaseFirestore.instance
                                .collection('libraries')
                                .doc(libraryId)
                                .collection('payments')
                                .doc();
                            final refundPayment = PaymentModel(
                              id: payDoc.id,
                              studentId: s.id,
                              studentUserId: s.userId,
                              amount: -exitCalc.netRefund,
                              totalPlanFee: curPaid,
                              remainingDue: 0.0,
                              method: refundMethod,
                              referenceNumber: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                              date: exitDate,
                              receiptId: receiptDoc.id,
                              receiptNumber: voucherNumber,
                              status: PaymentStatus.refunded,
                              notes: 'Early Exit Settlement Voucher #$voucherNumber: Used ${exitCalc.usedDays}/${exitCalc.totalCycleDays}d. Fair usage: ₹${exitCalc.fairUsageFee.toStringAsFixed(0)}. Deduction: ₹${processingFee.toStringAsFixed(0)}. Net refund: ₹${exitCalc.netRefund.toStringAsFixed(0)} ($refundMethod). Reason: ${reasonCtrl.text.trim()}',
                              createdAt: exitDate,
                            );
                            await payDoc.set(refundPayment.toJson());

                            // Adjust library revenue aggregate
                            final monthKey = exitDate.toIso8601String().substring(0, 7);
                            FirebaseFirestore.instance
                                .collection('libraries')
                                .doc(libraryId)
                                .collection('settings')
                                .doc('revenue_aggregate')
                                .set({
                              'totalRevenue': FieldValue.increment(-exitCalc.netRefund),
                              'monthlyRevenue.$monthKey': FieldValue.increment(-exitCalc.netRefund),
                              'lastUpdated': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true)).ignore();
                          }

                          // 3. Mark student as inactive, settle dues to ₹0, append settlement log
                          final exitSummaryNote = '[Exit Settlement] on ${DateFormat('dd MMM yyyy').format(exitDate)}. '
                              'Cycle: ${exitCalc.usedDays}/${exitCalc.totalCycleDays}d. '
                              'Fair usage: ₹${exitCalc.fairUsageFee.toStringAsFixed(0)}. '
                              'Deduction: ₹${processingFee.toStringAsFixed(0)}. '
                              'Net refund: ₹${exitCalc.netRefund.toStringAsFixed(0)}'
                              '${voucherNumber != null ? " (Voucher: $voucherNumber via $refundMethod)" : ""}. '
                              'Reason: ${reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : "Early exit requested by student"}.';

                          await FirebaseFirestore.instance
                              .collection('libraries')
                              .doc(libraryId)
                              .collection('students')
                              .doc(s.id)
                              .update({
                            'membershipStatus': 'inactive',
                            'previousSeatId': s.seatId,
                            'previousSectionId': s.sectionId,
                            'seatId': null,
                            'sectionId': null,
                            'pendingDueBalance': 0.0,
                            'notes': (s.notes != null && s.notes!.isNotEmpty) ? '${s.notes}\n$exitSummaryNote' : exitSummaryNote,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          // 4. Record audit entry
                          AuditLogger().log(
                            action: AuditAction.updated,
                            entityType: AuditEntity.student,
                            entityId: s.id,
                            libraryId: libraryId,
                            details: {
                              'action': 'early_exit_settlement',
                              'studentName': s.name,
                              'voucherNumber': voucherNumber,
                              'netRefund': exitCalc.netRefund,
                              'refundMethod': refundMethod,
                              'seatReleased': releaseSeat ? s.seatId : null,
                              if (cascadedCandidate != null) 'waitlistCandidatePromoted': cascadedCandidate.studentName,
                            },
                          );

                          // 5. Send WhatsApp settlement voucher if opted-in
                          if (sendWhatsApp && s.phone.isNotEmpty) {
                            try {
                              final whatsapp = ref.read(whatsappServiceProvider);
                              final libModel = ref.read(currentLibraryProvider).value;
                              await whatsapp.sendEarlyExitSettlement(
                                phone: s.phone,
                                studentName: s.name,
                                libraryName: libModel?.name ?? 'The Cozy Corner Study Centre',
                                voucherNumber: voucherNumber ?? 'SETTLE-${DateFormat('yyyyMMdd').format(exitDate)}',
                                usedDays: exitCalc.usedDays,
                                totalDays: exitCalc.totalCycleDays,
                                fairUsageFee: exitCalc.fairUsageFee,
                                processingFee: processingFee,
                                netRefund: exitCalc.netRefund,
                                refundMethod: refundMethod,
                                referenceNumber: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                                seatLabel: formattedSeatLabel,
                                libraryHelpline: libModel?.phone,
                                context: context.mounted ? context : null,
                              );
                            } catch (e) {
                              debugPrint('Error launching WhatsApp settlement confirmation: $e');
                            }
                          }

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            final seatMsg = releaseSeat && s.seatId != null
                                ? ' • Desk $formattedSeatLabel vacated${cascadedCandidate != null ? ' & held for ${cascadedCandidate.studentName}' : ''}'
                                : '';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Early exit processed ✓ Net refund: ${exitCalc.formattedNetRefund}${voucherNumber != null ? ' (Voucher: $voucherNumber)' : ''}$seatMsg',
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: cascadedCandidate != null ? 8 : 4),
                                action: cascadedCandidate != null
                                    ? SnackBarAction(
                                        label: 'WhatsApp Candidate',
                                        textColor: Colors.amberAccent,
                                        onPressed: () {
                                          final libModel = ref.read(currentLibraryProvider).value;
                                          ref.read(whatsappServiceProvider).sendWaitingListPromotion(
                                            phone: cascadedCandidate!.studentPhone,
                                            studentName: cascadedCandidate.studentName,
                                            libraryName: libModel?.name ?? 'The Cozy Corner Study Centre',
                                            seatLabel: formattedSeatLabel,
                                            sectionName: s.sectionId ?? 'Main Hall',
                                            libraryHelpline: libModel?.phone,
                                            libraryAddress: libModel?.address,
                                            adminTemplate: libModel?.waitingListNotificationTemplate,
                                            context: context,
                                          );
                                        },
                                      )
                                    : null,
                              ),
                            );
                            _loadStudent();
                          }
                        } catch (e) {
                          setDlgState(() => isProcessing = false);
                          if (context.mounted) {
                            AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'student');
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCustomPlanDialog(BuildContext context, String libraryId, StudentModel? s) async {
    final now = DateTime.now();
    final nextMonthFirst = DateTime(now.year, now.month + 1, 1);
    final monthEnd = DateTime(nextMonthFirst.year, nextMonthFirst.month, 0, 23, 59, 59, 999);
    final remainingDays = monthEnd.difference(now).inDays + 1;

    final nameCtrl = TextEditingController(text: s?.customPlanName ?? 'Custom Plan');
    final feeCtrl = TextEditingController(text: (s?.customPlanFee ?? 500).toStringAsFixed(0));
    final reasonCtrl = TextEditingController(text: s?.customDiscountReason ?? '');
    int durationDays = 0; // 0 = Till Month End
    DateTime? pickedExpiry;
    bool isSticky = s?.isStickyCustomPrice ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Assign Custom Plan'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Custom Plan Name *',
                        hintText: 'e.g. 15-Day Exam Pass, Daily Trial, Scholarship',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Custom Plan Fee (₹) *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Validity Duration (Max: Month End)',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('Today Only (1 Day)'),
                          selected: durationDays == 1 && pickedExpiry == null,
                          onSelected: (val) {
                            if (val) {
                              setDlgState(() {
                                durationDays = 1;
                                pickedExpiry = null;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text('Till Month End ($remainingDays Days)'),
                          selected: durationDays == 0 && pickedExpiry == null,
                          onSelected: (val) {
                            if (val) {
                              setDlgState(() {
                                durationDays = 0;
                                pickedExpiry = null;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.event_rounded, size: 14),
                          label: Text(
                            pickedExpiry != null
                                ? DateFormat('dd MMM yyyy').format(pickedExpiry!)
                                : 'Specific Date...',
                          ),
                          selected: pickedExpiry != null,
                          onSelected: (_) async {
                            final p = await showDatePicker(
                              context: context,
                              initialDate: pickedExpiry ?? monthEnd,
                              firstDate: now,
                              lastDate: monthEnd,
                              helpText: 'SELECT EXPIRY (MAX MONTH END)',
                            );
                            if (p != null) {
                              setDlgState(() {
                                pickedExpiry = p;
                                durationDays = p.difference(now).inDays + 1;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isSticky,
                      title: const Text('Recurring Concession for Monthly Renewals', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Allow renewing each month at this custom rate', style: TextStyle(fontSize: 10.5)),
                      onChanged: (v) => setDlgState(() => isSticky = v),
                    ),
                    if (isSticky) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Concession Reason (Optional)',
                          hintText: 'e.g. Scholarship, Hardship, Staff Ward',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Custom Plan';
                  final fee = double.tryParse(feeCtrl.text.trim()) ?? 500.0;
                  final effectiveEnd = pickedExpiry != null
                      ? DateTime(pickedExpiry!.year, pickedExpiry!.month, pickedExpiry!.day, 23, 59, 59, 999)
                      : (durationDays > 0
                          ? DateTime(now.year, now.month, now.day + durationDays - 1, 23, 59, 59, 999)
                          : monthEnd);

                  await FirebaseFirestore.instance
                      .collection('libraries')
                      .doc(libraryId)
                      .collection('students')
                      .doc(widget.studentId)
                      .update({
                    'planId': 'custom',
                    'customPlanName': name,
                    'customPlanFee': fee,
                    'isStickyCustomPrice': isSticky,
                    if (reasonCtrl.text.trim().isNotEmpty) 'customDiscountReason': reasonCtrl.text.trim(),
                    'planStartDate': Timestamp.fromDate(now),
                    'planEndDate': Timestamp.fromDate(effectiveEnd),
                    'membershipStatus': MembershipStatus.active.name,
                  });

                  AuditLogger().log(
                    action: AuditAction.updated,
                    entityType: AuditEntity.student,
                    libraryId: libraryId,
                    entityId: widget.studentId,
                    details: {'planChanged': true, 'planId': 'custom', 'planName': name, 'fee': fee},
                  ).ignore();

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // Close assign plan sheet
                    _loadStudent();
                  }
                },
                child: const Text('Assign Custom Plan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showPlanUpgradeDialog(
    BuildContext context,
    StudentModel s,
    PlanModel targetPlan,
    String libraryId,
  ) async {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 1. Resolve current plan model
    final curPlanName = s.customPlanName?.isNotEmpty == true
        ? s.customPlanName!
        : (planName.isNotEmpty ? planName : 'Current Active Plan');
    final curPlanPrice = s.customPlanFee ?? (planPrice > 0 ? planPrice : 700.0);
    final curStartDate = s.planStartDate ?? now.subtract(const Duration(days: 15));
    final curEndDate = s.planEndDate ?? now.add(const Duration(days: 15));

    final curPlan = PlanModel(
      id: s.planId ?? 'current',
      libraryId: libraryId,
      name: curPlanName,
      price: curPlanPrice,
      duration: 1,
      durationUnit: DurationUnit.months,
      description: '',
      gracePeriodDays: 0,
      isActive: true,
      isFeatured: false,
      displayOrder: 0,
    );

    // 2. Compute pro-rata settlement
    final settlement = PlanCalculatorService.calculatePlanChangeSettlement(
      currentPlan: curPlan,
      targetPlan: targetPlan,
      currentStartDate: curStartDate,
      currentEndDate: curEndDate,
      totalPaidForCurrent: curPlanPrice,
    );

    int upgradeMode = 0; // 0 = Mid-Cycle Pro-rata (keep expiry), 1 = Fresh Cycle with Credit
    String paymentMethod = 'UPI';
    bool recordAsPaid = true;
    final refController = TextEditingController();
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: !isProcessing,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            // Mode 0: Keep current expiry, pay mid-cycle pro-rata difference
            final mode0Amount = settlement.payableByStudent;
            final mode0EndDate = curEndDate;

            // Mode 1: Fresh full cycle from today, subtract unused credit
            final targetSmart = PlanCalculatorService.calculateSmartPlan(plan: targetPlan, fromDate: now);
            final mode1Amount = (targetPlan.price - settlement.unusedCredit).clamp(0.0, double.infinity);
            final mode1EndDate = targetSmart.endDate;

            final effectiveAmount = upgradeMode == 0 ? mode0Amount : mode1Amount;
            final effectiveEndDate = upgradeMode == 0 ? mode0EndDate : mode1EndDate;
            final effectiveStartDate = upgradeMode == 0 ? curStartDate : now;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.upgrade_rounded, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plan Upgrade & Settlement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Fair Pro-Rata Credit Adjustment', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview Comparison Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('CURRENT PLAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.outline)),
                                      Text(curPlanName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                      Text('₹${curPlanPrice.toStringAsFixed(0)} • ${settlement.remainingDays}d left', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('NEW TARGET TIER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                      Text(targetPlan.displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary), overflow: TextOverflow.ellipsis),
                                      Text('₹${targetPlan.price.toStringAsFixed(0)} catalog rate', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Unused Credit (${settlement.remainingDays} days):', style: const TextStyle(fontSize: 12)),
                                Text('₹${settlement.unusedCredit.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Choose Upgrade Mode:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      // Mode 0: Mid-Cycle Pro-rata
                      InkWell(
                        onTap: () => setDlgState(() => upgradeMode = 0),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: upgradeMode == 0 ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
                            border: Border.all(
                              color: upgradeMode == 0 ? theme.colorScheme.primary : theme.dividerColor,
                              width: upgradeMode == 0 ? 1.8 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                upgradeMode == 0 ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: upgradeMode == 0 ? theme.colorScheme.primary : Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Text('Mid-Cycle Upgrade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        SizedBox(width: 6),
                                        Text('(Recommended)', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Text(
                                      'Keep current expiry (${DateFormat('dd MMM').format(curEndDate)}). Pay ₹${mode0Amount.toStringAsFixed(0)} difference for remaining ${settlement.remainingDays} days.',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Text('₹${mode0Amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Mode 1: Fresh Full Cycle with Credit
                      InkWell(
                        onTap: () => setDlgState(() => upgradeMode = 1),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: upgradeMode == 1 ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
                            border: Border.all(
                              color: upgradeMode == 1 ? theme.colorScheme.primary : theme.dividerColor,
                              width: upgradeMode == 1 ? 1.8 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                upgradeMode == 1 ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: upgradeMode == 1 ? theme.colorScheme.primary : Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Fresh Cycle (Credit Applied)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(
                                      'Valid for full new month (till ${DateFormat('dd MMM').format(mode1EndDate)}). ₹${settlement.unusedCredit.toStringAsFixed(0)} credit deducted.',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Text('₹${mode1Amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment Details
                      if (effectiveAmount > 0) ...[
                        Text('Payment & Collection Method:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: ['UPI', 'Cash', 'Card', 'Bank Transfer'].map((m) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(m, style: const TextStyle(fontSize: 12)),
                                selected: paymentMethod == m,
                                onSelected: (val) {
                                  if (val) setDlgState(() => paymentMethod = m);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: refController,
                          decoration: const InputDecoration(
                            labelText: 'Reference / UTR / Note (Optional)',
                            hintText: 'e.g. UPI/20261105/982123',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: recordAsPaid,
                          title: const Text('Mark Surcharge as Paid Now', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Turn off to add ₹ difference to pending student dues instead', style: TextStyle(fontSize: 11)),
                          onChanged: (v) => setDlgState(() => recordAsPaid = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDlgState(() => isProcessing = true);
                          try {
                            // 1. Generate receipt if paid > 0
                            String? receiptNumber;
                            if (effectiveAmount > 0 && recordAsPaid) {
                              final receiptRepo = ReceiptRepository();
                              receiptNumber = await receiptRepo.getNextReceiptNumber(libraryId);

                              await receiptRepo.generateReceipt(
                                libraryId,
                                ReceiptModel(
                                  id: '',
                                  libraryId: libraryId,
                                  receiptNumber: receiptNumber,
                                  studentId: s.id,
                                  studentUserId: s.userId,
                                  planId: targetPlan.id,
                                  amount: effectiveAmount,
                                  paymentMethod: paymentMethod,
                                  validFrom: effectiveStartDate,
                                  validTo: effectiveEndDate,
                                  customFields: {
                                    'isPlanUpgrade': true,
                                    'previousPlanName': curPlanName,
                                    'unusedCredit': settlement.unusedCredit,
                                    'proratedDays': settlement.remainingDays,
                                    'note': 'Plan Upgrade: $curPlanName ➔ ${targetPlan.displayName}',
                                  },
                                  status: ReceiptStatus.active,
                                ),
                              );

                              // Record ledger payment
                              final paymentDoc = FirebaseFirestore.instance
                                  .collection('libraries')
                                  .doc(libraryId)
                                  .collection('payments')
                                  .doc();

                              await paymentDoc.set({
                                'studentId': s.id,
                                'studentName': s.name,
                                'planId': targetPlan.id,
                                'planName': targetPlan.displayName,
                                'amount': effectiveAmount,
                                'paymentMethod': paymentMethod,
                                'paymentDate': Timestamp.fromDate(now),
                                'receiptNumber': receiptNumber,
                                'reference': refController.text.trim(),
                                'status': PaymentStatus.paid.name,
                                'notes': 'Mid-Cycle Plan Upgrade from $curPlanName to ${targetPlan.displayName}',
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              // Increment library revenue aggregate
                              await FirebaseFirestore.instance
                                  .collection('libraries')
                                  .doc(libraryId)
                                  .collection('aggregates')
                                  .doc('revenue')
                                  .set({
                                'totalRevenue': FieldValue.increment(effectiveAmount),
                                'lastUpdated': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                            }

                            // 2. Update Student Profile
                            final double newDueBalance = (!recordAsPaid && effectiveAmount > 0)
                                ? ((s.pendingDueBalance ?? 0.0) + effectiveAmount)
                                : (s.pendingDueBalance ?? 0.0);

                            final upgradeNote = '[Plan Upgrade] $curPlanName ➔ ${targetPlan.displayName} (${DateFormat('dd MMM yyyy').format(now)}): '
                                '₹${effectiveAmount.toStringAsFixed(0)} ${recordAsPaid ? 'paid via $paymentMethod' : 'added to pending due'}'
                                '${receiptNumber != null ? ' • Receipt: $receiptNumber' : ''}';

                            final updatedNotes = s.notes != null && s.notes!.isNotEmpty
                                ? '${s.notes}\n$upgradeNote'
                                : upgradeNote;

                            await FirebaseFirestore.instance
                                .collection('libraries')
                                .doc(libraryId)
                                .collection('students')
                                .doc(s.id)
                                .update({
                              'planId': targetPlan.id,
                              'customPlanName': FieldValue.delete(),
                              'customPlanFee': FieldValue.delete(),
                              'planStartDate': Timestamp.fromDate(effectiveStartDate),
                              'planEndDate': Timestamp.fromDate(effectiveEndDate),
                              'membershipStatus': MembershipStatus.active.name,
                              'pendingDueBalance': newDueBalance,
                              'notes': updatedNotes,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            // 3. Audit Log
                            AuditLogger().log(
                              action: AuditAction.updated,
                              entityType: AuditEntity.student,
                              libraryId: libraryId,
                              entityId: s.id,
                              details: {
                                'planUpgrade': true,
                                'previousPlan': curPlanName,
                                'newPlan': targetPlan.displayName,
                                'amount': effectiveAmount,
                                'receiptNumber': receiptNumber,
                              },
                            ).ignore();

                            // 4. Soundbox Counter Announcement (if paid at counter)
                            if (recordAsPaid && effectiveAmount > 0) {
                              final libModel = ref.read(currentLibraryProvider).value;
                              ref.read(soundboxServiceProvider).announcePayment(
                                amount: effectiveAmount,
                                studentName: s.name,
                                seatLabel: s.seatId != null ? SeatHelper.formatSeatLabel(seatId: s.seatId) : null,
                                libraryName: libModel?.name,
                              );
                            }

                            // 5. WhatsApp confirmation
                            try {
                              final libModel = ref.read(currentLibraryProvider).value;
                              await WhatsAppService().sendPlanUpgradeConfirmation(
                                phone: s.phone,
                                studentName: s.name,
                                libraryName: libModel?.name ?? 'The Cozy Corner Study Centre',
                                oldPlanName: curPlanName,
                                newPlanName: targetPlan.displayName,
                                receiptNumber: receiptNumber ?? 'N/A',
                                remainingDays: settlement.remainingDays,
                                unusedCredit: settlement.unusedCredit,
                                newProratedFee: settlement.newPlanProratedFee,
                                netPaid: recordAsPaid ? effectiveAmount : 0.0,
                                paymentMethod: paymentMethod,
                                newExpiryDate: effectiveEndDate,
                                referenceNumber: refController.text.trim().isNotEmpty ? refController.text.trim() : null,
                                libraryHelpline: libModel?.phone,
                                context: context.mounted ? context : null,
                              );
                            } catch (e) {
                              debugPrint('Could not send WhatsApp upgrade message: $e');
                            }

                            if (context.mounted) {
                              Navigator.pop(ctx);
                              Navigator.pop(context); // Close assign plan sheet
                              _loadStudent();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Plan successfully upgraded to ${targetPlan.displayName} ✓${receiptNumber != null ? ' Receipt #$receiptNumber' : ''}'),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDlgState(() => isProcessing = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error upgrading plan: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  icon: isProcessing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(isProcessing ? 'Processing…' : 'Confirm Upgrade (₹${effectiveAmount.toStringAsFixed(0)})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAssignPlanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final plansAsync = ref.watch(plansStreamProvider);
                return plansAsync.when(
                  data: (plans) {
                    final activePlans = plans.where((p) => p.isActive).toList();
                    if (activePlans.isEmpty) {
                      return const Center(child: Text('No active plans available'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: activePlans.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                              ),
                              title: const Text('Custom Plan / Fee Override', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Set custom pricing, daily pass, or validity till month end', style: TextStyle(fontSize: 12)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                              onTap: () {
                                final libraryId = ref.read(currentLibraryIdProvider);
                                if (libraryId != null) {
                                  _showCustomPlanDialog(context, libraryId, student);
                                }
                              },
                            ),
                          );
                        }

                        final plan = activePlans[index - 1];
                        return ListTile(
                          title: Text(plan.name),
                          subtitle: Text('Duration: ${plan.duration} ${plan.durationUnit.name}'),
                          trailing: Text('₹${plan.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          onTap: () async {
                            final libraryId = ref.read(currentLibraryIdProvider);
                            if (libraryId == null) return;

                            // Mid-Cycle Plan Upgrade Wizard if student already has an active plan
                            if (student != null &&
                                student!.planId != null &&
                                student!.membershipStatus == MembershipStatus.active) {
                              await _showPlanUpgradeDialog(context, student!, plan, libraryId);
                              return;
                            }

                            final now = DateTime.now();
                            final smartCalc = PlanCalculatorService.calculateSmartPlan(
                              plan: plan,
                              fromDate: now,
                            );
                            final endDate = smartCalc.endDate;

                            await FirebaseFirestore.instance
                                .collection('libraries')
                                .doc(libraryId)
                                .collection('students')
                                .doc(widget.studentId)
                                .update({
                              'planId': plan.id,
                              'planStartDate': Timestamp.fromDate(now),
                              'planEndDate': Timestamp.fromDate(endDate),
                              'membershipStatus': MembershipStatus.active.name,
                            });

                            AuditLogger().log(
                              action: AuditAction.updated,
                              entityType: AuditEntity.student,
                              libraryId: libraryId,
                              entityId: widget.studentId,
                              details: {'planChanged': true, 'planId': plan.id, 'planName': plan.name},
                            ).ignore();

                            // C3: Auto-create receipt for direct plan assign
                            try {
                              final receiptRepo = ReceiptRepository();
                              final receiptNumber = await receiptRepo.getNextReceiptNumber(libraryId);
                              await receiptRepo.generateReceipt(
                                libraryId,
                                ReceiptModel(
                                  id: '',
                                  libraryId: libraryId,
                                  receiptNumber: receiptNumber,
                                  studentId: widget.studentId,
                                  planId: plan.id,
                                  amount: plan.price,
                                  paymentMethod: 'Plan Assigned',
                                  validFrom: now,
                                  validTo: endDate,
                                  customFields: {'note': 'Auto-generated on plan assign'},
                                  status: ReceiptStatus.active,
                                ),
                              );
                            } catch (_) {}

                            if (context.mounted) {
                              Navigator.pop(context);
                              _loadStudent();
                            }

                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStudent() async {
    final canDelete = ref.read(canDeleteStudentsProvider);
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to delete students.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text('Are you sure you want to delete this student?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final libraryId = ref.read(currentLibraryIdProvider);
      if (libraryId != null) {
        try {
          final s = student;

          // C10: Release the student's seat before deleting
          if (s != null && s.seatId != null && s.sectionId != null) {
            await ref.read(seatRepositoryProvider).updateSeatStatus(
              libraryId,
              s.sectionId!,
              s.seatId!,
              SeatStatus.available,
            );
            // Also clear studentId/name from seat document
            await FirebaseFirestore.instance
                .collection('libraries').doc(libraryId)
                .collection('sections').doc(s.sectionId!)
                .collection('seats').doc(s.seatId!)
                .update({
              'studentId': null,
              'studentName': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          // Use StudentRepository (moves to recycle_bin properly)
          await ref.read(studentRepositoryProvider).deleteStudent(
            libraryId,
            widget.studentId,
          );

          if (mounted) context.go('/admin/students');
        } catch (e) {
          if (mounted) {
            AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'student');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentLibraryIdProvider, (previous, next) {
      if (next != null && next.isNotEmpty && (student == null || next != previous)) {
        _loadStudent(overrideLibId: next);
      }
    });

    if (isLoading) {
      if (widget.isEmbeddedInSplitView) {
        return const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin/students');
              }
            },
          ),
          title: const Text('Student Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (student == null) {
      if (widget.isEmbeddedInSplitView) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('Student record not found', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin/students');
              }
            },
          ),
          title: const Text('Student Not Found'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_rounded, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Student not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('The requested student could not be found or has been removed.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.go('/admin/students'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Students'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final s = student!;
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';

    final scaffoldContent = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isEmbeddedInSplitView,
        leading: widget.isEmbeddedInSplitView
            ? Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.person_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/admin/students');
                  }
                },
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEmbeddedInSplitView ? s.name : 'Student Details',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.isEmbeddedInSplitView)
              Text(
                '${s.phone} • Desk ${seatLabel.isNotEmpty ? seatLabel : (s.seatId ?? "Unallocated")}',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          // WhatsApp quick-message button
          if (s.phone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              tooltip: 'WhatsApp Message',
              onPressed: () => _showWhatsAppSheet(context, s),
            ),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IdCardPreviewScreen(
                    student: s,
                    seatLabel: seatLabel,
                    sectionName: sectionName,
                    planName: planName,
                  ),
                ),
              );
            },
            tooltip: 'Print / Share ID Card',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await context.push('/admin/students/${widget.studentId}/edit');
              _loadStudent(); // Reload after edit
            },
            tooltip: 'Edit Student',
          ),
          if (ref.watch(canDeleteStudentsProvider))
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteStudent,
              tooltip: 'Delete Student',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (s.photoUrl.isNotEmpty) {
                      ImageService.showImageViewer(
                        context,
                        imageUrl: s.photoUrl,
                        title: s.name,
                      );
                    }
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: ImageService.getImageProvider(s.photoUrl),
                        child: s.photoUrl.isEmpty
                            ? Text(
                                s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      if (s.photoUrl.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(s.phone, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      if (s.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(s.email, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                      if (s.membershipNumber != null && s.membershipNumber!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onLongPress: () {
                            Clipboard.setData(ClipboardData(text: s.membershipNumber!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Membership ID copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.badge_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'ID: ${s.membershipNumber}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy, size: 12, color: Colors.grey),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _assignSequentialId(s),
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_card, size: 14, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Assign Sequential ID',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(s.membershipStatus.name.toUpperCase()),
                            backgroundColor: _getStatusColor(s.membershipStatus).withValues(alpha: 0.15),
                            labelStyle: TextStyle(color: _getStatusColor(s.membershipStatus), fontWeight: FontWeight.bold, fontSize: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          if (s.isCurrentlyFrozen)
                            Chip(
                              avatar: const Icon(Icons.ac_unit_rounded, size: 14, color: Color(0xFFD97706)),
                              label: const Text('STUDY LEAVE (FROZEN)'),
                              backgroundColor: const Color(0xFFFEF3C7),
                              labelStyle: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 11),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (s.membershipStatus != MembershipStatus.blocked) ...[
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.autorenew_rounded, size: 18),
                      label: Text(
                        s.planId != null ? 'Renew Membership' : 'Assign Plan',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        if (s.planId != null) {
                          _openRenewalFlow(context, s, planPrice);
                        } else {
                          _showAssignPlanSheet();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: s.membershipStatus == MembershipStatus.blocked ? 1 : 2,
                  child: s.membershipStatus == MembershipStatus.blocked
                      ? FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Unblock Student'),
                          onPressed: () async {
                            final repo = ref.read(studentRepositoryProvider);
                            await repo.unblockStudent(libraryId, s.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Student unblocked ✓'), backgroundColor: Colors.green),
                              );
                              _loadStudent();
                            }
                          },
                        )
                      : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.block_rounded, size: 16),
                          label: const Text('Block Student', maxLines: 1, overflow: TextOverflow.ellipsis),
                          onPressed: () async {
                            String reason = '';
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                final ctrl = TextEditingController();
                                return AlertDialog(
                                  title: const Text('Block Student'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Student will be locked out of the app. Seat stays assigned.'),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Reason for blocking *',
                                          border: OutlineInputBorder(),
                                        ),
                                        maxLines: 2,
                                        onChanged: (v) => reason = v,
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () {
                                        if (reason.trim().isEmpty) return;
                                        Navigator.pop(ctx, true);
                                      },
                                      child: const Text('Block'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirmed != true || !context.mounted) return;
                            final repo = ref.read(studentRepositoryProvider);
                            await repo.blockStudent(libraryId, s.id, reason: reason.trim());
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Student blocked'), backgroundColor: Colors.orange),
                              );
                              _loadStudent();
                            }
                          },
                        ),
                ),
              ],
            ),
            if (s.planId != null && s.membershipStatus != MembershipStatus.blocked) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: s.isCurrentlyFrozen
                        ? OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD97706),
                              side: const BorderSide(color: Color(0xFFFDE68A)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.wb_sunny_rounded, size: 16),
                            label: const Text('Unfreeze Pass', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            onPressed: () => _showUnfreezeMembershipDialog(context, s),
                          )
                        : OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.ac_unit_rounded, size: 16),
                            label: const Text('Freeze (10+ Days)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            onPressed: () => _showFreezeMembershipDialog(context, s),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange.shade800,
                        side: BorderSide(color: Colors.deepOrange.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                      label: const Text('Early Exit / Refund', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      onPressed: () => _showEarlyExitDialog(context, s),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // Personal & Academic Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Profile Details', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (s.fatherName.isNotEmpty)
                      _buildDetailRow(context, 'Father / Guardian', s.fatherName, Icons.family_restroom_rounded),
                    if (s.dob != null)
                      _buildDetailRow(context, 'Date of Birth', DateFormat('dd MMM yyyy').format(s.dob!), Icons.cake_outlined),
                    _buildDetailRow(context, 'Gender', s.gender.name.toUpperCase(), Icons.people_outline_rounded),
                    if (s.govIdNumber.isNotEmpty)
                      _buildGovIdRow(context, s.govIdType.name.toUpperCase(), s.govIdNumber),
                    _buildGovIdDocCard(context, s),
                    if (s.college.isNotEmpty)
                      _buildDetailRow(context, 'College / Institute', s.college, Icons.school_outlined),
                    if (s.course.isNotEmpty)
                      _buildDetailRow(context, 'Course & Year', '${s.course} ${s.year.isNotEmpty ? "(${s.year})" : ""}', Icons.menu_book_outlined),
                    if (s.address.isNotEmpty)
                      _buildDetailRow(context, 'Address', '${s.address} ${s.pincode.isNotEmpty ? "- ${s.pincode}" : ""}', Icons.location_on_outlined),
                    if (s.emergencyContact.isNotEmpty)
                      _buildDetailRow(context, 'Emergency Contact', s.emergencyContact, Icons.phone_in_talk_outlined),
                    if (s.bloodGroup != null && s.bloodGroup!.isNotEmpty)
                      _buildDetailRow(context, 'Blood Group', s.bloodGroup!, Icons.bloodtype_outlined),
                    if (s.rollNumber != null && s.rollNumber!.isNotEmpty)
                      _buildDetailRow(context, 'Roll / Enroll No.', s.rollNumber!, Icons.badge_outlined),
                    () {
                      final cleanNote = _sanitizeDisplayNote(s.notes, s);
                      if (cleanNote.isNotEmpty) {
                        return _buildDetailRow(
                          context,
                          'Notes',
                          cleanNote,
                          Icons.note_alt_outlined,
                          trailingAction: Tooltip(
                            message: 'Edit Note',
                            child: InkWell(
                              onTap: () => _showQuickEditNotesDialog(context, s),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                child: Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: InkWell(
                            onTap: () => _showQuickEditNotesDialog(context, s),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Icon(Icons.note_add_outlined, size: 16, color: Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+ Add Note',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    }(),
                    Consumer(
                      builder: (context, ref, _) {
                        final formConfigAsync = ref.watch(formConfigStreamProvider);
                        final fieldsList = formConfigAsync.value ?? [];
                        final customEntries = s.customFields.entries.where(
                          (e) => e.key != 'note' && e.value != null && e.value.toString().trim().isNotEmpty,
                        ).toList();

                        if (customEntries.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            const Divider(height: 16),
                            Text(
                              'Custom & Admission Fields',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final entry in customEntries)
                              _buildDetailRow(
                                context,
                                FormConfigService.getFieldLabel(fieldsList, entry.key, entry.key),
                                entry.value.toString(),
                                Icons.tune_rounded,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Seat Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_seat_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Seat Info', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (s.seatId != null && s.seatId!.isNotEmpty)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.chair, size: 32, color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  seatLabel.isNotEmpty ? 'Seat $seatLabel' : 'Seat ${SeatHelper.formatSeatLabel(seatId: s.seatId)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sectionName.isNotEmpty ? 'Section: $sectionName' : 'Section assigned',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(onPressed: _showAssignSeatSheet, child: const Text('Change')),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.chair_outlined, size: 40, color: Colors.grey[600]),
                              const SizedBox(width: 16),
                              const Expanded(child: Text('No seat assigned yet')),
                              FilledButton.icon(
                                onPressed: _showAssignSeatSheet,
                                icon: const Icon(Icons.add),
                                label: const Text('Assign Seat'),
                              ),
                            ],
                          ),
                          if (s.previousSeatId != null && s.previousSeatId!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.history_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Previously Allocated: Seat ${SeatHelper.formatSeatLabel(seatId: s.previousSeatId)}',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.restore_rounded, size: 16),
                                    label: const Text('Restore Desk'),
                                    onPressed: () async {
                                      final targetSec = s.previousSectionId;
                                      final targetSeat = s.previousSeatId;
                                      if (targetSec != null && targetSeat != null) {
                                        final seatRepo = ref.read(seatRepositoryProvider);
                                        await seatRepo.assignStudent(libraryId, targetSec, targetSeat, s.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Restored Seat ${SeatHelper.formatSeatLabel(seatId: targetSeat)} for ${s.name} ✓'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          _loadStudent();
                                        }
                                      } else {
                                        _showAssignSeatSheet();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Plan Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Plan Info', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (s.planId != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 360;
                              final actions = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.autorenew_rounded, size: 16),
                                    label: const Text('Renew Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => _openRenewalFlow(context, s, planPrice),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _showAssignPlanSheet,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Change'),
                                  ),
                                ],
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planName.isNotEmpty ? planName : 'Plan Assigned',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (planPrice > 0)
                                      Text(
                                        '₹${planPrice.toStringAsFixed(0)}',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    actions,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          planName.isNotEmpty ? planName : 'Plan Assigned',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        if (planPrice > 0)
                                          Text(
                                            '₹${planPrice.toStringAsFixed(0)}',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  actions,
                                ],
                              );
                            },
                          ),
                          if (s.planStartDate != null && s.planEndDate != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('${DateFormat.yMMMd().format(s.planStartDate!)} → ${DateFormat.yMMMd().format(s.planEndDate!)}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Builder(builder: (context) {
                              final daysLeft = s.planEndDate!.difference(DateTime.now()).inDays;
                              final color = daysLeft > 7 ? Colors.green : daysLeft > 0 ? Colors.orange : Colors.red;
                              final label = daysLeft > 0 ? '$daysLeft days remaining' : 'Expired ${-daysLeft} days ago';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                              );
                            }),
                          ],
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(Icons.assignment_outlined, size: 40, color: Colors.grey[600]),
                          const SizedBox(width: 16),
                          const Expanded(child: Text('No plan assigned yet')),
                          FilledButton.icon(
                            onPressed: _showAssignPlanSheet,
                            icon: const Icon(Icons.add),
                            label: const Text('Assign Plan'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment History Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Outstanding Due Balance Alert
                    if ((s.pendingDueBalance ?? 0) > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pending Due Balance: ₹${(s.pendingDueBalance ?? 0).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Student has an outstanding installment for their membership.',
                                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.amber.shade200,
                                foregroundColor: Colors.amber.shade900,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RecordPaymentScreen(
                                      studentId: widget.studentId,
                                      studentName: s.name,
                                      studentPhone: s.phone,
                                      planPrice: s.pendingDueBalance ?? 0.0,
                                      pendingDue: s.pendingDueBalance ?? 0.0,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Clear Due'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.account_balance_wallet_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Payment & Dues History',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          tooltip: 'Payment History Options',
                          onSelected: (val) {
                            if (val == 'record') {
                              final due = s.pendingDueBalance ?? 0.0;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecordPaymentScreen(
                                    studentId: widget.studentId,
                                    studentName: s.name,
                                    studentPhone: s.phone,
                                    planPrice: due > 0 ? due : planPrice,
                                    pendingDue: due,
                                  ),
                                ),
                              ).then((_) {
                                if (mounted) _loadStudent();
                              });
                            } else if (val == 'clear_due') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecordPaymentScreen(
                                    studentId: widget.studentId,
                                    studentName: s.name,
                                    studentPhone: s.phone,
                                    planPrice: s.pendingDueBalance ?? 0.0,
                                    pendingDue: s.pendingDueBalance ?? 0.0,
                                  ),
                                ),
                              ).then((_) {
                                if (mounted) _loadStudent();
                              });
                            } else if (val == 'send_ledger') {
                              _sendWhatsAppPaymentLedger(s, libraryId);
                            } else if (val == 'refresh') {
                              _loadStudent();
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'record',
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Record Payment & Issue Receipt'),
                                ],
                              ),
                            ),
                            if ((s.pendingDueBalance ?? 0) > 0)
                              const PopupMenuItem(
                                value: 'clear_due',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                                    SizedBox(width: 8),
                                    Text('Clear Outstanding Due Balance'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'send_ledger',
                              child: Row(
                                children: [
                                  Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                                  SizedBox(width: 8),
                                  Text('Send WhatsApp Ledger Statement'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'refresh',
                              child: Row(
                                children: [
                                  Icon(Icons.refresh_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Refresh Payment Records'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final due = s.pendingDueBalance ?? 0.0;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecordPaymentScreen(
                                studentId: widget.studentId,
                                studentName: s.name,
                                studentPhone: s.phone,
                                planPrice: due > 0 ? due : planPrice,
                                pendingDue: due,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) _loadStudent();
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Record Payment & Issue Official Receipt',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('payments')
                          .where('studentId', isEqualTo: widget.studentId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Text('No payments recorded.');
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final payment = PaymentModel.fromJson({...data, 'id': docs[index].id});
                            final isVoided = payment.status == PaymentStatus.voided || payment.status == PaymentStatus.cancelled;
                            final isRefunded = payment.status == PaymentStatus.refunded;
                            final isInactive = isVoided || isRefunded;
                            final isPartial = payment.status == PaymentStatus.partial;
                            final isPending = payment.status == PaymentStatus.pending || payment.status == PaymentStatus.overdue;

                            Color badgeBg;
                            Color badgeBorder;
                            Color badgeTextColor;
                            IconData badgeIcon;
                            String badgeText;

                            if (isVoided) {
                              badgeBg = Colors.red.shade50;
                              badgeBorder = Colors.red.shade300;
                              badgeTextColor = Colors.red.shade900;
                              badgeIcon = Icons.block_rounded;
                              badgeText = 'VOIDED';
                            } else if (isRefunded) {
                              badgeBg = Colors.orange.shade50;
                              badgeBorder = Colors.orange.shade300;
                              badgeTextColor = Colors.orange.shade900;
                              badgeIcon = Icons.replay_rounded;
                              badgeText = 'REFUNDED';
                            } else if (isPartial) {
                              badgeBg = Colors.amber.shade50;
                              badgeBorder = Colors.amber.shade300;
                              badgeTextColor = Colors.amber.shade900;
                              badgeIcon = Icons.timelapse_rounded;
                              badgeText = 'PARTIAL';
                            } else if (isPending) {
                              badgeBg = Colors.orange.shade50;
                              badgeBorder = Colors.orange.shade300;
                              badgeTextColor = Colors.orange.shade900;
                              badgeIcon = Icons.hourglass_top_rounded;
                              badgeText = 'PENDING';
                            } else {
                              badgeBg = Colors.green.shade50;
                              badgeBorder = Colors.green.shade300;
                              badgeTextColor = Colors.green.shade900;
                              badgeIcon = Icons.check_circle_rounded;
                              badgeText = 'PAID';
                            }

                            return Opacity(
                              opacity: isInactive ? 0.72 : 1.0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showPaymentActionSheet(context, payment, s, libraryId),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isVoided
                                              ? Colors.red.shade50
                                              : (isRefunded
                                                  ? Colors.orange.shade50
                                                  : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)),
                                          border: Border.all(
                                            color: isVoided
                                                ? Colors.red.shade200
                                                : (isRefunded ? Colors.orange.shade200 : Colors.transparent),
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isVoided
                                              ? Icons.block_rounded
                                              : (isRefunded ? Icons.money_off_rounded : Icons.receipt_long_rounded),
                                          color: isVoided
                                              ? Colors.red.shade700
                                              : (isRefunded ? Colors.orange.shade700 : Theme.of(context).colorScheme.primary),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '₹${payment.amount.toStringAsFixed(0)} • ${payment.method}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                decoration: isInactive ? TextDecoration.lineThrough : null,
                                                decorationColor: isVoided
                                                    ? Colors.red.shade700
                                                    : (isRefunded ? Colors.orange.shade700 : null),
                                                decorationThickness: 2,
                                                color: isInactive ? Colors.grey.shade600 : null,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              DateFormat.yMMMd().format(payment.date) +
                                                  (payment.installmentNumber != null
                                                      ? ' • Inst #${payment.installmentNumber}'
                                                      : '') +
                                                  (payment.remainingDue != null && payment.remainingDue! > 0
                                                      ? ' (Due: ₹${payment.remainingDue!.toStringAsFixed(0)})'
                                                      : ''),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: badgeBorder),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(badgeIcon, size: 10, color: badgeTextColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              badgeText,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: badgeTextColor,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ); // close Scaffold

    if (widget.isEmbeddedInSplitView) {
      return scaffoldContent;
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/admin/students');
        }
      },
      child: scaffoldContent,
    );
  }


  Widget _buildGovIdRow(BuildContext context, String type, String number) {
    String masked;
    final cleanDigits = number.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length >= 4) {
      final last4 = cleanDigits.substring(cleanDigits.length - 4);
      masked = type.contains('AADHAAR') ? '•••• •••• $last4' : '••••••$last4';
    } else if (number.length > 4 && !number.contains('=')) {
      final last4 = number.substring(number.length - 4);
      masked = '•••• $last4';
    } else {
      masked = '•••• •••• ••••';
    }

    final displayVal = _isGovIdVisible ? number : masked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              type,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              displayVal,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: _isGovIdVisible ? 0.5 : 1.5,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isGovIdVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: Colors.grey.shade700,
            ),
            tooltip: _isGovIdVisible ? 'Hide ID' : 'Show ID',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _isGovIdVisible = !_isGovIdVisible),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
            tooltip: 'Copy ID',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$type copied to clipboard!'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGovIdDocCard(BuildContext context, StudentModel s) {
    final front = s.govIdImageUrl;
    final back = s.govIdBackImageUrl ?? "";
    final hasDoc = front.isNotEmpty || back.isNotEmpty;
    final effectiveLibId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.document_scanner_rounded, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  hasDoc ? '${s.govIdType.displayName} Document Attached' : 'Government ID Document',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    AdminDocumentStudioDialog.show(
                      context,
                      documentTitle: '${s.name} - ${s.govIdType.displayName}',
                      imageUrl: front.isNotEmpty ? front : (back.isNotEmpty ? back : ""),
                      backImageUrl: back.isNotEmpty ? back : null,
                      initialGovIdType: s.govIdType.name,
                      initialGovIdNumber: s.govIdNumber,
                      libraryId: effectiveLibId,
                      studentId: s.id,
                      onDocumentUpdated: _loadStudent,
                    );
                  },
                  icon: Icon(hasDoc ? Icons.auto_fix_high_rounded : Icons.add_photo_alternate_rounded, size: 14),
                  label: Text(hasDoc ? 'Document Studio' : 'Scan / Attach ID', style: const TextStyle(fontSize: 11.5)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            if (hasDoc) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (front.isNotEmpty)
                    InkWell(
                      onTap: () {
                        AdminDocumentStudioDialog.show(
                          context,
                          documentTitle: '${s.name} - Front ID',
                          imageUrl: front,
                          backImageUrl: back.isNotEmpty ? back : null,
                          initialGovIdType: s.govIdType.name,
                          initialGovIdNumber: s.govIdNumber,
                          libraryId: effectiveLibId,
                          studentId: s.id,
                          onDocumentUpdated: _loadStudent,
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 70,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ImageService.buildImageWidget(
                            front,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  if (front.isNotEmpty && back.isNotEmpty) const SizedBox(width: 8),
                  if (back.isNotEmpty)
                    InkWell(
                      onTap: () {
                        AdminDocumentStudioDialog.show(
                          context,
                          documentTitle: '${s.name} - Back ID',
                          imageUrl: back.isNotEmpty ? back : "",
                          backImageUrl: back,
                          initialGovIdType: s.govIdType.name,
                          initialGovIdNumber: s.govIdNumber,
                          libraryId: effectiveLibId,
                          studentId: s.id,
                          onDocumentUpdated: _loadStudent,
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 70,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ImageService.buildImageWidget(
                            back,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tap thumbnail to view, rotate, filter, crop or replace document.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _sanitizeDisplayNote(String? rawNote, StudentModel s) {
    if (rawNote == null || rawNote.trim().isEmpty) return '';
    var note = rawNote;
    // Strip raw technical Firestore IDs in parentheses (e.g. (Gjq8iLM9sZ7W1y2OlZ2S))
    note = note.replaceAll(RegExp(r'\s*\([A-Za-z0-9_-]{15,}\)'), '');

    // If student has paid up or is active, strip legacy "Pending Fee Payment" / "Pay at Reception"
    if (s.membershipStatus == MembershipStatus.active || (s.pendingDueBalance ?? 0) <= 0) {
      note = note
          .replaceAll(RegExp(r'\s*—\s*Pending Fee Payment', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*Pending Fee Payment', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*—\s*Pay at Reception', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*Pay at Reception', caseSensitive: false), '');
    }

    note = note.replaceAll(RegExp(r'^[\s—•-]+|[\s—•-]+$'), '').trim();
    if (note.isEmpty) {
      return (rawNote.contains('Approved via App') || rawNote.contains('Approved via Student App'))
          ? 'Approved via Student App'
          : '';
    }
    return note;
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Widget? trailingAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          if (trailingAction != null) ...[
            const SizedBox(width: 8),
            trailingAction,
          ],
        ],
      ),
    );
  }

  Future<void> _showQuickEditNotesDialog(BuildContext context, StudentModel s) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    if (libraryId.isEmpty) return;

    final cleanInitialNote = _sanitizeDisplayNote(s.notes, s);
    final controller = TextEditingController(text: cleanInitialNote);
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hadDirtyNotes = s.notes != null && s.notes != cleanInitialNote;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Student Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add internal administrative remarks or clear previous notes.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                if (hadDirtyNotes) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade700),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Auto-Cleaned legacy raw ID & outdated pending note',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 2,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter student notes or remarks...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (s.notes != null && s.notes!.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('Clear', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('students')
                        .doc(s.id)
                        .update({
                      'notes': FieldValue.delete(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Note cleared successfully.')),
                      );
                      _loadStudent();
                    }
                  } catch (e) {
                    if (mounted) {
                      AppErrorFormatter.showErrorSnackBar(messenger.context, e, actionContext: 'student');
                    }
                  }
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newNotes = controller.text.trim();
                Navigator.pop(ctx);
                try {
                  await FirebaseFirestore.instance
                      .collection('libraries')
                      .doc(libraryId)
                      .collection('students')
                      .doc(s.id)
                      .update({
                    'notes': newNotes.isEmpty ? FieldValue.delete() : newNotes,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Notes updated successfully.')),
                    );
                    _loadStudent();
                  }
                } catch (e) {
                  if (mounted) {
                    AppErrorFormatter.showErrorSnackBar(messenger.context, e, actionContext: 'student');
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppPaymentLedger(StudentModel s, String libraryId) async {
    final phone = s.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number recorded for student.')),
      );
      return;
    }

    try {
      final paymentsSnap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('payments')
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      double totalPaid = 0.0;
      final historyLines = <String>[];
      for (final doc in paymentsSnap.docs) {
        final data = doc.data();
        if (data['status'] == 'refunded') continue;
        final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
        totalPaid += amt;
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final method = data['method'] ?? 'Paid';
        historyLines.add('• ₹${amt.toStringAsFixed(0)} on ${DateFormat('dd MMM yyyy').format(date)} ($method)');
      }

      final lib = ref.read(currentLibraryProvider).value;
      final libName = lib?.name.isNotEmpty == true ? lib!.name : 'The Cozy Corner Study Centre';

      final buf = StringBuffer()
        ..writeln('📜 *Payment & Dues Statement — $libName*')
        ..writeln()
        ..writeln('Dear *${s.name}*,')
        ..writeln('Here is your verified fee statement summary:')
        ..writeln()
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💰 *ACCOUNT SUMMARY*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💳 *Total Paid to Date:* ₹${totalPaid.toStringAsFixed(0)}')
        ..writeln('⚠️ *Pending Due Balance:* ₹${(s.pendingDueBalance ?? 0.0).toStringAsFixed(0)}')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━\n')
        ..writeln('🧾 *Recent Transactions:*');

      for (final line in historyLines) {
        buf.writeln(line);
      }

      buf.writeln('\nOfficial receipts are generated for all recorded installments. Thank you! 🙏');

      if (mounted) {
        await WhatsAppService().sendMessage(
          phone,
          buf.toString(),
          context: context,
          recipientName: s.name,
          title: 'Student Payment Ledger',
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'receipt');
      }
    }
  }

  Future<void> _showPaymentActionSheet(
    BuildContext context,
    PaymentModel payment,
    StudentModel s,
    String libraryId,
  ) async {
    final theme = Theme.of(context);
    // Compute a human-readable receipt number for display
    final displayReceiptNum = payment.receiptNumber ??
        (payment.receiptId != null && payment.receiptId!.startsWith('REC-')
            ? payment.receiptId
            : null);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Details',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${payment.amount.toStringAsFixed(0)} • ${payment.method} • ${DateFormat.yMMMd().format(payment.date)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                          if (displayReceiptNum != null)
                            Text(
                              'Receipt: $displayReceiptNum',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (payment.status == PaymentStatus.voided || payment.status == PaymentStatus.cancelled)
                            ? Colors.red.shade50
                            : (payment.status == PaymentStatus.refunded
                                ? Colors.orange.shade50
                                : (payment.status == PaymentStatus.paid ? Colors.green.shade50 : Colors.amber.shade50)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (payment.status == PaymentStatus.voided || payment.status == PaymentStatus.cancelled)
                              ? Colors.red.shade300
                              : (payment.status == PaymentStatus.refunded
                                  ? Colors.orange.shade300
                                  : (payment.status == PaymentStatus.paid ? Colors.green.shade300 : Colors.amber.shade300)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (payment.status == PaymentStatus.voided || payment.status == PaymentStatus.cancelled)
                                ? Icons.block_rounded
                                : (payment.status == PaymentStatus.refunded
                                    ? Icons.replay_rounded
                                    : (payment.status == PaymentStatus.paid ? Icons.check_circle_rounded : Icons.timelapse_rounded)),
                            size: 11,
                            color: (payment.status == PaymentStatus.voided || payment.status == PaymentStatus.cancelled)
                                ? Colors.red.shade900
                                : (payment.status == PaymentStatus.refunded
                                    ? Colors.orange.shade900
                                    : (payment.status == PaymentStatus.paid ? Colors.green.shade900 : Colors.amber.shade900)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            payment.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: (payment.status == PaymentStatus.voided || payment.status == PaymentStatus.cancelled)
                                  ? Colors.red.shade900
                                  : (payment.status == PaymentStatus.refunded
                                      ? Colors.orange.shade900
                                      : (payment.status == PaymentStatus.paid ? Colors.green.shade900 : Colors.amber.shade900)),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (payment.remainingDue != null && payment.remainingDue! > 0) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Remaining Due: ₹${payment.remainingDue!.toStringAsFixed(0)}${payment.installmentNumber != null ? " • Installment #${payment.installmentNumber}" : ""}',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const Divider(height: 24),

              // 0. Edit / Modify Payment Details
              ListTile(
                leading: Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
                title: const Text('Edit / Modify Payment Details'),
                subtitle: const Text('Correct amount, payment date, method, or notes'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditPaymentScreen(
                        payment: payment,
                        student: s,
                        libraryId: libraryId,
                        receiptNumber: displayReceiptNum,
                      ),
                    ),
                  );
                },
              ),

              // 1. View / Print PDF Receipt
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                title: const Text('View & Print Official PDF Receipt'),
                subtitle: const Text('Render high-resolution GST compliant receipt'),
                onTap: () async {
                  Navigator.pop(ctx);
                  String? receiptId = payment.receiptId;
                  if (receiptId == null || receiptId.isEmpty) {
                    final rSnap = await FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('receipts')
                        .where('studentId', isEqualTo: payment.studentId)
                        .limit(5)
                        .get();
                    if (rSnap.docs.isNotEmpty) {
                      receiptId = rSnap.docs.first.id;
                    }
                  }
                  if (context.mounted) {
                    if (receiptId != null && receiptId.isNotEmpty) {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => ReceiptPreviewScreen(receiptId: receiptId!),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receipt record not found for this payment')),
                      );
                    }
                  }
                },
              ),

              // 2. Resend via WhatsApp
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green),
                title: const Text('Resend Receipt via WhatsApp'),
                subtitle: const Text('1-tap WhatsApp wa.me prefilled message'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final phone = s.phone.trim();
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Student has no phone number recorded')),
                    );
                    return;
                  }
                  final libDoc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).get();
                  final libName = libDoc.data()?['name'] as String? ?? 'Cozy Corner Library';
                  final rNum = payment.receiptNumber ?? (payment.receiptId != null && payment.receiptId!.startsWith('REC-') ? payment.receiptId! : '#${payment.id.substring(0, payment.id.length >= 6 ? 6 : payment.id.length).toUpperCase()}');
                  final libModel = ref.read(currentLibraryProvider).value;
                  if (context.mounted) {
                    await WhatsAppService().sendPaymentConfirmation(
                      phone,
                      s.name,
                      libName,
                      payment.amount,
                      rNum,
                      adminTemplate: libModel?.effectiveReceiptTemplate,
                      libraryHelpline: libModel?.phone,
                      context: context,
                    );
                  }
                },
              ),

              // 3. Resend via Direct SMS
              ListTile(
                leading: const Icon(Icons.sms_rounded, color: Colors.blue),
                title: const Text('Resend Receipt via Direct SMS'),
                subtitle: const Text('Native SIM dispatch (100% Free)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final phone = s.phone.trim();
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Student has no phone number recorded')),
                    );
                    return;
                  }
                  final libDoc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).get();
                  final libName = libDoc.data()?['name'] as String? ?? 'Cozy Corner';
                  final rNum = payment.receiptNumber ?? (payment.receiptId != null && payment.receiptId!.startsWith('REC-') ? payment.receiptId! : '#${payment.id.substring(0, payment.id.length >= 6 ? 6 : payment.id.length).toUpperCase()}');
                  final ok = await ref.read(smsServiceProvider).sendPaymentReceiptSms(
                    phone: phone,
                    studentName: s.name,
                    libraryName: libName,
                    amount: payment.amount,
                    receiptNumber: rNum,
                    remainingDue: payment.remainingDue,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'SMS Receipt Dispatched! 📩' : 'SMS could not be sent directly.'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
              ),

              // 4. Resend via Telegram
              ListTile(
                leading: const Icon(Icons.send_rounded, color: Colors.lightBlue),
                title: const Text('Resend Receipt via Telegram'),
                subtitle: const Text('Send to staff group or student handle'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final msgHub = ref.read(messagingHubServiceProvider);
                  final config = await msgHub.getConfig(libraryId);
                  if (!config.telegramEnabled || config.telegramBotToken.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Telegram is not configured in Settings > Messaging')),
                      );
                    }
                    return;
                  }
                  final libDoc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).get();
                  final libName = libDoc.data()?['name'] as String? ?? 'Cozy Corner';
                  final rNum = payment.receiptNumber ?? (payment.receiptId != null && payment.receiptId!.startsWith('REC-') ? payment.receiptId! : '#${payment.id.substring(0, payment.id.length >= 6 ? 6 : payment.id.length).toUpperCase()}');
                  final ok = await ref.read(telegramServiceProvider).sendPaymentAlert(
                    botToken: config.telegramBotToken,
                    chatId: config.telegramChatId,
                    studentName: s.name,
                    libraryName: libName,
                    amount: payment.amount,
                    receiptNumber: rNum,
                    paymentMethod: payment.method,
                    remainingDue: payment.remainingDue,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Telegram Receipt Dispatched! 🚀' : 'Failed to send via Telegram.'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
              ),

              // 5. Void Status or Void Action
              if (payment.status == PaymentStatus.voided ||
                  payment.status == PaymentStatus.cancelled ||
                  payment.status == PaymentStatus.refunded) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This transaction is already ${payment.status.name.toUpperCase()}. It is excluded from library revenue.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  title: const Text('Void / Cancel Payment', style: TextStyle(color: Colors.redAccent)),
                  subtitle: const Text('Marks payment voided and restores student due balance'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Void Payment?'),
                        content: Text('Are you sure you want to void this ₹${payment.amount.toStringAsFixed(0)} payment? This will mark the record as VOIDED and restore the pending balance.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Void Payment'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('payments')
                          .doc(payment.id)
                          .update({'status': PaymentStatus.voided.name, 'updatedAt': FieldValue.serverTimestamp()});

                      // If student had pending balance, restore it
                      final newDue = (s.pendingDueBalance ?? 0.0) + payment.amount;
                      await FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('students')
                          .doc(s.id)
                          .update({'pendingDueBalance': newDue, 'updatedAt': FieldValue.serverTimestamp()});

                      AuditLogger().log(
                        action: AuditAction.deleted,
                        entityType: AuditEntity.payment,
                        libraryId: libraryId,
                        entityId: payment.id,
                        details: {'voidedAmount': payment.amount, 'studentId': s.id},
                      ).ignore();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment marked as VOIDED.'), backgroundColor: Colors.orange),
                        );
                      }
                    }
                  },
                ),
              ],

              // 6. Move to Recycle Bin (Permanent soft-delete, 30 days recovery)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Move to Recycle Bin', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Removes payment and stores in Recycle Bin for 30 days'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Move Payment to Recycle Bin?'),
                      content: Text('Are you sure you want to delete this ₹${payment.amount.toStringAsFixed(0)} payment? It will be stored in the Recycle Bin and can be restored anytime within 30 days.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Move to Bin'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final now = DateTime.now();
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final binData = {
                      'id': payment.id,
                      'name': 'Payment ₹${payment.amount.toStringAsFixed(0)} (${payment.method})',
                      'displayName': 'Payment ₹${payment.amount.toStringAsFixed(0)} (${s.name})',
                      'type': 'payment',
                      'libraryId': libraryId,
                      'studentId': s.id,
                      'amount': payment.amount,
                      'method': payment.method,
                      'date': payment.date.toIso8601String(),
                      'deletedAt': now.toIso8601String(),
                      'deletedBy': currentUser?.email ?? currentUser?.uid ?? 'admin',
                      'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
                      'originalData': payment.toJson(),
                    };

                    final batch = FirebaseFirestore.instance.batch();
                    final binRef = FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('recycle_bin')
                        .doc(payment.id);
                    batch.set(binRef, binData);

                    final payRef = FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('payments')
                        .doc(payment.id);
                    batch.delete(payRef);

                    // If active payment is deleted, restore due balance on student
                    if (payment.status != PaymentStatus.voided &&
                        payment.status != PaymentStatus.refunded &&
                        payment.status != PaymentStatus.cancelled) {
                      final newDue = (s.pendingDueBalance ?? 0.0) + payment.amount;
                      final studentRef = FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('students')
                          .doc(s.id);
                      batch.update(studentRef, {
                        'pendingDueBalance': newDue,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    }

                    await batch.commit();

                    AuditLogger().log(
                      action: AuditAction.deleted,
                      entityType: AuditEntity.payment,
                      libraryId: libraryId,
                      entityId: payment.id,
                      details: {'amount': payment.amount, 'studentId': s.id},
                    ).ignore();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment moved to Recycle Bin (available in Receipts & Payments tab).'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionItem extends ConsumerWidget {
  final SectionModel section;
  final String studentId;
  final VoidCallback onSeatAssigned;

  const _SectionItem({
    required this.section,
    required this.studentId,
    required this.onSeatAssigned,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatsAsync = ref.watch(seatsProvider(section.id));

    return ExpansionTile(
      title: Text(section.name),
      children: [
        seatsAsync.when(
          data: (seats) {
            final availableSeats = seats.where((s) => s.status == SeatStatus.available).toList();
            if (availableSeats.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No available seats in this section.'),
              );
            }
            return Wrap(
              spacing: 8,
              children: availableSeats.map((seat) {
                return ActionChip(
                  label: Text(seat.label),
                  onPressed: () async {
                    final libraryId = ref.read(currentLibraryIdProvider);
                    if (libraryId == null) return;

                    // Assign student through SeatRepository which atomically releases
                    // any old/duplicate seat the student previously occupied!
                    await ref.read(seatRepositoryProvider).assignStudent(
                          libraryId,
                          section.id,
                          seat.id,
                          studentId,
                        );

                    AuditLogger().log(
                      action: AuditAction.updated,
                      entityType: AuditEntity.student,
        libraryId: libraryId,
                      entityId: studentId,
                      details: {'seatAssigned': true, 'seatId': seat.id, 'sectionId': section.id},
                    ).ignore();

                    onSeatAssigned();
                  },
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading seats: $err'),
          ),
        ),
      ],
    );
  }
}
