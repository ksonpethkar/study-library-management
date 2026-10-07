import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'app_router.dart';

import 'package:study_library/services/inactivity_lock_service.dart';

/// Admin shell with PopScope exit-app dialog so back never closes the app silently.
class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  @override
  void initState() {
    super.initState();
    InactivityLockService.initialize(onLock: () {
      if (mounted) context.go(Routes.biometricLock);
    });
  }

  @override
  void dispose() {
    InactivityLockService.dispose();
    super.dispose();
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(Routes.adminSeats)) return 1;
    if (location.startsWith(Routes.adminStudents)) return 2;
    if (location.startsWith(Routes.adminMore)) return 3;
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.person_add_rounded, color: Color(0xFF4F46E5)),
              ),
              title: const Text('Add Student'),
              onTap: () { Navigator.pop(ctx); context.push(Routes.adminStudentAdd); },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5)),
              ),
              title: const Text('View Receipts'),
              onTap: () { Navigator.pop(ctx); context.push(Routes.adminReceipts); },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.event_seat_rounded, color: Color(0xFF4F46E5)),
              ),
              title: const Text('Add Section'),
              onTap: () { Navigator.pop(ctx); context.push(Routes.adminSeatsAddSection); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getSelectedIndex(context);

    return PopScope(
      // canPop = false means we handle pop ourselves
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you want to exit the application?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          // Properly exit the Android app
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Listener(
          onPointerDown: (_) => InactivityLockService.recordInteraction(),
          child: widget.child,
        ),
        floatingActionButton: currentIndex == 3
            ? null
            : FloatingActionButton(
                heroTag: 'admin_fab',
                onPressed: () => _showQuickActions(context),
                child: const Icon(Icons.add_rounded),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => _onItemTapped(context, index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_seat_outlined),
              selectedIcon: Icon(Icons.event_seat_rounded),
              label: 'Seats',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Students',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
