import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/providers/theme_provider.dart';
import 'package:study_library/features/search/presentation/screens/global_search_screen.dart';
import 'package:study_library/features/dashboard/presentation/widgets/notification_center_sheet.dart';
import 'package:study_library/features/settings/presentation/screens/security_settings_dialog.dart';
import 'package:study_library/features/settings/presentation/widgets/typography_settings_sheet.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/services/inactivity_lock_service.dart';

/// Modern, unified Quick Control Center bottom sheet.
/// Consolidates all header actions (Instant Lock, Theme, Sync, Search/Pass,
/// Typography, Notifications, and Security) into a single 1-tap thumb-friendly hub.
class QuickControlCenterSheet extends ConsumerWidget {
  final bool isStudent;
  final String libraryId;
  final String? studentId;
  final String? authUid;
  final int unreadNotificationsCount;
  final int pendingRequestsCount;
  final int renewalsDueCount;

  const QuickControlCenterSheet({
    super.key,
    required this.isStudent,
    required this.libraryId,
    this.studentId,
    this.authUid,
    this.unreadNotificationsCount = 0,
    this.pendingRequestsCount = 0,
    this.renewalsDueCount = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isStudent,
    required String libraryId,
    String? studentId,
    String? authUid,
    int unreadNotificationsCount = 0,
    int pendingRequestsCount = 0,
    int renewalsDueCount = 0,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickControlCenterSheet(
        isStudent: isStudent,
        libraryId: libraryId,
        studentId: studentId,
        authUid: authUid,
        unreadNotificationsCount: unreadNotificationsCount,
        pendingRequestsCount: pendingRequestsCount,
        renewalsDueCount: renewalsDueCount,
      ),
    );
  }

  static Future<void> triggerInstantLock(
    BuildContext context,
    WidgetRef ref, {
    required bool isStudent,
    String? studentId,
    String? authUid,
    String? libraryId,
  }) async {
    HapticFeedback.heavyImpact();

    final effectiveLibId = (libraryId != null && libraryId.isNotEmpty)
        ? libraryId
        : ref.read(currentLibraryIdProvider) ?? '';
    final uid = authUid;
    final effectiveAuthUid = (uid != null && uid.isNotEmpty)
        ? uid
        : FirebaseAuth.instance.currentUser?.uid;

    final isLockEnabled = await BiometricService.isLockEnabled(
      isAdmin: !isStudent,
      userId: studentId,
      authUid: effectiveAuthUid,
      libraryId: effectiveLibId,
    );

    final safeContext = rootNavigatorKey.currentContext ?? context;
    if (!safeContext.mounted) return;

    if (isLockEnabled) {
      try {
        final currentUri = GoRouterState.of(safeContext).uri.path;
        if (currentUri.isNotEmpty && currentUri != Routes.biometricLock) {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('last_active_route', currentUri);
          }).catchError((_) {});
        }
      } catch (_) {}

