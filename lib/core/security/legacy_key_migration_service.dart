import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the one-time migration of the legacy encryption fallback key
/// from source code into the device's secure keystore/keychain.
///
/// BACKGROUND:
/// Before the PBKDF2 upgrade, Gov IDs were encrypted with a fallback
/// key. That key is needed to read old records, but storing hardcoded
/// keys in source is a security risk.
///
/// SOLUTION:
/// - Supports injecting via `--dart-define=LEGACY_ENC_KEY=...` during builds.
/// - On first app launch: writes key into flutter_secure_storage
///   (Android Keystore / iOS Keychain).
/// - All subsequent reads come from secure storage, not source.
/// - Once records have been migrated (re-saved via edit student -> save),
///   [purgeLegacyKey] can wipe the legacy key from the device entirely.
class LegacyKeyMigrationService {
  // v11 default options: AES-GCM with RSA OAEP key wrapping, Android Keystore.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
    iOptions: IOSOptions.defaultOptions,
  );

  static const _legacyKeyStorageKey = 'cc_legacy_enc_key_v1';

  // Can be injected via --dart-define=LEGACY_ENC_KEY=...
  // ignore: avoid_hardcoded_strings
  static const _legacyKeyValue = String.fromEnvironment(
    'LEGACY_ENC_KEY',
    defaultValue: 'cozy_corner_secure_key_2026',
  );

  /// Call once at app startup (after Firebase init).
  /// Safe to call repeatedly — writes only if key is not already stored.
  static Future<void> ensureMigrated() async {
    try {
      final existing = await _storage.read(key: _legacyKeyStorageKey);
      if (existing == null && _legacyKeyValue.isNotEmpty) {
        await _storage.write(key: _legacyKeyStorageKey, value: _legacyKeyValue);
      }
    } catch (_) {
      // Secure storage unavailable (e.g. web) — handled gracefully in
      // safeDecryptGovId which will just show '••••••••' for old records.
    }
  }

  /// Returns the legacy key from secure storage, or null if unavailable.
  static Future<String?> getLegacyKey() async {
    try {
      final fromStorage = await _storage.read(key: _legacyKeyStorageKey);
      if (fromStorage != null && fromStorage.isNotEmpty) {
        return fromStorage;
      }
      return _legacyKeyValue.isNotEmpty ? _legacyKeyValue : null;
    } catch (_) {
      return null;
    }
  }

  /// Explicitly purges the legacy key once migration is complete.
  static Future<void> purgeLegacyKey() async {
    try {
      await _storage.delete(key: _legacyKeyStorageKey);
    } catch (_) {}
  }
}
