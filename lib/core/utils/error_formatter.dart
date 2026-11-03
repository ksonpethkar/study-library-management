/// Formats raw technical exceptions into friendly, non-technical human language
/// inspired by leading apps (Stripe, Airbnb, Uber, Apple) so users and admins
/// never see raw stack traces, database codes like [cloud_firestore/permission-denied], or system jargon.
class AppErrorFormatter {
  static String toUserFriendly(dynamic error, {String? actionContext}) {
    if (error == null) return 'An unexpected error occurred. Please try again.';
    final str = error.toString().toLowerCase();

    // Context-specific friendly handling:
    if (actionContext == 'feedback' || actionContext == 'suggestion' || actionContext == 'issue') {
      if (str.contains('permission-denied') || str.contains('unauthorized')) {
        return 'Unable to submit your feedback right now. Please ensure you are signed in or contact the library desk.';
      }
      if (str.contains('network') || str.contains('socket') || str.contains('offline') || str.contains('timeout')) {
        return 'Network issue. Your feedback could not be sent. Please check your internet connection and try again.';
      }
      return 'Unable to submit your feedback right now. Please try again shortly or speak to library staff.';
    }

    if (actionContext == 'seat' || actionContext == 'request') {
      if (str.contains('permission-denied') || str.contains('unauthorized')) {
        return 'Unable to submit seat request. Please ensure your student pass is active or visit the library desk.';
      }
      if (str.contains('occupied') || str.contains('already')) {
        return 'This study desk was just assigned to another student. Please select an available seat.';
      }
    }

    if (actionContext == 'payment' || actionContext == 'fee') {
      if (str.contains('permission-denied') || str.contains('unauthorized')) {
        return 'You do not have permission to record payments. Please check with the library owner.';
      }
      return 'Payment could not be recorded. Please verify the amount and payment details and try again.';
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
}
