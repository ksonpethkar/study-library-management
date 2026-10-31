import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';
import 'package:study_library/services/data_export_service.dart';

class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  final DataExportService _exportService = DataExportService();

  // Active export operation key for per-tile spinner
  String? _activeExportKey;
  String _statusMessage = '';
  bool _isSuccess = true;

  // Filters
  ExportDateRange _dateRangeType = ExportDateRange.thisMonth;
  DateTimeRange? _customRange;
  String _studentStatusFilter = 'all';

  DateTimeRange? get _effectiveDateRange => _dateRangeType.getRange(_customRange);

  String get _dateRangeLabel {
    final range = _effectiveDateRange;
    if (range == null) return 'All Historical Records';
    final start = DateFormat('dd MMM yyyy').format(range.start);
    final end = DateFormat('dd MMM yyyy').format(range.end);
    return '$start  –  $end';
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRangeType = ExportDateRange.custom;
        _customRange = picked;
      });
    }
  }

  Future<void> _runExport({
    required String key,
    required Future<ExportResult> Function(String libraryId, String libraryName) action,
  }) async {
    String? libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      libraryId = ref.read(currentLibraryProvider).value?.id;
    }
    if (libraryId == null || libraryId.isEmpty) {
      libraryId = CurrentLibraryNotifier.defaultLibraryId;
    }
    final library = ref.read(currentLibraryProvider).value;
    final libraryName = library?.name.trim().isNotEmpty == true ? library!.name : 'Study Library';

    if (libraryId.isEmpty) {
      setState(() {
        _statusMessage = '❌ No active library selected. Please select a library first.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _activeExportKey = key;
      _statusMessage = 'Fetching and compiling data...';
      _isSuccess = true;
    });

    try {
      final result = await action(libraryId, libraryName);
      if (!mounted) return;

      if (result.success) {
        setState(() {
          _statusMessage = '✅ Successfully exported ${result.count} records (${result.fileName})';
          _isSuccess = true;
        });
      } else {
        setState(() {
          _statusMessage = '❌ Export failed: ${result.errorMessage ?? 'Unknown error occurred'}';
          _isSuccess = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '❌ Error during export: $e';
        _isSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() => _activeExportKey = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canExport = ref.watch(canExportDataProvider);

    // Permission guard
    if (!canExport) {
      return Scaffold(
        appBar: AppBar(title: const Text('Export Data & Reports')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_person_rounded, size: 64, color: Colors.orange.shade700),
                const SizedBox(height: 16),
                Text(
                  'Access Restricted',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to export library data. Please contact the library owner or administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isAnyExporting = _activeExportKey != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data & Reports'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Info Banner ──────────────────────────────────────────
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.file_download_rounded, color: theme.colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Excel & Spreadsheet Ready Exports',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'All files are formatted as clean, sanitized CSVs compatible with Microsoft Excel, Google Sheets, and accounting software.',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Date Range Filter Section ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter by Period',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                InkWell(
                  onTap: isAnyExporting ? null : _pickCustomRange,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range_rounded, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Custom Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final range in [
                    ExportDateRange.thisMonth,
                    ExportDateRange.today,
                    ExportDateRange.thisWeek,
                    ExportDateRange.lastMonth,
                    ExportDateRange.allTime,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(range.label),
                        selected: _dateRangeType == range,
                        onSelected: isAnyExporting
                            ? null
                            : (val) {
                                if (val) {
                                  setState(() {
                                    _dateRangeType = range;
                                    _customRange = null;
                                  });
                                }
                              },
                      ),
                    ),
                  if (_dateRangeType == ExportDateRange.custom)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text('Custom (${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)})'),
                        selected: true,
                        onSelected: isAnyExporting ? null : (_) => _pickCustomRange(),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  _dateRangeLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.outline),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Feedback Banner ──────────────────────────────────────────
            if (_statusMessage.isNotEmpty) ...[
              Card(
                elevation: 0,
                color: _isSuccess
                    ? Colors.green.shade500.withValues(alpha: 0.12)
                    : Colors.red.shade500.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _isSuccess
                        ? Colors.green.shade400.withValues(alpha: 0.3)
                        : Colors.red.shade400.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      if (_activeExportKey != null)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ─────────────────────────────────────────────────────────────
            // SECTION 1: FINANCIAL & REVENUE REPORTS
            // ─────────────────────────────────────────────────────────────
            _buildSectionHeader(context, 'Financial & Revenue Reports'),
            const SizedBox(height: 8),

            _buildExportCard(
              context: context,
              icon: Icons.receipt_long_rounded,
              iconColor: Colors.green,
              title: 'Payments & Collections Ledger',
              subtitle: 'Transaction ID, Student Name, Phone, Membership #, Mode, Amount, Installment, Balance Due',
              badgeText: _dateRangeType.label,
              isExporting: _activeExportKey == 'payments',
              isDisabled: isAnyExporting,
              onTap: () => _runExport(
                key: 'payments',
                action: (libId, libName) => _exportService.exportPayments(
                  libraryId: libId,
                  libraryName: libName,
                  dateRange: _effectiveDateRange,
                ),
              ),
            ),

            const SizedBox(height: 10),

            _buildExportCard(
              context: context,
              icon: Icons.payments_rounded,
              iconColor: Colors.deepOrange,
              title: 'Expenses & Outflows Ledger',
              subtitle: 'Rent, Electricity, Wi-Fi, Staff Salaries, Maintenance, Cleaning, Drinking Water, Vendor details',
              badgeText: _dateRangeType.label,
              isExporting: _activeExportKey == 'expenses',
              isDisabled: isAnyExporting,
              onTap: () => _runExport(
                key: 'expenses',
                action: (libId, libName) => _exportService.exportExpenses(
                  libraryId: libId,
                  libraryName: libName,
                  dateRange: _effectiveDateRange,
                ),
              ),
            ),

            const SizedBox(height: 10),

            _buildExportCard(
              context: context,
              icon: Icons.query_stats_rounded,
              iconColor: Colors.purple,
              title: 'Financial P&L Executive Summary',
              subtitle: 'Total Revenue, Total Expenses, Net Margin, Mode-wise Collections, Category-wise Outflows',
              badgeText: 'P&L Report',
              isExporting: _activeExportKey == 'pnl',
              isDisabled: isAnyExporting,
              onTap: () => _runExport(
                key: 'pnl',
                action: (libId, libName) => _exportService.exportFinancialSummary(
                  libraryId: libId,
                  libraryName: libName,
                  dateRange: _effectiveDateRange,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // SECTION 2: STUDENTS & DUE COLLECTIONS
            // ─────────────────────────────────────────────────────────────
            _buildSectionHeader(context, 'Students & Due Management'),
            const SizedBox(height: 8),

            // Optional status filter chip for students
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Text('Student Status:', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _studentStatusFilter,
                    isDense: true,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Students')),
                      DropdownMenuItem(value: 'active', child: Text('Active Only')),
                      DropdownMenuItem(value: 'expired', child: Text('Expired Only')),
                      DropdownMenuItem(value: 'grace', child: Text('Grace Period')),
                      DropdownMenuItem(value: 'blocked', child: Text('Blocked Only')),
                    ],
                    onChanged: isAnyExporting
                        ? null
                        : (val) {
                            if (val != null) setState(() => _studentStatusFilter = val);
                          },
                  ),
                ],
              ),
            ),

            _buildExportCard(
              context: context,
              icon: Icons.people_alt_rounded,
              iconColor: Colors.blue,
              title: 'Students Master Directory',
              subtitle: 'Full profiles, Seats, Shifts, Plans, Expiry dates, Due balances, KYC ID, Father & Emergency contacts',
              badgeText: _studentStatusFilter.toUpperCase(),
              isExporting: _activeExportKey == 'students',
              isDisabled: isAnyExporting,
              onTap: () => _runExport(
                key: 'students',
                action: (libId, libName) => _exportService.exportStudents(
                  libraryId: libId,
                  libraryName: libName,
                  statusFilter: _studentStatusFilter,
                  dateRange: _dateRangeType == ExportDateRange.allTime ? null : _effectiveDateRange,
                ),
              ),
            ),

            const SizedBox(height: 10),

            _buildExportCard(
              context: context,
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.amber.shade900,
              title: 'Fee Defaulters & Overdue Balances',
              subtitle: 'Students with unpaid dues, expired memberships, or active grace period with days overdue',
              badgeText: 'Action Required',
              isExporting: _activeExportKey == 'defaulters',
              isDisabled: isAnyExporting,
              onTap: () => _runExport(
                key: 'defaulters',
                action: (libId, libName) => _exportService.exportFeeDefaulters(
                  libraryId: libId,
                  libraryName: libName,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────────────────────
            // SECTION 3: OPERATIONS & CAPACITY
            // ─────────────────────────────────────────────────────────────
            _buildSectionHeader(context, 'Operations & Space Capacity'),
            const SizedBox(height: 8),

            _buildExportCard(
              context: context,
              icon: Icons.chair_rounded,
              iconColor: Colors.teal,
              title: 'Seat Allocation & Occupancy Matrix',
              subtitle: 'Seat labels, Sections/Halls, Shift timings, Status (Occupied / Available), Student occupant & expiry',
              badgeText: 'Live Inventory',
              isExporting: _activeExportKey == 'seats',
              isDisabled: isAnyExporting,
              onTap: () => _runExport(
                key: 'seats',
                action: (libId, libName) => _exportService.exportSeatsAndOccupancy(
                  libraryId: libId,
                  libraryName: libName,
                ),
              ),
            ),

            const SizedBox(height: 10),

            _buildExportCard(
              context: context,
              icon: Icons.hourglass_top_rounded,
              iconColor: Colors.indigo,
              title: 'Waiting List Queue Register',
              subtitle: 'Queue positions, Student contacts, Preferred shift/hall, Suggested seat allocation, and Notes',
              badgeText: 'Waitlist',
              isExporting: _activeExportKey == 'waiting_list',
              isDisabled: isAnyExporting,
              onTap: () => _runExport(
                key: 'waiting_list',
                action: (libId, libName) => _exportService.exportWaitingList(
                  libraryId: libId,
                  libraryName: libName,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildSectionHeader(BuildContext context, String title, {IconData? icon}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon ?? Icons.analytics_rounded, size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required bool isExporting,
    required bool isDisabled,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isDisabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
              const SizedBox(width: 12),
              isExporting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
