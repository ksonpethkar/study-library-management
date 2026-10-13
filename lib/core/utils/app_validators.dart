
class AppValidators {
  AppValidators._();

  /// Indian mobile: 10 digits, starts with 6–9.
  static String? phone(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Phone number is required' : null;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit mobile number';
    if (!RegExp(r'^[6-9]').hasMatch(digits)) return 'Must start with 6, 7, 8 or 9';
    return null;
  }

  /// Person name: min 2 chars, no leading digit.
  static String? name(String? value, {bool required = true, String label = 'Name'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? '$label is required' : null;
    if (v.length < 2) return '$label must be at least 2 characters';
    if (RegExp(r'^\d').hasMatch(v)) return '$label cannot start with a number';
    return null;
  }

  /// Positive price > 0.
  static String? price(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Price is required' : null;
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid number';
    if (parsed <= 0) return 'Price must be greater than 0';
    return null;
  }

  /// Email format.
  static String? email(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Email is required' : null;
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false).hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Indian 6-digit PIN.
  static String? pinCode(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'PIN code is required' : null;
    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'Enter a valid 6-digit PIN code';
    return null;
  }

  /// Aadhaar: exactly 12 digits.
  static String? aadhaar(String? value, {bool required = false}) {
    final v = value?.trim().replaceAll(' ', '') ?? '';
    if (v.isEmpty) return required ? 'Aadhaar number is required' : null;
    if (!RegExp(r'^\d{12}$').hasMatch(v)) return 'Aadhaar must be exactly 12 digits';
    return null;
  }

  /// Plan duration: positive integer 1–365.
  static String? duration(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Duration is required';
    final parsed = int.tryParse(v);
    if (parsed == null || parsed < 1) return 'Duration must be at least 1';
    if (parsed > 365) return 'Duration cannot exceed 365';
    return null;
  }

  /// Generic required.
  static String? required(String? value, {String label = 'This field'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    return null;
  }
}