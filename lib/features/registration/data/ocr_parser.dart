/// Government ID OCR parser — extracts ALL available fields from each ID type.
/// Indian IDs supported: Aadhaar, PAN, Driving Licence, College/Student ID.
///
/// Field extraction map per ID type:
///
/// AADHAAR:
///   name, fatherName/husbandName, dob, gender, aadhaarNumber, address,
///   pinCode, district, state, phone (if present on back)
///
/// PAN:
///   name, fatherName, dob, panNumber
///
/// DRIVING LICENCE:
///   name, fatherName/husbandName, dob, dlNumber, address, pinCode,
///   vehicleClass, issuedDate, expiryDate, bloodGroup, birthPlace
///
/// COLLEGE ID:
///   name, rollNumber, college, course, year, branch, phone
enum GovIdType { aadhaar, pan, drivingLicence, collegeId }

class OcrResult {
  final String? name;
  final String? fatherName; // or guardian / husband
  final String? dob;
  final String? gender;
  final String? idNumber;
  final String? address;
  final String? pinCode;
  final String? district;
  final String? state;
  final String? bloodGroup;
  final String? phone;
  final String? email;
  final String? college;
  final String? course;
  final String? rollNumber;
  final String? vehicleClass;
  final String? expiryDate;
  final String? issuedDate;
  final int confidence; // 0–100
  final String? rawText; // for debugging

  const OcrResult({
    this.name,
    this.fatherName,
    this.dob,
    this.gender,
    this.idNumber,
    this.address,
    this.pinCode,
    this.district,
    this.state,
    this.bloodGroup,
    this.phone,
    this.email,
    this.college,
    this.course,
    this.rollNumber,
    this.vehicleClass,
    this.expiryDate,
    this.issuedDate,
    this.confidence = 0,
    this.rawText,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'fatherName': fatherName,
        'dob': dob,
        'gender': gender,
        'idNumber': idNumber,
        'address': address,
        'pinCode': pinCode,
        'district': district,
        'state': state,
        'bloodGroup': bloodGroup,
        'phone': phone,
        'email': email,
        'college': college,
        'course': course,
        'rollNumber': rollNumber,
        'vehicleClass': vehicleClass,
        'expiryDate': expiryDate,
        'issuedDate': issuedDate,
        'confidence': confidence,
      };

  /// Returns only non-null fields for auto-fill display
  Map<String, String> filledFields() {
    final map = <String, String>{};
    if (name != null) map['name'] = name!;
    if (fatherName != null) map['fatherName'] = fatherName!;
    if (dob != null) map['dob'] = dob!;
    if (gender != null) map['gender'] = gender!;
    if (idNumber != null) map['idNumber'] = idNumber!;
    if (address != null) map['address'] = address!;
    if (pinCode != null) map['pinCode'] = pinCode!;
    if (bloodGroup != null) map['bloodGroup'] = bloodGroup!;
    if (phone != null) map['phone'] = phone!;
    if (college != null) map['college'] = college!;
    if (course != null) map['course'] = course!;
    if (rollNumber != null) map['rollNumber'] = rollNumber!;
    return map;
  }
}

class OcrParser {
  /// Automatically detects which Indian Government ID document is scanned
  static GovIdType detectGovIdType(String rawText) {
    final text = rawText.toUpperCase();
    // PAN Card check
    if (RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b').hasMatch(text) ||
        text.contains('INCOME TAX') ||
        text.contains('PERMANENT ACCOUNT NUMBER')) {
      return GovIdType.pan;
    }
    // Driving Licence check
    if (text.contains('DRIVING LICENCE') ||
        text.contains('DRIVING LICENSE') ||
        text.contains('UNION OF INDIA DRIVING') ||
        RegExp(r'\b[A-Z]{2}[-\s]?\d{2}[-\s]?(?:19|20)\d{2}\b').hasMatch(text)) {
      return GovIdType.drivingLicence;
    }
    // College ID check
    if (text.contains('COLLEGE') ||
        text.contains('INSTITUTE') ||
        text.contains('UNIVERSITY') ||
        text.contains('STUDENT ID') ||
        text.contains('ENROLLMENT NO') ||
        text.contains('ROLL NO')) {
      return GovIdType.collegeId;
    }
    // Default to Aadhaar
    return GovIdType.aadhaar;
  }

