import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'app_exception.dart';

class ErrorHandler {
  ErrorHandler._();

  static String handleError(dynamic error, [StackTrace? stack]) {
    String userMessage = "Something went wrong. Please try again.";

    if (error == null) return userMessage;

    final errStr = error.toString().toLowerCase();

    // Check for offline / network issues
    if (errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('network_error') ||
        errStr.contains('clientexception') ||
        errStr.contains('httpexception')) {
      return "Unable to connect to the network. Please check your internet connection.";
    }

    if (errStr.contains('formatexception')) {
      return "The entered details are in an invalid format. Please check and try again.";
    }

    if (error is AppException) {
      userMessage = error.userMessage;
    } else if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          userMessage = "You don't have permission to perform this action.";
          break;
        case 'not-found':
          userMessage = "The item you're looking for doesn't exist or has been removed.";
          break;
        case 'unavailable':
          userMessage = "Our cloud servers are temporarily unavailable. Please try again in a moment.";
          break;
        case 'unauthenticated':
          userMessage = "Your session has expired. Please sign in again.";
          break;
        case 'resource-exhausted':
          userMessage = "The system is currently busy. Please wait a moment and try again.";
          break;
        default:
          userMessage = error.message?.isNotEmpty == true
              ? error.message!
              : "A network error occurred. Please try again.";
      }
    } else if (error is Exception) {
      var raw = error.toString().replaceFirst('Exception: ', '').trim();
      if (raw.startsWith('[') && raw.contains('] ')) {
        raw = raw.substring(raw.indexOf('] ') + 2);
      }
      userMessage = raw.isNotEmpty ? raw : "An unexpected issue occurred. Please try again.";
    } else if (error is String) {
      userMessage = error;
    }

    // Log the error
    if (kDebugMode) {
      debugPrint('ErrorHandler caught: $error');
      if (stack != null) debugPrint('Stack: $stack');
    } else {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, reason: 'ErrorHandler handled exception', fatal: false);
      } catch (_) {}
    }

    return userMessage;
  }
}

/// Universal, clean, non-technical floating SnackBar helper
class AppSnackbar {
  AppSnackbar._();

  static void showError(BuildContext context, dynamic error, {String? defaultMessage}) {
    if (!context.mounted) return;
    final message = defaultMessage ?? ErrorHandler.handleError(error);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
