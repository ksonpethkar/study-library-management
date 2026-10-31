import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
import 'firebase_options.dart';
import 'package:study_library/core/utils/url_strategy_helper.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrlStrategy();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Activate Firebase App Check
  if (kIsWeb) {
    // 100% FREE solution: Only activates on web when a custom key is passed via --dart-define=RECAPTCHA_V3_KEY=...
    // Otherwise runs seamlessly with zero configuration, zero billing, and zero console errors.
    const recaptchaV3SiteKey = String.fromEnvironment('RECAPTCHA_V3_KEY', defaultValue: '');
    if (recaptchaV3SiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(recaptchaV3SiteKey),
      );
    }
  } else {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(),
    );

    // Crashlytics: catch all Flutter framework errors
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Crashlytics: catch async errors not caught by Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Initialize Remote Config
  await RemoteConfigService.initialize();

  // Analytics: enable data collection
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  // Enable Firestore offline persistence
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Initialize push notifications & local schedulers on mobile
  if (!kIsWeb) {
    await NotificationService.initialize();
    await BadgeService.initialize();
    await ExpirySchedulerService.initialize();
    // SEC-4: Migrate legacy encryption key from source → device secure storage.
    // On first launch: writes key to Android Keystore / iOS Keychain.
    // On subsequent launches: reads from secure storage only (no hardcoded key).
    await LegacyKeyMigrationService.ensureMigrated();
    final legacyKey = await LegacyKeyMigrationService.getLegacyKey();
    EncryptionService.setLegacyKey(legacyKey);
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const StudyLibraryApp(),
    ),
  );
}
