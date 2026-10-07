import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
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
  static String decrypt(String encryptedBase64, String passphrase) {
    try {
      final combined = base64Decode(encryptedBase64);
      if (combined.length <= 16) throw Exception('Invalid encrypted data format.');

      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);

      final key = _deriveKey(passphrase);
      final iv = enc.IV(ivBytes);
      
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      
      final encrypted = enc.Encrypted(cipherBytes);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Failed to decrypt data securely.');
    }
  }

  /// Derives a 32-byte key from the given passphrase using SHA-256.
  static enc.Key _deriveKey(String passphrase) {
    final bytes = utf8.encode(passphrase);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
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
      } catch (_) {}
    }

    // SEC-4 FIX: Do NOT fall back to hardcoded key.
    // Return masked placeholder so UI shows protected data, not raw ciphertext.
    return '••••••••';
  }
}
