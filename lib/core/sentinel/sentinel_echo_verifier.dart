import 'dart:async';
import 'sentinel_models.dart';

/// The Echo Verifier observes user/system mutations and verifies that their
/// asynchronous reflection propagates through Firestore, Riverpod streams, and UI
/// within a strict Service Level Agreement (SLA, default 2500ms).
class SentinelEchoVerifier {
  final List<SentinelEchoExpectation> _activeExpectations = [];
  final List<SentinelEchoEvent> _history = [];
  final void Function(SentinelAnomaly anomaly)? onAnomalyDetected;

  Timer? _sweepTimer;

  SentinelEchoVerifier({this.onAnomalyDetected});

  bool get hasPendingChecks => _activeExpectations.isNotEmpty;

  void _startSweepTimer() {
    if (_sweepTimer?.isActive == true) return;
    // Check for timed-out expectations every 500ms only while checks are pending
    _sweepTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _sweepExpiredExpectations();
    });
  }

  void _stopSweepTimerIfIdle() {
    if (_activeExpectations.isEmpty) {
      _sweepTimer?.cancel();
      _sweepTimer = null;
    }
  }

  void dispose() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
  }

  List<SentinelEchoExpectation> get activeExpectations =>
      List.unmodifiable(_activeExpectations);

  List<SentinelEchoEvent> get recentEvents =>
      List.unmodifiable(_history.reversed.take(50));

  /// Registers an expectation when a mutation begins.
  /// Example: "Student #CC-102 balance must decrease by ₹500 within 2500ms".
  SentinelEchoExpectation registerExpectation({
    required String actionName,
    required String correlationId,
    required SentinelDomain domain,
    required String entityId,
    required String expectedKey,
    dynamic expectedValue,
    Duration timeout = const Duration(milliseconds: 2500),
  }) {
    final exp = SentinelEchoExpectation(
      id: 'echo_${DateTime.now().millisecondsSinceEpoch}_${_activeExpectations.length}',
      actionName: actionName,
      correlationId: correlationId,
      domain: domain,
      entityId: entityId,
      expectedKey: expectedKey,
      expectedValue: expectedValue,
      registeredAt: DateTime.now(),
      timeout: timeout,
    );

    _activeExpectations.add(exp);
    _startSweepTimer();
    return exp;
  }

  /// Called when a stream or repository confirms that state has reflected.
  bool notifyStateReflected({
    required SentinelDomain domain,
    required String entityId,
    required String key,
    dynamic actualValue,
  }) {
    if (_activeExpectations.isEmpty) return false;
    final now = DateTime.now();
    bool anyMatched = false;

    for (final exp in _activeExpectations.where((e) => e.status == EchoStatus.pending)) {
      if (exp.domain == domain && exp.entityId == entityId && exp.expectedKey == key) {
        bool valueMatches = true;
        if (exp.expectedValue != null && actualValue != null) {
          valueMatches = (exp.expectedValue == actualValue);
        }

        if (valueMatches) {
          exp.status = exp.isExpired ? EchoStatus.warning : EchoStatus.passed;
          exp.resolvedAt = now;
          anyMatched = true;

          _recordEvent(
            actionName: exp.actionName,
            correlationId: exp.correlationId,
            domain: exp.domain,
            status: exp.status,
            durationMs: exp.elapsedMs,
            details: 'Reflected in ${exp.elapsedMs}ms ($key = $actualValue)',
          );
        }
      }
    }

    _activeExpectations.removeWhere((e) => e.status != EchoStatus.pending);
    _stopSweepTimerIfIdle();
    return anyMatched;
  }

  void _sweepExpiredExpectations() {
    if (_activeExpectations.isEmpty) {
      _stopSweepTimerIfIdle();
      return;
    }
    final now = DateTime.now();
    final expired = _activeExpectations.where((e) => e.isExpired).toList();

    for (final exp in expired) {
      exp.status = EchoStatus.failed;
      exp.resolvedAt = now;
      exp.failureReason = 'SLA exceeded (${exp.timeout.inMilliseconds}ms elapsed without reflection)';

      _recordEvent(
        actionName: exp.actionName,
        correlationId: exp.correlationId,
        domain: exp.domain,
        status: EchoStatus.failed,
        durationMs: exp.elapsedMs,
        details: 'Failed: ${exp.failureReason}',
      );

      // Report anomaly to Sentinel
      if (onAnomalyDetected != null) {
        onAnomalyDetected!(
          SentinelAnomaly(
            id: 'sla_${exp.id}',
            title: 'Action Reflection Timeout: ${exp.actionName}',
            description:
                'Mutation on ${exp.domain.name} (ID: ${exp.entityId}) was not reflected in streams within ${exp.timeout.inMilliseconds}ms.',
            severity: SentinelSeverity.warning,
            domain: exp.domain,
            entityId: exp.entityId,
            detectedAt: now,
            canAutoHeal: true,
            rootCauseDiagnosis:
                'Possible Firestore index degradation, slow cellular network, or stream listener detachment.',
            remediationSuggestion:
                'Check network connectivity or trigger a stream re-sync for ${exp.domain.name}.',
            metadata: {
              'correlationId': exp.correlationId,
              'elapsedMs': exp.elapsedMs,
              'expectedKey': exp.expectedKey,
            },
          ),
        );
      }
    }

    _activeExpectations.removeWhere((e) => e.status != EchoStatus.pending);
    _stopSweepTimerIfIdle();
  }

  void _recordEvent({
    required String actionName,
    required String correlationId,
    required SentinelDomain domain,
    required EchoStatus status,
    required int durationMs,
    required String details,
  }) {
    final event = SentinelEchoEvent(
      id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
      actionName: actionName,
      correlationId: correlationId,
      domain: domain,
      status: status,
      durationMs: durationMs,
      details: details,
      timestamp: DateTime.now(),
    );

    _history.add(event);
    if (_history.length > 100) {
      _history.removeAt(0);
    }
  }
}
