import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mixin that prevents screenshots and screen recording on sensitive screens.
/// Apply to State classes that show ID cards, receipts, or payment info.
///
/// Behaviour:
///   - Checks SharedPreferences for 'screenshot_protection_global' and
///     'screenshot_protection_admin_disabled'.
///   - If the admin turned off protection, screenshots are PERMANENTLY allowed
///     and WILL NOT be re-enabled automatically across app updates or launches.
///   - If the global setting is on, this mixin enforces FLAG_SECURE for the screen.
///
/// Usage:
///   `class _MyScreenState extends State<MyScreen> with SecureScreenMixin {`
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  static const _channel = MethodChannel('study_library/secure_screen');

  /// If true, this screen enforces screenshot protection regardless of
  /// per-screen overrides (only the global toggle can turn it off).
  bool get isMandatorySecureScreen => false;

  @override
  void initState() {
    super.initState();
    _applySecureFlag();
  }

  @override
  void dispose() {
    _restoreGlobalSecureFlag();
    super.dispose();
  }

  Future<void> _restoreGlobalSecureFlag() async {
    final globalEnabled = await isScreenshotProtectionEnabled();
    _setSecure(globalEnabled);
  }

  Future<void> _applySecureFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Priority 1: Did the admin explicitly turn OFF screenshot protection?
      // If yes, NEVER auto-enable it under any circumstances (including updates).
      final adminDisabled = prefs.getBool('screenshot_protection_admin_disabled') ?? false;
      if (adminDisabled) {
        _setSecure(false);
        return;
      }

      // Priority 2: Has the admin explicitly configured a preference?
      final isConfigured = prefs.getBool('screenshot_protection_configured') ?? false;
      if (isConfigured) {
        final globalEnabled = prefs.getBool('screenshot_protection_global') ?? false;
        _setSecure(globalEnabled);
        return;
      }

      // Priority 3: Fallback check from cached library setting
      final cachedLibId = prefs.getString('cached_current_library_id');
      if (cachedLibId != null && cachedLibId.isNotEmpty) {
        final cloudSetting = await loadScreenshotProtectionFromFirestore(cachedLibId);
        _setSecure(cloudSetting);
        return;
      }

      // Default: Initial fresh install before any admin configuration
      final globalEnabled = prefs.getBool('screenshot_protection_global') ?? true;
      _setSecure(globalEnabled);
    } catch (_) {
      // In case of error, do not block screenshots if admin previously disabled
      _setSecure(false);
    }
  }

  Future<void> _setSecure(bool secure) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setSecureFlag', {'secure': secure});
    } catch (_) {
      // Graceful fallback — security feature only
    }
  }

  /// Call this when the global screenshot protection setting changes
  /// so the current screen updates without needing a rebuild.
  void refreshSecureFlag() => _applySecureFlag();
}

/// Saves the global screenshot protection preference.
/// Called from Security Settings dialog.
Future<void> setScreenshotProtectionEnabled(bool enabled, {String? libraryId}) async {
  final prefs = await SharedPreferences.getInstance();

  // Save explicit user preference
  await prefs.setBool('screenshot_protection_global', enabled);
  await prefs.setBool('screenshot_protection_configured', true);

  // If disabled by admin, set persistent lock to prevent auto-re-enabling on app updates
  await prefs.setBool('screenshot_protection_admin_disabled', !enabled);

  // Apply immediately to Android window
  if (!kIsWeb && Platform.isAndroid) {
    try {
      const MethodChannel('study_library/secure_screen')
          .invokeMethod('setSecureFlag', {'secure': enabled});
    } catch (_) {}
  }

  // Sync to Firestore for cloud persistence across devices and reinstalls
  if (libraryId != null && libraryId.isNotEmpty) {
    await syncScreenshotProtectionToFirestore(libraryId, enabled);
  }
}

