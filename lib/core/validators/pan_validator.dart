import '../constants/regex_patterns.dart';

class PanValidator {
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a PAN card number.';
    }

    final cleanValue = value.toUpperCase().replaceAll(RegExp(r'\s+'), '');

    if (cleanValue.length != 10) {
      return 'Please enter a valid 10-character PAN card number.';
    }

    if (!RegExp(RegexPatterns.pan).hasMatch(cleanValue)) {
      return 'Please enter a valid PAN card number (e.g., ABCDE1234F).';
    }

    return null;
  }
}
