import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/features/receipts/presentation/screens/receipt_preview_screen.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/constants/amenity_catalog.dart';
import 'package:study_library/core/utils/student_ledger_helper.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/features/student_app/presentation/widgets/silent_reception_help_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/features/settings/presentation/providers/settings_provider.dart';

class MyMembershipScreen extends ConsumerWidget {
  const MyMembershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final libraryId = ref.watch(currentLibraryIdProvider);
    final library = ref.watch(currentLibraryProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Home',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.studentHome),
        ),
        title: const Text('My Membership'),
        centerTitle: true,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge_outlined, size: 72, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Membership Found',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your account is not linked to an active student membership yet. Please register or contact your library administrator.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('requests')
                          .where('studentId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .where('status', isEqualTo: 'pending')
                          .limit(1)
                          .snapshots(),
                      builder: (context, snap) {
                        final hasPending = snap.data?.docs.isNotEmpty ?? false;
                        if (hasPending) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(children: const [
                                Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 48),
                                SizedBox(height: 8),
                                Text('Request Pending', style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Your seat request is waiting for admin approval.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                              ]),
                            ),
                          );
                        }
                        return FilledButton.icon(
                          icon: const Icon(Icons.app_registration_rounded),
                          label: const Text('Register for Seat'),
                          onPressed: () => context.push(Routes.studentRegister),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Match plan
          final plans = plansAsync.value ?? [];
          final currentPlan = plans.where((p) => p.id == student.planId).firstOrNull;
          final planName = currentPlan?.displayName ?? (student.planId != null ? 'Study Plan' : 'No Plan Assigned');
          final planPrice = currentPlan != null ? '₹${currentPlan.price.toStringAsFixed(0)}' : '';
          final baseMonthly = PlanCalculatorService.getBaseMonthlyPrice(plans);
          final origPrice = currentPlan?.getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthly);
          final discPercent = currentPlan?.getDiscountPercent(baseMonthlyPrice: baseMonthly);
          final saved = currentPlan?.getSavingsAmount(baseMonthlyPrice: baseMonthly);
          final hasDiscount = origPrice != null && currentPlan != null && origPrice > currentPlan.price;
          final dailyRate = currentPlan != null ? PlanCalculatorService.getDailyRate(currentPlan) : 0.0;
          final durationLabel = currentPlan != null
              ? (currentPlan.durationUnit == DurationUnit.months && currentPlan.duration == 1
                  ? '/ month'
                  : '/ ${currentPlan.duration} ${currentPlan.durationUnit.name}')
              : '/ month';

          // Dates
          final startDate = student.planStartDate;
          final endDate = student.planEndDate;
          final dateFormat = DateFormat('dd MMM yyyy');

          final now = DateTime.now();
          final daysRemaining = endDate != null ? endDate.difference(now).inDays : 0;
          final totalDays = (startDate != null && endDate != null)
              ? endDate.difference(startDate).inDays
              : 30;
          final progress = totalDays > 0
              ? (daysRemaining / totalDays).clamp(0.0, 1.0)
              : 0.0;

          final isPaymentPending = student.planEndDate == null ||
              student.effectiveMembershipStatus == MembershipStatus.inactive ||
              student.effectiveMembershipStatus == MembershipStatus.pending;
          final isExpired = !isPaymentPending && (endDate != null && endDate.isBefore(now));
          final isExpiringSoon = !isPaymentPending && !isExpired && daysRemaining <= 5;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentStudentProvider);
              ref.invalidate(plansStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 110.0),
              children: [
                // Outstanding Fee Balance Warning Card with 1-Tap UPI
                if ((student.pendingDueBalance ?? 0) > 0) ...[
                  _buildPendingDueWarningCard(
                    context: context,
                    ref: ref,
                    student: student,
                    library: library,
                    theme: theme,
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Executive Pro Scholar Tier Pass Card
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: theme.brightness == Brightness.dark
                          ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                          : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF312E81).withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFFCD34D)),
                                          SizedBox(width: 4),
                                          Text(
                                            'PRO SCHOLAR',
                                            style: TextStyle(
                                              color: Color(0xFFFCD34D),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        planName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFC7D2FE),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      if (hasDiscount) ...[
                                        Text(
                                          '₹${origPrice.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(alpha: 0.5),
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: Colors.white.withValues(alpha: 0.7),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        planPrice.isNotEmpty ? planPrice : '₹700',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        durationLabel,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                                if (currentPlan != null) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                                        ),
                                        child: Text(
                                          '₹${dailyRate.toStringAsFixed(1)} / day',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                      ),
                                      if (hasDiscount)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 0.8),
                                          ),
                                          child: Text(
                                            'Saved ₹${saved?.toStringAsFixed(0)} ($discPercent% OFF)',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF6EE7B7),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isExpired
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                        : (isPaymentPending || isExpiringSoon
                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                            : const Color(0xFF10B981).withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isExpired
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                          : (isPaymentPending || isExpiringSoon
                                              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                              : const Color(0xFF10B981).withValues(alpha: 0.4)),
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isExpired
                                              ? Icons.cancel_rounded
                                              : (isPaymentPending ? Icons.schedule_rounded : Icons.hourglass_bottom_rounded),
                                          size: 13,
                                          color: isExpired
                                              ? const Color(0xFFFCA5A5)
                                              : (isPaymentPending || isExpiringSoon ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7)),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isExpired
                                              ? 'Expired'
                                              : (isPaymentPending ? 'Payment Pending' : '$daysRemaining Days Left'),
                                          style: TextStyle(
                                            color: isExpired
                                                ? const Color(0xFFFCA5A5)
                                                : (isPaymentPending || isExpiringSoon ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7)),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  endDate != null
                                      ? 'Valid till ${dateFormat.format(endDate)}'
                                      : (isPaymentPending ? 'Starts on fee payment' : 'Pass Inactive'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Progress Bar with Gradient & Labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Validity Usage',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            isPaymentPending
                                ? 'Starts Upon Payment'
                                : '${(progress * 100).toInt()}% Remaining',
                            style: TextStyle(
                              color: isPaymentPending ? const Color(0xFFFDE68A) : const Color(0xFF818CF8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: const Color(0xFF334155),
                          color: isExpired
                              ? const Color(0xFFEF4444)
                              : (isExpiringSoon ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amenities & Shift Details Grid (Responsive Layout)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 420;

                          final deskCard = Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Assigned Desk', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.chair_rounded, size: 12, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        (student.seatId != null && student.seatId!.isNotEmpty)
                                            ? SeatHelper.formatSeatLabel(seatId: student.seatId)
                                            : 'Auto Allocated',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );

                          final shiftCard = Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Study Access', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.all_inclusive_rounded, size: 12, color: Color(0xFF818CF8)),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Dedicated 24x7 Desk',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );

                          final hasAc = library?.hasAirConditioning ?? false;
                          final hasWifi = library?.hasWifi ?? false;
                          final hasSilent = library?.hasSilentZone ?? false;
                          final envLabel = [
                            if (hasAc) 'AC Hall' else if (hasSilent) 'Quiet Hall' else 'Study Hall',
                            if (hasWifi) 'High-Speed Wi-Fi',
                          ].join(' • ');

                          final envCard = Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Environment', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      hasAc
                                          ? Icons.ac_unit_rounded
                                          : (hasWifi ? Icons.wifi_rounded : Icons.verified_outlined),
                                      size: 12,
                                      color: const Color(0xFF38BDF8),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        envLabel,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: deskCard),
                                    const SizedBox(width: 8),
                                    Expanded(child: shiftCard),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                envCard,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: deskCard),
                              const SizedBox(width: 8),
                              Expanded(child: shiftCard),
                              const SizedBox(width: 8),
                              Expanded(child: envCard),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phase 3: Seat Protection Active Guarantee Pill
                      if (isPaymentPending) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFFFDE68A)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  student.seatId != null && student.seatId!.isNotEmpty
                                      ? '🔒 ${SeatHelper.formatSeatLabel(seatId: student.seatId)} is held for you • Settle fee at reception to activate'
                                      : '🔒 Admission approved • Complete fee payment to activate your spot',
                                  style: const TextStyle(
                                    color: Color(0xFFFEF3C7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if ((student.daysRemaining != null && student.daysRemaining! <= 7) || isExpired) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_rounded, size: 15, color: Color(0xFF2DD4BF)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  student.seatId != null && student.seatId!.isNotEmpty
                                      ? '🔒 ${SeatHelper.formatSeatLabel(seatId: student.seatId)} is held for you • Renew to keep your spot'
                                      : '🔒 Seat reservation held for you • Renew to lock in your spot',
                                  style: const TextStyle(
                                    color: Color(0xFFCCFBF1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Quick Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context.push(Routes.studentRenew),
                              icon: const Icon(Icons.autorenew_rounded, size: 16),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isPaymentPending
                                      ? 'Pay Fee / Settle at Counter'
                                      : (((student.daysRemaining != null && student.daysRemaining! <= 7) || isExpired) &&
                                              student.seatId != null &&
                                              student.seatId!.isNotEmpty
                                          ? '🔒 Keep ${SeatHelper.formatSeatLabel(seatId: student.seatId)}'
                                          : 'Extend / Renew'),
                                  maxLines: 1,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPaymentPending
                                    ? const Color(0xFFD97706)
                                    : (((student.daysRemaining != null && student.daysRemaining! <= 7) || isExpired)
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF4F46E5)),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(Routes.studentIdCard),
                              icon: const Icon(Icons.badge_rounded, size: 16, color: Color(0xFF818CF8)),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Digital ID Card', maxLines: 1, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF4338CA)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Study Privileges & Perks Bento Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'STUDY PRIVILEGES & PERKS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaymentPending
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                  : (isExpired
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : Colors.green.withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isPaymentPending
                                  ? 'Pending Fee'
                                  : (isExpired ? 'Inactive' : 'All Active'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPaymentPending
                                    ? const Color(0xFFD97706)
                                    : (isExpired ? const Color(0xFFDC2626) : Colors.green),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDynamicPerksGrid(
                        context,
                        theme,
                        library?.effectiveFacilities ?? const [],
                        library: library,
                        student: student,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Pending Seat Change Indicator (if requested)
                if (student.seatId != null && libraryId != null)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('requests')
                        .where('type', isEqualTo: 'seat_change')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, reqSnap) {
                      final docs = reqSnap.data?.docs ?? [];
                      final myPending = docs.where((d) {
                        final data = d.data();
                        final sId = data['studentId'] as String? ?? '';
                        final sUid = data['studentUserId'] as String? ?? data['userId'] as String? ?? '';
                        final sEmail = data['studentEmail'] as String? ?? '';
                        final curUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                        final curEmail = FirebaseAuth.instance.currentUser?.email ?? '';
                        return (sId == student.id) ||
                            (curUid.isNotEmpty && sUid == curUid) ||
                            (curEmail.isNotEmpty && sEmail.toLowerCase() == curEmail.toLowerCase());
                      }).firstOrNull;

                      if (myPending != null) {
                        final pData = myPending.data();
                        final targetSeat = SeatHelper.formatSeatLabel(rawLabel: pData['targetSeatLabel'] as String?);
                        final targetSec = pData['targetSectionName'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Seat Change Requested: Moving to $targetSeat${targetSec.isNotEmpty ? " ($targetSec)" : ""} • Waiting for Admin Approval',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                const SizedBox(height: 28),

                // Payment History Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payment History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => context.push(Routes.studentReceipts),
                      child: const Text('View All Receipts'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (libraryId != null)
                  _StudentTransactionsSection(
                    libraryId: libraryId,
                    student: student,
                    plans: plansAsync.value ?? [],
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_problem_rounded, size: 54, color: theme.colorScheme.primary),
                const SizedBox(height: 14),
                Text(
                  'Membership Syncing',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your network connection or tap retry.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  onPressed: () {
                    ref.invalidate(currentStudentProvider);
                    ref.invalidate(plansStreamProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicPerksGrid(
    BuildContext context,
    ThemeData theme,
    List<String> facilities, {
    LibraryModel? library,
    StudentModel? student,
  }) {
    final resolvedItems = library != null
        ? library.effectiveAmenityItems
        : AmenityCatalog.parseList(facilities);

    if (resolvedItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No library amenities have been listed by management yet.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final items = resolvedItems.map((e) => e.label).toList();

    Map<String, dynamic> getPerkMeta(String facility) {
      final canonical = AmenityCatalog.fromDynamic(facility);
      final id = canonical?.id ?? '';
      if (id == 'wifi') {
        return {'icon': Icons.wifi_rounded, 'color': const Color(0xFF0284C7), 'sub': 'High-Speed • Tap to copy pass'};
      } else if (id == 'power') {
        return {'icon': Icons.power_rounded, 'color': const Color(0xFF0D9488), 'sub': 'Individual Sockets'};
      } else if (id == 'desk_lamp') {
        return {'icon': Icons.lightbulb_outline_rounded, 'color': const Color(0xFFF59E0B), 'sub': 'Dedicated Study Light'};
      } else if (id == 'ro_water') {
        return {'icon': Icons.water_drop_rounded, 'color': const Color(0xFF2563EB), 'sub': 'Chilled & Normal RO'};
      } else if (id == 'silence') {
        return {'icon': Icons.volume_off_rounded, 'color': const Color(0xFF059669), 'sub': 'Pin-Drop Focus • Tap for Help'};
      } else if (id == 'cctv') {
        return {'icon': Icons.videocam_rounded, 'color': const Color(0xFF7C3AED), 'sub': '24x7 Security Surveillance'};
      } else if (id == 'chairs') {
        return {'icon': Icons.chair_alt_rounded, 'color': const Color(0xFFD97706), 'sub': 'High-Back Cushion Support'};
      } else if (id == 'ac') {
        return {'icon': Icons.ac_unit_rounded, 'color': const Color(0xFF06B6D4), 'sub': 'Climate Controlled Cooling'};
      } else if (id == 'locker') {
        return {'icon': Icons.lock_rounded, 'color': const Color(0xFFEAB308), 'sub': 'Authorized Desk Locker'};
      } else if (id == 'pantry') {
        return {'icon': Icons.coffee_rounded, 'color': const Color(0xFFEA580C), 'sub': 'Dining & Refreshments'};
      } else if (id == 'newspapers') {
        return {'icon': Icons.newspaper_rounded, 'color': const Color(0xFF8B5CF6), 'sub': 'Dailies & Magazines'};
      } else if (id == 'parking') {
        return {'icon': Icons.local_parking_rounded, 'color': const Color(0xFF10B981), 'sub': 'Designated Parking'};
      } else if (id == 'power_backup') {
        return {'icon': Icons.battery_charging_full_rounded, 'color': const Color(0xFF0EA5E9), 'sub': 'Uninterrupted Power'};
      } else if (id == 'open_24_7') {
        return {'icon': Icons.access_time_rounded, 'color': const Color(0xFF6366F1), 'sub': 'Round-The-Clock Study'};
      } else if (id == 'natural_light') {
        return {'icon': Icons.wb_sunny_outlined, 'color': const Color(0xFFF97316), 'sub': 'Ventilated Window Area'};
      }
      return {'icon': Icons.verified_rounded, 'color': const Color(0xFF6366F1), 'sub': 'Admin Verified Facility'};
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth > 320;
        final itemWidth = isTwoColumn ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((facility) {
            final meta = getPerkMeta(facility);
            final isWifi = facility.toLowerCase().contains('wi-fi') || facility.toLowerCase().contains('wifi');
            final isSilent = facility.toLowerCase().contains('silent') || facility.toLowerCase().contains('zone');

            return SizedBox(
              width: itemWidth,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: isWifi
                      ? () {
                          final ssid = library?.effectiveWifiSsid ?? 'Cozy Corner 5G';
                          final pass = library?.effectiveWifiPassword ?? 'Study@Cozy2026';
                          HapticFeedback.mediumImpact();
                          Clipboard.setData(ClipboardData(text: pass));
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text('✅ Wi-Fi password copied! Network: "$ssid"'),
                                  ),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      : (isSilent
                          ? () {
                              SilentReceptionHelpSheet.show(
                                context,
                                libraryId: library?.id ?? '',
                                student: student,
                              );
                            }
                          : null),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isWifi
                          ? const Color(0xFF0284C7).withValues(alpha: 0.05)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWifi
                            ? const Color(0xFF0284C7).withValues(alpha: 0.35)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(meta['icon'] as IconData, size: 18, color: meta['color'] as Color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      facility,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isWifi) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.copy_rounded, size: 11, color: Color(0xFF0284C7)),
                                  ],
                                ],
                              ),
                              Text(
                                meta['sub'] as String,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isWifi ? const Color(0xFF0284C7) : Colors.grey,
                                  fontWeight: isWifi ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
  Widget _buildPendingDueWarningCard({
    required BuildContext context,
    required WidgetRef ref,
    required StudentModel student,
    required LibraryModel? library,
    required ThemeData theme,
  }) {
    final due = (student.pendingDueBalance ?? 0).toDouble();
    final isDark = theme.brightness == Brightness.dark;
    final libraryName = library?.name ?? 'Study Library';

    final paymentSettings = ref.watch(paymentMethodsStreamProvider).value;
    final methods = (paymentSettings?['methods'] as List?)?.whereType<Map>().toList();
    final libMethods = library?.enabledPaymentMethods;
    final bool isUpiEnabled = methods != null && methods.isNotEmpty
        ? methods.any((m) => m['id'] == 'upi' && m['active'] == true)
        : (libMethods != null && libMethods.isNotEmpty ? libMethods.contains('upi') : true);
    final upiId = (paymentSettings?['upiId'] ?? library?.upiId ?? '').toString().trim();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF291E0B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outstanding Fee Balance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      'Please clear dues to keep your desk reserved',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${due.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isUpiEnabled && upiId.isNotEmpty)
                FilledButton.icon(
                  onPressed: () async {
                    final cleanName = Uri.encodeComponent(libraryName);
                    final cleanNote = Uri.encodeComponent('Due Fee Payment - ${student.name}');
                    final uri = Uri.parse(
                      'upi://pay?pa=$upiId&pn=$cleanName&am=${due.toStringAsFixed(2)}&cu=INR&tn=$cleanNote',
                    );
                    try {
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          _showUpiCopyDialog(context, upiId, due);
                        }
                      }
                    } catch (_) {
                      if (context.mounted) {
                        _showUpiCopyDialog(context, upiId, due);
                      }
                    }
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Pay via UPI'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.studentRenew),
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Submit Payment Proof / Pay at Reception'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFD97706)),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpiCopyDialog(BuildContext context, String upiId, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Pay Outstanding Due'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount Due: ₹${amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            const Text('UPI ID:'),
            const SizedBox(height: 4),
            SelectableText(
              upiId,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD97706)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: upiId));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('UPI ID copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy UPI ID'),
          ),
        ],
      ),
    );
  }
}

class _StudentTransactionsSection extends StatelessWidget {
  final String libraryId;
  final StudentModel student;
  final List<PlanModel> plans;

  const _StudentTransactionsSection({
    required this.libraryId,
    required this.student,
    required this.plans,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    // Zero-Index Single-Field Queries for instant loading without composite indexes
    final receiptQuery = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('receipts')
        .where('studentId', isEqualTo: student.id);

    final paymentQuery = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('payments')
        .where('studentId', isEqualTo: student.id);

    // Stream both receipts and payments for the student
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: receiptQuery.snapshots(),
      builder: (context, receiptSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: paymentQuery.snapshots(),
          builder: (context, paymentSnap) {
            if (receiptSnap.connectionState == ConnectionState.waiting &&
                paymentSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
              );
            }

            final receiptDocs = (receiptSnap.data?.docs ?? [])
                .map((d) => <String, dynamic>{...d.data(), 'id': d.id})
                .toList();
            final paymentDocs = (paymentSnap.data?.docs ?? [])
                .map((d) => <String, dynamic>{...d.data(), 'id': d.id})
                .toList();

            final items = StudentLedgerHelper.buildTransactionsLedger(
              libraryId: libraryId,
              student: student,
              receiptDocs: receiptDocs,
              paymentDocs: paymentDocs,
              plans: plans,
            );

            if (items.isEmpty) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: theme.colorScheme.outline),
                        const SizedBox(height: 8),
                        Text(
                          student.membershipStatus == MembershipStatus.inactive
                              ? 'Admission approved • Awaiting fee payment at counter'
                              : 'No payment records found',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final rawStatus = (item['status'] ?? 'paid').toString().toLowerCase();
                final isVoided = rawStatus == 'voided' ||
                    rawStatus == 'void' ||
                    rawStatus == 'cancelled' ||
                    rawStatus == 'canceled' ||
                    rawStatus == 'refunded';
                final isPaid = StudentLedgerHelper.isConfirmedPaidStatus(rawStatus);
                final receiptId = item['receiptId'] as String?;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isVoided
                          ? Colors.red.withValues(alpha: 0.3)
                          : (isPaid
                              ? Colors.green.withValues(alpha: 0.3)
                              : theme.colorScheme.outlineVariant),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: isVoided
                          ? Colors.red.withValues(alpha: 0.12)
                          : (isPaid
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12)),
                      child: Icon(
                        isVoided
                            ? Icons.cancel_rounded
                            : (isPaid ? Icons.check_circle_rounded : Icons.pending_rounded),
                        color: isVoided
                            ? Colors.red.shade700
                            : (isPaid ? Colors.green.shade700 : Colors.orange.shade700),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          '₹${(item['amount'] as double).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        if (receiptId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, size: 10, color: Colors.blue),
                                SizedBox(width: 3),
                                Text('RECEIPT', style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        else if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 10, color: Colors.teal),
                                SizedBox(width: 3),
                                Text('VERIFIED RECORD', style: TextStyle(color: Colors.teal, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hourglass_top_rounded, size: 10, color: Colors.orange),
                                SizedBox(width: 3),
                                Text('PENDING VERIFICATION', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      receiptId != null
                          ? '${item['title']} • ${item['method']}\n${dateFormat.format(item['date'] as DateTime)}'
                          : (isPaid
                              ? 'Payment Logged • ${item['method']}\n${dateFormat.format(item['date'] as DateTime)} • Receipt in issuance'
                              : 'Payment Record • ${item['method']}\n${dateFormat.format(item['date'] as DateTime)} • Awaiting admin verification'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    isThreeLine: true,
                    trailing: receiptId != null
                        ? IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                            tooltip: 'View Official Receipt',
                            onPressed: () {
                              final rModel = item['receiptModel'] as ReceiptModel?;
                              final pModel = item['planModel'] as PlanModel?;
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (_) => ReceiptPreviewScreen(
                                    receiptId: receiptId,
                                    preloadedReceipt: rModel,
                                    preloadedStudent: student,
                                    preloadedPlan: pModel,
                                    isStudent: true,
                                  ),
                                ),
                              );
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
                            tooltip: 'Payment Details',
                            onPressed: () => _showPaymentInfoSheet(context, item, isPaid, dateFormat),
                          ),
                    onTap: () {
                      if (receiptId != null) {
                        final rModel = item['receiptModel'] as ReceiptModel?;
                        final pModel = item['planModel'] as PlanModel?;
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => ReceiptPreviewScreen(
                              receiptId: receiptId,
                              preloadedReceipt: rModel,
                              preloadedStudent: student,
                              preloadedPlan: pModel,
                              isStudent: true,
                            ),
                          ),
                        );
                      } else {
                        _showPaymentInfoSheet(context, item, isPaid, dateFormat);
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showPaymentInfoSheet(
    BuildContext context,
    Map<String, dynamic> item,
    bool isPaid,
    DateFormat dateFormat,
  ) {
    final amount = (item['amount'] as double).toStringAsFixed(0);
    final method = item['method'] ?? 'UPI';
    final dateStr = dateFormat.format(item['date'] as DateTime);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isPaid
                        ? Colors.teal.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    child: Icon(
                      isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                      color: isPaid ? Colors.teal : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹$amount • $method',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          isPaid ? 'Verified Payment Ledger Record' : 'Payment Awaiting Office Verification',
                          style: TextStyle(
                            color: isPaid ? Colors.teal : Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPaid
                        ? Colors.teal.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transaction Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Mode:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(method, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      isPaid
                          ? 'This payment has been confirmed in the study centre accounts ledger. The formal tax invoice/receipt is currently being formatted by the management.'
                          : 'This transaction was registered via $method and is currently under verification by the reception staff. Once verified, your membership pass validity will update automatically and a downloadable PDF receipt will be issued.',
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
