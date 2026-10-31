import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:study_library/core/validators/aadhaar_validator.dart';
import 'package:study_library/models/student_model.dart';
export 'package:study_library/models/student_model.dart' show GovIdType, GovIdTypeExtension;

/// Government ID OCR & QR parser — extracts ALL available fields from each Indian ID type.
/// Supported IDs: Aadhaar, PAN, Driving Licence, Voter ID, Passport, College/Student ID, Other.

class OcrResult {
  final String? name;
  final String? fatherName; // or guardian / husband / mother
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
  final String? qrData;

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
    this.qrData,
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
        'qrData': qrData,
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
    if (vehicleClass != null) map['vehicleClass'] = vehicleClass!;
    if (college != null) map['college'] = college!;
    if (course != null) map['course'] = course!;
    if (rollNumber != null) map['rollNumber'] = rollNumber!;
    return map;
  }

  OcrResult mergeWith(OcrResult other) {
    return OcrResult(
      name: (name != null && name!.isNotEmpty) ? name : other.name,
      fatherName: (fatherName != null && fatherName!.isNotEmpty) ? fatherName : other.fatherName,
      dob: (dob != null && dob!.isNotEmpty) ? dob : other.dob,
      gender: (gender != null && gender!.isNotEmpty) ? gender : other.gender,
      idNumber: (idNumber != null && idNumber!.isNotEmpty) ? idNumber : other.idNumber,
      address: (address != null && address!.isNotEmpty) ? address : other.address,
      pinCode: (pinCode != null && pinCode!.isNotEmpty) ? pinCode : other.pinCode,
      district: (district != null && district!.isNotEmpty) ? district : other.district,
      state: (state != null && state!.isNotEmpty) ? state : other.state,
      bloodGroup: (bloodGroup != null && bloodGroup!.isNotEmpty) ? bloodGroup : other.bloodGroup,
      phone: (phone != null && phone!.isNotEmpty) ? phone : other.phone,
      email: (email != null && email!.isNotEmpty) ? email : other.email,
      college: (college != null && college!.isNotEmpty) ? college : other.college,
      course: (course != null && course!.isNotEmpty) ? course : other.course,
      rollNumber: (rollNumber != null && rollNumber!.isNotEmpty) ? rollNumber : other.rollNumber,
      vehicleClass: (vehicleClass != null && vehicleClass!.isNotEmpty) ? vehicleClass : other.vehicleClass,
      expiryDate: (expiryDate != null && expiryDate!.isNotEmpty) ? expiryDate : other.expiryDate,
      issuedDate: (issuedDate != null && issuedDate!.isNotEmpty) ? issuedDate : other.issuedDate,
      confidence: confidence > other.confidence ? confidence : other.confidence,
      rawText: rawText ?? other.rawText,
      qrData: qrData ?? other.qrData,
    );
  }
}

// ── Client-Side QR Code Parser for Indian Gov IDs ─────────────────────────────
class QrIdResult {
  final GovIdType type;
  final String? name;
  final String? fatherName;
  final String? dob;
  final String? gender;
  final String? idNumber;
  final String? address;
  final String? pinCode;
  final String? bloodGroup;
  final String? phone;
  final String? vehicleClass;
  final String rawQr;

  const QrIdResult({
    required this.type,
    this.name,
    this.fatherName,
    this.dob,
    this.gender,
    this.idNumber,
    this.address,
    this.pinCode,
    this.bloodGroup,
    this.phone,
    this.vehicleClass,
    required this.rawQr,
  });

  OcrResult toOcrResult() {
    return OcrResult(
      name: name,
      fatherName: fatherName,
      dob: dob,
      gender: gender,
      idNumber: idNumber,
      address: address,
      pinCode: pinCode,
      bloodGroup: bloodGroup,
      phone: phone,
      vehicleClass: vehicleClass,
      confidence: 100, // QR Codes have 100% accuracy
      qrData: rawQr,
    );
  }
}

