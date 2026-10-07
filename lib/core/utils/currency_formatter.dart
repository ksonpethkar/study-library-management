import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Format amount in Indian Rupees (e.g. ₹1,500.00)
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Format amount compactly (e.g. ₹1.5K, ₹2.3L)
  static String formatCurrencyCompact(double amount) {
    final formatter = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 1,
    );
    // intl uses 'T' for thousands in some cases, replace with 'K' if needed
    return formatter.format(amount).replaceAll('T', 'K');
  }

  /// Parse currency string to double
  static double? parseCurrency(String text) {
    try {
      final cleanText = text.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.parse(cleanText);
    } catch (e) {
      return null;
    }
  }
}
