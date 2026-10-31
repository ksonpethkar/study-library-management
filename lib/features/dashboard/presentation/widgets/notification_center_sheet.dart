import 'package:study_library/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:study_library/models/app_notification_model.dart';
import 'package:study_library/services/app_notification_service.dart';

class NotificationCenterSheet extends ConsumerStatefulWidget {
  final String libraryId;
  final String role; // 'admin' or 'student'
  final String? studentId;
  final int pendingRequestsCount;
  final int renewalsDueCount;

  const NotificationCenterSheet({
    super.key,
    required this.libraryId,
    required this.role,
    this.studentId,
    this.pendingRequestsCount = 0,
    this.renewalsDueCount = 0,
  });

  static void show(
    BuildContext context, {
    required String libraryId,
    required String role,
    String? studentId,
    int pendingRequestsCount = 0,
    int renewalsDueCount = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationCenterSheet(
        libraryId: libraryId,
        role: role,
        studentId: studentId,
        pendingRequestsCount: pendingRequestsCount,
        renewalsDueCount: renewalsDueCount,
      ),
    );
  }

  @override
  ConsumerState<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends ConsumerState<NotificationCenterSheet> {
  bool _showOnlyUnread = false;

  @override
  void initState() {
    super.initState();
    if (widget.libraryId.isNotEmpty && widget.role == 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(systemAlertsProvider(widget.libraryId).notifier).syncCounts(
            currentPending: widget.pendingRequestsCount,
            currentRenewals: widget.renewalsDueCount,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifsAsync = widget.role == 'admin'
        ? ref.watch(adminNotificationsStreamProvider)
        : ref.watch(studentNotificationsStreamProvider(widget.studentId));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.role == 'admin' ? 'Desk & Admission Alerts' : 'My Pass & Seat Alerts',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          HapticFeedback.heavyImpact();
                          await AppNotificationService.markAllAsRead(
                            libraryId: widget.libraryId,
                            targetRole: widget.role,
                            targetUserId: widget.studentId,
                          );
                          if (widget.role == 'admin' && widget.libraryId.isNotEmpty) {
                            await ref.read(systemAlertsProvider(widget.libraryId).notifier).acknowledgeAll(
                              pendingCount: widget.pendingRequestsCount,
                              renewalsCount: widget.renewalsDueCount,
                            );
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All notifications marked as read'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await AppNotificationService.clearAllRead(
                            libraryId: widget.libraryId,
                            targetRole: widget.role,
                            targetUserId: widget.studentId,
                          );
                          if (widget.role == 'admin' && widget.libraryId.isNotEmpty) {
                            await ref.read(systemAlertsProvider(widget.libraryId).notifier).acknowledgeAll(
                              pendingCount: widget.pendingRequestsCount,
                              renewalsCount: widget.renewalsDueCount,
                            );
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Read notifications cleared!'),
                                duration: Duration(milliseconds: 1400),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                        label: const Text('Clear Read', style: TextStyle(fontSize: 12)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Alerts'),
                    selected: !_showOnlyUnread,
                    onSelected: (val) {
                      if (val) setState(() => _showOnlyUnread = false);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF06B6D4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: const Text('Unread Only'),
                    selected: _showOnlyUnread,
                    onSelected: (val) {
                      if (val) setState(() => _showOnlyUnread = true);
                    },
                  ),
                ],
              ),
            ),

            // Notification Feed List
            Expanded(
              child: notifsAsync.when(
                data: (notifications) {
                  final alertsState = (widget.libraryId.isNotEmpty && widget.role == 'admin')
                      ? ref.watch(systemAlertsProvider(widget.libraryId))
                      : const SystemAlertsState();
                  final unreadPending = (widget.pendingRequestsCount - alertsState.acknowledgedPendingCount).clamp(0, 999999);
                  final unreadRenewals = (widget.renewalsDueCount - alertsState.acknowledgedRenewalsCount).clamp(0, 999999);

                  // Merge system alerts for admin
                  final items = _showOnlyUnread
                      ? notifications.where((n) => !n.read).toList()
                      : notifications;

                  final showPending = widget.role == 'admin' &&
                      widget.pendingRequestsCount > 0 &&
                      (!_showOnlyUnread || unreadPending > 0);

                  final showRenewals = widget.role == 'admin' &&
                      widget.renewalsDueCount > 0 &&
                      (!_showOnlyUnread || unreadRenewals > 0);

                  if (items.isEmpty && !showPending && !showRenewals) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 56, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              _showOnlyUnread ? 'No Unread Notifications' : 'No Notifications Yet',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "You're all caught up with your study center updates.",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Admin System Alerts (Pending Admissions & Expiries)
                      if (widget.role == 'admin') ...[
                        if (showPending)
                          _buildSystemAlertTile(
                            context: context,
                            theme: theme,
                            icon: Icons.pending_actions_rounded,
                            iconColor: Colors.red,
                            title: '${widget.pendingRequestsCount} Pending Student Applications',
                            body: 'New student admissions are awaiting verification & approval.',
                            badgeText: unreadPending > 0
                                ? '${widget.pendingRequestsCount} New'
                                : '${widget.pendingRequestsCount} Pending • Read',
                            badgeColor: Colors.red,
                            isUnread: unreadPending > 0,
                            onMarkRead: unreadPending > 0
                                ? () {
                                    HapticFeedback.lightImpact();
                                    ref.read(systemAlertsProvider(widget.libraryId).notifier)
                                        .acknowledgePending(widget.pendingRequestsCount);
                                  }
                                : null,
                            onTap: () {
                              ref.read(systemAlertsProvider(widget.libraryId).notifier)
                                  .acknowledgePending(widget.pendingRequestsCount);
                              Navigator.pop(context);
                              context.go(Routes.adminRequests);
                            },
                          ),
                        if (showRenewals)
                          _buildSystemAlertTile(
                            context: context,
                            theme: theme,
                            icon: Icons.alarm_rounded,
                            iconColor: Colors.orange.shade800,
                            title: '${widget.renewalsDueCount} Membership${widget.renewalsDueCount > 1 ? "s" : ""} Expiring Soon',
                            body: 'Follow up with students to renew study plans and retain seats.',
                            badgeText: unreadRenewals > 0
                                ? '${widget.renewalsDueCount} Due'
                                : '${widget.renewalsDueCount} Due • Read',
                            badgeColor: Colors.orange.shade800,
                            isUnread: unreadRenewals > 0,
                            onMarkRead: unreadRenewals > 0
                                ? () {
                                    HapticFeedback.lightImpact();
                                    ref.read(systemAlertsProvider(widget.libraryId).notifier)
                                        .acknowledgeRenewals(widget.renewalsDueCount);
                                  }
                                : null,
                            onTap: () {
                              ref.read(systemAlertsProvider(widget.libraryId).notifier)
                                  .acknowledgeRenewals(widget.renewalsDueCount);
                              Navigator.pop(context);
                              context.go('${Routes.adminStudents}?filter=Due Soon');
                            },
                          ),
                      ],

                      // Firestore Stream Items with Individual Unread Dots
                      ...items.map((notif) => _buildNotificationItem(context, theme, notif)),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, ThemeData theme, AppNotificationModel notif) {
    final dateFormat = DateFormat('dd MMM • h:mm a');
    final (icon, iconColor) = _getTypeVisuals(notif.type);

    return Dismissible(
      key: Key('notif_${notif.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text('Dismiss', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
      onDismissed: (_) async {
        HapticFeedback.mediumImpact();
        await AppNotificationService.deleteNotification(
          libraryId: widget.libraryId,
          notificationId: notif.id,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: !notif.read
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.22)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !notif.read
                ? theme.colorScheme.primary.withValues(alpha: 0.35)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: !notif.read ? 1.5 : 1,
          ),
        ),
        child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          HapticFeedback.lightImpact();
          if (!notif.read) {
            await AppNotificationService.markAsRead(
              libraryId: widget.libraryId,
              notificationId: notif.id,
            );
          }
          if (notif.actionRoute != null && notif.actionRoute!.isNotEmpty && context.mounted) {
            Navigator.pop(context);
            context.push(notif.actionRoute!);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // INDIVIDUAL UNREAD INDICATOR DOT
              if (!notif.read)
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF06B6D4), // Cyan unread dot
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x6606B6D4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(width: 4),

              // Category Icon
              CircleAvatar(
                radius: 18,
                backgroundColor: iconColor.withValues(alpha: 0.15),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: !notif.read ? FontWeight.bold : FontWeight.w600,
                              color: !notif.read ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          dateFormat.format(notif.createdAt),
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Mark as read icon button
              if (!notif.read)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  tooltip: 'Mark as read',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    AppNotificationService.markAsRead(
                      libraryId: widget.libraryId,
                      notificationId: notif.id,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildSystemAlertTile({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
    bool isUnread = true,
    VoidCallback? onMarkRead,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread
            ? badgeColor.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? badgeColor.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // UNREAD DOT (Only if unread)
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              )
            else
              const SizedBox(width: 4),
            CircleAvatar(
              backgroundColor: isUnread
                  ? iconColor.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                icon,
                color: isUnread ? iconColor : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ],
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
            color: isUnread ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          body,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isUnread ? badgeColor : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: isUnread ? Colors.white : theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isUnread && onMarkRead != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                tooltip: 'Mark as read',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onMarkRead,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color) _getTypeVisuals(String type) {
    return switch (type) {
      'payment' => (Icons.payment_rounded, const Color(0xFF10B981)),
      'admission' => (Icons.school_rounded, const Color(0xFF3B82F6)),
      'seat' => (Icons.event_seat_rounded, const Color(0xFF8B5CF6)),
      'expiry' => (Icons.alarm_rounded, const Color(0xFFF59E0B)),
      'announcement' => (Icons.campaign_rounded, const Color(0xFF6366F1)),
      _ => (Icons.notifications_rounded, const Color(0xFF64748B)),
    };
  }
}
