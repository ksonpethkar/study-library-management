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
import 'package:study_library/features/holidays/presentation/screens/holiday_calendar_screen.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/models/announcement_model.dart';
import 'package:study_library/core/utils/error_formatter.dart';

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
    final rawLibraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final studentAsync = ref.watch(currentStudentProvider);
    final student = studentAsync.value;
    final studentId = student?.id ?? '';
    final effectiveLibId = rawLibraryId.isNotEmpty
        ? rawLibraryId
        : CurrentLibraryNotifier.defaultLibraryId;
    final libraryId = effectiveLibId;

    if (rawLibraryId.isEmpty && effectiveLibId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentLibraryIdProvider.notifier).set(effectiveLibId);
      });
    }

    final announcementsAsync = ref.watch(announcementsStreamProvider);
    final holidaysAsync = ref.watch(holidaysStreamProvider);
    final holidays = holidaysAsync.value ?? [];

    // Synthesize holiday circulars from official library calendar
    final holidayCirculars = holidays.map((h) {
      final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(h.date);
      final extText = h.membershipExtended
          ? '\n\n✓ Active student memberships have been automatically extended by +${h.extensionDays > 0 ? h.extensionDays : 1} day.'
          : '\n\nPlease plan your study schedule accordingly.';

      return AnnouncementModel(
        id: 'holiday_${h.id}',
        libraryId: h.libraryId,
        title: 'Holiday Closure: ${h.reason}',
        message: '${h.reason} ($dateStr) — The library will be ${h.isFullDay ? "closed for the full day" : "partially open"}.$extText',
        type: AnnouncementType.broadcast,
        priority: AnnouncementPriority.holiday,
        isActive: true,
        createdAt: h.createdAt,
        expiresAt: DateTime(h.date.year, h.date.month, h.date.day, 23, 59, 59),
      );
    }).toList();

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
            // Merge announcements and library holidays (prevent duplicate holiday announcements)
            final existingIds = allAnnouncements.map((a) => a.id).toSet();
            final mergedAnnouncements = [
              ...allAnnouncements,
              ...holidayCirculars.where((h) => !existingIds.contains(h.id)),
            ];

            // Sort newest / upcoming first
            mergedAnnouncements.sort((a, b) {
              final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

            // Filter active notices and non-expired
            final notices = mergedAnnouncements.where((a) {
              if (!a.isActive) return false;

              // For holidays, keep future dates and recent holidays (last 14 days)
              if (a.priority == AnnouncementPriority.holiday) {
                if (a.expiresAt != null && a.expiresAt!.isBefore(DateTime.now().subtract(const Duration(days: 14)))) {
                  return false;
                }
              } else {
                if (a.isExpired) return false;
              }

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
                      ? (_selectedFilter == 'holiday' && _searchQuery.isEmpty
                          ? _buildHolidayOperationalCard(context, theme)
                          : EmptyStateWidget(
                              icon: _selectedFilter == 'holiday'
                                  ? Icons.celebration_outlined
                                  : Icons.campaign_outlined,
                              title: _searchQuery.isNotEmpty
                                  ? 'No matching circulars found'
                                  : (_selectedFilter == 'holiday'
                                      ? 'No library closures scheduled'
                                      : 'No active circulars'),
                              message: _searchQuery.isNotEmpty
                                  ? 'Try searching with different keywords.'
                                  : (_selectedFilter == 'holiday'
                                      ? 'The study library is fully open on all standard calendar days. Any upcoming festival closures or maintenance breaks will be published here.'
                                      : 'Library administration has not posted any active notices under this category.'),
                              actionLabel: _searchQuery.isNotEmpty
                                  ? 'Clear Search'
                                  : (_selectedFilter != 'all' ? 'View All Circulars' : null),
                              onAction: _searchQuery.isNotEmpty
                                  ? () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    }
                                  : (_selectedFilter != 'all'
                                      ? () => setState(() => _selectedFilter = 'all')
                                      : null),
                            ))
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
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                AppErrorFormatter.toUserFriendly(e, actionContext: 'announcement'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
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

  Widget _buildHolidayOperationalCard(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              // Operational Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                    SizedBox(width: 6),
                    Text(
                      'FULLY OPEN · 7 DAYS A WEEK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Operational Detail Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.event_available_rounded, color: Colors.teal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Scheduled Closures',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'All reading zones, silent desks, and amenities are running normally.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Slot Highlights
                    _buildTimingRow(Icons.wb_sunny_outlined, 'Full-Day & Flexible Slots', 'Morning (6 AM - 2 PM) • Evening (2 PM - 10 PM) • 24/7 Access Active', theme),
                    const SizedBox(height: 10),
                    _buildTimingRow(Icons.wifi_rounded, 'Active Amenities', 'High-Speed Fiber Wi-Fi, Air Conditioning, Personal Power Sockets', theme),
                    const SizedBox(height: 10),
                    _buildTimingRow(Icons.verified_user_outlined, 'Holiday Compensation', 'Any gazetted festival closures automatically extend your membership by +1 day at zero cost.', theme),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _selectedFilter = 'all'),
                    icon: const Icon(Icons.dashboard_outlined, size: 16),
                    label: const Text('View All Circulars'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showCalendarGuidelinesDialog(context, theme),
                    icon: const Icon(Icons.info_outline_rounded, size: 16),
                    label: const Text('Holiday Policy & Rules'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimingRow(IconData icon, String title, String subtitle, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCalendarGuidelinesDialog(BuildContext context, ThemeData theme) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.policy_rounded, color: Colors.teal),
            SizedBox(width: 10),
            Text('Holiday & Closure Policy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Standard Operating Schedule',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 3),
              Text(
                'The study centre remains open all 365 days of the year, including Sundays and regular public holidays, to ensure uninterrupted preparation for competitive exams.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '2. Gazetted Festival Closures',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 3),
              Text(
                'On major festival days (e.g. Diwali, Holi) or rare emergency deep-cleaning days, administration notifies students at least 48 hours in advance via this Notice Board and WhatsApp.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '3. Automatic Validity Extension Guarantee',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 3),
              Text(
                'Whenever a full-day closure is declared by the administration, all active student subscriptions are automatically credited with a compensatory +1 day extension in the cloud ledger.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
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
}
