import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_router.dart';

import 'package:study_library/services/inactivity_lock_service.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _AdminShellState extends ConsumerState<AdminShell> {
  @override
  void initState() {
    super.initState();
    InactivityLockService.initialize(
      onLock: () {
        if (mounted) context.go(Routes.biometricLock);
      },
      checkLockEnabled: () => BiometricService.isLockEnabled(isAdmin: true),
    );
  }

  @override
  void dispose() {
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
              leading: CircleAvatar(
                backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                child: Icon(Icons.person_add_rounded, color: Theme.of(ctx).colorScheme.primary),
              ),
              title: const Text('Add Student'),
              subtitle: const Text('Register new admission with ID & Desk'),
              onTap: () { Navigator.pop(ctx); context.push(Routes.adminStudentAdd); },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                child: Icon(Icons.payment_rounded, color: Theme.of(ctx).colorScheme.primary),
              ),
              title: const Text('Record Payment'),
              subtitle: const Text('Collect fees, deposit, or dues from student'),
              onTap: () {
                Navigator.pop(ctx);
                _showRecordPaymentPicker(context);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                child: Icon(Icons.meeting_room_rounded, color: Theme.of(ctx).colorScheme.primary),
              ),
              title: const Text('Add Section / Room'),
              subtitle: const Text('Create a new study hall, floor or cabin'),
              onTap: () { Navigator.pop(ctx); context.push(Routes.adminSeatsAddSection); },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                child: Icon(Icons.campaign_rounded, color: Theme.of(ctx).colorScheme.primary),
              ),
              title: const Text('Broadcast Notice'),
              subtitle: const Text('Post announcement to student dashboard'),
              onTap: () { Navigator.pop(ctx); context.push(Routes.adminAnnouncements); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentPicker(BuildContext context) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .orderBy('name')
          .limit(100)
          .get();

      if (!context.mounted) return;
      final students = snap.docs;
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
        builder: (sheetCtx) {
          String query = '';
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final filtered = students.where((doc) {
                final d = doc.data();
                final name = (d['name'] as String? ?? '').toLowerCase();
                final phone = (d['phone'] as String? ?? '');
                final q = query.toLowerCase();
                return name.contains(q) || phone.contains(q);
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
                            hintText: 'Search student to record payment...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (val) => setSheetState(() => query = val),
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
                                  final sDoc = filtered[index];
                                  final data = sDoc.data();
                                  final sId = sDoc.id;
                                  final sName = data['name'] as String? ?? 'Student';
                                  final sPhone = data['phone'] as String? ?? '';
                                  final sDue = (data['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(sName.isNotEmpty ? sName[0].toUpperCase() : '?'),
                                    ),
                                    title: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('$sPhone${sDue > 0 ? " • Due: ₹${sDue.toStringAsFixed(0)}" : ""}'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      context.push('/admin/payments/record/$sId');
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
    } catch (_) { /* intentionally silent */ }
  }

  Widget _badgedIcon(IconData icon, int count, {bool selected = false}) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(selected
          ? (icon == Icons.more_horiz_outlined ? Icons.more_horiz_rounded : icon)
          : icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMainTab = _isMainTab(context);
    final currentIndex = _getSelectedIndex(context);
    final pendingCount = ref.watch(_pendingCountProvider).value ?? 0;

    return PopScope(
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
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: isMainTab,
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