  static OcrResult parseByType(GovIdType type, String rawText) {
    switch (type) {
      case GovIdType.aadhaar:
        return _parseAadhaar(rawText);
      case GovIdType.pan:
        return _parsePAN(rawText);
      case GovIdType.drivingLicence:
        return _parseDrivingLicence(rawText);
      case GovIdType.collegeId:
        return _parseCollegeId(rawText);
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Strip non-ASCII (Devanagari etc.) keeping spaces, basic punctuation
  static String _clean(String text) =>
      text.replaceAll(RegExp(r'[^\x00-\x7F]+'), ' ').replaceAll(RegExp(r' {2,}'), ' ').trim();

  static List<String> _lines(String text) =>
      _clean(text).split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// Matches dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy
  static String? _extractDob(String text) {
    final match = RegExp(r'\b(\d{2})[/\-.](\d{2})[/\-.](\d{4})\b').firstMatch(text);
    if (match == null) return null;
    return '${match.group(1)}/${match.group(2)}/${match.group(3)}';
  }

  /// Extract 6-digit Indian PIN code
  static String? _extractPin(String text) {
    final match = RegExp(r'\b(\d{6})\b').firstMatch(text);
    return match?.group(1);
  }

  /// Extract 10-digit Indian phone number
  static String? _extractPhone(String text) {
    final match = RegExp(r'\b([6-9]\d{9})\b').firstMatch(text);
    return match?.group(1);
  }

  /// Extract blood group (A+, B-, O+, AB+, etc.)
  static String? _extractBloodGroup(String text) {
    final match = RegExp(r'\b(A|B|AB|O)[+\-]\b', caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    return match.group(0)?.toUpperCase();
  }

  /// Extract gender from text
  static String? _extractGender(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('female') || lower.contains('महिला')) return 'female';
    if (lower.contains('male') || lower.contains('पुरुष')) return 'male';
    if (lower.contains('transgender')) return 'other';
    return null;
  }

  /// Find a value on the line AFTER a label line containing [keyword]
  static String? _valueAfterLabel(List<String> lines, String keyword) {
    final kLower = keyword.toLowerCase();
    for (int i = 0; i < lines.length - 1; i++) {
      if (lines[i].toLowerCase().contains(kLower)) {
        final next = lines[i + 1].trim();
        if (next.isNotEmpty && next.length > 1) return next;
      }
    }
    return null;
  }

  /// Find the value on the SAME line after a label (e.g. "DOB: 01/01/2000")
  static String? _inlineValue(String text, String label) {
    final match = RegExp(
      '${RegExp.escape(label)}[:\\s]+([^\\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  // ── Aadhaar Card ──────────────────────────────────────────────────────────
  //
  // Front: Name, DOB/YOB, Gender, Aadhaar number (xxxx xxxx xxxx)
  // Back:  Address, PIN, Aadhaar number repeated
  //
  static OcrResult _parseAadhaar(String rawText) {
    // Keep both raw lines (with Marathi/Hindi etc) and cleaned lines (ASCII)
    final rawLines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final text = _clean(rawText);
    final lines = _lines(rawText);
    int confidence = 0;

    // ── ID Number: 4-4-4 pattern ────────────────────────────────────────
    String? aadhaarNumber;
    final numMatch = RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b').firstMatch(text);
    if (numMatch != null) {
      aadhaarNumber = numMatch.group(0);
      confidence += 35;
    } else {
      // also try 12 contiguous digits
      final contiguous = RegExp(r'\b(\d{12})\b').firstMatch(text);
      if (contiguous != null) {
        final n = contiguous.group(1)!;
        aadhaarNumber = '${n.substring(0, 4)} ${n.substring(4, 8)} ${n.substring(8)}';
        confidence += 25;
      }
    }

    // ── DOB ──────────────────────────────────────────────────────────────
    final dob = _extractDob(text);
    if (dob != null) confidence += 15;

    // ── Year of Birth (if no full DOB) ────────────────────────────────────
    String? yob;
    if (dob == null) {
      final yobMatch = RegExp(r'\bYear of Birth\s*[:\-]?\s*(\d{4})\b', caseSensitive: false)
          .firstMatch(text);
      yob = yobMatch?.group(1);
    }

    // ── Gender ───────────────────────────────────────────────────────────
    final gender = _extractGender(text);
    if (gender != null) confidence += 10;

    // ── Name ─────────────────────────────────────────────────────────────
    // On Aadhaar front:
    // English Name almost always sits immediately ABOVE the line with DOB or Gender.
    String? name;

    // Heuristic 1: Find the line index containing DOB or "Year of Birth" or Gender
    int anchorLineIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if (l.contains('dob') ||
          l.contains('date of birth') ||
          l.contains('year of birth') ||
          RegExp(r'\b\d{2}[/\-.]\d{2}[/\-.]\d{4}\b').hasMatch(l)) {
        anchorLineIdx = i;
        break;
      }
    }
    if (anchorLineIdx == -1) {
      for (int i = 0; i < lines.length; i++) {
        final l = lines[i].toLowerCase();
        if (l.contains('male') || l.contains('female')) {
          anchorLineIdx = i;
          break;
        }
      }
    }

    // Look backwards from the anchor line for the closest candidate name line
    if (anchorLineIdx > 0) {
      for (int i = anchorLineIdx - 1; i >= 0 && i >= anchorLineIdx - 4; i--) {
        final candidate = lines[i];
        if (_isValidPersonName(candidate)) {
          name = _toTitleCase(candidate);
          break;
        }
      }
    }

    // Heuristic 2: Explicit "name" label
    if (name == null) {
      final fromLabel = _valueAfterLabel(lines, 'name');
      if (fromLabel != null && _isValidPersonName(fromLabel)) {
        name = _toTitleCase(fromLabel);
      }
    }

    // Heuristic 3: Scan all lines from top, skipping boilerplate
    if (name == null) {
      for (final line in lines) {
        if (_isValidPersonName(line)) {
          name = _toTitleCase(line);
          break;
        }
      }
    }

    if (name != null) confidence += 20;

    // ── Father / Husband name ────────────────────────────────────────────
    String? fatherName;
    final relMatch = RegExp(
      r'(?:C/O|S/O|D/O|W/O|c/o|s/o|d/o|w/o|Care of|Son of|Daughter of|Wife of|आत्मज|नाते)[:\s]+([^,\n\r]+)',
      caseSensitive: false,
    ).firstMatch(rawText);

    if (relMatch != null) {
      final candidate = _clean(relMatch.group(1) ?? '').trim();
      if (_isValidPersonName(candidate)) {
        fatherName = _toTitleCase(candidate);
      }
    }

    // Fallback: Indian naming convention — middle word of "First Father Surname"
    if (fatherName == null && name != null) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length == 3 && parts[1].length > 1) {
        fatherName = parts[1]; // middle word = father's name
        confidence += 5;
      }
    }

    if (fatherName != null) confidence += 10;

    // ── Address (Aadhaar back) ────────────────────────────────────────────
    String? address = _extractAadhaarAddress(rawLines, lines, text);
    if (address != null && address.isNotEmpty) {
      confidence += 20;
    }

    // ── PIN Code ─────────────────────────────────────────────────────────
    final pinCode = _extractPin(text);

    // ── Phone ─────────────────────────────────────────────────────────────
    final phone = _extractPhone(text);

    return OcrResult(
      name: name,
      fatherName: fatherName,
      dob: dob ?? (yob != null ? '01/01/$yob' : null),
      gender: gender,
      idNumber: aadhaarNumber,
      address: address,
      pinCode: pinCode,
      phone: phone,
      confidence: confidence.clamp(0, 100),
      rawText: text,
    );
  }

  static bool _isValidPersonName(String s) {
    final trimmed = s.trim();
    if (trimmed.length < 3 || trimmed.length > 50) return false;
    // Must contain letters, spaces, dots or hyphens
    if (!RegExp(r'^[A-Za-z\s.\-]+$').hasMatch(trimmed)) return false;
    // Must not be boilerplate or keyword
    if (_isKeyword(trimmed) || _isAadhaarBoilerplate(trimmed)) return false;
    // Must not contain numeric digits
    if (RegExp(r'\d').hasMatch(trimmed)) return false;
    // Common non-name words found on Aadhaar
    final lower = trimmed.toLowerCase();
    const banned = [
      'enrolment', 'enrollment', 'government', 'india', 'authority',
      'identity', 'resident', 'help', 'card', 'male', 'female',
      'birth', 'download', 'unique', 'identification', 'po box'
    ];
    if (banned.any((b) => lower.contains(b))) return false;
    return true;
  }

  static String? _extractAadhaarAddress(
    List<String> rawLines,
    List<String> cleanLines,
    String cleanText,
  ) {
    // 1. Try finding address start in rawLines (supporting Marathi/Hindi 'पत्ता', 'पता', 'Address')
    int addrStartIdx = -1;
    String? inlinePart;

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final match = RegExp(
        r'(?:address|पत्ता|पता|addr)[:\s\-]+(.*)',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        addrStartIdx = i;
        final remainder = _clean(match.group(1) ?? '').trim();
        if (remainder.isNotEmpty && !_isAadhaarBoilerplate(remainder)) {
          inlinePart = remainder;
        }
        break;
      }
    }

    // If not found in rawLines, check cleanLines
    if (addrStartIdx == -1) {
      for (int i = 0; i < cleanLines.length; i++) {
        final line = cleanLines[i];
        final match = RegExp(
          r'(?:address|addr)[:\s\-]+(.*)',
          caseSensitive: false,
        ).firstMatch(line);
        if (match != null) {
          addrStartIdx = i;
          final remainder = match.group(1)?.trim() ?? '';
          if (remainder.isNotEmpty && !_isAadhaarBoilerplate(remainder)) {
            inlinePart = remainder;
          }
          break;
        }
      }
    }

    if (addrStartIdx >= 0) {
      final collected = <String>[];
      if (inlinePart != null && inlinePart.isNotEmpty) {
        collected.add(inlinePart);
      }

      // Collect following lines until end of address block
      for (int i = addrStartIdx + 1; i < rawLines.length && i < addrStartIdx + 8; i++) {
        final cleanedLine = _clean(rawLines[i]).trim();
        if (cleanedLine.isEmpty) continue;
        if (_isAadhaarBoilerplate(cleanedLine)) continue;

        // Stop if we hit Aadhaar number pattern or UIDAI footer
        if (RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b').hasMatch(cleanedLine) ||
            cleanedLine.toLowerCase().startsWith('uidai') ||
            cleanedLine.toLowerCase().contains('www.uidai') ||
            cleanedLine.toLowerCase().contains('1947')) {
          break;
        }

        collected.add(cleanedLine);

        // If this line contains a 6-digit PIN code, this marks the end of the address!
        if (RegExp(r'\b\d{6}\b').hasMatch(cleanedLine)) {
          break;
        }
      }

      if (collected.isNotEmpty) {
        final joined = collected.join(', ')
            .replaceAll(RegExp(r',\s*,+'), ',')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim();
        if (joined.length >= 8) return joined;
      }
    }

    // Fallback: If no "Address" label was found, but a 6-digit PIN was found:
    // Gather 2-3 lines preceding the PIN code line
    final pin = _extractPin(cleanText);
    if (pin != null) {
      final pinLineIdx = cleanLines.indexWhere((l) => l.contains(pin));
      if (pinLineIdx > 0) {
        final fallbackLines = <String>[];
        final start = (pinLineIdx - 3).clamp(0, pinLineIdx);
        for (int i = start; i <= pinLineIdx; i++) {
          final l = cleanLines[i];
          if (!_isAadhaarBoilerplate(l) &&
              !_isKeyword(l) &&
              !RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b').hasMatch(l)) {
            fallbackLines.add(l);
          }
        }
        if (fallbackLines.isNotEmpty) {
          final candidate = fallbackLines.join(', ');
          if (candidate.length >= 10) return candidate;
        }
      }
    }

    return null;
  }

