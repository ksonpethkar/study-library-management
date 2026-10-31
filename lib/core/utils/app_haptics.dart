import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized haptic feedback utility for consistent tactile responses.
///
/// Use these methods on user interactions for a polished mobile feel:
/// - [light] — Tab switches, toggles, minor selections
/// - [medium] — Card taps, button presses, confirmations
/// - [heavy] — Delete actions, important state changes
/// - [selection] — Picker scrolls, slider changes
class AppHaptics {
  AppHaptics._();

  /// Light tap — for subtle interactions like tab switches.
  static Future<void> light() async {
    if (kIsWeb) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium tap — for card taps, button presses.
  static Future<void> medium() async {
    if (kIsWeb) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy tap — for destructive or important actions.
  static Future<void> heavy() async {
    if (kIsWeb) return;
    await HapticFeedback.heavyImpact();
  }

  /// Selection tick — for scrolling through pickers/sliders.
  static Future<void> selection() async {
    if (kIsWeb) return;
    await HapticFeedback.selectionClick();
  }

  /// Vibrate — last resort, for errors or alerts.
  static Future<void> vibrate() async {
    if (kIsWeb) return;
    await HapticFeedback.vibrate();
  }
}
