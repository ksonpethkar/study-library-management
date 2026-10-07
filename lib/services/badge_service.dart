import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

/// Manages the app icon badge count (the red number on the app icon).
/// Used to show admin how many pending student requests are waiting.
class BadgeService {
  static bool _supported = false;

  static Future<void> initialize() async {
    try {
      _supported = await FlutterAppBadger.isAppBadgeSupported();
    } catch (_) {
      _supported = false;
    }
  }

  /// Update the badge count. Pass 0 to clear it.
  static Future<void> updateBadge(int count) async {
    if (!_supported) return;
    try {
      if (count <= 0) {
        await FlutterAppBadger.removeBadge();
      } else {
        await FlutterAppBadger.updateBadgeCount(count);
      }
    } catch (e) {
      debugPrint('Badge update failed: $e');
    }
  }

  static Future<void> clearBadge() => updateBadge(0);
}
