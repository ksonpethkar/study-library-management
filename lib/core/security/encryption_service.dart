import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  /// In-memory cache of the legacy migration key, loaded at startup
  /// by [setLegacyKey]. Never hardcoded in this file after initial migration.
  static String? _cachedLegacyKey;

  /// Called once at app startup (after [LegacyKeyMigrationService.ensureMigrated]).
  /// Stores the legacy key in memory so [safeDecryptGovId] works synchronously.
  static void setLegacyKey(String? key) => _cachedLegacyKey = key;
  /// Encrypts plaintext using AES-256 with a key derived from a passphrase.
  /// Generates a random IV, prepends it to the ciphertext, and returns base64.
  static String encrypt(String plainText, String passphrase) {
    try {
      final key = _deriveKey(passphrase);
      final iv = enc.IV.fromSecureRandom(16);
      
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      
      // Combine IV and ciphertext for storage
      final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
      combined.setAll(0, iv.bytes);
      combined.setAll(iv.bytes.length, encrypted.bytes);
      
      return base64Encode(combined);
    } catch (e) {
      throw Exception('Failed to encrypt data securely. Please try again.');
    }
  }

  /// Decrypts base64 encoded text containing IV + ciphertext.
  /// Tries PBKDF2-derived key first; if that fails, falls back to legacy
  /// SHA-256 key for data encrypted before the KDF upgrade.
  static String decrypt(String encryptedBase64, String passphrase) {
    try {
      final combined = base64Decode(encryptedBase64);
      if (combined.length <= 16) throw Exception('Invalid encrypted data format.');

      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);
      final iv = enc.IV(ivBytes);
      final encrypted = enc.Encrypted(cipherBytes);

      // Try PBKDF2 key first (new standard)
      try {
        final key = _deriveKey(passphrase);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
        return encrypter.decrypt(encrypted, iv: iv);
      } catch (_) { /* intentionally silent — try legacy */ }

      // Fall back to legacy SHA-256 key (for pre-upgrade data)
      final legacyKey = _deriveKeyLegacy(passphrase);
      final legacyEncrypter = enc.Encrypter(enc.AES(legacyKey, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      return legacyEncrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Failed to decrypt data securely.');
    }
  }

  /// Derives a 32-byte key using PBKDF2-HMAC-SHA256 (100K iterations).
  /// OWASP-recommended key derivation for brute-force resistance.
  static enc.Key _deriveKey(String passphrase) {
    final passphraseBytes = utf8.encode(passphrase);
    // Deterministic salt (same passphrase → same key for decryption compatibility)
    final salt = sha256.convert(utf8.encode('study_library_kdf_salt_$passphrase')).bytes;
    final derivedKey = _pbkdf2(passphraseBytes, salt, 100000, 32);
    return enc.Key(Uint8List.fromList(derivedKey));
  }

  /// Legacy key derivation (simple SHA-256) — used ONLY for decrypting
  /// data that was encrypted before the PBKDF2 upgrade.
  static enc.Key _deriveKeyLegacy(String passphrase) {
    final bytes = utf8.encode(passphrase);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// PBKDF2 implementation using HMAC-SHA256.
  static List<int> _pbkdf2(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final numBlocks = (keyLength / 32).ceil();
    final result = <int>[];

    for (var i = 1; i <= numBlocks; i++) {
      final blockSalt = [...salt, (i >> 24) & 0xff, (i >> 16) & 0xff, (i >> 8) & 0xff, i & 0xff];
      var u = hmac.convert(blockSalt).bytes;
      var xorResult = List<int>.from(u);

      for (var j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < xorResult.length; k++) {
          xorResult[k] ^= u[k];
        }
      }
      result.addAll(xorResult);
    }

    return result.sublist(0, keyLength);
  }

  /// Encrypts a government ID (Aadhaar, PAN) using the provided appSecret.
  /// SEC-4 FIX: No hardcoded fallback key. If appSecret is empty, throws
  /// immediately — fails safe rather than using a publicly-known key.
  static String encryptGovId(String govId, String appSecret) {
    if (appSecret.isEmpty) {
      throw Exception('Encryption key not available. Cannot encrypt sensitive ID.');
    }
    return encrypt(govId, appSecret);
  }

  /// Decrypts a government ID using the provided appSecret.
  /// SEC-4 FIX: No hardcoded fallback key. Returns empty string if key not
  /// available so the UI shows a masked field rather than exposing plaintext.
  static String decryptGovId(String encryptedGovId, String appSecret) {
    if (appSecret.isEmpty) return '';
    return decrypt(encryptedGovId, appSecret);
  }

  /// Safely decrypts a government ID, returning masked value on failure.
  /// SEC-4 FIX: Removed hardcoded 'cozy_corner_secure_key_2026' fallback.
  /// If decryption fails, returns '••••••••' to indicate data is protected.
  static String safeDecryptGovId(String value, String appSecret) {
    if (value.isEmpty) return '';
    
    // If value is already plaintext (standard Aadhaar or PAN format)
    final clean = value.replaceAll(' ', '');
    if (RegExp(r'^\d{12}$').hasMatch(clean) ||
        RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(clean)) {
      return value;
    }

    // Try decrypting with the provided appSecret (library ID or Remote Config key)
    if (appSecret.isNotEmpty) {
      try {
        final decrypted = decrypt(value, appSecret);
        if (decrypted.isNotEmpty) return decrypted;
      } catch (_) { /* intentionally silent */ }
    }

    // Fall back to legacy key (loaded from device secure storage at startup,
    // never hardcoded here — see LegacyKeyMigrationService).
    if (_cachedLegacyKey != null && _cachedLegacyKey!.isNotEmpty) {
      try {
        final decrypted = decrypt(value, _cachedLegacyKey!);
        if (decrypted.isNotEmpty) return decrypted;
      } catch (_) { /* intentionally silent */ }
    }

    // SEC-4: Return masked placeholder so UI never exposes raw base64 ciphertext
    return '••••••••';
  }
}
