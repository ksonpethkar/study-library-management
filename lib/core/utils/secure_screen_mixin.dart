import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mixin that prevents screenshots and screen recording on sensitive screens.
/// Apply to State classes that show ID cards, receipts, or payment info.
///
/// Usage:
///   `class _MyScreenState extends State<MyScreen> with SecureScreenMixin {`
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  static const _channel = MethodChannel('study_library/secure_screen');

  @override
  void initState() {
    super.initState();
    _setSecure(true);
  }

  @override
  void dispose() {
    _setSecure(false);
    super.dispose();
  }

  Future<void> _setSecure(bool secure) async {
    if (!Platform.isAndroid) return; // iOS handles this differently (FLAG_SECURE equivalent)
    try {
      await _channel.invokeMethod('setSecureFlag', {'secure': secure});
    } catch (_) {
      // Graceful fallback — security feature only
    }
  }
}
