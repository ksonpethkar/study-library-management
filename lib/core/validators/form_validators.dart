import '../constants/regex_patterns.dart';
import 'phone_validator.dart';
import 'aadhaar_validator.dart';
import 'pan_validator.dart';
import 'dl_validator.dart';
import 'email_validator.dart';
import 'pincode_validator.dart';

class FormValidators {
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a name.';
    }
    
    if (value.trim().length < 2) {
      return 'Name is too short. Please enter at least 2 characters.';
    }
    
    if (value.trim().length > 100) {
      return 'Name is too long. Please keep it under 100 characters.';
    }

    if (!RegExp(RegexPatterns.name).hasMatch(value.trim())) {
      return 'Please enter a valid name using only letters and spaces.';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an amount.';
    }
    
    if (!RegExp(RegexPatterns.amount).hasMatch(value.trim())) {
      return 'Please enter a valid amount (e.g., 500 or 500.50).';
    }
    return null;
  }

  static String? validatePhone(String? value) => PhoneValidator.validate(value);
  static String? validateAadhaar(String? value) => AadhaarValidator.validate(value);
  static String? validatePan(String? value) => PanValidator.validate(value);
  static String? validateDrivingLicence(String? value) => DlValidator.validate(value);
  static String? validateEmail(String? value) => EmailValidator.validate(value);
  static String? validatePincode(String? value) => PincodeValidator.validate(value);
}
