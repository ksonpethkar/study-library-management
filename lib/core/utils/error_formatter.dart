/// Formats raw technical exceptions into friendly, non-technical human language
/// so that users and admins never see raw stack traces, database codes, or system jargon.
class AppErrorFormatter {
  static String toUserFriendly(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';
    final str = error.toString().toLowerCase();

    // Permissions & Authentication
    if (str.contains('permission-denied') || str.contains('unauthorized')) {
      return 'You do not have permission to perform this action. Please check your assigned role.';
    }
    if (str.contains('user-not-found') || str.contains('sign_in_failed') || str.contains('invalid-credential')) {
      return 'Sign-in failed. Please verify your Google account or connection and try again.';
    }

    // Network & Connectivity
    if (str.contains('network') ||
        str.contains('socket') ||
        str.contains('connection') ||
        str.contains('timeout') ||
        str.contains('offline')) {
      return 'Internet connection error. Please check your network and try again.';
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

    // Clean standard Exception: prefix if custom message is already readable
    final clean = error.toString().replaceAll('Exception: ', '').trim();
    if (clean.isNotEmpty && !clean.contains('[') && clean.length < 80) {
      return clean;
    }

    return 'Action could not be completed. Please try again or contact support.';
  }
}
