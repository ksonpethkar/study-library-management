import '../constants/regex_patterns.dart';

class PhoneValidator {
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a mobile number.';
    }
    
    final cleanValue = value.replaceAll(RegExp(r'\s+'), '');
    
    if (cleanValue.length != 10) {
      return 'Please enter a valid 10-digit mobile number.';
    }
    
    if (!RegExp(RegexPatterns.phone).hasMatch(cleanValue)) {
      return 'Please enter a valid Indian mobile number starting with 6-9.';
    }
    
    return null;
  }
}