class QrIdParser {
  /// Parse raw decoded QR string from Indian Gov ID
  static QrIdResult? parseQrString(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    // 1. Aadhaar XML QR: <PrintLetterBarcodeData ... />
    if (text.contains('<PrintLetterBarcodeData') || text.contains('PrintLetterBarcodeData')) {
      return _parseAadhaarXml(text);
    }

    // 1b. Modern UIDAI Secure QR (2018+ PVC / e-Aadhaar): Compressed BigInt byte array
    final secureAadhaar = _parseSecureAadhaarQr(text);
    if (secureAadhaar != null) {
      return secureAadhaar;
    }

    // 2. JSON formatted QR
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final map = jsonDecode(text) as Map<String, dynamic>;
        return _parseJsonQr(map, text);
      } catch (_) { /* intentionally silent */ }
    }

    // 3. Driving Licence QR (contains "DL NO" or MH RTO code)
    if (text.toUpperCase().contains('DL NO') ||
        text.toUpperCase().contains('MH44') ||
        RegExp(r'\b[A-Z]{2}\d{2}\s?\d{11}\b').hasMatch(text)) {
      return _parseDlQr(text);
    }

    // 4. PAN Card QR
    if (text.toUpperCase().contains('PAN') ||
        RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b').hasMatch(text)) {
      return _parsePanQr(text);
    }

    return null;
  }

  static QrIdResult? _parseAadhaarXml(String xml) {
    String? getAttr(String attr) {
      final match = RegExp('$attr="([^"]*)"', caseSensitive: false).firstMatch(xml);
      return match?.group(1)?.trim();
    }

    final uid = getAttr('uid');
    final name = getAttr('name');
    final rawGender = getAttr('gender')?.toUpperCase();
    final dob = getAttr('dob') ?? getAttr('yob');
    final co = getAttr('co') ?? getAttr('careof');
    final house = getAttr('house');
    final street = getAttr('street');
    final lm = getAttr('lm');
    final loc = getAttr('loc');
    final vtc = getAttr('vtc');
    final dist = getAttr('dist');
    final state = getAttr('state');
    final pc = getAttr('pc');

    String? gender;
    if (rawGender == 'M' || rawGender == 'MALE') gender = 'male';
    if (rawGender == 'F' || rawGender == 'FEMALE') gender = 'female';

    String? formattedUid;
    if (uid != null && uid.length == 12) {
      formattedUid = '${uid.substring(0, 4)} ${uid.substring(4, 8)} ${uid.substring(8)}';
    } else {
      formattedUid = uid;
    }

    String? fatherName = co;
    if (fatherName != null) {
      fatherName = fatherName.replaceAll(RegExp(r'^(?:C/O|S/O|D/O|W/O|Care of|Son of)[:\s]*', caseSensitive: false), '').trim();
    }

    final addrParts = [house, street, lm, loc, vtc, dist, state].where((p) => p != null && p.trim().isNotEmpty).toList();
    final address = addrParts.isNotEmpty ? addrParts.join(', ') : null;

    return QrIdResult(
      type: GovIdType.aadhaar,
      name: name,
      fatherName: fatherName,
      dob: dob,
      gender: gender,
      idNumber: formattedUid,
      address: address,
      pinCode: pc,
      rawQr: xml,
    );
  }

  static QrIdResult? _parseSecureAadhaarQr(String text) {
    if (!RegExp(r'^\d{300,}$').hasMatch(text)) return null;

    try {
      final bigInt = BigInt.parse(text);
      var hex = bigInt.toRadixString(16);
      if (hex.length % 2 != 0) hex = '0$hex';
      final compressedBytes = <int>[];
      for (int i = 0; i < hex.length; i += 2) {
        compressedBytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }

      List<int>? decompressed;
      try {
        decompressed = GZipDecoder().decodeBytes(compressedBytes);
      } catch (_) {
        try {
          decompressed = ZLibDecoder().decodeBytes(compressedBytes);
        } catch (_) {
          decompressed = null;
        }
      }

      if (decompressed == null || decompressed.isEmpty) return null;

      final delimiter = decompressed.contains(255) ? 255 : (decompressed.contains(0) ? 0 : -1);
      if (delimiter == -1) return null;

      final fields = <String>[];
      int start = 0;
      for (int i = 0; i < decompressed.length; i++) {
        if (decompressed[i] == delimiter) {
          final chunk = decompressed.sublist(start, i);
          fields.add(utf8.decode(chunk, allowMalformed: true).trim());
          start = i + 1;
          if (fields.length >= 17) break;
        }
      }

      if (fields.length < 5) return null;

      final refId = fields.length > 1 ? fields[1] : '';
      final name = fields.length > 2 && fields[2].isNotEmpty ? fields[2] : null;
      final rawDob = fields.length > 3 && fields[3].isNotEmpty ? fields[3] : null;
      final rawGender = fields.length > 4 ? fields[4].toUpperCase() : null;
      final careOf = fields.length > 5 && fields[5].isNotEmpty ? fields[5] : null;

      final district = fields.length > 6 ? fields[6] : null;
      final landmark = fields.length > 7 ? fields[7] : null;
      final house = fields.length > 8 ? fields[8] : null;
      final location = fields.length > 9 ? fields[9] : null;
      final pincode = fields.length > 10 ? fields[10] : null;
      final state = fields.length > 12 ? fields[12] : null;
      final street = fields.length > 13 ? fields[13] : null;
      final vtc = fields.length > 15 ? fields[15] : null;

      String? gender;
      if (rawGender == 'M' || rawGender == 'MALE') gender = 'male';
      if (rawGender == 'F' || rawGender == 'FEMALE') gender = 'female';
      if (rawGender == 'T' || rawGender == 'OTHER') gender = 'other';

      String? fatherName = careOf;
      if (fatherName != null) {
        fatherName = fatherName.replaceAll(RegExp(r'^(?:C/O|S/O|D/O|W/O|Care of|Son of)[:\s]*', caseSensitive: false), '').trim();
      }

      final addrParts = [house, street, landmark, location, vtc, district, state]
          .where((p) => p != null && p.trim().isNotEmpty)
          .toList();
      final address = addrParts.isNotEmpty ? addrParts.join(', ') : null;

      String? idNumber;
      if (refId.length >= 4) {
        idNumber = 'XXXX XXXX ${refId.substring(refId.length - 4)}';
      }

      return QrIdResult(
        type: GovIdType.aadhaar,
        name: name,
        fatherName: fatherName,
        dob: rawDob?.replaceAll('-', '/'),
        gender: gender,
        idNumber: idNumber,
        address: address,
        pinCode: pincode,
        rawQr: text,
      );
    } catch (_) {
      return null;
    }
  }

  static QrIdResult? _parseJsonQr(Map<String, dynamic> map, String raw) {
    final pan = map['pan'] ?? map['panNumber'];
    final dl = map['dl'] ?? map['dlNumber'];
    final uid = map['uid'] ?? map['aadhaar'];

    final name = map['name'] ?? map['fullName'];
    final father = map['fatherName'] ?? map['father'] ?? map['co'];
    final dob = map['dob'] ?? map['dateOfBirth'];
    final gender = map['gender'];
    final address = map['address'];
    final pin = map['pin'] ?? map['pinCode'] ?? map['pc'];

    if (pan != null) {
      return QrIdResult(type: GovIdType.pan, idNumber: pan.toString(), name: name?.toString(), fatherName: father?.toString(), dob: dob?.toString(), rawQr: raw);
    }
    if (dl != null) {
      return QrIdResult(type: GovIdType.drivingLicence, idNumber: dl.toString(), name: name?.toString(), fatherName: father?.toString(), dob: dob?.toString(), address: address?.toString(), pinCode: pin?.toString(), rawQr: raw);
    }
    if (uid != null) {
      return QrIdResult(type: GovIdType.aadhaar, idNumber: uid.toString(), name: name?.toString(), fatherName: father?.toString(), dob: dob?.toString(), gender: gender?.toString(), address: address?.toString(), pinCode: pin?.toString(), rawQr: raw);
    }
    return null;
  }

  static QrIdResult? _parseDlQr(String text) {
    final dlMatch = RegExp(r'\b([A-Z]{2}\d{2}\s?\d{11})\b').firstMatch(text);
    final nameMatch = RegExp(r'(?:Name|Holder)[:\s]+([^\n\r,]+)', caseSensitive: false).firstMatch(text);
    final fatherMatch = RegExp(r'(?:Father|S/O|Son of)[:\s]+([^\n\r,]+)', caseSensitive: false).firstMatch(text);
    final dobMatch = RegExp(r'\b(\d{2}[/\-.]\d{2}[/\-.]\d{4})\b').firstMatch(text);
    final bgMatch = RegExp(r'\b(A1B\+|A2B\+|A1\+|A2\+|AB\+|A\+|B\+|O\+|AB\-|A\-|B\-|O\-)\b').firstMatch(text);

    return QrIdResult(
      type: GovIdType.drivingLicence,
      idNumber: dlMatch?.group(1),
      name: nameMatch?.group(1)?.trim(),
      fatherName: fatherMatch?.group(1)?.trim(),
      dob: dobMatch?.group(1)?.replaceAll('-', '/'),
      bloodGroup: bgMatch?.group(1),
      rawQr: text,
    );
  }

  static QrIdResult? _parsePanQr(String text) {
    final panMatch = RegExp(r'\b([A-Z]{5}[0-9]{4}[A-Z])\b').firstMatch(text);
    final nameMatch = RegExp(r'(?:Name)[:\s]+([^\n\r,]+)', caseSensitive: false).firstMatch(text);
    final fatherMatch = RegExp(r'(?:Father(?:(?:\x27s)?\s*Name)?)[:\s]+([^\n\r,]+)', caseSensitive: false).firstMatch(text);
    final dobMatch = RegExp(r'\b(\d{2}[/\-.]\d{2}[/\-.]\d{4})\b').firstMatch(text);

    return QrIdResult(
      type: GovIdType.pan,
      idNumber: panMatch?.group(1),
      name: nameMatch?.group(1)?.trim(),
      fatherName: fatherMatch?.group(1)?.trim(),
      dob: dobMatch?.group(1)?.replaceAll('-', '/'),
      rawQr: text,
    );
  }
}

