import '../constants/regex_patterns.dart';

class PincodeValidator {
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a PIN code.';
    }

    final cleanValue = value.replaceAll(RegExp(r'\s+'), '');

    if (cleanValue.length != 6) {
      return 'Please enter a valid 6-digit PIN code.';
    }

    if (!RegExp(RegexPatterns.pincode).hasMatch(cleanValue)) {
      return 'Please enter a valid Indian PIN code.';
    }

    return null;
  }
}
