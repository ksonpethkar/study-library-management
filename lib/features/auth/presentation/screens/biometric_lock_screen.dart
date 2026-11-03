import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/services/inactivity_lock_service.dart';
import 'package:study_library/features/settings/presentation/screens/security_settings_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();

  StreamSubscription<DocumentSnapshot>? _securitySubscription;
  bool _isHandlingReset = false;
  bool _usePin = false;
  bool _hasBiometric = false;
  bool _hasPin = false;
  bool _isVerifying = false;
  int _failedAttempts = 0;
  String? _errorMessage;
  String _enteredPin = '';

  DateTime? _lockoutUntil;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  bool get _isAdminLock => ref.read(userRoleProvider) == AppUserRole.admin;
  String? _resolvedStudentDocId;
  String? _loadedStudentName;

  String? get _studentId =>
      _resolvedStudentDocId ??
      ref.read(currentStudentProvider).value?.id ??
      FirebaseAuth.instance.currentUser?.uid;

  List<String> get _candidateStudentIds {
    final ids = <String>{};
    if (_resolvedStudentDocId != null && _resolvedStudentDocId!.isNotEmpty) {
      ids.add(_resolvedStudentDocId!);
    }
    final student = ref.read(currentStudentProvider).value;
    if (student?.id != null && student!.id.isNotEmpty) ids.add(student.id);
    if (student?.userId != null && student!.userId!.isNotEmpty) ids.add(student.userId!);
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) ids.add(authUid);
    if (student?.membershipNumber != null && student!.membershipNumber!.isNotEmpty) {
      ids.add(student.membershipNumber!);
    }
    return ids.toList();
  }

  String get _studentName {
    final fromProvider = ref.watch(currentStudentProvider).value?.name;
    if (fromProvider != null && fromProvider.trim().isNotEmpty) {
      return fromProvider.trim();
    }
    if (_loadedStudentName != null && _loadedStudentName!.trim().isNotEmpty) {
      return _loadedStudentName!.trim();
    }
    final authName = FirebaseAuth.instance.currentUser?.displayName;
    if (authName != null && authName.trim().isNotEmpty) {
      return authName.trim();
    }
    return 'Student';
  }

  @override
  void initState() {
    super.initState();
    InactivityLockService.setLocked(true);
    _initSecurityState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  Future<void> _initSecurityState() async {
    final isAdmin = _isAdminLock;
    final libraryId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    final authUser = FirebaseAuth.instance.currentUser;

    // Proactively restore admin security settings & PIN hash from Firestore if admin
    if (isAdmin && libraryId.isNotEmpty) {
      try {
        await BiometricService.restoreSecuritySettingsFromFirestore(libraryId);
      } catch (_) {}
    }

    // Proactively resolve student document & restore security from Firestore if student
    if (!isAdmin && authUser != null) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .where('userId', isEqualTo: authUser.uid)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          _resolvedStudentDocId = doc.id;
          final name = doc.data()['name'] as String?;
          if (name != null && name.isNotEmpty && mounted) {
            setState(() => _loadedStudentName = name);
          }
          await BiometricService.restoreStudentSecurityFromFirestore(
            libraryId: libraryId,
            studentId: doc.id,
            authUid: authUser.uid,
            candidateIds: [doc.id, authUser.uid],
          );
        } else if (authUser.email != null && authUser.email!.isNotEmpty) {
          final eq = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .where('email', isEqualTo: authUser.email)
              .limit(1)
              .get();
          if (eq.docs.isNotEmpty) {
            final doc = eq.docs.first;
            _resolvedStudentDocId = doc.id;
            final name = doc.data()['name'] as String?;
            if (name != null && name.isNotEmpty && mounted) {
              setState(() => _loadedStudentName = name);
            }
            await BiometricService.restoreStudentSecurityFromFirestore(
              libraryId: libraryId,
              studentId: doc.id,
              authUid: authUser.uid,
              candidateIds: [doc.id, authUser.uid],
            );
          }
        }
      } catch (_) {}
    }

    final activeStudentDocId = _resolvedStudentDocId ?? ref.read(currentStudentProvider).value?.id;
    if (!isAdmin && activeStudentDocId != null && activeStudentDocId.isNotEmpty) {
      _subscribeToLiveSecurityUpdates(libraryId, activeStudentDocId);
    }

    await _checkLockout();
    await _checkHardwareAndPrompt();
  }

  void _subscribeToLiveSecurityUpdates(String libraryId, String studentDocId) {
    _securitySubscription?.cancel();
    _securitySubscription = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('students')
        .doc(studentDocId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data();
      if (data == null) return;

      final pinResetByAdmin = data['pinResetByAdmin'] == true;
      final serverResetAtTs = data['pinResetAt'] as Timestamp?;
      final serverResetAtMs = serverResetAtTs?.millisecondsSinceEpoch ?? 0;

      // Only handle reset if explicitly flagged by admin AND newer than local PIN set timestamp
      if (pinResetByAdmin && _hasPin) {
        SharedPreferences.getInstance().then((prefs) {
          int localSetAt = 0;
          for (final cid in _candidateStudentIds) {
            final ts = prefs.getInt('security_pin_local_set_at_$cid') ?? 0;
            if (ts > localSetAt) localSetAt = ts;
          }
          if (serverResetAtMs > localSetAt || localSetAt == 0) {
            _handleAdminResetDetected();
          }
        });
      }
    });
  }

  Future<void> _handleAdminResetDetected() async {
    if (_isHandlingReset) return;
    _isHandlingReset = true;

    _countdownTimer?.cancel();
    _enteredPin = '';
    _pinController.clear();

    final isAdmin = _isAdminLock;
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final candidates = _candidateStudentIds;
    final studentId = _resolvedStudentDocId ?? _studentId;

    await BiometricService.resetFailedAttempts(
      userId: isAdmin ? null : studentId,
      authUid: isAdmin ? null : authUid,
      candidateIds: isAdmin ? null : candidates,
      isAdmin: isAdmin,
    );
    await BiometricService.clearPin(
      userId: isAdmin ? null : studentId,
      authUid: isAdmin ? null : authUid,
      candidateIds: isAdmin ? null : candidates,
    );

    if (mounted) {
      setState(() {
        _lockoutUntil = null;
        _remainingSeconds = 0;
        _failedAttempts = 0;
        _hasPin = false;
        _errorMessage = null;
      });
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.lock_reset_rounded, size: 40, color: Colors.orange),
        title: const Text(
          'Security PIN Reset by Admin',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your library administrator has reset your 4-digit security PIN and biometric lock.\n\n'
          'Your pass is now unlocked. You can configure a fresh PIN now, or proceed to your dashboard.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unlockApp();
            },
            child: const Text('Go to Dashboard'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.pin_rounded, size: 16),
            label: const Text('Set New PIN Now'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () {
              Navigator.pop(ctx);
              _unlockApp();
              final sId = _resolvedStudentDocId ?? _studentId;
              if (sId != null && sId.isNotEmpty && mounted) {
                SecuritySettingsDialog.show(
                  context,
                  isStudent: true,
                  studentId: sId,
                  authUid: FirebaseAuth.instance.currentUser?.uid,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkLockout() async {
    final isAdmin = _isAdminLock;
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final candidates = _candidateStudentIds;
    final studentId = _resolvedStudentDocId ?? _studentId;

    final lockout = await BiometricService.getLockoutUntil(
      userId: isAdmin ? null : studentId,
      authUid: isAdmin ? null : authUid,
      candidateIds: isAdmin ? null : candidates,
      isAdmin: isAdmin,
    );
    final attempts = await BiometricService.getFailedAttempts(
      userId: isAdmin ? null : studentId,
      authUid: isAdmin ? null : authUid,
      candidateIds: isAdmin ? null : candidates,
      isAdmin: isAdmin,
    );
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
    final isAdmin = _isAdminLock;
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final candidates = _candidateStudentIds;
    final studentId = _resolvedStudentDocId ?? _studentId;

    await BiometricService.resetFailedAttempts(
      userId: isAdmin ? null : studentId,
      authUid: isAdmin ? null : authUid,
      candidateIds: isAdmin ? null : candidates,
      isAdmin: isAdmin,
    );
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
    final isAdmin = _isAdminLock;
    final libraryId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final candidates = _candidateStudentIds;
    final studentId = _resolvedStudentDocId ?? _studentId;

    final bioAvailable = await BiometricService.isBiometricAvailable();
    final bioEnabled = await BiometricService.isBiometricEnabled(
      userId: isAdmin ? null : studentId,
      authUid: isAdmin ? null : authUid,
      candidateIds: isAdmin ? null : candidates,
      isAdmin: isAdmin,
    );
    final hasPin = await BiometricService.hasPin(
      userId: isAdmin ? null : studentId,
      authUid: isAdmin ? null : authUid,
      libraryId: libraryId,
      candidateIds: isAdmin ? null : candidates,
      isAdmin: isAdmin,
    );

    // CRITICAL SAFETY GUARD: If user has neither biometric nor PIN configured,
    // do NOT present a lock screen! Automatically unlock and proceed!
    if (!hasPin && !bioEnabled) {
      _unlockApp();
      return;
    }

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

    final isAdmin = _isAdminLock;
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final candidates = _candidateStudentIds;
    final studentId = _resolvedStudentDocId ?? _studentId;

    setState(() => _errorMessage = null);
    final reason = isAdmin
        ? 'Scan fingerprint or Face ID to unlock Admin Console'
        : 'Scan fingerprint or Face ID to unlock your Student Pass';
    final authenticated = await BiometricService.authenticate(reason: reason);
    if (authenticated) {
      await BiometricService.resetFailedAttempts(
        userId: isAdmin ? null : studentId,
        authUid: isAdmin ? null : authUid,
        candidateIds: isAdmin ? null : candidates,
        isAdmin: isAdmin,
      );
      _unlockApp();
    } else {
      final lockout = await BiometricService.recordFailedAttempt(
        userId: isAdmin ? null : studentId,
        authUid: isAdmin ? null : authUid,
        candidateIds: isAdmin ? null : candidates,
        isAdmin: isAdmin,
      );
      final attempts = await BiometricService.getFailedAttempts(
        userId: isAdmin ? null : studentId,
        authUid: isAdmin ? null : authUid,
        candidateIds: isAdmin ? null : candidates,
        isAdmin: isAdmin,
      );

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

  void _onDigitPressed(String digit) {
    if (_lockoutUntil != null && _remainingSeconds > 0) return;
    if (_isVerifying) return;
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _pinController.text = _enteredPin;
        _errorMessage = null;
      });
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_lockoutUntil != null && _remainingSeconds > 0) return;
    if (_isVerifying) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _pinController.text = _enteredPin;
        _errorMessage = null;
      });
    }
  }

  void _onClearPressed() {
    if (_lockoutUntil != null && _remainingSeconds > 0) return;
    if (_isVerifying) return;
    setState(() {
      _enteredPin = '';
      _pinController.clear();
      _errorMessage = null;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final logicalKey = event.logicalKey;

    if (logicalKey == LogicalKeyboardKey.backspace) {
      _onBackspacePressed();
      return;
    }
    if (logicalKey == LogicalKeyboardKey.escape) {
      _onClearPressed();
      return;
    }
    if (logicalKey == LogicalKeyboardKey.enter || logicalKey == LogicalKeyboardKey.numpadEnter) {
      _verifyPin();
      return;
    }

    final digitChars = {
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };

    if (digitChars.containsKey(logicalKey)) {
      _onDigitPressed(digitChars[logicalKey]!);
      return;
    }

    final keyLabel = logicalKey.keyLabel;
    if (keyLabel.length == 1 && RegExp(r'^[0-9]$').hasMatch(keyLabel)) {
      _onDigitPressed(keyLabel);
      return;
    }

    final char = event.character;
    if (char != null && char.length == 1 && RegExp(r'^[0-9]$').hasMatch(char)) {
      _onDigitPressed(char);
    }
  }

  Future<void> _verifyPin() async {
    if (_lockoutUntil != null && _remainingSeconds > 0) return;
    if (_isVerifying) return;

    final pin = _enteredPin.trim();
    if (pin.length < 4) {
      setState(() => _errorMessage = 'Please enter your 4-digit PIN');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final isAdmin = _isAdminLock;
      final libraryId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final candidates = _candidateStudentIds;
      final studentId = _resolvedStudentDocId ?? _studentId;

      // Check if student's PIN was reset by admin before penalizing failed attempts
      if (!isAdmin) {
        final hasActivePin = await BiometricService.hasPin(
          userId: studentId,
          authUid: authUid,
          libraryId: libraryId,
          candidateIds: candidates,
          isAdmin: false,
        );
        if (!hasActivePin) {
          setState(() {
            _enteredPin = '';
            _pinController.clear();
          });
          await _handleAdminResetDetected();
          return;
        }
      }

      // Strict account isolation: Admin PIN only unlocks Admin; Student PIN only unlocks that student!
      final isValid = await BiometricService.verifyPin(
        pin,
        userId: isAdmin ? null : studentId,
        authUid: isAdmin ? null : authUid,
        libraryId: libraryId,
        candidateIds: isAdmin ? null : candidates,
        isAdmin: isAdmin,
      );

      if (isValid) {
        await BiometricService.resetFailedAttempts(
          userId: isAdmin ? null : studentId,
          authUid: isAdmin ? null : authUid,
          candidateIds: isAdmin ? null : candidates,
          isAdmin: isAdmin,
        );
        _unlockApp();
      } else {
        final lockout = await BiometricService.recordFailedAttempt(
          userId: isAdmin ? null : studentId,
          authUid: isAdmin ? null : authUid,
          candidateIds: isAdmin ? null : candidates,
          isAdmin: isAdmin,
        );
        final attempts = await BiometricService.getFailedAttempts(
          userId: isAdmin ? null : studentId,
          authUid: isAdmin ? null : authUid,
          candidateIds: isAdmin ? null : candidates,
          isAdmin: isAdmin,
        );
        setState(() {
          _enteredPin = '';
          _pinController.clear();
        });

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
              _errorMessage = isAdmin
                  ? 'Incorrect Admin Master PIN (Attempt $_failedAttempts/5)'
                  : 'Incorrect Student PIN (Attempt $_failedAttempts/5)';
            });
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _handleAdminGoogleReAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    final adminEmail = user?.email ?? 'Administrator';

    setState(() => _isVerifying = true);
    try {
      // Direct call on user gesture preserves browser transient user activation (prevents popup blocking)
      final cred = await ref.read(authRepositoryProvider).signInWithGoogle();
      final verifiedUser = cred.user;

      if (verifiedUser == null) {
        throw Exception('Google verification was not completed.');
      }

      // Security Check: Verify that the re-authenticated user matches the active session
      if (user != null && verifiedUser.uid != user.uid && verifiedUser.email != user.email) {
        throw Exception('The Google account used does not match the active administrator ($adminEmail).');
      }

      // Legitimate administrator verified via Google OAuth!
      await _clearLockout();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Identity Verified!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          verifiedUser.email ?? adminEmail,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your Google identity has been successfully verified. Would you like to set a fresh Master PIN now, or proceed directly to the Admin Console?',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _unlockApp();
                },
                child: const Text('Proceed to Console'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.pin_rounded, size: 16),
                label: const Text('Set New Master PIN'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _unlockApp();
                  if (mounted) {
                    SecuritySettingsDialog.show(
                      context,
                      isStudent: false,
                      authUid: verifiedUser.uid,
                    );
                  }
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception:', '').trim();
        final isCancelled = errorMsg.toLowerCase().contains('cancelled') ||
            errorMsg.toLowerCase().contains('popup-closed') ||
            errorMsg.toLowerCase().contains('whenever you\'re ready');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isCancelled ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCancelled
                        ? 'Google verification cancelled. Tap "Forgot Master PIN" whenever you are ready.'
                        : errorMsg,
                  ),
                ),
              ],
            ),
            backgroundColor: isCancelled ? Colors.grey.shade800 : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _unlockApp() async {
    _countdownTimer?.cancel();
    BiometricService.markUnlocked();
    InactivityLockService.setLocked(false);

    // Restore the route the user was on before the lock was triggered
    final prefs = await SharedPreferences.getInstance();
    final lastRoute = prefs.getString('last_active_route');

    if (!mounted) return;

    final isAdmin = _isAdminLock;

    // Strict security check: Ensure student route cannot go to admin, and admin route cannot go to student
    if (lastRoute != null &&
        lastRoute.isNotEmpty &&
        lastRoute != Routes.biometricLock &&
        lastRoute != Routes.splash &&
        lastRoute != Routes.login) {
      final isRouteAdmin = lastRoute.startsWith('/admin');
      if (isAdmin && isRouteAdmin) {
        context.go(lastRoute);
        return;
      } else if (!isAdmin && !isRouteAdmin) {
        context.go(lastRoute);
        return;
      }
    }

    // Default safe fallback strictly adhering to role
    if (isAdmin) {
      context.go(Routes.adminHome);
    } else {
      context.go(Routes.studentHome);
    }
  }

  @override
  void dispose() {
    _securitySubscription?.cancel();
    _countdownTimer?.cancel();
    _keyboardFocusNode.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Widget _buildPinIndicators(ThemeData theme) {
    final hasError = _errorMessage != null;
    final primaryColor = _isAdminLock ? Colors.amber.shade700 : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasError
              ? theme.colorScheme.error
              : (_enteredPin.isNotEmpty ? primaryColor.withValues(alpha: 0.6) : Colors.transparent),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < _enteredPin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: isFilled ? 18 : 14,
            height: isFilled ? 18 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled
                  ? (hasError ? theme.colorScheme.error : primaryColor)
                  : Colors.transparent,
              border: Border.all(
                color: isFilled
                    ? (hasError ? theme.colorScheme.error : primaryColor)
                    : theme.colorScheme.outline.withValues(alpha: 0.4),
                width: 2.2,
              ),
              boxShadow: isFilled
                  ? [
                      BoxShadow(
                        color: (hasError ? theme.colorScheme.error : primaryColor).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKeypadButton({
    required Widget child,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? splashColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (_lockoutUntil != null && _remainingSeconds > 0) ? null : onTap,
        borderRadius: BorderRadius.circular(36),
        splashColor: splashColor ?? (_isAdminLock ? Colors.amber.withValues(alpha: 0.2) : null),
        child: Ink(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildDigitButton(String digit, ThemeData theme) {
    return _buildKeypadButton(
      onTap: () => _onDigitPressed(digit),
      child: Text(
        digit,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 26,
        ),
      ),
    );
  }

  Widget _buildNumericDialPad(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDigitButton('1', theme),
            const SizedBox(width: 24),
            _buildDigitButton('2', theme),
            const SizedBox(width: 24),
            _buildDigitButton('3', theme),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDigitButton('4', theme),
            const SizedBox(width: 24),
            _buildDigitButton('5', theme),
            const SizedBox(width: 24),
            _buildDigitButton('6', theme),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDigitButton('7', theme),
            const SizedBox(width: 24),
            _buildDigitButton('8', theme),
            const SizedBox(width: 24),
            _buildDigitButton('9', theme),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Clear Key
            _buildKeypadButton(
              onTap: _onClearPressed,
              backgroundColor: Colors.transparent,
              child: Text(
                'C',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(width: 24),
            _buildDigitButton('0', theme),
            const SizedBox(width: 24),
            // Backspace Key
            _buildKeypadButton(
              onTap: _onBackspacePressed,
              backgroundColor: Colors.transparent,
              child: Icon(
                Icons.backspace_outlined,
                size: 22,
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _isAdminLock
                              ? Colors.amber.shade100
                              : theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isAdminLock ? Icons.admin_panel_settings_rounded : Icons.lock_person_rounded,
                          size: 38,
                          color: _isAdminLock ? Colors.amber.shade900 : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _isAdminLock ? 'Admin Console Locked' : 'Student Pass Locked',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isAdminLock
                            ? 'Master PIN required for library administration'
                            : 'Personal security pass lock for $_studentName',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isAdminLock ? Colors.amber.shade50 : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isAdminLock ? Colors.amber.shade300 : theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isAdminLock ? Icons.shield_rounded : Icons.account_circle_rounded,
                              size: 15,
                              color: _isAdminLock ? Colors.amber.shade900 : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                FirebaseAuth.instance.currentUser?.email ??
                                    FirebaseAuth.instance.currentUser?.phoneNumber ??
                                    (_isAdminLock ? "Administrator" : _studentName),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isAdminLock ? Colors.amber.shade900 : theme.colorScheme.onPrimaryContainer,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

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
                                _isAdminLock
                                    ? 'Security Lockout: 5 failed attempts. Entering PIN is temporarily disabled to protect console records. Please wait for the timer or re-verify with Google.'
                                    : 'Security Lockout: 5 failed attempts. Entering PIN is temporarily disabled. Please wait $_cooldownString before retrying.',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_isAdminLock) ...[
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.error,
                                    foregroundColor: theme.colorScheme.onError,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.security_rounded, size: 16),
                                  label: const Text(
                                    'Verify Identity with Google',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _handleAdminGoogleReAuth,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (_usePin || !_hasBiometric) ...[
                        // PIN Indicator Circles
                        _buildPinIndicators(theme),
                        const SizedBox(height: 24),

                        // On-Screen Numeric Dial Pad
                        _buildNumericDialPad(theme),
                        const SizedBox(height: 20),

                        // Manual Submit Button (active when 4 digits typed)
                        if (_enteredPin.length == 4) ...[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _isAdminLock ? Colors.amber.shade800 : null,
                              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: _isVerifying
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.lock_open_rounded, size: 18),
                            label: Text(_isVerifying ? 'Verifying...' : 'Unlock with PIN'),
                            onPressed: (_lockoutUntil != null && _remainingSeconds > 0) || _isVerifying ? null : _verifyPin,
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (_hasBiometric) ...[
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

                      const SizedBox(height: 20),

                      // Clean, Secure Sign Out / Switch Account Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 17),
                        label: const Text(
                          'Sign Out / Switch Account',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).signOut();
                          BiometricService.markUnlocked();
                          if (context.mounted) {
                            context.go(Routes.login);
                          }
                        },
                      ),

                      if (!_isAdminLock) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.help_outline_rounded, size: 16),
                          label: const Text('Forgot PIN? Ask Admin to Reset', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showForgotPinDialog(context),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: _isVerifying
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.lock_reset_rounded, size: 16),
                          label: Text(
                            _isVerifying ? 'Verifying with Google...' : 'Forgot Master PIN? Verify via Google Account',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _isVerifying ? null : _handleAdminGoogleReAuth,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPinDialog(BuildContext context) {
    final library = ref.read(currentLibraryProvider).value;
    final adminContact = library?.effectiveContact ?? '';
    final adminName = library?.adminName.trim().isNotEmpty == true
        ? library!.adminName.trim()
        : 'Library Admin';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('Resetting Your PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your 4-digit PIN is strictly private to your account and cannot be bypassed on this device.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                'If you have forgotten your PIN, please request $adminName at the library front desk to reset your PIN.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              if (adminContact.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone, size: 16, color: Colors.green),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Admin Contact: $adminContact',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
            if (adminContact.isNotEmpty)
              FilledButton.icon(
                icon: const Icon(Icons.call, size: 16),
                label: const Text('Call Admin'),
                onPressed: () async {
                  final uri = Uri.parse('tel:$adminContact');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
          ],
        );
      },
    );
  }
}