// ── ICAO 9303 Passport Machine Readable Zone (MRZ) Parser ────────────────────
class MrzResult {
  final String surname;
  final String givenNames;
  final String fullName;
  final String passportNumber;
  final String dob; // DD/MM/YYYY
  final String gender;
  final String expiryDate; // DD/MM/YYYY
  final String issuingCountry;

  const MrzResult({
    required this.surname,
    required this.givenNames,
    required this.fullName,
    required this.passportNumber,
    required this.dob,
    required this.gender,
    required this.expiryDate,
    required this.issuingCountry,
  });
}

class PassportMrzParser {
  /// Parse 2-line ICAO 9303 Type 3 Machine Readable Zone (Passport bottom lines)
  static MrzResult? parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim().replaceAll(' ', ''))
        .where((l) => l.isNotEmpty)
        .toList();

    int line1Idx = -1;
    for (int i = 0; i < lines.length; i++) {
      final clean = lines[i].replaceAll('«', '<');
      if (RegExp(r'^P[A-Z0-9]?<[A-Z]{3}').hasMatch(clean)) {
        line1Idx = i;
        break;
      }
    }

    if (line1Idx == -1 || line1Idx + 1 >= lines.length) return null;

    final line1 = lines[line1Idx].replaceAll('«', '<');
    final line2 = lines[line1Idx + 1].replaceAll('«', '<');

    if (line1.length < 20 || line2.length < 20) return null;

    // Line 1: P<IND[SURNAME]<<[GIVEN_NAMES]<<
    final country = line1.length >= 5 ? line1.substring(2, 5) : 'IND';
    final nameSection = line1.length > 5 ? line1.substring(5) : '';
    final nameParts = nameSection.split('<<');
    final surname = nameParts.isNotEmpty ? nameParts[0].replaceAll('<', ' ').trim() : '';
    final givenNames = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';

    final fullName = [givenNames, surname].where((s) => s.isNotEmpty).join(' ');

    // Line 2: W0255557<7IND9505184M320531216C4039299422<74
    final passNumMatch = RegExp(r'^([A-Z0-9<]{8,9})').firstMatch(line2);
    final passportNumber = passNumMatch?.group(1)?.replaceAll('<', '') ?? '';

    String dob = '';
    String gender = '';
    String expiry = '';

    final mrzDetails = RegExp(r'(\d{6})\d([MFX])(\d{6})').firstMatch(line2);
    if (mrzDetails != null) {
      final yymmddDob = mrzDetails.group(1)!;
      gender = mrzDetails.group(2) == 'M' ? 'male' : (mrzDetails.group(2) == 'F' ? 'female' : 'other');
      final yymmddExp = mrzDetails.group(3)!;

      dob = _formatYyMmDd(yymmddDob, isDob: true);
      expiry = _formatYyMmDd(yymmddExp, isDob: false);
    }

    return MrzResult(
      surname: surname,
      givenNames: givenNames,
      fullName: fullName,
      passportNumber: passportNumber,
      dob: dob,
      gender: gender,
      expiryDate: expiry,
      issuingCountry: country,
    );
  }

  static String _formatYyMmDd(String yymmdd, {required bool isDob}) {
    if (yymmdd.length != 6) return yymmdd;
    final yy = int.tryParse(yymmdd.substring(0, 2)) ?? 0;
    final mm = yymmdd.substring(2, 4);
    final dd = yymmdd.substring(4, 6);

    int fullYear;
    if (isDob) {
      fullYear = yy > 26 ? 1900 + yy : 2000 + yy;
    } else {
      fullYear = 2000 + yy;
    }
    return '$dd/$mm/$fullYear';
  }
}

// ── Main OCR Parser ──────────────────────────────────────────────────────────
class OcrParser {
  /// Unified entry point: checks QR code first, then OCR text, and seamlessly combines both!
  static OcrResult parseUnified({
    String? qrString,
    required String rawText,
    GovIdType? preferredType,
  }) {
    // 1. Try QR parsing first
    final qrParsed = QrIdParser.parseQrString(qrString);
    final effectiveType = preferredType ?? qrParsed?.type ?? detectGovIdType(rawText);

    // 2. Parse OCR text
    final textParsed = parseByType(effectiveType, rawText);

    // 3. If QR data is available, merge text fields with 100% confidence QR fields!
    if (qrParsed != null) {
      return qrParsed.toOcrResult().mergeWith(textParsed);
    }

    return textParsed;
  }

