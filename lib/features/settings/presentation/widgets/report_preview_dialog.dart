import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_library/services/data_export_service.dart';
import 'package:study_library/services/whatsapp_service.dart';

class ReportPreviewDialog extends StatefulWidget {
  final ReportPreviewData data;
  final Future<void> Function() onExportCsv;
  final String libraryName;

  const ReportPreviewDialog({
    super.key,
    required this.data,
    required this.onExportCsv,
    required this.libraryName,
  });

  static Future<void> show({
    required BuildContext context,
    required ReportPreviewData data,
    required Future<void> Function() onExportCsv,
    required String libraryName,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReportPreviewDialog(
        data: data,
        onExportCsv: onExportCsv,
        libraryName: libraryName,
      ),
    );
  }

  @override
  State<ReportPreviewDialog> createState() => _ReportPreviewDialogState();
}

class _ReportPreviewDialogState extends State<ReportPreviewDialog> {
  final TextEditingController _searchController = TextEditingController();
  final WhatsAppService _whatsAppService = WhatsAppService();

  String _searchQuery = '';
  bool _isCardView = false;
  bool _isExporting = false;
  String? _exportSuccessMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<int> get _filteredIndices {
    if (_searchQuery.isEmpty) {
      return List<int>.generate(widget.data.rows.length, (i) => i);
    }
    final results = <int>[];
    for (int i = 0; i < widget.data.rows.length; i++) {
      final row = widget.data.rows[i];
      final matches = row.any((cell) => cell.toLowerCase().contains(_searchQuery));
      if (matches) {
        results.add(i);
      }
    }
    return results;
  }

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
      _exportSuccessMessage = null;
    });
    try {
      await widget.onExportCsv();
      if (mounted) {
        setState(() {
          _exportSuccessMessage = '✅ CSV export complete! File downloaded.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('CSV downloaded successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _sendWhatsAppAlert(Map<String, dynamic> metadata) async {
    final phone = (metadata['phone'] as String?) ?? '';
    final name = (metadata['name'] as String?) ?? 'Student';
    final due = (metadata['due'] as num?)?.toDouble() ?? 0.0;
    final plan = (metadata['planName'] as String?) ?? 'membership';
    final expiry = (metadata['expiryDate'] as String?) ?? '';

    if (phone.isEmpty || phone == '—') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number recorded for this student.')),
      );
      return;
    }

    if (widget.data.reportKey == 'defaulters') {
      await _whatsAppService.sendDueReminder(
        phone: phone,
        studentName: name,
        libraryName: widget.libraryName,
        dueAmount: due,
        planName: plan,
        dueDate: expiry,
        context: mounted ? context : null,
      );
    } else {
      await _whatsAppService.sendMessage(
        phone,
        'Hello $name, greeting from ${widget.libraryName}. This is regarding your library study seat.',
        context: mounted ? context : null,
        recipientName: name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;
    final filteredIndices = _filteredIndices;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8.0 : 28.0,
        vertical: isMobile ? 12.0 : 28.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1040,
          maxHeight: size.height * (isMobile ? 0.95 : 0.88),
        ),
        child: Column(
          children: [
            // ── TOP HEADER ──────────────────────────────────────────────────
            _buildHeader(context, theme, isMobile),

            const Divider(height: 1),

            // ── SCROLLABLE BODY ─────────────────────────────────────────────
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // 1. Summary KPIs Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: _buildKpisRow(context, theme, isMobile),
                    ),
                  ),

                  // 2. Search & Toolbar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: _buildSearchBar(context, theme, filteredIndices.length, isMobile),
                    ),
                  ),

                  // 3. Feedback Banner if exported
                  if (_exportSuccessMessage != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade500.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade400.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _exportSuccessMessage!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  // 4. Data Content: Table or Cards
                  if (widget.data.rows.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme, isSearch: false),
                    )
                  else if (filteredIndices.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme, isSearch: true),
                    )
                  else if (_isCardView && isMobile)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final rowIndex = filteredIndices[index];
                            final row = widget.data.rows[rowIndex];
                            final metadata = (widget.data.rowMetadata != null &&
                                    rowIndex < widget.data.rowMetadata!.length)
                                ? widget.data.rowMetadata![rowIndex]
                                : null;
                            return _buildMobileCard(theme, row, metadata);
                          },
                          childCount: filteredIndices.length,
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildDataTable(context, theme, filteredIndices),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── BOTTOM ACTIONS ──────────────────────────────────────────────
            _buildFooter(context, theme, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.preview_rounded, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.data.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.data.badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _isExporting ? null : _handleExport,
              icon: _isExporting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Close Preview',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildKpisRow(BuildContext context, ThemeData theme, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final kpis = widget.data.kpis;
        if (kpis.isEmpty) return const SizedBox.shrink();

        final crossAxisCount = constraints.maxWidth > 800
            ? kpis.length
            : (constraints.maxWidth > 500 ? (kpis.length > 2 ? 3 : 2) : 2);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isMobile ? 2.1 : 2.5,
          ),
          itemCount: kpis.length,
          itemBuilder: (context, idx) {
            final kpi = kpis[idx];
            final color = kpi.color ?? theme.colorScheme.primary;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(kpi.icon ?? Icons.analytics_rounded, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          kpi.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          kpi.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (kpi.subtitle != null && !isMobile) ...[
                          const SizedBox(height: 1),
                          Text(
                            kpi.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, ThemeData theme, int currentCount, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by student name, phone, seat, reference, or category...',
                hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$currentCount / ${widget.data.rows.length}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (isMobile) ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: _isCardView ? 'Switch to Table View' : 'Switch to Card View',
            icon: Icon(_isCardView ? Icons.table_chart_rounded : Icons.view_agenda_rounded, size: 20),
            onPressed: () => setState(() => _isCardView = !_isCardView),
          ),
        ],
      ],
    );
  }

  Widget _buildDataTable(BuildContext context, ThemeData theme, List<int> indices) {
    final hasAction = widget.data.reportKey == 'defaulters' || widget.data.reportKey == 'waiting_list';
    final headers = [...widget.data.headers, if (hasAction) 'Quick Action'];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 800),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            headingRowHeight: 42,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 52,
            horizontalMargin: 16,
            columnSpacing: 20,
            columns: [
              for (final header in headers)
                DataColumn(
                  label: Text(
                    header,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
            ],
            rows: [
              for (int i = 0; i < indices.length; i++) ...[
                () {
                  final rowIndex = indices[i];
                  final row = widget.data.rows[rowIndex];
                  final metadata = (widget.data.rowMetadata != null &&
                          rowIndex < widget.data.rowMetadata!.length)
                      ? widget.data.rowMetadata![rowIndex]
                      : null;

                  return DataRow(
                    color: WidgetStateProperty.all(
                      i.isEven ? Colors.transparent : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                    ),
                    cells: [
                      for (int c = 0; c < row.length; c++)
                        DataCell(_buildCellContent(theme, headers[c], row[c])),
                      if (hasAction)
                        DataCell(
                          IconButton.filledTonal(
                            tooltip: widget.data.reportKey == 'defaulters'
                                ? 'Send WhatsApp Due Reminder'
                                : 'Contact Applicant',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.green),
                            onPressed: metadata != null ? () => _sendWhatsAppAlert(metadata) : null,
                          ),
                        ),
                    ],
                  );
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(ThemeData theme, String header, String value) {
    final h = header.toLowerCase();
    final v = value.toUpperCase();

    // Badges for Status
    if (h.contains('status')) {
      Color bg = theme.colorScheme.surfaceContainerHighest;
      Color fg = theme.colorScheme.onSurfaceVariant;

      if (v == 'ACTIVE' || v == 'PAID' || v == 'AVAILABLE') {
        bg = Colors.green.shade500.withValues(alpha: 0.15);
        fg = Colors.green.shade800;
      } else if (v == 'EXPIRED' || v == 'OCCUPIED') {
        bg = Colors.red.shade500.withValues(alpha: 0.15);
        fg = Colors.red.shade800;
      } else if (v == 'GRACE' || v == 'PARTIAL' || v == 'PENDING') {
        bg = Colors.amber.shade500.withValues(alpha: 0.2);
        fg = Colors.amber.shade900;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
        ),
      );
    }

    // Amount or Dues styling
    if (h.contains('amount') || h.contains('due') || h.contains('revenue') || h.contains('profit')) {
      final isDue = h.contains('due') && value != '₹0';
      return Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDue ? Colors.red.shade700 : theme.colorScheme.onSurface,
        ),
      );
    }

    return Text(
      value,
      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
    );
  }

  Widget _buildMobileCard(ThemeData theme, List<String> row, Map<String, dynamic>? metadata) {
    final hasAction = widget.data.reportKey == 'defaulters' || widget.data.reportKey == 'waiting_list';
    final headers = widget.data.headers;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    row.length > 1 ? row[1] : (row.isNotEmpty ? row[0] : 'Record'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (row.isNotEmpty)
                  _buildCellContent(theme, headers.last, row.last),
              ],
            ),
            const Divider(height: 16),
            for (int i = 0; i < row.length; i++) ...[
              if (i != 1 && i != row.length - 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        headers[i],
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                      ),
                      Text(
                        row[i],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
            if (hasAction && metadata != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _sendWhatsAppAlert(metadata),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.green),
                  label: Text(
                    widget.data.reportKey == 'defaulters' ? 'Send WhatsApp Alert' : 'WhatsApp Applicant',
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, {required bool isSearch}) {
    if (!isSearch) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 52, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              const Text(
                'No Records Found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'There are no entries logged for this report in the selected period.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No records match "$_searchQuery"',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search query or clear the filter',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _searchController.clear(),
              child: const Text('Clear Search Filter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme, bool isMobile) {
    final nowStr = DateFormat('hh:mm a').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.sync_rounded, size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Text(
                'Synced $nowStr • ${widget.data.totalCount} total entries',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Close', style: TextStyle(fontSize: 12)),
              ),
              if (isMobile) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isExporting ? null : _handleExport,
                  icon: _isExporting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: const Text('CSV', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
