import 'dart:async';
import 'package:flutter/material.dart';
import 'package:study_library/services/biometric_service.dart';

/// Service that monitors front-desk touch/pointer interaction and automatically
/// triggers the security lock if the desk has been idle for the configured timeout.
class InactivityLockService {
  InactivityLockService._();

  static DateTime _lastInteraction = DateTime.now();
  static Timer? _idleCheckTimer;
  static VoidCallback? _onLockTriggered;
  static bool _isEnabled = true;
  static bool _isLocked = false;

  /// Initialize the idle timer with a callback to invoke when timeout is reached.
  static void initialize({required VoidCallback onLock}) {
    _onLockTriggered = onLock;
    _lastInteraction = DateTime.now();
    _idleCheckTimer?.cancel();
    _idleCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkInactivity());
  }

  /// Record user activity (tap, scroll, pointer move, keystroke)
  static void recordInteraction() {
    _lastInteraction = DateTime.now();
  }

  /// Mark whether the screen is currently displaying the lock UI
  static void setLocked(bool locked) {
    _isLocked = locked;
    if (!locked) {
      _lastInteraction = DateTime.now();
    }
  }

  /// Enable or disable idle checking (e.g. during fullscreen video or camera capture)
  static void setMonitoringEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      _lastInteraction = DateTime.now();
    }
  }

  static Future<void> _checkInactivity() async {
    if (!_isEnabled || _isLocked) return;

    final lockEnabled = await BiometricService.isLockEnabled();
    if (!lockEnabled) return;

    final timeoutMinutes = await BiometricService.getAutoLockTimeoutMinutes();
    final elapsedMinutes = DateTime.now().difference(_lastInteraction).inMinutes;

    if (elapsedMinutes >= timeoutMinutes) {
      _isLocked = true;
      _onLockTriggered?.call();
    }
  }

  static void dispose() {
    _idleCheckTimer?.cancel();
  }
}

/// A global wrapper widget that detects pointer activity to reset the front-desk idle timer.
class InactivityDetectorWrapper extends StatelessWidget {
  final Widget child;

  const InactivityDetectorWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => InactivityLockService.recordInteraction(),
      onPointerMove: (_) => InactivityLockService.recordInteraction(),
      child: child,
    );
  }
}