  /// Automatically detects which Indian Government ID document is scanned
  static GovIdType detectGovIdType(String rawText) {
    final text = rawText.toUpperCase();

    // 1. Passport check (Look for PASSPORT, MRZ P<IND, or Passport No W0255557)
    if (text.contains('PASSPORT') ||
        text.contains('P<IND') ||
        text.contains('P<') ||
        (text.contains('REPUBLIC OF INDIA') && text.contains('NATIONALITY')) ||
        RegExp(r'\b[A-Z][0-9]{7}\b').hasMatch(text)) {
      return GovIdType.passport;
    }

    // 2. Driving Licence check (Look for DL keywords or MH RTO pattern)
    if (text.contains('DRIVING LICENCE') ||
        text.contains('DRIVING LICENSE') ||
        text.contains('UNION OF INDIA DRIVING') ||
        text.contains('TRANSPORT DEPARTMENT') ||
        text.contains('AUTHORISED TO DRIVE') ||
        text.contains('MAHARASHTRA STATE') ||
        RegExp(r'\b[A-Z]{2}[-\s]?\d{2}[-\s]?(?:19|20)\d{2}\b').hasMatch(text)) {
      return GovIdType.drivingLicence;
    }

    // 3. Voter ID / EPIC check (Election Commission of India)
    if (text.contains('ELECTION COMMISSION') ||
        text.contains('ELECTOR PHOTO') ||
        (text.contains('IDENTITY CARD') && (text.contains('EPIC') || text.contains('VOTER') || text.contains('ELECTOR'))) ||
        RegExp(r'\b[A-Z]{3}[0-9]{7}\b').hasMatch(text)) {
      return GovIdType.voterId;
    }

    // 4. PAN Card check (10-char alphanumeric or Income Tax keywords)
    // Supports: INCOME TAX, GOVT OF INDIA (with or without dot), आयकर विभाग, भारत सरकार, PERMANENT ACCOUNT
    if (RegExp(r'\b[A-Z]{5}[0-9OIS]{4}[A-Z]\b').hasMatch(text) ||
        text.contains('INCOME TAX') ||
        text.contains('INCOMETAX') ||
        text.contains('PERMANENT ACCOUNT') ||
        text.contains('ACCOUNT NUMBER CARD') ||
        text.contains('आयकर विभाग') ||
        text.contains('भारत सरकार') ||
        ((text.contains('GOVT OF INDIA') || text.contains('GOVERNMENT OF INDIA') || text.contains('GOVT. OF INDIA')) &&
         (text.contains('FATHER') || text.contains('FATHERS') || text.contains('DATE OF BIRTH') || text.contains('SIGNATURE')))) {
      return GovIdType.pan;
    }

    // 5. College / Student ID check (Strict: Must mention academic institute + student credential)
    if ((text.contains('COLLEGE') || text.contains('INSTITUTE') || text.contains('UNIVERSITY') || text.contains('POLYTECHNIC')) &&
        (text.contains('STUDENT') || text.contains('ROLL') || text.contains('ENROLL') || text.contains('SEMESTER') || text.contains('STUDENT CARD') || text.contains('IDENTITY CARD'))) {
      return GovIdType.collegeId;
    }

    // 6. Aadhaar check (Specific to UIDAI or 12-digit pattern)
    // NOTE: We do NOT use generic "GOVERNMENT OF INDIA" as a sole match!
    if (text.contains('AADHAAR') ||
        text.contains('UIDAI') ||
        text.contains('UNIQUE IDENTIFICATION') ||
        text.contains('MERA AADHAAR') ||
        text.contains('ENROLMENT NO') ||
        RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b').hasMatch(text)) {
      return GovIdType.aadhaar;
    }

    // Default to Aadhaar
    return GovIdType.aadhaar;
  }

  static OcrResult parseByType(GovIdType type, String rawText) {
    switch (type) {
      case GovIdType.passport:
        return _parsePassport(rawText);
      case GovIdType.drivingLicence:
        return _parseDrivingLicence(rawText);
      case GovIdType.voterId:
        return _parseVoterId(rawText);
      case GovIdType.pan:
        return _parsePAN(rawText);
      case GovIdType.aadhaar:
        return _parseAadhaar(rawText);
      case GovIdType.collegeId:
        return _parseCollegeId(rawText);
      case GovIdType.other:
        return _parseOther(rawText);
    }
  }

