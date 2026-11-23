import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SecuritySettingsDialog extends ConsumerStatefulWidget {
  final bool isStudent;
  final String? studentId;
  final String? authUid;
  final String? libraryId;

  const SecuritySettingsDialog({
    super.key,
    this.isStudent = false,
    this.studentId,
    this.authUid,
    this.libraryId,
  });

  static Future<void> show(
    BuildContext context, {
    bool isStudent = false,
    String? studentId,
    String? authUid,
    String? libraryId,
  }) {
    return showDialog(
      context: context,
      builder: (_) => SecuritySettingsDialog(
        isStudent: isStudent,
        studentId: studentId,
        authUid: authUid,
        libraryId: libraryId,
      ),
    );
  }

  static Future<bool> showSetPinDialog(
    BuildContext context, {
    required bool isStudent,
    String? studentId,
    String? authUid,
    String? libraryId,
    List<String>? candidateIds,
    bool isChanging = false,
  }) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? dialogError;
    bool isDialogSaving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isChanging ? Icons.lock_reset_rounded : Icons.pin_rounded,
                color: isStudent ? const Color(0xFF059669) : const Color(0xFFD97706),
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isStudent
                      ? (isChanging ? 'Change 4-Digit PIN' : 'Set Personal 4-Digit PIN')
                      : (isChanging ? 'Change Master PIN' : 'Set Admin Master PIN'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isStudent
                    ? 'Enter a 4-digit PIN to securely protect your student pass on this device.'
                    : 'Enter a 4-digit master PIN to secure library management data.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (dialogError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogError!,
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                onChanged: (_) {
                  if (dialogError != null) setDialogState(() => dialogError = null);
                },
                decoration: InputDecoration(
                  labelText: isChanging ? 'Enter New 4-Digit PIN' : 'Enter 4-Digit PIN',
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                onChanged: (_) {
                  if (dialogError != null) setDialogState(() => dialogError = null);
                },
                decoration: InputDecoration(
                  labelText: isChanging ? 'Confirm New 4-Digit PIN' : 'Confirm 4-Digit PIN',
                  counterText: '',
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDialogSaving ? null : () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: isDialogSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_rounded, size: 16),
              label: Text(isDialogSaving ? 'Saving...' : (isChanging ? 'Update PIN' : 'Save PIN')),
              style: FilledButton.styleFrom(
                backgroundColor: isStudent ? const Color(0xFF059669) : const Color(0xFFD97706),
              ),
              onPressed: isDialogSaving
                  ? null
                  : () async {
                      final pin = pinController.text.trim();
                      final confirm = confirmController.text.trim();
                      if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
                        setDialogState(() => dialogError = 'PIN must be exactly 4 numeric digits (0-9)');
                        return;
                      }
                      if (pin != confirm) {
                        setDialogState(() => dialogError = 'PINs do not match. Please re-enter.');
                        return;
                      }

                      setDialogState(() {
                        isDialogSaving = true;
                        dialogError = null;
                      });

                      try {
                        final ids = <String>{};
                        if (studentId != null && studentId.isNotEmpty) ids.add(studentId);
                        if (authUid != null && authUid.isNotEmpty) ids.add(authUid);
                        if (candidateIds != null) ids.addAll(candidateIds);
                        final currentUid = FirebaseAuth.instance.currentUser?.uid;
                        if (currentUid != null && currentUid.isNotEmpty) ids.add(currentUid);
                        final allCandidates = ids.toList();

                        await BiometricService.setPin(
                          pin,
                          userId: isStudent ? studentId : null,
                          authUid: authUid,
                          candidateIds: allCandidates,
                        );

                        final effectiveLibId = libraryId ?? '';
                        if (!isStudent) {
                          if (effectiveLibId.isNotEmpty) {
                            await BiometricService.syncSecuritySettingsToFirestore(effectiveLibId);
                          }
                        } else if (studentId != null && studentId.isNotEmpty && effectiveLibId.isNotEmpty) {
                          await BiometricService.syncStudentSecurityToFirestore(
                            libraryId: effectiveLibId,
                            studentId: studentId,
                            pin: pin,
                            authUid: authUid,
                            candidateIds: allCandidates,
                            biometricEnabled: false,
                          );
                          await BiometricService.clearAdminPinResetFlag(
                            libraryId: effectiveLibId,
                            studentId: studentId,
                          );
                        }

                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop(true);
                      } catch (err) {
                        if (ctx.mounted) {
                          setDialogState(() {
                            isDialogSaving = false;
                            dialogError = 'Failed to save PIN: $err';
                          });
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  @override
  ConsumerState<SecuritySettingsDialog> createState() => _SecuritySettingsDialogState();
}

class _SecuritySettingsDialogState extends ConsumerState<SecuritySettingsDialog> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _hasPin = false;
  int _autoLockMinutes = 2;
  bool _screenshotProtectionEnabled = true;
  bool _loading = true;
  String? _successBannerMessage;

  String? get _effectiveUserId => widget.isStudent ? widget.studentId : null;
  List<String> get _candidateIds {
    final ids = <String>{};
    if (widget.studentId != null && widget.studentId!.isNotEmpty) ids.add(widget.studentId!);
    if (widget.authUid != null && widget.authUid!.isNotEmpty) ids.add(widget.authUid!);
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) ids.add(authUid);
    return ids.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final libraryId = widget.libraryId ?? ref.read(currentLibraryIdProvider);
    if (!widget.isStudent) {
      if (libraryId != null && libraryId.isNotEmpty) {
        await BiometricService.restoreSecuritySettingsFromFirestore(libraryId);
      }
    } else if (widget.studentId != null && libraryId != null && libraryId.isNotEmpty) {
      await BiometricService.restoreStudentSecurityFromFirestore(
        libraryId: libraryId,
        studentId: widget.studentId!,
        authUid: widget.authUid,
        candidateIds: _candidateIds,
      );
    }

    final available = await BiometricService.isBiometricAvailable();
    final enabled = await BiometricService.isBiometricEnabled(
      userId: _effectiveUserId,
      authUid: widget.authUid,
      candidateIds: _candidateIds,
      isAdmin: !widget.isStudent,
    );
    final hasPin = await BiometricService.hasPin(
      userId: _effectiveUserId,
      authUid: widget.authUid,
      libraryId: libraryId,
      candidateIds: _candidateIds,
      isAdmin: !widget.isStudent,
    );
    final timeout = await BiometricService.getAutoLockTimeoutMinutes();
    final screenshotProtection = await isScreenshotProtectionEnabled(libraryId: libraryId);

    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
        _hasPin = hasPin;
        _autoLockMinutes = timeout;
        _screenshotProtectionEnabled = screenshotProtection;
        _loading = false;
      });
    }
  }

  Future<void> _toggleScreenshotProtection(bool value) async {
    setState(() => _screenshotProtectionEnabled = value);
    final libraryId = widget.libraryId ?? ref.read(currentLibraryIdProvider);
    await setScreenshotProtectionEnabled(value, libraryId: libraryId);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final available = await BiometricService.isBiometricAvailable();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No biometric hardware detected or no fingerprint/face enrolled in device settings.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      // Test biometric authentication before enabling
      final success = await BiometricService.authenticate(
        reason: widget.isStudent
            ? 'Scan fingerprint or Face ID to protect your student pass'
            : 'Scan fingerprint or Face ID to enable admin app lock',
      );
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric verification cancelled or failed. Not enabled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    await BiometricService.setBiometricEnabled(
      value,
      userId: _effectiveUserId,
      authUid: widget.authUid,
      candidateIds: _candidateIds,
    );

    final libraryId = widget.libraryId ?? ref.read(currentLibraryIdProvider);
    if (!widget.isStudent) {
      if (libraryId != null && libraryId.isNotEmpty) {
        BiometricService.syncSecuritySettingsToFirestore(libraryId).catchError((_) {});
      }
    } else if (widget.studentId != null && libraryId != null && libraryId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId!)
          .update({'biometricEnabled': value}).catchError((_) {});
    }

    setState(() => _biometricEnabled = value);
  }

  Future<void> _showSetPinDialog() async {
    final libraryId = widget.libraryId ?? ref.read(currentLibraryIdProvider);
    final pinSet = await SecuritySettingsDialog.showSetPinDialog(
      context,
      isStudent: widget.isStudent,
      studentId: widget.studentId,
      authUid: widget.authUid,
      libraryId: libraryId,
      candidateIds: _candidateIds,
      isChanging: _hasPin,
    );

    if (pinSet && mounted) {
      setState(() {
        _hasPin = true;
        _successBannerMessage = _hasPin
            ? 'Security PIN configured and active! 🔒'
            : 'Security PIN updated and active! 🔒';
      });

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _successBannerMessage = null);
      });

      await _loadState();
    }
  }

  Future<void> _removePin() async {
    await BiometricService.clearPin(
      userId: _effectiveUserId,
      authUid: widget.authUid,
      candidateIds: _candidateIds,
    );

    final libraryId = widget.libraryId ?? ref.read(currentLibraryIdProvider);
    if (!widget.isStudent) {
      if (libraryId != null && libraryId.isNotEmpty) {
        BiometricService.clearPinFromFirestore(libraryId).catchError((_) {});
      }
    } else if (widget.studentId != null && libraryId != null && libraryId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId!)
          .update({'pinHash': FieldValue.delete()}).catchError((_) {});
      final currentAuthUid = widget.authUid ?? FirebaseAuth.instance.currentUser?.uid;
      if (currentAuthUid != null && currentAuthUid.isNotEmpty) {
        FirebaseFirestore.instance.collection('users').doc(currentAuthUid).update({'pinHash': FieldValue.delete()}).catchError((_) {});
      }
    }

    _loadState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Security PIN removed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.isStudent ? 'Personal App Security' : 'Admin App Security';
    final subtitle = widget.isStudent
        ? 'Protect your digital student pass and personal details on this device.'
        : 'Protect your library financial and student records when your device is unattended.';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _loading
              ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.isStudent
                                ? Colors.teal.withValues(alpha: 0.15)
                                : theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.security_rounded,
                            color: widget.isStudent ? Colors.teal : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 12),

                    // Success Feedback Banner
                    if (_successBannerMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _successBannerMessage!,
                                style: const TextStyle(
                                  color: Color(0xFF047857),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Scrollable Settings Items
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Screenshot Protection Toggle — ONLY visible to Admin (library policy enforced)
                            if (!widget.isStudent) ...[
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                secondary: const Icon(Icons.screenshot_monitor_rounded),
                                title: const Text('Screenshot Protection', style: TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: const Text(
                                  'Prevents screenshots & screen recording in the app. '
                                  'Enforced on: Payment, Receipt, ID Card, and Student financial screens.',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: _screenshotProtectionEnabled,
                                onChanged: _toggleScreenshotProtection,
                              ),
                              const Divider(),
                            ],

                            // Biometric Toggle
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(Icons.fingerprint_rounded),
                              title: const Text('Biometric Lock', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                _biometricAvailable
                                    ? 'Unlock with Fingerprint or Face ID'
                                    : 'Biometrics not available on this device',
                                style: const TextStyle(fontSize: 12),
                              ),
                              value: _biometricEnabled && _biometricAvailable,
                              onChanged: _biometricAvailable ? _toggleBiometric : null,
                            ),

                            const Divider(),

                            // PIN Management with Full Width Responsive Layout
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.pin_rounded, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.isStudent ? 'Personal 4-Digit PIN' : 'Admin 4-Digit Security PIN',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _hasPin ? 'PIN is configured & active' : 'No PIN configured',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _hasPin ? const Color(0xFF059669) : theme.colorScheme.outline,
                                                fontWeight: _hasPin ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 36),
                                    child: _hasPin
                                        ? Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.edit_outlined, size: 14),
                                                label: const Text('Change PIN', style: TextStyle(fontSize: 12)),
                                                onPressed: _showSetPinDialog,
                                              ),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  foregroundColor: Colors.red.shade700,
                                                  side: BorderSide(color: Colors.red.shade200),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.delete_outline, size: 14),
                                                label: const Text('Remove', style: TextStyle(fontSize: 12)),
                                                onPressed: _removePin,
                                              ),
                                            ],
                                          )
                                        : FilledButton.tonalIcon(
                                            style: FilledButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            icon: const Icon(Icons.add_rounded, size: 16),
                                            label: const Text('Set PIN', style: TextStyle(fontSize: 12)),
                                            onPressed: _showSetPinDialog,
                                          ),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(),

                            // Auto-lock Timeout Dropdown with Responsive Layout
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 24),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Auto-Lock After', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        SizedBox(height: 2),
                                        Text('When app moves to background', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _autoLockMinutes,
                                        isDense: true,
                                        items: const [
                                          DropdownMenuItem(value: 0, child: Text('Immediately', style: TextStyle(fontSize: 13))),
                                          DropdownMenuItem(value: 2, child: Text('2 Minutes', style: TextStyle(fontSize: 13))),
                                          DropdownMenuItem(value: 5, child: Text('5 Minutes', style: TextStyle(fontSize: 13))),
                                          DropdownMenuItem(value: 15, child: Text('15 Minutes', style: TextStyle(fontSize: 13))),
                                        ],
                                        onChanged: (val) async {
                                          if (val != null) {
                                            await BiometricService.setAutoLockTimeoutMinutes(val);
                                            if (!widget.isStudent) {
                                              final libraryId = ref.read(currentLibraryIdProvider);
                                              if (libraryId != null && libraryId.isNotEmpty) {
                                                BiometricService.syncSecuritySettingsToFirestore(libraryId).catchError((_) {});
                                              }
                                            }
                                            setState(() => _autoLockMinutes = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
