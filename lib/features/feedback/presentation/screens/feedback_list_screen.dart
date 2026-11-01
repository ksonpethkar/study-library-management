import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/feedback_model.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';

/// Stream provider for library student feedback, sorted in Dart (newest first).
final feedbackStreamProvider = StreamProvider.autoDispose<List<FeedbackModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('feedback')
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs.map((doc) {
      final data = doc.data();
      return FeedbackModel.fromJson({...data, 'id': doc.id});
    }).toList();

    // Sort in Dart by createdAt descending (no composite index needed)
    list.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return list;
  });
});

/// Screen to display and manage student feedback for the current library.
class FeedbackListScreen extends ConsumerWidget {
  const FeedbackListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryId = ref.watch(currentLibraryIdProvider);
    final feedbackAsync = ref.watch(feedbackStreamProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminHome),
        ),
        title: const Text('Student Feedback & Suggestions'),
      ),
      body: feedbackAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load feedback',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.refresh(feedbackStreamProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (feedbackList) {
          if (feedbackList.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(feedbackStreamProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.rate_review_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No feedback yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Feedback and suggestions submitted by students will appear here for you to review and answer.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(feedbackStreamProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: feedbackList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = feedbackList[index];
                return _FeedbackCard(
                  feedback: item,
                  onReply: () => _showReplyDialog(context, libraryId, item),
                  onDelete: () => _confirmDelete(context, libraryId, item.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showReplyDialog(
    BuildContext context,
    String? libraryId,
    FeedbackModel feedback,
  ) async {
    if (libraryId == null || libraryId.isEmpty) return;

    final controller = TextEditingController(text: feedback.adminReply ?? '');
    final formKey = GlobalKey<FormState>();
    final studentDisplayName = feedback.studentName ?? 'Student';

    final cannedResponses = [
      {
        'label': '❄️ AC / Cooling',
        'text': 'Dear $studentDisplayName, thank you for alerting us! Our team has adjusted the AC temperature and airflow in your section to ensure a comfortable study environment. Please inform the reception desk if further adjustment is needed.',
      },
      {
        'label': '📶 Wi-Fi Router',
        'text': 'Dear $studentDisplayName, the high-speed fiber routers and access points have been refreshed and bandwidth distribution normalized. Kindly reconnect your device. If you still encounter latency, please visit the desk.',
      },
      {
        'label': '🤫 Silence Enforced',
        'text': 'Dear $studentDisplayName, we strictly prioritize a pin-drop silent learning environment. Our floor supervisor has taken immediate action and reminded students in that zone. Thank you for helping us maintain decorum.',
      },
      {
        'label': '🧹 Cleanliness',
        'text': 'Dear $studentDisplayName, our housekeeping team has completed a thorough cleaning and sanitization of the requested area. Cleanliness is our top priority. Thank you for bringing this to our attention!',
      },
      {
        'label': '💡 Desk / Light',
        'text': 'Dear $studentDisplayName, the desk light and power socket at your cubicle have been inspected and repaired by our maintenance staff. Everything is now fully operational for your study sessions.',
      },
      {
        'label': '🙏 Suggestion',
        'text': 'Dear $studentDisplayName, thank you so much for your valuable suggestion! We deeply appreciate your input and are actively working on it to make our study centre even better.',
      },
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.reply_rounded, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Reply to $studentDisplayName',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quote student message
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '"${feedback.message}"',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('Quick Pre-Templated Responses:', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cannedResponses.map((preset) {
                          return ActionChip(
                            label: Text(preset['label']!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              setSheetState(() {
                                controller.text = preset['text']!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: controller,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Official Response to Student',
                          hintText: 'Type your official reply here...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a reply message'
                            : null,
                      ),
                      const SizedBox(height: 18),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.send_rounded, size: 18),
                                  label: const Text('In-App Reply'),
                                  onPressed: () async {
                                    if (!formKey.currentState!.validate()) return;
                                    final replyText = controller.text.trim();

                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('libraries')
                                          .doc(libraryId)
                                          .collection('feedback')
                                          .doc(feedback.id)
                                          .update({
                                        'adminReply': replyText,
                                        'repliedAt': FieldValue.serverTimestamp(),
                                        'status': 'resolved',
                                      });

                                      if (feedback.studentId.isNotEmpty) {
                                        AppNotificationService.sendNotification(
                                          libraryId: libraryId,
                                          title: 'Library Replied to Your Feedback 💬',
                                          body: replyText,
                                          type: 'feedback_reply',
                                          targetRole: 'student',
                                          targetUserId: feedback.studentId,
                                          actionRoute: '/student/feedback',
                                        ).ignore();
                                      }

                                      if (context.mounted) {
                                        Navigator.pop(dialogCtx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Official reply sent to student!'),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to send reply: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text('Send Reply via WhatsApp'),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final replyText = controller.text.trim();

                              try {
                                // 1. Save in Firestore & mark resolved
                                await FirebaseFirestore.instance
                                    .collection('libraries')
                                    .doc(libraryId)
                                    .collection('feedback')
                                    .doc(feedback.id)
                                    .update({
                                  'adminReply': replyText,
                                  'repliedAt': FieldValue.serverTimestamp(),
                                  'status': 'resolved',
                                });

                                // 2. Send In-App notification
                                if (feedback.studentId.isNotEmpty) {
                                  AppNotificationService.sendNotification(
                                    libraryId: libraryId,
                                    title: 'Library Replied to Your Feedback 💬',
                                    body: replyText,
                                    type: 'feedback_reply',
                                    targetRole: 'student',
                                    targetUserId: feedback.studentId,
                                    actionRoute: '/student/feedback',
                                  ).ignore();
                                }

                                // 3. Resolve student phone number
                                String phone = feedback.studentPhone ?? '';
                                if (phone.isEmpty && feedback.studentId.isNotEmpty) {
                                  final sDoc = await FirebaseFirestore.instance
                                      .collection('libraries')
                                      .doc(libraryId)
                                      .collection('students')
                                      .doc(feedback.studentId)
                                      .get();
                                  phone = sDoc.data()?['phone'] as String? ?? '';
                                }

                                // 4. Fetch library name
                                final libDoc = await FirebaseFirestore.instance
                                    .collection('libraries')
                                    .doc(libraryId)
                                    .get();
                                final libName = (libDoc.data()?['name'] as String?) ?? 'Study Library';

                                if (context.mounted) {
                                  Navigator.pop(dialogCtx);
                                }

                                if (phone.isNotEmpty) {
                                  final waMessage = '💬 *Response to Your Feedback — $libName*\n\n'
                                      'Dear *$studentDisplayName*,\n'
                                      'Regarding your message:\n'
                                      '*"${feedback.message}"*\n\n'
                                      '$replyText\n\n'
                                      'Warm regards,\n'
                                      '*$libName Admin Desk*';

                                  if (context.mounted) { await WhatsAppService().sendMessage(phone, waMessage, context: context, title: 'Feedback Reply Preview'); }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Feedback saved, but student phone was not found for WhatsApp.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to process reply: $e'),
                                      backgroundColor: Colors.red,
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, String? libraryId, String feedbackId) async {
    if (libraryId == null || libraryId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Feedback'),
        content: const Text(
          'Are you sure you want to delete this feedback? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('feedback')
            .doc(feedbackId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Feedback deleted successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete feedback: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackModel feedback;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const _FeedbackCard({
    required this.feedback,
    required this.onReply,
    required this.onDelete,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recently';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = (feedback.studentName != null && feedback.studentName!.trim().isNotEmpty)
        ? feedback.studentName!.trim()
        : (feedback.studentId.isNotEmpty ? 'Student (${feedback.studentId})' : 'Anonymous Student');

    final hasReply = feedback.adminReply != null && feedback.adminReply!.trim().isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasReply
              ? Colors.green.shade300
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: hasReply ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    _getInitials(displayName),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (feedback.feedbackType == 'issue' || (feedback.rating != null && feedback.rating! <= 2)) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('ISSUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                            ),
                          ] else if (feedback.feedbackType == 'suggestion' || (feedback.category != null && feedback.category!.contains('Suggestion'))) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('SUGGESTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('FEEDBACK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                            ),
                          ],
                          Text(
                            _formatDate(feedback.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (feedback.category != null && feedback.category!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('•', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                            const SizedBox(width: 6),
                            Text(
                              feedback.category!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Delete Feedback',
                  onPressed: onDelete,
                ),
              ],
            ),
            if (feedback.rating != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  ...List.generate(5, (index) {
                    final isFilled = index < (feedback.rating ?? 0);
                    return Icon(
                      isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 20,
                      color: isFilled ? Colors.amber.shade700 : theme.colorScheme.outlineVariant,
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    '${feedback.rating}/5',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              feedback.message.isNotEmpty ? feedback.message : 'No message provided.',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
            ),
            if (hasReply) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          size: 16,
                          color: Colors.green.shade800,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Your Official Reply',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.green.shade900,
                          ),
                        ),
                        if (feedback.repliedAt != null) ...[
                          const Spacer(),
                          Text(
                            _formatDate(feedback.repliedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      feedback.adminReply!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade900,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onReply,
                icon: Icon(hasReply ? Icons.edit_rounded : Icons.reply_rounded, size: 16),
                label: Text(hasReply ? 'Edit Reply' : 'Reply to Student'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
