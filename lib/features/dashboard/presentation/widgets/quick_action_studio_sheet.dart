import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/utils/app_haptics.dart';
import 'package:study_library/features/expenses/presentation/screens/add_expense_dialog.dart';
import 'package:study_library/features/payments/presentation/widgets/smart_payment_picker_sheet.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/waiting_list/data/repositories/waiting_list_repository.dart';

/// Categorized Quick Action Studio (FAB `+` upgrade).
/// Organizes operational actions into Daily High-Frequency Transactions vs Admissions/Notices,
/// with semantic color coding, live smart counters, and staff RBAC validation.
class QuickActionStudioSheet {
  static Future<void> show(BuildContext context, WidgetRef ref) {
    AppHaptics.medium();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickActionStudioContent(parentContext: context),
    );
  }
}

class _QuickActionStudioContent extends ConsumerWidget {
  final BuildContext parentContext;
  const _QuickActionStudioContent({required this.parentContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fmt = NumberFormat('#,##,###');

    // 1. Staff RBAC Permissions
    final currentStaff = ref.watch(currentUserStaffProvider).value;
    final canRecordPayments = currentStaff?.canRecordPayments ?? true;
    final canManageStudents = currentStaff?.canManageStudents ?? true;
    final canViewRevenue = currentStaff?.canViewRevenue ?? true;
    final canManageSeats = currentStaff?.canManageSeats ?? true;

    // 2. Real-Time Smart Data
    final occupancy = ref.watch(occupancyProvider).value;
    final totalSeats = occupancy?['total'] ?? 0;
    final availableSeats = occupancy?['available'] ?? 0;

    final students = ref.watch(studentsStreamProvider).value ?? [];
    final defaulters = students.where((s) => (s.pendingDueBalance ?? 0) > 0).toList();
    final defaultersCount = defaulters.length;
    final totalDueAmount = defaulters.fold<double>(0, (acc, s) => acc + (s.pendingDueBalance ?? 0));

    final waitingList = ref.watch(waitingListStreamProvider).value ?? [];
    final waitingCount = waitingList.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Studio Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Action Studio',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Instant operations, financial logging & admissions',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              const Divider(height: 12),

              // Action Tiles List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    // ── CATEGORY 1: DAILY TRANSACTIONS ──
                    _buildCategoryHeader(
                      theme: theme,
                      icon: Icons.electric_bolt_rounded,
                      title: 'DAILY TRANSACTIONS',
                      badge: 'High Frequency',
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(height: 8),

                    // 1. Record Fee Payment
                    if (canRecordPayments)
                      _buildActionCard(
                        theme: theme,
                        icon: Icons.payments_rounded,
                        color: const Color(0xFF059669),
                        title: 'Record Fee Payment',
                        subtitle: defaultersCount > 0
                            ? '$defaultersCount student${defaultersCount > 1 ? "s have" : " has"} pending dues • ₹${fmt.format(totalDueAmount)}'
                            : 'All fees settled • Record fee, dues or deposit',
                        badgeText: defaultersCount > 0 ? '₹${fmt.format(totalDueAmount)} Due' : null,
                        badgeColor: defaultersCount > 0 ? const Color(0xFFDC2626) : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          SmartPaymentPickerSheet.show(parentContext, ref);
                        },
                      ),

                    // 2. Log Quick Expense
                    if (canViewRevenue) ...[
                      const SizedBox(height: 8),
                      _buildActionCard(
                        theme: theme,
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFFE11D48),
                        title: 'Log Quick Expense',
                        subtitle: 'Petty cash, electricity, water jars, chai & cleaning supplies',
                        badgeText: 'Live Margin Update',
                        badgeColor: const Color(0xFFE11D48),
                        onTap: () {
                          Navigator.pop(ctx);
                          AddExpenseDialog.show(parentContext);
                        },
                      ),
                    ],

                    // 3. Scan Student QR Pass
                    const SizedBox(height: 8),
                    _buildActionCard(
                      theme: theme,
                      icon: Icons.qr_code_scanner_rounded,
                      color: const Color(0xFF4F46E5),
                      title: 'Scan Student QR Pass',
                      subtitle: 'Fast gate check-in, desk verification & digital pass status',
                      onTap: () {
                        Navigator.pop(ctx);
                        parentContext.push(Routes.adminQrScanner);
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── CATEGORY 2: ADMISSIONS & NOTICES ──
                    _buildCategoryHeader(
                      theme: theme,
                      icon: Icons.account_balance_rounded,
                      title: 'ADMISSIONS & NOTICES',
                      badge: 'Master Hub',
                      color: const Color(0xFF0284C7),
                    ),
                    const SizedBox(height: 8),

                    // 4. Register New Student
                    if (canManageStudents)
                      _buildActionCard(
                        theme: theme,
                        icon: Icons.person_add_rounded,
                        color: const Color(0xFF0284C7),
                        title: 'Register New Student',
                        subtitle: availableSeats > 0
                            ? '$availableSeats desk${availableSeats > 1 ? "s" : ""} available to assign across sections'
                            : '⚠️ Facility 100% Full • All $totalSeats desks occupied',
                        badgeText: availableSeats > 0 ? '$availableSeats Desks Free' : '100% Full',
                        badgeColor: availableSeats > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        onTap: () {
                          Navigator.pop(ctx);
                          parentContext.push(Routes.adminStudentAdd);
                        },
                      ),

                    // 5. Add to Waiting Queue
                    if (canManageStudents || canManageSeats) ...[
                      const SizedBox(height: 8),
                      _buildActionCard(
                        theme: theme,
                        icon: Icons.hourglass_top_rounded,
                        color: const Color(0xFF7C3AED),
                        title: 'Add to Waiting Queue',
                        subtitle: waitingCount > 0
                            ? '$waitingCount candidate${waitingCount > 1 ? "s" : ""} in waiting queue • Fast walk-in inquiry'
                            : 'Queue empty • Capture walk-in inquiries for busy shifts',
                        badgeText: waitingCount > 0 ? '$waitingCount In Queue' : null,
                        badgeColor: const Color(0xFF7C3AED),
                        onTap: () {
                          Navigator.pop(ctx);
                          parentContext.push(Routes.adminWaitingList);
                        },
                      ),
                    ],

                    // 6. Broadcast Notice
                    const SizedBox(height: 8),
                    _buildActionCard(
                      theme: theme,
                      icon: Icons.campaign_rounded,
                      color: const Color(0xFFD97706),
                      title: 'Broadcast Notice',
                      subtitle: 'Publish priority circular with instant push to student passes',
                      badgeText: 'Priority Carousel',
                      badgeColor: const Color(0xFFD97706),
                      onTap: () {
                        Navigator.pop(ctx);
                        parentContext.push(Routes.adminAnnouncements);
                      },
                    ),

                    // 7. Add Section / Study Hall
                    if (canManageSeats) ...[
                      const SizedBox(height: 8),
                      _buildActionCard(
                        theme: theme,
                        icon: Icons.meeting_room_rounded,
                        color: const Color(0xFF0D9488),
                        title: 'Add Section / Room',
                        subtitle: 'Create a new study hall, floor, cabin or zoning area',
                        onTap: () {
                          Navigator.pop(ctx);
                          parentContext.push(Routes.adminSeatsAddSection);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String badge,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? badgeText,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? color).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (badgeColor ?? color).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: badgeColor ?? color,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