  // ── Passport (Front & Back) ────────────────────────────────────────────────
  static OcrResult _parsePassport(String rawText) {
    final text = _clean(rawText);
    final lines = _lines(rawText);
    int confidence = 0;

    // 1. Try ICAO 9303 MRZ on Front Page first (100% precision)
    final mrz = PassportMrzParser.parse(rawText);
    if (mrz != null && mrz.fullName.isNotEmpty) {
      String? fatherName;
      // In Indian passports, middle name in Given Names is typically the father's name
      final givenParts = mrz.givenNames.split(' ');
      if (givenParts.length >= 2) {
        fatherName = _toTitleCase(givenParts.last);
      }

      // Check if Back Page is also in the text (Father / Mother / Address)
      final backFather = _valueAfterLabel(lines, 'father') ?? _valueAfterLabel(lines, 'guardian');
      final backMother = _valueAfterLabel(lines, 'mother');
      final address = _extractPassportAddress(rawText);
      final pinCode = _extractPin(text);

      final parentName = backFather != null
          ? _toTitleCase(backFather)
          : (backMother != null ? _toTitleCase(backMother) : fatherName);

      return OcrResult(
        name: _toTitleCase(mrz.fullName),
        fatherName: parentName,
        dob: mrz.dob,
        gender: mrz.gender,
        idNumber: mrz.passportNumber,
        expiryDate: mrz.expiryDate,
        address: address,
        pinCode: pinCode,
        confidence: 95,
        rawText: rawText,
      );
    }

    // 2. Standard Passport text extraction fallback
    String? passportNumber;
    final passMatch = RegExp(r'\b([A-Z][0-9]{7})\b').firstMatch(text);
    if (passMatch != null) {
      passportNumber = passMatch.group(1);
      confidence += 35;
    }

    String? surname = _valueAfterLabel(lines, 'surname') ?? _inlineValue(text, 'surname');
    String? givenName = _valueAfterLabel(lines, 'given name') ??
        _valueAfterLabel(lines, 'given names') ??
        _inlineValue(text, 'given name');
    String? name;
    if (givenName != null || surname != null) {
      name = [givenName, surname].where((s) => s != null).join(' ').trim();
      confidence += 20;
    }

    final dob = _extractDob(text);
    if (dob != null) confidence += 15;

    final gender = _extractGender(text);
    if (gender != null) confidence += 10;

    // Expiry date
    String? expiryDate;
    final expMatch = RegExp(
      r'(?:Date of Expiry|Expiry|Valid Until|Expiration)\s*[:\-]?\s*(\d{2}[/\-.]\d{2}[/\-.]\d{4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (expMatch != null) expiryDate = expMatch.group(1)?.replaceAll('-', '/');

    // Father / Mother (Passport Back)
    final fatherName = _valueAfterLabel(lines, 'father') ?? _valueAfterLabel(lines, 'legal guardian');
    final address = _extractPassportAddress(rawText);
    final pinCode = _extractPin(text);

    return OcrResult(
      name: name != null ? _toTitleCase(name) : null,
      fatherName: fatherName != null ? _toTitleCase(fatherName) : null,
      dob: dob,
      gender: gender,
      idNumber: passportNumber,
      expiryDate: expiryDate,
      address: address,
      pinCode: pinCode,
      confidence: confidence.clamp(0, 100),
      rawText: rawText,
    );
  }

  static String? _extractPassportAddress(String rawText) {
    final cleanLines = _lines(rawText);
    final addrIdx = cleanLines.indexWhere((l) => l.toLowerCase().contains('address'));
    if (addrIdx >= 0 && addrIdx + 1 < cleanLines.length) {
      final collected = <String>[];
      for (int i = addrIdx + 1; i < cleanLines.length && i < addrIdx + 6; i++) {
        final l = cleanLines[i];
        if (l.toLowerCase().contains('file no') ||
            l.toLowerCase().contains('old passport') ||
            l.toLowerCase().contains('pin:')) {
          collected.add(l);
          break;
        }
        collected.add(l);
      }
      if (collected.isNotEmpty) {
        return collected.join(', ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      }
    }
    return null;
  }

  // ── Driving Licence (Front & Back) ─────────────────────────────────────────
  static OcrResult _parseDrivingLicence(String rawText) {
    final text = _clean(rawText);
    final lines = _lines(rawText);
    int confidence = 0;

    // 1. DL Number: MH44 20250010202 or MH-44-20250010202
    String? dlNumber;
    final dlMatch = RegExp(r'\b([A-Z]{2}[0-9]{2}\s?[0-9]{11})\b').firstMatch(rawText) ??
        RegExp(r'\b([A-Z]{2}[-\s]?[0-9]{2}[-\s]?[0-9]{4}[-\s]?[0-9]{7})\b').firstMatch(rawText) ??
        RegExp(r'\b([A-Z]{2}\d{13,15})\b').firstMatch(rawText);
    if (dlMatch != null) {
      dlNumber = dlMatch.group(1);
      confidence += 35;
    }

    // 2. Name
    String? name;
    final nameMatch = RegExp(r'(?:Name|Holder(?:\x27s)?\s*Name)[:\s\-]+([^\n\r,]+)', caseSensitive: false).firstMatch(rawText);
    if (nameMatch != null) {
      name = _cleanPersonName(nameMatch.group(1)!);
      confidence += 20;
    } else {
      final nameLine = _valueAfterLabel(lines, 'name');
      if (nameLine != null && _isValidPersonName(nameLine)) {
        name = _toTitleCase(nameLine);
        confidence += 15;
      }
    }

    // 3. Father / Spouse Name (Son/Daughter/Wife of: BHARAT SONPETHKAR)
    String? fatherName;
    final fatherMatch = RegExp(
      r'(?:Son\s*/\s*Daughter\s*/\s*Wife\s*of|S/D/W\s*of|Father(?:(?:\x27s)?\s*Name)?|S/O|D/O|W/O)[:\s\-]+([^\n\r,]+)',
      caseSensitive: false,
    ).firstMatch(rawText);
    if (fatherMatch != null) {
      fatherName = _cleanPersonName(fatherMatch.group(1)!);
      confidence += 15;
    }

    // 4. DOB
    String? dob;
    final dobMatch = RegExp(r'(?:DOB|Date of Birth)[:\s\-]+(\d{2}[/\-.]\d{2}[/\-.]\d{4})', caseSensitive: false).firstMatch(rawText) ??
        RegExp(r'\b(\d{2}[/\-.]\d{2}[/\-.]\d{4})\b').firstMatch(rawText);
    if (dobMatch != null) {
      dob = dobMatch.group(1)?.replaceAll('-', '/');
      confidence += 15;
    }

    // 5. Blood Group (Supports A1B+, AB+, O+, etc.)
    String? bloodGroup;
    final bgMatch = RegExp(r'(?:Blood\s*Group|BG)[:\s\-]+([A-Z0-9+\-]+)', caseSensitive: false).firstMatch(rawText) ??
        RegExp(r'\b(A1B\+|A2B\+|A1\+|A2\+|AB\+|A\+|B\+|O\+|AB\-|A\-|B\-|O\-)\b').firstMatch(rawText);
    if (bgMatch != null) {
      bloodGroup = bgMatch.group(1)?.toUpperCase();
      confidence += 5;
    }

    // 6. Address & PIN
    String? address;
    String? pinCode = _extractPin(text);
    final addrMatch = RegExp(r'Address[:\s\-]+([^\n\r]+(?:\n[^\n\r]+)?)', caseSensitive: false).firstMatch(rawText);
    if (addrMatch != null) {
      address = addrMatch.group(1)?.replaceAll('\n', ', ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      confidence += 10;
    }

    // 7. Emergency Contact Number / Phone (DL Back side)
    String? phone;
    final phoneMatch = RegExp(r'(?:Emergency\s*Contact(?:\s*Number)?|Contact(?:\s*Number)?|Mobile|Phone)[:\s\-]+([6-9]\d{9})', caseSensitive: false).firstMatch(rawText) ??
        RegExp(r'\b([6-9]\d{9})\b').firstMatch(rawText);
    if (phoneMatch != null) {
      phone = phoneMatch.group(1);
    }

    // 8. Vehicle Classes: MCWG, LMV
    String? vehicleClass;
    final vcMatch = RegExp(r'(?:COV|Vehicle\s*Class(?:es)?)[:\s\-]+([^\n\r]+)', caseSensitive: false).firstMatch(rawText);
    if (vcMatch != null) {
      vehicleClass = vcMatch.group(1)?.trim();
    } else {
      final foundClasses = <String>[];
      for (final vc in ['MCWG', 'LMV', 'MCWOG', 'HMV', 'TRANS']) {
        if (rawText.toUpperCase().contains(vc)) foundClasses.add(vc);
      }
      if (foundClasses.isNotEmpty) vehicleClass = foundClasses.join(', ');
    }

    // 9. Dates (DOI & Valid Till)
    String? issuedDate;
    String? expiryDate;
    final doiMatch = RegExp(r'(?:DOI|Issue(?:d\s*On)?)[:\s\-]+(\d{2}[/\-.]\d{2}[/\-.]\d{4})', caseSensitive: false).firstMatch(rawText);
    if (doiMatch != null) issuedDate = doiMatch.group(1)?.replaceAll('-', '/');

    final valMatch = RegExp(r'(?:VALID\s*TILL|Expiry|Valid\s*Upto)[:\s\-]+(\d{2}[/\-.]\d{2}[/\-.]\d{4})', caseSensitive: false).firstMatch(rawText);
    if (valMatch != null) expiryDate = valMatch.group(1)?.replaceAll('-', '/');

    return OcrResult(
      name: name,
      fatherName: fatherName,
      dob: dob,
      idNumber: dlNumber,
      bloodGroup: bloodGroup,
      address: address,
      pinCode: pinCode,
      phone: phone,
      vehicleClass: vehicleClass,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      confidence: confidence.clamp(0, 100),
      rawText: rawText,
    );
  }

  // ── PAN Card ──────────────────────────────────────────────────────────────
  static OcrResult _parsePAN(String rawText) {
    final text = _clean(rawText);
    final lines = _lines(rawText);
    int confidence = 0;

    // 1. PAN Number (5 letters + 4 digits + 1 letter)
    String? panNumber;
    final panMatch = RegExp(r'\b([A-Z]{5}[0-9OIS]{4}[A-Z])\b').firstMatch(text) ??
        RegExp(r'([A-Z]{5}[0-9OIS]{4}[A-Z])').firstMatch(text);
    if (panMatch != null) {
      final rawPan = panMatch.group(1)!;
      final prefix = rawPan.substring(0, 5);
      final suffix = rawPan.substring(9, 10);
      final middle = rawPan.substring(5, 9)
          .replaceAll('O', '0')
          .replaceAll('I', '1')
          .replaceAll('S', '5');
      if (RegExp(r'^\d{4}$').hasMatch(middle)) {
        panNumber = '$prefix$middle$suffix';
        confidence += 50;
      }
    }

    // 2. DOB
    final dob = _extractDob(text);
    if (dob != null) confidence += 20;

    // 3. Name & Father's Name
    String? name;
    String? fatherName;

    final fatherMatch = RegExp(r'(?:Father(?:(?:\x27s)?\s*Name)?)[:\s\-]+([^\n\r,]+)', caseSensitive: false).firstMatch(rawText);
    if (fatherMatch != null && _isValidEnglishName(fatherMatch.group(1)!)) {
      fatherName = _cleanPersonName(fatherMatch.group(1)!);
      confidence += 15;
    }

    // On Indian PAN cards, Name is typically directly above Father's Name
    final fatherIdx = lines.indexWhere((l) => l.toLowerCase().contains("father"));
    if (fatherIdx > 0) {
      for (int i = fatherIdx - 1; i >= 0; i--) {
        if (_isValidPersonName(lines[i])) {
          name = _toTitleCase(lines[i]);
          confidence += 20;
          break;
        }
      }
      if (fatherName == null && fatherIdx + 1 < lines.length && _isValidPersonName(lines[fatherIdx + 1])) {
        fatherName = _toTitleCase(lines[fatherIdx + 1]);
      }
    }

    if (name == null) {
      for (final line in lines) {
        if (_isValidPersonName(line)) {
          name = _toTitleCase(line);
          confidence += 10;
          break;
        }
      }
    }

    // If neither PAN number nor name could be extracted reliably, keep confidence 0
    if (panNumber == null && name == null) {
      confidence = 0;
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

  // ── Voter ID (EPIC) ────────────────────────────────────────────────────────
  static OcrResult _parseVoterId(String rawText) {
    final text = _clean(rawText);
    final lines = _lines(rawText);
    int confidence = 0;

    // 1. EPIC Number (e.g. ABC1234567 or XYZ/01/123/456789)
    String? epicNumber;
    final epicMatch = RegExp(r'\b([A-Z]{3}[0-9]{7})\b').firstMatch(text) ??
        RegExp(r'\b([A-Z]{2,3}[/0-9]{6,12})\b').firstMatch(text);
    if (epicMatch != null) {
      epicNumber = epicMatch.group(1);
      confidence += 50;
    }

    // 2. DOB or Age
    final dob = _extractDob(text);
    if (dob != null) confidence += 15;

    // 3. Gender
    final gender = _extractGender(text);
    if (gender != null) confidence += 10;

    // 4. Name & Father / Husband Name
    String? name;
    String? fatherName;

    final nameMatch = RegExp(r'(?:Elector(?:\x27s)?\s*Name|Name)[:\s\-]+([^\n\r,]+)', caseSensitive: false).firstMatch(rawText);
    if (nameMatch != null && _isValidEnglishName(nameMatch.group(1)!)) {
      name = _cleanPersonName(nameMatch.group(1)!);
      confidence += 20;
    }

    final fatherMatch = RegExp(r'(?:Father(?:\x27s)?\s*Name|Husband(?:\x27s)?\s*Name)[:\s\-]+([^\n\r,]+)', caseSensitive: false).firstMatch(rawText);
    if (fatherMatch != null && _isValidEnglishName(fatherMatch.group(1)!)) {
      fatherName = _cleanPersonName(fatherMatch.group(1)!);
      confidence += 15;
    }

    if (name == null) {
      for (final line in lines) {
        if (_isValidPersonName(line)) {
          name = _toTitleCase(line);
          confidence += 10;
          break;
        }
      }
    }

    if (epicNumber == null && name == null) {
      confidence = 0;
    }

    return OcrResult(
      name: name,
      fatherName: fatherName,
      dob: dob,
      gender: gender,
      idNumber: epicNumber,
      confidence: confidence.clamp(0, 100),
      rawText: text,
    );
  }

  // ── Other Govt ID ──────────────────────────────────────────────────────────
  static OcrResult _parseOther(String rawText) {
    final text = _clean(rawText);
    final dob = _extractDob(text);
    final phone = _extractPhone(text);
    final gender = _extractGender(text);

    return OcrResult(
      dob: dob,
      phone: phone,
      gender: gender,
      confidence: (dob != null || phone != null) ? 20 : 0,
      rawText: text,
    );
  }

  static String? _validateOrRepairAadhaar(String rawCandidate) {
    // Check if Masked Aadhaar
    final maskedMatch = RegExp(r'(?:[Xx*•]{4}\s?){2}(\d{4})').firstMatch(rawCandidate);
    if (maskedMatch != null) {
      return 'XXXX XXXX ${maskedMatch.group(1)}';
    }

    final clean = rawCandidate.replaceAll(RegExp(r'\s+'), '');
    if (clean.length != 12 || !RegExp(r'^\d{12}$').hasMatch(clean)) {
      return null;
    }

    // 1. Direct Verhoeff validation
    if (AadhaarValidator.validateVerhoeff(clean)) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8)}';
    }

    // 2. Single-character OCR error correction permutation
    const Map<String, List<String>> confusions = {
      '8': ['3', '0', '9'],
      '3': ['8'],
      '0': ['8', '6', '9'],
      '6': ['0', '5', '8'],
      '1': ['7', '4'],
      '7': ['1'],
      '5': ['6', '3'],
      '9': ['0', '8'],
    };

    String? repaired;
    int repairCount = 0;

    for (int i = 0; i < 12; i++) {
      final ch = clean[i];
      final alts = confusions[ch];
      if (alts != null) {
        for (final alt in alts) {
          final candidate = clean.substring(0, i) + alt + clean.substring(i + 1);
          if (AadhaarValidator.validateVerhoeff(candidate)) {
            repaired = candidate;
            repairCount++;
          }
        }
      }
    }

    if (repairCount == 1 && repaired != null) {
      return '${repaired.substring(0, 4)} ${repaired.substring(4, 8)} ${repaired.substring(8)}';
    }

    return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8)}';
  }

  // ── Aadhaar Card (Bilingual Pre-processing & Structured Parser) ─────────────
  static OcrResult _parseAadhaar(String rawText) {
    // 1. Bilingual Noise Filtering: Strip isolated 1-2 char punctuation lines like ". EI", "w .", "~"
    final rawLines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final cleanLines = <String>[];
    for (final l in rawLines) {
      final ascii = l.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim();
      if (ascii.length <= 2 && !RegExp(r'^[A-Za-z0-9]{2}$').hasMatch(ascii)) continue;
      if (RegExp(r'^[.\-—~`|^_*+=\s\x22\x27]+$').hasMatch(ascii)) continue;
      cleanLines.add(l);
    }

    final text = _clean(rawText);
    int confidence = 0;

    // 2. Aadhaar Number (4-4-4 pattern or 12 contiguous digits, or Masked Aadhaar)
    String? aadhaarNumber;
    final numMatch = RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b').firstMatch(text) ??
        RegExp(r'\b(\d{12})\b').firstMatch(text) ??
        RegExp(r'\b(?:[Xx*•]{4}[\s\-]){2}(\d{4})\b').firstMatch(text);
    if (numMatch != null) {
      final rawMatch = numMatch.group(0)!;
      aadhaarNumber = _validateOrRepairAadhaar(rawMatch);
      if (aadhaarNumber != null) {
        final cleanDigits = aadhaarNumber.replaceAll(RegExp(r'\s+'), '');
        if (cleanDigits.length == 12 && AadhaarValidator.validateVerhoeff(cleanDigits)) {
          confidence += 45; // Validated with 100% genuine Verhoeff checksum
        } else {
          confidence += 30;
        }
      }
    }

    // 3. DOB
    final dob = _extractDob(rawText);
    if (dob != null) confidence += 15;

    // 4. Gender
    final gender = _extractGender(rawText);
    if (gender != null) confidence += 10;

    // 5. English Name: Look specifically for clean English words above DOB / Gender
    String? name;
    int anchorLineIdx = -1;
    for (int i = 0; i < cleanLines.length; i++) {
      final l = cleanLines[i].toLowerCase();
      if (l.contains('dob') ||
          l.contains('जन्म तारीख') ||
          l.contains('जन्म वर्ष') ||
          l.contains('जन्मदिनांक') ||
          l.contains('year of birth') ||
          RegExp(r'\b\d{2}[/\-.]\d{2}[/\-.]\d{4}\b').hasMatch(l)) {
        anchorLineIdx = i;
        break;
      }
    }
    if (anchorLineIdx == -1) {
      for (int i = 0; i < cleanLines.length; i++) {
        final l = cleanLines[i].toLowerCase();
        if (l.contains('male') || l.contains('female') || l.contains('पुरुष') || l.contains('महिला') || l.contains('तृतीयपंथी')) {
          anchorLineIdx = i;
          break;
        }
      }
    }

    if (anchorLineIdx > 0) {
      for (int i = anchorLineIdx - 1; i >= 0 && i >= anchorLineIdx - 4; i--) {
        final ascii = cleanLines[i].replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim();
        if (_isValidEnglishName(ascii)) {
          name = _toTitleCase(ascii);
          confidence += 20;
          break;
        }
      }
    }

    if (name == null) {
      for (final line in cleanLines) {
        final ascii = line.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim();
        if (_isValidEnglishName(ascii)) {
          name = _toTitleCase(ascii);
          confidence += 15;
          break;
        }
      }
    }

    // 6. Father / Care of
    String? fatherName;
    final relMatch = RegExp(
      r'(?:C/O|S/O|D/O|W/O|Care of|Son of|Daughter of|Wife of|आत्मज|नाते|वडील|पती)[:\s]+([^\n\r,]+)',
      caseSensitive: false,
    ).firstMatch(rawText);
    if (relMatch != null) {
      fatherName = _cleanPersonName(relMatch.group(1)!);
      confidence += 10;
    } else if (name != null) {
      // Middle name fallback
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length == 3 && parts[1].length > 2) {
        fatherName = parts[1];
      }
    }

    // 7. Address & PIN (Aadhaar Back)
    final address = _extractAadhaarAddress(cleanLines, text);
    final pinCode = _extractPin(text);
    if (address != null) confidence += 15;

    final phone = _extractPhone(text);

    return OcrResult(
      name: name,
      fatherName: fatherName,
      dob: dob,
      gender: gender,
      idNumber: aadhaarNumber,
      address: address,
      pinCode: pinCode,
      phone: phone,
      confidence: confidence.clamp(0, 100),
      rawText: rawText,
    );
  }

