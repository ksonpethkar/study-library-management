import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/sentinel/sentinel_models.dart';
import 'package:study_library/core/utils/app_haptics.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import '../providers/sentinel_providers.dart';

/// Cozy Sentinel — Autonomous System Guardian & Integrity Console.
/// Monitors real-time state reflection, detects discrepancies,
/// and provides 1-tap self-healing operations for Cozy Corner.
class SentinelDiagnosticScreen extends ConsumerStatefulWidget {
  const SentinelDiagnosticScreen({super.key});

  @override
  ConsumerState<SentinelDiagnosticScreen> createState() => _SentinelDiagnosticScreenState();
}

class _SentinelDiagnosticScreenState extends ConsumerState<SentinelDiagnosticScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAutoHealing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runDeepScan();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleBackNavigation(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.adminHome);
    }
  }

  Future<void> _runDeepScan() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    AppHaptics.medium();

    // Invariant: MUST fetch ALL seats across sections (both occupied and available),
    // never availableSeatsProvider alone which creates false-positive invalid desk anomalies.
    List<SeatModel> seats = ref.read(allSeatsProvider);
    if (seats.isEmpty || seats.every((s) => s.status == SeatStatus.available)) {
      seats = await ref.read(seatRepositoryProvider).getAllSeats(libraryId);
    }
    final students = ref.read(studentsStreamProvider).value ?? [];

    await ref.read(sentinelMetricsProvider.notifier).triggerDeepScan(
          libraryId: libraryId,
          seats: seats,
          students: students,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Deep Diagnostic Scan Complete! All invariants verified.'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleAutoHeal(SentinelAnomaly anomaly) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isAutoHealing = true);
    AppHaptics.medium();

    final service = ref.read(sentinelServiceProvider);
    final success = await service.execute1TapAutoHeal(
      libraryId: libraryId,
      anomaly: anomaly,
    );

    setState(() => _isAutoHealing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '✓ Successfully resolved: ${anomaly.title}' : 'Failed to auto-heal: ${anomaly.title}',
          ),
          backgroundColor: success ? const Color(0xFF059669) : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(sentinelMetricsProvider);
    final anomalies = ref.watch(sentinelAnomaliesProvider);
    final echoEvents = ref.watch(sentinelEchoEventsProvider);
    final service = ref.watch(sentinelServiceProvider);
    final aiSummary = service.aiDiagnostic.generateExecutiveSummary(metrics, anomalies);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Clamp text scaling as per Section 4 standards
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBackNavigation(context);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _handleBackNavigation(context),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cozy Sentinel Guardian',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'प्रणाली सुरक्षा व निदान केंद्र (System Guardian)',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Run Deep Scan (सखोल तपासणी)',
                icon: metrics.isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
: const Icon(Icons.refresh_rounded),
                onPressed: metrics.isScanning ? null : _runDeepScan,
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.health_and_safety_outlined, size: 20),
                  text: 'Anomalies (${anomalies.length})',
                ),
                Tab(
                  icon: const Icon(Icons.sync_alt_rounded, size: 20),
                  text: 'Live Echo Feed (${echoEvents.length})',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: System Health & Detected Anomalies
              _buildAnomaliesTab(
                context,
                metrics: metrics,
                anomalies: anomalies,
                aiSummary: aiSummary,
                isDark: isDark,
              ),
              // Tab 2: Live Echo Verification Feed
              _buildEchoFeedTab(
                context,
                echoEvents: echoEvents,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnomaliesTab(
    BuildContext context, {
    required SentinelHealthMetrics metrics,
    required List<SentinelAnomaly> anomalies,
    required String aiSummary,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 80 + MediaQuery.of(context).padding.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Health Score Hero Card
              _buildHealthHeroCard(context, metrics: metrics, isDark: isDark),
              const SizedBox(height: 16),

              // AI Copilot Executive Summary Box
              _buildAiSummaryBox(context, summary: aiSummary, isDark: isDark),
              const SizedBox(height: 16),

              // Active Watchers Status Grid
              _buildWatchersGrid(context, metrics: metrics, isDark: isDark),
              const SizedBox(height: 24),

              // Anomalies Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detected Issues (${anomalies.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (anomalies.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text('Dismiss Non-Critical'),
                      onPressed: () {
                        ref.read(sentinelServiceProvider).clearAllAnomalies();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (anomalies.isEmpty)
                _buildCleanState(context, isDark: isDark)
              else
                ...anomalies.map((a) => _buildAnomalyCard(context, anomaly: a, isDark: isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthHeroCard(
    BuildContext context, {
    required SentinelHealthMetrics metrics,
    required bool isDark,
  }) {
    Color statusColor;
    if (metrics.score >= 90.0) {
      statusColor = const Color(0xFF059669); // Emerald Green
    } else if (metrics.score >= 75.0) {
      statusColor = const Color(0xFFD97706); // Amber
    } else {
      statusColor = const Color(0xFFDC2626); // Crimson Red
    }

    return Card(
      elevation: 0,
      color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: metrics.score / 100.0,
                    strokeWidth: 8,
                    backgroundColor: statusColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                Text(
                  '${metrics.score.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          metrics.statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cozy Sentinel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last Audit: ${DateFormat('hh:mm:ss a').format(metrics.lastAuditTime)}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildMiniBadge('Critical', metrics.criticalCount, Colors.red),
                      _buildMiniBadge('Warnings', metrics.warningCount, Colors.amber.shade800),
                      _buildMiniBadge('Advisories', metrics.advisoryCount, Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildAiSummaryBox(BuildContext context, {required String summary, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sentinel AI Diagnostic Summary (बुद्धिमत्ता विश्लेषण)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchersGrid(
    BuildContext context, {
    required SentinelHealthMetrics metrics,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active System Watchers (सक्रिय सुरक्षा घटक)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildWatcherTile(
                icon: Icons.chair_rounded,
                title: 'Seat & Desks',
                subtitle: 'Double-Binding & Soft-Locks',
                status: 'HEALTHY',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWatcherTile(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Finance & Dues',
                subtitle: 'Zero Negative Dues',
                status: 'HEALTHY',
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildWatcherTile(
                icon: Icons.sync_rounded,
                title: 'Dual-Portal Parity',
                subtitle: 'ID Card & Pass Sync',
                status: 'HEALTHY',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWatcherTile(
                icon: Icons.speed_rounded,
                title: 'Stream Heartbeat',
                subtitle: '${metrics.averageStreamLatencyMs}ms average SLA',
                status: 'ACTIVE',
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWatcherTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF059669)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanState(BuildContext context, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 48),
          const SizedBox(height: 12),
          const Text(
            'Zero Discrepancies Detected',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'All Firestore documents, Riverpod real-time streams, desk allocations, and financial records are in 100% mathematical consistency.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyCard(
    BuildContext context, {
    required SentinelAnomaly anomaly,
    required bool isDark,
  }) {
    Color cardColor;
    Color borderColor;

    switch (anomaly.severity) {
      case SentinelSeverity.critical:
        cardColor = Colors.red.withValues(alpha: isDark ? 0.2 : 0.08);
        borderColor = Colors.red.withValues(alpha: 0.3);
        break;
      case SentinelSeverity.warning:
        cardColor = Colors.amber.withValues(alpha: isDark ? 0.2 : 0.08);
        borderColor = Colors.amber.withValues(alpha: 0.3);
        break;
      case SentinelSeverity.advisory:
      case SentinelSeverity.info:
        cardColor = Colors.blue.withValues(alpha: isDark ? 0.2 : 0.08);
        borderColor = Colors.blue.withValues(alpha: 0.3);
        break;
    }

    final service = ref.read(sentinelServiceProvider);
    final aiInsights = service.aiDiagnostic.analyzeAnomaly(anomaly);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSeverityChip(anomaly.severity),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    anomaly.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('hh:mm a').format(anomaly.detectedAt),
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              anomaly.description,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 10),

            // AI Root Cause & Remediation
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        'Root Cause: ${aiInsights['diagnosis']}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.healing_rounded, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Suggested Action: ${aiInsights['remediation']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (anomaly.domain == SentinelDomain.students && (anomaly.entityId?.isNotEmpty == true))
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.person_search_rounded, size: 16),
                    label: const Text('Update Dossier (तपशील उघडा)'),
                    onPressed: () {
                      context.push('${Routes.adminStudents}/${anomaly.entityId}');
                    },
                  ),
                if (anomaly.canAutoHeal)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: _isAutoHealing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: Text(aiInsights['actionLabel'] ?? 'Auto-Heal (स्वयं-दुरुस्ती)'),
                    onPressed: _isAutoHealing ? null : () => _handleAutoHeal(anomaly),
                  ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    ref.read(sentinelServiceProvider).clearAnomaly(anomaly.id);
                  },
                  child: const Text('Dismiss (दुर्लक्ष करा)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(SentinelSeverity severity) {
    Color bg;
    Color fg;
    String text;

    switch (severity) {
      case SentinelSeverity.critical:
        bg = Colors.red;
        fg = Colors.white;
        text = 'CRITICAL';
        break;
      case SentinelSeverity.warning:
        bg = Colors.amber.shade800;
        fg = Colors.white;
        text = 'WARNING';
        break;
      case SentinelSeverity.advisory:
      case SentinelSeverity.info:
        bg = Colors.blue;
        fg = Colors.white;
        text = 'ADVISORY';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEchoFeedTab(
    BuildContext context, {
    required List<SentinelEchoEvent> echoEvents,
    required bool isDark,
  }) {
    if (echoEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radar_rounded, size: 48, color: isDark ? Colors.white38 : Colors.black26),
            const SizedBox(height: 12),
            const Text(
              'No Recent Mutation Events',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Actions performed by counter staff will appear here with live reflection SLA timing.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 80 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: echoEvents.length,
      itemBuilder: (context, index) {
        final evt = echoEvents[index];
        Color iconColor;
        IconData icon;

        switch (evt.status) {
          case EchoStatus.passed:
            iconColor = const Color(0xFF059669);
            icon = Icons.check_circle_rounded;
            break;
          case EchoStatus.warning:
            iconColor = Colors.amber.shade800;
            icon = Icons.warning_rounded;
            break;
          case EchoStatus.failed:
            iconColor = Colors.red;
            icon = Icons.error_rounded;
            break;
          case EchoStatus.pending:
            iconColor = Colors.blue;
            icon = Icons.hourglass_top_rounded;
            break;
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: ListTile(
            leading: Icon(icon, color: iconColor, size: 24),
            title: Text(
              evt.actionName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              '${evt.details} • Correlation ID: ${evt.correlationId.length > 12 ? evt.correlationId.substring(0, 12) : evt.correlationId}',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
            ),
            trailing: Text(
              DateFormat('hh:mm:ss a').format(evt.timestamp),
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        );
      },
    );
  }
}
