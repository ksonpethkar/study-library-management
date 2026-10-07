import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/holiday_model.dart';

/// Stream of holidays for the current library, sorted by date in Dart.
final holidaysStreamProvider = StreamProvider.autoDispose<List<HolidayModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('holidays')
      .snapshots()
      .map((snapshot) {
    final holidays = snapshot.docs.map((doc) {
      return HolidayModel.fromJson({
        ...doc.data(),
        'id': doc.id,
      });
    }).toList();

    // Sort by date ascending in Dart (composite index avoided)
    holidays.sort((a, b) => a.date.compareTo(b.date));
    return holidays;
  });
});

/// Screen to view, add, and manage library holidays.
class HolidayCalendarScreen extends ConsumerStatefulWidget {
  const HolidayCalendarScreen({super.key});

  @override
  ConsumerState<HolidayCalendarScreen> createState() => _HolidayCalendarScreenState();
}

typedef HolidaysScreen = HolidayCalendarScreen;

class _HolidayCalendarScreenState extends ConsumerState<HolidayCalendarScreen> {
  String _selectedFilter = 'All';

  Future<bool> _confirmDelete(BuildContext context, HolidayModel holiday) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text(
          'Are you sure you want to delete "${holiday.reason}" on ${DateFormat('EEE, MMM d, yyyy').format(holiday.date)}?',
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

    return result ?? false;
  }

