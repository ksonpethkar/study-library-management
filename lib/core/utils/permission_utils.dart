import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionUtils {
  PermissionUtils._();

  /// Prompts user with rationale before requesting permission, returns true if granted.
  static Future<bool> _requestWithPrePrompt(
    BuildContext context, 
    Permission permission,
    String title,
    String rationale,
  ) async {
    if (kIsWeb) return true; // Web browsers prompt natively at hardware access point

    final status = await permission.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showDeniedDialog(context, title, 'Permission was denied. Please enable it in system app settings.');
      return false;
    }

    if (!context.mounted) return false;
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.security_rounded, color: theme.colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  rationale,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Continue'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Not Now'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (proceed == true) {
      final newStatus = await permission.request();
      if (newStatus.isGranted) return true;
      
      if (newStatus.isPermanentlyDenied) {
        if (!context.mounted) return false;
        await _showDeniedDialog(context, title, 'Permission is required to proceed. Please enable it in app settings.');
      }
    }
    return false;
  }

  static Future<void> _showDeniedDialog(BuildContext context, String title, String message) async {
    if (kIsWeb) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title Denied'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            }, 
            child: const Text('Open Settings')
          ),
        ],
      ),
    );
  }

  static Future<bool> requestCameraPermission(BuildContext context) async {
    return await _requestWithPrePrompt(
      context,
      Permission.camera,
      'Camera Permission',
      'We need camera access to scan attendance QR codes and capture student profile pictures.',
    );
  }

  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      // Modern Android 13+ (API 33+) Scoped Storage does not require storage permissions
      return true;
    }
    return true;
  }

  static Future<bool> requestNotificationPermission(BuildContext context) async {
    return await _requestWithPrePrompt(
      context,
      Permission.notification,
      'Notifications & Alerts',
      'Enable alerts for membership validity, seat renewal notices, payment receipts, and emergency announcements.',
    );
  }

  static Future<PermissionStatus> checkPermission(Permission permission) async {
    if (kIsWeb) return PermissionStatus.granted;
    return await permission.status;
  }
}
