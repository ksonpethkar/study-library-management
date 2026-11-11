import 'package:study_library/models/student_model.dart';

/// Classified orientation / side of an uploaded Government ID document image.
enum DocumentSideClassification {
  /// Front side only (contains photo, name, ID number, DOB, gender)
  frontOnly,

  /// Back side only (contains address, care-of, PIN code)
  backOnly,

  /// Both front and back sides appear on a SINGLE image (e.g. A4 Xerox photocopy,
  /// e-Aadhaar downloaded PDF cut-off section, or two sides laid out together).
  bothSidesCombined,

  /// PAN Card (by definition, PAN is single-sided; back side is not required).
  panCard,

  /// Unrecognized / general document
  unknown,
}

/// Intelligent, 100% Client-Side Layout & Orientation Classifier for Indian Gov IDs.
/// Runs in-memory with zero external API calls or costs.
class DocumentLayoutClassifier {
  /// Analyzes text tokens and aspect ratio to classify the document layout.
  static DocumentSideClassification classify({
    required String rawText,
    GovIdType? preferredType,
    double? aspectRatio, // width / height
  }) {
    final lower = rawText.toLowerCase();

    // ── 1. PAN Card Detection (Always single-sided) ───────────────────────────
    final isPan = preferredType == GovIdType.pan ||
        lower.contains('income tax department') ||
        lower.contains('permanent account number card') ||
        RegExp(r'\b[a-z]{5}[0-9]{4}[a-z]\b', caseSensitive: false).hasMatch(lower);

    if (isPan) {
      return DocumentSideClassification.panCard;
    }

    // ── 2. Front Markers Detection ────────────────────────────────────────────
    final hasFront = hasFrontMarkers(lower, preferredType);

    // ── 3. Back Markers Detection ─────────────────────────────────────────────
    final hasBack = hasBackMarkers(lower, preferredType);

    // ── 4. Combined Page (Both Sides on Single Page) ──────────────────────────
    // If BOTH front markers AND back markers are present in the text, it is
    // definitively a combined document (e.g. e-Aadhaar, A4 xerox, or single-photo both sides).
    if (hasFront && hasBack) {
      return DocumentSideClassification.bothSidesCombined;
    }

    // Aspect ratio heuristic: ISO A4 page is ~0.707 (portrait) or ~1.414 (landscape)
    // Full A4 page uploads with partial text often contain both sides.
    if (aspectRatio != null && aspectRatio > 0) {
      final isA4Portrait = aspectRatio >= 0.65 && aspectRatio <= 0.78;
      if (isA4Portrait && (hasFront || hasBack)) {
        return DocumentSideClassification.bothSidesCombined;
      }
    }

    // ── 5. Unambiguous Single Side ────────────────────────────────────────────
    if (hasFront) return DocumentSideClassification.frontOnly;
    if (hasBack) return DocumentSideClassification.backOnly;

    return DocumentSideClassification.unknown;
  }

  /// Checks for distinct front-side markers across Indian Gov IDs
  static bool hasFrontMarkers(String lowerText, GovIdType? type) {
    // Front indicators common to Aadhaar, DL, Voter, Passport
    final generalFrontKeywords = [
      'government of india',
      'bharat sarkar',
      'unique identification authority',
      'uidai',
      'male',
      'female',
      'transgender',
      'dob',
      'date of birth',
      'year of birth',
      'yob',
      'जन्म तारीख',
      'जन्म वर्ष',
      'जन्मदिनांक',
      'driving licence',
      'driving license',
      'union of india',
      'election commission of india',
      'elector photo identity',
      'republic of india',
      'passport',
    ];

    for (final kw in generalFrontKeywords) {
      if (lowerText.contains(kw)) return true;
    }

    // Check for standard 12-digit Aadhaar pattern or 4-4-4 spacing
    if (RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b').hasMatch(lowerText)) {
      return true;
    }

    // Check for Driving Licence number
    if (RegExp(r'\b[a-z]{2}\d{2}\s?[0-9a-z]{8,15}\b', caseSensitive: false).hasMatch(lowerText)) {
      return true;
    }

    // Check for EPIC Voter ID number
    if (RegExp(r'\b[a-z]{3}[0-9]{7}\b', caseSensitive: false).hasMatch(lowerText)) {
      return true;
    }

    return false;
  }

