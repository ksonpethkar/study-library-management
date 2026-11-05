import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/theme_provider.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/dashboard/presentation/widgets/notification_center_sheet.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/auth/services/auth_role_service.dart';
import 'package:study_library/services/badge_service.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/search/presentation/screens/global_search_screen.dart';
import 'package:study_library/features/dashboard/presentation/widgets/revenue_chart.dart';
import 'package:study_library/features/dashboard/presentation/widgets/app_update_banner.dart';
import 'package:study_library/core/widgets/update_reminder_dialog.dart';
import 'package:study_library/features/seats/presentation/widgets/share_qr_dialog.dart';
import 'package:study_library/services/expiry_notification_service.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/services/membership_automation_service.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';
import 'package:study_library/services/backup_service.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import 'package:study_library/services/quick_actions_service.dart';
import 'package:study_library/services/remote_config_service.dart';
import 'package:study_library/features/requests/presentation/providers/request_providers.dart';
import 'package:study_library/features/holidays/presentation/screens/holiday_calendar_screen.dart';
import 'package:study_library/features/waiting_list/data/repositories/waiting_list_repository.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/features/expenses/presentation/providers/expense_providers.dart';
import 'package:study_library/features/payments/presentation/widgets/smart_payment_picker_sheet.dart';
import 'package:intl/intl.dart';

class DashboardMetrics {
  final int newToday;
  final int expiredToday;
  final int renewalsDue;
  final int activeStudentsCount;
  final int totalStudentsCount;
  final int defaultersCount;
  final double totalDueAmount;
  final List<StudentModel> recentStudents;

  const DashboardMetrics({
    this.newToday = 0,
    this.expiredToday = 0,
    this.renewalsDue = 0,
    this.activeStudentsCount = 0,
    this.totalStudentsCount = 0,
    this.defaultersCount = 0,
    this.totalDueAmount = 0.0,
    this.recentStudents = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardMetrics &&
          runtimeType == other.runtimeType &&
          newToday == other.newToday &&
          expiredToday == other.expiredToday &&
          renewalsDue == other.renewalsDue &&
          activeStudentsCount == other.activeStudentsCount &&
          totalStudentsCount == other.totalStudentsCount &&
          defaultersCount == other.defaultersCount &&
          totalDueAmount == other.totalDueAmount &&
          recentStudents.length == other.recentStudents.length;

  @override
  int get hashCode => Object.hash(
        newToday,
        expiredToday,
        renewalsDue,
        activeStudentsCount,
        totalStudentsCount,
        defaultersCount,
        totalDueAmount,
        recentStudents.length,
      );
}

final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  final studentsAsync = ref.watch(studentsStreamProvider);
  final allStudents = studentsAsync.value ?? [];
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));
  final next7Days = todayStart.add(const Duration(days: 7));

  int newToday = 0;
  int expiredToday = 0;
  int renewalsDue = 0;
  int activeCount = 0;
  int defaultersCount = 0;
  double totalDue = 0.0;

  for (final s in allStudents) {
    if (s.membershipStatus == MembershipStatus.active || s.membershipStatus == MembershipStatus.grace) {
      activeCount++;
    }
    final c = s.createdAt;
    if (c != null && !c.isBefore(todayStart) && c.isBefore(todayEnd)) {
      newToday++;
    }
    if (s.membershipStatus == MembershipStatus.expired) {
      final e = s.planEndDate;
      if (e != null && !e.isBefore(todayStart) && e.isBefore(todayEnd)) {
        expiredToday++;
      }
    }
    if (s.membershipStatus == MembershipStatus.active || s.membershipStatus == MembershipStatus.grace) {
      final e = s.planEndDate;
      if (e != null && (s.membershipStatus == MembershipStatus.grace || (!e.isBefore(now) && !e.isAfter(next7Days)))) {
        renewalsDue++;
      }
    }
    final due = s.pendingDueBalance ?? 0;
    if (due > 0) {
      defaultersCount++;
      totalDue += due;
    }
  }

  return DashboardMetrics(
    newToday: newToday,
    expiredToday: expiredToday,
    renewalsDue: renewalsDue,
    activeStudentsCount: activeCount,
    totalStudentsCount: allStudents.length,
    defaultersCount: defaultersCount,
    totalDueAmount: totalDue,
    recentStudents: allStudents.take(5).toList(),
  );
});


