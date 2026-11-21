import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/sentinel/sentinel_models.dart';
import 'package:study_library/core/sentinel/sentinel_service.dart';

final sentinelServiceProvider = Provider<SentinelService>((ref) {
  return SentinelService.instance;
});

class SentinelMetricsNotifier extends Notifier<SentinelHealthMetrics> {
  late final SentinelService _service;

  @override
  SentinelHealthMetrics build() {
    _service = ref.watch(sentinelServiceProvider);
    _service.addListener(_onServiceUpdate);
    ref.onDispose(() {
      _service.removeListener(_onServiceUpdate);
    });
    return _service.getHealthMetrics();
  }

  void _onServiceUpdate() {
    state = _service.getHealthMetrics();
  }

  Future<void> triggerDeepScan({
    required String libraryId,
    required dynamic seats,
    required dynamic students,
  }) async {
    await _service.runDeepDiagnosticScan(
      libraryId: libraryId,
      seats: seats,
      students: students,
    );
  }
}

/// Reactive stream/state provider for system health metrics.
final sentinelMetricsProvider =
    NotifierProvider<SentinelMetricsNotifier, SentinelHealthMetrics>(SentinelMetricsNotifier.new);

/// Reactive provider for all active and detected system anomalies.
final sentinelAnomaliesProvider = Provider<List<SentinelAnomaly>>((ref) {
  ref.watch(sentinelMetricsProvider);
  return ref.watch(sentinelServiceProvider).anomalies;
});

/// Reactive provider for recent Echo Verification events.
final sentinelEchoEventsProvider = Provider<List<SentinelEchoEvent>>((ref) {
  ref.watch(sentinelMetricsProvider);
  return ref.watch(sentinelServiceProvider).echoVerifier.recentEvents;
});
