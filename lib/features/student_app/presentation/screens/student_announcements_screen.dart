import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'package:study_library/features/announcements/presentation/screens/announcement_list_screen.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/models/announcement_model.dart';

class StudentAnnouncementsScreen extends ConsumerStatefulWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  ConsumerState<StudentAnnouncementsScreen> createState() =>
      _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState
    extends ConsumerState<StudentAnnouncementsScreen> {
  String _selectedFilter = 'all'; // 'all', 'urgent', 'holiday', 'maintenance', 'general'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _markAsRead(AnnouncementModel announcement, String studentId, String libraryId) {
    if (studentId.isNotEmpty &&
        libraryId.isNotEmpty &&
        !announcement.readBy.contains(studentId)) {
      FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('announcements')
          .doc(announcement.id)
          .update({
        'readBy': FieldValue.arrayUnion([studentId]),
      }).ignore();
    }
  }

  void _showNoticeDetailDialog(
      BuildContext context, AnnouncementModel announcement, String studentId, String libraryId) {
    _markAsRead(announcement, studentId, libraryId);
    final theme = Theme.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: announcement.priority.containerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(announcement.priority.icon,
                  color: announcement.priority.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: announcement.priority.containerColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      announcement.priority.label.toUpperCase(),
                      style: TextStyle(
                        color: announcement.priority.onContainerColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    announcement.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (announcement.createdAt != null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEE, MMM d, yyyy • h:mm a').format(announcement.createdAt!),
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
              ],
              SelectableText(
                announcement.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              if (announcement.expiresAt != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.outline),
                      const SizedBox(width: 6),
                      Text(
                        'Active until ${DateFormat("MMM d, yyyy • h:mm a").format(announcement.expiresAt!)}',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final studentAsync = ref.watch(currentStudentProvider);
    final student = studentAsync.value;
    final studentId = student?.id ?? '';
    final announcementsAsync = ref.watch(announcementsStreamProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.studentHome);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.studentHome),
          ),
          title: const Text('Notice Board & Circulars'),
          centerTitle: true,
        ),
        body: announcementsAsync.when(
          data: (allAnnouncements) {
            // Filter active notices and non-expired
            final notices = allAnnouncements.where((a) {
              if (!a.isActive) return false;
              if (a.isExpired) return false;

              // Filter by category
              if (_selectedFilter != 'all' && a.priority.name != _selectedFilter) {
                return false;
              }

              // Filter by search query
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                return a.title.toLowerCase().contains(q) ||
                    a.message.toLowerCase().contains(q);
              }
              return true;
            }).toList();

            return Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search notices & updates...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All Notices', Icons.dashboard_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('urgent', 'Urgent Alerts', Icons.warning_amber_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      _buildFilterChip('holiday', 'Holidays', Icons.celebration_rounded, color: Colors.teal),
                      const SizedBox(width: 8),
                      _buildFilterChip('maintenance', 'Maintenance', Icons.build_circle_outlined, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      _buildFilterChip('general', 'General', Icons.campaign_rounded, color: Colors.blue),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Notices Feed
                Expanded(
                  child: notices.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.campaign_outlined,
                          title: _searchQuery.isNotEmpty
                              ? 'No matching notices found'
                              : 'No active circulars',
                          message: _searchQuery.isNotEmpty
                              ? 'Try searching with different keywords.'
                              : 'Library administration has not posted any active notices under this category.',
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(announcementsStreamProvider);
                            await Future.delayed(const Duration(milliseconds: 500));
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: notices.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final notice = notices[index];
                              final isRead = studentId.isNotEmpty && notice.isReadBy(studentId);

                              // Automatically mark as read when displayed
                              if (studentId.isNotEmpty && !isRead) {
                                _markAsRead(notice, studentId, libraryId);
                              }

                              return InkWell(
                                onTap: () => _showNoticeDetailDialog(
                                  context,
                                  notice,
                                  studentId,
                                  libraryId,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: notice.priority == AnnouncementPriority.urgent
                                          ? Colors.red.withValues(alpha: 0.4)
                                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                                      width: notice.priority == AnnouncementPriority.urgent ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: notice.priority.containerColor,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  notice.priority.icon,
                                                  size: 13,
                                                  color: notice.priority.onContainerColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  notice.priority.label.toUpperCase(),
                                                  style: TextStyle(
                                                    color: notice.priority.onContainerColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          if (!isRead)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'NEW',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          else
                                            Row(
                                              children: [
                                                Icon(Icons.done_all_rounded, size: 14, color: theme.colorScheme.primary),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'Read',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme.colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        notice.title,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        notice.message,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          height: 1.4,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          if (notice.createdAt != null) ...[
                                            Icon(Icons.schedule, size: 12, color: theme.colorScheme.outline),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('MMM d, yyyy • h:mm a').format(notice.createdAt!),
                                              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                            ),
                                          ],
                                          const Spacer(),
                                          Text(
                                            'View Details →',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading notices: $e')),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon, {Color? color}) {
    final isSelected = _selectedFilter == value;
    final theme = Theme.of(context);

    return FilterChip(
      selected: isSelected,
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected
            ? theme.colorScheme.onPrimary
            : (color ?? theme.colorScheme.onSurfaceVariant),
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.onPrimary : null,
      ),
      selectedColor: color ?? theme.colorScheme.primary,
      checkmarkColor: theme.colorScheme.onPrimary,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = value);
      },
    );
  }
}
