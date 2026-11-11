import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_router.dart';
import 'package:study_library/features/dashboard/presentation/widgets/quick_action_studio_sheet.dart';

import 'package:study_library/services/inactivity_lock_service.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/features/requests/presentation/providers/request_providers.dart';
import 'package:study_library/models/app_notification_model.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/services/in_app_notification_toast.dart';
import 'package:study_library/core/widgets/pulsing_glow_container.dart';

/// Stream provider for pending request count shown in the bottom nav badge.
final _pendingCountProvider = StreamProvider.autoDispose<int>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('requests')
      .where('status', whereIn: ['pending', 'desk_payment_pending', 'payment_pending'])
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Admin shell with PopScope exit-app dialog so back never closes the app silently.
class AdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> with WidgetsBindingObserver {
  DateTime? _shellStartTime;
  DateTime? _lastBackPressTime;
  final Set<String> _seenNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    InactivityLockService.initialize(
      onLock: () {
        if (mounted) context.go(Routes.biometricLock);
      },
      checkLockEnabled: () => BiometricService.isLockEnabled(isAdmin: true),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    InactivityLockService.onAppLifecycleStateChanged(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    InactivityLockService.dispose();
    super.dispose();
  }

  bool _isMainTab(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return location == Routes.adminHome ||
        location == Routes.adminSeats ||
        location == Routes.adminStudents ||
        location == Routes.adminMore;
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == Routes.adminSeats) return 1;
    if (location == Routes.adminStudents) return 2;
    if (location == Routes.adminMore) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(Routes.adminHome); break;
      case 1: context.go(Routes.adminSeats); break;
      case 2: context.go(Routes.adminStudents); break;
      case 3: context.go(Routes.adminMore); break;
    }
  }

  void _showQuickActions(BuildContext context) {
    QuickActionStudioSheet.show(context, ref);
  }

  Widget _badgedIcon(IconData icon, int count, {bool selected = false}) {
    final baseIcon = Icon(selected
        ? (icon == Icons.more_horiz_outlined ? Icons.more_horiz_rounded : icon)
        : icon);
    if (count <= 0) return baseIcon;

    return Badge(
      isLabelVisible: true,
      backgroundColor: const Color(0xFFEA580C),
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          baseIcon,
          Positioned(
            top: -2,
            right: -3,
            child: IgnorePointer(
              child: LiveRadarDot(
                color: const Color(0xFFEA580C),
                size: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMainTab = _isMainTab(context);
    final currentIndex = _getSelectedIndex(context);
    final reqCounts = ref.watch(requestModuleCountsProvider);
    final pendingCount = reqCounts.totalActionableItems > 0
        ? reqCounts.totalActionableItems
        : (ref.watch(_pendingCountProvider).value ?? 0);

    final libraryId = ref.watch(currentLibraryIdProvider);
    ref.listen<AsyncValue<List<AppNotificationModel>>>(
      adminNotificationsStreamProvider,
      (previous, next) {
        final notifications = next.value;
        if (notifications == null || notifications.isEmpty) return;

        final now = DateTime.now();
        _shellStartTime ??= now;

        if (previous == null || previous.isLoading || previous.value == null) {
          _seenNotificationIds.addAll(notifications.map((n) => n.id));
          return;
        }

        for (final notif in notifications) {
          if (!_seenNotificationIds.contains(notif.id)) {
            _seenNotificationIds.add(notif.id);
            if (!notif.read &&
                notif.createdAt.isAfter(_shellStartTime!.subtract(const Duration(minutes: 2)))) {
              if (context.mounted && libraryId != null && libraryId.isNotEmpty) {
                InAppNotificationToast.show(
                  context,
                  notification: notif,
                  libraryId: libraryId,
                );
              }
              break;
            }
          }
        }
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final currentIndex = _getSelectedIndex(context);
        if (currentIndex != 0) {
          // Layer 2: On secondary tabs (Seats, Students, More), return to Admin Home tab
          _onItemTapped(context, 0);
          return;
        }

        // Layer 3: Already on Home tab: double-tap back to exit with 2-second timeout (Leading app standard)
        final now = DateTime.now();
        final last = _lastBackPressTime;
        if (last == null || now.difference(last) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Second press within 2 seconds: close app cleanly
        if (context.mounted) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: false,
        body: Listener(
          onPointerDown: (_) => InactivityLockService.recordInteraction(),
          child: widget.child,
        ),
        floatingActionButton: (isMainTab && currentIndex == 0)
            ? FloatingActionButton(
                heroTag: 'admin_fab',
                onPressed: () {
                  AppHaptics.medium();
                  _showQuickActions(context);
                },
                child: const Icon(Icons.add_rounded),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: isMainTab
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      selectedIndex: currentIndex,
                      onDestinationSelected: (index) {
                        AppHaptics.light();
                        _onItemTapped(context, index);
                      },
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Home',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.event_seat_outlined),
                          selectedIcon: Icon(Icons.event_seat_rounded),
                          label: 'Seats',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.people_outline_rounded),
                          selectedIcon: Icon(Icons.people_rounded),
                          label: 'Students',
                        ),
                        NavigationDestination(
                          icon: _badgedIcon(Icons.more_horiz_outlined, pendingCount),
                          selectedIcon: _badgedIcon(Icons.more_horiz_rounded, pendingCount, selected: true),
                          label: 'More',
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
