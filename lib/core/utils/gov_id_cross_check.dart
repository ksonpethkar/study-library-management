import 'package:study_library/models/student_model.dart';

/// Cross-checks a manually entered Government ID number against OCR-extracted ID text.
class GovIdCrossCheck {
  GovIdCrossCheck._();

  /// Returns a friendly mismatch warning if both values are meaningfully present
  /// and their normalized trailing characters disagree; returns null if they match
  /// or if either value is too short/masked to compare safely.
  static String? checkMismatch({
    required GovIdType type,
    required String? typedId,
    required String? ocrDetectedId,
  }) {
    final typedClean = _normalize(typedId);
    final ocrClean = _normalize(ocrDetectedId);
    if (typedClean.length < 4 || ocrClean.length < 4) return null;

    // For Aadhaar, compare last 4 digits safely (handles Masked Aadhaar XXXX XXXX 1234 too)
    if (type == GovIdType.aadhaar) {
      final typedTail = typedClean.substring(typedClean.length - 4);
      final ocrTail = ocrClean.substring(ocrClean.length - 4);
      if (RegExp(r'^\d{4}$').hasMatch(typedTail) &&
          RegExp(r'^\d{4}$').hasMatch(ocrTail) &&
          typedTail != ocrTail) {
        return 'Notice: Typed ${type.displayName} ends in $typedTail, but the uploaded document shows $ocrTail. Please verify.';
      }
      return null;
    }

    // For PAN / DL / Voter ID / Passport: compare full normalized string or last 4 chars
    if (typedClean != ocrClean) {
      final typedTail = typedClean.substring(typedClean.length - 4);
      final ocrTail = ocrClean.substring(ocrClean.length - 4);
      if (typedTail != ocrTail) {
        return 'Notice: Typed ${type.displayName} ends in $typedTail, while uploaded document reads $ocrTail. Please double-check.';
      }
    }
    return null;
  }

  static String _normalize(String? value) {
    if (value == null) return '';
    return value.toUpperCase().replaceAll(RegExp(r'[\s\-_/]'), '');
  }
}
