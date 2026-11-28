import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/maintenance/data/services/database_diagnostics_service.dart';
import 'package:study_library/services/app_notification_service.dart';

final databaseDiagnosticsServiceProvider = Provider<DatabaseDiagnosticsService>((ref) {
  return DatabaseDiagnosticsService();
});

/// Future provider that fetches collection metrics and Spark quota statistics.
final databaseMetricsProvider = FutureProvider.autoDispose<DatabaseMetrics>((ref) async {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    throw Exception('No active library selected.');
  }
  final service = ref.watch(databaseDiagnosticsServiceProvider);
  return await service.fetchDatabaseMetrics(libraryId);
});

/// State provider for holding the latest integrity scan result.
final integrityReportProvider = FutureProvider.autoDispose<IntegrityReport>((ref) async {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    throw Exception('No active library selected.');
  }
  final service = ref.watch(databaseDiagnosticsServiceProvider);
  final report = await service.scanDatabaseIntegrity(libraryId);

  // Sync cached health summary whenever Admin opens or heals System Diagnostics
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_health_scan_ms_$libraryId', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('last_health_issues_count_$libraryId', report.issues.length);
    await prefs.setString(
      'last_health_issues_summary_$libraryId',
      report.issues.isNotEmpty ? report.issues.first.title : '',
    );
  } catch (_) {}

  return report;
});

class BackgroundHealthAlert {
  final int issueCount;
  final String headline;

  const BackgroundHealthAlert({
    required this.issueCount,
    required this.headline,
  });
}

/// Throttled (once per 6h) background database invariant check for Admin Home & Bell.
/// Dispatches 1 deduplicated Admin Notification when discrepancies are detected.
final backgroundIntegrityCheckProvider = FutureProvider.autoDispose<BackgroundHealthAlert?>((ref) async {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) return null;

  try {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastScanMs = prefs.getInt('last_health_scan_ms_$libraryId') ?? 0;
    const sixHoursMs = 6 * 60 * 60 * 1000;

    if (nowMs - lastScanMs < sixHoursMs) {
      final cachedCount = prefs.getInt('last_health_issues_count_$libraryId') ?? 0;
      if (cachedCount > 0) {
        final cachedHeadline = prefs.getString('last_health_issues_summary_$libraryId') ?? 'Database discrepancy detected';
        return BackgroundHealthAlert(issueCount: cachedCount, headline: cachedHeadline);
      }
      return null;
    }

    final service = ref.read(databaseDiagnosticsServiceProvider);
    final report = await service.scanDatabaseIntegrity(libraryId);

    await prefs.setInt('last_health_scan_ms_$libraryId', nowMs);
    await prefs.setInt('last_health_issues_count_$libraryId', report.issues.length);
    final headline = report.issues.isNotEmpty ? report.issues.first.title : '';
    await prefs.setString('last_health_issues_summary_$libraryId', headline);

    if (report.hasIssues) {
      final lastNotifMs = prefs.getInt('last_health_notif_ms_$libraryId') ?? 0;
      final lastNotifCount = prefs.getInt('last_health_notif_count_$libraryId') ?? 0;

      // Notify Admin Bell once every 6h (or immediately if issue count increased)
      if (nowMs - lastNotifMs >= sixHoursMs || report.issues.length > lastNotifCount) {
        await prefs.setInt('last_health_notif_ms_$libraryId', nowMs);
        await prefs.setInt('last_health_notif_count_$libraryId', report.issues.length);

        final firstIssue = report.issues.first;
        final count = report.issues.length;
        await AppNotificationService.sendNotification(
          libraryId: libraryId,
          title: '⚠️ $count Database Discrepanc${count == 1 ? 'y' : 'ies'} Detected',
          body: '${firstIssue.title} — ${firstIssue.description} (Tap to Auto-Heal)',
          type: 'system_health',
          targetRole: 'admin',
          actionRoute: Routes.adminMaintenance,
          metadata: {'issueCount': count},
        );
      }

      return BackgroundHealthAlert(issueCount: report.issues.length, headline: headline);
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[BackgroundHealthCheck] Skipped: $e');
  }

  return null;
});
