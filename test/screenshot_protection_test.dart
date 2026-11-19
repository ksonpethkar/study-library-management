import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Protection Admin Persistence & Anti-Auto-On Invariants', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Fresh install without admin config defaults to enabled (safe fallback)', () async {
      final isEnabled = await isScreenshotProtectionEnabled();
      expect(isEnabled, isTrue, reason: 'Out-of-the-box fresh install defaults to enabled before admin choice');
    });

    test('2. When admin turns OFF screenshot protection, admin_disabled flag is set to true', () async {
      await setScreenshotProtectionEnabled(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('screenshot_protection_global'), isFalse);
      expect(prefs.getBool('screenshot_protection_configured'), isTrue);
      expect(prefs.getBool('screenshot_protection_admin_disabled'), isTrue);

      final isEnabled = await isScreenshotProtectionEnabled();
      expect(isEnabled, isFalse, reason: 'Admin turned off protection, so it must be disabled');
    });

    test('3. App update simulation: When admin previously disabled, auto-on is PREVENTED', () async {
      // Step 1: Admin sets protection to OFF
      await setScreenshotProtectionEnabled(false);

      // Step 2: Simulate app update where transient keys or fresh defaults are queried
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('screenshot_protection_admin_disabled'), isTrue);

      // Querying setting on updated app MUST NOT auto-turn on
      final isEnabledAfterUpdate = await isScreenshotProtectionEnabled();
      expect(isEnabledAfterUpdate, isFalse, reason: 'Must remain OFF after app updates because admin explicitly disabled it');
    });

    test('4. When admin turns ON screenshot protection, admin_disabled lock is released', () async {
      // Admin turns OFF
      await setScreenshotProtectionEnabled(false);
      expect(await isScreenshotProtectionEnabled(), isFalse);

      // Admin turns back ON
      await setScreenshotProtectionEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('screenshot_protection_global'), isTrue);
      expect(prefs.getBool('screenshot_protection_configured'), isTrue);
      expect(prefs.getBool('screenshot_protection_admin_disabled'), isFalse);

      expect(await isScreenshotProtectionEnabled(), isTrue);
    });

    test('5. Cloud restore schema restores admin OFF decision into local storage', () async {
      final prefs = await SharedPreferences.getInstance();

      // Cloud document has adminDisabled: true or screenshotProtectionEnabled: false
      final cloudData = {
        'screenshotProtectionEnabled': false,
        'screenshotProtectionAdminDisabled': true,
        'screenshotProtectionConfigured': true,
      };

      if (cloudData.containsKey('screenshotProtectionEnabled') &&
          cloudData['screenshotProtectionEnabled'] is bool) {
        final screenshotEnabled = cloudData['screenshotProtectionEnabled'] as bool;
        final adminDisabled = cloudData['screenshotProtectionAdminDisabled'] == true || !screenshotEnabled;
        await prefs.setBool('screenshot_protection_global', screenshotEnabled);
        await prefs.setBool('screenshot_protection_configured', true);
        await prefs.setBool('screenshot_protection_admin_disabled', adminDisabled);
      }

      expect(await isScreenshotProtectionEnabled(), isFalse);
      expect(prefs.getBool('screenshot_protection_admin_disabled'), isTrue);
    });
  });
}
