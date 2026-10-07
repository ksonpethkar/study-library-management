import '../constants/regex_patterns.dart';

class DlValidator {
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a Driving Licence number.';
    }

    final cleanValue = value.toUpperCase().replaceAll(RegExp(r'\s+'), '');

    if (!RegExp(RegexPatterns.drivingLicence).hasMatch(cleanValue)) {
      return 'Please enter a valid Driving Licence number.';
    }

    return null;
  }
}
