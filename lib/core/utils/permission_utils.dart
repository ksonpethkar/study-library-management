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
    final status = await permission.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showDeniedDialog(context, title, 'You have permanently denied this permission. Please enable it in app settings.');
      return false;
    }

    if (!context.mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(rationale),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not Now')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
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
      'We need camera access to let you scan ID cards or take profile pictures of students.',
    );
  }

  static Future<bool> requestStoragePermission(BuildContext context) async {
    return await _requestWithPrePrompt(
      context,
      Permission.storage, // Using general storage, manage properly based on Android API level
      'Storage Permission',
      'We need storage access to save receipts, backups, and upload documents.',
    );
  }

  static Future<bool> requestNotificationPermission(BuildContext context) async {
    return await _requestWithPrePrompt(
      context,
      Permission.notification,
      'Notifications',
      'Enable notifications to receive alerts for expiring plans and low seats.',
    );
  }

  static Future<PermissionStatus> checkPermission(Permission permission) async {
    return await permission.status;
  }
}
