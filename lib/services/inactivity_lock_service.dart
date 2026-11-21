import 'dart:async';
import 'package:flutter/material.dart';
import 'package:study_library/services/biometric_service.dart';

/// Service that monitors front-desk touch/pointer interaction and automatically
/// triggers the security lock if the desk has been idle for the configured timeout.
class InactivityLockService {
  InactivityLockService._();

  static DateTime _lastInteraction = DateTime.now();
  static DateTime? _pausedAt;
  static Timer? _idleCheckTimer;
  static VoidCallback? _onLockTriggered;
  static Future<bool> Function()? _checkLockEnabledCallback;
  static bool _isEnabled = true;
  static bool _isLocked = false;
  static bool _isExternalDialogActive = false;

  /// Whether the screen is currently locked
  static bool get isLocked => _isLocked;

  /// Returns true if an external OS dialog (file picker, camera, image upload) is currently open.
  /// When active, all inactivity timers and lifecycle lockouts are temporarily suppressed.
  static bool get isExternalDialogActive => _isExternalDialogActive;

  /// Mark when an external OS dialog opens or closes.
  static void setExternalDialogActive(bool active) {
    _isExternalDialogActive = active;
    if (!active) {
      _lastInteraction = DateTime.now();
      _pausedAt = null;
    }
  }

  /// Handle OS-level application lifecycle changes (background/foreground)
  static void onAppLifecycleStateChanged(AppLifecycleState state) {
    if (isExternalDialogActive) {
      _lastInteraction = DateTime.now();
      _pausedAt = null;
      return;
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final backgroundDuration = DateTime.now().difference(_pausedAt!);
        _pausedAt = null;
        _checkInactivityWithDuration(backgroundDuration);
      } else {
        _checkInactivity();
      }
    }
  }

  static Future<void> _checkInactivityWithDuration(Duration backgroundDuration) async {
    if (!_isEnabled || _isLocked || isExternalDialogActive) return;

    final bool lockEnabled;
    if (_checkLockEnabledCallback != null) {
      lockEnabled = await _checkLockEnabledCallback!();
    } else {
      lockEnabled = await BiometricService.isLockEnabled();
    }
    if (!lockEnabled) return;

    final timeoutMinutes = await BiometricService.getAutoLockTimeoutMinutes();
    final bool isTimeoutReached = timeoutMinutes == 0
        ? backgroundDuration.inSeconds >= 15
        : backgroundDuration.inMinutes >= timeoutMinutes;
    if (isTimeoutReached) {
      _isLocked = true;
      _onLockTriggered?.call();
    }
  }

  /// Initialize the idle timer with a callback to invoke when timeout is reached.
  static void initialize({
    required VoidCallback onLock,
    Future<bool> Function()? checkLockEnabled,
  }) {
    _onLockTriggered = onLock;
    _checkLockEnabledCallback = checkLockEnabled;
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
    if (!_isEnabled || _isLocked || isExternalDialogActive) return;

    final bool lockEnabled;
    if (_checkLockEnabledCallback != null) {
      lockEnabled = await _checkLockEnabledCallback!();
    } else {
      lockEnabled = await BiometricService.isLockEnabled();
    }
    if (!lockEnabled) return;

    final timeoutMinutes = await BiometricService.getAutoLockTimeoutMinutes();
    // Inactivity idle timeout (front desk unattended) must have a safe floor (min 2 minutes)
    // so that "Immediately" (which means background lock) does not lock active foreground sessions every 15 seconds.
    final effectiveIdleMinutes = timeoutMinutes == 0 ? 2 : timeoutMinutes;
    final elapsedMinutes = DateTime.now().difference(_lastInteraction).inMinutes;

    if (elapsedMinutes >= effectiveIdleMinutes) {
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