      InactivityLockService.setLocked(true);
      safeContext.push(Routes.biometricLock);
    } else {
      _showPinSetupPrompt(
        safeContext,
        isStudent: isStudent,
        effectiveAuthUid: effectiveAuthUid,
        studentId: studentId,
        effectiveLibId: effectiveLibId,
      );
    }
  }

  static void _showPinSetupPrompt(
    BuildContext context, {
    required bool isStudent,
    String? effectiveAuthUid,
    String? studentId,
    required String effectiveLibId,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Set Up Quick App Lock',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isStudent
              ? 'Your student account does not have a 4-digit PIN configured yet. Set up a PIN or Fingerprint to lock your screen with 1 tap anytime.'
              : 'The counter terminal does not have an Admin PIN configured yet. Set up an Admin PIN to lock the reception screen with 1 tap.',
          style: const TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.key_rounded, size: 18),
            label: const Text('Set Up PIN Now'),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final rootCtx = rootNavigatorKey.currentContext;
                if (rootCtx != null && rootCtx.mounted) {
                  SecuritySettingsDialog.show(
                    rootCtx,
                    isStudent: isStudent,
                    authUid: effectiveAuthUid,
                    studentId: studentId,
                    libraryId: effectiveLibId,
                  );
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleInstantLock(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();

    final effectiveLibId = (libraryId.isNotEmpty)
        ? libraryId
        : ref.read(currentLibraryIdProvider) ?? '';
    final uid = authUid;
    final effectiveAuthUid = (uid != null && uid.isNotEmpty)
        ? uid
        : FirebaseAuth.instance.currentUser?.uid;

    final isLockEnabled = await BiometricService.isLockEnabled(
      isAdmin: !isStudent,
      userId: studentId,
      authUid: effectiveAuthUid,
      libraryId: effectiveLibId,
    );

    // 1. Pop the bottom sheet first so the overlay cleanly unmounts
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // 2. Dispatch the lock screen or setup prompt cleanly on the next frame via root navigator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rootCtx = rootNavigatorKey.currentContext;
      if (rootCtx == null || !rootCtx.mounted) return;

      if (isLockEnabled) {
        try {
          final currentUri = GoRouterState.of(rootCtx).uri.path;
          if (currentUri.isNotEmpty && currentUri != Routes.biometricLock) {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('last_active_route', currentUri);
            }).catchError((_) {});
          }
        } catch (_) {}

        InactivityLockService.setLocked(true);
        rootCtx.push(Routes.biometricLock);
      } else {
        _showPinSetupPrompt(
          rootCtx,
          isStudent: isStudent,
          effectiveAuthUid: effectiveAuthUid,
          studentId: studentId,
          effectiveLibId: effectiveLibId,
        );
      }
    });
  }

  void _handleDataSync(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    ref.invalidate(currentLibraryProvider);
    if (isStudent) {
      ref.invalidate(currentStudentProvider);
    } else {
      ref.invalidate(studentsStreamProvider);
      ref.invalidate(occupancyProvider);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            SizedBox(width: 10),
            Text('Synchronizing latest library & profile data...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark;
    final totalUnread = unreadNotificationsCount + pendingRequestsCount + renewalsDueCount;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick Control Center',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                isStudent
                                    ? 'Student Privacy & Screen Shortcuts'
                                    : 'Front-Desk & Terminal Security Shortcuts',
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
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Deterministic Action Rows (Zero LayoutBuilder/Wrap to prevent Web intrinsic freeze)
                    // Row 1: Instant Screen Lock & Theme Toggle
                    Row(
                      children: [
                        Expanded(
                          child: _buildControlTile(
                            context,
                            icon: Icons.lock_rounded,
                            iconColor: const Color(0xFFEF4444),
                            bgColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            title: 'Instant Lock',
                            subtitle: 'Shield screen immediately',
                            onTap: () => _handleInstantLock(context, ref),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildControlTile(
                            context,
                            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            iconColor: isDark ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
                            bgColor: (isDark ? const Color(0xFFF59E0B) : const Color(0xFF6366F1)).withValues(alpha: 0.12),
                            title: isDark ? 'Light Theme' : 'Dark Theme',
                            subtitle: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(themeNotifierProvider.notifier).toggleTheme();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 2: Sync Live Data & Typography
                    Row(
                      children: [
                        Expanded(
                          child: _buildControlTile(
                            context,
                            icon: Icons.sync_rounded,
                            iconColor: const Color(0xFF10B981),
                            bgColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                            title: 'Sync Live Data',
                            subtitle: 'Refresh cloud data',
                            onTap: () => _handleDataSync(context, ref),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildControlTile(
                            context,
                            icon: Icons.format_size_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            title: 'Typography',
                            subtitle: 'Text size & font styles',
                            onTap: () {
                              Navigator.of(context).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final rootCtx = rootNavigatorKey.currentContext;
                                if (rootCtx != null && rootCtx.mounted) {
                                  TypographySettingsSheet.show(rootCtx);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 3: Search / ID Card & Notifications
                    Row(
                      children: [
                        Expanded(
                          child: !isStudent
                              ? _buildControlTile(
                                  context,
                                  icon: Icons.search_rounded,
                                  iconColor: const Color(0xFF0284C7),
                                  bgColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                  title: 'Global Search',
                                  subtitle: 'Students, desks & plans',
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      final rootCtx = rootNavigatorKey.currentContext;
                                      if (rootCtx != null && rootCtx.mounted) {
                                        Navigator.of(rootCtx, rootNavigator: true).push(
                                          MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                                        );
                                      }
                                    });
                                  },
                                )
                              : _buildControlTile(
                                  context,
                                  icon: Icons.badge_outlined,
                                  iconColor: const Color(0xFF0284C7),
                                  bgColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                  title: 'My ID Card',
                                  subtitle: 'Digital pass & barcode',
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      final rootCtx = rootNavigatorKey.currentContext;
                                      if (rootCtx != null && rootCtx.mounted) {
                                        rootCtx.push(Routes.studentIdCard);
                                      }
                                    });
                                  },
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildControlTile(
                            context,
                            icon: Icons.notifications_active_rounded,
                            iconColor: totalUnread > 0 ? const Color(0xFFF97316) : const Color(0xFF64748B),
                            bgColor: (totalUnread > 0 ? const Color(0xFFF97316) : const Color(0xFF64748B)).withValues(alpha: 0.12),
                            badgeText: totalUnread > 0 ? '$totalUnread' : null,
                            title: 'Notifications',
                            subtitle: totalUnread > 0 ? '$totalUnread actionable items' : 'View history & updates',
                            onTap: () {
                              Navigator.of(context).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final rootCtx = rootNavigatorKey.currentContext;
                                if (rootCtx != null && rootCtx.mounted) {
                                  NotificationCenterSheet.show(
                                    rootCtx,
                                    libraryId: libraryId,
                                    role: isStudent ? 'student' : 'admin',
                                    studentId: studentId,
                                    pendingRequestsCount: pendingRequestsCount,
                                    renewalsDueCount: renewalsDueCount,
                                  );
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    // Row 4 (Admin only): Sentinel AI Guardian & Audit Trail
                    if (!isStudent) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildControlTile(
                              context,
                              icon: Icons.health_and_safety_rounded,
                              iconColor: const Color(0xFF059669),
                              bgColor: const Color(0xFF059669).withValues(alpha: 0.12),
                              title: 'Sentinel AI Guardian',
                              subtitle: 'Health & integrity audit',
                              onTap: () {
                                Navigator.of(context).pop();
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  final rootCtx = rootNavigatorKey.currentContext;
                                  if (rootCtx != null && rootCtx.mounted) {
                                    rootCtx.push(Routes.sentinelDiagnostics);
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildControlTile(
                              context,
                              icon: Icons.history_rounded,
                              iconColor: const Color(0xFF0D9488),
                              bgColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
                              title: 'Audit Log',
                              subtitle: 'Staff activity & events',
                              onTap: () {
                                Navigator.of(context).pop();
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  final rootCtx = rootNavigatorKey.currentContext;
                                  if (rootCtx != null && rootCtx.mounted) {
                                    rootCtx.push(Routes.adminAuditLog);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Bottom Pro-Tip Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security_rounded, size: 18, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isStudent
                                  ? 'Instant Lock shields your active screen with PIN / Fingerprint.'
                                  : 'Reception staff can 1-tap lock the terminal before stepping away.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final rootCtx = rootNavigatorKey.currentContext;
                                if (rootCtx != null && rootCtx.mounted) {
                                  SecuritySettingsDialog.show(
                                    rootCtx,
                                    isStudent: isStudent,
                                    authUid: authUid,
                                    studentId: studentId,
                                    libraryId: libraryId,
                                  );
                                }
                              });
                            },
                            child: const Text('Security', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlTile(
    BuildContext context, {
    double? width,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          color: theme.colorScheme.surfaceContainerLow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
