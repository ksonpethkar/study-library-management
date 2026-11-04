import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/utils/app_haptics.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/models/app_notification_model.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/services/in_app_notification_toast.dart';
import 'package:study_library/services/inactivity_lock_service.dart';
import 'package:study_library/services/biometric_service.dart';
import 'app_router.dart';

/// Student shell with PopScope exit-app dialog so back never closes the app silently,
/// and live foreground in-app toast notification stream listener.
class StudentShell extends ConsumerStatefulWidget {
  final Widget child;
  const StudentShell({super.key, required this.child});

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> with WidgetsBindingObserver {
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
      checkLockEnabled: () => BiometricService.isLockEnabled(isAdmin: false),
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
    return location == Routes.studentHome ||
        location == Routes.studentMembership ||
        location == Routes.studentReceipts ||
        location == Routes.studentProfile;
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == Routes.studentMembership) return 1;
    if (location == Routes.studentReceipts) return 2;
    if (location == Routes.studentProfile) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(Routes.studentHome); break;
      case 1: context.go(Routes.studentMembership); break;
      case 2: context.go(Routes.studentReceipts); break;
      case 3: context.go(Routes.studentProfile); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMainTab = _isMainTab(context);
    final libraryId = ref.watch(currentLibraryIdProvider);
    final student = ref.watch(currentStudentProvider).value;
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveId = (student?.id != null && student!.id.isNotEmpty)
        ? student.id
        : authUid;

    // Listen to real-time student notifications for foreground floating toast
    if (effectiveId != null && effectiveId.isNotEmpty) {
      ref.listen<AsyncValue<List<AppNotificationModel>>>(
        studentNotificationsStreamProvider(effectiveId),
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
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final currentIndex = _getSelectedIndex(context);
        if (currentIndex != 0) {
          // Layer 2: On secondary tabs (Membership, Receipts, Profile), return to Home tab
          _onItemTapped(context, 0);
          return;
        }

        // Layer 3: Already on Home tab: double-tap back to exit with 2-second timeout (Leading app standard)
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
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
        extendBody: isMainTab,
        body: InactivityDetectorWrapper(child: widget.child),
        bottomNavigationBar: isMainTab
            ? SafeArea(
                top: false,
                child: ClipRect(
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
                        selectedIndex: _getSelectedIndex(context),
                        onDestinationSelected: (index) {
                          AppHaptics.light();
                          _onItemTapped(context, index);
                        },
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: 'Home',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.card_membership_outlined),
                            selectedIcon: Icon(Icons.card_membership_rounded),
                            label: 'Membership',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.receipt_long_outlined),
                            selectedIcon: Icon(Icons.receipt_long_rounded),
                            label: 'Receipts',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.person_outline_rounded),
                            selectedIcon: Icon(Icons.person_rounded),
                            label: 'Profile',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
