import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:study_library/core/sentinel/sentinel_models.dart';
import 'package:study_library/core/sentinel/sentinel_service.dart';
import 'package:study_library/core/utils/structured_logger.dart';

/// Centralized telemetry and error monitoring service for Firebase Crashlytics & Cozy Sentinel.
/// Manages user identification, custom session metadata, crash diagnostics, and real-time error boundaries
/// across both Mobile (native Crashlytics) and Web (Structured Telemetry & Sentinel Anomaly stream).
class TelemetryService {
  TelemetryService._();

  static bool _initialized = false;

  /// Initializes Crashlytics hooks and standard environment metadata across mobile and web.
  static Future<void> initialize({
    String? appVersion,
    String? buildNumber,
  }) async {
    try {
      // 1. Catch all Flutter framework errors (both Mobile and Web)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        if (!kIsWeb) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } else {
          StructuredLogger.log(
            'Flutter Framework Error: ${details.exceptionAsString()}',
            level: LogLevel.error,
            tag: 'TelemetryWeb',
            data: {
              'stack': details.stack?.toString(),
              'context': details.context?.toString(),
              'library': details.library,
            },
          );
          // Real-time dispatch into Cozy Sentinel
          SentinelService.instance.reportAnomaly(
            SentinelAnomaly(
              id: 'web_runtime_err_${details.exception.hashCode}',
              title: 'UI Framework Exception (Web)',
              description: details.exceptionAsString(),
              severity: SentinelSeverity.warning,
              domain: SentinelDomain.uiLifecycle,
              detectedAt: DateTime.now(),
              rootCauseDiagnosis: 'Unhandled Flutter framework exception on Web platform.',
              remediationSuggestion: 'Inspect browser console or StructuredLogger telemetry.',
              metadata: {
                'exception': details.exceptionAsString(),
                'platform': 'web',
              },
            ),
          );
        }
      };

      // 2. Catch async unhandled platform errors (both Mobile and Web)
      PlatformDispatcher.instance.onError = (error, stack) {
        if (!kIsWeb) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } else {
          StructuredLogger.log(
            'Async Unhandled Error: $error',
            level: LogLevel.error,
            tag: 'TelemetryWeb',
            data: {'stack': stack.toString()},
          );
          SentinelService.instance.reportAnomaly(
            SentinelAnomaly(
              id: 'web_async_err_${error.hashCode}',
              title: 'Async Runtime Failure (Web)',
              description: error.toString(),
              severity: SentinelSeverity.critical,
              domain: SentinelDomain.streams,
              detectedAt: DateTime.now(),
              rootCauseDiagnosis: 'Unhandled asynchronous platform exception.',
              remediationSuggestion: 'Check network stream providers or async future handlers.',
              metadata: {
                'error': error.toString(),
                'platform': 'web',
              },
            ),
          );
        }
        return true;
      };

      if (!kIsWeb) {
        // Set standard device & environment metadata for triage filtering in Firebase Crashlytics
        await FirebaseCrashlytics.instance.setCustomKey(
          'environment',
          kReleaseMode ? 'production' : (kProfileMode ? 'profile' : 'development'),
        );
        if (appVersion != null) {
          await FirebaseCrashlytics.instance.setCustomKey('app_version', appVersion);
        }
        if (buildNumber != null) {
          await FirebaseCrashlytics.instance.setCustomKey('build_number', buildNumber);
        }
        await FirebaseCrashlytics.instance.setCustomKey('platform', defaultTargetPlatform.name);
      }

      _initialized = true;
      debugPrint('[Telemetry] Real-time Error Boundary & Crashlytics initialized successfully on ${kIsWeb ? "Web" : defaultTargetPlatform.name}.');
    } catch (e) {
      debugPrint('[Telemetry] Error initializing TelemetryService: $e');
    }
  }

  /// Sets user context in Crashlytics and telemetry when authenticated.
  static Future<void> setUser({
    required String uid,
    String? email,
    String? role,
    String? libraryId,
  }) async {
    if (!_initialized) return;

    try {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setUserIdentifier(uid);
        if (email != null && email.isNotEmpty) {
          await FirebaseCrashlytics.instance.setCustomKey('user_email', email);
        }
        if (role != null && role.isNotEmpty) {
          await FirebaseCrashlytics.instance.setCustomKey('user_role', role);
        }
        if (libraryId != null && libraryId.isNotEmpty) {
          await FirebaseCrashlytics.instance.setCustomKey('current_library_id', libraryId);
        }
      } else {
        StructuredLogger.log(
          'Active Telemetry User Context Set',
          level: LogLevel.info,
          tag: 'Telemetry',
          data: {
            'uid': uid,
            'email': email,
            'role': role,
            'libraryId': libraryId,
          },
        );
      }
    } catch (e) {
      debugPrint('[Telemetry] Failed to set user context: $e');
    }
  }

  /// Clears user context upon logout.
  static Future<void> clearUser() async {
    if (!_initialized) return;

    try {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setUserIdentifier('');
        await FirebaseCrashlytics.instance.setCustomKey('user_email', '');
        await FirebaseCrashlytics.instance.setCustomKey('user_role', '');
      }
    } catch (_) {}
  }

  /// Updates current active library context.
  static Future<void> setLibrary(String libraryId) async {
    if (!_initialized) return;

    try {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setCustomKey('current_library_id', libraryId);
      }
    } catch (_) {}
  }

  /// Logs a custom breadcrumb to Crashlytics timeline and structured telemetry.
  static void logBreadcrumb(String message) {
    if (!kIsWeb && _initialized) {
      FirebaseCrashlytics.instance.log(message);
    } else {
      StructuredLogger.log(message, level: LogLevel.info, tag: 'Breadcrumb');
    }
  }

  /// Records a non-fatal caught exception with optional diagnostics.
  static void recordError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    if (!kIsWeb && _initialized) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } else {
      StructuredLogger.log(
        reason ?? 'Caught Exception',
        level: fatal ? LogLevel.error : LogLevel.warning,
        tag: 'Telemetry',
        data: {'error': error.toString(), 'stack': stack?.toString()},
      );
    }
  }

  /// Records a non-fatal exception with custom reason and optional correlation ID.
  static Future<void> recordNonFatal(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    String? correlationId,
  }) async {
    if (!kIsWeb && _initialized) {
      try {
        if (correlationId != null) {
          await FirebaseCrashlytics.instance.setCustomKey('last_correlation_id', correlationId);
        }
        await FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: reason ?? 'Handled non-fatal exception',
          fatal: false,
        );
      } catch (_) {}
    } else {
      StructuredLogger.log(
        reason ?? 'Handled non-fatal exception',
        level: LogLevel.warning,
        tag: 'Telemetry',
        correlationId: correlationId,
        data: {'error': error.toString(), 'stack': stack?.toString()},
      );
    }
  }
}
