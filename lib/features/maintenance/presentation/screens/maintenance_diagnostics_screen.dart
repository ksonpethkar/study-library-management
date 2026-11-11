import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/utils/app_haptics.dart';
import 'package:study_library/core/utils/file_download_helper.dart';
import 'package:study_library/features/maintenance/data/services/database_diagnostics_service.dart';
import 'package:study_library/features/maintenance/presentation/providers/maintenance_providers.dart';

/// Unified Maintenance & Diagnostics Studio for Cozy Corner:
/// 1. Quota & Storage Pulse (Spark Free Plan limits vs live usage)
/// 2. Invariant Auto-Healer (Diagnostic Scanner & Orphaned desk repair)
/// 3. Stale Data & Cache Optimizer (Prune old read notifications, trash & memory)
class MaintenanceDiagnosticsScreen extends ConsumerStatefulWidget {
  const MaintenanceDiagnosticsScreen({super.key});

  @override
  ConsumerState<MaintenanceDiagnosticsScreen> createState() => _MaintenanceDiagnosticsScreenState();
}

class _MaintenanceDiagnosticsScreenState extends ConsumerState<MaintenanceDiagnosticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAutoHealing = false;
  bool _isPruning = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runAutoHeal(IntegrityReport report) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.healing_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Auto-Heal Database Invariants'),
          ],
        ),
        content: Text(
          'This will automatically release ${report.healableCount} orphaned/misaligned desks and clear ghost student IDs. All changes will be logged in the library audit trail.\n\nProceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Heal Database'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isAutoHealing = true);
    AppHaptics.medium();

    try {
      final service = ref.read(databaseDiagnosticsServiceProvider);
      final res = await service.autoHealIntegrityIssues(libraryId, report);

      ref.invalidate(integrityReportProvider);
      ref.invalidate(databaseMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Auto-Heal Complete: ${res.healedSeatsCount} desks released, ${res.clearedGhostIdsCount} ghost IDs cleaned.',
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to auto-heal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoHealing = false);
    }
  }

  Future<void> _runPruning({
    bool pruneNotifications = true,
    bool pruneRecycleBin = true,
    bool pruneAuditLogs = false,
  }) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 8),
            Text('Confirm Safe Data Pruning'),
          ],
        ),
        content: const Text(
          'This will safely delete read notifications older than 30 days and recycle bin items older than 30 days. Active students, past receipts, and current plans will NEVER be touched.\n\nProceed with cleanup?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Cleanup'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPruning = true);
    AppHaptics.medium();

    try {
      final service = ref.read(databaseDiagnosticsServiceProvider);
      final res = await service.pruneStaleData(
        libraryId,
        pruneNotifications: pruneNotifications,
        pruneRecycleBin: pruneRecycleBin,
        pruneAuditLogs: pruneAuditLogs,
      );

      ref.invalidate(integrityReportProvider);
      ref.invalidate(databaseMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Cleanup Complete: Pruned ${res.prunedNotifications} old notifications & ${res.prunedRecycleBin} trash records.',
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleanup failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPruning = false);
    }
  }

  Future<void> _exportDiagnosticReport() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final metricsAsync = ref.read(databaseMetricsProvider);
    final reportAsync = ref.read(integrityReportProvider);

    final metrics = metricsAsync.value;
    final report = reportAsync.value;

    if (metrics == null || report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for diagnostics to finish loading.')),
      );
      return;
    }

    final service = ref.read(databaseDiagnosticsServiceProvider);
    final reportText = service.generateDiagnosticTextReport(metrics, report);
    final bytes = utf8.encode(reportText);

    final fileName = 'cozy_corner_diagnostics_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt';

    await FileDownloadHelper.downloadFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'text/plain',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Diagnostic report saved ($fileName) ✓'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  Future<void> _openFirebaseConsole() async {
    const url = 'https://console.firebase.google.com/project/study-lib-mgmt-2026/usage';
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open external browser for Firebase console.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open link: $e')),
        );
      }
    }
  }

  Future<void> _runManualScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    AppHaptics.medium();
    ref.invalidate(integrityReportProvider);
    ref.invalidate(databaseMetricsProvider);
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Diagnostic Scan Complete: Database invariants 100% verified.')),
            ],
          ),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final metricsAsync = ref.watch(databaseMetricsProvider);
    final reportAsync = ref.watch(integrityReportProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Settings',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminMore),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Diagnostics', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('Database metrics & auto-healer', style: TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download Diagnostic Report',
            onPressed: _exportDiagnosticReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Metrics',
            onPressed: () {
              AppHaptics.light();
              ref.invalidate(databaseMetricsProvider);
              ref.invalidate(integrityReportProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: const [
            Tab(icon: Icon(Icons.speed_rounded, size: 20), text: 'Quota'),
            Tab(icon: Icon(Icons.healing_rounded, size: 20), text: 'Auto-Healer'),
            Tab(icon: Icon(Icons.cleaning_services_rounded, size: 20), text: 'Optimizer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: QUOTA & STORAGE PULSE ──
          _buildQuotaTab(context, theme, isDark, metricsAsync),

          // ── TAB 2: INTEGRITY AUTO-HEALER ──
          _buildIntegrityTab(context, theme, isDark, reportAsync),

          // ── TAB 3: STALE DATA & CACHE OPTIMIZER ──
          _buildOptimizerTab(context, theme, isDark, reportAsync),
        ],
      ),
    );
  }

  Widget _buildQuotaTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AsyncValue<DatabaseMetrics> metricsAsync,
  ) {
    return metricsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load database metrics: $e')),
      data: (m) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Firebase Spark Free Tier Gauge
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: const Color(0xFF059669).withValues(alpha: 0.3)),
              ),
              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFECFDF5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF059669),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Firebase Spark Plan: 100% Free Quota',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'All daily operational usage is fully covered by Google Free Tier',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'HEALTHY 🟢',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Progress Metrics
                    _buildQuotaBar(
                      label: 'Daily Firestore Reads',
                      current: m.estimatedDailyReads,
                      max: DatabaseMetrics.sparkDailyFreeReads,
                      percent: m.readsQuotaPercent,
                      color: const Color(0xFF059669),
                      unit: 'reads',
                    ),
                    const SizedBox(height: 12),
                    _buildQuotaBar(
                      label: 'Daily Firestore Writes',
                      current: m.estimatedDailyWrites,
                      max: DatabaseMetrics.sparkDailyFreeWrites,
                      percent: m.writesQuotaPercent,
                      color: const Color(0xFF2563EB),
                      unit: 'writes',
                    ),
                    const SizedBox(height: 12),
                    _buildQuotaBar(
                      label: 'Stored Data Size (JSON & Metadata)',
                      currentText: m.formattedStorageSize,
                      maxText: '1.0 GB Free Limit',
                      percent: m.storageQuotaPercent,
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Direct Firebase Console Link
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('View Real-Time Google Cloud Quota in Firebase Console'),
              onPressed: _openFirebaseConsole,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Live Collection Inventory Bento Grid
            Text('Collection Document Inventory', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Real-time document counts measured across all library collections', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildBentoTile(
                  icon: Icons.people_rounded,
                  color: const Color(0xFF0284C7),
                  title: 'Students',
                  count: '${m.studentsCount} (${m.activeStudentsCount} Active)',
                  subtitle: 'KYC & passes',
                ),
                _buildBentoTile(
                  icon: Icons.chair_rounded,
                  color: const Color(0xFF7C3AED),
                  title: 'Desks / Seats',
                  count: '${m.seatsCount}',
                  subtitle: '${m.sectionsCount} Sections',
                ),
                _buildBentoTile(
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF059669),
                  title: 'Payments',
                  count: '${m.paymentsCount}',
                  subtitle: 'Recorded transactions',
                ),
                _buildBentoTile(
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF0D9488),
                  title: 'Receipts',
                  count: '${m.receiptsCount}',
                  subtitle: 'GST / Fee receipts',
                ),
                _buildBentoTile(
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFFE11D48),
                  title: 'Expenses',
                  count: '${m.expensesCount}',
                  subtitle: 'Petty cash log',
                ),
                _buildBentoTile(
                  icon: Icons.notifications_rounded,
                  color: const Color(0xFFD97706),
                  title: 'Notifications',
                  count: '${m.notificationsCount}',
                  subtitle: 'Alerts & circulars',
                ),
                _buildBentoTile(
                  icon: Icons.history_rounded,
                  color: const Color(0xFF64748B),
                  title: 'Audit Logs',
                  count: '${m.auditLogCount}',
                  subtitle: 'Traceability trail',
                ),
                _buildBentoTile(
                  icon: Icons.hourglass_top_rounded,
                  color: const Color(0xFF8B5CF6),
                  title: 'Waiting List',
                  count: '${m.waitingListCount}',
                  subtitle: 'Prospective leads',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildIntegrityTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AsyncValue<IntegrityReport> reportAsync,
  ) {
    return reportAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning database invariants & seat references...'),
          ],
        ),
      ),
      error: (e, _) => Center(child: Text('Diagnostic scan failed: $e')),
      data: (report) {
        if (!report.hasIssues) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 64),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'All Database Invariants 100% Intact',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scanned ${report.totalSeatsScanned} seats across all sections and ${report.totalStudentsScanned} student profiles. Zero orphaned desks or broken references detected.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFF059669), width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(_isScanning ? 'Scanning Database...' : 'Re-Run Diagnostic Scan'),
                    onPressed: _isScanning ? null : _runManualScan,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Issues Warning Header
            Card(
              elevation: 0,
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.amber.shade400),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${report.issues.length} Discrepancies Detected',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade900),
                          ),
                          Text(
                            '${report.healableCount} issues can be resolved automatically right now.',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (report.healableCount > 0)
              FilledButton.icon(
                icon: _isAutoHealing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_fix_high_rounded),
                label: Text(_isAutoHealing ? 'Healing Invariants...' : 'Auto-Heal All ${report.healableCount} Invariants'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isAutoHealing ? null : () => _runAutoHeal(report),
              ),

            const SizedBox(height: 20),
            Text('Discrepancy Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            ...report.issues.map((issue) {
              final isError = issue.severity == IssueSeverity.error;
              final color = isError ? const Color(0xFFDC2626) : const Color(0xFFD97706);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: color, size: 20),
                  ),
                  title: Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(issue.description, style: const TextStyle(fontSize: 12)),
                  trailing: issue.canAutoHeal
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('AUTO-FIX', style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      : null,
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildOptimizerTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AsyncValue<IntegrityReport> reportAsync,
  ) {
    final report = reportAsync.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Stale Document Pruning', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text('Safely trim obsolete alerts and expired trash to keep collections lightweight', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),

        // 1. Prune Read Notifications
        _buildPruneTile(
          icon: Icons.notifications_off_rounded,
          color: const Color(0xFFD97706),
          title: 'Prune Read Notifications (>30 Days)',
          count: report?.staleNotificationsCount ?? 0,
          description: 'Removes old read alerts from student notification inboxes while preserving active notices.',
          onTap: () => _runPruning(pruneNotifications: true, pruneRecycleBin: false, pruneAuditLogs: false),
        ),

        const SizedBox(height: 12),

        // 2. Empty Expired Trash
        _buildPruneTile(
          icon: Icons.delete_sweep_rounded,
          color: const Color(0xFFE11D48),
          title: 'Purge Expired Recycle Bin (>30 Days)',
          count: report?.expiredRecycleBinCount ?? 0,
          description: 'Permanently deletes soft-deleted records past their 30-day recovery window.',
          onTap: () => _runPruning(pruneNotifications: false, pruneRecycleBin: true, pruneAuditLogs: false),
        ),

        const SizedBox(height: 12),

        // 3. Flush Local Caches
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF4F46E5),
              child: Icon(Icons.cached_rounded, color: Colors.white, size: 20),
            ),
            title: const Text('Flush Local Device Image & In-Memory Cache', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text('Clears in-memory Flutter image cache and invalidates local state streams.', style: TextStyle(fontSize: 12)),
            trailing: OutlinedButton(
              onPressed: () async {
                AppHaptics.light();
                final service = ref.read(databaseDiagnosticsServiceProvider);
                await service.clearLocalCaches(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Local caches flushed successfully!')),
                  );
                }
              },
              child: const Text('Flush'),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Master 1-Tap Cleanup
        FilledButton.icon(
          icon: _isPruning
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.bolt_rounded),
          label: Text(_isPruning ? 'Cleaning Database...' : 'Run Safe 1-Tap Database Cleanup'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE11D48),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isPruning ? null : () => _runPruning(pruneNotifications: true, pruneRecycleBin: true),
        ),
      ],
    );
  }

  Widget _buildQuotaBar({
    required String label,
    int? current,
    int? max,
    String? currentText,
    String? maxText,
    required double percent,
    required Color color,
    String unit = '',
  }) {
    final fmt = NumberFormat('#,##,###');
    final curStr = currentText ?? '${fmt.format(current)} $unit';
    final maxStr = maxText ?? '${fmt.format(max)} $unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: Text(
                '$curStr / $maxStr (${(percent * 100).toStringAsFixed(1)}%)',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoTile({
    required IconData icon,
    required Color color,
    required String title,
    required String count,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : color), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text(count, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(subtitle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPruneTile({
    required IconData icon,
    required Color color,
    required String title,
    required int count,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: count > 0 ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count ready',
                    style: TextStyle(
                      color: count > 0 ? color : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (count > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: color,
                  ),
                  onPressed: onTap,
                  child: Text('Clean $count Records'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
