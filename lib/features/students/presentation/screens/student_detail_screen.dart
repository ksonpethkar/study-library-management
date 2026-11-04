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
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/services/sms_service.dart';
import 'package:study_library/services/telegram_service.dart';
import 'package:study_library/services/messaging_hub_service.dart';
import 'package:study_library/features/receipts/presentation/screens/receipt_preview_screen.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';
import 'package:study_library/features/requests/presentation/widgets/admin_document_studio_dialog.dart';

class StudentDetailScreen extends ConsumerStatefulWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

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
                whatsapp.sendWelcomeMessage(s.phone, s.name, libraryName, context: context);
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
                  whatsapp.sendExpiryReminder(s.phone, s.name, daysLeft, libraryName: libraryName, context: context);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign ID: $e'), backgroundColor: Colors.red),
      );
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
                          await FirebaseFirestore.instance
                              .collection('libraries')
                              .doc(libraryId)
                              .collection('students')
                              .doc(s.id)
                              .update({
                            'planEndDate': Timestamp.fromDate(freezeCalc.newEndDate),
                            'notes': '${(s.notes != null && s.notes!.isNotEmpty) ? "${s.notes}\n" : ""}[Freeze] Study Vacation: ${freezeCalc.freezeDays}d (${DateFormat('dd MMM').format(freezeStart)} - ${DateFormat('dd MMM').format(freezeEnd)}). Expiry extended to ${DateFormat('dd MMM yyyy').format(freezeCalc.newEndDate)}.',
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Membership freeze applied ✓ Plan extended to ${DateFormat('dd MMM yyyy').format(freezeCalc.newEndDate)}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadStudent();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to freeze membership: $e'), backgroundColor: Colors.red),
                            );
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

    if (!context.mounted) return;

    await showDialog(
      context: context,
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
                  child: Text('Early Exit & Settlement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fair pro-rata calculation based on exact calendar days used. The seat will be released upon exit.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: paidCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Paid (₹)',
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
                            decoration: const InputDecoration(
                              labelText: 'Processing Fee (₹)',
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
                              const Text('Fair Usage Fee:', style: TextStyle(fontSize: 13)),
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
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                label: const Text('Confirm Early Exit'),
                onPressed: () async {
                  try {
                    // 1. Release allocated seat if autoReleaseSeat is true
                    if (autoReleaseSeat && s.seatId != null && s.sectionId != null) {
                      try {
                        final seatRepo = ref.read(seatRepositoryProvider);
                        await seatRepo.unassignStudent(
                          libraryId: libraryId,
                          sectionId: s.sectionId!,
                          seatId: s.seatId!,
                          studentId: s.id,
                        );
                      } catch (e) {
                        debugPrint('Could not unassign seat: $e');
                      }
                    }

                    // 2. Mark student as inactive / exit
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
                      'notes': '${(s.notes != null && s.notes!.isNotEmpty) ? "${s.notes}\n" : ""}[Exit] Early exit on ${DateFormat('dd MMM yyyy').format(exitDate)}. Used: ${exitCalc.usedDays}/${exitCalc.totalCycleDays}d. Fair usage: ${exitCalc.formattedFairUsage}. Deducted Fee: ₹${processingFee.toStringAsFixed(0)}. Net Refund: ${exitCalc.formattedNetRefund}.',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    // 3. Record audit entry
                    AuditLogger().log(
                      action: AuditAction.updated,
                      entityType: AuditEntity.student,
                      entityId: s.id,
                      libraryId: libraryId,
                      details: {
                        'action': 'early_exit',
                        'studentName': s.name,
                        'netRefund': exitCalc.formattedNetRefund,
                      },
                    );

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Student exit processed ✓ Net refund: ${exitCalc.formattedNetRefund} • Seat released'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadStudent();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to process exit: $e'), backgroundColor: Colors.red),
                      );
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

                            // C2: Warn if student already has an active plan
                            if (student != null &&
                                student!.planId != null &&
                                student!.membershipStatus == MembershipStatus.active) {
                              final replace = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Replace Active Plan?'),
                                  content: Text(
                                    'This student already has an active plan.\n\n'
                                    'Assigning "${plan.name}" will override the current plan '
                                    'and reset the validity period.\n\nContinue?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Replace Plan'),
                                    ),
                                  ],
                                ),
                              );
                              if (replace != true) return;
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete: $e')),
            );
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

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Cannot pop (this screen is the root). Navigate to student list.
          context.go('/admin/students');
        }
      },
      child: Scaffold(
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
                      Chip(
                        label: Text(s.membershipStatus.name.toUpperCase()),
                        backgroundColor: _getStatusColor(s.membershipStatus).withValues(alpha: 0.15),
                        labelStyle: TextStyle(color: _getStatusColor(s.membershipStatus), fontWeight: FontWeight.bold, fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    child: OutlinedButton.icon(
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
                    if (s.notes != null && s.notes!.isNotEmpty)
                      _buildDetailRow(context, 'Notes', s.notes!, Icons.note_alt_outlined),
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
                            final isRefunded = payment.status == PaymentStatus.refunded;

                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _showPaymentActionSheet(context, payment, s, libraryId),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isRefunded
                                            ? Colors.red.shade50
                                            : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isRefunded ? Icons.money_off_rounded : Icons.receipt_long_rounded,
                                        color: isRefunded ? Colors.red : Theme.of(context).colorScheme.primary,
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
                                              decoration: isRefunded ? TextDecoration.lineThrough : null,
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
                                    Chip(
                                      label: Text(
                                        payment.status.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isRefunded ? Colors.red.shade900 : Colors.green.shade900,
                                        ),
                                      ),
                                      backgroundColor: isRefunded ? Colors.red.shade100 : Colors.green.shade100,
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                  ],
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
    ), // close Scaffold
    ); // close PopScope
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
                          child: Image(
                            image: ImageService.getImageProvider(front) ?? const AssetImage("assets/images/app_logo.png"),
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
                          child: Image(
                            image: ImageService.getImageProvider(back)!,
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

  Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon) {
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
        ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating statement: $e')),
        );
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
                    Chip(
                      label: Text(
                        payment.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: payment.status == PaymentStatus.paid ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                      backgroundColor: payment.status == PaymentStatus.paid
                          ? Colors.green.shade100
                          : Colors.red.shade100,
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
                  if (context.mounted) { await WhatsAppService().sendPaymentConfirmation(phone, s.name, libName, payment.amount, rNum, context: context); }
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

              // 5. Void Payment
              if (payment.status != PaymentStatus.refunded)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  title: const Text('Void / Cancel Payment', style: TextStyle(color: Colors.redAccent)),
                  subtitle: const Text('Marks payment refunded and restores student due balance'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Void Payment?'),
                        content: Text('Are you sure you want to void this ₹${payment.amount.toStringAsFixed(0)} payment? This will mark the record refunded.'),
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
                          .update({'status': PaymentStatus.refunded.name, 'updatedAt': FieldValue.serverTimestamp()});

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
                          const SnackBar(content: Text('Payment marked as void and refunded.'), backgroundColor: Colors.orange),
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
