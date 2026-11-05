import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/maintenance/data/services/database_diagnostics_service.dart';

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
  return await service.scanDatabaseIntegrity(libraryId);
});