  Future<void> _deleteHoliday(String holidayId, String reason) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('holidays');
      await ref.doc(holidayId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Holiday "$reason" deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete holiday: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showAddHolidayDialog(BuildContext context, String? libraryId) async {
    if (libraryId == null || libraryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No library selected. Cannot add holiday.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddHolidayDialog(libraryId: libraryId),
    );

    if (!context.mounted) return;
    if (added == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Holiday added successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _getRelativeDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff <= 7) return 'In $diff days';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider);
    final holidaysAsync = ref.watch(holidaysStreamProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holidays & Closures'),
      ),
      body: libraryId == null || libraryId.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_outlined, size: 64, color: colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No Library Selected',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please select a library to manage holidays.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : holidaysAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load holidays',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(holidaysStreamProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (holidays) {
                if (holidays.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(holidaysStreamProvider);
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 72,
                            color: colorScheme.outline.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Holidays Scheduled',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add holidays and closures to keep your staff and students informed.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _showAddHolidayDialog(context, libraryId),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Holiday'),
                          ),
                        ],
                        ),
                      ],
                    ),
                  );
                }

                // Group & sort: Upcoming first, past grouped separately
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                final upcomingHolidays = <HolidayModel>[];
                final pastHolidays = <HolidayModel>[];

                for (final h in holidays) {
                  final hDate = DateTime(h.date.year, h.date.month, h.date.day);
                  if (hDate.isBefore(today)) {
                    pastHolidays.add(h);
                  } else {
                    upcomingHolidays.add(h);
                  }
                }

                // Upcoming sorted earliest to latest
                upcomingHolidays.sort((a, b) => a.date.compareTo(b.date));
                // Past sorted latest to earliest
                pastHolidays.sort((a, b) => b.date.compareTo(a.date));

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment<String>(
                            value: 'All',
                            label: Text('All (${holidays.length})'),
                            icon: const Icon(Icons.calendar_view_day),
                          ),
                          ButtonSegment<String>(
                            value: 'Upcoming',
                            label: Text('Upcoming (${upcomingHolidays.length})'),
                            icon: const Icon(Icons.upcoming),
                          ),
                          ButtonSegment<String>(
                            value: 'Past',
                            label: Text('Past (${pastHolidays.length})'),
                            icon: const Icon(Icons.history),
                          ),
                        ],
                        selected: {_selectedFilter},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _selectedFilter = newSelection.first;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(holidaysStreamProvider);
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 80),
                          children: [
                          if (_selectedFilter == 'All') ...[
                            if (upcomingHolidays.isNotEmpty) ...[
                              _buildSectionHeader(
                                context,
                                'Upcoming Holidays',
                                upcomingHolidays.length,
                                Icons.upcoming,
                              ),
                              ...upcomingHolidays.map((h) => _buildHolidayTile(context, h, isUpcoming: true)),
                            ],
                            if (pastHolidays.isNotEmpty) ...[
                              _buildSectionHeader(
                                context,
                                'Past Holidays',
                                pastHolidays.length,
                                Icons.history,
                              ),
                              ...pastHolidays.map((h) => _buildHolidayTile(context, h, isUpcoming: false)),
                            ],
                          ] else if (_selectedFilter == 'Upcoming') ...[
                            if (upcomingHolidays.isEmpty)
                              _buildEmptyFilterState(context, 'No upcoming holidays scheduled.')
                            else
                              ...upcomingHolidays.map((h) => _buildHolidayTile(context, h, isUpcoming: true)),
                          ] else if (_selectedFilter == 'Past') ...[
                            if (pastHolidays.isEmpty)
                              _buildEmptyFilterState(context, 'No past holidays recorded.')
                            else
                              ...pastHolidays.map((h) => _buildHolidayTile(context, h, isUpcoming: false)),
                          ],
                        ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHolidayDialog(context, libraryId),
        icon: const Icon(Icons.add),
        label: const Text('Add Holiday'),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_busy_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayTile(
    BuildContext context,
    HolidayModel holiday, {
    required bool isUpcoming,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final relativeLabel = _getRelativeDateLabel(holiday.date);

    return Dismissible(
      key: Key(holiday.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _confirmDelete(context, holiday);
      },
      onDismissed: (direction) {
        _deleteHoliday(holiday.id, holiday.reason);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isUpcoming
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMM').format(holiday.date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isUpcoming
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  DateFormat('dd').format(holiday.date),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isUpcoming
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            holiday.reason,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(holiday.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (relativeLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isUpcoming
                          ? colorScheme.primary.withValues(alpha: 0.12)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      relativeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isUpcoming ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Full-day badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: holiday.isFullDay
                      ? colorScheme.primaryContainer
                      : colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  holiday.isFullDay ? 'Full Day' : 'Half Day',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: holiday.isFullDay
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: colorScheme.error,
                tooltip: 'Delete holiday',
                onPressed: () async {
                  final confirmed = await _confirmDelete(context, holiday);
                  if (confirmed && mounted) {
                    await _deleteHoliday(holiday.id, holiday.reason);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for adding a new holiday.
class _AddHolidayDialog extends StatefulWidget {
  final String libraryId;

  const _AddHolidayDialog({required this.libraryId});

  @override
  State<_AddHolidayDialog> createState() => _AddHolidayDialogState();
}

class _AddHolidayDialogState extends State<_AddHolidayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _selectedDate = DateTime.now();
  bool _isFullDay = true;
  bool _isSaving = false;
  String? _dateError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateError = null;
      });
    }
  }

  Future<void> _save() async {
    if (_selectedDate == null) {
      setState(() {
        _dateError = 'Please select a date';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final ref = FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .collection('holidays');

      final newDoc = ref.doc();
      final holiday = HolidayModel(
        id: newDoc.id,
        libraryId: widget.libraryId,
        date: _selectedDate!,
        reason: _reasonController.text.trim(),
        isFullDay: _isFullDay,
        createdAt: DateTime.now(),
      );

      await newDoc.set(holiday.toJson());

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save holiday: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateStr = _selectedDate != null
        ? DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!)
        : 'Select holiday date';

    return AlertDialog(
      title: const Text('Add Holiday'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Holiday Date *',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _isSaving ? null : _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _dateError != null ? colorScheme.error : colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dateStr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _selectedDate != null ? colorScheme.onSurface : colorScheme.outline,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isSaving ? null : _pickDate,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_dateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    _dateError!,
                    style: TextStyle(color: colorScheme.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  hintText: 'e.g., Diwali, Independence Day, Renovation',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.celebration_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a holiday reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Full Day Holiday'),
                subtitle: Text(
                  _isFullDay
                      ? 'Library closed for the entire day'
                      : 'Partial / half day holiday',
                  style: theme.textTheme.bodySmall,
                ),
                value: _isFullDay,
                onChanged: _isSaving ? null : (val) => setState(() => _isFullDay = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
