import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'package:study_library/models/announcement_model.dart';
import 'package:study_library/core/security/audit_logger.dart';

/// Stream provider for announcements of the current library, sorted by createdAt descending.
final announcementsStreamProvider =
    StreamProvider.autoDispose<List<AnnouncementModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('announcements')
      .snapshots()
      .map((snapshot) {
    final items = snapshot.docs.map((doc) {
      return AnnouncementModel.fromJson({
        ...doc.data(),
        'id': doc.id,
      });
    }).toList();

    // Sort in Dart by createdAt descending (newest first)
    items.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return items;
  });
});

class AnnouncementListScreen extends ConsumerWidget {
  const AnnouncementListScreen({super.key});

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, yyyy • h:mm a').format(date);
  }

  Widget _buildTypeBadge(BuildContext context, AnnouncementType type) {
    final theme = Theme.of(context);
    final isBroadcast = type == AnnouncementType.broadcast;
    final bgColor = isBroadcast
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.tertiaryContainer;
    final textColor = isBroadcast
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBroadcast ? Icons.campaign : Icons.view_carousel,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            isBroadcast ? 'Broadcast' : 'Banner',
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryId = ref.watch(currentLibraryIdProvider);
    final theme = Theme.of(context);

    if (libraryId == null || libraryId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Announcements')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final announcementsAsync = ref.watch(announcementsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.campaign_outlined,
              title: 'No announcements yet',
              message:
                  'Keep your students informed by posting library announcements and banners.',
              actionLabel: 'Add Announcement',
              onAction: () => _showAnnouncementDialog(
                context,
                libraryId: libraryId,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(announcementsStreamProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                final announcement = announcements[index];

              return Dismissible(
                key: ValueKey(announcement.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Delete Announcement'),
                      content: Text(
                        'Are you sure you want to delete "${announcement.title}"? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          onPressed: () => Navigator.of(dialogCtx).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('announcements')
                          .doc(announcement.id)
                          .delete();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Announcement deleted')),
                        );
                      }
                      return true;
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete announcement: $e'),
                          ),
                        );
                      }
                      return false;
                    }
                  }
                  return false;
                },
                child: Card(
                  elevation: 0,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showAnnouncementDialog(
                      context,
                      libraryId: libraryId,
                      announcement: announcement,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildTypeBadge(context, announcement.type),
                              const Spacer(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    announcement.isActive
                                        ? 'Active'
                                        : 'Inactive',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: announcement.isActive
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Switch.adaptive(
                                    value: announcement.isActive,
                                    onChanged: (val) async {
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('libraries')
                                            .doc(libraryId)
                                            .collection('announcements')
                                            .doc(announcement.id)
                                            .update({'isActive': val});
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to update status: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            announcement.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            announcement.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (announcement.createdAt != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_outlined,
                                  size: 14,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(announcement.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load announcements: $error',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAnnouncementDialog(
          context,
          libraryId: libraryId,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Function to show add/edit announcement dialog.
Future<void> _showAnnouncementDialog(
  BuildContext context, {
  required String libraryId,
  AnnouncementModel? announcement,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _AnnouncementFormDialog(
      libraryId: libraryId,
      announcement: announcement,
    ),
  );
}

/// Public alias for external callers if needed.
Future<void> showAnnouncementDialog(
  BuildContext context, {
  required String libraryId,
  AnnouncementModel? announcement,
}) =>
    _showAnnouncementDialog(
      context,
      libraryId: libraryId,
      announcement: announcement,
    );

class _AnnouncementFormDialog extends StatefulWidget {
  final String libraryId;
  final AnnouncementModel? announcement;

  const _AnnouncementFormDialog({
    required this.libraryId,
    this.announcement,
  });

  @override
  State<_AnnouncementFormDialog> createState() =>
      _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState extends State<_AnnouncementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  late AnnouncementType _selectedType;
  late bool _isActive;
  bool _isSaving = false;

  bool get _isEditing => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.announcement?.title ?? '');
    _messageController =
        TextEditingController(text: widget.announcement?.message ?? '');
    _selectedType = widget.announcement?.type ?? AnnouncementType.broadcast;
    _isActive = widget.announcement?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .collection('announcements');

      if (_isEditing) {
        final data = {
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
          'type': _selectedType.name,
          'isActive': _isActive,
        };
        await ref.doc(widget.announcement!.id).update(data);
      } else {
        final docRef = ref.doc();
        final newAnnouncement = AnnouncementModel(
          id: docRef.id,
          libraryId: widget.libraryId,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          type: _selectedType,
          isActive: _isActive,
          createdAt: DateTime.now(),
        );
        await docRef.set(newAnnouncement.toJson());

        AuditLogger().log(
          action: AuditAction.created,
          entityType: AuditEntity.announcement,
          libraryId: widget.libraryId,
          entityId: docRef.id,
          details: {'title': _titleController.text.trim(), 'type': _selectedType.name},
        ).ignore();

        // Notify all students via Firestore trigger doc (Cloud Function picks this up)
        // Also write to admin_notifications for in-app display
        // Write to push_queue — processed by Cloud Function (or manually via FCM REST API).
        // Students are subscribed to 'lib-{libraryId}' topic on login; upgrading to Blaze
        // plan + adding a Cloud Function will make push go live with zero code change.
        if (_isActive) {
          try {
            await FirebaseFirestore.instance
                .collection('libraries')
                .doc(widget.libraryId)
                .collection('push_queue')
                .add({
              'title': _titleController.text.trim(),
              'body': _messageController.text.trim(),
              'type': 'announcement',
              'topic': 'lib-${widget.libraryId}', // FCM topic to send to
              'libraryId': widget.libraryId,
              'createdAt': FieldValue.serverTimestamp(),
              'processed': false,
            });
          } catch (_) {}
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Announcement updated' : 'Announcement created',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save announcement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Announcement' : 'New Announcement'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g., Extended Library Hours',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Message *',
                    hintText: 'Enter announcement details...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a message';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AnnouncementType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AnnouncementType.broadcast,
                      child: Text('Broadcast'),
                    ),
                    DropdownMenuItem(
                      value: AnnouncementType.banner,
                      child: Text('Banner'),
                    ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedType = val);
                          }
                        },
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: Text(
                    _isActive
                        ? 'Visible to students'
                        : 'Hidden from students',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: _isActive,
                  onChanged: _isSaving
                      ? null
                      : (val) => setState(() => _isActive = val),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
