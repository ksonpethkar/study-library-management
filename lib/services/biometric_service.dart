import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static const String _keyBiometricEnabled = 'security_biometric_enabled';
  static const String _keyPinHash = 'security_pin_hash';
  static const String _keyAutoLockMinutes = 'security_auto_lock_minutes';

  static DateTime? _lastPausedTime;
  static bool _isCurrentlyLocked = false;

  /// Check if hardware supports biometric (fingerprint/face)
  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Trigger biometric authentication prompt
  static Future<bool> authenticate({
    String reason = 'Scan fingerprint or Face ID to unlock Cozy Corner',
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable' || e.code == 'PasscodeNotSet') {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if user has turned on biometric toggle in settings
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Set biometric toggle
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  /// Check if user has set a master 4-digit PIN
  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Verify entered PIN against stored SHA-256 hash
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_keyPinHash);
    if (storedHash == null) return false;

    final inputHash = sha256.convert(utf8.encode(pin)).toString();
    return storedHash == inputHash;
  }

  /// Set new master 4-digit PIN
  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await prefs.setString(_keyPinHash, hash);
  }

  /// Remove master PIN
  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
  }

  /// Is any security lock enabled (either biometric or PIN)?
  static Future<bool> isLockEnabled() async {
    final bio = await isBiometricEnabled();
    final pin = await hasPin();
    return bio || pin;
  }

  /// Auto-lock timeout in minutes (default 2 mins)
  static Future<int> getAutoLockTimeoutMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAutoLockMinutes) ?? 2;
  }

  static Future<void> setAutoLockTimeoutMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoLockMinutes, minutes);
  }

  /// Called when app goes into background
  static void onAppPaused() {
    _lastPausedTime = DateTime.now();
  }

  /// Called when app resumes: returns true if app should navigate to lock screen
  static Future<bool> shouldLockOnResume() async {
    if (_isCurrentlyLocked) return false;
    final enabled = await isLockEnabled();
    if (!enabled) return false;

    if (_lastPausedTime == null) return false;

    final timeoutMinutes = await getAutoLockTimeoutMinutes();
    final difference = DateTime.now().difference(_lastPausedTime!);

    if (difference.inMinutes >= timeoutMinutes) {
      _isCurrentlyLocked = true;
      return true;
    }
    return false;
  }

  /// Marks app as unlocked
  static void markUnlocked() {
    _lastPausedTime = null;
    _isCurrentlyLocked = false;
  }

  // ── Rate Limiting (5 failed attempts -> 15 min cooldown) ───────────────────
  static const String _keyFailedAttempts = 'security_failed_attempts';
  static const String _keyLockoutUntil = 'security_lockout_until';
  static const int maxFailedAttempts = 5;
  static const int lockoutMinutes = 15;

  /// Get current number of consecutive failed attempts
  static Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFailedAttempts) ?? 0;
  }

  /// Check if the user is currently in a 15-minute lockout
  static Future<DateTime?> getLockoutUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLockoutUntil);
    if (raw == null) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    if (DateTime.now().isAfter(dt)) {
      // Cooldown expired — reset cleanly
      await resetFailedAttempts();
      return null;
    }
    return dt;
  }

  /// Record a failed PIN or biometric attempt.
  /// Returns the lockout expiry if locked out, or null if attempts remain.
  static Future<DateTime?> recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    int attempts = (prefs.getInt(_keyFailedAttempts) ?? 0) + 1;
    await prefs.setInt(_keyFailedAttempts, attempts);

    if (attempts >= maxFailedAttempts) {
      final lockoutUntil = DateTime.now().add(const Duration(minutes: lockoutMinutes));
      await prefs.setString(_keyLockoutUntil, lockoutUntil.toIso8601String());
      return lockoutUntil;
    }
    return null;
  }

  /// Reset failed attempts and clear lockout on successful authentication
  static Future<void> resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFailedAttempts);
    await prefs.remove(_keyLockoutUntil);
  }
}
