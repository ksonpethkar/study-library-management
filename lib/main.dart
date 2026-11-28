import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/services/notification_service.dart';
import 'package:study_library/services/badge_service.dart';
import 'package:study_library/services/expiry_scheduler_service.dart';
import 'package:study_library/services/remote_config_service.dart';
import 'package:study_library/core/security/legacy_key_migration_service.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/services/telemetry_service.dart';
import 'package:study_library/core/constants/app_constants.dart';
import 'package:study_library/core/sentinel/sentinel_provider_observer.dart';
import 'package:study_library/core/sentinel/sentinel_service.dart';
import 'firebase_options.dart';
import 'package:study_library/core/utils/url_strategy_helper.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrlStrategy();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence synchronously before first query
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('[Firestore] Persistence config note: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  // Schedule non-blocking post-frame initialization so Frame #1 renders immediately
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeDeferredServices());
  });

  runApp(
    ProviderScope(
      observers: [
        SentinelProviderObserver(),
      ],
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const StudyLibraryApp(),
    ),
  );
}

Future<void> _initializeDeferredServices() async {
  // Activate Firebase App Check
  try {
    if (kIsWeb) {
      const recaptchaV3SiteKey = String.fromEnvironment('RECAPTCHA_V3_KEY', defaultValue: '');
      if (recaptchaV3SiteKey.isNotEmpty) {
        await FirebaseAppCheck.instance.activate(
          providerWeb: ReCaptchaV3Provider(recaptchaV3SiteKey),
        );
      } else if (kDebugMode) {
        debugPrint('[Security Notice] App Check Web is inactive. Pass --dart-define=RECAPTCHA_V3_KEY=... for production protection.');
      }
    } else {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
      );
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[AppCheck] Deferred init note: $e');
  }

  // Initialize Crashlytics telemetry, Remote Config, and Analytics concurrently
  await Future.wait([
    TelemetryService.initialize(
      appVersion: AppConstants.appVersion,
      buildNumber: '${AppConstants.buildNumber}',
    ).catchError((_) {}),
    RemoteConfigService.initialize(waitForFetch: false).catchError((_) {}),
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true).catchError((_) {}),
  ]);

  // Initialize push notifications, badges, schedulers & key migration on mobile
  if (!kIsWeb) {
    await Future.wait([
      NotificationService.initialize().catchError((_) {}),
      BadgeService.initialize().catchError((_) {}),
      ExpirySchedulerService.initialize().catchError((_) {}),
      LegacyKeyMigrationService.ensureMigrated().then((_) async {
        final legacyKey = await LegacyKeyMigrationService.getLegacyKey();
        EncryptionService.setLegacyKey(legacyKey);
      }).catchError((_) {}),
    ]);
  }

  // Initialize Cozy Sentinel Autonomous Quality Guardian
  SentinelService.instance.startMonitoring();
}
