import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/services/inactivity_lock_service.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _usePin = false;
  bool _hasBiometric = false;
  bool _hasPin = false;
  int _failedAttempts = 0;
  String? _errorMessage;

  DateTime? _lockoutUntil;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    InactivityLockService.setLocked(true);
    _initSecurityState();
  }

  Future<void> _initSecurityState() async {
    await _checkLockout();
    await _checkHardwareAndPrompt();
  }

  Future<void> _checkLockout() async {
    final lockout = await BiometricService.getLockoutUntil();
    final attempts = await BiometricService.getFailedAttempts();
    if (mounted) {
      setState(() {
        _failedAttempts = attempts;
        _lockoutUntil = lockout;
      });
    }

    if (lockout != null) {
      _startCountdown(lockout);
    }
  }

  void _startCountdown(DateTime lockout) {
    _countdownTimer?.cancel();
    final diff = lockout.difference(DateTime.now()).inSeconds;
    if (diff <= 0) {
      _clearLockout();
      return;
    }

    setState(() {
      _remainingSeconds = diff;
      _errorMessage = null;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nowDiff = lockout.difference(DateTime.now()).inSeconds;
      if (nowDiff <= 0) {
        timer.cancel();
        _clearLockout();
      } else {
        if (mounted) {
          setState(() => _remainingSeconds = nowDiff);
        }
      }
    });
  }

  Future<void> _clearLockout() async {
    _countdownTimer?.cancel();
    await BiometricService.resetFailedAttempts();
    if (mounted) {
      setState(() {
        _lockoutUntil = null;
        _remainingSeconds = 0;
        _failedAttempts = 0;
        _errorMessage = null;
      });
    }
  }

  String get _cooldownString {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _checkHardwareAndPrompt() async {
    final bioAvailable = await BiometricService.isBiometricAvailable();
    final bioEnabled = await BiometricService.isBiometricEnabled();
    final hasPin = await BiometricService.hasPin();

    if (mounted) {
      setState(() {
        _hasBiometric = bioAvailable && bioEnabled;
        _hasPin = hasPin;
        // If biometric not available or not enabled, default to PIN
        if (!_hasBiometric && hasPin) {
          _usePin = true;
        }
      });
    }

    // Only prompt biometric if not in active 15-min lockout
    if (_hasBiometric && (_lockoutUntil == null || _remainingSeconds <= 0)) {
      _handleBiometric();
    }
  }

  Future<void> _handleBiometric() async {
    if (_lockoutUntil != null && _remainingSeconds > 0) return;

    setState(() => _errorMessage = null);
    final authenticated = await BiometricService.authenticate();
    if (authenticated) {
      await BiometricService.resetFailedAttempts();
      _unlockApp();
    } else {
      final lockout = await BiometricService.recordFailedAttempt();
      final attempts = await BiometricService.getFailedAttempts();

      if (mounted) {
        if (lockout != null) {
          setState(() {
            _lockoutUntil = lockout;
            _failedAttempts = attempts;
          });
          _startCountdown(lockout);
        } else {
          setState(() {
            _failedAttempts = attempts;
            _errorMessage = 'Biometric check failed (Attempt $_failedAttempts/5)';
          });
        }
      }
    }
  }

  Future<void> _verifyPin() async {
    if (_lockoutUntil != null && _remainingSeconds > 0) return;

    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _errorMessage = 'Please enter your 4-digit PIN');
      return;
    }

    final isValid = await BiometricService.verifyPin(pin);
    if (isValid) {
      await BiometricService.resetFailedAttempts();
      _unlockApp();
    } else {
      final lockout = await BiometricService.recordFailedAttempt();
      final attempts = await BiometricService.getFailedAttempts();
      _pinController.clear();

      if (mounted) {
        if (lockout != null) {
          setState(() {
            _lockoutUntil = lockout;
            _failedAttempts = attempts;
          });
          _startCountdown(lockout);
        } else {
          setState(() {
            _failedAttempts = attempts;
            _errorMessage = 'Incorrect PIN (Attempt $_failedAttempts/5)';
          });
        }
      }
    }
  }

  void _unlockApp() {
    _countdownTimer?.cancel();
    BiometricService.markUnlocked();
    InactivityLockService.setLocked(false);
    // Route according to user role
    final libId = ref.read(currentLibraryIdProvider);
    if (libId != null && libId.isNotEmpty) {
      context.go(Routes.adminHome);
    } else {
      context.go(Routes.studentHome);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 38,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'App Locked',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cozy Corner Security Guard',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 36),

                  if (_lockoutUntil != null && _remainingSeconds > 0) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: theme.colorScheme.error),
                              const SizedBox(width: 8),
                              Text(
                                'Lockout Cooldown: $_cooldownString',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Blocked after 5 failed attempts. Please wait 15 minutes before retrying.',
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (_usePin || !_hasBiometric) ...[
                    // PIN Entry View
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: TextField(
                        controller: _pinController,
                        enabled: _lockoutUntil == null || _remainingSeconds <= 0,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, letterSpacing: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '••••',
                          counterText: '',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _verifyPin(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (_lockoutUntil != null && _remainingSeconds > 0) ? null : _verifyPin,
                      child: const Text('Unlock with PIN'),
                    ),
                    if (_hasBiometric) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.fingerprint_rounded, size: 20),
                        label: const Text('Use Fingerprint / Face ID'),
                        onPressed: (_lockoutUntil != null && _remainingSeconds > 0)
                            ? null
                            : () {
                                setState(() => _usePin = false);
                                _handleBiometric();
                              },
                      ),
                    ],
                  ] else ...[
                    // Biometric Trigger View
                    InkWell(
                      onTap: (_lockoutUntil != null && _remainingSeconds > 0) ? null : _handleBiometric,
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_lockoutUntil != null && _remainingSeconds > 0)
                              ? Colors.grey.shade300
                              : theme.colorScheme.primaryContainer,
                          boxShadow: (_lockoutUntil != null && _remainingSeconds > 0)
                              ? []
                              : [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          size: 64,
                          color: (_lockoutUntil != null && _remainingSeconds > 0)
                              ? Colors.grey
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      (_lockoutUntil != null && _remainingSeconds > 0)
                          ? 'Biometric Disabled During Lockout'
                          : 'Tap to Scan Biometric',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: (_lockoutUntil != null && _remainingSeconds > 0) ? Colors.grey : null,
                      ),
                    ),
                    if (_hasPin) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.pin_rounded, size: 18),
                        label: const Text('Use Security PIN'),
                        onPressed: () {
                          setState(() => _usePin = true);
                        },
                      ),
                    ],
                  ],

                  const SizedBox(height: 48),
                  TextButton(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      BiometricService.markUnlocked();
                      if (context.mounted) {
                        context.go(Routes.login);
                      }
                    },
                    child: Text(
                      'Sign In with Different Account',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
