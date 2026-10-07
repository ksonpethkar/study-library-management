import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/badge_service.dart';

/// Data representation of a student request from raw Firestore data.
class StudentRequestItem {
  final String id;
  final String type;
  final String message;
  final String studentName;
  final String studentId;
  final String status;
  final DateTime? createdAt;
  final String? rejectionReason;

  const StudentRequestItem({
    required this.id,
    required this.type,
    required this.message,
    required this.studentName,
    required this.studentId,
    required this.status,
    this.createdAt,
    this.rejectionReason,
  });

  factory StudentRequestItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    // Support both direct fields and nested studentData fallback
    String studentName = 'Student';
    if (data['studentName'] is String && (data['studentName'] as String).trim().isNotEmpty) {
      studentName = (data['studentName'] as String).trim();
    } else if (data['studentData'] is Map &&
        (data['studentData'] as Map)['name'] != null &&
        (data['studentData'] as Map)['name'].toString().trim().isNotEmpty) {
      studentName = (data['studentData'] as Map)['name'].toString().trim();
    }

    return StudentRequestItem(
      id: doc.id,
      type: data['type'] as String? ?? 'General Request',
      message: data['message'] as String? ?? '',
      studentName: studentName,
      studentId: data['studentId'] as String? ?? '',
      status: (data['status'] as String? ?? 'pending').trim().toLowerCase(),
      createdAt: _parseDate(data['createdAt']),
      rejectionReason: (data['rejectionReason'] ?? data['rejectReason']) as String?,
    );
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
    if (date is String) return DateTime.tryParse(date);
    return null;
  }
}

/// Stream provider for student requests, sorted in Dart (newest first).
final requestsStreamProvider = StreamProvider.autoDispose<List<StudentRequestItem>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('requests')
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs
        .map((doc) => StudentRequestItem.fromFirestore(doc))
        .toList();

    // Sort in Dart by createdAt descending (no composite index needed)
    list.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return list;
  });
});

/// Screen to view and manage student requests (seat changes, plan changes, etc.).
class RequestListScreen extends ConsumerWidget {
  const RequestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Clear badge when admin opens requests screen (they're seeing the requests)
    BadgeService.clearBadge();

    final libraryId = ref.watch(currentLibraryIdProvider);
    final requestsAsync = ref.watch(requestsStreamProvider);

    return requestsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Student Requests')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Student Requests')),
        body: Center(
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
                  'Failed to load requests',
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
                  onPressed: () => ref.refresh(requestsStreamProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (requests) {
        final pending = requests.where((r) => r.status == 'pending').toList();
        final approved = requests.where((r) => r.status == 'approved').toList();
        final rejected = requests.where((r) => r.status == 'rejected').toList();

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Student Requests'),
              bottom: TabBar(
                isScrollable: false,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pending'),
                        if (pending.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${pending.length}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onError,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Approved'),
                  const Tab(text: 'Rejected'),
                  const Tab(text: 'All'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildRequestList(
                  context,
                  ref,
                  libraryId,
                  pending,
                  emptyTitle: 'All caught up! 🎉',
                  emptySubtitle: 'There are no pending student requests at this moment.',
                  emptyIcon: Icons.check_circle_outline_rounded,
                ),
                _buildRequestList(
                  context,
                  ref,
                  libraryId,
                  approved,
                  emptyTitle: 'No approved requests',
                  emptySubtitle: 'Approved requests will appear here.',
                  emptyIcon: Icons.task_alt_rounded,
                ),
                _buildRequestList(
                  context,
                  ref,
                  libraryId,
                  rejected,
                  emptyTitle: 'No rejected requests',
                  emptySubtitle: 'Rejected requests will appear here.',
                  emptyIcon: Icons.cancel_outlined,
                ),
                _buildRequestList(
                  context,
                  ref,
                  libraryId,
                  requests,
                  emptyTitle: 'No requests yet',
                  emptySubtitle: 'Student requests for seat or plan changes will appear here.',
                  emptyIcon: Icons.inbox_outlined,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestList(
    BuildContext context,
    WidgetRef ref,
    String? libraryId,
    List<StudentRequestItem> items, {
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
  }) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(requestsStreamProvider);
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
                      emptyIcon,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    emptyTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptySubtitle,
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
        ref.invalidate(requestsStreamProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _RequestCard(
            request: item,
            onApprove: () => _updateRequestStatus(context, libraryId, item.id, 'approved'),
            onReject: () => _promptReject(context, libraryId, item),
            onDelete: () => _confirmDelete(context, libraryId, item.id),
          );
        },
      ),
    );
  }

  Future<void> _updateRequestStatus(
    BuildContext context,
    String? libraryId,
    String requestId,
    String newStatus, {
    String? reason,
  }) async {
    if (libraryId == null || libraryId.isEmpty) return;

    if (newStatus == 'approved') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve Request'),
          content: const Text('Are you sure you want to approve this request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    if (!context.mounted) return;

    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'processedAt': FieldValue.serverTimestamp(),
      };
      if (reason != null && reason.trim().isNotEmpty) {
        updateData['rejectionReason'] = reason.trim();
      }

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(requestId)
          .update(updateData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved'
                  ? 'Request approved successfully'
                  : 'Request rejected',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update request: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _promptReject(
    BuildContext context,
    String? libraryId,
    StudentRequestItem request,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject this request from ${request.studentName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (optional)',
                hintText: 'e.g. Seat unavailable, invalid plan...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _updateRequestStatus(
        context,
        libraryId,
        request.id,
        'rejected',
        reason: reasonController.text,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String? libraryId,
    String requestId,
  ) async {
    if (libraryId == null || libraryId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'Are you sure you want to delete this request record? This action cannot be undone.',
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
            .collection('requests')
            .doc(requestId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request deleted successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete request: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

class _RequestCard extends StatelessWidget {
  final StudentRequestItem request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recently';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  String _formatType(String type) {
    switch (type.toLowerCase()) {
      case 'seatchange':
        return 'Seat Change';
      case 'newregistration':
        return 'New Registration';
      case 'renewal':
        return 'Plan Renewal';
      default:
        if (type.isEmpty) return 'General';
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'seatchange':
        return Icons.event_seat_rounded;
      case 'renewal':
        return Icons.autorenew_rounded;
      case 'newregistration':
        return Icons.person_add_rounded;
      default:
        return Icons.assignment_outlined;
    }
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'approved':
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green.shade800;
        icon = Icons.check_circle_rounded;
        label = 'Approved';
        break;
      case 'rejected':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade800;
        icon = Icons.cancel_rounded;
        label = 'Rejected';
        break;
      case 'pending':
      default:
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade900;
        icon = Icons.schedule_rounded;
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = request.status == 'pending';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type chip, Status chip, and Overflow delete menu
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTypeIcon(request.type),
                        size: 15,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatType(request.type),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(context, request.status),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Student Info & Date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.person_rounded, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.studentName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (request.studentId.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          'ID: ${request.studentId}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  _formatDate(request.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            // Message Body
            if (request.message.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  request.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                  ),
                ),
              ),
            ],

            // Rejection reason note if rejected
            if (request.status == 'rejected' &&
                request.rejectionReason != null &&
                request.rejectionReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${request.rejectionReason}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons for Pending Requests
            if (isPending) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