  /// Returns true if the line is known Aadhaar boilerplate (header/footer/legal text)
  /// and should NOT be used as a name or address component.
  static bool _isAadhaarBoilerplate(String line) {
    final lower = line.toLowerCase();
    const boilerplate = [
      'government of india',
      'government',
      'govt of india',
      'unique identification',
      'uidai',
      'aadhaar after every',
      'date of enrolment',
      'update your',
      'www.uidai',
      'help@uidai',
      'helpline',
      '1947',
      'toll free',
      'enrolment is free',
      'valid proof',
      'my aadhaar',
      'maadhaar',
      'resident',
      'ministry of',
      'authority of india',
      'for any',
      'identity',
      'electronic identification',
      'proof of identity',
      'not proof of citizenship',
      'information',
      'po box',
      'bangalore',
      'chanderlok',
    ];
    return boilerplate.any((b) => lower.contains(b));
  }


  // ── PAN Card ──────────────────────────────────────────────────────────────
  //
  // Front: Name, Father's Name, DOB, PAN Number (AAAAA9999A)
  //
  static OcrResult _parsePAN(String rawText) {
    final text = _clean(rawText);
    final lines = _lines(rawText);
    int confidence = 0;

    // ── PAN Number ────────────────────────────────────────────────────────
    String? panNumber;
    final panMatch = RegExp(r'\b([A-Z]{5}[0-9]{4}[A-Z])\b').firstMatch(text);
    if (panMatch != null) {
      panNumber = panMatch.group(1);
      confidence += 40;
    }

    // ── DOB ───────────────────────────────────────────────────────────────
    final dob = _extractDob(text);
    if (dob != null) confidence += 20;

    // ── Name (appears ABOVE Father's name on PAN) ─────────────────────────
    // Layout: Name label → Name → Father's name label → Father's Name → DOB → PAN number
    String? name = _valueAfterLabel(lines, "name");
    String? fatherName;

    // More precise: find line after "Name" but before "Father"
    final nameIdx = lines.indexWhere((l) => l.toLowerCase().trim() == 'name');
    final fatherIdx = lines.indexWhere(
        (l) => l.toLowerCase().contains("father") || l.toLowerCase().contains("father's name"));
    if (nameIdx >= 0 && nameIdx + 1 < lines.length) {
      name = _toTitleCase(lines[nameIdx + 1]);
      confidence += 15;
    }
    if (fatherIdx >= 0 && fatherIdx + 1 < lines.length) {
      fatherName = _toTitleCase(lines[fatherIdx + 1]);
      confidence += 10;
    }

    // Fallback: pick capitalised lines that look like names
    if (name == null) {
      for (final line in lines) {
        if (RegExp(r'^[A-Z ]{4,50}$').hasMatch(line) && !_isKeyword(line)) {
          name = _toTitleCase(line);
          confidence += 10;
          break;
        }
      }
    }

    return OcrResult(
      name: name,
      fatherName: fatherName,
      dob: dob,
      idNumber: panNumber,
      confidence: confidence.clamp(0, 100),
      rawText: text,
    );
  }

