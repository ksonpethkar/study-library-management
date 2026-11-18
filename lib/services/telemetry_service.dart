import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized telemetry and error monitoring service for Firebase Crashlytics.
/// Manages user identification, custom session metadata, and crash diagnostics.
class TelemetryService {
  TelemetryService._();

  static bool _initialized = false;

  /// Initializes Crashlytics hooks and standard environment metadata.
  static Future<void> initialize({
    String? appVersion,
    String? buildNumber,
  }) async {
    if (kIsWeb) {
      debugPrint('[Telemetry] Web platform active — Crashlytics mobile-only features disabled.');
      return;
    }

    try {
      // Catch all Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // Catch async unhandled errors
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Set standard device & environment metadata for triage filtering
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

      _initialized = true;
      debugPrint('[Telemetry] Crashlytics initialized successfully.');
    } catch (e) {
      debugPrint('[Telemetry] Error initializing Crashlytics: $e');
    }
  }

  /// Sets user context in Crashlytics when authenticated.
  static Future<void> setUser({
    required String uid,
    String? email,
    String? role,
    String? libraryId,
  }) async {
    if (kIsWeb || !_initialized) return;

    try {
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
    } catch (e) {
      debugPrint('[Telemetry] Failed to set user context: $e');
    }
  }

  /// Clears user context upon logout.
  static Future<void> clearUser() async {
    if (kIsWeb || !_initialized) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
      await FirebaseCrashlytics.instance.setCustomKey('user_email', '');
      await FirebaseCrashlytics.instance.setCustomKey('user_role', '');
    } catch (_) {}
  }

  /// Updates current active library context.
  static Future<void> setLibrary(String libraryId) async {
    if (kIsWeb || !_initialized) return;

    try {
      await FirebaseCrashlytics.instance.setCustomKey('current_library_id', libraryId);
    } catch (_) {}
  }

  /// Logs a custom breadcrumb to Crashlytics timeline.
  static void logBreadcrumb(String message) {
    if (kIsWeb || !_initialized) return;

    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }

  /// Records a non-fatal exception with custom reason and optional correlation ID.
  static Future<void> recordNonFatal(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    String? correlationId,
  }) async {
    if (kIsWeb || !_initialized) return;

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
  }
}
