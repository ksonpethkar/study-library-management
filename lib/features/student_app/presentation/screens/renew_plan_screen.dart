import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/expiry_scheduler_service.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/error/error_handler.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';

enum RenewalTiming { advance, immediate }
enum RenewalPaymentMode { upi, bank, deskCash }

class RenewPlanScreen extends ConsumerStatefulWidget {
  const RenewPlanScreen({super.key});

  @override
  ConsumerState<RenewPlanScreen> createState() => _RenewPlanScreenState();
}

class _RenewPlanScreenState extends ConsumerState<RenewPlanScreen> {
  String? _selectedPlanId;
  bool _keepSeat = true;
  RenewalTiming _timingMode = RenewalTiming.advance;
  RenewalPaymentMode _paymentMode = RenewalPaymentMode.upi;

  final _notesController = TextEditingController();
  final _transactionRefController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    _transactionRefController.dispose();
    super.dispose();
  }

  DateTime _computeCycleStartDate(StudentModel student) {
    final now = DateTime.now();
    final isCurrentActive = student.planEndDate != null && student.planEndDate!.isAfter(now);

    if (isCurrentActive && _timingMode == RenewalTiming.advance) {
      final currentEnd = student.planEndDate!;
      return DateTime(currentEnd.year, currentEnd.month, currentEnd.day + 1);
    }
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _computeCycleEndDate(DateTime startDate, PlanModel plan) {
    return PlanCalculatorService.calculatePlanEndDate(startDate, plan.duration, plan.durationUnit);
  }

  Future<void> _submitRenewal({
    required String libraryId,
    required StudentModel student,
    required PlanModel selectedPlan,
    required double? origPrice,
    required bool hasDiscount,
  }) async {
    if ((_paymentMode == RenewalPaymentMode.upi || _paymentMode == RenewalPaymentMode.bank) &&
        _transactionRefController.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_paymentMode == RenewalPaymentMode.upi
              ? 'Please enter your 12-digit UPI UTR / Transaction Reference number'
              : 'Please enter your Bank Transfer UTR / Transaction Reference number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final startDate = _computeCycleStartDate(student);
      final endDate = _computeCycleEndDate(startDate, selectedPlan);
      final isAdvance = student.planEndDate != null &&
          student.planEndDate!.isAfter(DateTime.now()) &&
          _timingMode == RenewalTiming.advance;

      final paymentMethodStr = _paymentMode == RenewalPaymentMode.upi
          ? 'upi'
          : (_paymentMode == RenewalPaymentMode.bank ? 'bank' : 'desk_cash');
      final paymentLabelStr = _paymentMode == RenewalPaymentMode.upi
          ? 'UPI / QR Code'
          : (_paymentMode == RenewalPaymentMode.bank
              ? 'Direct Bank Transfer (NEFT/IMPS)'
              : 'Pay at Desk / Reception');
      final refNumberStr = _paymentMode == RenewalPaymentMode.deskCash
          ? 'Desk Cash Payment Requested'
          : _transactionRefController.text.trim();
      final statusStr = _paymentMode == RenewalPaymentMode.deskCash
          ? 'desk_payment_pending'
          : 'pending';

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .add({
        'type': 'renewal',
        'studentId': student.id,
        'studentName': student.name,
        'studentPhone': student.phone,
        'studentUserId': student.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
        'userId': FirebaseAuth.instance.currentUser?.uid ?? student.userId ?? '',
        'requestedPlanId': selectedPlan.id,
        'requestedPlanName': selectedPlan.name,
        'amount': selectedPlan.price,
        'originalPrice': origPrice,
        'discountAmount': hasDiscount && origPrice != null ? (origPrice - selectedPlan.price) : 0.0,
        'currentSeatId': student.seatId,
        'keepSeat': _keepSeat,
        'isAdvanceRenewal': isAdvance,
        'cycleStartDate': Timestamp.fromDate(startDate),
        'cycleEndDate': Timestamp.fromDate(endDate),
        'paymentMethod': paymentMethodStr,
        'paymentModeLabel': paymentLabelStr,
        'referenceNumber': refNumberStr,
        'notes': _notesController.text.trim(),
        'status': statusStr,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Cancel local expiry reminders until renewed cycle begins
      ExpirySchedulerService.cancelExpiryReminders().ignore();

      if (mounted) {
        HapticFeedback.heavyImpact();
        final successMsg = _paymentMode == RenewalPaymentMode.deskCash
            ? 'Desk payment renewal registered! Please deposit fee at the reception counter to activate.'
            : (_paymentMode == RenewalPaymentMode.bank
                ? 'Bank transfer renewal request submitted! Library admin will verify your payment and activate your seat.'
                : 'Renewal request submitted! Library admin will verify your payment and activate your membership.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit renewal request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final libraryId = ref.watch(currentLibraryIdProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Renew Membership'),
        centerTitle: true,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null || libraryId == null) {
            return const Center(child: Text('Student profile not found. Please log in again.'));
          }

          return plansAsync.when(
            data: (plans) {
              final activePlans = plans.where((p) => p.isActive).toList();

              if (_selectedPlanId == null && activePlans.isNotEmpty) {
                // Default to current plan if active, else first active plan
                final currentMatches = activePlans.any((p) => p.id == student.planId);
                _selectedPlanId = currentMatches ? student.planId : activePlans.first.id;
              }

              final selectedPlan = activePlans.where((p) => p.id == _selectedPlanId).firstOrNull ??
                  (activePlans.isNotEmpty ? activePlans.first : null);

              final baseMonthly = PlanCalculatorService.getBaseMonthlyPrice(activePlans);

              final isCurrentPlanActive = student.planEndDate != null && student.planEndDate!.isAfter(DateTime.now());
              final startDate = selectedPlan != null ? _computeCycleStartDate(student) : DateTime.now();
              final endDate = selectedPlan != null ? _computeCycleEndDate(startDate, selectedPlan) : DateTime.now();

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Current Plan Status Summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrentPlanActive
                          ? Colors.teal.withValues(alpha: 0.08)
                          : Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrentPlanActive
                            ? Colors.teal.withValues(alpha: 0.3)
                            : Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isCurrentPlanActive ? Colors.teal : Colors.orange,
                          radius: 20,
                          child: Icon(
                            isCurrentPlanActive ? Icons.verified_rounded : Icons.history_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCurrentPlanActive ? 'Current Membership Active' : 'Membership Expired',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentPlanActive ? Colors.teal.shade800 : Colors.orange.shade900,
                                ),
                              ),
                              if (student.planEndDate != null)
                                Text(
                                  isCurrentPlanActive
                                      ? 'Valid until ${dateFormat.format(student.planEndDate!)} • ${SeatHelper.formatSeatLabel(seatId: student.seatId)}'
                                      : 'Expired on ${dateFormat.format(student.planEndDate!)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section Header: Available Plans
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Select Renewal Plan',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (activePlans.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('No active study plans configured by library.')),
                      ),
                    )
                  else
                    ...activePlans.map((plan) {
                      final isSelected = _selectedPlanId == plan.id;
                      final origPrice = plan.getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthly);
                      final discPercent = plan.getDiscountPercent(baseMonthlyPrice: baseMonthly);
                      final savings = plan.getSavingsAmount(baseMonthlyPrice: baseMonthly);
                      final hasDiscount = origPrice != null && origPrice > plan.price;
                      final dailyRate = PlanCalculatorService.getDailyRate(plan);

                      return PressableScale(
                        scaleFactor: 0.97,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedPlanId = plan.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
                                : theme.colorScheme.surface,
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      theme.colorScheme.primaryContainer.withValues(alpha: 0.38),
                                      theme.colorScheme.surface,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Custom Animated Radio Check Indicator
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, right: 8),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                                          width: isSelected ? 2 : 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Center(
                                              child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              plan.displayName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            if (plan.isFeatured) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.amber.withValues(alpha: 0.3),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: const Text(
                                                  'POPULAR',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${plan.duration} ${plan.durationUnit.name} • ₹${dailyRate.toStringAsFixed(1)}/day',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                        if (plan.description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            plan.description,
                                            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Pricing display with MRP Strikethrough & Discount %
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (hasDiscount) ...[
                                        Text(
                                          '₹${origPrice.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: Colors.grey.shade500,
                                            color: Colors.grey.shade500,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                      ],
                                      Text(
                                        '₹${plan.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: hasDiscount ? Colors.green.shade800 : theme.colorScheme.onSurface,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      if (hasDiscount && discPercent != null) ...[
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            border: Border.all(color: Colors.green.shade600, width: 0.8),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$discPercent% OFF',
                                            style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              if (hasDiscount && savings != null && savings > 0) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 30),
                                  child: Text(
                                    (plan.durationUnit == DurationUnit.months && plan.duration > 1) ||
                                            (plan.durationUnit == DurationUnit.days && plan.duration > 31)
                                        ? '🎉 Save ₹${savings.toStringAsFixed(0)} compared to paying monthly'
                                        : '🎉 Save ₹${savings.toStringAsFixed(0)} with special library discount',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),

                  // Advance Renewal Timing Selection (When membership is still active)
                  if (isCurrentPlanActive) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Renewal Timing',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          // ignore: deprecated_member_use
                          RadioListTile<RenewalTiming>(
                            value: RenewalTiming.advance,
                            // ignore: deprecated_member_use
                            groupValue: _timingMode,
                            // ignore: deprecated_member_use
                            onChanged: (val) {
                              if (val != null) {
                                HapticFeedback.selectionClick();
                                setState(() => _timingMode = val);
                              }
                            },
                            title: const Text('Advance Renewal (Continuous Study)', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Starts on ${dateFormat.format(DateTime(student.planEndDate!.year, student.planEndDate!.month, student.planEndDate!.day + 1))} (Current plan active till ${dateFormat.format(student.planEndDate!)}). Zero study days lost.',
                            ),
                          ),
                          const Divider(height: 1),
                          // ignore: deprecated_member_use
                          RadioListTile<RenewalTiming>(
                            value: RenewalTiming.immediate,
                            // ignore: deprecated_member_use
                            groupValue: _timingMode,
                            // ignore: deprecated_member_use
                            onChanged: (val) {
                              if (val != null) {
                                HapticFeedback.selectionClick();
                                setState(() => _timingMode = val);
                              }
                            },
                            title: const Text('Start Immediately (From Today)', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Starts today (${dateFormat.format(DateTime.now())}). Resets your membership cycle.'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Calculated New Membership Cycle Banner
                  if (selectedPlan != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('New Membership Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text(
                                  '${dateFormat.format(startDate)}  →  ${dateFormat.format(endDate)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${selectedPlan.duration} ${selectedPlan.durationUnit.name}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Keep Seat Toggle
                  if (student.seatId != null)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: SwitchListTile(
                        title: Text('Keep My Allocated ${SeatHelper.formatSeatLabel(seatId: student.seatId)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Retain your desk upon renewal approval'),
                        value: _keepSeat,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _keepSeat = val);
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Section Header: Payment Mode Selection
                  Row(
                    children: [
                      Icon(Icons.payments_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Option',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Payment Method Switcher (UPI vs Bank vs Pay at Desk)
                  SegmentedButton<RenewalPaymentMode>(
                    segments: const [
                      ButtonSegment(
                        value: RenewalPaymentMode.upi,
                        icon: Icon(Icons.qr_code_2_rounded),
                        label: Text('UPI / QR'),
                      ),
                      ButtonSegment(
                        value: RenewalPaymentMode.bank,
                        icon: Icon(Icons.account_balance_rounded),
                        label: Text('Bank Transfer'),
                      ),
                      ButtonSegment(
                        value: RenewalPaymentMode.deskCash,
                        icon: Icon(Icons.storefront_rounded),
                        label: Text('Pay at Desk'),
                      ),
                    ],
                    selected: {_paymentMode},
                    onSelectionChanged: (newSelection) {
                      HapticFeedback.selectionClick();
                      setState(() => _paymentMode = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Dynamic Payment Data Stream
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('settings')
                        .doc('payment_methods')
                        .snapshots(),
                    builder: (context, paySnap) {
                      final library = ref.watch(currentLibraryProvider).value;
                      final payData = paySnap.data?.data() ?? {};

                      final planPriceStr = selectedPlan != null ? selectedPlan.price.toStringAsFixed(0) : '0';

                      // Merchant Contact Info
                      final rawContactPhone = (library?.contact.isNotEmpty == true
                              ? library!.contact
                              : (library?.whatsappNumber ?? ''))
                          .replaceAll(RegExp(r'\D'), '');
                      final merchantPhone = (payData['upiPhone']?.toString().isNotEmpty == true)
                          ? payData['upiPhone'].toString()
                          : rawContactPhone;

                      // Bank details map
                      final bankDetails = payData['bankDetails'] is Map
                          ? Map<String, dynamic>.from(payData['bankDetails'] as Map)
                          : <String, dynamic>{};
                      final bankName = bankDetails['bankName']?.toString() ?? '';
                      final accNo = bankDetails['accountNumber']?.toString() ?? '';
                      final ifsc = bankDetails['ifscCode']?.toString() ?? '';
                      final accHolder = bankDetails['accountHolder']?.toString() ?? (library?.name ?? 'Study Library');
                      final branch = bankDetails['branch']?.toString() ?? '';
                      final hasBankConfigured = bankName.isNotEmpty && accNo.isNotEmpty;

                      // Cash details map
                      final cashDetails = payData['cashDetails'] is Map
                          ? Map<String, dynamic>.from(payData['cashDetails'] as Map)
                          : <String, dynamic>{};
                      final deskTimings = cashDetails['timings']?.toString().isNotEmpty == true
                          ? cashDetails['timings'].toString()
                          : '8:00 AM – 10:00 PM (Daily)';
                      final deskInstructions = cashDetails['instructions']?.toString().isNotEmpty == true
                          ? cashDetails['instructions'].toString()
                          : 'You can pay in cash or swipe/scan directly when you visit the library. Submitting this renewal reserves your seat and study plan. The admin will confirm your payment at the reception desk.';

                      // Policies
                      final policies = payData['policies'] is Map
                          ? Map<String, dynamic>.from(payData['policies'] as Map)
                          : <String, dynamic>{};
                      final refundPolicy = policies['refundPolicy']?.toString() ?? '';

                      if (_paymentMode == RenewalPaymentMode.deskCash) {
                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      radius: 20,
                                      child: Icon(Icons.storefront_rounded, color: Colors.green.shade800),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Pay at Reception Desk',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Text(
                                            'Desk Hours: $deskTimings',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Fee to deposit at counter:', style: TextStyle(fontSize: 13)),
                                      AnimatedRollingPrice(
                                        targetPrice: selectedPlan?.price ?? 0,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  deskInstructions,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (_paymentMode == RenewalPaymentMode.bank) {
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00796B).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.account_balance_rounded, color: Color(0xFF00796B)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Direct Bank Transfer (NEFT / IMPS)',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Text(
                                            'Transfer ₹$planPriceStr directly to library bank account',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                if (hasBankConfigured) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: theme.colorScheme.outlineVariant),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Bank Name', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                Text(bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('Account Holder', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                Text(accHolder, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Account Number', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                Text(accNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                                              ],
                                            ),
                                            TactileCopyButton(
                                              copyText: accNo,
                                              successMessage: 'Account number copied!',
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('IFSC Code', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                Text(ifsc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                if (branch.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(right: 6.0),
                                                    child: Text('($branch)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                  ),
                                                TactileCopyButton(
                                                  copyText: ifsc,
                                                  successMessage: 'IFSC code copied!',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Action buttons row: Copy all details & WhatsApp screenshot share
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TactileCopyButton(
                                          copyText: 'Bank: $bankName\nAccount Holder: $accHolder\nA/C No: $accNo\nIFSC: $ifsc${branch.isNotEmpty ? "\nBranch: $branch" : ""}\nAmount: ₹$planPriceStr',
                                          successMessage: 'Full bank details copied to clipboard!',
                                          label: 'Copy Bank Details',
                                          icon: Icons.copy_all_rounded,
                                        ),
                                      ),
                                      if (merchantPhone.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton.tonalIcon(
                                            icon: const Icon(Icons.share_rounded, size: 16),
                                            label: const Text('Share Receipt'),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () async {
                                              final cleanPhone = merchantPhone.replaceAll(RegExp(r'\D'), '');
                                              final targetPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
                                              final waMsg = Uri.encodeComponent(
                                                'Hi, I have transferred ₹$planPriceStr for membership renewal.\nName: ${student.name}\nPlan: ${selectedPlan?.name ?? "Renewal"}\nUTR: ${_transactionRefController.text.trim()}',
                                              );
                                              final waUrl = Uri.parse('https://wa.me/$targetPhone?text=$waMsg');
                                              try {
                                                await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                                              } catch (_) {}
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.shade300),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Bank details have not been set by library admin yet. Please pay via UPI QR or at desk.',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),

                                // Bank UTR Reference Field
                                TextField(
                                  controller: _transactionRefController,
                                  decoration: const InputDecoration(
                                    labelText: 'Bank Transfer UTR / Ref No. *',
                                    hintText: 'e.g. 423589123456 or IMPS12345',
                                    prefixIcon: Icon(Icons.tag_rounded),
                                    border: OutlineInputBorder(),
                                    helperText: 'Enter transaction reference / UTR from your bank app after transfer',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Default: RenewalPaymentMode.upi
                      final customUpi = payData['upiId']?.toString();
                      final libUpi = library?.upiId;
                      final upiId = (customUpi != null && customUpi.isNotEmpty)
                          ? customUpi
                          : ((libUpi != null && libUpi.isNotEmpty)
                              ? libUpi
                              : (rawContactPhone.isNotEmpty ? '$rawContactPhone@upi' : 'library@upi'));

                      final payeeName = payData['payeeName']?.toString().isNotEmpty == true
                          ? payData['payeeName'].toString()
                          : (library?.name.isNotEmpty == true ? library!.name : 'Study Library');

                      final upiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$planPriceStr&cu=INR&tn=${Uri.encodeComponent("Renewal - ${student.name}")}';

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.qr_code_2_rounded, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text('Scan & Pay via UPI', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    QrImageView(
                                      data: upiUri,
                                      version: QrVersions.auto,
                                      size: 160.0,
                                      backgroundColor: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Pay ',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                        ),
                                        AnimatedRollingPrice(
                                          targetPrice: selectedPlan?.price ?? 0,
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87),
                                        ),
                                        Text(
                                          ' to $payeeName',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Google Pay • PhonePe • Paytm • BHIM • Any UPI',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('UPI ID: $upiId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    TactileCopyButton(
                                      copyText: upiId,
                                      successMessage: 'UPI ID copied to clipboard!',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Pay via UPI Native App Button
                              FilledButton.icon(
                                icon: const Icon(Icons.flash_on_rounded),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Pay '),
                                    AnimatedRollingPrice(
                                      targetPrice: selectedPlan?.price ?? 0,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const Text(' via UPI App'),
                                  ],
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  final uri = Uri.parse(upiUri);
                                  try {
                                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    if (!launched && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not launch UPI app directly. Please scan the QR code above or copy the UPI ID.'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('UPI payment notice: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              // UTR Reference Input Field
                              TextField(
                                controller: _transactionRefController,
                                decoration: const InputDecoration(
                                  labelText: 'UTR / Transaction Reference No. *',
                                  hintText: 'e.g. 423589123456',
                                  prefixIcon: Icon(Icons.tag_rounded),
                                  border: OutlineInputBorder(),
                                  helperText: 'Enter 12-digit UTR from your bank or UPI payment confirmation',
                                ),
                              ),

                              if (refundPolicy.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 14, color: theme.colorScheme.outline),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          refundPolicy,
                                          style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
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
                    },
                  ),
                  const SizedBox(height: 16),

                  // Special Note / Desk Request
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _paymentMode == RenewalPaymentMode.deskCash
                          ? 'Note for Reception Desk (Optional)'
                          : 'Special Note / Requests (Optional)',
                      hintText: 'e.g. Prefer morning shift, paid cash at desk, etc.',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  PressableScale(
                    scaleFactor: 0.96,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        label: _isSubmitting
                            ? const Text('Submitting...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _paymentMode == RenewalPaymentMode.deskCash
                                        ? 'Submit Desk Renewal ('
                                        : (_paymentMode == RenewalPaymentMode.bank
                                            ? 'Submit Bank Renewal ('
                                            : 'Submit Renewal ('),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  AnimatedRollingPrice(
                                    targetPrice: selectedPlan?.price ?? 0,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                                  ),
                                  const Text(')', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmitting || selectedPlan == null
                            ? null
                            : () {
                                final origPrice = selectedPlan.getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthly);
                                final hasDiscount = origPrice != null && origPrice > selectedPlan.price;
                                _submitRenewal(
                                  libraryId: libraryId,
                                  student: student,
                                  selectedPlan: selectedPlan,
                                  origPrice: origPrice,
                                  hasDiscount: hasDiscount,
                                );
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  ErrorHandler.handleError(err),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              ErrorHandler.handleError(err),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

/// A smooth, high-precision price counter that rolls numbers with authentic spring
/// interpolation and tabular figures when the user toggles between membership plans.
class AnimatedRollingPrice extends StatefulWidget {
  final double targetPrice;
  final TextStyle? style;
  final String prefix;

  const AnimatedRollingPrice({
    super.key,
    required this.targetPrice,
    this.style,
    this.prefix = '₹',
  });

  @override
  State<AnimatedRollingPrice> createState() => _AnimatedRollingPriceState();
}

class _AnimatedRollingPriceState extends State<AnimatedRollingPrice> {
  late double _oldPrice;

  @override
  void initState() {
    super.initState();
    _oldPrice = widget.targetPrice;
  }

  @override
  void didUpdateWidget(covariant AnimatedRollingPrice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetPrice != widget.targetPrice) {
      _oldPrice = oldWidget.targetPrice;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.targetPrice),
      tween: Tween<double>(begin: _oldPrice, end: widget.targetPrice),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '${widget.prefix}${value.round()}',
          style: (widget.style ?? const TextStyle()).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}

/// A tactile button that triggers micro-haptic feedback and morphs the copy icon
/// into an animated green checkmark with ripple confirmation.
class TactileCopyButton extends StatefulWidget {
  final String copyText;
  final String successMessage;
  final String? label;
  final IconData icon;

  const TactileCopyButton({
    super.key,
    required this.copyText,
    required this.successMessage,
    this.label,
    this.icon = Icons.copy_rounded,
  });

  @override
  State<TactileCopyButton> createState() => _TactileCopyButtonState();
}

class _TactileCopyButtonState extends State<TactileCopyButton> {
  bool _copied = false;

  void _onCopy() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.copyText));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text(widget.successMessage),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2000),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.label != null) {
      return PressableScale(
        scaleFactor: 0.95,
        onTap: _onCopy,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _copied ? Colors.green.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _copied ? Colors.green : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _copied ? Icons.check_rounded : widget.icon,
                  key: ValueKey(_copied),
                  size: 16,
                  color: _copied ? Colors.green.shade700 : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _copied ? 'Copied!' : widget.label!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _copied ? Colors.green.shade700 : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PressableScale(
      scaleFactor: 0.88,
      onTap: _onCopy,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _copied ? Colors.green.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _copied ? Icons.check_rounded : widget.icon,
            key: ValueKey(_copied),
            size: 18,
            color: _copied ? Colors.green.shade700 : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