  // ── Driving Licence ───────────────────────────────────────────────────────
  //
  // Fields: DL Number, Name, Father/Husband name, DOB, Address, PIN,
  //         Blood Group, Vehicle Class(es), Issue Date, Expiry Date
  //
  static OcrResult _parseDrivingLicence(String rawText) {
    final text = _clean(rawText);
    final lines = _lines(rawText);
    int confidence = 0;

    // ── DL Number (state code + digits, e.g. MH01 2019 0012345) ──────────
    String? dlNumber;
    final dlMatch = RegExp(
      r'\b([A-Z]{2})[-\s]?(\d{2})[-\s]?(\d{4}|\d{2})[-\s]?(\d{7}|\d{11}|\d{5,10})\b',
    ).firstMatch(text);
    if (dlMatch != null) {
      dlNumber = dlMatch.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim();
      confidence += 35;
    }

    // ── DOB, Issue, Expiry dates ───────────────────────────────────────────
    final allDates = RegExp(r'\b\d{2}[/\-.]\d{2}[/\-.]\d{4}\b')
        .allMatches(text)
        .map((m) => m.group(0)!.replaceAll(RegExp(r'[.\-]'), '/'))
        .toList();

    String? dob, issuedDate, expiryDate;

    // Look for labelled dates first
    dob = _extractLabelledDate(text, ['dob', 'date of birth', 'birth']);
    issuedDate = _extractLabelledDate(text, ['issue', 'issued on', 'doi', 'date of issue']);
    expiryDate = _extractLabelledDate(text, ['valid', 'expiry', 'doe', 'valid till', 'valid upto']);

    // Fallback: assign by order if labels not found (DOB < issue < expiry)
    if (allDates.length >= 3 && dob == null) {
      final sorted = List<String>.from(allDates)
        ..sort((a, b) => _parseDate(a).compareTo(_parseDate(b)));
      dob = sorted[0];
      issuedDate = sorted[1];
      expiryDate = sorted.last;
    } else if (allDates.length == 1 && dob == null) {
      dob = allDates[0];
    }

    if (dob != null) confidence += 15;
    if (expiryDate != null) confidence += 5;

    // ── Name ─────────────────────────────────────────────────────────────
    String? name = _valueAfterLabel(lines, 'name') ??
        _inlineValue(text, 'Name');
    if (name != null) {
      name = _toTitleCase(name.replaceAll(RegExp(r'^(Sri|Smt|Mr|Ms|Mrs)\.?\s*', caseSensitive: false), ''));
      confidence += 10;
    }

    // ── Father / Husband Name ─────────────────────────────────────────────
    String? fatherName = _valueAfterLabel(lines, 'father') ??
        _valueAfterLabel(lines, 's/o') ??
        _valueAfterLabel(lines, 'd/o') ??
        _valueAfterLabel(lines, 'w/o') ??
        _inlineValue(text, 'S/O') ??
        _inlineValue(text, 'D/O');
    if (fatherName != null) {
      fatherName = _toTitleCase(fatherName);
      confidence += 5;
    }

    // ── Address ───────────────────────────────────────────────────────────
    String? address;
    final addrIdx = lines.indexWhere((l) => l.toLowerCase().contains('address'));
    if (addrIdx >= 0 && addrIdx + 1 < lines.length) {
      final addrLines = <String>[];
      for (int i = addrIdx + 1; i < lines.length && i < addrIdx + 6; i++) {
        if (_isKeyword(lines[i])) break;
        addrLines.add(lines[i]);
      }
      if (addrLines.isNotEmpty) address = addrLines.join(', ');
    }

    // ── PIN ───────────────────────────────────────────────────────────────
    final pinCode = _extractPin(text);

    // ── Blood Group ───────────────────────────────────────────────────────
    final bloodGroup = _extractBloodGroup(text);
    if (bloodGroup != null) confidence += 5;

    // ── Vehicle Class ─────────────────────────────────────────────────────
    String? vehicleClass;
    final vcMatch = RegExp(
      r'\b(LMV|MCWG|MCWOG|HMV|HGMV|HPMV|MGV|MGV|Trans|Transport|NTR|NT|TR)\b',
    ).firstMatch(text.toUpperCase());
    if (vcMatch != null) vehicleClass = vcMatch.group(0);

    // ── Gender ────────────────────────────────────────────────────────────
    final gender = _extractGender(text);

    return OcrResult(
      name: name,
      fatherName: fatherName,
      dob: dob,
      gender: gender,
      idNumber: dlNumber,
      address: address,
      pinCode: pinCode,
      bloodGroup: bloodGroup,
      vehicleClass: vehicleClass,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      confidence: confidence.clamp(0, 100),
      rawText: text,
    );
  }

