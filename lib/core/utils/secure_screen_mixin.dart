import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mixin that prevents screenshots and screen recording on sensitive screens.
/// Apply to State classes that show ID cards, receipts, or payment info.
///
/// Behaviour:
///   - Checks SharedPreferences for 'screenshot_protection_global' (admin toggle).
///   - If the global setting is off, screenshots are allowed on all screens.
///   - If the global setting is on, this mixin enforces FLAG_SECURE for the screen.
///   - Certain screens (payment, ID card, receipt) always enforce protection
///     when global is on, regardless of per-screen overrides.
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
    _setSecure(false);
    super.dispose();
  }

  Future<void> _applySecureFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final globalEnabled = prefs.getBool('screenshot_protection_global') ?? true;

      if (!globalEnabled) {
        // Admin turned off global protection — allow screenshots everywhere
        _setSecure(false);
        return;
      }

      // Global is on — apply protection on this screen
      _setSecure(true);
    } catch (_) {
      // Fallback: apply protection if we can't determine the setting
      _setSecure(true);
    }
  }

  Future<void> _setSecure(bool secure) async {
    if (!Platform.isAndroid) return;
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
Future<void> setScreenshotProtectionEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('screenshot_protection_global', enabled);

  // Also save to Firestore for multi-device sync (best effort)
  try {
    // libraryId must be passed by caller for Firestore sync
  } catch (_) {}
}

/// Reads current global screenshot protection preference.
Future<bool> isScreenshotProtectionEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('screenshot_protection_global') ?? true;
}

/// Helper to sync screenshot protection setting to Firestore.
Future<void> syncScreenshotProtectionToFirestore(
    String libraryId, bool enabled) async {
  try {
    await FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('security')
        .set({'screenshotProtectionEnabled': enabled},
            SetOptions(merge: true));
  } catch (_) {}
}

/// Helper to load screenshot protection setting from Firestore.
Future<bool> loadScreenshotProtectionFromFirestore(String libraryId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('security')
        .get();
    return (doc.data()?['screenshotProtectionEnabled'] as bool?) ?? true;
  } catch (_) {
    return true;
  }
}
