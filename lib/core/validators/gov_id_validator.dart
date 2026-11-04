import 'package:flutter/services.dart';
import 'package:study_library/core/constants/regex_patterns.dart';
import 'package:study_library/models/student_model.dart';

/// Custom TextInputFormatter to force uppercase as user types.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Custom TextInputFormatter to automatically format 12-digit Aadhaar with standard 4-4-4 spacing: XXXX XXXX XXXX
class AadhaarInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 12) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Centralized Real-Time Validator & Input Formatter for all Indian Government IDs.
/// Handles: Aadhaar, PAN, Driving Licence, Voter ID (EPIC), Passport, College ID, Other.
class GovIdValidator {
  /// Validate format according to [GovIdType].
  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validate(
    GovIdType type,
    String? value, {
    bool isRequired = true,
  }) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) {
      return isRequired ? 'Please enter ${type.displayName} number' : null;
    }

    switch (type) {
      case GovIdType.aadhaar:
        final digitsOnly = clean.replaceAll(RegExp(r'\s+'), '');
        if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) {
          return 'Aadhaar must contain only numbers';
        }
        if (digitsOnly.length != 12) {
          return 'Aadhaar must be 12 digits (e.g. 5482 1234 5678)';
        }
        if (digitsOnly.startsWith('0') || digitsOnly.startsWith('1')) {
          return 'Aadhaar cannot begin with 0 or 1';
        }
        return null;

      case GovIdType.pan:
        final pan = clean.toUpperCase().replaceAll(RegExp(r'\s+'), '');
        if (pan.length != 10) {
          return 'Enter 10-character PAN (e.g. ABCDE1234F)';
        }
        if (!RegExp(RegexPatterns.pan).hasMatch(pan)) {
          return 'Invalid PAN format. Expected 5 letters, 4 numbers, 1 letter (e.g. ABCDE1234F)';
        }
        return null;

      case GovIdType.drivingLicence:
        final dl = clean.toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '');
        if (dl.length < 10 || dl.length > 18) {
          return 'Enter valid Driving Licence (e.g. MH12 20210001234)';
        }
        if (!RegExp(r'^[A-Z]{2}[0-9A-Z]{8,16}$').hasMatch(dl)) {
          return 'Invalid Driving Licence format (e.g. MH12 20210001234)';
        }
        return null;

      case GovIdType.voterId:
        final epic = clean.toUpperCase().replaceAll(RegExp(r'\s+'), '');
        if (epic.length != 10) {
          return 'Enter 10-character Voter ID (e.g. ABC1234567)';
        }
        if (!RegExp(RegexPatterns.voterId).hasMatch(epic)) {
          return 'Invalid Voter ID. Expected 3 letters + 7 numbers (e.g. ABC1234567)';
        }
        return null;

      case GovIdType.passport:
        final passport = clean.toUpperCase().replaceAll(RegExp(r'\s+'), '');
        if (passport.length != 8) {
          return 'Enter 8-character Passport number (e.g. A1234567)';
        }
        if (!RegExp(RegexPatterns.passport).hasMatch(passport)) {
          return 'Invalid Passport. Expected 1 letter + 7 numbers (e.g. A1234567)';
        }
        return null;

      case GovIdType.collegeId:
        if (clean.length < 2) {
          return 'College ID / Roll No must be at least 2 characters';
        }
        if (clean.length > 30) {
          return 'College ID is too long (max 30 characters)';
        }
        return null;

      case GovIdType.other:
        if (clean.length < 3) {
          return 'Government ID must be at least 3 characters';
        }
        if (clean.length > 35) {
          return 'ID number is too long (max 35 characters)';
        }
        return null;
    }
  }

  /// Real-time boolean check for showing visual confirmation (e.g. Green checkmark icon).
  static bool isValid(GovIdType type, String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return validate(type, value, isRequired: true) == null;
  }

  /// Clean & format an ID value before persisting or validating.
  static String format(GovIdType type, String value) {
    final trimmed = value.trim();
    switch (type) {
      case GovIdType.aadhaar:
        // Group into 4-digit blocks: 1234 5678 9012
        final digits = trimmed.replaceAll(RegExp(r'\D'), '');
        if (digits.length <= 4) return digits;
        if (digits.length <= 8) return '${digits.substring(0, 4)} ${digits.substring(4)}';
        final end = digits.length > 12 ? 12 : digits.length;
        return '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8, end)}';

      case GovIdType.pan:
      case GovIdType.drivingLicence:
      case GovIdType.voterId:
      case GovIdType.passport:
        return trimmed.toUpperCase();

      case GovIdType.collegeId:
      case GovIdType.other:
        return trimmed;
    }
  }

  /// Input formatters for real-time text field enforcement.
  static List<TextInputFormatter> inputFormatters(GovIdType type) {
    switch (type) {
      case GovIdType.aadhaar:
        return [
          AadhaarInputFormatter(),
          LengthLimitingTextInputFormatter(14), // 12 digits + 2 spaces
        ];

      case GovIdType.pan:
        return [
          UpperCaseTextFormatter(),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(10),
        ];

      case GovIdType.voterId:
        return [
          UpperCaseTextFormatter(),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(10),
        ];

      case GovIdType.passport:
        return [
          UpperCaseTextFormatter(),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(8),
        ];

      case GovIdType.drivingLicence:
        return [
          UpperCaseTextFormatter(),
          LengthLimitingTextInputFormatter(20),
        ];

      case GovIdType.collegeId:
        return [
          LengthLimitingTextInputFormatter(30),
        ];

      case GovIdType.other:
        return [
          LengthLimitingTextInputFormatter(35),
        ];
    }
  }

  /// Keyboard type for text input.
  static TextInputType keyboardType(GovIdType type) {
    return type == GovIdType.aadhaar ? TextInputType.number : TextInputType.text;
  }

  /// Capitalization style.
  static TextCapitalization textCapitalization(GovIdType type) {
    switch (type) {
      case GovIdType.pan:
      case GovIdType.voterId:
      case GovIdType.passport:
      case GovIdType.drivingLicence:
        return TextCapitalization.characters;
      case GovIdType.collegeId:
        return TextCapitalization.characters;
      default:
        return TextCapitalization.none;
    }
  }
}
