import 'package:flutter/services.dart';
import 'package:study_library/core/constants/regex_patterns.dart';

/// Centralized, production-grade validation and input formatter library for Cozy Corner.
/// Covers all fields across Student Management, Financial Accounting, Catalog,
/// Operations, Hardware/Seats, and Administrative Settings.
class AppValidators {
  AppValidators._();

  // ---------------------------------------------------------------------------
  // Input Formatters
  // ---------------------------------------------------------------------------

  /// Only numeric digits.
  static final TextInputFormatter digitsOnly = FilteringTextInputFormatter.digitsOnly;

  /// Standard 10-digit Indian mobile number formatter.
  static final List<TextInputFormatter> phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  /// Standard 6-digit Indian postal PIN code formatter.
  static final List<TextInputFormatter> pincodeFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(6),
  ];

  /// Currency amount formatter (allows numbers with up to 2 decimal places).
  static final List<TextInputFormatter> amountFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  ];

  /// Force text to uppercase as user types.
  static final TextInputFormatter upperCase = _UpperCaseTextFormatter();

  /// Alphanumeric seat label formatter (A-Z, 0-9, hyphen, max 10 chars).
  static final List<TextInputFormatter> seatLabelFormatters = [
    _UpperCaseTextFormatter(),
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
    LengthLimitingTextInputFormatter(10),
  ];

  /// Alphanumeric transaction/UTR formatter (A-Z, 0-9, max 35 chars).
  static final List<TextInputFormatter> utrFormatters = [
    _UpperCaseTextFormatter(),
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_\-]')),
    LengthLimitingTextInputFormatter(35),
  ];

  /// Cheque number formatter (exactly 6 digits).
  static final List<TextInputFormatter> chequeFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(6),
  ];

  // ---------------------------------------------------------------------------
  // Student & Contact Validators
  // ---------------------------------------------------------------------------

  /// Person name: min 2, max 100 characters. Alphabets, spaces, dots, and hyphens.
  static String? name(
    String? value, {
    bool required = true,
    String label = 'Name',
    int min = 2,
    int max = 100,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? '$label is required' : null;
    if (v.length < min) return '$label must be at least $min characters';
    if (v.length > max) return '$label cannot exceed $max characters';
    if (RegExp(r'^\d').hasMatch(v)) return '$label cannot start with a number';
    if (!RegExp(RegexPatterns.name, unicode: true).hasMatch(v)) {
      return '$label can only contain letters, spaces, dots, and hyphens';
    }
    return null;
  }

  /// Indian mobile: 10 digits starting with 6, 7, 8, or 9.
  /// Rejects mock repeating sequences like 0000000000, 1111111111, etc.
  static String? phone(
    String? value, {
    bool required = true,
    String label = 'Mobile number',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? '$label is required' : null;

    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return '$label must be exactly 10 digits';
    if (!RegExp(RegexPatterns.phone).hasMatch(digits)) {
      return '$label must start with 6, 7, 8, or 9';
    }

    // Guard against all-same digits mock numbers (e.g. 9999999999, 8888888888)
    final first = digits[0];
    if (digits.split('').every((d) => d == first)) {
      return 'Please enter a genuine, active mobile number';
    }

    return null;
  }

  /// Emergency contact: 10-digit mobile, must NOT match student's own mobile.
  static String? emergencyPhone(
    String? value, {
    String? primaryPhone,
    bool required = false,
    String label = 'Emergency contact',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? '$label is required' : null;

    final result = phone(v, required: true, label: label);
    if (result != null) return result;

    if (primaryPhone != null && primaryPhone.trim().isNotEmpty) {
      final cleanPrimary = primaryPhone.replaceAll(RegExp(r'\D'), '');
      final cleanEmergency = v.replaceAll(RegExp(r'\D'), '');
      if (cleanPrimary.isNotEmpty && cleanPrimary == cleanEmergency) {
        return 'Emergency contact cannot be the student\'s own phone number';
      }
    }

    return null;
  }

  /// Email validation (RFC 5322).
  /// If [required] is false, validates format only when non-empty.
  static String? email(
    String? value, {
    bool required = false,
    String label = 'Email address',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? '$label is required' : null;
    if (!RegExp(RegexPatterns.email, caseSensitive: false).hasMatch(v)) {
      return 'Enter a valid email address (e.g. name@example.com)';
    }
    return null;
  }

  /// Indian 6-digit postal PIN code. First digit cannot be 0.
  static String? pinCode(
    String? value, {
    bool required = false,
    String label = 'PIN code',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? '$label is required' : null;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return '$label must be exactly 6 digits';
    if (!RegExp(RegexPatterns.pincode).hasMatch(digits)) {
      return 'Invalid PIN code. First digit must be between 1 and 9';
    }
    return null;
  }

  /// Alias for pinCode to support lowercase calling convention.
  static String? pincode(
    String? value, {
    bool required = false,
    String label = 'PIN code',
  }) => pinCode(value, required: required, label: label);

  /// Residential or institutional address (min 5, max 250 characters).
  static String? address(
    String? value, {
    bool required = false,
    String label = 'Address',
    int min = 5,
    int max = 250,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? '$label is required' : null;
    if (v.length < min) return '$label must be at least $min characters';
    if (v.length > max) return '$label cannot exceed $max characters';
    return null;
  }

  /// Date of Birth: must be in the past, age between [minAge] and [maxAge].
  static String? dob(
    DateTime? date, {
    bool required = false,
    int minAge = 5,
    int maxAge = 100,
  }) {
    if (date == null) return required ? 'Date of birth is required' : null;
    final now = DateTime.now();
    if (date.isAfter(now)) return 'Date of birth cannot be in the future';

    final ageYears = now.year - date.year - ((now.month < date.month || (now.month == date.month && now.day < date.day)) ? 1 : 0);
    if (ageYears < minAge) return 'Age must be at least $minAge years';
    if (ageYears > maxAge) return 'Please verify the entered birth year';
    return null;
  }

  /// Blood group: A+, A-, B+, B-, AB+, AB-, O+, O-.
  static String? bloodGroup(
    String? value, {
    bool required = false,
  }) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return required ? 'Blood group is required' : null;
    if (!RegExp(RegexPatterns.bloodGroup).hasMatch(v)) {
      return 'Enter a valid blood group (e.g. A+, B+, O+, AB-)';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Financial, Payment & Pricing Validators
  // ---------------------------------------------------------------------------

  /// Currency amount: must be positive number within [min] and [max], max 2 decimals.
  static String? amount(
    String? value, {
    bool required = true,
    double min = 1.0,
    double max = 99999.0,
    String label = 'Amount',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? '$label is required' : null;

    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid numeric amount';
    if (parsed < min) return '$label must be at least ₹${min.toStringAsFixed(0)}';
    if (parsed > max) return '$label cannot exceed ₹${max.toStringAsFixed(0)}';
    if (!RegExp(RegexPatterns.amount).hasMatch(v)) {
      return '$label can have at most 2 decimal places';
    }
    return null;
  }

  /// Alias for catalog price validation (> 0).
  static String? price(String? value, {bool required = true}) {
    return amount(value, required: required, min: 1.0, max: 99999.0, label: 'Price');
  }

  /// Discount: non-negative double, cannot exceed [maxAmount].
  static String? discount(
    String? value, {
    double? maxAmount,
    String label = 'Discount',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // Optional

    final parsed = double.tryParse(v);
    if (parsed == null || parsed < 0) return 'Enter a valid discount (≥ 0)';
    if (maxAmount != null && parsed > maxAmount) {
      return 'Discount cannot exceed total fee (₹${maxAmount.toStringAsFixed(0)})';
    }
    return null;
  }

  /// Bank UTR / UPI Transaction Reference (6 to 35 alphanumeric characters).
  static String? utr(
    String? value, {
    bool required = true,
    String label = 'Transaction reference / UTR',
  }) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return required ? '$label is required' : null;
    if (!RegExp(RegexPatterns.utr).hasMatch(v)) {
      return '$label must be 6 to 35 alphanumeric characters';
    }
    return null;
  }

  /// Cheque Number: exactly 6 digits.
  static String? chequeNumber(
    String? value, {
    bool required = true,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Cheque number is required' : null;
    if (!RegExp(RegexPatterns.cheque).hasMatch(v)) {
      return 'Cheque number must be exactly 6 numeric digits';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Plans, Catalog & Hardware/Seat Validators
  // ---------------------------------------------------------------------------

  /// Plan duration: positive integer between [min] and [max].
  static String? duration(
    String? value, {
    int min = 1,
    int max = 365,
    String label = 'Duration',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    final parsed = int.tryParse(v);
    if (parsed == null || parsed < min) return '$label must be at least $min';
    if (parsed > max) return '$label cannot exceed $max';
    return null;
  }

  /// College / Institute name: 2 to 100 characters.
  static String? collegeName(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'College / Institute name is required' : null;
    if (v.length < 2) return 'College name must be at least 2 characters';
    if (v.length > 100) return 'College name cannot exceed 100 characters';
    return null;
  }

  /// Year / Semester: 1 to 20 characters (e.g. "1st Year", "Sem 3", "Final").
  static String? yearOrSem(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Year / Semester is required' : null;
    if (v.length > 20) return 'Year / Sem cannot exceed 20 characters';
    return null;
  }

  /// Plan Name: 2 to 50 characters.
  static String? planName(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Plan name is required' : null;
    if (v.length < 2) return 'Plan name must be at least 2 characters';
    if (v.length > 50) return 'Plan name cannot exceed 50 characters';
    return null;
  }

  /// Section Name: 2 to 30 characters.
  static String? sectionName(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Section name is required' : null;
    if (v.length < 2) return 'Section name must be at least 2 characters';
    if (v.length > 30) return 'Section name cannot exceed 30 characters';
    return null;
  }

  /// Seat label / number (1-10 alphanumeric characters).
  static String? seatLabel(String? value, {bool required = true}) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return required ? 'Seat number is required' : null;
    if (!RegExp(RegexPatterns.seatLabel).hasMatch(v)) {
      return 'Seat number must be 1 to 10 alphanumeric characters (e.g. S-1, 101, A2)';
    }
    return null;
  }

  /// Total seat count in section: positive integer 1 to 1000.
  static String? seatCount(String? value, {int min = 1, int max = 1000}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Seat count is required';
    final parsed = int.tryParse(v);
    if (parsed == null || parsed < min) return 'Must be at least $min seat';
    if (parsed > max) return 'Cannot exceed $max seats';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Library, Tax & Identity Settings Validators
  // ---------------------------------------------------------------------------

  /// Indian GSTIN (15 characters).
  static String? gstin(String? value, {bool required = false}) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return required ? 'GSTIN is required' : null;
    if (!RegExp(RegexPatterns.gstin).hasMatch(v)) {
      return 'Enter a valid 15-character GSTIN (e.g. 27AAAAA0000A1Z5)';
    }
    return null;
  }

  /// PAN number (10 characters: 5 letters, 4 digits, 1 letter).
  static String? pan(String? value, {bool required = false}) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return required ? 'PAN is required' : null;
    if (!RegExp(RegexPatterns.pan).hasMatch(v)) {
      return 'Enter a valid 10-character PAN (e.g. ABCDE1234F)';
    }
    return null;
  }

  /// Multiplication table (d) for Verhoeff algorithm based on dihedral group D5
  static const List<List<int>> _verhoeffD = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];

  /// Permutation table (p) for Verhoeff algorithm
  static const List<List<int>> _verhoeffP = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];

  /// Inverse table (inv) for Verhoeff algorithm
  static const List<int> _verhoeffInv = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9];

  /// Official Verhoeff Algorithm Checksum validator (UIDAI Aadhaar standard).
  /// Validates that 12-digit UID numbers pass dihedral checksum verification,
  /// immediately detecting single-digit errors and digit transpositions.
  static bool validateVerhoeff(String numStr) {
    final clean = numStr.trim().replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d+$').hasMatch(clean)) return false;
    int c = 0;
    final digits = clean.split('').map(int.parse).toList().reversed.toList();
    for (int i = 0; i < digits.length; i++) {
      c = _verhoeffD[c][_verhoeffP[i % 8][digits[i]]];
    }
    return c == 0;
  }

  /// Calculates and generates the 12th Verhoeff checksum digit for any 11-digit Aadhaar prefix.
  static int generateVerhoeffCheckDigit(String prefix) {
    final clean = prefix.trim().replaceAll(RegExp(r'\s+'), '');
    int c = 0;
    final digits = clean.split('').map(int.parse).toList().reversed.toList();
    for (int i = 0; i < digits.length; i++) {
      c = _verhoeffD[c][_verhoeffP[(i + 1) % 8][digits[i]]];
    }
    return _verhoeffInv[c];
  }

  /// Aadhaar number: exactly 12 digits, cannot start with 0 or 1.
  /// Optionally enforces Verhoeff checksum algorithm verification.
  static String? aadhaar(String? value, {bool required = false, bool verifyChecksum = false}) {
    final v = value?.trim().replaceAll(RegExp(r'\s+'), '') ?? '';
    if (v.isEmpty) return required ? 'Aadhaar number is required' : null;
    if (!RegExp(r'^\d{12}$').hasMatch(v)) {
      return 'Aadhaar must be exactly 12 numeric digits';
    }
    if (v.startsWith('0') || v.startsWith('1')) {
      return 'Aadhaar cannot begin with 0 or 1';
    }
    if (verifyChecksum && !validateVerhoeff(v)) {
      return 'Invalid Aadhaar number (checksum validation failed)';
    }
    return null;
  }

  /// UPI ID / VPA.
  static String? upiId(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'UPI ID is required' : null;
    if (!RegExp(RegexPatterns.upiId).hasMatch(v)) {
      return 'Enter a valid UPI ID (e.g. library@oksbi, name@upi)';
    }
    return null;
  }

  /// Generic required validator.
  static String? required(String? value, {String label = 'This field'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    return null;
  }

  /// Validates a value against an arbitrary regular expression pattern.
  /// Used for tenant-custom dynamic fields like University Roll Number,
  /// Vehicle Registration Number, College ID, Hall Ticket, etc.
  static String? validatePattern(
    String? value,
    String? regexPattern, {
    String? errorMessage,
    bool required = false,
    String label = 'Field',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return required ? '$label is required' : null;
    }
    if (regexPattern == null || regexPattern.trim().isEmpty) {
      return null;
    }
    try {
      final reg = RegExp(regexPattern);
      if (!reg.hasMatch(v)) {
        return errorMessage ?? '$label format is invalid';
      }
    } catch (_) {
      // Invalid regex pattern configured in database, allow input rather than crashing
      return null;
    }
    return null;
  }

  /// Round monetary amount to nearest integer rupee to prevent fractional paise drift.
  static double roundRupee(double amount) {
    return amount.roundToDouble();
  }
}

/// TextInputFormatter to force uppercase characters.
class _UpperCaseTextFormatter extends TextInputFormatter {
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
