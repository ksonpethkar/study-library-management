/// Severity level of a detected system anomaly or health issue.
enum SentinelSeverity {
  info,
  advisory,
  warning,
  critical,
}

/// Status of an Echo Verification SLA check.
enum EchoStatus {
  pending,
  passed,
  warning,
  failed,
}

/// Target domain of an action or entity monitored by Cozy Sentinel.
enum SentinelDomain {
  seats,
  students,
  payments,
  requests,
  settings,
  streams,
  cache,
  uiLifecycle,
}

/// Represents a detected discrepancy, invariant breach, or operational issue.
class SentinelAnomaly {
  final String id;
  final String title;
  final String description;
  final SentinelSeverity severity;
  final SentinelDomain domain;
  final String? entityId;
  final DateTime detectedAt;
  final bool canAutoHeal;
  final String? rootCauseDiagnosis;
  final String? remediationSuggestion;
  final Map<String, dynamic> metadata;

  const SentinelAnomaly({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.domain,
    this.entityId,
    required this.detectedAt,
    this.canAutoHeal = false,
    this.rootCauseDiagnosis,
    this.remediationSuggestion,
    this.metadata = const {},
  });

  SentinelAnomaly copyWith({
    String? id,
    String? title,
    String? description,
    SentinelSeverity? severity,
    SentinelDomain? domain,
    String? entityId,
    DateTime? detectedAt,
    bool? canAutoHeal,
    String? rootCauseDiagnosis,
    String? remediationSuggestion,
    Map<String, dynamic>? metadata,
  }) {
    return SentinelAnomaly(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      domain: domain ?? this.domain,
      entityId: entityId ?? this.entityId,
      detectedAt: detectedAt ?? this.detectedAt,
      canAutoHeal: canAutoHeal ?? this.canAutoHeal,
      rootCauseDiagnosis: rootCauseDiagnosis ?? this.rootCauseDiagnosis,
      remediationSuggestion: remediationSuggestion ?? this.remediationSuggestion,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Represents an active expectation registered when an action occurs.
/// The Echo Verifier expects an asynchronous state reflection within SLA (e.g. 2500ms).
class SentinelEchoExpectation {
  final String id;
  final String actionName;
  final String correlationId;
  final SentinelDomain domain;
  final String entityId;
  final String expectedKey;
  final dynamic expectedValue;
  final DateTime registeredAt;
  final Duration timeout;
  EchoStatus status;
  DateTime? resolvedAt;
  String? failureReason;

  SentinelEchoExpectation({
    required this.id,
    required this.actionName,
    required this.correlationId,
    required this.domain,
    required this.entityId,
    required this.expectedKey,
    this.expectedValue,
    required this.registeredAt,
    this.timeout = const Duration(milliseconds: 2500),
    this.status = EchoStatus.pending,
    this.resolvedAt,
    this.failureReason,
  });

  bool get isExpired =>
      status == EchoStatus.pending &&
      DateTime.now().difference(registeredAt) > timeout;

  int get elapsedMs =>
      (resolvedAt ?? DateTime.now()).difference(registeredAt).inMilliseconds;
}

/// Represents a historical echo verification log entry for real-time audit feeds.
class SentinelEchoEvent {
  final String id;
  final String actionName;
  final String correlationId;
  final SentinelDomain domain;
  final EchoStatus status;
  final int durationMs;
  final String details;
  final DateTime timestamp;

  const SentinelEchoEvent({
    required this.id,
    required this.actionName,
    required this.correlationId,
    required this.domain,
    required this.status,
    required this.durationMs,
    required this.details,
    required this.timestamp,
  });
}

/// Aggregated system health score and operational metrics.
class SentinelHealthMetrics {
  final double score; // 0.0 to 100.0
  final int activeWatchersCount;
  final int totalInvariantsChecked;
  final int criticalCount;
  final int warningCount;
  final int advisoryCount;
  final int averageStreamLatencyMs;
  final DateTime lastAuditTime;
  final bool isScanning;

  const SentinelHealthMetrics({
    this.score = 100.0,
    this.activeWatchersCount = 6,
    this.totalInvariantsChecked = 8,
    this.criticalCount = 0,
    this.warningCount = 0,
    this.advisoryCount = 0,
    this.averageStreamLatencyMs = 120,
    required this.lastAuditTime,
    this.isScanning = false,
  });

  bool get isHealthy => score >= 90.0 && criticalCount == 0;
  bool get hasWarnings => warningCount > 0 || criticalCount > 0;

  String get statusText {
    if (score >= 95.0) return 'EXCELLENT';
    if (score >= 85.0) return 'HEALTHY';
    if (score >= 70.0) return 'DEGRADED';
    return 'CRITICAL ATTENTION';
  }
}