class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with WidgetsBindingObserver {
  int _newToday = 0;
  int _expiredToday = 0;
  int _renewalsDue = 0;
  int _pendingCount = 0;
  StreamSubscription<QuerySnapshot>? _pendingRequestsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _watchPendingRequests();
    _initQuickActions();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Enrolled Student Precedence Check: If active session is an enrolled student, auto-heal & route to Student Portal
        final wasHealed = await AuthRoleService.healEnrolledStudentRole(ref, context: context, navigate: true);
        if (wasHealed || !mounted) return;

        if (_pendingRequestsSub == null) _watchPendingRequests();
        WhatsNewService.checkAndShow(context, isStudent: false);
        UpdateReminderDialog.checkAndShow(context, ref);
        _runAutomations();
        _loadTodayStats();
      }
    });
  }

  void _initQuickActions() {
    QuickActionsService.initializeForAdmin(context, (shortcutType) {
      if (!mounted) return;
      switch (shortcutType) {
        case 'add_student':
          context.push(Routes.adminStudentAdd);
          break;
        case 'record_payment':
          // Navigate to student list first (payment needs a student)
          context.go(Routes.adminStudents);
          break;
        case 'scan_qr':
          context.push(Routes.adminQrScanner);
          break;
        case 'announcements':
          context.push(Routes.adminAnnouncements);
          break;
      }
    });
  }

  void _watchPendingRequests() {
    if (_pendingRequestsSub != null) return;
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;
    _pendingRequestsSub = FirebaseFirestore.instance
        .collection('libraries').doc(libraryId)
        .collection('requests')
        .where('status', whereIn: ['pending', 'desk_payment_pending', 'payment_pending'])
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _pendingCount = snap.docs.length;
        });
      }
      BadgeService.updateBadge(snap.docs.length);
    });
  }

  Future<void> _loadTodayStats() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final next7Days = todayStart.add(const Duration(days: 7));

    try {
      // New today
      final newSnap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId).collection('students')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(todayEnd))
          .count().get();

      // Expired today
      final expiredSnap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId).collection('students')
          .where('membershipStatus', isEqualTo: 'expired')
          .where('planEndDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('planEndDate', isLessThan: Timestamp.fromDate(todayEnd))
          .count().get();

      // Renewals due (active students expiring in next 7 days)
      final renewalSnap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId).collection('students')
          .where('membershipStatus', isEqualTo: 'active')
          .where('planEndDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('planEndDate', isLessThanOrEqualTo: Timestamp.fromDate(next7Days))
          .count().get();

      if (mounted) {
        setState(() {
          _newToday = newSnap.count ?? 0;
          _expiredToday = expiredSnap.count ?? 0;
          _renewalsDue = renewalSnap.count ?? 0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingRequestsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runAutomations();
      _loadTodayStats();
    }
  }

  Future<void> _runAutomations() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    final result =
        await MembershipAutomationService.runDailyMaintenance(libraryId);

    // Silent rolling 7-day snapshot backup
    ref.read(backupServiceProvider).checkAndRunRollingBackup(libraryId);

    if (mounted && result.hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Auto-Maintenance: ${result.expiredCount} expired plans, ${result.releasedSeatsCount} seats released.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      ref.invalidate(studentsStreamProvider);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showRecordPaymentPicker(BuildContext context) {
    SmartPaymentPickerSheet.show(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.split(' ').first ?? 'Admin';
    final library = ref.watch(currentLibraryProvider);
    final occupancy = ref.watch(occupancyProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);

    final libraryName = library.when(
      data: (lib) => lib?.name.isNotEmpty == true ? lib!.name : 'Study Library',
      loading: () => 'Study Library',
      error: (_, _) => 'Study Library',
    );

    // Check for expiring plans (fire and forget)
    final libId = ref.watch(currentLibraryIdProvider);
    if (libId != null && libId.isNotEmpty) {
      ExpiryNotificationService.checkExpiringPlans(libId);
    }

    final currentStaff = ref.watch(currentUserStaffProvider).value;
    final canViewRevenue = currentStaff?.canViewRevenue ?? true;

    final metrics = ref.watch(dashboardMetricsProvider);
    final effectiveNewToday = metrics.newToday > 0 ? metrics.newToday : _newToday;
    final effectiveExpiredToday = metrics.expiredToday > 0 ? metrics.expiredToday : _expiredToday;
    final effectiveRenewalsDue = metrics.renewalsDue > 0 ? metrics.renewalsDue : _renewalsDue;

    return Scaffold(
      body: Column(
        children: [
          // App notice banner from Remote Config
          if (RemoteConfigService.appNoticeBanner.isNotEmpty)
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                color: Colors.amber.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        RemoteConfigService.appNoticeBanner,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Library Closed Today banner (from Holiday Calendar)
          Builder(builder: (context) {
            final today = DateTime.now();
            final todayKey = DateTime(today.year, today.month, today.day);
            final holidaysAsync = ref.watch(holidaysStreamProvider);
            return holidaysAsync.when(
              data: (holidays) {
                final todayHoliday = holidays.where((h) {
                  final d = DateTime(h.date.year, h.date.month, h.date.day);
                  return d == todayKey && h.isFullDay;
                }).firstOrNull;
                if (todayHoliday == null) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.event_busy_rounded, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🔒 Library Closed Today — ${todayHoliday.reason}',
                          style: const TextStyle(fontSize: 13, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            );
          }),
          Expanded(
            child: RefreshIndicator(
                onRefresh: () async {
          ref.invalidate(occupancyProvider);
          ref.invalidate(studentsStreamProvider);
          ref.invalidate(netProfitProvider);
          ref.invalidate(revenueDataProvider);
          ref.invalidate(expensesStreamProvider);
          ref.invalidate(holidaysStreamProvider);
          ref.invalidate(adminNotificationsStreamProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push(Routes.adminLibraryProfile),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: ImageService.getImageProvider(library.value?.logoUrl),
                      child: (ImageService.getImageProvider(library.value?.logoUrl) == null)
                          ? Icon(Icons.local_library_rounded, color: theme.colorScheme.primary, size: 20)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          libraryName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$_greeting, $displayName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // 1. Direct Theme Mode Toggle
                Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(themeNotifierProvider);
                    final isDark = themeMode == ThemeMode.dark;
                    return IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: isDark ? Colors.amber : null,
                      ),
                      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(themeNotifierProvider.notifier).toggleTheme();
                      },
                    );
                  },
                ),
                // 2. Admin Notification Center with Live Unread Badge
                Consumer(
                  builder: (context, ref, _) {
                    final notifs = ref.watch(adminNotificationsStreamProvider).value ?? [];
                    final unreadNotifsCount = notifs.where((n) => !n.read).length;
                    final libId = library.value?.id ?? ref.read(currentLibraryIdProvider) ?? '';
                    final alertsState = libId.isNotEmpty
                        ? ref.watch(systemAlertsProvider(libId))
                        : const SystemAlertsState();
                    final unreadPending = (_pendingCount - alertsState.acknowledgedPendingCount).clamp(0, 999999);
                    final unreadRenewals = (effectiveRenewalsDue - alertsState.acknowledgedRenewalsCount).clamp(0, 999999);
                    final totalUnread = unreadNotifsCount + unreadPending + unreadRenewals;

                    return Badge(
                      isLabelVisible: totalUnread > 0,
                      label: Text('$totalUnread'),
                      backgroundColor: Colors.redAccent,
                      child: IconButton(
                        icon: Icon(
                          totalUnread > 0
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_outlined,
                        ),
                        tooltip: 'Admin Notifications ($totalUnread)',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          NotificationCenterSheet.show(
                            context,
                            libraryId: libId,
                            role: 'admin',
                            pendingRequestsCount: _pendingCount,
                            renewalsDueCount: effectiveRenewalsDue,
                          );
                        },
                      ),
                    );
                  },
                ),
                // 3. Global Search Action
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Global Search',
                  onPressed: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 130.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppUpdateBanner(),
                    const SizedBox(height: 12),

                    // Contextual Intelligence Renewal Alert
                    if (effectiveRenewalsDue > 0) ...[
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.go(Uri(path: Routes.adminStudents, queryParameters: {'filter': 'Due Soon'}).toString());
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF3B2D12)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                  : const Color(0xFFFCD34D),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(
                                  alpha: theme.brightness == Brightness.dark ? 0.1 : 0.08,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.alarm_on_rounded, size: 20, color: Color(0xFFD97706)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$effectiveRenewalsDue Student Membership${effectiveRenewalsDue > 1 ? "s" : ""} Due for Renewal',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: theme.brightness == Brightness.dark
                                            ? const Color(0xFFFDE68A)
                                            : const Color(0xFF92400E),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Expiring within 48h. Tap to review & send 1-click WhatsApp alerts.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: theme.brightness == Brightness.dark
                                            ? const Color(0xFFE2E8F0)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFF92400E),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 1. Facility Occupancy Radar & Metrics Ribbon
                    _buildOccupancyRadarCard(
                      context: context,
                      theme: theme,
                      occupancyAsync: occupancy,
                      activeStudentsCount: metrics.activeStudentsCount,
                      totalStudentsCount: metrics.totalStudentsCount,
                      renewalsDue: effectiveRenewalsDue,
                      libId: libId ?? '',
                    ),
                    const SizedBox(height: 16),

                    // 2. Consolidated Financial Pulse Card
                    _buildFinancialPulseCard(
                      context: context,
                      theme: theme,
                      students: studentsAsync.value ?? [],
                      netProfitAsync: ref.watch(netProfitProvider),
                      canViewRevenue: canViewRevenue,
                    ),
                    const SizedBox(height: 20),

                    // 3. Operational Action Dock
                    _buildOperationalDock(
                      context: context,
                      theme: theme,
                      newToday: effectiveNewToday,
                      expiredToday: effectiveExpiredToday,
                      renewalsDue: effectiveRenewalsDue,
                    ),
                    const SizedBox(height: 20),
                    // Revenue Chart (Owners & Managers only)
                    if (canViewRevenue) ...[
                      const RevenueChart(),
                      const SizedBox(height: 24),
                    ],

                    // Recent Students
                    Text('Recent Students', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    metrics.recentStudents.isEmpty
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline, size: 48, color: theme.colorScheme.outline),
                                    const SizedBox(height: 8),
                                    Text('No students yet', style: theme.textTheme.bodyLarge),
                                    const SizedBox(height: 4),
                                    Text('Add your first student to get started', style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: metrics.recentStudents.length,
                            itemBuilder: (context, index) {
                              final student = metrics.recentStudents[index];
                              Color statusColor;
                              switch (student.membershipStatus) {
                                case MembershipStatus.active:
                                  statusColor = const Color(0xFF10B981);
                                  break;
                                case MembershipStatus.grace:
                                  statusColor = const Color(0xFFF59E0B);
                                  break;
                                case MembershipStatus.expired:
                                  statusColor = const Color(0xFFEF4444);
                                  break;
                                case MembershipStatus.blocked:
                                  statusColor = const Color(0xFF7C3AED);
                                  break;
                                case MembershipStatus.pending:
                                  statusColor = const Color(0xFF0284C7);
                                  break;
                                default:
                                  statusColor = const Color(0xFF64748B);
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: PressableScale(
                                  scaleFactor: 0.98,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.push('/admin/students/${student.id}');
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: theme.brightness == Brightness.dark
                                            ? Colors.white10
                                            : const Color(0xFFE2E8F0),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: theme.brightness == Brightness.dark ? 0.2 : 0.03,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                      leading: Hero(
                                        tag: 'student-avatar-${student.id}',
                                        child: Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                              backgroundImage: ImageService.getImageProvider(student.photoUrl),
                                              child: ImageService.getImageProvider(student.photoUrl) == null
                                                  ? Text(
                                                      student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    )
                                                  : null,
                                            ),
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: theme.cardColor,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      title: Hero(
                                        tag: 'student-name-${student.id}',
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: Text(
                                            student.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${student.membershipNumber != null ? "#${student.membershipNumber} • " : ""}${student.phone}',
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if ((student.pendingDueBalance ?? 0) > 0)
                                            Container(
                                              margin: const EdgeInsets.only(right: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                '₹${student.pendingDueBalance!.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              student.membershipStatus.name.toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                  ],
                ),
              ),
            ),
            ],
          ),
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildOccupancyRadarCard({
    required BuildContext context,
    required ThemeData theme,
    required AsyncValue<Map<String, int>> occupancyAsync,
    required int activeStudentsCount,
    required int totalStudentsCount,
    required int renewalsDue,
    required String libId,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final occ = occupancyAsync.value ?? {'total': 0, 'occupied': 0, 'available': 0};
    final totalSeats = occ['total'] ?? 0;
    final occupiedSeats = occ['occupied'] ?? 0;
    final availableSeats = occ['available'] ?? (totalSeats > occupiedSeats ? totalSeats - occupiedSeats : 0);
    final percent = totalSeats > 0 ? (occupiedSeats / totalSeats * 100).round() : 0;
    final waitingListAsync = ref.watch(waitingListStreamProvider);
    final waitingCount = waitingListAsync.value?.length ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.radar_rounded, size: 18, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Facility Occupancy Radar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (waitingCount > 0) ...[
                    InkWell(
                      onTap: () => context.push(Routes.adminWaitingList),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            Text(
                              'Queue: $waitingCount',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$percent% Full',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final double gaugeDimension = screenWidth < 380 ? 76.0 : 90.0;
              final double gaugeSpacing = screenWidth < 380 ? 10.0 : 16.0;

              return Row(
                children: [
                  // Circular Occupancy Gauge
                  GestureDetector(
                    onTap: () => context.go(Routes.adminSeats),
                    child: SizedBox(
                      width: gaugeDimension,
                      height: gaugeDimension,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: gaugeDimension,
                            height: gaugeDimension,
                            child: CircularProgressIndicator(
                              value: totalSeats > 0 ? (occupiedSeats / totalSeats).clamp(0.0, 1.0) : 0,
                              strokeWidth: screenWidth < 380 ? 7 : 8,
                              strokeCap: StrokeCap.round,
                              backgroundColor: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percent > 90
                                    ? const Color(0xFFEF4444)
                                    : (percent > 65 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$percent%',
                                style: TextStyle(
                                  fontSize: screenWidth < 380 ? 16 : 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Occupied',
                                style: TextStyle(
                                  fontSize: screenWidth < 380 ? 9 : 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: gaugeSpacing),
                  // 4 Micro Metrics Grid
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMicroMetricTile(
                            label: 'Occupied',
                            value: '$occupiedSeats',
                            subtext: 'of $totalSeats desks',
                            color: const Color(0xFFEF4444),
                            icon: Icons.event_seat_rounded,
                            onTap: () => context.go(Routes.adminSeats),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMicroMetricTile(
                            label: 'Available',
                            value: '$availableSeats',
                            subtext: 'ready to assign',
                            color: const Color(0xFF10B981),
                            icon: Icons.chair_rounded,
                            onTap: () => context.push(Routes.adminSeats),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMicroMetricTile(
                            label: 'Active Students',
                            value: '$activeStudentsCount',
                            subtext: '$totalStudentsCount enrolled',
                            color: const Color(0xFF3B82F6),
                            icon: Icons.school_rounded,
                            onTap: () => context.go(Routes.adminStudents),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final reqCounts = ref.watch(requestModuleCountsProvider);
                              final count = reqCounts.totalPending;
                              return _buildMicroMetricTile(
                                label: 'Requests Hub',
                                value: '$count',
                                subtext: count > 0 ? reqCounts.summaryText : 'all cleared',
                                color: count > 0 ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                                icon: Icons.pending_actions_rounded,
                                onTap: () => context.push(Routes.adminRequests),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
          if (waitingCount > 0) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => context.push(Routes.adminWaitingList),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 15, color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Text(
                          '$waitingCount ${waitingCount == 1 ? "student" : "students"} in Waiting Queue',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3),
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text(
                          'View Queue',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF6366F1)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: () => context.push(Routes.adminSeats),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.map_outlined, size: 15, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Interactive Floor Plan & Seat Sections',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroMetricTile({
    required String label,
    required String value,
    required String subtext,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                subtext,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialPulseCard({
    required BuildContext context,
    required ThemeData theme,
    required List<StudentModel> students,
    required AsyncValue<NetProfitSummary> netProfitAsync,
    required bool canViewRevenue,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final defaulters = students.where((s) => (s.pendingDueBalance ?? 0) > 0).toList();
    final totalDueAmount = defaulters.fold<double>(0, (total, s) => total + (s.pendingDueBalance ?? 0));
    final fmt = NumberFormat('#,##,###');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Financial Pulse',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (canViewRevenue)
                InkWell(
                  onTap: () => context.push(Routes.adminRevenue),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Analytics',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (canViewRevenue)
            netProfitAsync.when(
              data: (np) {
                final isProfit = np.netProfit >= 0;
                return InkWell(
                  onTap: () => context.push(Routes.adminRevenue),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isProfit
                            ? [const Color(0xFF065F46), const Color(0xFF047857)]
                            : [const Color(0xFF991B1B), const Color(0xFFB91C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NET FACILITY PROFIT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.8),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${fmt.format(np.netProfit)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${np.profitMargin.toStringAsFixed(1)}% Margin',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '₹${fmt.format(np.grossRevenue)} Collected',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => Container(
                height: 70,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
          const SizedBox(height: 12),
          // Outstanding dues alert or healthy confirmation
          if (defaulters.isNotEmpty)
            InkWell(
              onTap: () => context.go(Uri(path: Routes.adminStudents, queryParameters: {'filter': 'Has Dues'}).toString()),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFDC2626)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${fmt.format(totalDueAmount)} Pending Fee Dues',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          Text(
                            '${defaulters.length} student(s) have overdue balances. Tap to review.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : const Color(0xFF7F1D1D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFDC2626)),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF059669)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All Fees 100% Settled • Zero Unpaid Dues Across Facility',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOperationalDock({
    required BuildContext context,
    required ThemeData theme,
    required int newToday,
    required int expiredToday,
    required int renewalsDue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Operational Action Dock',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
        // Primary 4-Action Dock
        Row(
          children: [
            Expanded(
              child: _AdminDockTile(
                icon: Icons.person_add_rounded,
                label: 'Add Student',
                color: const Color(0xFF2563EB),
                onTap: () => context.push(Routes.adminStudentAdd),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AdminDockTile(
                icon: Icons.payments_rounded,
                label: 'Collect Fee',
                color: const Color(0xFF059669),
                onTap: () => _showRecordPaymentPicker(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AdminDockTile(
                icon: Icons.chair_rounded,
                label: 'Seat Radar',
                color: const Color(0xFF7C3AED),
                onTap: () => context.push(Routes.adminSeats),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AdminDockTile(
                icon: Icons.campaign_rounded,
                label: 'Announce',
                color: const Color(0xFFD97706),
                onTap: () => context.push(Routes.adminAnnouncements),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Secondary Utilities Ribbon
        Row(
          children: [
            Expanded(
              child: _buildUtilityChip(
                context: context,
                theme: theme,
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan QR Pass',
                onTap: () => context.push(Routes.adminQrScanner),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildUtilityChip(
                context: context,
                theme: theme,
                icon: Icons.qr_code_2_rounded,
                label: 'Share QR Poster',
                onTap: () {
                  final currentLib = ref.read(currentLibraryProvider).value;
                  final libId = ref.read(currentLibraryIdProvider);
                  if (libId != null && libId.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (_) => ShareQrDialog(
                        libraryId: libId,
                        libraryName: currentLib?.name ?? 'Study Library',
                        address: currentLib?.address,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildUtilityChip(
                context: context,
                theme: theme,
                icon: Icons.alarm_rounded,
                label: '$renewalsDue Renew in 7d',
                color: renewalsDue > 0 ? const Color(0xFFEA580C) : null,
                onTap: () => context.go(Uri(path: Routes.adminStudents, queryParameters: {'filter': 'Due Soon'}).toString()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUtilityChip({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final effColor = color ?? (isDark ? Colors.white70 : const Color(0xFF475569));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: effColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: effColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDockTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminDockTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: isDark ? 0.3 : 0.15),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isDark ? Colors.white : color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
