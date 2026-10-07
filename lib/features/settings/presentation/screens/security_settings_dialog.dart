import 'package:flutter/material.dart';
import 'package:study_library/services/biometric_service.dart';

class SecuritySettingsDialog extends StatefulWidget {
  const SecuritySettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const SecuritySettingsDialog(),
    );
  }

  @override
  State<SecuritySettingsDialog> createState() => _SecuritySettingsDialogState();
}

class _SecuritySettingsDialogState extends State<SecuritySettingsDialog> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _hasPin = false;
  int _autoLockMinutes = 2;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final available = await BiometricService.isBiometricAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    final hasPin = await BiometricService.hasPin();
    final timeout = await BiometricService.getAutoLockTimeoutMinutes();

    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
        _hasPin = hasPin;
        _autoLockMinutes = timeout;
        _loading = false;
      });
    }
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
        reason: 'Scan fingerprint or Face ID to enable app lock',
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
    await BiometricService.setBiometricEnabled(value);
    setState(() => _biometricEnabled = value);
  }

  Future<void> _showSetPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set 4-Digit Security PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Enter 4-Digit PIN',
                counterText: '',
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
              decoration: const InputDecoration(
                labelText: 'Confirm 4-Digit PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              if (pin.length != 4) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('PIN must be exactly 4 digits')),
                );
                return;
              }
              if (pin != confirm) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('PINs do not match')),
                );
                return;
              }
              await BiometricService.setPin(pin);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              if (!mounted) return;
              _loadState();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Security PIN set successfully!')),
              );
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _removePin() async {
    await BiometricService.clearPin();
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _loading
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.security_rounded, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Admin App Security',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Protect your library financial and student records when your device is unattended.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 16),

                  // Biometric Toggle
                  SwitchListTile(
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

                  // PIN Management
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pin_rounded),
                    title: const Text('4-Digit Security PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _hasPin ? 'PIN is configured' : 'No PIN configured',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: _hasPin
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(onPressed: _showSetPinDialog, child: const Text('Change')),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: _removePin,
                              ),
                            ],
                          )
                        : FilledButton.tonal(
                            onPressed: _showSetPinDialog,
                            child: const Text('Set PIN'),
                          ),
                  ),

                  const Divider(),

                  // Auto-lock Timeout Dropdown
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Auto-Lock After', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('When app moves to background', style: TextStyle(fontSize: 12)),
                    trailing: DropdownButton<int>(
                      value: _autoLockMinutes,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Immediately')),
                        DropdownMenuItem(value: 2, child: Text('2 Minutes')),
                        DropdownMenuItem(value: 5, child: Text('5 Minutes')),
                        DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await BiometricService.setAutoLockTimeoutMinutes(val);
                          setState(() => _autoLockMinutes = val);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
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
    );
  }
}