  /// Checks for distinct back-side markers across Indian Gov IDs (Address, Care of, PIN code)
  static bool hasBackMarkers(String lowerText, GovIdType? type) {
    final backKeywords = [
      'address',
      'पत्ता',
      'पता',
      's/o',
      'd/o',
      'w/o',
      'c/o',
      'son of',
      'daughter of',
      'wife of',
      'care of',
      'आत्मज',
      'वडील',
      'पती',
      'help@uidai.gov.in',
      'www.uidai.gov.in',
      'post box no',
      'unique identification authority of india',
      'pin code',
      'pincode',
      'pin:',
      'district',
      'taluka',
      'tq.',
      'post:',
      'at post',
    ];

    int keywordCount = 0;
    for (final kw in backKeywords) {
      if (lowerText.contains(kw)) {
        keywordCount++;
        if (keywordCount >= 1) return true;
      }
    }

    // Check for 6-digit Indian Postal PIN Code (starting with 1-9)
    if (RegExp(r'\b[1-9][0-9]{5}\b').hasMatch(lowerText)) {
      // Must be accompanied by at least one address-like word or comma
      if (lowerText.contains(',') || lowerText.contains('dist') || lowerText.contains('state') || lowerText.contains('road') || lowerText.contains('nagar')) {
        return true;
      }
    }

    return false;
  }

  /// Determines whether a second upload (back side) is required given the ID type & classification
  static bool isBackSideRequired({
    required GovIdType type,
    required DocumentSideClassification classification,
    bool hasAddressAlready = false,
  }) {
    // 1. PAN Card NEVER requires a back side
    if (type == GovIdType.pan || classification == DocumentSideClassification.panCard) {
      return false;
    }

    // 2. If both sides were already found on a single page, no second upload needed!
    if (classification == DocumentSideClassification.bothSidesCombined) {
      return false;
    }

    // 3. If address is already extracted (e.g. from Aadhaar QR code or full page), back side is optional
    if (hasAddressAlready) {
      return false;
    }

    // 4. College / Other IDs generally don't require two sides
    if (type == GovIdType.collegeId || type == GovIdType.other) {
      return false;
    }

    // 5. Standard two-sided IDs (Aadhaar, DL, Voter ID) require back side for address
    return true;
  }

  /// Returns user-facing smart guidance text based on the detected layout
  static String getGuidanceMessage({
    required GovIdType type,
    required DocumentSideClassification classification,
    required bool isSecondUpload,
    bool hasAddress = false,
  }) {
    if (classification == DocumentSideClassification.bothSidesCombined) {
      return '✓ Full document detected! Both Front & Back sides found on this single image — Address, Name & ID Number auto-extracted.';
    }

    if (classification == DocumentSideClassification.panCard || type == GovIdType.pan) {
      return '✓ PAN Card detected. Back side is not required — ID details auto-filled!';
    }

    if (!isSecondUpload) {
      if (classification == DocumentSideClassification.backOnly) {
        return '✓ Back side detected first! Residential address auto-filled. Please attach the FRONT side for your Name, Photo & ID Number.';
      }
      if (hasAddress) {
        return '✓ Complete details (including Address) decoded from QR code. Back side scan is optional.';
      }
      return '✓ Front side detected. Please scan the BACK side to auto-extract your Residential Address & PIN code.';
    } else {
      if (classification == DocumentSideClassification.frontOnly) {
        return '⚠️ This appears to be another front side. Make sure the back side (with address & PIN) is clearly visible.';
      }
      return '✓ Back side captured! Address and PIN code added.';
    }
  }
}