  static String? _extractAadhaarAddress(List<String> cleanLines, String text) {
    int addrStartIdx = -1;
    for (int i = 0; i < cleanLines.length; i++) {
      final l = cleanLines[i].toLowerCase();
      if (l.contains('address') || l.contains('पत्ता') || l.contains('पता')) {
        addrStartIdx = i;
        break;
      }
    }

    if (addrStartIdx >= 0) {
      final collected = <String>[];
      for (int i = addrStartIdx; i < cleanLines.length && i < addrStartIdx + 7; i++) {
        final line = _clean(cleanLines[i]);
        if (line.isEmpty || _isAadhaarBoilerplate(line)) continue;
        if (RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b').hasMatch(line)) break;
        collected.add(line);
        if (RegExp(r'\b\d{6}\b').hasMatch(line)) break;
      }
      if (collected.isNotEmpty) {
        return collected
            .join(', ')
            .replaceAll(RegExp(r'^(?:address|पत्ता|पता)[:\s\-]*', caseSensitive: false), '')
            .replaceAll(RegExp(r',\s*,+'), ',')
            .trim();
      }
    }

    final pin = _extractPin(text);
    if (pin != null) {
      final pinIdx = cleanLines.indexWhere((l) => l.contains(pin));
      if (pinIdx > 0) {
        final parts = <String>[];
        final start = (pinIdx - 3).clamp(0, pinIdx);
        for (int i = start; i <= pinIdx; i++) {
          final l = _clean(cleanLines[i]);
          if (!_isAadhaarBoilerplate(l) && !_isKeyword(l)) parts.add(l);
        }
        if (parts.isNotEmpty) return parts.join(', ');
      }
    }

    return null;
  }

  // ── College / Student ID ───────────────────────────────────────────────────
  static OcrResult _parseCollegeId(String rawText) {
    final text = _clean(rawText);
    final lines = _lines(rawText);
    int confidence = 0;

    String? rollNumber;
    for (final keyword in ['roll', 'enrollment', 'enroll', 'reg', 'registration', 'student id', 'id no']) {
      final val = _valueAfterLabel(lines, keyword) ?? _inlineValue(text, keyword);
      if (val != null && RegExp(r'^[A-Z0-9/\-]{3,20}$', caseSensitive: false).hasMatch(val.trim())) {
        rollNumber = val.trim().toUpperCase();
        confidence += 35;
        break;
      }
    }

    String? name = _valueAfterLabel(lines, 'name') ?? _inlineValue(text, 'name');
    if (name != null && _isValidEnglishName(name)) {
      name = _toTitleCase(name);
      confidence += 20;
    }

    String? college;
    for (final keyword in ['college', 'institute', 'university', 'polytechnic', 'school']) {
      final val = _valueAfterLabel(lines, keyword) ?? _inlineValue(text, keyword);
      if (val != null && val.trim().length >= 4) {
        college = val.trim();
        confidence += 20;
        break;
      }
    }

    String? course;
    for (final keyword in ['course', 'programme', 'program', 'degree', 'branch', 'class']) {
      final val = _valueAfterLabel(lines, keyword) ?? _inlineValue(text, keyword);
      if (val != null && val.trim().length >= 2) {
        course = val.trim();
        confidence += 10;
        break;
      }
    }

    final dob = _extractDob(text);
    final phone = _extractPhone(text);

    // If no meaningful ID or college was found, zero the confidence
    if (rollNumber == null && college == null) {
      confidence = 0;
    }

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

  // ── Helper Utilities ───────────────────────────────────────────────────────
  static String _clean(String text) =>
      text.replaceAll(RegExp(r'[^\x00-\x7F]+'), ' ').replaceAll(RegExp(r' {2,}'), ' ').trim();

  static List<String> _lines(String text) =>
      _clean(text).split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  static String _cleanPersonName(String raw) {
    return _toTitleCase(
      raw.replaceAll(RegExp(r'^(?:Sri|Smt|Mr|Mrs|Ms)\.?\s+', caseSensitive: false), '').trim(),
    );
  }

  static bool _isValidEnglishName(String s) {
    final trimmed = s.trim();
    if (trimmed.length < 3 || trimmed.length > 50) return false;
    if (!RegExp(r'^[A-Za-z\s.\-]+$').hasMatch(trimmed)) return false;
    if (_isKeyword(trimmed) || _isAadhaarBoilerplate(trimmed)) return false;
    if (RegExp(r'\d').hasMatch(trimmed)) return false;
    final lower = trimmed.toLowerCase();
    const banned = [
      'enrolment', 'enrollment', 'government', 'india', 'authority',
      'identity', 'resident', 'help', 'card', 'male', 'female',
      'birth', 'download', 'unique', 'identification', 'po box',
      'income', 'tax', 'department', 'permanent', 'account', 'number',
      'signature', 'photo', 'republic', 'passport', 'driving', 'licence',
      'license', 'transport', 'college', 'institute', 'university',
      'student', 'roll no', 'elector', 'election', 'commission', 'epic'
    ];
    if (banned.any((b) => lower.contains(b))) return false;
    return trimmed.split(RegExp(r'\s+')).every((word) => word.length >= 2);
  }

  static bool _isValidPersonName(String s) => _isValidEnglishName(s);

  static String? _extractDob(String text) {
    final datePattern = RegExp(r'\b(\d{2})[/\-.](\d{2})[/\-.](\d{4})\b');
    final dobLabelPattern = RegExp(
      r'(?:dob|date of birth|birth date|जन्म तारीख|जन्मदिनांक)\s*[:\-]?\s*',
      caseSensitive: false,
    );

    for (final line in text.split('\n')) {
      if (dobLabelPattern.hasMatch(line)) {
        final match = datePattern.firstMatch(line);
        if (match != null) {
          return '${match.group(1)}/${match.group(2)}/${match.group(3)}';
        }
      }
    }

    final lines = text.split('\n');
    for (int i = 0; i < lines.length - 1; i++) {
      if (dobLabelPattern.hasMatch(lines[i])) {
        final match = datePattern.firstMatch(lines[i + 1]);
        if (match != null) {
          return '${match.group(1)}/${match.group(2)}/${match.group(3)}';
        }
      }
    }

    // Skip issue/print date lines
    final issuePattern = RegExp(r'(?:issue|print|enrol|generated|updated)', caseSensitive: false);
    for (final line in text.split('\n')) {
      if (issuePattern.hasMatch(line)) continue;
      final match = datePattern.firstMatch(line);
      if (match != null) {
        final year = int.tryParse(match.group(3) ?? '');
        if (year != null && year >= 1920 && year <= 2015) {
          return '${match.group(1)}/${match.group(2)}/${match.group(3)}';
        }
      }
    }

    final match = datePattern.firstMatch(text);
    if (match == null) return null;
    return '${match.group(1)}/${match.group(2)}/${match.group(3)}';
  }

  static String? _extractPin(String text) {
    final match = RegExp(r'\b([1-9]\d{5})\b').firstMatch(text);
    return match?.group(1);
  }

  static String? _extractPhone(String text) {
    final match = RegExp(r'\b([6-9]\d{9})\b').firstMatch(text);
    return match?.group(1);
  }

  static String? _extractGender(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('female') || lower.contains('महिला')) return 'female';
    if (lower.contains('male') || lower.contains('पुरुष')) return 'male';
    if (lower.contains('transgender')) return 'other';
    return null;
  }

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

  static String? _inlineValue(String text, String label) {
    final match = RegExp(
      '${RegExp.escape(label)}[:\\s]+([^\\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  static bool _isAadhaarBoilerplate(String line) {
    final lower = line.toLowerCase();
    const boilerplate = [
      'government of india', 'govt of india', 'unique identification',
      'uidai', 'aadhaar', 'enrolment', 'update your', 'www.uidai',
      'help@uidai', 'helpline', '1947', 'toll free', 'resident',
      'ministry of', 'authority of india', 'po box', 'bangalore',
    ];
    return boilerplate.any((b) => lower.contains(b));
  }

  static bool _isKeyword(String line) {
    const keywords = [
      'government', 'india', 'aadhaar', 'unique', 'identification',
      'income', 'tax', 'pan', 'driving', 'licence', 'license',
      'transport', 'authority', 'motor', 'vehicles', 'college',
      'university', 'uidai', 'address', 'father', 'mother', 'husband',
      'valid', 'issue', 'expiry', 'blood', 'vehicle', 'class',
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
}
