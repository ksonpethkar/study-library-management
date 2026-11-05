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
import 'package:study_library/services/plan_calculator_service.dart';

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

          final isExpired = daysRemaining <= 0;
          final isExpiringSoon = !isExpired && daysRemaining <= 5;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentStudentProvider);
              ref.invalidate(plansStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
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
                          Column(
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
                                  Text(
                                    planName,
                                    style: const TextStyle(
                                      color: Color(0xFFC7D2FE),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isExpired
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                      : (isExpiringSoon
                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                          : const Color(0xFF10B981).withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isExpired
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                        : (isExpiringSoon
                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                            : const Color(0xFF10B981).withValues(alpha: 0.4)),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isExpired ? Icons.cancel_rounded : Icons.hourglass_bottom_rounded,
                                      size: 13,
                                      color: isExpired
                                          ? const Color(0xFFFCA5A5)
                                          : (isExpiringSoon ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7)),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isExpired ? 'Expired' : '$daysRemaining Days Left',
                                      style: TextStyle(
                                        color: isExpired
                                            ? const Color(0xFFFCA5A5)
                                            : (isExpiringSoon ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                endDate != null ? 'Valid till ${dateFormat.format(endDate)}' : 'Active Pass',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            ],
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
                            '${(progress * 100).toInt()}% Remaining',
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
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

                      // Amenities & Shift Details Grid
                      Row(
                        children: [
                          Expanded(
                            child: Container(
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
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Study Shift', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF818CF8)),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Full Day Access',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Environment', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        (library?.hasAirConditioning == true) ? Icons.ac_unit_rounded : Icons.wifi_rounded,
                                        size: 12,
                                        color: const Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          (library?.hasAirConditioning == true) ? 'AC • 5G WiFi' : 'Comfortable • 5G WiFi',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Quick Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context.push(Routes.studentRenew),
                              icon: const Icon(Icons.autorenew_rounded, size: 16),
                              label: const Text('Extend / Renew', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
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
                              label: const Text('Digital ID Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
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
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('All Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDynamicPerksGrid(context, theme, library?.facilities ?? const [], library: library),
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
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error loading membership: $err', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicPerksGrid(BuildContext context, ThemeData theme, List<String> facilities, {LibraryModel? library}) {
    final items = facilities.isNotEmpty
        ? facilities
        : const [
            'High-Speed Wi-Fi',
            'Power Sockets at Desk',
            'Purified RO Water',
            'Silent Study Zone',
            'CCTV Surveillance',
            'Ergonomic Chairs',
          ];

    Map<String, dynamic> getPerkMeta(String facility) {
      final lower = facility.toLowerCase();
      if (lower.contains('wi-fi') || lower.contains('wifi')) {
        return {'icon': Icons.wifi_rounded, 'color': const Color(0xFF0284C7), 'sub': '5G Mesh • Tap to copy pass'};
      } else if (lower.contains('power') || lower.contains('socket')) {
        return {'icon': Icons.power_rounded, 'color': const Color(0xFF0D9488), 'sub': 'Individual Sockets'};
      } else if (lower.contains('water') || lower.contains('ro')) {
        return {'icon': Icons.water_drop_rounded, 'color': const Color(0xFF2563EB), 'sub': 'Chilled & Normal RO'};
      } else if (lower.contains('silent') || lower.contains('zone')) {
        return {'icon': Icons.volume_off_rounded, 'color': const Color(0xFF059669), 'sub': 'Pin-Drop Acoustic Focus'};
      } else if (lower.contains('cctv') || lower.contains('security')) {
        return {'icon': Icons.videocam_rounded, 'color': const Color(0xFF7C3AED), 'sub': '24x7 Security Surveillance'};
      } else if (lower.contains('chair') || lower.contains('ergonomic')) {
        return {'icon': Icons.chair_alt_rounded, 'color': const Color(0xFFD97706), 'sub': 'High-Back Cushion Support'};
      } else if (lower.contains('ac') || lower.contains('air condition')) {
        return {'icon': Icons.ac_unit_rounded, 'color': const Color(0xFF06B6D4), 'sub': 'Climate Controlled Cooling'};
      } else if (lower.contains('locker')) {
        return {'icon': Icons.lock_rounded, 'color': const Color(0xFFEAB308), 'sub': 'Authorized Desk Locker'};
      } else if (lower.contains('pantry') || lower.contains('cafeteria')) {
        return {'icon': Icons.coffee_rounded, 'color': const Color(0xFFEA580C), 'sub': 'Dining & Refreshments'};
      } else if (lower.contains('newspaper') || lower.contains('magazine')) {
        return {'icon': Icons.newspaper_rounded, 'color': const Color(0xFF8B5CF6), 'sub': 'Dailies & Magazines'};
      } else if (lower.contains('parking')) {
        return {'icon': Icons.local_parking_rounded, 'color': const Color(0xFF10B981), 'sub': 'Designated Parking'};
      }
      return {'icon': Icons.verified_rounded, 'color': const Color(0xFF6366F1), 'sub': 'Authorized Privilege'};
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
                      : null,
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

    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final effectiveUid = student.userId?.isNotEmpty == true ? student.userId! : authUid;

    // Stream both receipts and payments for the student
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: effectiveUid.isNotEmpty
          ? FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('receipts')
              .where('studentUserId', isEqualTo: effectiveUid)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('receipts')
              .where('studentId', isEqualTo: student.id)
              .snapshots(),
      builder: (context, receiptSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: effectiveUid.isNotEmpty
              ? FirebaseFirestore.instance
                  .collection('libraries')
                  .doc(libraryId)
                  .collection('payments')
                  .where('studentUserId', isEqualTo: effectiveUid)
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('libraries')
                  .doc(libraryId)
                  .collection('payments')
                  .where('studentId', isEqualTo: student.id)
                  .snapshots(),
          builder: (context, paymentSnap) {
            if (receiptSnap.connectionState == ConnectionState.waiting &&
                paymentSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
              );
            }

            final List<Map<String, dynamic>> items = [];
            final Set<String> seenReceiptIds = {};

            // 1. Add Receipts
            for (final doc in receiptSnap.data?.docs ?? []) {
              final data = doc.data();
              if (data['deletedAt'] != null) continue;
              final rId = doc.id;
              seenReceiptIds.add(rId);

              DateTime date = DateTime.now();
              final rawDate = data['createdAt'] ?? data['validFrom'];
              if (rawDate is Timestamp) date = rawDate.toDate();
              if (rawDate is String) date = DateTime.tryParse(rawDate) ?? date;

              items.add({
                'id': rId,
                'receiptId': rId,
                'title': data['receiptNumber'] ?? 'Official Receipt',
                'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
                'date': date,
                'method': data['paymentMethod'] ?? 'Paid',
                'status': data['status'] ?? 'paid',
                'isOfficialReceipt': true,
              });
            }

            // 2. Add Payments (skip if already represented by a receipt)
            for (final doc in paymentSnap.data?.docs ?? []) {
              final data = doc.data();
              final linkedReceiptId = data['receiptId'] as String?;
              if (linkedReceiptId != null && seenReceiptIds.contains(linkedReceiptId)) {
                continue;
              }

              DateTime date = DateTime.now();
              final rawDate = data['date'] ?? data['createdAt'];
              if (rawDate is Timestamp) date = rawDate.toDate();
              if (rawDate is String) date = DateTime.tryParse(rawDate) ?? date;

              items.add({
                'id': doc.id,
                'receiptId': linkedReceiptId,
                'title': data['referenceNumber']?.toString().isNotEmpty == true
                    ? 'Ref: ${data['referenceNumber']}'
                    : 'Payment Record',
                'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
                'date': date,
                'method': data['paymentMethod'] ?? data['method'] ?? 'Cash',
                'status': data['status'] ?? 'paid',
                'isOfficialReceipt': linkedReceiptId != null,
              });
            }

            // 3. If no receipt/payment exists, but membership plan is active:
            if (items.isEmpty && (student.planId != null || student.planStartDate != null || student.membershipStatus == MembershipStatus.active)) {
              final plan = plans.where((p) => p.id == student.planId).firstOrNull;
              final planPrice = plan?.price ?? student.customPlanFee ?? 2000.0;
              final startDate = student.planStartDate ?? student.createdAt ?? DateTime.now();
              final endDate = student.planEndDate ?? startDate.add(const Duration(days: 90));
              final planName = plan?.name ?? student.customPlanName ?? 'Pro Scholar Quarterly';

              final uniqueSuffix = student.membershipNumber?.isNotEmpty == true
                  ? student.membershipNumber!
                  : (student.id.length >= 6 ? student.id.substring(0, 6).toUpperCase() : student.id.toUpperCase());

              final virtualReceipt = ReceiptModel(
                id: 'active_enrollment_${student.id}',
                libraryId: libraryId,
                receiptNumber: 'REC-${startDate.year}-$uniqueSuffix',
                studentId: student.id,
                studentUserId: effectiveUid,
                planId: student.planId ?? 'membership_enrollment',
                amount: planPrice > 0 ? planPrice : 2000.0,
                totalFee: planPrice > 0 ? planPrice : 2000.0,
                paidAmount: planPrice > 0 ? planPrice : 2000.0,
                remainingDue: 0.0,
                paymentMethod: 'Desk / Confirmed',
                validFrom: startDate,
                validTo: endDate,
                status: ReceiptStatus.active,
                customFields: {
                  'planName': planName,
                  if (student.seatId != null) 'seatLabel': SeatHelper.formatSeatLabel(seatId: student.seatId),
                  'admissionType': 'Official Enrollment Receipt',
                },
                createdAt: startDate,
                updatedAt: startDate,
              );

              items.add({
                'id': virtualReceipt.id,
                'receiptId': virtualReceipt.id,
                'title': '$planName Enrollment',
                'amount': planPrice > 0 ? planPrice : 2000.0,
                'date': startDate,
                'method': 'Desk / Confirmed',
                'status': 'active',
                'isOfficialReceipt': true,
                'receiptModel': virtualReceipt,
                'planModel': plan,
              });
            }

            // Sort in memory by date descending
            items.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

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
                          'No payment records found',
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
                final isPaid = item['status'] == 'paid' || item['status'] == 'active';
                final receiptId = item['receiptId'] as String?;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isPaid
                          ? Colors.green.withValues(alpha: 0.3)
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: isPaid
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      child: Icon(
                        isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                        color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
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
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${item['title']} • ${item['method']}\n${dateFormat.format(item['date'] as DateTime)}',
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
                        : null,
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
                        context.push(Routes.studentReceipts);
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
}
