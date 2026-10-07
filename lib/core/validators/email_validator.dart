import '../constants/regex_patterns.dart';

class EmailValidator {
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an email address.';
    }

    if (!RegExp(RegexPatterns.email).hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }

    return null;
  }
}