  // ── College / Student ID ───────────────────────────────────────────────────
  //
  // Fields: Name, Roll/Enrollment No., College Name, Course, Year/Batch, Branch, Phone
  //
  static OcrResult _parseCollegeId(String rawText) {
    final text = _clean(rawText);
    final lines = _lines(rawText);
    int confidence = 10;

    // ── Roll / Enrollment Number ──────────────────────────────────────────
    String? rollNumber;
    for (final keyword in ['roll', 'enrollment', 'enroll', 'reg', 'registration', 'student id', 'id no']) {
      final val = _valueAfterLabel(lines, keyword) ?? _inlineValue(text, keyword);
      if (val != null && RegExp(r'^[A-Z0-9/\-]{3,20}$', caseSensitive: false).hasMatch(val.trim())) {
        rollNumber = val.trim().toUpperCase();
        confidence += 25;
        break;
      }
    }

    // ── Name ─────────────────────────────────────────────────────────────
    String? name = _valueAfterLabel(lines, 'name') ?? _inlineValue(text, 'name');
    if (name != null) {
      name = _toTitleCase(name);
      confidence += 15;
    }

    // ── College Name ──────────────────────────────────────────────────────
    String? college;
    for (final keyword in ['college', 'institute', 'university', 'school']) {
      final val = _valueAfterLabel(lines, keyword) ?? _inlineValue(text, keyword);
      if (val != null) {
        college = val.trim();
        confidence += 10;
        break;
      }
    }
    // Fallback: first line is often the institution name
    if (college == null && lines.isNotEmpty) {
      college = lines[0];
    }

    // ── Course / Branch ───────────────────────────────────────────────────
    String? course;
    for (final keyword in ['course', 'programme', 'program', 'degree']) {
      final val = _valueAfterLabel(lines, keyword) ?? _inlineValue(text, keyword);
      if (val != null) {
        course = val.trim();
        confidence += 5;
        break;
      }
    }

    // ── DOB ───────────────────────────────────────────────────────────────
    final dob = _extractDob(text);

    // ── Phone ─────────────────────────────────────────────────────────────
    final phone = _extractPhone(text);

    return OcrResult(
      name: name,
      dob: dob,
      idNumber: rollNumber,
      college: college,
      course: course,
      phone: phone,
      rollNumber: rollNumber,
      confidence: confidence.clamp(0, 100),
      rawText: text,
    );
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  static bool _isKeyword(String line) {
    const keywords = [
      'government', 'india', 'aadhaar', 'unique', 'identification',
      'income', 'tax', 'pan', 'driving', 'licence', 'license',
      'transport', 'authority', 'motor', 'vehicles', 'college',
      'university', 'uidai', 'enrolment', 'enrollment', 'address',
      'father', 'mother', 'husband', 'valid', 'issue', 'expiry',
      'blood', 'vehicle', 'class', 'fee', 'session',
    ];
    final lower = line.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }

  static String _toTitleCase(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase());
  }

  static String? _extractLabelledDate(String text, List<String> labels) {
    for (final label in labels) {
      final match = RegExp(
        '${RegExp.escape(label)}[:\\s]+([\\d]{2}[/\\-.][\\d]{2}[/\\-.][\\d]{4})',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return match.group(1)!.replaceAll(RegExp(r'[.\-]'), '/');
      }
    }
    return null;
  }

  static DateTime _parseDate(String s) {
    try {
      final parts = s.split('/');
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    } catch (_) {
      return DateTime(2000);
    }
  }
}
