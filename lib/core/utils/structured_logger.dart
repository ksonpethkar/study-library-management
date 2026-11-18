import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../security/audit_logger.dart';

enum LogLevel { debug, info, warning, error }

/// Structured logger with correlation ID tracking across async operations.
/// Helps trace user actions, API calls, and errors from initiation to resolution.
class StructuredLogger {
  StructuredLogger._();

  static const _uuid = Uuid();
  static final _auditLogger = AuditLogger();

  // Zone key for storing ambient correlation ID in the current execution zone.
  static final _zoneKey = Object();

  /// Generates a new unique correlation ID (e.g. `req_e3b8a1c9...`).
  static String newCorrelationId([String prefix = 'trace']) {
    return '${prefix}_${_uuid.v4().replaceAll('-', '').substring(0, 16)}';
  }

  /// Returns the ambient correlation ID for the current execution context,
  /// or generates a new one if not inside a [runWithCorrelationId] zone.
  static String get currentCorrelationId {
    final ambient = Zone.current[_zoneKey];
    if (ambient is String && ambient.isNotEmpty) {
      return ambient;
    }
    return newCorrelationId();
  }

  /// Executes [action] in an asynchronous zone where [correlationId] is ambient.
  /// Any nested calls to [currentCorrelationId] or logger methods will automatically
  /// inherit this correlation ID.
  static Future<T> runWithCorrelationId<T>(
    String correlationId,
    Future<T> Function() action,
  ) {
    return runZoned(
      action,
      zoneValues: {_zoneKey: correlationId},
    );
  }

  /// Logs a structured message with correlation ID, tags, and parameters.
  static void log(
    String message, {
    LogLevel level = LogLevel.info,
    String? correlationId,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    final cid = correlationId ?? currentCorrelationId;
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';

    if (kDebugMode) {
      debugPrint('[$timestamp] [${level.name.toUpperCase()}] [CID:$cid] $tagStr$message ${data != null ? data.toString() : ""}');
    }

    // Mirror to Crashlytics breadcrumbs on mobile platforms
    if (!kIsWeb) {
      try {
        FirebaseCrashlytics.instance.log('[${level.name.toUpperCase()}] [CID:$cid] $tagStr$message');
      } catch (_) {}
    }
  }

  /// Logs informational events.
  static void info(String message, {String? tag, Map<String, dynamic>? data, String? correlationId}) {
    log(message, level: LogLevel.info, tag: tag, data: data, correlationId: correlationId);
  }

  /// Logs warnings.
  static void warning(String message, {String? tag, Map<String, dynamic>? data, String? correlationId}) {
    log(message, level: LogLevel.warning, tag: tag, data: data, correlationId: correlationId);
  }

  /// Logs an error with stack trace and correlation ID.
  /// Automatically tags Crashlytics on mobile devices.
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
    String? correlationId,
    Map<String, dynamic>? data,
    bool fatal = false,
  }) {
    final cid = correlationId ?? currentCorrelationId;
    log(message, level: LogLevel.error, correlationId: cid, tag: tag, data: data);

    if (kDebugMode && error != null) {
      debugPrint('[CID:$cid] Error detail: $error');
      if (stackTrace != null) debugPrint('[CID:$cid] Stack: $stackTrace');
    }

    if (!kIsWeb && error != null) {
      try {
        FirebaseCrashlytics.instance.setCustomKey('last_correlation_id', cid);
        if (tag != null) FirebaseCrashlytics.instance.setCustomKey('last_error_tag', tag);
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: '[$cid] $message',
          fatal: fatal,
        );
      } catch (_) {}
    }
  }

  /// Bridge to persist critical operations directly to Firestore Audit Log
  /// with matching correlation ID.
  static Future<void> audit({
    required AuditAction action,
    required AuditEntity entityType,
    String? libraryId,
    String? entityId,
    String? entityName,
    String? correlationId,
    Map<String, dynamic>? details,
  }) {
    final cid = correlationId ?? currentCorrelationId;
    return _auditLogger.log(
      action: action,
      entityType: entityType,
      libraryId: libraryId,
      entityId: entityId,
      entityName: entityName,
      correlationId: cid,
      details: details,
    );
  }
}
