import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/services/badge_service.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/search/presentation/screens/global_search_screen.dart';
import 'package:study_library/features/dashboard/presentation/widgets/revenue_chart.dart';
import 'package:study_library/features/dashboard/presentation/widgets/app_update_banner.dart';
import 'package:study_library/features/seats/presentation/widgets/share_qr_dialog.dart';
import 'package:study_library/services/expiry_notification_service.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/services/membership_automation_service.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';
import 'package:study_library/services/backup_service.dart';
import 'package:study_library/features/admin_qr/presentation/screens/admin_qr_scanner_screen.dart';
import 'package:study_library/core/widgets/loading_skeleton.dart';
import 'package:study_library/services/quick_actions_service.dart';
import 'package:study_library/services/remote_config_service.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with WidgetsBindingObserver {
  int _newToday = 0;
  int _expiredToday = 0;
  int _renewalsDue = 0;
  StreamSubscription<QuerySnapshot>? _pendingRequestsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _watchPendingRequests();
    _initQuickActions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_pendingRequestsSub == null) _watchPendingRequests();
        WhatsNewService.checkAndShow(context, isStudent: false);
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
          context.push(Routes.adminStudents);
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
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
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
    final students = ref.read(studentsStreamProvider).value ?? [];
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students registered yet. Add a student first.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = students.where((s) {
              final q = searchQuery.toLowerCase();
              return s.name.toLowerCase().contains(q) || s.phone.contains(q);
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search student by name or phone...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) => setSheetState(() => searchQuery = val),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No matching students found'))
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final student = filtered[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?'),
                                  ),
                                  title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(student.phone),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    context.push('/admin/payments/record/${student.id}');
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
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
      data: (lib) => lib?.name ?? 'Cozy Corner',
      loading: () => 'Cozy Corner',
      error: (_, _) => 'Cozy Corner',
    );

    // Check for expiring plans (fire and forget)
    final libId = ref.watch(currentLibraryIdProvider);
    if (libId != null && libId.isNotEmpty) {
      ExpiryNotificationService.checkExpiringPlans(libId);
    }

    final currentStaff = ref.watch(currentUserStaffProvider).value;
    final canViewRevenue = currentStaff?.canViewRevenue ?? true;

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
          Expanded(
            child: RefreshIndicator(
                onRefresh: () async {
          ref.invalidate(occupancyProvider);
          ref.invalidate(studentsStreamProvider);
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
                        Text('$_greeting, $displayName!', style: theme.textTheme.titleMedium),
                        Text(libraryName, style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.bold,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppUpdateBanner(),
                    // Stats Cards
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _StatCard(
                            title: 'Total Students',
                            value: studentsAsync.when(
                              data: (s) => '${s.length}',
                              loading: () => '...',
                              error: (_, _) => '0',
                            ),
                            icon: Icons.people_rounded,
                            onTap: () => context.push(Routes.adminStudents),
                          ),
                          _StatCard(
                            title: 'Occupied Seats',
                            value: occupancy.when(
                              data: (o) => '${o['occupied'] ?? 0}/${o['total'] ?? 0}',
                              loading: () => '...',
                              error: (_, _) => '0',
                            ),
                            icon: Icons.event_seat_rounded,
                            onTap: () => context.push(Routes.adminSeats),
                          ),
                          _StatCard(
                            title: 'Available Seats',
                            value: occupancy.when(
                              data: (o) => '${o['available'] ?? 0}',
                              loading: () => '...',
                              error: (_, _) => '0',
                            ),
                            icon: Icons.chair_rounded,
                            onTap: () => context.push(Routes.adminSeats),
                          ),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: (libId != null && libId.isNotEmpty)
                                ? FirebaseFirestore.instance
                                    .collection('libraries')
                                    .doc(libId)
                                    .collection('requests')
                                    .where('status', isEqualTo: 'pending')
                                    .snapshots()
                                : null,
                            builder: (context, reqSnap) {
                              final count = reqSnap.data?.docs.length ?? 0;
                              return _StatCard(
                                title: 'Pending Requests',
                                value: reqSnap.connectionState == ConnectionState.waiting ? '...' : '$count',
                                icon: Icons.pending_actions_rounded,
                                onTap: () => context.push(Routes.adminRequests),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Today's Activity section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                      child: Text("Today's Activity", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    Row(
                      children: [
                        _TodayStatChip(count: _newToday, label: 'Joined Today', icon: Icons.person_add_alt_1_rounded, color: Colors.green),
                        const SizedBox(width: 8),
                        _TodayStatChip(count: _expiredToday, label: 'Expired Today', icon: Icons.timer_off_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        _TodayStatChip(count: _renewalsDue, label: 'Renew in 7d', icon: Icons.alarm_rounded, color: Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions
                    Text('Quick Actions', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _QuickActionChip(
                          icon: Icons.person_add_rounded,
                          label: 'Add Student',
                          onTap: () => context.push(Routes.adminStudentAdd),
                        ),
                        _QuickActionChip(
                          icon: Icons.bar_chart_rounded,
                          label: 'Revenue',
                          onTap: () => context.push(Routes.adminRevenue),
                        ),
                        _QuickActionChip(
                          icon: Icons.payment_rounded,
                          label: 'Record Payment',
                          onTap: () => _showRecordPaymentPicker(context),
                        ),
                        _QuickActionChip(
                          icon: Icons.campaign_rounded,
                          label: 'Announcement',
                          onTap: () => context.push(Routes.adminAnnouncements),
                        ),
                        _QuickActionChip(
                          icon: Icons.qr_code_rounded,
                          label: 'Share QR',
                          onTap: () {
                            final currentLib = ref.read(currentLibraryProvider).value;
                            final libId = ref.read(currentLibraryIdProvider);
                            if (libId != null && libId.isNotEmpty) {
                              showDialog(
                                context: context,
                                builder: (_) => ShareQrDialog(
                                  libraryId: libId,
                                  libraryName: currentLib?.name ?? 'Cozy Corner',
                                  address: currentLib?.address,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select or configure a library first')),
                              );
                            }
                          },
                        ),
                        _QuickActionChip(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Scan Student',
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminQrScannerScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Revenue Chart (Owners & Managers only)
                    if (canViewRevenue) ...[
                      const RevenueChart(),
                      const SizedBox(height: 24),
                    ],

                    // Recent Students
                    Text('Recent Students', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    studentsAsync.when(
                      data: (students) {
                        if (students.isEmpty) {
                          return Card(
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
                          );
                        }
                        final recentStudents = students.take(5).toList();
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentStudents.length,
                          itemBuilder: (context, index) {
                            final student = recentStudents[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?'),
                                ),
                                title: Text(student.name),
                                subtitle: Text(student.phone),
                                trailing: Chip(
                                  label: Text(
                                    student.membershipStatus.name,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const DashboardSkeleton(),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}

class _TodayStatChip extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color;
  const _TodayStatChip({required this.count, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
