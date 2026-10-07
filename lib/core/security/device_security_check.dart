import 'dart:io';
import 'package:flutter/foundation.dart';

/// Simple heuristic root/jailbreak detection.
/// Does NOT use a package (to avoid adding dependencies).
/// Checks for common root indicators on Android.
class DeviceSecurityCheck {
  /// Returns true if the device appears to be rooted (Android) or jailbroken (iOS).
  /// This is a best-effort check — determined attackers can bypass it.
  static Future<bool> isDeviceCompromised() async {
    if (kDebugMode) return false; // Allow in debug/dev
    try {
      if (Platform.isAndroid) {
        return _checkAndroid();
      } else if (Platform.isIOS) {
        return _checkIOS();
      }
    } catch (_) {}
    return false;
  }

  static bool _checkAndroid() {
    // Check for common root indicators
    final rootPaths = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
    ];
    for (final path in rootPaths) {
      if (File(path).existsSync()) return true;
    }
    return false;
  }

  static bool _checkIOS() {
    // Check for common jailbreak indicators
    final jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt',
    ];
    for (final path in jailbreakPaths) {
      if (File(path).existsSync()) return true;
    }
    return false;
  }
}
