import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the one-time migration of the legacy encryption fallback key
/// from source code into the device's secure keystore/keychain.
///
/// BACKGROUND:
/// Before the PBKDF2 upgrade, Gov IDs were encrypted with a hardcoded
/// key ('cozy_corner_secure_key_2026'). That key is needed to read old
/// records, but storing it in source is a security smell.
///
/// SOLUTION:
/// - On first app launch after this version: write the key into
///   flutter_secure_storage (Android Keystore / iOS Keychain).
/// - All subsequent reads come from secure storage, not source.
/// - Once all libraries have migrated their old records (re-saved via
///   edit student → save), the legacy key and this class can be removed.
class LegacyKeyMigrationService {
  // v11 default options: AES-GCM with RSA OAEP key wrapping, Android Keystore.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
    iOptions: IOSOptions.defaultOptions,
  );

  static const _legacyKeyStorageKey = 'cc_legacy_enc_key_v1';

  // Written once here; removed from source in the next major release
  // after all admins have re-saved their student records.
  // ignore: avoid_hardcoded_strings
  static const _legacyKeyValue = 'cozy_corner_secure_key_2026';

  /// Call once at app startup (after Firebase init).
  /// Safe to call repeatedly — writes only if key is not already stored.
  static Future<void> ensureMigrated() async {
    try {
      final existing = await _storage.read(key: _legacyKeyStorageKey);
      if (existing == null) {
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
      return await _storage.read(key: _legacyKeyStorageKey);
    } catch (_) {
      return null;
    }
  }
}