/// Reads current global screenshot protection preference.
/// Strictly respects admin's decision to disable protection.
Future<bool> isScreenshotProtectionEnabled({String? libraryId}) async {
  final prefs = await SharedPreferences.getInstance();

  // 1. If admin explicitly disabled protection, it must stay OFF
  final adminDisabled = prefs.getBool('screenshot_protection_admin_disabled') ?? false;
  if (adminDisabled) {
    return false;
  }

  // 2. If configured locally, return the exact stored value
  final isConfigured = prefs.getBool('screenshot_protection_configured') ?? false;
  if (isConfigured && prefs.containsKey('screenshot_protection_global')) {
    return prefs.getBool('screenshot_protection_global') ?? false;
  }

  // 3. If libraryId is available, load authoritative setting from cloud
  if (libraryId != null && libraryId.isNotEmpty) {
    return await loadScreenshotProtectionFromFirestore(libraryId);
  }

  // 4. Default for unconfigured initial setup
  return prefs.getBool('screenshot_protection_global') ?? true;
}

/// Helper to sync screenshot protection setting to Firestore.
Future<void> syncScreenshotProtectionToFirestore(
    String libraryId, bool enabled) async {
  if (libraryId.isEmpty) return;
  try {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Write to libraries/{id}/settings/security
    final securityDoc = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('security');
    batch.set(securityDoc, {
      'screenshotProtectionEnabled': enabled,
      'screenshotProtectionConfigured': true,
      'screenshotProtectionAdminDisabled': !enabled,
      'screenshotProtectionUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Also write to libraries/{id} root doc so real-time listeners react immediately
    final libDoc = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId);
    batch.set(libDoc, {
      'screenshotProtectionEnabled': enabled,
    }, SetOptions(merge: true));

    await batch.commit();
  } catch (e) {
    if (kDebugMode) debugPrint('[Security] Failed to sync screenshot protection to Firestore: $e');
  }
}

/// Applies or removes Android window FLAG_SECURE natively.
Future<void> applyNativeSecureFlag(bool enabled) async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    const MethodChannel('study_library/secure_screen')
        .invokeMethod('setSecureFlag', {'secure': enabled});
  } catch (_) {}
}

/// Helper to load screenshot protection setting from Firestore and persist locally.
Future<bool> loadScreenshotProtectionFromFirestore(String libraryId) async {
  if (libraryId.isEmpty) return true;
  try {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try reading from libraries/{id}/settings/security
    final doc = await FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('security')
        .get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data.containsKey('screenshotProtectionEnabled') &&
          data['screenshotProtectionEnabled'] is bool) {
        final enabled = data['screenshotProtectionEnabled'] as bool;
        await prefs.setBool('screenshot_protection_global', enabled);
        await prefs.setBool('screenshot_protection_configured', true);
        await prefs.setBool('screenshot_protection_admin_disabled', !enabled);
        await applyNativeSecureFlag(enabled);
        return enabled;
      }
    }

    // 2. Fallback: try reading directly from libraries/{id}
    final libDoc = await FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .get();

    if (libDoc.exists && libDoc.data() != null) {
      final data = libDoc.data()!;
      if (data.containsKey('screenshotProtectionEnabled') &&
          data['screenshotProtectionEnabled'] is bool) {
        final enabled = data['screenshotProtectionEnabled'] as bool;
        await prefs.setBool('screenshot_protection_global', enabled);
        await prefs.setBool('screenshot_protection_configured', true);
        await prefs.setBool('screenshot_protection_admin_disabled', !enabled);
        await applyNativeSecureFlag(enabled);
        return enabled;
      }
    }

    // 3. If cloud does not have it, respect existing local admin setting
    final adminDisabled = prefs.getBool('screenshot_protection_admin_disabled') ?? false;
    if (adminDisabled) {
      await applyNativeSecureFlag(false);
      return false;
    }

    final global = prefs.getBool('screenshot_protection_global') ?? true;
    await applyNativeSecureFlag(global);
    return global;
  } catch (_) {
    final prefs = await SharedPreferences.getInstance();
    final adminDisabled = prefs.getBool('screenshot_protection_admin_disabled') ?? false;
    if (adminDisabled) {
      await applyNativeSecureFlag(false);
      return false;
    }
    final global = prefs.getBool('screenshot_protection_global') ?? true;
    await applyNativeSecureFlag(global);
    return global;
  }
}
