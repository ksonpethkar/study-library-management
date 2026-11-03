import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/models/app_notification_model.dart';
import 'package:study_library/services/app_notification_service.dart';

/// Floating in-app toast notification banner that slides down smoothly from the top
/// when a real-time notification arrives while the user is actively using the app.
class InAppNotificationToast {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  /// Display a floating top toast banner for an incoming notification.
  static void show(
    BuildContext context, {
    required AppNotificationModel notification,
    required String libraryId,
    VoidCallback? onTap,
  }) {
    // Dismiss any existing toast first
    dismiss();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // Haptic feedback for arrival
    HapticFeedback.lightImpact();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _InAppToastBanner(
        notification: notification,
        libraryId: libraryId,
        onDismiss: dismiss,
        onTap: () async {
          dismiss();
          HapticFeedback.mediumImpact();
          // Mark notification as read
          if (!notification.read) {
            await AppNotificationService.markAsRead(
              libraryId: libraryId,
              notificationId: notification.id,
            );
          }
          if (onTap != null) {
            onTap();
          } else if (notification.actionRoute != null &&
              notification.actionRoute!.isNotEmpty &&
              context.mounted) {
            context.push(notification.actionRoute!);
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    // Auto dismiss after 4.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 4500), () {
      dismiss();
    });
  }

  /// Manually dismiss the active toast
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _InAppToastBanner extends StatefulWidget {
  final AppNotificationModel notification;
  final String libraryId;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _InAppToastBanner({
    required this.notification,
    required this.libraryId,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_InAppToastBanner> createState() => _InAppToastBannerState();
}

class _InAppToastBannerState extends State<_InAppToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  (IconData, Color) _getTypeVisuals(String type) {
    return switch (type) {
      'payment' || 'receipt' => (Icons.receipt_long_rounded, const Color(0xFF10B981)),
      'admission' || 'new_registration' => (Icons.school_rounded, const Color(0xFF3B82F6)),
      'seat' || 'seat_change' => (Icons.event_seat_rounded, const Color(0xFF8B5CF6)),
      'expiry' || 'due' || 'renewal' => (Icons.alarm_rounded, const Color(0xFFF59E0B)),
      'announcement' => (Icons.campaign_rounded, const Color(0xFF6366F1)),
      'feedback' || 'feedback_reply' => (Icons.feedback_rounded, const Color(0xFF14B8A6)),
      'profile_update_request' => (Icons.manage_accounts_rounded, const Color(0xFF06B6D4)),
      _ => (Icons.notifications_active_rounded, const Color(0xFF64748B)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, iconColor) = _getTypeVisuals(widget.notification.type);
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _offsetAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Dismissible(
              key: Key('toast_${widget.notification.id}'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth: mediaQuery.size.width > 600 ? 480 : mediaQuery.size.width,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Type Icon Avatar with subtle glow
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 12),

                          // Text Content
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.notification.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Just now',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.notification.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Action indicator / Dismiss icon
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: theme.colorScheme.onSurfaceVariant,
                            onPressed: _handleDismiss,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
