import 'package:intl/intl.dart';

class AppDateUtils {
  static const String _dateFormat = 'dd/MM/yyyy';
  static const String _dateTimeFormat = 'dd/MM/yyyy hh:mm a';

  /// Formats date to DD/MM/YYYY for Indian locale
  static String formatDate(DateTime date) {
    return DateFormat(_dateFormat).format(date);
  }

  /// Formats datetime to DD/MM/YYYY hh:mm a
  static String formatDateTime(DateTime date) {
    return DateFormat(_dateTimeFormat).format(date);
  }

  /// Parses Indian date format string to DateTime
  static DateTime? parseDate(String dateString) {
    try {
      return DateFormat(_dateFormat).parseStrict(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Calculates age based on Date of Birth
  static int calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Checks if a date has expired
  static bool isExpired(DateTime expiryDate) {
    return DateTime.now().isAfter(expiryDate);
  }

  /// Returns days until the expiry date
  static int daysUntilExpiry(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    return difference.inDays;
  }

  /// Gets the end date of the grace period
  static DateTime getGracePeriodEnd(DateTime expiryDate, int graceDays) {
    return expiryDate.add(Duration(days: graceDays));
  }

  /// Checks if currently in grace period
  static bool isInGracePeriod(DateTime expiryDate, int graceDays) {
    final now = DateTime.now();
    final graceEnd = getGracePeriodEnd(expiryDate, graceDays);
    return now.isAfter(expiryDate) && now.isBefore(graceEnd);
  }

  /// Returns relative time string like "2 days ago", "just now"
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? "minute" : "minutes"} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} ${difference.inDays == 1 ? "day" : "days"} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? "month" : "months"} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? "year" : "years"} ago';
    }
  }
}
