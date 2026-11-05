import 'package:flutter/material.dart';

/// Formats raw technical exceptions into friendly, non-technical human language
/// inspired by leading apps (Stripe, Airbnb, Google Pay) so users and admins
/// never see raw stack traces, database codes like [cloud_firestore/permission-denied], or system jargon.
class AppErrorFormatter {
  static String toUserFriendly(dynamic error, {String? actionContext}) {
    if (error == null) return 'An unexpected error occurred. Please try again.';
    final str = error.toString().toLowerCase();

    // Context-specific friendly handling:
    if (actionContext == 'auth' || actionContext == 'login') {
      if (str.contains('user-not-found') || str.contains('invalid-credential') || str.contains('wrong-password')) {
        return 'Account not recognized. If you are a new student, please complete registration or speak to the library desk.';
      }
      if (str.contains('popup_closed') || str.contains('cancelled') || str.contains('canceled')) {
        return 'Sign-in cancelled. Please choose your Google account to proceed.';
      }
      if (str.contains('network') || str.contains('socket') || str.contains('timeout')) {
        return 'Network error during sign-in. Please check your connection and try again.';
      }
      return 'Sign-in could not be completed. Please try again or contact the study centre administrator.';
    }

    if (actionContext == 'feedback' || actionContext == 'suggestion' || actionContext == 'issue') {
      if (str.contains('permission-denied') || str.contains('unauthorized')) {
        return 'Unable to submit feedback right now. Please ensure you are signed in or contact the library desk.';
      }
      if (str.contains('network') || str.contains('socket') || str.contains('offline') || str.contains('timeout')) {
        return 'Network issue. Your feedback could not be sent. Please check your internet connection and try again.';
      }
      return 'Unable to submit your feedback right now. Please try again shortly or speak to library staff.';
    }

    if (actionContext == 'seat' || actionContext == 'request' || actionContext == 'section') {
      if (str.contains('permission-denied') || str.contains('unauthorized')) {
        return 'Unable to update seat details. Please ensure your pass is active or visit the library desk.';
      }
      if (str.contains('occupied') || str.contains('already')) {
        return 'This study desk was just assigned to another student. Please select an available seat.';
      }
      if (actionContext == 'section') {
        return 'Unable to save section layout. Please check the rows and columns and try again.';
      }
    }

    if (actionContext == 'payment' || actionContext == 'fee') {
      if (str.contains('permission-denied') || str.contains('unauthorized')) {
        return 'You do not have permission to record payments. Please check with the library owner.';
      }
      return 'Payment could not be recorded. Please verify the amount and payment details and try again.';
    }

    if (actionContext == 'receipt') {
      if (str.contains('network') || str.contains('socket') || str.contains('lookup') || str.contains('clientexception')) {
        return 'Network connection dropped while generating receipt. Please check your internet connection.';
      }
      return 'Unable to generate receipt PDF. Please try again or download from your payment history.';
    }

    if (actionContext == 'student') {
      if (str.contains('permission-denied') || str.contains('unauthorized')) {
        return 'Permission denied. Only authorized staff can update student profiles.';
      }
      return 'Unable to save student details. Please verify that all required fields are filled and try again.';
    }

    if (actionContext == 'announcement') {
      return 'Unable to update announcements. Please check your connection and try again.';
    }

    if (actionContext == 'plan') {
      return 'Unable to save membership plan. Please verify the price and duration.';
    }

    if (actionContext == 'expense') {
      return 'Unable to save expense entry. Please check the amount and category.';
    }

    if (actionContext == 'backup') {
      return 'Backup or restore operation could not be completed. Please check your network and try again.';
    }

    if (actionContext == 'holiday') {
      return 'Unable to update holiday schedule. Please try again.';
    }

    if (actionContext == 'gov_id' || actionContext == 'id_card' || actionContext == 'document') {
      if (str.contains('permission') || str.contains('denied')) {
        return 'Permission was not granted. Please allow camera or file access in your browser/device settings.';
      }
      if (str.contains('camera') || str.contains('hardware') || str.contains('media') || str.contains('notreadable')) {
        return 'Camera was unavailable. Please choose an ID photo or PDF file from your device.';
      }
      return 'Could not read text automatically from the ID. Please verify details in the form or try a clearer photo.';
    }

    if (actionContext == 'camera' || str.contains('notreadableerror') || str.contains('video source') || str.contains('camera')) {
      if (str.contains('notreadableerror') || str.contains('video source')) {
        return 'Camera is being used by another tab or app. Please close other camera tabs and tap Retry.';
      }
      if (str.contains('permission') || str.contains('denied')) {
        return 'Camera permission was not granted. Please allow camera access in your browser or device settings.';
      }
      if (actionContext == 'admin_qr') {
        return 'Camera is temporarily unavailable on this device. You can look up the student manually.';
      }
      return 'Camera is temporarily unavailable on this device. Please select an image or document from your device.';
    }

    // Permissions & Authentication
    if (str.contains('permission-denied') || str.contains('unauthorized') || str.contains('insufficient permissions')) {
      return 'Action not permitted with your current account. Please sign in or contact the desk manager.';
    }
    if (str.contains('unauthenticated') || str.contains('session-expired')) {
      return 'Your session has expired. Please sign in again to continue.';
    }
    if (str.contains('user-not-found') || str.contains('sign_in_failed') || str.contains('invalid-credential')) {
      return 'Sign-in failed. Please verify your Google account or connection and try again.';
    }

    // Network & Connectivity
    if (str.contains('network') ||
        str.contains('socket') ||
        str.contains('connection') ||
        str.contains('timeout') ||
        str.contains('offline') ||
        str.contains('failed host lookup') ||
        str.contains('clientexception')) {
      return 'Internet connection error. Please check your Wi-Fi or mobile data and try again.';
    }

    // Server Busy / Quota
    if (str.contains('resource-exhausted') || str.contains('quota') || str.contains('unavailable')) {
      return 'The library system is experiencing high traffic. Please wait a moment and try again.';
    }

    // Not found / Deleted
    if (str.contains('not-found') || str.contains('not found') || str.contains('does not exist')) {
      return 'The requested record could not be found or has been removed.';
    }

    // Duplicate records
    if (str.contains('already-exists') || str.contains('already exists')) {
      return 'A record with this information already exists in the system.';
    }

    // Seat conflicts
    if (str.contains('occupied') || str.contains('seat already')) {
      return 'This seat is already occupied by another student. Please select an available seat.';
    }

    // Form inputs
    if (str.contains('phone') || str.contains('mobile')) {
      return 'Please enter a valid 10-digit mobile number.';
    }
    if (str.contains('email')) {
      return 'Please enter a valid email address.';
    }

    // Clean standard Exception: prefix if custom message is already readable and does not contain brackets or technical paths
    String clean = error.toString().replaceAll('Exception: ', '').trim();
    if (clean.contains('[') && clean.contains(']')) {
      clean = clean.replaceAll(RegExp(r'\[.*?\]'), '').trim();
    }
    if (clean.isNotEmpty &&
        !clean.contains('/') &&
        !clean.contains('PlatformException') &&
        !clean.contains('cloud_firestore') &&
        clean.length < 90) {
      return clean;
    }

    return 'Action could not be completed. Please try again or contact the study centre desk.';
  }

  /// Displays an empathetic floating error SnackBar with an optional Retry button
  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    String? actionContext,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    final message = toUserFriendly(error, actionContext: actionContext);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.amber,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
