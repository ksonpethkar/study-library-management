import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/services/badge_service.dart';

class AccessRestrictedScreen extends ConsumerStatefulWidget {
  const AccessRestrictedScreen({super.key});

  @override
  ConsumerState<AccessRestrictedScreen> createState() => _AccessRestrictedScreenState();
}

class _AccessRestrictedScreenState extends ConsumerState<AccessRestrictedScreen> {
  Timer? _autoCheckTimer;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _silentlyCheckRole();
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  /// Within 3 seconds, silently verify role in background.
  /// If user has a valid persisted role, redirect without showing "Access Denied".
  Future<void> _silentlyCheckRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    try {
      final persisted = await readPersistedUserRole(user.uid).timeout(const Duration(seconds: 3));
      if (!mounted) return;

      if (persisted != null && persisted['role'] != null) {
        final roleStr = persisted['role'] as String;
        final libId = (persisted['libraryId'] ?? '') as String;

        if (roleStr == AppUserRole.admin.name) {
          if (libId.isNotEmpty) ref.read(currentLibraryIdProvider.notifier).set(libId);
          ref.read(userRoleProvider.notifier).setRole(AppUserRole.admin);
          if (mounted) context.go(Routes.adminHome);
          return;
        }

        if (roleStr == AppUserRole.student.name) {
          if (libId.isNotEmpty) ref.read(currentLibraryIdProvider.notifier).set(libId);
          ref.read(userRoleProvider.notifier).setRole(AppUserRole.student);
          if (mounted) context.go(Routes.studentHome);
          return;
        }
      }
    } catch (_) {}

    // No valid role found — show the access denied UI
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Unknown Email';
    final photoUrl = user?.photoURL;

    // Show a minimal loading screen while silently checking
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Verifying access…', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false, // no back — show buttons only
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: theme.colorScheme.errorContainer,
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Icon(Icons.lock_person_rounded,
                          size: 48, color: theme.colorScheme.error)
                      : null,
                ),
                const SizedBox(height: 20),

                Text(
                  'Access Denied',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),

                // Account badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          email,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security_rounded,
                                color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your account does not have access to this section.',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        const Text(
                          '• If you are a student — sign out and choose "I\'m a Student" on the login screen.\n'
                          '• If you are an admin — your email may not be whitelisted. Contact your system administrator.\n'
                          '• If you believe this is an error — sign out and try again.',
                          style: TextStyle(height: 1.6, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Sign out and go back to login (clears role)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign Out & Choose Role'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.brightness == Brightness.dark
                          ? Colors.brown.shade900
                          : theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      // Clear role so redirect guard lets login through
                      ref.read(userRoleProvider.notifier).clear();
                      ref.read(currentLibraryIdProvider.notifier).clear();
                      await BadgeService.clearBadge();
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) context.go(Routes.login);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.how_to_reg_rounded),
                    label: const Text('Register as Student'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ref
                          .read(userRoleProvider.notifier)
                          .setRole(AppUserRole.student);
                      context.go(Routes.studentRegister);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

