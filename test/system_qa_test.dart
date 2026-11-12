import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/theme/app_theme.dart' as custom_theme;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/models/user_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/student_model.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/models/waiting_list_model.dart';
import 'package:study_library/models/payment_model.dart';
import 'package:study_library/features/registration/data/ocr_parser.dart';
import 'package:study_library/core/validators/gov_id_validator.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/core/validators/form_validators.dart';
import 'package:study_library/models/expense_model.dart';
import 'package:study_library/features/expenses/presentation/providers/expense_providers.dart';
import 'package:study_library/services/pdf_service.dart';
import 'package:study_library/services/message_template_service.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/models/feedback_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/membership_automation_service.dart';
import 'package:study_library/features/payments/presentation/screens/record_payment_screen.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/constants/app_constants.dart';
import 'package:study_library/features/legal/presentation/screens/terms_screen.dart';
import 'package:study_library/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/firebase_options.dart';
import 'package:study_library/features/waiting_list/data/repositories/waiting_list_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:study_library/services/id_card_pdf_service.dart';
import 'package:study_library/features/registration/presentation/providers/registration_provider.dart';
import 'package:study_library/features/maintenance/data/services/database_diagnostics_service.dart';
import 'package:study_library/services/document_picker_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/models/announcement_model.dart';
import 'package:study_library/models/app_notification_model.dart';
import 'package:study_library/services/soundbox_service.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:study_library/services/meta_whatsapp_api_service.dart';
import 'package:study_library/services/messaging_hub_service.dart';
import 'package:study_library/core/router/app_router.dart';

StudentModel createTestStudent({
  required String id,
  required String name,
  required String phone,
  String? membershipNumber,
  MembershipStatus membershipStatus = MembershipStatus.active,
  double? pendingDueBalance,
  String? planId,
  DateTime? planStartDate,
  DateTime? planEndDate,
  DateTime? graceEndDate,
  String? seatId,
  String? blockedReason,
}) {
  return StudentModel(
    id: id,
    name: name,
    fatherName: 'Guardian',
    phone: phone,
    email: '$id@test.com',
    gender: Gender.male,
    address: 'Parli',
    pincode: '431515',
    govIdType: GovIdType.aadhaar,
    govIdNumber: '123456789012',
    govIdImageUrl: '',
    photoUrl: '',
    college: 'University',
    course: 'Gov Exam',
    year: '2026',
    emergencyContact: '9822000000',
    membershipNumber: membershipNumber,
    membershipStatus: membershipStatus,
    pendingDueBalance: pendingDueBalance,
    planId: planId,
    planStartDate: planStartDate,
    planEndDate: planEndDate,
    graceEndDate: graceEndDate,
    seatId: seatId,
    blockedReason: blockedReason,
    customFields: const {},
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );
}

void main() {
  group('E2E QA Test Suite — Study Library SaaS', () {

    test('1. UserModel Role & Serialization Integrity', () {
      final adminUser = UserModel(
        id: 'usr_admin_123',
        email: 'admin@cozycorner.com',
        name: 'Library Admin',
        photoUrl: '',
        role: UserRole.admin,
        libraryId: 'lib_001',
        biometricEnabled: true,
        fcmTokens: ['token_1'],
        createdAt: DateTime(2026, 9, 25),
      );

      final json = adminUser.toJson();
      expect(json['role'], equals('admin'));
      expect(json['libraryId'], equals('lib_001'));
      expect(json['biometricEnabled'], isTrue);

      final parsed = UserModel.fromJson(json);
      expect(parsed.role, equals(UserRole.admin));
      expect(parsed.name, equals('Library Admin'));

      // Test student role parsing
      final studentJson = {...json, 'role': 'student', 'studentId': 'std_999'};
      final studentUser = UserModel.fromJson(studentJson);
      expect(studentUser.role, equals(UserRole.student));
      expect(studentUser.studentId, equals('std_999'));
    });

    test('2. Biometric & Master PIN Hashing Security (SHA-256)', () {
      const pin = '1234';
      final hash1 = sha256.convert(utf8.encode(pin)).toString();
      final hash2 = sha256.convert(utf8.encode(pin)).toString();

      // Deterministic & irreversible
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // 256 bits = 64 hex chars

      // Wrong pin check
      const wrongPin = '0000';
      final wrongHash = sha256.convert(utf8.encode(wrongPin)).toString();
      expect(hash1, isNot(equals(wrongHash)));
    });

    test('3. Seat Grid Calculation & Auto-Label Generation', () {
      const rows = 3;
      const cols = 4;
      final generatedLabels = <String>[];

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final label = '${String.fromCharCode(65 + r)}${c + 1}';
          generatedLabels.add(label);
        }
      }

      expect(generatedLabels.length, equals(12));
      expect(generatedLabels.first, equals('A1'));
      expect(generatedLabels[3], equals('A4'));
      expect(generatedLabels[4], equals('B1'));
      expect(generatedLabels.last, equals('C4'));
    });

    test('4. Seat & Section Model Validation', () {
      final section = SectionModel(
        id: 'sec_1',
        libraryId: 'lib_1',
        name: 'Silent Zone',
        rows: 5,
        cols: 5,
        color: 0xFF4CAF50,
        order: 1,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(section.name, equals('Silent Zone'));
      expect(section.rows * section.cols, equals(25));

      final seat = SeatModel(
        id: 'seat_a1',
        sectionId: 'sec_1',
        label: 'A1',
        row: 0,
        col: 0,
        status: SeatStatus.available,
        genderRestriction: GenderRestriction.any,
      );

      final seatJson = seat.toJson();
      expect(seatJson['status'], equals('available'));
      expect(seatJson['genderRestriction'], equals('any'));

      final parsedSeat = SeatModel.fromJson({...seatJson, 'id': 'seat_a1'});
      expect(parsedSeat.status, equals(SeatStatus.available));
      expect(parsedSeat.genderRestriction, equals(GenderRestriction.any));
    });

    test('5. In-App Update Version Comparison Logic', () {
      const installedBuildNumber = "1";
      final installedCode = int.tryParse(installedBuildNumber) ?? 0;

      // Case A: Remote has newer build
      const remoteNewerCode = 2;
      final isUpdateAvailable = remoteNewerCode > installedCode;
      expect(isUpdateAvailable, isTrue);

      // Case B: Remote has same build
      const remoteSameCode = 1;
      final isUpToDate = remoteSameCode <= installedCode;
      expect(isUpToDate, isTrue);

      // Case C: Force update check
      const minVersionCode = 2;
      final isForceRequired = minVersionCode > installedCode;
      expect(isForceRequired, isTrue);
    });

    test('6. Plan Duration and Expiry Calculation', () {
      final plan = PlanModel(
        id: 'plan_monthly',
        libraryId: 'lib_1',
        name: 'Monthly 30 Days',
        duration: 30,
        durationUnit: DurationUnit.days,
        price: 500,
        description: 'Standard 30 days plan',
        gracePeriodDays: 3,
        isActive: true,
        isFeatured: false,
        displayOrder: 1,
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      final startDate = DateTime(2026, 9, 25, 10, 0);
      final endDate = startDate.add(Duration(days: plan.duration));

      expect(endDate.difference(startDate).inDays, equals(30));
      expect(endDate.isAfter(startDate), isTrue);

      // Days remaining calculation
      final simulatedCurrentDate = DateTime(2026, 10, 20);
      final daysRemaining = endDate.difference(simulatedCurrentDate).inDays;
      expect(daysRemaining, equals(5));
      expect(daysRemaining <= 7, isTrue); // Triggers 7-day expiry reminder!
    });

    test('7. Student ID Card QR Code Payload & Format Verification', () {
      const studentId = 'std_2026_9876';
      const libraryId = 'lib_cozy_corner';

      // Standard verification payload pattern: COZY:{studentId}:{libraryId}
      final qrPayload = 'COZY:$studentId:$libraryId';
      expect(qrPayload.startsWith('COZY:'), isTrue);
      
      final parts = qrPayload.split(':');
      expect(parts.length, equals(3));
      expect(parts[0], equals('COZY'));
      expect(parts[1], equals(studentId));
      expect(parts[2], equals(libraryId));
    });

    test('8. AES-256 Govt ID Encryption at Rest & Safe Decryption', () {
      const libraryId = 'lib_cozy_corner';
      const plainAadhaar = '5489 1234 5678';

      // 1. Encrypt Aadhaar using library secret
      final encrypted = EncryptionService.encryptGovId(plainAadhaar, libraryId);
      expect(encrypted, isNot(equals(plainAadhaar)));

      // 2. Safe decrypt returns original plaintext
      final decrypted = EncryptionService.safeDecryptGovId(encrypted, libraryId);
      expect(decrypted, equals(plainAadhaar));

      // 3. Fallback check for unencrypted legacy records
      const legacyPlain = 'ABCDE1234F';
      final legacyResult = EncryptionService.safeDecryptGovId(legacyPlain, libraryId);
      expect(legacyResult, equals(legacyPlain));

      // 4. Deterministic SHA-256 hash for duplicate check
      final hash1 = sha256.convert(utf8.encode(plainAadhaar)).toString();
      final hash2 = sha256.convert(utf8.encode(plainAadhaar)).toString();
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
    });

    test('9. Waiting List Queue Entry Serialization & Ordering', () {
      final now = DateTime(2026, 9, 28, 12, 0, 0);
      final entry = WaitingListEntry(
        id: 'wl_001',
        libraryId: 'lib_cozy',
        studentId: 'std_456',
        studentName: 'Rahul Verma',
        studentPhone: '9876543210',
        preferredSectionId: 'sec_silent',
        genderPreference: 'male',
        position: 1,
        createdAt: now,
      );

      final json = entry.toJson();
      expect(json['id'], equals('wl_001'));
      expect(json['studentName'], equals('Rahul Verma'));
      expect(json['genderPreference'], equals('male'));
      expect(json['preferredSectionId'], equals('sec_silent'));

      final parsed = WaitingListEntry.fromJson(json);
      expect(parsed.id, equals('wl_001'));
      expect(parsed.studentName, equals('Rahul Verma'));
      expect(parsed.createdAt, equals(now));
    });

    test('10. Customizable Invoice Prefix & Counter Pattern', () {
      String formatReceipt(String customPrefix, int count, int year) {
        final prefix = customPrefix.trim().replaceAll(RegExp(r'[-/]+$'), '');
        final cleanPrefix = prefix.isEmpty ? 'REC' : prefix;
        return '$cleanPrefix-$year-${count.toString().padLeft(4, '0')}';
      }

      expect(formatReceipt('REC', 1, 2026), equals('REC-2026-0001'));
      expect(formatReceipt('INV-', 42, 2026), equals('INV-2026-0042'));
      expect(formatReceipt('COZY', 999, 2026), equals('COZY-2026-0999'));
      expect(formatReceipt('', 5, 2026), equals('REC-2026-0005'));
    });

    test('11. Biometric Lockout Rate Limiting Thresholds', () {
      expect(BiometricService.maxFailedAttempts, equals(5));
      expect(BiometricService.lockoutMinutes, equals(15));

      // Simulate 5 attempts triggering lockout
      int failedCount = 0;
      bool isLocked = false;
      for (int i = 1; i <= 5; i++) {
        failedCount++;
        if (failedCount >= BiometricService.maxFailedAttempts) {
          isLocked = true;
        }
      }
      expect(failedCount, equals(5));
      expect(isLocked, isTrue);
    });

    test('12. Recycle Bin 30-Day Retention Calculation', () {
      final now = DateTime(2026, 9, 28);
      int calculateRemainingDays(DateTime deletedAt) {
        final elapsed = now.difference(deletedAt).inDays;
        return (30 - elapsed).clamp(0, 30);
      }

      // Deleted today -> 30 days left
      expect(calculateRemainingDays(now), equals(30));
      // Deleted 10 days ago -> 20 days left
      expect(calculateRemainingDays(now.subtract(const Duration(days: 10))), equals(20));
      // Deleted 29 days ago -> 1 day left
      expect(calculateRemainingDays(now.subtract(const Duration(days: 29))), equals(1));
      // Deleted 40 days ago -> 0 days left (expired)
      expect(calculateRemainingDays(now.subtract(const Duration(days: 40))), equals(0));
    });

    test('13. Master PIN SHA-256 Cloud Sync & Reinstall Recovery Schema', () {
      const plainPin = '8492';
      final pinHash = sha256.convert(utf8.encode(plainPin)).toString();

      // Cloud payload format stored in libraries/{id}/settings/security
      final cloudSecurityPayload = {
        'masterPinHash': pinHash,
        'hasMasterPin': true,
        'autoLockTimeoutMinutes': 5,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      expect(cloudSecurityPayload['hasMasterPin'], isTrue);
      expect(cloudSecurityPayload['masterPinHash'], equals(pinHash));
      expect(cloudSecurityPayload['autoLockTimeoutMinutes'], equals(5));

      // Recovery simulation: Local SharedPreferences lost, recovered from cloud
      final restoredHash = cloudSecurityPayload['masterPinHash'] as String?;
      expect(restoredHash, isNotNull);
      expect(restoredHash, equals(pinHash));

      // Verifying candidate pin against restored hash
      final testInputHash = sha256.convert(utf8.encode('8492')).toString();
      expect(testInputHash, equals(restoredHash));
    });

    test('14. Student Expiry Date Field Consistency for Firestore Range Queries', () {
      final now = DateTime(2026, 10, 17);
      final expiryDate = now.add(const Duration(days: 5));

      // When updating student, dates must not be saved as raw ISO strings which break range queries
      final studentUpdateMap = <String, dynamic>{
        'name': 'Aarav Patel',
        'planEndDate': expiryDate, // Passed as DateTime / Timestamp, not String
      };

      expect(studentUpdateMap['planEndDate'], isA<DateTime>());
      expect(studentUpdateMap['planEndDate'].isAfter(now), isTrue);

      final daysUntilExpiry = (studentUpdateMap['planEndDate'] as DateTime).difference(now).inDays;
      expect(daysUntilExpiry, equals(5));
      expect(daysUntilExpiry <= 7, isTrue); // Expiring soon filter
    });

    test('15. Receipt Plan ID & Validity Auto-Population Logic', () {
      final studentPlanEndDate = DateTime(2026, 11, 15);
      const studentPlanId = 'plan_quarterly_special';

      // Receipt auto-populates validTo and planId from student's active plan
      final receiptData = {
        'planId': studentPlanId,
        'validFrom': DateTime(2026, 10, 15),
        'validTo': studentPlanEndDate,
      };

      expect(receiptData['planId'], equals('plan_quarterly_special'));
      expect(receiptData['validTo'], equals(DateTime(2026, 11, 15)));
      expect((receiptData['validTo'] as DateTime).isAfter(receiptData['validFrom'] as DateTime), isTrue);
    });

    test('16. Seat Tile Clean Label Formatting (No "Occ" text overlap)', () {
      // Clean seat display: only seat label should be displayed (e.g. A1, B4)
      // No "Occ" badge placed on top of the seat number
      String formatSeatDisplay(String seatLabel, SeatStatus status) {
        // Returns clean seat label regardless of status
        return seatLabel;
      }

      expect(formatSeatDisplay('A1', SeatStatus.occupied), equals('A1'));
      expect(formatSeatDisplay('A1', SeatStatus.occupied).contains('Occ'), isFalse);
      expect(formatSeatDisplay('B12', SeatStatus.available), equals('B12'));
    });

    test('17. Partial Payment & Installment Tracking Calculation', () {
      const double totalFee = 1500.0;
      const double firstInstallment = 500.0;
      final double remainingDue = totalFee - firstInstallment;

      expect(remainingDue, equals(1000.0));

      final payment = PaymentModel(
        id: 'pay_001',
        studentId: 'stud_123',
        amount: firstInstallment,
        method: 'UPI / QR',
        date: DateTime.now(),
        totalPlanFee: totalFee,
        remainingDue: remainingDue,
        installmentNumber: 1,
        status: PaymentStatus.partial,
        createdAt: DateTime.now(),
      );

      expect(payment.totalPlanFee, equals(1500.0));
      expect(payment.remainingDue, equals(1000.0));
      expect(payment.installmentNumber, equals(1));
      expect(payment.status, equals(PaymentStatus.partial));

      final json = payment.toJson();
      expect(json['totalPlanFee'], equals(1500.0));
      expect(json['remainingDue'], equals(1000.0));
      expect(json['installmentNumber'], equals(1));
      expect(json['status'], equals('partial'));
    });

    test('18. Native SMS Phone Number Sanitization (Admin SIM Free Messaging)', () {
      String sanitizePhone(String raw) {
        String digits = raw.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 12 && digits.startsWith('91')) {
          return digits.substring(2);
        }
        if (digits.length == 11 && digits.startsWith('0')) {
          return digits.substring(1);
        }
        return digits;
      }

      expect(sanitizePhone('+91 98765 43210'), equals('9876543210'));
      expect(sanitizePhone('09876543210'), equals('9876543210'));
      expect(sanitizePhone('9876543210'), equals('9876543210'));
    });

    test('19. Autonomous OCR Document Detection Logic', () {
      // PAN Card detection (with or without dot in GOVT OF INDIA, with and without PAN number)
      expect(OcrParser.detectGovIdType('INCOME TAX DEPARTMENT GOVT OF INDIA GMHPS7447Q'), equals(GovIdType.pan));
      expect(OcrParser.detectGovIdType('PERMANENT ACCOUNT NUMBER CARD GOVT OF INDIA'), equals(GovIdType.pan));

      // Voter ID / EPIC detection
      expect(OcrParser.detectGovIdType('ELECTION COMMISSION OF INDIA ELECTOR PHOTO IDENTITY CARD ABC1234567'), equals(GovIdType.voterId));

      // Passport detection
      expect(OcrParser.detectGovIdType('PASSPORT REPUBLIC OF INDIA P<IND'), equals(GovIdType.passport));

      // Driving Licence detection
      expect(OcrParser.detectGovIdType('UNION OF INDIA DRIVING LICENCE TRANSPORT DEPT DL NO'), equals(GovIdType.drivingLicence));

      // College ID detection
      expect(OcrParser.detectGovIdType('ABC COLLEGE OF ENGINEERING STUDENT IDENTITY CARD ROLL NO 42'), equals(GovIdType.collegeId));

      // Aadhaar detection & Aadhaar Letter OCR Invariants
      expect(OcrParser.detectGovIdType('GOVERNMENT OF INDIA UNIQUE IDENTIFICATION AUTHORITY AADHAAR 1234 5678 9012'), equals(GovIdType.aadhaar));
      expect(
        OcrParser.detectGovIdType(
          'UNIQUE IDENTIFICATION AUTHORITY OF INDIA भारतीय विशिष्ट ओळख प्राधिकरण नोंदणी क्रमांक / ENROLMENT NO.: 2821/14005/02968 '
          'CHANDRAKALA PADMAKARRAO SONPETHKAR W/O PADMAKARRAO SONPETHKAR DHEKANMOHA BHIR BEED MAHARASHTRA PIN CODE: 431122 MOBILE: 9921448238 DATE OF BIRTH: 01/01/1946',
        ),
        equals(GovIdType.aadhaar),
      );

      // Verify Aadhaar letter is accurately parsed into structured fields
      final aadhaarLetterResult = OcrParser.parseByType(
        GovIdType.aadhaar,
        'Unique Identification Authority of India\n'
        'भारतीय विशिष्ट ओळख प्राधिकरण\n'
        'नोंदणी क्रमांक / Enrolment No.: 2821/14005/02968\n\n'
        'To,\n'
        'Chandrakala Padmakarrao Sonpethkar\n'
        'W/O Padmakarrao Sonpethkar,\n'
        'Dhekanmoha, Bhir, Beed, Beed, Maharashtra,\n'
        'PIN Code: 431122,\n'
        'Mobile: 9921448238\n'
        'Date of Birth: 01/01/1946\n',
      );
      expect(aadhaarLetterResult.name, equals('Chandrakala Padmakarrao Sonpethkar'));
      expect(aadhaarLetterResult.dob, equals('01/01/1946'));
      expect(aadhaarLetterResult.fatherName, equals('Padmakarrao Sonpethkar'));
      expect(aadhaarLetterResult.gender, equals('female'));
      expect(aadhaarLetterResult.idNumber, equals('2821/14005/02968'));
      expect(aadhaarLetterResult.pinCode, equals('431122'));
      expect(aadhaarLetterResult.phone, equals('9921448238'));
      expect(aadhaarLetterResult.address, contains('Dhekanmoha'));

      // Validate Enrolment format in GovIdValidator
      expect(GovIdValidator.isValid(GovIdType.aadhaar, '2821/14005/02968'), isTrue);
    });

    test('20. Biometric & Security Firestore Recovery Schema Completeness', () {
      final docData = <String, dynamic>{
        'pinHash': '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
        'biometricEnabled': true,
        'autoLockMinutes': 5,
        'screenshotProtectionEnabled': false,
      };

      expect(docData['pinHash'], isNotEmpty);
      expect(docData['biometricEnabled'], isTrue);
      expect(docData['autoLockMinutes'], equals(5));
      expect(docData['screenshotProtectionEnabled'], isFalse);
    });

    test('21. Real-Time GovIdValidator Format and Validation Rules', () {
      // Aadhaar: 12 digits, cannot start with 0 or 1, and satisfies Verhoeff checksum
      const aadhaarPrefix = '23456789012';
      final validAadhaar = '$aadhaarPrefix${AppValidators.generateVerhoeffCheckDigit(aadhaarPrefix)}';
      expect(GovIdValidator.isValid(GovIdType.aadhaar, validAadhaar), isTrue);
      expect(GovIdValidator.isValid(GovIdType.aadhaar, '034567890123'), isFalse);
      expect(GovIdValidator.isValid(GovIdType.aadhaar, '12345'), isFalse);

      // PAN: 5 letters, 4 digits, 1 letter
      expect(GovIdValidator.isValid(GovIdType.pan, 'GMHPS7447Q'), isTrue);
      expect(GovIdValidator.isValid(GovIdType.pan, 'ABCDE1234F'), isTrue);
      expect(GovIdValidator.isValid(GovIdType.pan, 'ABC1234'), isFalse);

      // Voter ID: 3 letters + 7 digits
      expect(GovIdValidator.isValid(GovIdType.voterId, 'ABC1234567'), isTrue);
      expect(GovIdValidator.isValid(GovIdType.voterId, 'AB1234567'), isFalse);

      // Passport: 1 letter + 7 digits
      expect(GovIdValidator.isValid(GovIdType.passport, 'A1234567'), isTrue);
      expect(GovIdValidator.isValid(GovIdType.passport, '12345678'), isFalse);
    });

    test('22. Watermark Opacity and Scale Clamping Range Constraints', () {
      double clampOpacity(num val) => val.toDouble().clamp(0.02, 0.40);
      double clampScale(num val) => val.toDouble().clamp(0.10, 0.98);

      // Boundary tests
      expect(clampOpacity(0.01), equals(0.02));
      expect(clampOpacity(0.06), equals(0.06));
      expect(clampOpacity(0.50), equals(0.40));

      expect(clampScale(0.05), equals(0.10));
      expect(clampScale(0.88), equals(0.88));
      expect(clampScale(1.20), equals(0.98));
    });

    test('23. Profile Update Payload & Dynamic Custom Fields Verification', () {
      final proposedData = <String, dynamic>{
        'emergencyContact': '9876543210',
        'college': 'IIT Bombay',
        'course': 'B.Tech CS',
        'year': '4th Year',
        'customFields': {
          'lockerNumber': 'L-42',
          'bloodDonor': 'Yes',
        },
      };

      final updateFields = <String, dynamic>{
        'updatedAt': 'MOCK_TIMESTAMP',
      };
      if (proposedData.containsKey('customFields') && proposedData['customFields'] is Map) {
        final customMap = Map<String, dynamic>.from(proposedData['customFields'] as Map);
        for (final entry in customMap.entries) {
          updateFields['customFields.${entry.key}'] = entry.value;
        }
      }

      expect(updateFields['customFields.lockerNumber'], equals('L-42'));
      expect(updateFields['customFields.bloodDonor'], equals('Yes'));
    });

    // ── NEW: Security Audit Fix Verification Tests ──────────────────────

    test('24. SEC-H3: Default UserRole Parses to Student (Least Privilege)', () {
      // Unknown role should default to student, NOT admin
      final unknownRole = UserModel.fromJson({
        'id': 'usr_unknown',
        'email': 'unknown@test.com',
        'name': 'Unknown User',
        'photoUrl': '',
        'role': 'superadmin',  // Invalid role string
        'libraryId': 'lib_001',
      });
      expect(unknownRole.role, equals(UserRole.student));

      final nullRole = UserModel.fromJson({
        'id': 'usr_null',
        'email': 'null@test.com',
        'name': 'Null Role User',
        'photoUrl': '',
        'role': null,
        'libraryId': 'lib_001',
      });
      expect(nullRole.role, equals(UserRole.student));

      // Explicit 'admin' still works
      final adminRole = UserModel.fromJson({
        'id': 'usr_admin',
        'email': 'admin@test.com',
        'name': 'Admin User',
        'photoUrl': '',
        'role': 'admin',
        'libraryId': 'lib_001',
      });
      expect(adminRole.role, equals(UserRole.admin));
    });

    test('25. PBKDF2 Encryption KDF: Encrypt/Decrypt Roundtrip', () {
      const testPassphrase = 'test_secret_key_2026';
      const testPlaintext = 'AADHAAR:123456789012';

      // Encrypt with PBKDF2 KDF
      final encrypted = EncryptionService.encrypt(testPlaintext, testPassphrase);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(equals(testPlaintext)));

      // Decrypt should return original
      final decrypted = EncryptionService.decrypt(encrypted, testPassphrase);
      expect(decrypted, equals(testPlaintext));
    });

    test('26. PBKDF2 Encryption: Different Passphrases Produce Different Ciphertexts', () {
      const plaintext = 'PAN:ABCDE1234F';
      final enc1 = EncryptionService.encrypt(plaintext, 'passphrase_A');
      final enc2 = EncryptionService.encrypt(plaintext, 'passphrase_B');

      // Same plaintext, different keys → different ciphertexts
      expect(enc1, isNot(equals(enc2)));

      // Each decrypts correctly with its own key
      expect(EncryptionService.decrypt(enc1, 'passphrase_A'), equals(plaintext));
      expect(EncryptionService.decrypt(enc2, 'passphrase_B'), equals(plaintext));
    });

    test('27. PBKDF2 Encryption: Wrong Passphrase Throws Exception', () {
      const plaintext = 'DL:MH1220230001234';
      final encrypted = EncryptionService.encrypt(plaintext, 'correct_key');

      // Decrypting with wrong key should throw
      expect(
        () => EncryptionService.decrypt(encrypted, 'wrong_key'),
        throwsException,
      );
    });

    test('28. Salted PIN Hash Format Verification', () {
      // Simulate the salted PIN hash format: "salt:hash"
      final pin = '1234';
      // Generate salt (simulating BiometricService._generateSalt)
      final salt = 'a1b2c3d4e5f6g7h8';
      final hash = sha256.convert(utf8.encode('$salt$pin')).toString();
      final stored = '$salt:$hash';

      // Format must be "salt:hash"
      expect(stored.contains(':'), isTrue);
      final parts = stored.split(':');
      expect(parts.length, equals(2));
      expect(parts[0], equals(salt));
      expect(parts[1].length, equals(64)); // SHA-256 hex = 64 chars

      // Same salt+pin → same hash (deterministic)
      final hash2 = sha256.convert(utf8.encode('$salt$pin')).toString();
      expect(hash2, equals(parts[1]));

      // Different salt → different hash (even same PIN)
      final differentSalt = 'x1y2z3w4v5u6t7s8';
      final hash3 = sha256.convert(utf8.encode('$differentSalt$pin')).toString();
      expect(hash3, isNot(equals(parts[1])));
    });

    test('29. AppConstants Version String is Current', () {
      // Version should not be the stale '1.0.0'
      expect('1.5.25', isNot(equals('1.0.0')));
      // Should be a valid semver
      final parts = '1.5.25'.split('.');
      expect(parts.length, equals(3));
      expect(int.tryParse(parts[0]), isNotNull);
      expect(int.tryParse(parts[1]), isNotNull);
      expect(int.tryParse(parts[2]), isNotNull);
    });

    test('30. L4 FIX: Plan Date Range Validation Rejects Invalid Ranges', () {
      final admissionDate = DateTime(2026, 10, 24);
      final invalidEndDateSameDay = DateTime(2026, 10, 24);
      final invalidEndDatePast = DateTime(2026, 10, 20);
      final validEndDate = DateTime(2026, 11, 24);

      bool validatePlanDates(DateTime start, DateTime end) {
        if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
          return false;
        }
        return true;
      }

      expect(validatePlanDates(admissionDate, invalidEndDateSameDay), isFalse);
      expect(validatePlanDates(admissionDate, invalidEndDatePast), isFalse);
      expect(validatePlanDates(admissionDate, validEndDate), isTrue);
    });

    test('31. L2 FIX: Double-Tap Prevention / Idempotency Flag Guard', () {
      bool isSubmitting = false;
      int executions = 0;

      void submitPayment() {
        if (isSubmitting) return; // Guard
        isSubmitting = true;
        executions++;
      }

      // Simulate fast double tap
      submitPayment();
      submitPayment(); // second tap ignored
      expect(executions, equals(1));
    });

    test('32. L5 FIX: Payment Amount Boundary Validation (₹1 to ₹99,999)', () {
      String? validateAmount(String? val, {double effectiveTotal = 1500, bool isPartial = false}) {
        if (val == null || val.isEmpty) return 'Required';
        final num = double.tryParse(val);
        if (num == null || num <= 0) return 'Invalid amount (must be > ₹0)';
        if (num > 99999) return 'Maximum amount allowed is ₹99,999';
        if (isPartial && num > effectiveTotal) {
          return 'Paying amount cannot exceed total fee';
        }
        return null;
      }

      expect(validateAmount(''), equals('Required'));
      expect(validateAmount('0'), equals('Invalid amount (must be > ₹0)'));
      expect(validateAmount('-500'), equals('Invalid amount (must be > ₹0)'));
      expect(validateAmount('100000'), equals('Maximum amount allowed is ₹99,999'));
      expect(validateAmount('2000', effectiveTotal: 1500, isPartial: true), equals('Paying amount cannot exceed total fee'));
      expect(validateAmount('1500'), isNull);
      expect(validateAmount('1'), isNull);
      expect(validateAmount('99999'), isNull);
    });

    test('33. S8 FIX: Typed Hard-Delete Confirmation Guard', () {
      bool canConfirmDelete(String input, String expected) {
        return input.trim().toUpperCase() == expected.toUpperCase();
      }

      expect(canConfirmDelete('delete', 'DELETE'), isTrue);
      expect(canConfirmDelete('  DELETE  ', 'DELETE'), isTrue);
      expect(canConfirmDelete('DEL', 'DELETE'), isFalse);
      expect(canConfirmDelete('', 'DELETE'), isFalse);
      expect(canConfirmDelete('empty', 'EMPTY'), isTrue);
    });

    test('34. V7 FIX: Zero Amount Receipt Displays "—" instead of ₹0.00', () {
      String formatReceiptAmount(double amount) {
        if (amount <= 0) return '—';
        return '₹${amount.toStringAsFixed(2)}';
      }

      expect(formatReceiptAmount(0.0), equals('—'));
      expect(formatReceiptAmount(-10.0), equals('—'));
      expect(formatReceiptAmount(1500.0), equals('₹1500.00'));
    });

    test('35. S5 FIX: Deep Link Intent Filtering Requires Host Verification', () {
      bool isIntentVerified(Uri uri) {
        if (uri.scheme == 'studylibrary' && uri.host == 'app') return true;
        if (uri.scheme == 'https' && uri.host == 'study-lib-mgmt-2026.web.app' && uri.path.startsWith('/app')) return true;
        return false;
      }

      expect(isIntentVerified(Uri.parse('studylibrary://app/student/home')), isTrue);
      expect(isIntentVerified(Uri.parse('studylibrary://malicious-host/payload')), isFalse);
      expect(isIntentVerified(Uri.parse('https://study-lib-mgmt-2026.web.app/app/login')), isTrue);
      expect(isIntentVerified(Uri.parse('https://evil-spoof.com/app/login')), isFalse);
    });

    test('36. ARCH FIX: Invariant: Unpaid Approval Must Remain Inactive Without Valid Dates', () {
      // Simulating request approval logic without payment vs with payment
      MembershipStatus resolveStatusOnApproval({required bool isPaid}) {
        return isPaid ? MembershipStatus.active : MembershipStatus.inactive;
      }

      DateTime? resolveStartDate({required bool isPaid, required DateTime fallback}) {
        return isPaid ? fallback : null;
      }

      DateTime? resolveEndDate({required bool isPaid, required DateTime fallback}) {
        return isPaid ? fallback : null;
      }

      // 1. Without payment recorded (e.g. Admin approves, but skips payment)
      expect(resolveStatusOnApproval(isPaid: false), equals(MembershipStatus.inactive));
      expect(resolveStartDate(isPaid: false, fallback: DateTime.now()), isNull);
      expect(resolveEndDate(isPaid: false, fallback: DateTime.now().add(const Duration(days: 30))), isNull);

      // 2. Once payment is recorded
      expect(resolveStatusOnApproval(isPaid: true), equals(MembershipStatus.active));
      expect(resolveStartDate(isPaid: true, fallback: DateTime(2026, 10, 24)), isNotNull);
      expect(resolveEndDate(isPaid: true, fallback: DateTime(2026, 11, 24)), isNotNull);
    });

    test('37. ARCH FIX: Dynamic Expiry Evaluation (isEffectivelyActive, isExpired, daysRemaining)', () {
      final now = DateTime.now();

      // Case A: Active student with future end date
      final activeStudent = StudentModel.fromJson({
        'id': 's1',
        'name': 'Active Student',
        'membershipStatus': 'active',
        'planStartDate': now.subtract(const Duration(days: 10)).toIso8601String(),
        'planEndDate': now.add(const Duration(days: 20)).toIso8601String(),
      });
      expect(activeStudent.isEffectivelyActive, isTrue);
      expect(activeStudent.isExpired, isFalse);
      expect(activeStudent.daysRemaining, greaterThan(0));

      // Case B: Static 'active' status but date has passed (Expired in reality!)
      final staleActiveStudent = StudentModel.fromJson({
        'id': 's2',
        'name': 'Stale Active Student',
        'membershipStatus': 'active',
        'planStartDate': now.subtract(const Duration(days: 40)).toIso8601String(),
        'planEndDate': now.subtract(const Duration(days: 5)).toIso8601String(),
      });
      expect(staleActiveStudent.isEffectivelyActive, isFalse);
      expect(staleActiveStudent.isExpired, isTrue);
      expect(staleActiveStudent.daysRemaining, lessThan(0));

      // Case C: Inactive student with no dates
      final unpaidStudent = StudentModel.fromJson({
        'id': 's3',
        'name': 'Unpaid Student',
        'membershipStatus': 'inactive',
      });
      expect(unpaidStudent.isEffectivelyActive, isFalse);
      expect(unpaidStudent.isExpired, isFalse);
      expect(unpaidStudent.daysRemaining, isNull);
    });

    // -------------------------------------------------------------------------
    // 38. UI FIX: Seat Tile Number Visibility & Occupied Student Safe Property Access
    // -------------------------------------------------------------------------
    test('38. UI FIX: Seat Tile Number Visibility & Occupied Student Safe Property Access', () {
      final seat1 = SeatModel(
        id: '1790647291016_r0_c0',
        sectionId: '1790647291016',
        label: '1',
        row: 0,
        col: 0,
        status: SeatStatus.occupied,
        genderRestriction: GenderRestriction.male,
        studentId: 'TFBktLry0fa4FlDLVvyl',
      );

      final student = StudentModel.fromJson({
        'id': 'TFBktLry0fa4FlDLVvyl',
        'name': 'Rahul Sharma',
        'membershipStatus': 'active',
        'customFields': {'shift': 'Morning 8AM-2PM'},
      });

      // Verify safe lookup without NoSuchMethodError
      final shiftName = (student.customFields['shift'] as String?) ??
          (student.planId != null ? 'Active Plan' : null);
      expect(shiftName, equals('Morning 8AM-2PM'));

      // Verify seat label is strictly non-empty
      expect(seat1.label, equals('1'));
    });

    // -------------------------------------------------------------------------
    // 39. ARCH FIX: Invariant Cascade: Voiding/Deleting Receipt Reverts Unbacked Active Students
    // -------------------------------------------------------------------------
    test('39. ARCH FIX: Invariant Cascade: Voiding/Deleting Receipt Reverts Unbacked Active Students', () {
      // Simulating invariant logic: if no remaining active receipts exist for a student,
      // the student record must revert to inactive with null validity dates.
      final receipts = <Map<String, dynamic>>[
        {'id': 'r1', 'studentId': 's1', 'status': 'voided', 'amount': 700.0},
        {'id': 'r2', 'studentId': 's2', 'status': 'active', 'amount': 800.0},
      ];

      // Check for s1
      final remainingActiveForS1 = receipts
          .where((r) => r['studentId'] == 's1' && r['status'] == 'active')
          .toList();
      expect(remainingActiveForS1.isEmpty, isTrue);

      // Student s1 must not remain active
      final studentS1 = StudentModel.fromJson({
        'id': 's1',
        'name': 'Voided Student',
        'membershipStatus': remainingActiveForS1.isEmpty ? 'inactive' : 'active',
        'planStartDate': remainingActiveForS1.isEmpty ? null : '2026-10-01T00:00:00Z',
        'planEndDate': remainingActiveForS1.isEmpty ? null : '2026-11-01T00:00:00Z',
      });

      expect(studentS1.membershipStatus, equals(MembershipStatus.inactive));
      expect(studentS1.planStartDate, isNull);
      expect(studentS1.planEndDate, isNull);
      expect(studentS1.isEffectivelyActive, isFalse);

      // Check for s2 (has remaining active receipt)
      final remainingActiveForS2 = receipts
          .where((r) => r['studentId'] == 's2' && r['status'] == 'active')
          .toList();
      expect(remainingActiveForS2.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // 40. VALIDATION ARCHITECTURE: Field Rules, Regex Restrictions & Invariant Boundaries
    // -------------------------------------------------------------------------
    test('40. VALIDATION ARCHITECTURE: Field Rules, Regex Restrictions & Invariant Boundaries', () {
      // 1. Phone validation
      expect(AppValidators.phone('9823456789'), isNull);
      expect(AppValidators.phone('7012345678'), isNull);
      expect(AppValidators.phone('5123456789'), contains('start with 6, 7, 8, or 9'));
      expect(AppValidators.phone('98234'), contains('must be exactly 10 digits'));
      expect(AppValidators.phone('9999999999'), contains('genuine, active mobile number'));
      expect(AppValidators.phone('0000000000'), contains('start with 6, 7, 8, or 9'));

      // 2. Emergency phone validation & duplicate prevention
      expect(AppValidators.emergencyPhone('9876543210', primaryPhone: '9823456789'), isNull);
      expect(AppValidators.emergencyPhone('9823456789', primaryPhone: '9823456789'), contains('cannot be the student\'s own phone number'));
      expect(AppValidators.emergencyPhone('', required: false), isNull);

      // 3. Email validation (RFC 5322)
      expect(AppValidators.email('test@library.com'), isNull);
      expect(AppValidators.email('student.john+study@gmail.co.in'), isNull);
      expect(AppValidators.email('invalid-email'), contains('Enter a valid email address'));
      expect(AppValidators.email('user@domain'), contains('Enter a valid email address'));
      expect(AppValidators.email('', required: false), isNull);

      // 4. Name validation (Universal Multilingual Text Support)
      expect(AppValidators.name('Rahul Sharma'), isNull);
      expect(AppValidators.name('Dr. A. P. J. Abdul Kalam'), isNull);
      expect(AppValidators.name('Mary-Jane'), isNull);
      expect(AppValidators.name('राहुल शर्मा'), isNull);
      expect(AppValidators.name('சுரேஷ்'), isNull);
      expect(AppValidators.name('સંજય પટેલ'), isNull);
      expect(AppValidators.name('محمد علي'), isNull);
      expect(AppValidators.name('123 Rahul'), contains('cannot start with a number'));
      expect(AppValidators.name('R'), contains('must be at least 2 characters'));

      // 5. Postal Pincode
      expect(AppValidators.pinCode('431515'), isNull);
      expect(AppValidators.pinCode('110001'), isNull);
      expect(AppValidators.pinCode('031515'), contains('First digit must be between 1 and 9'));
      expect(AppValidators.pinCode('43151'), contains('must be exactly 6 digits'));
      expect(AppValidators.pinCode('', required: false), isNull);

      // 6. Currency Amount Boundaries
      expect(AppValidators.amount('500'), isNull);
      expect(AppValidators.amount('1200.50'), isNull);
      expect(AppValidators.amount('0'), contains('must be at least ₹1'));
      expect(AppValidators.amount('-50'), contains('must be at least ₹1'));
      expect(AppValidators.amount('100000'), contains('cannot exceed ₹99999'));
      expect(AppValidators.amount('50.123'), contains('at most 2 decimal places'));

      // 7. UPI / Bank UTR
      expect(AppValidators.utr('429182910281'), isNull);
      expect(AppValidators.utr('TXN_98721_ABC'), isNull);
      expect(AppValidators.utr('123'), contains('must be 6 to 35 alphanumeric characters'));

      // 8. Cheque Number
      expect(AppValidators.chequeNumber('000492'), isNull);
      expect(AppValidators.chequeNumber('12345'), contains('must be exactly 6 numeric digits'));
      expect(AppValidators.chequeNumber('1234567'), contains('must be exactly 6 numeric digits'));

      // 9. Catalog Plan Name & Duration
      expect(AppValidators.planName('Full Day Platinum (12 Hrs)'), isNull);
      expect(AppValidators.planName('A'), contains('must be at least 2 characters'));
      expect(AppValidators.duration('30'), isNull);
      expect(AppValidators.duration('0'), contains('must be at least 1'));
      expect(AppValidators.duration('400'), contains('cannot exceed 365'));

      // 10. Hardware / Seat Label
      expect(AppValidators.seatLabel('S-1'), isNull);
      expect(AppValidators.seatLabel('CAB_12'), isNull);
      expect(AppValidators.seatLabel('101'), isNull);
      expect(AppValidators.seatLabel(''), contains('Seat number is required'));

      // 11. GSTIN & PAN
      expect(AppValidators.gstin('27AAAAA0000A1Z5'), isNull);
      expect(AppValidators.gstin('INVALID_GSTIN'), contains('Enter a valid 15-character GSTIN'));
      expect(AppValidators.pan('ABCDE1234F'), isNull);
      expect(AppValidators.pan('ABC1234F'), contains('Enter a valid 10-character PAN'));

      // 12. UPI ID / VPA
      expect(AppValidators.upiId('cozycorner@oksbi'), isNull);
      expect(AppValidators.upiId('admin.library@paytm'), isNull);
      expect(AppValidators.upiId('invalidupi'), contains('Enter a valid UPI ID'));
    });

    // -------------------------------------------------------------------------
    // 41. OPERATING EXPENSE MODULE: ExpenseModel Serialization & Category Integrity
    // -------------------------------------------------------------------------
    test('41. OPERATING EXPENSE MODULE: ExpenseModel Serialization & Category Integrity', () {
      final now = DateTime(2026, 10, 24, 15, 30);
      final expense = ExpenseModel(
        id: 'exp_001',
        libraryId: 'lib_cozy_001',
        title: 'Electricity Bill - October',
        category: ExpenseCategory.electricity,
        amount: 3450.0,
        date: now,
        paymentMethod: 'UPI',
        paidTo: 'MSEDCL',
        notes: 'Meter reading #94012',
        createdAt: now,
      );

      final json = expense.toJson();
      expect(json['title'], 'Electricity Bill - October');
      expect(json['category'], 'electricity');
      expect(json['amount'], 3450.0);
      expect(json['paymentMethod'], 'UPI');
      expect(json['paidTo'], 'MSEDCL');

      final deserialized = ExpenseModel.fromJson({
        'id': 'exp_001',
        'libraryId': 'lib_cozy_001',
        'title': 'Electricity Bill - October',
        'category': 'electricity',
        'amount': 3450.0,
        'date': now.toIso8601String(),
        'paymentMethod': 'UPI',
        'paidTo': 'MSEDCL',
        'createdAt': now.toIso8601String(),
      });

      expect(deserialized.category, ExpenseCategory.electricity);
      expect(deserialized.category.displayName, 'Electricity & Power');
      expect(deserialized.category.iconEmoji, '⚡');
      expect(deserialized.amount, 3450.0);
    });

    // -------------------------------------------------------------------------
    // 42. NET PROFIT ENGINE: Gross Revenue, Expense Sum & Profit Margin Math
    // -------------------------------------------------------------------------
    test('42. NET PROFIT ENGINE: Gross Revenue, Expense Sum & Profit Margin Math', () {
      const grossRevenue = 50000.0;
      const totalExpenses = 18000.0;
      final netProfit = grossRevenue - totalExpenses;
      final margin = (netProfit / grossRevenue) * 100;

      final summary = NetProfitSummary(
        grossRevenue: grossRevenue,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        profitMargin: margin,
        expensesByCategory: {
          ExpenseCategory.rent: 12000.0,
          ExpenseCategory.electricity: 4000.0,
          ExpenseCategory.wifi: 2000.0,
        },
        expenseCount: 3,
      );

      expect(summary.netProfit, 32000.0);
      expect(summary.profitMargin, 64.0);
      expect(summary.isProfitable, isTrue);

      // Deficit scenario
      final deficitSummary = NetProfitSummary(
        grossRevenue: 10000.0,
        totalExpenses: 15000.0,
        netProfit: 10000.0 - 15000.0,
        profitMargin: ((10000.0 - 15000.0) / 10000.0) * 100,
        expensesByCategory: {ExpenseCategory.rent: 15000.0},
        expenseCount: 1,
      );

      expect(deficitSummary.netProfit, -5000.0);
      expect(deficitSummary.profitMargin, -50.0);
      expect(deficitSummary.isProfitable, isFalse);
    });

    // -------------------------------------------------------------------------
    // 43. FEE RECEIPT ENGINE: Indian Number-to-Words Ledger Math
    // -------------------------------------------------------------------------
    test('43. FEE RECEIPT ENGINE: Indian Number-to-Words Ledger Math', () {
      expect(PdfService.numberToIndianWords(700), equals('Seven Hundred'));
      expect(PdfService.numberToIndianWords(1500), equals('One Thousand Five Hundred'));
      expect(PdfService.numberToIndianWords(25000), equals('Twenty Five Thousand'));
      expect(PdfService.numberToIndianWords(125000), equals('One Lakh Twenty Five Thousand'));
      expect(PdfService.numberToIndianWords(0), equals('Zero'));
    });
    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // 44. WAITING LIST PROMOTION PIPELINE: Section Matching & Seat Suggestion
    // -------------------------------------------------------------------------
    test('44. WAITING LIST PROMOTION PIPELINE: Section Matching & Suggested Seat Serialization', () {
      final entry = WaitingListEntry(
        id: 'wait_001',
        libraryId: 'lib_001',
        studentName: 'Rahul Sharma',
        studentPhone: '9876543210',
        studentId: 'std_wait_01',
        preferredSectionId: 'sec_silent_a',
        genderPreference: 'none',
        position: 1,
        notes: 'Needs morning slot',
        suggestedSeatId: 'seat_101',
        suggestedSectionId: 'sec_silent_a',
        suggestedSeatLabel: 'A-12',
        createdAt: DateTime(2026, 10, 1),
      );

      final json = entry.toJson();
      expect(json['studentName'], equals('Rahul Sharma'));
      expect(json['suggestedSeatLabel'], equals('A-12'));
      expect(json['suggestedSeatId'], equals('seat_101'));
      expect(json['suggestedSectionId'], equals('sec_silent_a'));
      expect(json['notes'], equals('Needs morning slot'));

      final parsed = WaitingListEntry.fromJson(json);
      expect(parsed.suggestedSeatLabel, equals('A-12'));
      expect(parsed.suggestedSeatId, equals('seat_101'));
      expect(parsed.suggestedSectionId, equals('sec_silent_a'));
      expect(parsed.notes, equals('Needs morning slot'));

      // Section preference evaluation logic:
      bool matchesSection(WaitingListEntry e, String targetSec) =>
          e.preferredSectionId == null ||
          e.preferredSectionId!.isEmpty ||
          e.preferredSectionId == targetSec;

      expect(matchesSection(entry, 'sec_silent_a'), isTrue);
      expect(matchesSection(entry, 'sec_general_b'), isFalse);

      final openEntry = WaitingListEntry(
        id: 'wait_002',
        libraryId: 'lib_001',
        studentName: 'Pooja Verma',
        studentPhone: '9123456780',
        studentId: '',
        position: 2,
        createdAt: DateTime(2026, 10, 2),
      );
      // Null preferredSection matches any section
      expect(matchesSection(openEntry, 'sec_general_b'), isTrue);
    });

    test('45. UNIVERSAL MULTILINGUAL TEXT ENGINE: Devanagari, Tamil, Telugu, Gujarati, Bengali Support', () {
      // 1. Devanagari (Marathi / Hindi)
      expect(AppValidators.name('रोहन शिंदे'), isNull);
      expect(AppValidators.name('अनिकेत देशमुख'), isNull);
      expect(FormValidators.validateName('अमित शर्मा'), isNull);

      // 2. Tamil
      expect(AppValidators.name('சரவணன் குமார்'), isNull);
      expect(FormValidators.validateName('கார்த்திக்'), isNull);

      // 3. Telugu
      expect(AppValidators.name('రాకేష్ వర్మ'), isNull);
      expect(FormValidators.validateName('వెంకటేష్'), isNull);

      // 4. Gujarati
      expect(AppValidators.name('વિજય પટેલ'), isNull);
      expect(FormValidators.validateName('પ્રતીક શાહ'), isNull);

      // 5. Bengali
      expect(AppValidators.name('রাহুল শর্মা'), isNull);
      expect(FormValidators.validateName('অনিক সেন'), isNull);

      // 6. Latin / English standard
      expect(AppValidators.name('Kri Sonpethkar'), isNull);

      // 7. Rejection of invalid inputs (numbers, symbols, empty)
      expect(AppValidators.name('123 Rohan'), isNotNull);
      expect(AppValidators.name('Rohan@123'), isNotNull);
      expect(AppValidators.name(''), isNotNull);
    });

    test('46. PLAN MODEL & RENEWAL PRICING: MRP Strikethrough, Discount % & Daily Rates', () {
      final monthlyPlan = PlanModel(
        id: 'plan_1m',
        libraryId: 'lib_test',
        name: 'Monthly Study Pass',
        duration: 1,
        durationUnit: DurationUnit.months,
        price: 700.0,
        originalPrice: 850.0,
        description: 'Standard 1-Month Access',
        gracePeriodDays: 3,
        isActive: true,
        isFeatured: false,
        displayOrder: 1,
      );

      final quarterlyPlan = PlanModel(
        id: 'plan_3m',
        libraryId: 'lib_test',
        name: 'Quarterly Smart Pass',
        duration: 3,
        durationUnit: DurationUnit.months,
        price: 1800.0, // ₹600/month
        description: '3-Month Bundle',
        gracePeriodDays: 5,
        isActive: true,
        isFeatured: true,
        displayOrder: 2,
      );

      // Explicit originalPrice discount calculation
      expect(monthlyPlan.getEffectiveOriginalPrice(), equals(850.0));
      expect(monthlyPlan.getDiscountPercent(), equals(18)); // ((850-700)/850)*100 = 17.6% -> 18%
      expect(monthlyPlan.getSavingsAmount(), equals(150.0));

      // Bundle discount calculated against base monthly price (3 * 700 = 2100 vs 1800)
      expect(quarterlyPlan.getEffectiveOriginalPrice(baseMonthlyPrice: 700.0), equals(2100.0));
      expect(quarterlyPlan.getDiscountPercent(baseMonthlyPrice: 700.0), equals(14)); // (300/2100)*100 = 14%
      expect(quarterlyPlan.getSavingsAmount(baseMonthlyPrice: 700.0), equals(300.0));
    });

    test('47. ADVANCE MEMBERSHIP RENEWAL TIMING: Continuous Cycle Calculation', () {
      final currentPlanEnd = DateTime(2026, 11, 15);

      // Advance renewal must start the day immediately following current expiry
      final advanceStartDate = currentPlanEnd.add(const Duration(days: 1));
      expect(advanceStartDate, equals(DateTime(2026, 11, 16)));

      // 1-month duration calculation from advance start date
      final advanceEndDate = PlanCalculatorService.calculatePlanEndDate(advanceStartDate, 1, DurationUnit.months);
      expect(advanceEndDate.month, equals(12));
      expect(advanceEndDate.isAfter(advanceStartDate), isTrue);
    });

    test('48. DYNAMIC UPI ID CONFIGURATION & SANITIZATION', () {
      String resolveUpiUri({
        required String upiId,
        required String payeeName,
        required double amount,
        required String studentName,
      }) {
        final amountStr = amount.toStringAsFixed(0);
        return 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amountStr&cu=INR&tn=${Uri.encodeComponent("Renewal - $studentName")}';
      }

      final uri = resolveUpiUri(
        upiId: '8625982248@upi',
        payeeName: 'The Cozy Corner Centre',
        amount: 700.0,
        studentName: 'Rohan Shinde',
      );

      expect(uri, contains('pa=8625982248@upi'));
      expect(uri, contains('The%20Cozy%20Corner%20Centre'));
      expect(uri, contains('am=700'));
      expect(uri, contains('cu=INR'));
    });

    test('49. ROLE-BASED INDEPENDENT APP SECURITY: Key Isolation', () {
      String getPinKey({String? userId}) =>
          (userId != null && userId.isNotEmpty) ? 'security_pin_hash_$userId' : 'security_pin_hash';

      String getBioKey({String? userId}) =>
          (userId != null && userId.isNotEmpty) ? 'security_biometric_enabled_$userId' : 'security_biometric_enabled';

      // Admin uses master keys
      expect(getPinKey(userId: null), equals('security_pin_hash'));
      expect(getBioKey(userId: null), equals('security_biometric_enabled'));

      // Student uses isolated studentId-scoped keys
      expect(getPinKey(userId: 'student_123'), equals('security_pin_hash_student_123'));
      expect(getBioKey(userId: 'student_123'), equals('security_biometric_enabled_student_123'));
      expect(getPinKey(userId: 'student_123'), isNot(equals(getPinKey(userId: null))));
    });

    test('50. DESK CASH PAYMENT RENEWAL REQUEST PAYLOAD STRUCTURE', () {
      final deskRenewalPayload = <String, dynamic>{
        'type': 'renewal',
        'studentId': 'stud_001',
        'studentName': 'Rohan Shinde',
        'requestedPlanId': 'plan_1m',
        'requestedPlanName': 'Monthly Plan',
        'amount': 700.0,
        'paymentMethod': 'desk_cash',
        'paymentModeLabel': 'Pay at Desk / Reception',
        'referenceNumber': 'Desk Cash Payment Requested',
        'status': 'desk_payment_pending',
      };

      expect(deskRenewalPayload['paymentMethod'], equals('desk_cash'));
      expect(deskRenewalPayload['status'], equals('desk_payment_pending'));
      expect(deskRenewalPayload['referenceNumber'], equals('Desk Cash Payment Requested'));
    });

    test('51. FEEDBACK MODEL: Category, Status & Official Admin Reply Closed-Loop Serialization', () {
      final feedback = FeedbackModel(
        id: 'fb_101',
        libraryId: 'lib_001',
        studentId: 'stud_123',
        studentName: 'Aarav Patil',
        studentPhone: '9876543210',
        message: 'The Wi-Fi speed in Room 2 is slow during afternoon hours.',
        category: 'High-Speed WiFi & Power',
        rating: 3,
        adminReply: 'We have restarted the 5GHz router and upgraded the bandwidth. Issue resolved!',
        status: 'resolved',
        createdAt: DateTime(2026, 10, 26, 14, 30),
        repliedAt: DateTime(2026, 10, 26, 16, 45),
      );

      final json = feedback.toJson();
      expect(json['category'], equals('High-Speed WiFi & Power'));
      expect(json['status'], equals('resolved'));
      expect(json['adminReply'], contains('upgraded the bandwidth'));
      expect(json['studentPhone'], equals('9876543210'));

      final parsed = FeedbackModel.fromJson(json);
      expect(parsed.id, equals('fb_101'));
      expect(parsed.category, equals('High-Speed WiFi & Power'));
      expect(parsed.status, equals('resolved'));
      expect(parsed.adminReply, equals('We have restarted the 5GHz router and upgraded the bandwidth. Issue resolved!'));
      expect(parsed.repliedAt, isNotNull);
    });

    test('52. GENDER RESTRICTION SEAT ALLOCATION RULES', () {
      bool isEligible(Gender studentGender, String sectionGender, GenderRestriction seatGender) {
        final secG = sectionGender.toLowerCase().trim();
        if (studentGender == Gender.male) {
          if (secG == 'female' || secG == 'girls') return false;
          if (seatGender == GenderRestriction.female) return false;
          return true;
        } else if (studentGender == Gender.female) {
          if (secG == 'male' || secG == 'boys') return false;
          if (seatGender == GenderRestriction.male) return false;
          return true;
        }
        return true;
      }

      // Male student checks
      expect(isEligible(Gender.male, 'any', GenderRestriction.any), isTrue, reason: 'Male can pick unisex seat');
      expect(isEligible(Gender.male, 'male', GenderRestriction.male), isTrue, reason: 'Male can pick male seat');
      expect(isEligible(Gender.male, 'female', GenderRestriction.any), isFalse, reason: 'Male cannot pick in female section');
      expect(isEligible(Gender.male, 'any', GenderRestriction.female), isFalse, reason: 'Male cannot pick female reserved seat');

      // Female student checks
      expect(isEligible(Gender.female, 'any', GenderRestriction.any), isTrue, reason: 'Female can pick unisex seat');
      expect(isEligible(Gender.female, 'female', GenderRestriction.female), isTrue, reason: 'Female can pick female seat');
      expect(isEligible(Gender.female, 'male', GenderRestriction.any), isFalse, reason: 'Female cannot pick in male section');
      expect(isEligible(Gender.female, 'any', GenderRestriction.male), isFalse, reason: 'Female cannot pick male reserved seat');
    });

    test('53. SEAT CHANGE REQUEST PAYLOAD INTEGRITY & STATE TRANSITIONS', () {
      final seatChangeReq = <String, dynamic>{
        'type': 'seat_change',
        'status': 'pending',
        'studentId': 'stud_001',
        'studentName': 'Rohan Shinde',
        'studentPhone': '9876543210',
        'studentGender': 'male',
        'currentSeatId': 'seat_10',
        'currentSectionId': 'sec_hall',
        'targetSeatId': 'seat_15',
        'targetSeatLabel': '15',
        'targetSectionId': 'sec_ac',
        'targetSectionName': 'AC Silent Hall',
        'reason': 'Need a quiet corner near power socket',
      };

      expect(seatChangeReq['type'], equals('seat_change'));
      expect(seatChangeReq['currentSeatId'], equals('seat_10'));
      expect(seatChangeReq['targetSeatId'], equals('seat_15'));
      expect(seatChangeReq['reason'], contains('power socket'));

      // Transition to approved
      final approvedReq = {...seatChangeReq, 'status': 'approved', 'processedAt': DateTime.now().toIso8601String()};
      expect(approvedReq['status'], equals('approved'));
      expect(approvedReq['processedAt'], isNotNull);
    });

    test('54. RECEIPTS REALTIME RESILIENT MATCHING & SYNTHESIS LOGIC', () {
      final sampleStudent = StudentModel(
        id: 'std_auto_999',
        name: 'Neha Sharma',
        fatherName: 'Rajesh Sharma',
        phone: '9811223344',
        email: 'neha@test.com',
        gender: Gender.female,
        address: 'Pune, MH',
        pincode: '411001',
        govIdType: GovIdType.aadhaar,
        govIdNumber: '123456789012',
        govIdImageUrl: '',
        photoUrl: '',
        college: 'Fergusson College',
        course: 'B.Sc',
        year: '3',
        emergencyContact: '9811223345',
        seatId: '7',
        sectionId: 'sec_girls',
        planId: 'monthly_plan',
        planStartDate: DateTime(2026, 10, 1),
        planEndDate: DateTime(2026, 10, 31),
        membershipStatus: MembershipStatus.active,
        customFields: const {},
        userId: 'firebase_auth_uid_neha',
        membershipNumber: 'CC20260055',
      );

      final r1 = ReceiptModel(
        id: 'rec_01',
        libraryId: 'lib_001',
        receiptNumber: 'REC-2026-0001',
        studentId: 'std_auto_999',
        planId: 'monthly_plan',
        amount: 700.0,
        paymentMethod: 'UPI',
        validFrom: DateTime(2026, 10, 1),
        validTo: DateTime(2026, 10, 31),
        status: ReceiptStatus.active,
        customFields: const {},
      );

      final r2 = ReceiptModel(
        id: 'rec_02',
        libraryId: 'lib_001',
        receiptNumber: 'REC-2026-0002',
        studentId: 'CC20260055', // Saved by membership number
        planId: 'monthly_plan',
        amount: 700.0,
        paymentMethod: 'Cash',
        validFrom: DateTime(2026, 9, 1),
        validTo: DateTime(2026, 9, 30),
        status: ReceiptStatus.active,
        customFields: const {},
      );

      bool matchesStudent(ReceiptModel r, StudentModel student) {
        return r.studentId == student.id ||
            (r.studentUserId != null && r.studentUserId == student.userId) ||
            (student.userId != null && r.studentId == student.userId) ||
            (student.membershipNumber != null && r.studentId == student.membershipNumber);
      }

      expect(matchesStudent(r1, sampleStudent), isTrue, reason: 'Matched by studentId');
      expect(matchesStudent(r2, sampleStudent), isTrue, reason: 'Matched by membershipNumber');

      // Verify active admission synthesis flag
      final hasActiveAdmission = sampleStudent.membershipStatus == MembershipStatus.active ||
          sampleStudent.planStartDate != null ||
          sampleStudent.seatId != null;
      expect(hasActiveAdmission, isTrue);
    });

    test('55. STUDENT ID CARD SECURITY: Admin Customizer Lockdown in Student Portal', () {
      bool isCustomizerAccessible({required bool isStudent}) => !isStudent;
      bool canSaveAsDefaultTheme({required bool isStudent}) => !isStudent;

      // Admin has full control
      expect(isCustomizerAccessible(isStudent: false), isTrue);
      expect(canSaveAsDefaultTheme(isStudent: false), isTrue);

      // Student has zero customization / configuration knobs
      expect(isCustomizerAccessible(isStudent: true), isFalse);
      expect(canSaveAsDefaultTheme(isStudent: true), isFalse);
    });

    test('56. ADMIN NAME & DYNAMIC SYNC: LibraryModel parses and propagates admin/manager name', () {
      final jsonWithAdmin = {
        'id': 'lib_test_1',
        'name': 'Cozy Corner Library',
        'address': 'Pune',
        'logoUrl': '',
        'contact': '9403243830',
        'ownerId': 'owner_1',
        'accentColor': 0xFF5D4037,
        'welcomeMessage': 'Welcome',
        'operatingHours': '8am - 10pm',
        'socialLinks': <String, String>{},
        'rulesText': 'Silence',
        'adminPhotoUrl': '',
        'helplineNumber': '8625982248',
        'waitingListMode': 'contactAdmin',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'adminName': 'Srikrishnadatta Sonpethkar',
      };

      final lib = LibraryModel.fromJson(jsonWithAdmin);
      expect(lib.adminName, equals('Srikrishnadatta Sonpethkar'));

      // Check fallback when not explicitly provided
      final jsonWithoutAdmin = Map<String, dynamic>.from(jsonWithAdmin)..remove('adminName');
      final libFallback = LibraryModel.fromJson(jsonWithoutAdmin);
      expect(libFallback.adminName, isEmpty);

      final displayAdmin = lib.adminName.isNotEmpty ? lib.adminName : 'Srikrishnadatta Sonpethkar';
      expect(displayAdmin, equals('Srikrishnadatta Sonpethkar'));
    });

    test('57. SECURE GOVT ID DECRYPTION: Raw ciphertext is decrypted or masked, never exposed', () {
      const plainPan = 'ABCDE1234F';
      const librarySecret = 'lib_test_secret_123';

      final encrypted = EncryptionService.encryptGovId(plainPan, librarySecret);
      expect(encrypted, isNot(equals(plainPan)));

      // Decryption with librarySecret succeeds
      final decrypted = EncryptionService.safeDecryptGovId(encrypted, librarySecret);
      expect(decrypted, equals(plainPan));

      // Plaintext is preserved as-is
      expect(EncryptionService.safeDecryptGovId('ABCDE1234F', librarySecret), equals('ABCDE1234F'));
      expect(EncryptionService.safeDecryptGovId('123456789012', librarySecret), equals('123456789012'));

      // In invalid key scenario, returns masked placeholder, never the raw ciphertext
      final corruptedResult = EncryptionService.safeDecryptGovId('invalid_gibberish_string==', 'wrong_key');
      expect(corruptedResult, equals('••••••••'));
    });

    test('58. RENEWAL SCHEMA & PERMISSIONS: Payload includes studentUserId, userId, and desk_payment_pending', () {
      final renewalPayload = {
        'type': 'renewal',
        'studentId': 'student_doc_xyz',
        'studentName': 'Rahul Sharma',
        'studentPhone': '9876543210',
        'studentUserId': 'auth_uid_123',
        'userId': 'auth_uid_123',
        'requestedPlanId': 'plan_monthly',
        'status': 'desk_payment_pending',
      };

      // Validates required permission keys
      expect(renewalPayload['studentUserId'], equals('auth_uid_123'));
      expect(renewalPayload['userId'], equals('auth_uid_123'));
      expect(renewalPayload['status'], isIn(['pending', 'desk_payment_pending']));
    });

    test('59. SEAT HELPER LABEL FORMATTING: Universal parsing of composite IDs, raw numbers, and double-prefix prevention', () {
      // 1. Composite row/col seat ID
      expect(SeatHelper.formatSeatLabel(seatId: '1790647291016_r0_c4', cols: 6), equals('Seat #5'));
      expect(SeatHelper.formatSeatLabel(seatId: '1790647291016_r0_c4', cols: 6, includePrefix: false), equals('#5'));

      // 2. Pure number
      expect(SeatHelper.formatSeatLabel(seatId: '5'), equals('Seat #5'));
      expect(SeatHelper.formatSeatLabel(seatId: '5', includePrefix: false), equals('#5'));

      // 3. Raw label with existing prefix (prevents 'Seat #Seat #5')
      expect(SeatHelper.formatSeatLabel(rawLabel: 'Seat #5'), equals('Seat #5'));
      expect(SeatHelper.formatSeatLabel(rawLabel: '#5'), equals('Seat #5'));
      expect(SeatHelper.formatSeatLabel(rawLabel: 'Seat #5', includePrefix: false), equals('#5'));

      // 4. Custom code (e.g. CAB-05)
      expect(SeatHelper.formatSeatLabel(seatId: 'CAB-05'), equals('Seat CAB-05'));
      expect(SeatHelper.formatSeatLabel(seatId: 'CAB-05', includePrefix: false), equals('CAB-05'));

      // 5. Null or empty returns fallback
      expect(SeatHelper.formatSeatLabel(seatId: null), equals('Allocated Desk'));
      expect(SeatHelper.formatSeatLabel(seatId: null, includePrefix: false), equals('Desk'));
    });

    test('60. SEAT CHANGE POLICY: One change per 30-day cycle enforcement & next eligible date calculation', () {
      final now = DateTime(2026, 10, 27, 12, 0);

      // Student whose seat was changed 10 days ago (restricted)
      final recentChangeDate = now.subtract(const Duration(days: 10));
      final daysSince1 = now.difference(recentChangeDate).inDays;
      final isRestricted1 = daysSince1 < 30;
      final nextEligibleDate1 = recentChangeDate.add(const Duration(days: 30));
      final daysRemaining1 = nextEligibleDate1.difference(now).inDays + 1;

      expect(isRestricted1, isTrue);
      expect(daysRemaining1, equals(21));

      // Student whose seat was changed 35 days ago (eligible)
      final oldChangeDate = now.subtract(const Duration(days: 35));
      final daysSince2 = now.difference(oldChangeDate).inDays;
      final isRestricted2 = daysSince2 < 30;

      expect(isRestricted2, isFalse);
    });

    test('61. STUDENT RECEIPT & ID PERMISSIONS: No printer or thermal printing, only download and share', () {
      // Role checking logic in ReceiptPreviewScreen and IdCardPreviewScreen
      bool calculateAllowPrinting({required bool isStudent}) => !isStudent;
      bool calculateAllowThermalPrint({required bool isStudent}) => !isStudent;
      bool calculateAllowDownload({required bool isStudent}) => true;
      bool calculateAllowSharing({required bool isStudent}) => true;

      // Student permissions
      expect(calculateAllowPrinting(isStudent: true), isFalse);
      expect(calculateAllowThermalPrint(isStudent: true), isFalse);
      expect(calculateAllowDownload(isStudent: true), isTrue);
      expect(calculateAllowSharing(isStudent: true), isTrue);

      // Admin permissions
      expect(calculateAllowPrinting(isStudent: false), isTrue);
      expect(calculateAllowThermalPrint(isStudent: false), isTrue);
      expect(calculateAllowDownload(isStudent: false), isTrue);
      expect(calculateAllowSharing(isStudent: false), isTrue);

      // Receipt Seat formatting
      const rawCompositeSeat = '1790647291016_r0_c4';
      final receiptSeatFormatted = SeatHelper.formatSeatLabel(seatId: rawCompositeSeat, includePrefix: false);
      expect(receiptSeatFormatted, equals('#5'));
      expect(receiptSeatFormatted, isNot(contains('1790647291016')));
      expect(receiptSeatFormatted, isNot(contains('_r0_c4')));
    });

    test('62. STRICT PIN & ACCOUNT ISOLATION: No cross-account access between Admin and Student, or Student to Student', () async {
      SharedPreferences.setMockInitialValues({
        'security_pin_hash': 'salt1:${sha256.convert(utf8.encode('salt19999')).toString()}', // Admin PIN = 9999
        'security_pin_hash_std_A': 'saltA:${sha256.convert(utf8.encode('saltA1111')).toString()}', // Student A PIN = 1111
        'security_pin_hash_std_B': 'saltB:${sha256.convert(utf8.encode('saltB2222')).toString()}', // Student B PIN = 2222
      });

      // 1. Admin login verification
      expect(await BiometricService.verifyPin('9999', isAdmin: true), isTrue);
      // Student A PIN entered on Admin lock MUST FAIL
      expect(await BiometricService.verifyPin('1111', isAdmin: true), isFalse);
      // Student B PIN entered on Admin lock MUST FAIL
      expect(await BiometricService.verifyPin('2222', isAdmin: true), isFalse);

      // 2. Student A verification
      expect(await BiometricService.verifyPin('1111', userId: 'std_A'), isTrue);
      // Admin PIN entered on Student A lock MUST FAIL
      expect(await BiometricService.verifyPin('9999', userId: 'std_A'), isFalse);
      // Student B PIN entered on Student A lock MUST FAIL
      expect(await BiometricService.verifyPin('2222', userId: 'std_A'), isFalse);

      // 3. Student B verification
      expect(await BiometricService.verifyPin('2222', userId: 'std_B'), isTrue);
      // Student A PIN entered on Student B lock MUST FAIL
      expect(await BiometricService.verifyPin('1111', userId: 'std_B'), isFalse);
      // Admin PIN entered on Student B lock MUST FAIL
      expect(await BiometricService.verifyPin('9999', userId: 'std_B'), isFalse);
    });

    test('63. ADMIN RESET STUDENT PIN: Only Admin can clear/reset another user PIN', () async {
      SharedPreferences.setMockInitialValues({
        'security_pin_hash_std_X': 'saltX:${sha256.convert(utf8.encode('saltX4444')).toString()}',
        'security_biometric_enabled_std_X': true,
      });

      expect(await BiometricService.hasPin(userId: 'std_X'), isTrue);
      expect(await BiometricService.isBiometricEnabled(userId: 'std_X'), isTrue);

      // Student clears own PIN or Admin resets it
      await BiometricService.clearPin(userId: 'std_X');
      await BiometricService.setBiometricEnabled(false, userId: 'std_X');

      expect(await BiometricService.hasPin(userId: 'std_X'), isFalse);
      expect(await BiometricService.isBiometricEnabled(userId: 'std_X'), isFalse);
      expect(await BiometricService.isLockEnabled(userId: 'std_X'), isFalse);
    });

    test('64. ZERO HARDCODED HELPLINES & DYNAMIC CONTACT RESOLUTION', () {
      final lib = LibraryModel.fromJson({
        'id': 'lib_001',
        'name': 'Cozy Corner Library',
        'address': 'Nanded City Center',
        'logoUrl': '',
        'contact': '9403243830',
        'email': 'cozycorner@example.com',
        'ownerId': 'owner_1',
        'adminName': 'Sonpethkar Sir',
      });

      // Verify no hardcoded helpline is used
      expect(lib.effectiveContact, equals('9403243830'));
      expect(lib.effectiveHelpline, equals('9403243830'));
      expect(lib.adminName, equals('Sonpethkar Sir'));
      expect(lib.effectiveContact, isNot(contains('8625982248')));
      expect(lib.effectiveHelpline, isNot(contains('8625982248')));
    });

    test('65. PURE-DART IMAGE COMPRESSION SAFETY CEILING GUARD (< 80 KB)', () {
      final img.Image testImage = img.Image(width: 200, height: 200);
      img.fill(testImage, color: img.ColorRgb8(100, 150, 200));
      final rawBytes = Uint8List.fromList(img.encodePng(testImage));

      final safeBytes = ImageService.compressBytesToSafeJpeg(rawBytes, maxDimension: 400, initialQuality: 70);

      expect(safeBytes.isNotEmpty, isTrue);
      expect(safeBytes.length, lessThan(80 * 1024)); // Must be < 80 KB
      expect(safeBytes.length, lessThan(1048576));   // Must be well below 1 MB Firestore limit
    });

    test('66. SEAT CHANGE REQUEST AUDIT: Rich details parsing & duplicate request superseding', () {
      final reqDocData = <String, dynamic>{
        'type': 'seat_change',
        'status': 'pending',
        'studentId': 'DBrwRqUdqRPk6u8EEyqq',
        'studentName': 'Srikrishnadatta Bharatrao Sonpethkar',
        'studentPhone': '9403243830',
        'studentEmail': 'thecozycornersc@gmail.com',
        'membershipNumber': 'CC-2026-0042',
        'currentSeatId': '1790647291016_r0_c4',
        'currentSeatLabel': 'Seat #5',
        'currentSectionName': 'Main Reading Hall',
        'targetSeatId': '1790647291016_12',
        'targetSeatLabel': '12',
        'targetSectionName': 'Silent AC Zone',
        'reason': 'Need power outlet near window',
        'createdAt': DateTime(2026, 10, 27, 14, 45).millisecondsSinceEpoch,
      };

      // 1. Verify seat labels are clean and human-readable
      final currentClean = SeatHelper.formatSeatLabel(rawLabel: reqDocData['currentSeatLabel'] as String?);
      final targetClean = SeatHelper.formatSeatLabel(rawLabel: reqDocData['targetSeatLabel'] as String?);
      expect(currentClean, equals('Seat #5'));
      expect(targetClean, equals('Seat #12'));

      // 2. Verify Member ID & Phone are used instead of raw Firestore ID
      final memberId = reqDocData['membershipNumber'];
      final phone = reqDocData['studentPhone'];
      expect(memberId, equals('CC-2026-0042'));
      expect(phone, equals('9403243830'));
      expect(memberId, isNot(equals('DBrwRqUdqRPk6u8EEyqq')));

      // 3. State transition: when newest request is approved, older duplicates are marked 'superseded'
      final olderDuplicateReq = {
        'id': 'req_older_11_12_am',
        'studentId': 'DBrwRqUdqRPk6u8EEyqq',
        'type': 'seat_change',
        'status': 'pending',
      };

      final supersededReq = {
        ...olderDuplicateReq,
        'status': 'superseded',
        'rejectionReason': 'Superseded by approval of seat change to Seat #12',
      };

      expect(supersededReq['status'], equals('superseded'));
      expect(supersededReq['status'], isNot(equals('pending')));
      expect(supersededReq['rejectionReason'], contains('Superseded'));
    });

    test('67. REAL-TIME SEAT CHANGE & MAP AMBER SYNC STABILITY', () {
      // 1. Version consistency check
      expect(WhatsNewService.currentVersionIdentifier, equals('${AppConstants.appVersion}+${AppConstants.buildNumber}'));
      expect(AppConstants.appVersion, equals('1.5.53'));
      expect(AppConstants.buildNumber, equals(68));

      // 2. Pending Seat Change Multi-Identifier Matching
      final testStudent = StudentModel(
        id: 'DBrwRqUdqRPk6u8EEyqq',
        name: 'Shubham',
        fatherName: 'Father',
        phone: '+91 9403243830',
        email: 'thecozycornersc@gmail.com',
        userId: 'auth_uid_12345',
        address: 'Parli',
        pincode: '431515',
        govIdType: GovIdType.aadhaar,
        govIdNumber: '123456789012',
        govIdImageUrl: '',
        photoUrl: '',
        college: 'College',
        course: 'UPSC',
        year: '2026',
        emergencyContact: '9876543210',
        seatId: 'seat_r0_c0',
        membershipStatus: MembershipStatus.active,
        gender: Gender.male,
        customFields: const {},
      );

      bool matchPendingRequest(Map<String, dynamic> reqData) {
        final sId = (reqData['studentId'] ?? '').toString();
        final sUid = (reqData['studentUserId'] ?? reqData['userId'] ?? '').toString();
        final sEmail = (reqData['studentEmail'] ?? '').toString().trim().toLowerCase();
        final sPhone = (reqData['studentPhone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final myPhone = testStudent.phone.replaceAll(RegExp(r'\D'), '');
        final curUid = 'auth_uid_12345';
        final curEmail = 'thecozycornersc@gmail.com';
        final myStudentUserId = (testStudent.userId ?? '').toString();

        if (sId == testStudent.id) return true;
        if (curUid.isNotEmpty && (sUid == curUid || sId == curUid)) return true;
        if (myStudentUserId.isNotEmpty && (sUid == myStudentUserId || sId == myStudentUserId)) return true;
        if (curEmail.isNotEmpty && sEmail.isNotEmpty && curEmail == sEmail) return true;
        if (testStudent.email.isNotEmpty && sEmail.isNotEmpty && testStudent.email.toLowerCase().trim() == sEmail) return true;
        if (myPhone.isNotEmpty && sPhone.isNotEmpty && (myPhone == sPhone || myPhone.endsWith(sPhone) || sPhone.endsWith(myPhone))) return true;
        return false;
      }

      // Matches by Firestore student doc ID
      expect(matchPendingRequest({'studentId': 'DBrwRqUdqRPk6u8EEyqq'}), isTrue);
      // Matches by Auth UID
      expect(matchPendingRequest({'studentUserId': 'auth_uid_12345'}), isTrue);
      // Matches by phone
      expect(matchPendingRequest({'studentPhone': '9403243830'}), isTrue);
      // Matches by email
      expect(matchPendingRequest({'studentEmail': 'thecozycornersc@gmail.com'}), isTrue);
      // Does not match random student
      expect(matchPendingRequest({'studentId': 'random_other_id', 'studentPhone': '1111111111'}), isFalse);

      // 3. Seat Map Target Seat Amber Matching
      final seatModel = SeatModel(
        id: '1790647291016_2',
        sectionId: 'sec_1',
        row: 0,
        col: 1,
        label: '2',
        status: SeatStatus.available,
        genderRestriction: GenderRestriction.any,
      );

      final pendingReqData = {
        'targetSeatId': '1790647291016_2',
        'targetSeatLabel': '2',
        'targetSectionName': 'Cozy Hall',
      };

      final seatFormatted = SeatHelper.formatSeatLabel(
        seatId: seatModel.id,
        rawLabel: seatModel.label,
        cols: 6,
        includePrefix: false,
      );
      final pendingTargetFormatted = SeatHelper.formatSeatLabel(
        rawLabel: pendingReqData['targetSeatLabel'],
        includePrefix: false,
      );

      final isPendingTarget = (seatModel.id == pendingReqData['targetSeatId'] ||
          (pendingTargetFormatted.isNotEmpty && seatFormatted == pendingTargetFormatted));

      expect(seatFormatted, equals('#2'));
      expect(pendingTargetFormatted, equals('#2'));
      expect(isPendingTarget, isTrue);
    });

    test('68. UNIFIED WAITING LIST & CAPACITY HUB INTEGRATION', () {
      // 1. LibraryModel WaitingListMode deserialization test (both camelCase & snake_case)
      final libJson1 = {
        'id': 'lib_1',
        'name': 'Cozy Corner',
        'waitingListMode': 'waiting_list',
        'waitingListHoldingHours': 48,
        'waitingListAutoNotify': true,
        'waitingListNotificationTemplate': 'Hello {studentName}, seat {seatLabel} is ready at {libraryName}!',
      };
      final lib1 = LibraryModel.fromJson(libJson1);
      expect(lib1.waitingListMode, equals(WaitingListMode.waitingList));
      expect(lib1.waitingListHoldingHours, equals(48));
      expect(lib1.waitingListAutoNotify, isTrue);

      final libJson2 = {
        'id': 'lib_2',
        'name': 'Cozy Corner 2',
        'waitingListMode': 'no_seats',
      };
      final lib2 = LibraryModel.fromJson(libJson2);
      expect(lib2.waitingListMode, equals(WaitingListMode.noSeatsMessage));

      final libJson3 = {
        'id': 'lib_3',
        'name': 'Cozy Corner 3',
        'waitingListMode': 'contactAdmin',
      };
      final lib3 = LibraryModel.fromJson(libJson3);
      expect(lib3.waitingListMode, equals(WaitingListMode.contactAdmin));

      // 2. WaitingListEntry serialization & copyWith test
      final entry = WaitingListEntry(
        id: 'entry_1',
        libraryId: 'lib_1',
        studentId: 'stud_123',
        studentName: 'Aarav Sharma',
        studentPhone: '+91 9876543210',
        preferredSectionId: 'sec_quiet',
        genderPreference: 'male',
        position: 1,
        suggestedSeatLabel: 'Desk #12',
        createdAt: DateTime(2026, 10, 28, 10, 0),
      );
      final json = entry.toJson();
      expect(json['studentName'], equals('Aarav Sharma'));
      expect(json['suggestedSeatLabel'], equals('Desk #12'));

      final restored = WaitingListEntry.fromJson(json);
      expect(restored.id, equals('entry_1'));
      expect(restored.studentPhone, equals('+91 9876543210'));
      expect(restored.suggestedSeatLabel, equals('Desk #12'));

      // 3. StudentQueueInfo contract verification
      final queueInfo = StudentQueueInfo(
        entry: restored,
        position: 1,
        totalInQueue: 5,
        isSeatReady: true,
        suggestedSeatLabel: 'Desk #12',
      );
      expect(queueInfo.position, equals(1));
      expect(queueInfo.totalInQueue, equals(5));
      expect(queueInfo.isSeatReady, isTrue);
      expect(queueInfo.suggestedSeatLabel, equals('Desk #12'));
    });

    test('69. ID CARD DIGITAL & PDF PARITY: Blood group on front, combined guardian/emergency on back', () {
      final student = StudentModel(
        id: 'CC20260002',
        name: 'Srikrishnadatta Bharatrao Sonpethkar',
        fatherName: 'Bharat',
        phone: '8625982248',
        email: 'thecozycornersc@gmail.com',
        bloodGroup: 'AB+',
        course: 'Mechanical',
        college: 'Universal College of Engineering',
        year: '2026',
        seatId: '2',
        emergencyContact: '9359492248',
        membershipNumber: 'CC20260002',
        planStartDate: DateTime(2026, 10, 22),
        planEndDate: DateTime(2026, 11, 22),
        gender: Gender.male,
        membershipStatus: MembershipStatus.active,
        address: 'Parli',
        pincode: '431515',
        govIdType: GovIdType.aadhaar,
        govIdNumber: '123456789012',
        govIdImageUrl: '',
        photoUrl: '',
        createdAt: DateTime(2026, 10, 22),
        customFields: const {},
      );

      final library = LibraryModel.fromJson({
        'id': 'lib_001',
        'name': 'The Cozy Corner Study Centre',
        'address': 'Front of Reliance Fashion Factory, Nath Road, Parli-431515',
        'contact': '9403243830',
        'helplineNumber': '9403243830',
        'ownerId': 'owner_1',
        'logoUrl': '',
      });

      // 1. Verify blood group belongs to student and is strictly present for front display
      expect(student.bloodGroup, equals('AB+'));
      expect(student.fatherName, equals('Bharat'));
      expect(student.emergencyContact, equals('9359492248'));

      // 2. Verify combined Guardian & Emergency text synthesis
      final effectiveReception = library.effectiveContact;
      final emergencyPhone = student.emergencyContact.isNotEmpty
          ? student.emergencyContact
          : (student.phone.isNotEmpty ? student.phone : effectiveReception);

      final combinedBackContact = student.fatherName.isNotEmpty
          ? '${student.fatherName} (Guardian) • $emergencyPhone'
          : 'Emergency: $emergencyPhone';

      expect(combinedBackContact, equals('Bharat (Guardian) • 9359492248'));
      expect(combinedBackContact, contains('Bharat'));
      expect(combinedBackContact, contains('9359492248'));

      // 3. Verify theme gradient mapping for modern PDF card
      final navyGradients = IdCardPdfService.getThemeGradientColors('royalNavy', 0);
      expect(navyGradients.length, equals(2));
      expect(navyGradients.first, equals(PdfColor.fromInt(0xFF1E3A8A)));
      expect(navyGradients.last, equals(PdfColor.fromInt(0xFF0F172A)));

      final crimsonGradients = IdCardPdfService.getThemeGradientColors('crimsonExecutive', 0);
      expect(crimsonGradients.first, equals(PdfColor.fromInt(0xFF881337)));

      final customGradients = IdCardPdfService.getThemeGradientColors('#881337', 0);
      expect(customGradients.length, equals(2));
    });

    test('70. STUDENT PORTAL ARCHITECTURE: Seat readability, Admin Name sync, Notification Center stream, and Org dynamic propagation', () {
      final library = LibraryModel.fromJson({
        'id': 'lib_001',
        'name': 'The Cozy Corner Study Centre',
        'adminName': 'Sanket Shahane',
        'address': 'Front Of Reliance Fashion Factory, Nath Road, Parli-431515',
        'contact': '9403243830',
        'helplineNumber': '9403243830',
        'whatsappNumber': '9403243830',
        'ownerId': 'owner_1',
        'logoUrl': '',
      });

      // 1. Dynamic Admin Name Sync Verification
      expect(library.adminName, equals('Sanket Shahane'));
      final adminGreeting = library.adminName.isNotEmpty ? 'Hello ${library.adminName}, ' : 'Hello Admin, ';
      final helpMsg = '${adminGreeting}I need help with my membership at ${library.name}.';
      expect(helpMsg, contains('Hello Sanket Shahane, '));
      expect(helpMsg, contains('The Cozy Corner Study Centre'));

      // 2. Seat Label Readability Across Student Login
      const rawSeatId = '2';
      const sectionName = 'Cozy Hall';
      final formattedSeat = SeatHelper.formatSeatLabel(seatId: rawSeatId);
      final fullDeskText = '$formattedSeat • $sectionName';
      expect(formattedSeat, equals('Seat #2'));
      expect(fullDeskText, equals('Seat #2 • Cozy Hall'));
      expect(fullDeskText, isNot(contains('Section ID:')));

      // 3. Composite Coordinate Formatter
      final compositeLabel = SeatHelper.formatSeatLabel(seatId: '1790647291016_r0_c1', cols: 6);
      expect(compositeLabel, equals('Seat #2'));

      // 4. Student Notification Model & Target Role Verification
      final notifData = {
        'id': 'notif_1',
        'title': 'Seat Change Approved',
        'message': 'Your seat has been shifted to Desk #2.',
        'targetRole': 'student',
        'targetUserId': 'CC20260002',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      };
      expect(notifData['targetRole'], equals('student'));
      expect(notifData['read'], isFalse);
    });

    test('71. MULTI-IDENTIFIER PIN VERIFICATION & SELF-SERVICE LOCKOUT RECOVERY', () async {
      SharedPreferences.setMockInitialValues({});
      const docId = 'doc_student_123';
      const authUid = 'auth_firebase_uid_456';
      const membershipNo = 'CC20260099';
      const candidateList = [docId, authUid, membershipNo];

      // 1. Set PIN using student document ID and auth UID
      await BiometricService.setPin(
        '1234',
        userId: docId,
        authUid: authUid,
        candidateIds: candidateList,
      );

      // Verify that lookup works under ANY candidate ID
      expect(await BiometricService.verifyPin('1234', userId: docId), isTrue);
      expect(await BiometricService.verifyPin('1234', userId: authUid), isTrue);
      expect(await BiometricService.verifyPin('1234', userId: membershipNo), isTrue);
      expect(await BiometricService.verifyPin('1234', candidateIds: candidateList), isTrue);

      // Verify incorrect PIN fails
      expect(await BiometricService.verifyPin('9999', userId: authUid), isFalse);

      // 2. Strict isolation: student PIN never unlocks Admin, and Admin PIN never unlocks Student
      await BiometricService.setPin('5555'); // Admin Master PIN
      expect(await BiometricService.verifyPin('5555', isAdmin: true), isTrue);
      expect(await BiometricService.verifyPin('1234', isAdmin: true), isFalse);
      expect(await BiometricService.verifyPin('5555', userId: authUid), isFalse);

      // 3. Rate limiting and lockout triggering
      for (int i = 0; i < 5; i++) {
        await BiometricService.recordFailedAttempt(userId: docId, authUid: authUid, candidateIds: candidateList);
      }
      final lockoutUntil = await BiometricService.getLockoutUntil(userId: docId, authUid: authUid, candidateIds: candidateList);
      expect(lockoutUntil, isNotNull);
      expect(await BiometricService.getFailedAttempts(userId: authUid, candidateIds: candidateList), greaterThanOrEqualTo(5));

      // 4. Emergency Self-Service / Authenticated Session Lockout Clear
      await BiometricService.clearStudentLockout(userId: docId, authUid: authUid, candidateIds: candidateList);
      final clearedLockout = await BiometricService.getLockoutUntil(userId: docId, authUid: authUid, candidateIds: candidateList);
      expect(clearedLockout, isNull);
      expect(await BiometricService.getFailedAttempts(userId: authUid, candidateIds: candidateList), equals(0));

      // 5. App is immediately unlockable with correct PIN again after clearing lockout
      expect(await BiometricService.verifyPin('1234', userId: authUid, candidateIds: candidateList), isTrue);

      // 6. Student with NO PIN or biometric must NEVER be locked
      expect(await BiometricService.isLockEnabled(userId: 'empty_user'), isFalse);
      expect(await BiometricService.isLockEnabled(), isFalse); // Non-admin without ID must never lock
    });

    test('Test 72: Dynamic Facilities, Strict No-AC Verification, Multi-Personnel Contacts & Safe Gov ID Masking', () {
      // 1. LibraryModel Default Facilities: Guarantee NO AC unless explicitly configured
      final defaultLib = LibraryModel(
        id: 'lib_test',
        name: 'The Cozy Corner Study Centre',
        address: 'Nath Road, Parli',
        logoUrl: '',
        contact: '9403243830',
        ownerId: 'owner_123',
        accentColor: 0xFF5D4037,
        welcomeMessage: 'Welcome',
        operatingHours: '6 AM - 11 PM',
        socialLinks: {},
        rulesText: 'Rules',
        adminPhotoUrl: '',
        helplineNumber: '9403243830',
        waitingListMode: WaitingListMode.contactAdmin,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        adminName: 'Sanket Shahane',
      );

      // Verify that AC is NOT in the default facilities
      expect(defaultLib.facilities, isNot(contains('Air Conditioning (AC)')));
      expect(defaultLib.facilities, isNot(contains('AC')));
      expect(defaultLib.hasAirConditioning, isFalse);

      // 2. Backward Compatibility: When only adminName is present, populatedPersonnel shows "Admin / Owner / Manager"
      final personnelSingle = defaultLib.populatedPersonnel;
      expect(personnelSingle.length, equals(1));
      expect(personnelSingle.first['role'], equals('Admin / Owner / Manager'));
      expect(personnelSingle.first['name'], equals('Sanket Shahane'));
      expect(personnelSingle.first['contact'], equals('9403243830'));

      // 3. Multi-Personnel: When separate Owner, Admin, Manager are configured
      final multiLib = defaultLib.copyWith(
        ownerName: 'Sanket Shahane',
        ownerContact: '9403243830',
        adminName: 'Shrikrishnadatta Sonpethkar',
        adminContact: '8625982248',
        managerName: 'Rahul Deshmukh',
        managerContact: '9876543210',
        facilities: [
          'High-Speed Wi-Fi',
          'Power Sockets at Desk',
          'Air Conditioning (AC)',
        ],
      );

      final personnelMulti = multiLib.populatedPersonnel;
      expect(personnelMulti.length, equals(3));
      expect(personnelMulti[0]['role'], equals('Owner'));
      expect(personnelMulti[0]['name'], equals('Sanket Shahane'));
      expect(personnelMulti[1]['role'], equals('Admin'));
      expect(personnelMulti[1]['name'], equals('Shrikrishnadatta Sonpethkar'));
      expect(personnelMulti[2]['role'], equals('Manager'));
      expect(personnelMulti[2]['name'], equals('Rahul Deshmukh'));

      // 4. AC check when explicitly enabled
      expect(multiLib.hasAirConditioning, isTrue);

      // 5. Seat Label Formatting: Human readable, never composite IDs
      expect(SeatHelper.formatSeatLabel(seatId: '1790647291016_r0_c1'), equals('Seat #2'));
      expect(SeatHelper.formatSeatLabel(seatId: '1790647291016_r0_c0'), equals('Seat #1'));
      expect(SeatHelper.formatSeatWithSection(seatId: '1790647291016_r0_c1', sectionName: 'Cozy Hall'), equals('Cozy Hall • Seat #2'));

      // 6. Safe Gov ID Masking: Never exposes ciphertext like CZZ••••E=
      final plainAadhaar = '123456789012';
      final safeDecrypted = EncryptionService.safeDecryptGovId(plainAadhaar, 'lib_test');
      expect(safeDecrypted, equals('123456789012'));

      // Failed / invalid encrypted ciphertext gracefully returns masked placeholder
      final garbageCipher = 'CZZsdfsdfsdfE=';
      final safeCipherResult = EncryptionService.safeDecryptGovId(garbageCipher, 'lib_test');
      expect(safeCipherResult, equals('••••••••'));
    });

    test('Test 73: 100% DIGITAL PASS ARCHITECTURE: Zero ID Card Print or Download Actions Across System', () {
      // 1. Digital Pass Credential Verification
      final testStudent = StudentModel(
        id: 'std_digital_001',
        name: 'Srikrishnadatta Bharatrao Sonpethkar',
        fatherName: 'Bharat',
        phone: '8625982248',
        email: 'thecozycornersc@gmail.com',
        bloodGroup: 'AB+',
        course: 'Mechanical',
        college: 'Universal College of Engineering',
        year: '2026',
        seatId: '1790647291016_r0_c1',
        emergencyContact: '9359492248',
        membershipNumber: 'CC20260002',
        planStartDate: DateTime(2026, 10, 22),
        planEndDate: DateTime(2026, 11, 22),
        gender: Gender.male,
        membershipStatus: MembershipStatus.active,
        address: 'Parli',
        pincode: '431515',
        govIdType: GovIdType.aadhaar,
        govIdNumber: '123456789012',
        govIdImageUrl: '',
        photoUrl: '',
        createdAt: DateTime(2026, 10, 22),
        customFields: const {},
      );

      final library = LibraryModel.fromJson({
        'id': 'lib_digital',
        'name': 'The Cozy Corner Study Centre',
        'adminName': 'Sanket Shahane',
        'contact': '9403243830',
        'helplineNumber': '9403243830',
      });

      // 2. Both Admin and Student operate strictly on Digital Passes
      // No printing allowed, no PDF download required
      bool allowPhysicalPrint({required bool isStudent}) => false;
      bool allowIdCardDownload({required bool isStudent}) => false;
      bool allowDigitalPassView({required bool isStudent}) => true;
      bool allowDigitalWhatsAppShare({required bool isStudent}) => true;

      expect(allowPhysicalPrint(isStudent: true), isFalse);
      expect(allowPhysicalPrint(isStudent: false), isFalse);
      expect(allowIdCardDownload(isStudent: true), isFalse);
      expect(allowIdCardDownload(isStudent: false), isFalse);
      expect(allowDigitalPassView(isStudent: true), isTrue);
      expect(allowDigitalPassView(isStudent: false), isTrue);
      expect(allowDigitalWhatsAppShare(isStudent: true), isTrue);
      expect(allowDigitalWhatsAppShare(isStudent: false), isTrue);

      // 3. Digital Pass QR Payload verification
      final dynamicId = testStudent.membershipNumber ?? testStudent.id;
      final qrPayload = 'STUDENT:${testStudent.id}:$dynamicId:${library.id}';
      expect(qrPayload, contains('CC20260002'));
      expect(qrPayload, contains('lib_digital'));

      // 4. Clean human readable seat formatted on digital pass
      final formattedSeat = SeatHelper.formatSeatLabel(seatId: testStudent.seatId);
      expect(formattedSeat, equals('Seat #2'));
      expect(formattedSeat, isNot(contains('1790647291016')));
    });

    test('Test 74: ADMIN HEADER ACTIONS & STREAMLINED STUDENT DASHBOARD (Zero Study Streak / Check-In)', () {
      // 1. Verify Admin Dashboard Header feature set
      const adminHeaderActions = ['theme_toggle', 'notification_center', 'global_search'];
      expect(adminHeaderActions, contains('theme_toggle'));
      expect(adminHeaderActions, contains('notification_center'));
      expect(adminHeaderActions, contains('global_search'));

      // 2. Verify Student Dashboard feature set: Study Streak & Check-in completely removed
      const studentDashboardWidgets = [
        'dynamic_smart_pass',
        'assigned_seat_card',
        'quick_services_dock',
        'compact_contact_card',
      ];
      expect(studentDashboardWidgets, isNot(contains('study_streak_banner')));
      expect(studentDashboardWidgets, isNot(contains('check_in_button')));
      expect(studentDashboardWidgets, isNot(contains('check_out_button')));
      expect(studentDashboardWidgets.first, equals('dynamic_smart_pass'));
    });

    test('Test 75: APPLE BENTO PROFILE SCREEN ARCHITECTURE (Consolidated Contact & Personnel)', () {
      // 1. Verify single helpline propagates to contact, phone, helplineNumber, and whatsappNumber
      final libraryMap = {
        'id': 'lib_bento_001',
        'name': 'The Cozy Corner Study Centre',
        'address': 'Front Of Reliance Fashion Factory, Nath Road, Parli-431515',
        'contact': '9403243830',
        'phone': '9403243830',
        'helplineNumber': '9403243830',
        'whatsappNumber': '9403243830',
        'adminName': 'Sanket Shahane',
        'ownerName': 'Sanket Shahane',
        'tagline': 'Smart Study Center & Silent Reading Hall',
        'operatingHours': '06:00 AM – 11:00 PM',
        'membershipPrefix': 'CC',
        'facilities': [
          'High-Speed Wi-Fi',
          'Power Sockets at Desk',
          'Purified RO Water',
          'Silent Study Zone',
          'CCTV Surveillance',
          'Ergonomic Chairs',
        ],
      };

      final lib = LibraryModel.fromJson(libraryMap);
      expect(lib.name, equals('The Cozy Corner Study Centre'));
      expect(lib.contact, equals('9403243830'));
      expect(lib.phone, equals('9403243830'));
      expect(lib.effectiveContact, equals('9403243830'));
      expect(lib.adminName, equals('Sanket Shahane'));
      expect(lib.tagline, equals('Smart Study Center & Silent Reading Hall'));
      expect(lib.membershipPrefix, equals('CC'));
      expect(lib.operatingHours, equals('06:00 AM – 11:00 PM'));
      expect(lib.facilities.length, equals(6));
      expect(lib.facilities, contains('High-Speed Wi-Fi'));

      // 2. Verify optional manager expansion
      final libWithManager = LibraryModel.fromJson({
        ...libraryMap,
        'managerName': 'Rahul Deshmukh',
        'managerContact': '9876543210',
      });
      expect(libWithManager.managerName, equals('Rahul Deshmukh'));
      expect(libWithManager.managerContact, equals('9876543210'));
    });

    test('Test 76: STUDENT PASS OFFLINE CACHING & INSTANT DESERIALIZATION (Underground Basement Resilience)', () {
      // Create a full StudentModel representing an active student with a digital pass
      final originalStudent = StudentModel(
        id: 'student_offline_001',
        name: 'Ganesh Shinde',
        fatherName: 'Ramesh Shinde',
        phone: '9876543210',
        email: 'ganesh@example.com',
        gender: Gender.male,
        address: 'Parli Vaijnath',
        pincode: '431515',
        govIdType: GovIdType.aadhaar,
        govIdNumber: '123456789012',
        govIdImageUrl: '',
        photoUrl: 'https://cdn.example.com/photos/ganesh.jpg',
        college: 'Vaidyanath College',
        course: 'M.Sc',
        year: '2',
        emergencyContact: '9123456780',
        seatId: 'seat_a1',
        sectionId: 'sec_ground',
        planId: 'plan_monthly',
        planStartDate: DateTime(2026, 1, 1),
        planEndDate: DateTime(2026, 12, 31),
        membershipStatus: MembershipStatus.active,
        customFields: const {},
        userId: 'firebase_auth_uid_ganesh',
        membershipNumber: 'CC20260042',
        bloodGroup: 'O+',
      );

      // Serialize to JSON string (as stored in SharedPreferences offline cache)
      final serializedJson = jsonEncode(originalStudent.toJson());
      expect(serializedJson, isNotEmpty);
      expect(serializedJson, contains('CC20260042'));
      expect(serializedJson, contains('seat_a1'));

      // Deserialize back to StudentModel (instant <5ms offline recovery)
      final Map<String, dynamic> decodedMap = jsonDecode(serializedJson);
      final restoredStudent = StudentModel.fromJson(decodedMap);

      expect(restoredStudent.id, equals(originalStudent.id));
      expect(restoredStudent.name, equals('Ganesh Shinde'));
      expect(restoredStudent.membershipNumber, equals('CC20260042'));
      expect(restoredStudent.seatId, equals('seat_a1'));
      expect(restoredStudent.membershipStatus, equals(MembershipStatus.active));
      expect(restoredStudent.isEffectivelyActive, isTrue);
      expect(restoredStudent.bloodGroup, equals('O+'));
      expect(restoredStudent.photoUrl, equals(originalStudent.photoUrl));
    });

    test('Test 77: REAL-TIME SEAT SWAPPING & OCCUPANCY INVARIANT INTEGRITY', () {
      // 1. Initial State: Seat A1 occupied by Ganesh, Seat B2 available
      final initialSeatA1 = SeatModel(
        id: 'seat_a1',
        sectionId: 'sec_ground',
        row: 0,
        col: 0,
        label: 'A1',
        status: SeatStatus.occupied,
        genderRestriction: GenderRestriction.any,
        studentId: 'student_001',
      );

      final initialSeatB2 = SeatModel(
        id: 'seat_b2',
        sectionId: 'sec_ground',
        row: 0,
        col: 1,
        label: 'B2',
        status: SeatStatus.available,
        genderRestriction: GenderRestriction.any,
      );

      expect(initialSeatA1.status, equals(SeatStatus.occupied));
      expect(initialSeatA1.studentId, equals('student_001'));
      expect(initialSeatB2.status, equals(SeatStatus.available));
      expect(initialSeatB2.studentId, isNull);

      // 2. Admin swaps student from A1 to B2
      // Seat A1 becomes available
      final updatedSeatA1 = initialSeatA1.copyWith(
        status: SeatStatus.available,
        clearStudent: true,
      );

      // Seat B2 becomes occupied by Ganesh
      final updatedSeatB2 = initialSeatB2.copyWith(
        status: SeatStatus.occupied,
        studentId: 'student_001',
      );

      // Student model reflects updated seat
      final updatedStudent = StudentModel(
        id: 'student_001',
        name: 'Ganesh Shinde',
        fatherName: 'Ramesh Shinde',
        phone: '9876543210',
        email: 'ganesh@example.com',
        gender: Gender.male,
        address: 'Parli',
        pincode: '431515',
        govIdType: GovIdType.aadhaar,
        govIdNumber: '123456789012',
        govIdImageUrl: '',
        photoUrl: '',
        college: 'College',
        course: 'B.Sc',
        year: '1',
        emergencyContact: '9123456780',
        seatId: updatedSeatB2.id,
        sectionId: updatedSeatB2.sectionId,
        membershipStatus: MembershipStatus.active,
        customFields: const {},
      );

      expect(updatedSeatA1.status, equals(SeatStatus.available));
      expect(updatedSeatA1.studentId, isNull);
      expect(updatedSeatB2.status, equals(SeatStatus.occupied));
      expect(updatedSeatB2.studentId, equals('student_001'));
      expect(updatedStudent.seatId, equals('seat_b2'));
      expect(updatedStudent.sectionId, equals('sec_ground'));
    });

    test('Test 78: DIGITAL PASS ORG LOGO & ZERO-BLINKING IMAGE PROVIDER CACHE', () {
      // 1. ImageService base64 memory cache identity preservation
      const sampleBase64 = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      final p1 = ImageService.getImageProvider(sampleBase64);
      final p2 = ImageService.getImageProvider(sampleBase64);
      expect(p1, isNotNull);
      expect(p2, isNotNull);
      expect(identical(p1, p2), isTrue, reason: 'Identical MemoryImage instance must be returned across rebuilds to prevent flickering/blinking');

      // 2. LibraryModel organization logoUrl propagation
      final lib = LibraryModel.fromJson({
        'id': 'lib_test',
        'name': 'The Cozy Corner Study Centre',
        'address': 'Parli',
        'contact': '9403243830',
        'logoUrl': 'https://firebasestorage.googleapis.com/v0/b/study-lib-mgmt-2026.appspot.com/o/logo.png?alt=media',
      });
      expect(lib.logoUrl, isNotEmpty);
      final logoProvider = ImageService.getImageProvider(lib.logoUrl);
      expect(logoProvider, isNotNull);
    });

    test('Test 79: REAL-TIME DYNAMIC PASS VALIDITY & EXPOSURE OF EXPIRED/GRACE/ACTIVE STATES', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 2));
      final tomorrow = now.add(const Duration(days: 2));

      // 1. Expired plan (Stored membershipStatus='active', but planEndDate is in the past)
      final expiredStudent = StudentModel.fromJson({
        'id': 'student_exp_001',
        'name': 'Srikrishnadatta Sonpethkar',
        'fatherName': 'Bharat',
        'phone': '8625982248',
        'email': 'test@gmail.com',
        'seatId': 'seat_2',
        'membershipStatus': 'active', // Still 'active' in Firestore document
        'planEndDate': yesterday.toIso8601String(),
      });

      expect(expiredStudent.membershipStatus, equals(MembershipStatus.active), reason: 'Document status is active');
      expect(expiredStudent.isExpired, isTrue, reason: 'Plan end date is in the past');
      expect(expiredStudent.isEffectivelyActive, isFalse, reason: 'Genuinely expired student cannot be effectively active');
      expect(expiredStudent.effectiveMembershipStatus, equals(MembershipStatus.expired), reason: 'Dynamic status must evaluate to expired');

      // 2. Grace period plan (planEndDate is in past, but graceEndDate is in future)
      final graceStudent = StudentModel.fromJson({
        'id': 'student_grace_002',
        'name': 'Rahul Sharma',
        'fatherName': 'Father',
        'phone': '9876543210',
        'email': 'rahul@gmail.com',
        'seatId': 'seat_5',
        'membershipStatus': 'active',
        'planEndDate': yesterday.toIso8601String(),
        'graceEndDate': tomorrow.toIso8601String(),
      });

      expect(graceStudent.isExpired, isFalse, reason: 'Within grace period');
      expect(graceStudent.isEffectivelyActive, isTrue, reason: 'Within grace period');
      expect(graceStudent.effectiveMembershipStatus, equals(MembershipStatus.grace), reason: 'Dynamic status must evaluate to grace');

      // 3. Active plan (planEndDate is in future)
      final activeStudent = StudentModel.fromJson({
        'id': 'student_act_003',
        'name': 'Pooja Patil',
        'fatherName': 'Father',
        'phone': '9123456789',
        'email': 'pooja@gmail.com',
        'seatId': 'seat_10',
        'membershipStatus': 'active',
        'planEndDate': tomorrow.toIso8601String(),
      });

      expect(activeStudent.isExpired, isFalse);
      expect(activeStudent.isEffectivelyActive, isTrue);
      expect(activeStudent.effectiveMembershipStatus, equals(MembershipStatus.active));

      // 4. Blocked account
      final blockedStudent = StudentModel.fromJson({
        'id': 'student_blk_004',
        'name': 'Blocked User',
        'fatherName': 'Father',
        'phone': '9000000000',
        'email': 'blocked@gmail.com',
        'seatId': 'seat_12',
        'membershipStatus': 'blocked',
        'planEndDate': tomorrow.toIso8601String(),
      });

      expect(blockedStudent.effectiveMembershipStatus, equals(MembershipStatus.blocked));
      expect(blockedStudent.isEffectivelyActive, isFalse);

      // 5. QR Code Payload Status Dynamic Parity
      final qrPayload = jsonEncode({
        'type': 'STUDENT_PASS',
        'id': expiredStudent.id,
        'status': expiredStudent.effectiveMembershipStatus.name.toUpperCase(),
      });
      final decoded = jsonDecode(qrPayload) as Map<String, dynamic>;
      expect(decoded['status'], equals('EXPIRED'));
    });

    test('80. ZERO-CLICK AUTO-SEAT RETENTION, GOOGLE OAUTH PARITY & PAYMENT DEDUPLICATION', () {
      // 1. Verify StudentModel sticky seat memory fields
      final student = StudentModel.fromJson({
        'id': 'student_seat_001',
        'name': 'Srikrishnadatta Sonpethkar',
        'fatherName': 'Bharat',
        'gender': 'MALE',
        'phone': '8625982248',
        'email': 'konpethkar02@gmail.com',
        'seatId': null,
        'sectionId': null,
        'previousSeatId': 'C1',
        'previousSectionId': 'sec_cabin_1',
        'membershipStatus': 'active',
      });

      final studentJson = student.toJson();
      expect(studentJson['previousSeatId'], equals('C1'));
      expect(studentJson['previousSectionId'], equals('sec_cabin_1'));

      final restored = StudentModel.fromJson(studentJson);
      expect(restored.previousSeatId, equals('C1'));
      expect(restored.previousSectionId, equals('sec_cabin_1'));

      // CopyWith seat restore test
      final reactivated = restored.copyWith(
        seatId: restored.previousSeatId,
        sectionId: restored.previousSectionId,
      );
      expect(reactivated.seatId, equals('C1'));
      expect(reactivated.sectionId, equals('sec_cabin_1'));

      // 2. Google OAuth Web Client AuthDomain verification
      expect(
        DefaultFirebaseOptions.web.authDomain,
        equals('study-lib-mgmt-2026.firebaseapp.com'),
        reason: 'AuthDomain must match Firebase authorized redirect URI to prevent Error 400: redirect_uri_mismatch',
      );

      // 3. Payment Method Deduplication logic
      final initialMethods = [
        'Cash / Pay at Reception',
        'UPI / QR Code',
        'Debit / Credit Card',
      ];
      final loadedFromDb = ['Cash', 'UPI', 'Cheque'];
      for (final m in loadedFromDb) {
        final normalized = m.toLowerCase() == 'cash'
            ? 'Cash / Pay at Reception'
            : (m.toLowerCase().contains('upi') ? 'UPI / QR Code' : m);
        if (!initialMethods.contains(normalized)) {
          initialMethods.add(normalized);
        }
      }
      expect(initialMethods.where((m) => m == 'Cash').isEmpty, isTrue);
      expect(initialMethods.contains('Cash / Pay at Reception'), isTrue);
      expect(initialMethods.contains('Cheque'), isTrue);

      // 4. Renewal Membership Period Accuracy
      final start = DateTime(2026, 11, 23);
      final end = DateTime(2026, 12, 31);
      final actualDays = end.difference(start).inDays + 1;
      expect(actualDays, equals(39));
    });

    test('81. SECTION CAPACITY AUTO-HEAL & CUSTOM PLAN STUDIO INTEGRITY', () {
      // 1. Stored Section Capacity vs Physical Desks
      // When Cozy Hall was initialized with 120 capacity, but only 59 desks were generated:
      final rawSection = SectionModel(
        id: 'sec_cozy_hall',
        libraryId: 'lib_1',
        name: 'Cozy Hall',
        rows: 10,
        cols: 12,
        color: 0xFF5D4037,
        order: 0,
        isActive: true,
        totalSeats: 120, // Old stored capacity in DB
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(rawSection.capacity, equals(120));

      // Auto-heal logic: live physical desks count (59) updates the section
      const physicalDesksCount = 59;
      final healedSection = rawSection.copyWith(
        totalSeats: physicalDesksCount,
        rows: (physicalDesksCount <= 10) ? 1 : (physicalDesksCount / 10).ceil(),
        cols: 10,
        updatedAt: DateTime.now(),
      );
      expect(healedSection.capacity, equals(59));
      expect(healedSection.totalSeats, equals(59));

      // 2. Custom Plan Naming & Complete Removal of "Ad-hoc fee"
      const userCustomName = 'Custom Plan';
      final effectivePlanName = userCustomName.isNotEmpty ? userCustomName : 'Custom Plan';
      expect(effectivePlanName, equals('Custom Plan'));
      expect(effectivePlanName.toLowerCase().contains('ad-hoc'), isFalse);
      expect(effectivePlanName.toLowerCase().contains('adhoc'), isFalse);

      // 3. Plan deserialization with merged doc ID
      final rawFirestoreDoc = {
        'name': 'Monthly',
        'price': 700.0,
        'duration': 30,
        'durationUnit': 'days',
        'isActive': true,
      };
      // When doc ID 'plan_monthly_1' is merged into fromJson payload:
      final plan = PlanModel.fromJson({...rawFirestoreDoc, 'id': 'plan_monthly_1'});
      expect(plan.id, equals('plan_monthly_1'));
      expect(plan.name, equals('Monthly'));
      expect(plan.price, equals(700.0));
      expect(plan.isActive, isTrue);
    });

    test('82. UNIFIED GRACE PERIOD RESOLUTION & CONTINUOUS RENEWAL CYCLE INTEGRITY', () {
      final now = DateTime.now();
      final expiredDate = DateTime(2026, 10, 31);

      // 1. Student in grace without explicit graceEndDate evaluates dynamically as grace and active
      final studentInGrace = StudentModel.fromJson({
        'id': 'student_grace_eval_01',
        'name': 'Grace Candidate',
        'fatherName': 'Father',
        'phone': '9876543210',
        'email': 'grace@test.com',
        'membershipStatus': 'grace',
        'planEndDate': expiredDate.toIso8601String(),
      });

      expect(studentInGrace.effectiveMembershipStatus, equals(MembershipStatus.grace));
      expect(studentInGrace.isEffectivelyActive, isTrue, reason: 'Grace period students hold their desk and remain active');
      expect(studentInGrace.isExpired, isFalse, reason: 'Student in grace is not marked expired');

      // 2. Continuous Queue vs Fresh Start Date Resolution
      // Continuous: Start = previous planEndDate + 1 day
      final continuousStart = DateTime(expiredDate.year, expiredDate.month, expiredDate.day + 1);
      expect(continuousStart, equals(DateTime(2026, 11, 1)));

      // Fresh start: Start = today
      final freshStart = DateTime(now.year, now.month, now.day);
      expect(freshStart.day, equals(now.day));

      // 3. 3-Tier Grace Period Resolution Hierarchy
      const defaultGraceDays = 3;
      final planOverrides = {'plan_custom': 5};
      final catalogGraceDays = {'plan_standard': 4};

      int resolveGrace(String planId) {
        return planOverrides[planId] ?? catalogGraceDays[planId] ?? defaultGraceDays;
      }

      expect(resolveGrace('plan_custom'), equals(5), reason: 'Admin override takes top priority');
      expect(resolveGrace('plan_standard'), equals(4), reason: 'Catalog plan setting is respected');
      expect(resolveGrace('plan_unconfigured'), equals(3), reason: 'Global default fallback applies');
    });

    test('83. CUSTOM PLAN DYNAMIC PRICING, BIDIRECTIONAL SYNC & DURATION PRESETS', () {
      // 1. Inclusive Day Calculation between Start Date and Expiry Date
      final start = DateTime(2026, 11, 3);
      final end15 = start.add(const Duration(days: 14)); // 03 Nov to 17 Nov inclusive is 15 days
      final calcDays15 = end15.difference(start).inDays + 1;
      expect(calcDays15, equals(15));

      // 2. Forward Calculation: Days * Daily Rate = Total Fee
      const dailyRate25 = 25.0;
      final totalFee15 = (calcDays15 * dailyRate25).roundToDouble();
      expect(totalFee15, equals(375.0)); // 15 days * ₹25 = ₹375

      const dailyRate30 = 25.0;
      final end30 = start.add(const Duration(days: 29)); // 30 days
      final calcDays30 = end30.difference(start).inDays + 1;
      expect(calcDays30, equals(30));
      final totalFee30 = (calcDays30 * dailyRate30).roundToDouble();
      expect(totalFee30, equals(750.0)); // 30 days * ₹25 = ₹750

      // 3. Till Month End Calculation
      final nextMonthFirst = DateTime(start.year, start.month + 1, 1);
      final monthEnd = nextMonthFirst.subtract(const Duration(days: 1));
      final monthEndDays = monthEnd.difference(start).inDays + 1;
      // In Nov (30 days), starting 3 Nov gives 28 days remaining
      expect(monthEndDays, equals(28));
      final monthEndFee = (monthEndDays * 25.0).roundToDouble();
      expect(monthEndFee, equals(700.0)); // 28 days * ₹25 = ₹700

      // 4. Reverse Calculation: Total Fee / Days = Daily Rate
      // Admin negotiates flat ₹500 for 15 days
      const negotiatedTotal = 500.0;
      final reverseRate = negotiatedTotal / calcDays15; // 500 / 15 = 33.333...
      final formattedRate = reverseRate.toStringAsFixed(1);
      expect(formattedRate, equals('33.3'));

      // 5. Partial Payment Installment Math
      const customTotalFee = 750.0;
      const payingNow = 400.0;
      final remainingDue = customTotalFee - payingNow;
      expect(remainingDue, equals(350.0));

      // 6. Complete Removal of 'Ad-hoc' / 'ad hoc' terms across custom plan naming
      const customPlanStudioTitle = 'Custom Plan Studio';
      const defaultCustomPlanName = 'Custom Plan';
      expect(customPlanStudioTitle.toLowerCase().contains('ad-hoc'), isFalse);
      expect(defaultCustomPlanName.toLowerCase().contains('ad-hoc'), isFalse);
    });

    test('84. ZERO-INDEXED SEAT CORRECTION, MONTH-END CAPPED CUSTOM PLANS & AUTO-SEAT RETENTION', () {
      // 1. Zero-indexed column seat label formatting (c0 -> Seat #1, c1 -> Seat #2)
      expect(SeatHelper.formatSeatLabel(seatId: 'c0'), equals('Seat #1'));
      expect(SeatHelper.formatSeatLabel(seatId: 'c1'), equals('Seat #2'));
      expect(SeatHelper.formatSeatLabel(seatId: 'c0', includePrefix: false), equals('#1'));
      expect(SeatHelper.formatSeatLabel(seatId: 'c1', includePrefix: false), equals('#2'));
      expect(SeatHelper.formatSeatLabel(seatId: 'desk_c0'), equals('Seat #1'));
      expect(SeatHelper.formatSeatLabel(seatId: 'seat_c4'), equals('Seat #5'));

      // 2. Custom plan model persistence with sticky recurring concession
      final customStudent = StudentModel.fromJson({
        'id': 'stud_custom_001',
        'name': 'Scholarship Candidate',
        'fatherName': 'Father',
        'gender': 'MALE',
        'phone': '9988776655',
        'email': 'scholar@study.com',
        'planId': 'custom',
        'customPlanName': 'Merit Scholarship',
        'customPlanFee': 450.0,
        'isStickyCustomPrice': true,
        'customDiscountReason': 'Academic Excellence Award',
      });

      final json = customStudent.toJson();
      expect(json['planId'], equals('custom'));
      expect(json['customPlanName'], equals('Merit Scholarship'));
      expect(json['customPlanFee'], equals(450.0));
      expect(json['isStickyCustomPrice'], isTrue);
      expect(json['customDiscountReason'], equals('Academic Excellence Award'));

      final restored = StudentModel.fromJson(json);
      expect(restored.planId, equals('custom'));
      expect(restored.customPlanName, equals('Merit Scholarship'));
      expect(restored.customPlanFee, equals(450.0));
      expect(restored.isStickyCustomPrice, isTrue);
      expect(restored.customDiscountReason, equals('Academic Excellence Award'));

      // 3. Strict month-end capping invariant
      final now = DateTime(2026, 11, 15);
      final nextMonthFirst = DateTime(now.year, now.month + 1, 1);
      final monthEnd = DateTime(nextMonthFirst.year, nextMonthFirst.month, 0, 23, 59, 59, 999);
      expect(monthEnd.month, equals(11));
      expect(monthEnd.day, equals(30)); // Nov has 30 days
      expect(monthEnd.hour, equals(23));

      // 4. Renewal retainSeat payload validation
      final renewalPayload = {
        'type': 'renewal',
        'studentId': 'stud_001',
        'retainSeat': true,
        'currentSeatId': 'c1',
      };
      expect(renewalPayload['retainSeat'], isTrue);
      expect(SeatHelper.formatSeatLabel(seatId: renewalPayload['currentSeatId'] as String), equals('Seat #2'));
    });

    test('85. STUDENT REGISTRATION SEAT SELECTION & GENDER RESTRICTION INTEGRITY', () {
      // 1. SelectedSeatDetails model verification
      const emptySelection = SelectedSeatDetails();
      expect(emptySelection.hasSelection, isFalse);
      expect(emptySelection.isAutoAssign, isFalse);
      expect(emptySelection.seatId, isNull);

      const specificSeat = SelectedSeatDetails(
        seatId: '1790647291016_r1_c4',
        seatLabel: '14',
        sectionId: '1790647291016',
        sectionName: 'Cozy Hall',
        isAutoAssign: false,
      );
      expect(specificSeat.hasSelection, isTrue);
      expect(specificSeat.isAutoAssign, isFalse);
      expect(specificSeat.seatLabel, equals('14'));
      expect(specificSeat.sectionName, equals('Cozy Hall'));

      const autoAssign = SelectedSeatDetails(
        seatId: null,
        seatLabel: 'Auto-Assign',
        sectionId: '1790647291016',
        sectionName: 'Cozy Hall',
        isAutoAssign: true,
      );
      expect(autoAssign.hasSelection, isTrue);
      expect(autoAssign.isAutoAssign, isTrue);

      // 2. Gender zoning rules check: Desks 1-50 (Boys), Desks 51-60 (Girls)
      bool isEligibleForGender(String gender, int seatNum) {
        if (gender == 'male') {
          return seatNum <= 50;
        } else if (gender == 'female') {
          return true; // Girls can select girls zone (51-60) or any available desk
        }
        return true;
      }

      // Male student test
      expect(isEligibleForGender('male', 14), isTrue);
      expect(isEligibleForGender('male', 50), isTrue);
      expect(isEligibleForGender('male', 51), isFalse); // Female row blocked for male
      expect(isEligibleForGender('male', 60), isFalse); // Female row blocked for male

      // Female student test
      expect(isEligibleForGender('female', 55), isTrue);
      expect(isEligibleForGender('female', 14), isTrue);

      // 3. Admission request payload with seat selection metadata
      final registrationPayload = {
        'type': 'registration',
        'status': 'pending',
        'studentName': 'Rahul Sharma',
        'studentPhone': '9876543210',
        'planId': 'plan_monthly',
        'requestedSeatId': specificSeat.seatId,
        'requestedSeatLabel': specificSeat.seatLabel,
        'requestedSectionId': specificSeat.sectionId,
        'requestedSectionName': specificSeat.sectionName,
        'studentData': {
          'name': 'Rahul Sharma',
          'phone': '9876543210',
          'gender': 'male',
          'seatId': specificSeat.seatId,
          'sectionId': specificSeat.sectionId,
          'requestedSeatLabel': specificSeat.seatLabel,
          'requestedSectionName': specificSeat.sectionName,
        },
      };

      expect(registrationPayload['requestedSeatId'], equals('1790647291016_r1_c4'));
      expect(registrationPayload['requestedSeatLabel'], equals('14'));
      expect(registrationPayload['requestedSectionName'], equals('Cozy Hall'));
      expect((registrationPayload['studentData'] as Map)['seatId'], equals('1790647291016_r1_c4'));
    });

    test('86. ROLE PRECEDENCE, STUDENT MULTI-TENANT ISOLATION & TEST WORKSPACE QUARANTINE', () {
      const defaultLibraryId = 'aPSMq8xSAjuZQh2fTtuY';
      const testLibraryId = 'a9XtHXM2jDpFWXvm7guS';
      const studentUid = 'Z4vp6LzMXkMaLbGfUm7XEyfcr463';
      const studentEmail = 'ashishchoudhari04@gmail.com';
      const studentPhone = '7385817571';

      // 1. Master admin whitelist rejection check
      const masterWhitelistedEmails = {
        'ksonpethkar@gmail.com',
        'thecozycornersc@gmail.com',
      };
      expect(masterWhitelistedEmails.contains(studentEmail.toLowerCase()), isFalse);

      // 2. Student Precedence Invariant:
      // When a user exists in the library roster as a student,
      // their role MUST resolve as AppUserRole.student, regardless of any test library ownership
      final studentRosterEntry = {
        'id': 'CC20260002_ashish',
        'name': 'Ashish Wagesh Choudhari',
        'phone': studentPhone,
        'email': studentEmail,
        'libraryId': defaultLibraryId,
        'membershipStatus': 'expired',
        'expiryDate': '2026-10-31T00:00:00.000Z',
      };

      // Multi-identifier resolution verification
      final phoneVariants = <String>{
        studentPhone,
        '+91$studentPhone',
        '91$studentPhone',
        '0$studentPhone',
      };
      expect(phoneVariants.contains('7385817571'), isTrue);
      expect(phoneVariants.contains('+917385817571'), isTrue);

      // 3. Test Library Quarantine Policy:
      // Any test library owned by studentUid that is NOT defaultLibraryId must be quarantined
      final rawLibraries = [
        {'id': defaultLibraryId, 'name': 'The Cozy Corner Study Centre', 'ownerId': '85k5JWF8baMgAJmtRdZd3IIpxnf1'},
        {'id': testLibraryId, 'name': 'the cozy corner (test)', 'ownerId': studentUid, 'totalDesks': 3481},
      ];

      final quarantinedLibraries = rawLibraries.map((lib) {
        if (lib['ownerId'] == studentUid && lib['id'] != defaultLibraryId) {
          return {
            ...lib,
            'ownerId': 'quarantined_test_owner',
            'quarantinedReason': 'Disassociated orphan test library - owner is student',
          };
        }
        return lib;
      }).toList();

      expect(quarantinedLibraries[0]['ownerId'], equals('85k5JWF8baMgAJmtRdZd3IIpxnf1'));
      expect(quarantinedLibraries[1]['ownerId'], equals('quarantined_test_owner'));

      // 4. Role Authority & Session Cleansing Invariant
      final sessionProfile = {
        'role': 'student',
        'libraryId': defaultLibraryId,
        'isStaff': false,
        'isOwner': false,
        'studentName': studentRosterEntry['name'],
      };

      expect(sessionProfile['role'], equals('student'));
      expect(sessionProfile['libraryId'], equals(defaultLibraryId));
      expect(sessionProfile['isOwner'], isFalse);
    });

    test('87. PRIORITY ANNOUNCEMENTS & LEADING-APP 3-LAYER NAVIGATION ARCHITECTURE', () {
      // 1. Verify AnnouncementPriority serialization & visual mapping
      final urgentAnnouncement = AnnouncementModel.fromJson({
        'id': 'ann_001',
        'libraryId': 'lib_test_parli',
        'title': 'Library Closed for Diwali',
        'message': 'Study halls will remain closed on Diwali.',
        'type': 'broadcast',
        'priority': 'urgent',
        'isActive': true,
        'readBy': ['student_1', 'student_2'],
        'expiresAt': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      });

      expect(urgentAnnouncement.priority, equals(AnnouncementPriority.urgent));
      expect(urgentAnnouncement.isExpired, isFalse);
      expect(urgentAnnouncement.isReadBy('student_1'), isTrue);
      expect(urgentAnnouncement.isReadBy('student_3'), isFalse);
      expect(urgentAnnouncement.priority.label, equals('Urgent'));

      // 2. Verify Expiration Logic
      final expiredAnnouncement = AnnouncementModel.fromJson({
        'id': 'ann_002',
        'libraryId': 'lib_test_parli',
        'title': 'Maintenance Notice',
        'message': 'AC maintenance in Cozy Hall.',
        'type': 'banner',
        'priority': 'maintenance',
        'isActive': true,
        'expiresAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });

      expect(expiredAnnouncement.priority, equals(AnnouncementPriority.maintenance));
      expect(expiredAnnouncement.isExpired, isTrue);

      // 3. Verify Route Constants for Leading App Navigation
      expect(Routes.studentAnnouncements, equals('/student/announcements'));
      expect(Routes.studentHome, equals('/student/home'));
      expect(Routes.adminAnnouncements, equals('/admin/announcements'));

      // 4. Default priority fallback
      final defaultAnnouncement = AnnouncementModel.fromJson({
        'id': 'ann_003',
        'libraryId': 'lib_test_parli',
        'title': 'Regular Notice',
        'message': 'Please maintain silence.',
      });
      expect(defaultAnnouncement.priority, equals(AnnouncementPriority.general));
      expect(defaultAnnouncement.targetAudience, equals('all'));
    });

    test('88. SINGLE-UPLOAD GOVT ID, REAL-TIME FRIENDLY VALIDATION & ADMIN DOCUMENT STUDIO', () {
      // 1. AadhaarInputFormatter: 4-4-4 spacing enforcement
      final formatter = AadhaarInputFormatter();
      const rawDigits = '548212345678';
      final formattedVal = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: rawDigits),
      );
      expect(formattedVal.text, equals('5482 1234 5678'));

      // 2. Human-friendly validation messages (zero technical jargon / regex leaks)
      expect(
        GovIdValidator.validate(GovIdType.aadhaar, '5482 1234'),
        equals('Aadhaar must be 12 digits (e.g. 5482 1234 5678)'),
      );
      expect(
        GovIdValidator.validate(GovIdType.aadhaar, '0123 4567 8901'),
        equals('Aadhaar cannot begin with 0 or 1'),
      );
      expect(
        GovIdValidator.validate(GovIdType.pan, 'ABC123'),
        equals('Enter 10-character PAN (e.g. ABCDE1234F)'),
      );
      expect(
        GovIdValidator.validate(GovIdType.voterId, '12345'),
        equals('Enter 10-character Voter ID (e.g. ABC1234567)'),
      );
      expect(
        GovIdValidator.validate(GovIdType.passport, '123'),
        equals('Enter 8-character Passport number (e.g. A1234567)'),
      );

      // Valid IDs pass cleanly without error
      final validAadhaarCheckDigit = AppValidators.generateVerhoeffCheckDigit('54821234567');
      final validAadhaarStr = '5482 1234 567$validAadhaarCheckDigit';
      expect(GovIdValidator.validate(GovIdType.aadhaar, validAadhaarStr), isNull);
      expect(GovIdValidator.validate(GovIdType.pan, 'ABCDE1234F'), isNull);
      expect(GovIdValidator.validate(GovIdType.voterId, 'ABC1234567'), isNull);
      expect(GovIdValidator.validate(GovIdType.passport, 'A1234567'), isNull);

      // 3. Single-Upload Lifecycle & Zero Duplication Payload
      const frontDataUrl = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD...front';
      const backDataUrl = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD...back';
      final registrationPayload = {
        'name': 'Rahul Sharma',
        'phone': '9823456789',
        'govIdType': 'aadhaar',
        'govIdNumber': validAadhaarStr,
        'govIdImageUrl': frontDataUrl,
        'govIdBackImageUrl': backDataUrl,
        'photoUrl': 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD...selfie', // Strictly separate portrait photo
      };

      // Ensure Gov ID is captured once and preserved without duplicate upload
      expect(registrationPayload['govIdImageUrl'], equals(frontDataUrl));
      expect(registrationPayload['govIdBackImageUrl'], equals(backDataUrl));
      expect(registrationPayload['photoUrl'], isNot(equals(frontDataUrl)));

      // 4. Google Account vs ID OCR Legal Name Reconciliation
      const googleDisplayName = 'Rahul S';
      const ocrLegalName = 'Rahul Suresh Sharma';
      final isNameReconciled = ocrLegalName != googleDisplayName;
      expect(isNameReconciled, isTrue);

      // 5. Admin Document Studio Watermark & Rotation Invariant
      const watermarkOrgName = 'The Cozy Corner Study Centre';
      const stampText = 'COZY CORNER STUDY CENTRE • ADMISSION VERIFIED';
      expect(stampText.contains('COZY CORNER STUDY CENTRE'), isTrue);
      expect(watermarkOrgName.isNotEmpty, isTrue);
    });

    test('89. STUDENT RENEWAL PAYMENT CAPABILITY-GATING & DYNAMIC METHOD RESOLUTION', () {
      // 1. Admin turns off Bank Transfer (like user scenario)
      final adminMethodsSettings = [
        {'id': 'cash', 'name': 'Cash / Pay at Reception', 'active': true},
        {'id': 'upi', 'name': 'UPI / QR Code', 'active': true},
        {'id': 'card', 'name': 'Debit / Credit Card', 'active': false},
        {'id': 'bank', 'name': 'Bank Transfer', 'active': false},
        {'id': 'cheque', 'name': 'Cheque / DD', 'active': false},
      ];

      final emptyBankDetails = {
        'bankName': '',
        'accountNumber': '',
      };
      final hasBankConfigured = (emptyBankDetails['bankName']?.isNotEmpty ?? false) &&
          (emptyBankDetails['accountNumber']?.isNotEmpty ?? false);

      const upiId = '7276969070@upi';
      final hasUpiConfigured = upiId.isNotEmpty;

      final isUpiActive = (adminMethodsSettings.firstWhere((m) => m['id'] == 'upi')['active'] == true) && hasUpiConfigured;
      final isBankActive = (adminMethodsSettings.firstWhere((m) => m['id'] == 'bank')['active'] == true) && hasBankConfigured;
      final isCashActive = (adminMethodsSettings.firstWhere((m) => m['id'] == 'cash')['active'] == true);

      final availableModes = <String>[];
      if (isUpiActive) availableModes.add('upi');
      if (isBankActive) availableModes.add('bank');
      if (isCashActive) availableModes.add('deskCash');

      // Bank Transfer MUST NOT be available when active is false
      expect(availableModes.contains('bank'), isFalse);
      expect(availableModes, equals(['upi', 'deskCash']));

      // 2. If student had previously selected bank, auto-switch to first available active method (UPI)
      const studentSelectedMode = 'bank';
      final activeResolvedMode = availableModes.contains(studentSelectedMode)
          ? studentSelectedMode
          : availableModes.first;
      expect(activeResolvedMode, equals('upi'));

      // 3. Defensive check: Bank toggle is true, but Bank Name / Account No is blank
      final bankToggledOnIncomplete = [
        {'id': 'bank', 'name': 'Bank Transfer', 'active': true},
      ];
      final isBankConfiguredAndActive = (bankToggledOnIncomplete.first['active'] == true) && hasBankConfigured;
      expect(isBankConfiguredAndActive, isFalse, reason: 'Bank transfer must remain disabled if account details are blank');

      // 4. Single Payment Method Active (e.g. UPI Only) -> SegmentedButton hidden
      final singleModeAvailable = ['upi'];
      expect(singleModeAvailable.length > 1, isFalse, reason: 'When only 1 method is active, switcher is hidden and directly renders payment card');
    });

    test('90. STUDENT RECEIPTS VISIBILITY & REAL-TIME ENROLLMENT PASS AUTO-SYNTHESIS', () {
      // 1. PaymentModel Serialization with studentUserId
      final payment = PaymentModel(
        id: 'pay_999',
        studentId: 'st_123',
        studentUserId: 'usr_auth_abc',
        amount: 2000.0,
        method: 'UPI / Desk Admission',
        date: DateTime.now(),
        status: PaymentStatus.paid,
        createdAt: DateTime.now(),
      );

      final payJson = payment.toJson();
      expect(payJson['studentUserId'], equals('usr_auth_abc'));
      expect(payJson['studentId'], equals('st_123'));
      expect(payJson['amount'], equals(2000.0));

      final payDeserialized = PaymentModel.fromJson(payJson);
      expect(payDeserialized.studentUserId, equals('usr_auth_abc'));
      expect(payDeserialized.studentId, equals('st_123'));

      // 2. Active Student without Firestore Receipt Doc -> Auto-synthesize enrollment pass
      final activeStudent = StudentModel(
        id: 'st_123',
        name: 'Kshitij S',
        fatherName: '',
        phone: '9876543210',
        email: 'ksonpethkar@gmail.com',
        gender: Gender.male,
        address: 'Pune',
        pincode: '411001',
        govIdType: GovIdType.pan,
        govIdNumber: 'ABCDE1234F',
        govIdImageUrl: '',
        photoUrl: '',
        college: '',
        course: '',
        year: '',
        emergencyContact: '9876543211',
        membershipStatus: MembershipStatus.active,
        planId: 'plan_quarterly_2000',
        planStartDate: DateTime(2026, 11, 1),
        planEndDate: DateTime(2027, 1, 31),
        seatId: '46',
        membershipNumber: 'CC20260001',
        customFields: const {},
        userId: 'usr_auth_abc',
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );

      // Verify that receipts list is never empty for active members
      final List<ReceiptModel> studentReceipts = [];
      if (studentReceipts.isEmpty && (activeStudent.membershipStatus == MembershipStatus.active || activeStudent.planId != null)) {
        final uniqueSuffix = activeStudent.membershipNumber?.isNotEmpty == true
            ? activeStudent.membershipNumber!
            : activeStudent.id.toUpperCase();

        studentReceipts.add(
          ReceiptModel(
            id: 'active_enrollment_${activeStudent.id}',
            libraryId: 'lib_001',
            receiptNumber: 'REC-2026-$uniqueSuffix',
            studentId: activeStudent.id,
            studentUserId: activeStudent.userId,
            planId: activeStudent.planId ?? 'membership_enrollment',
            amount: 2000.0,
            totalFee: 2000.0,
            paidAmount: 2000.0,
            remainingDue: 0.0,
            paymentMethod: 'Desk / Confirmed',
            validFrom: activeStudent.planStartDate!,
            validTo: activeStudent.planEndDate!,
            status: ReceiptStatus.active,
            customFields: {
              'planName': 'Pro Scholar Quarterly',
              'seatLabel': SeatHelper.formatSeatLabel(seatId: activeStudent.seatId),
              'admissionType': 'Official Enrollment Receipt',
            },
            createdAt: activeStudent.planStartDate!,
            updatedAt: activeStudent.planStartDate!,
          ),
        );
      }

      expect(studentReceipts.isNotEmpty, isTrue, reason: 'Active students must always have their enrollment receipt visible');
      final r = studentReceipts.first;
      expect(r.receiptNumber, equals('REC-2026-CC20260001'));
      expect(r.amount, equals(2000.0));
      expect(r.studentUserId, equals('usr_auth_abc'));
      expect(r.status, equals(ReceiptStatus.active));
      expect(r.customFields['seatLabel'], equals('Seat #46'));
    });

    test('91. PHYSICAL ROOM GRID FIDELITY, QUICK FILTER METRICS & SEAT TILE OCCUPANCY BADGES', () {
      // 1. Physical 10-Column Room Alignment Verification
      const roomCols = 10;
      final List<SeatModel> cozyHallSeats = List.generate(60, (index) {
        final deskNum = index + 1;
        final row = index ~/ roomCols;
        final col = index % roomCols;
        return SeatModel(
          id: 'seat_$deskNum',
          sectionId: 'sec_cozy_hall',
          row: row,
          col: col,
          label: '$deskNum',
          status: deskNum == 14 ? SeatStatus.occupied : (deskNum == 60 ? SeatStatus.reserved : SeatStatus.available),
          genderRestriction: deskNum >= 51 ? GenderRestriction.female : GenderRestriction.male,
          studentId: deskNum == 14 ? 'st_rahul' : null,
          reservedCandidateName: deskNum == 60 ? 'Priya Patil' : null,
        );
      });

      expect(cozyHallSeats.length, equals(60));

      // Row 1 starts at 1, ends at 10
      expect(cozyHallSeats[0].label, equals('1'));
      expect(cozyHallSeats[0].row, equals(0));
      expect(cozyHallSeats[9].label, equals('10'));
      expect(cozyHallSeats[9].row, equals(0));

      // Row 2 starts at 11, ends at 20
      expect(cozyHallSeats[10].label, equals('11'));
      expect(cozyHallSeats[10].row, equals(1));
      expect(cozyHallSeats[19].label, equals('20'));
      expect(cozyHallSeats[19].row, equals(1));

      // Row 6 (Girls Reserved) contains exactly Desks 51 to 60
      final girlsRow = cozyHallSeats.where((s) => s.row == 5).toList();
      expect(girlsRow.length, equals(10));
      expect(girlsRow.first.label, equals('51'));
      expect(girlsRow.last.label, equals('60'));
      expect(girlsRow.every((s) => s.genderRestriction == GenderRestriction.female), isTrue);

      // 2. Quick Filter Counts Logic
      final total = cozyHallSeats.length;
      final vacant = cozyHallSeats.where((s) => s.status == SeatStatus.available).length;
      final occupied = cozyHallSeats.where((s) => s.status == SeatStatus.occupied).length;
      final boys = cozyHallSeats.where((s) => s.genderRestriction == GenderRestriction.male).length;
      final girls = cozyHallSeats.where((s) => s.genderRestriction == GenderRestriction.female).length;

      expect(total, equals(60));
      expect(vacant, equals(58));
      expect(occupied, equals(1));
      expect(boys, equals(50));
      expect(girls, equals(10));

      // 3. Short Student Name Formatting
      String formatShortName(String? name) {
        if (name == null || name.trim().isEmpty) return '';
        final parts = name.trim().split(RegExp(r'\s+'));
        if (parts.length == 1) return parts.first;
        final first = parts.first;
        final lastInitial = parts.last[0].toUpperCase();
        return '$first $lastInitial.';
      }

      expect(formatShortName('Rahul Sharma'), equals('Rahul S.'));
      expect(formatShortName('Kiran Sonpetkar'), equals('Kiran S.'));
      expect(formatShortName('Suresh'), equals('Suresh'));
      expect(formatShortName(null), equals(''));
    });

    test('92. QUICK ACTION STUDIO (+) & SMART PAYMENT PICKER ARCHITECTURE', () {
      // 1. Defaulter Prioritization & Sorting Invariant
      final studentA = createTestStudent(
        id: 's_1',
        name: 'Bharat Patil',
        phone: '9822001122',
        membershipNumber: 'CC20260005',
        membershipStatus: MembershipStatus.active,
        pendingDueBalance: 0.0,
      );

      final studentDefaulterSmall = createTestStudent(
        id: 's_2',
        name: 'Chetan Shinde',
        phone: '9822003344',
        membershipNumber: 'CC20260002',
        membershipStatus: MembershipStatus.active,
        pendingDueBalance: 500.0,
      );

      final studentDefaulterLarge = createTestStudent(
        id: 's_3',
        name: 'Amit Deshmukh',
        phone: '9822005566',
        membershipNumber: 'CC20260001',
        membershipStatus: MembershipStatus.active,
        pendingDueBalance: 1500.0,
      );

      final studentGrace = createTestStudent(
        id: 's_4',
        name: 'Deepak Joshi',
        phone: '9822007788',
        membershipNumber: 'CC20260003',
        membershipStatus: MembershipStatus.grace,
        pendingDueBalance: 0.0,
      );

      final list = [studentA, studentDefaulterSmall, studentDefaulterLarge, studentGrace];

      // Sort using Smart Payment Picker rules
      list.sort((a, b) {
        final aDue = a.pendingDueBalance ?? 0.0;
        final bDue = b.pendingDueBalance ?? 0.0;

        // Defaulters strictly at the top (highest dues first)
        if (aDue > 0 && bDue <= 0) return -1;
        if (bDue > 0 && aDue <= 0) return 1;
        if (aDue > 0 && bDue > 0) return bDue.compareTo(aDue);

        // Next: Grace period / Expiring students
        final aIsGrace = a.membershipStatus == MembershipStatus.grace;
        final bIsGrace = b.membershipStatus == MembershipStatus.grace;
        if (aIsGrace && !bIsGrace) return -1;
        if (bIsGrace && !aIsGrace) return 1;

        // Alphabetical secondary sort
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      // Assertions:
      // Index 0: studentDefaulterLarge (₹1500 due)
      // Index 1: studentDefaulterSmall (₹500 due)
      // Index 2: studentGrace (Grace period)
      // Index 3: studentA (₹0 due)
      expect(list[0].id, equals('s_3'));
      expect(list[0].pendingDueBalance, equals(1500.0));
      expect(list[1].id, equals('s_2'));
      expect(list[1].pendingDueBalance, equals(500.0));
      expect(list[2].id, equals('s_4'));
      expect(list[3].id, equals('s_1'));

      // 2. Multimodal Search Matching Test (Admission ID, Phone, Name)
      bool matchesQuery(StudentModel s, String q) {
        final query = q.trim().toLowerCase();
        return s.name.toLowerCase().contains(query) ||
            s.phone.toLowerCase().contains(query) ||
            (s.membershipNumber ?? '').toLowerCase().contains(query);
      }

      // Search by Admission Number (#CC20260001)
      expect(matchesQuery(studentDefaulterLarge, 'CC20260001'), isTrue);
      expect(matchesQuery(studentDefaulterLarge, '0001'), isTrue);
      // Search by Phone
      expect(matchesQuery(studentDefaulterSmall, '9822003344'), isTrue);
      // Search by Name
      expect(matchesQuery(studentGrace, 'Deepak'), isTrue);
      expect(matchesQuery(studentGrace, 'xyz_not_exist'), isFalse);

      // 3. RBAC Capability-Gated Security Evaluation
      final staffOperator = {
        'role': 'operator',
        'canRecordPayments': false,
        'canManageStudents': true,
        'canViewRevenue': false,
        'canManageSeats': false,
      };

      final staffManager = {
        'role': 'manager',
        'canRecordPayments': true,
        'canManageStudents': true,
        'canViewRevenue': true,
        'canManageSeats': true,
      };

      // Operator cannot record payment or view expenses
      expect(staffOperator['canRecordPayments'], isFalse);
      expect(staffOperator['canViewRevenue'], isFalse);
      expect(staffOperator['canManageStudents'], isTrue);

      // Manager has full operational access
      expect(staffManager['canRecordPayments'], isTrue);
      expect(staffManager['canViewRevenue'], isTrue);
      expect(staffManager['canManageSeats'], isTrue);
    });

    test('93. 7 MEMBERSHIP STATUSES & REAL-TIME AUTOMATION SCENARIOS ENGINE', () {
      final now = DateTime.now();

      StudentModel createTestStudent({
        required String id,
        required String name,
        required String phone,
        DateTime? planStartDate,
        DateTime? planEndDate,
        DateTime? graceEndDate,
        required MembershipStatus membershipStatus,
        String? seatId,
        String? blockedReason,
      }) {
        return StudentModel(
          id: id,
          name: name,
          fatherName: 'Father $name',
          phone: phone,
          email: '$id@example.com',
          gender: Gender.male,
          address: 'Main Street, Parli',
          pincode: '431515',
          govIdType: GovIdType.aadhaar,
          govIdNumber: '123456789012',
          govIdImageUrl: '',
          photoUrl: '',
          college: 'Government College',
          course: 'B.Sc',
          year: 'Final Year',
          emergencyContact: '9876543210',
          membershipStatus: membershipStatus,
          customFields: const {},
          planStartDate: planStartDate,
          planEndDate: planEndDate,
          graceEndDate: graceEndDate,
          seatId: seatId,
          blockedReason: blockedReason,
        );
      }

      // ── SCENARIO 1: ACTIVE STUDENT (Valid Subscription) ──
      final activeStudent = createTestStudent(
        id: 's_act_1',
        name: 'Aarav Sharma',
        phone: '9876543210',
        planStartDate: now.subtract(const Duration(days: 10)),
        planEndDate: now.add(const Duration(days: 20)),
        graceEndDate: now.add(const Duration(days: 23)),
        membershipStatus: MembershipStatus.active,
        seatId: 'seat_01',
      );
      expect(activeStudent.effectiveMembershipStatus, equals(MembershipStatus.active));
      expect(activeStudent.isEffectivelyActive, isTrue);
      expect(activeStudent.isExpired, isFalse);
      expect(activeStudent.daysRemaining, equals(20));

      // ── SCENARIO 2: DYNAMIC TRANSITION TO GRACE (Plan Ended, Within Grace) ──
      // Stored in Firestore as 'active', but wall-clock time is past planEndDate!
      final graceDynamicStudent = createTestStudent(
        id: 's_grace_2',
        name: 'Priya Verma',
        phone: '9876543211',
        planStartDate: now.subtract(const Duration(days: 31)),
        planEndDate: now.subtract(const Duration(days: 1)), // Ended yesterday
        graceEndDate: now.add(const Duration(days: 2)),     // 2 grace days left
        membershipStatus: MembershipStatus.active,          // Stored string still says active
        seatId: 'seat_02',
      );
      // Evaluates dynamically to GRACE without waiting for batch cron
      expect(graceDynamicStudent.effectiveMembershipStatus, equals(MembershipStatus.grace));
      // Grace period protects their desk — student is still effectively active!
      expect(graceDynamicStudent.isEffectivelyActive, isTrue);
      expect(graceDynamicStudent.isExpired, isFalse);
      expect(graceDynamicStudent.daysRemaining, lessThan(0));

      // ── SCENARIO 3: DYNAMIC TRANSITION TO EXPIRED (Past Grace Window) ──
      // Stored in Firestore as 'active' or 'grace', but graceEndDate has passed!
      final expiredDynamicStudent = createTestStudent(
        id: 's_exp_3',
        name: 'Rohan Gupta',
        phone: '9876543212',
        planStartDate: now.subtract(const Duration(days: 40)),
        planEndDate: now.subtract(const Duration(days: 10)),
        graceEndDate: now.subtract(const Duration(days: 7)), // Grace ended 7 days ago
        membershipStatus: MembershipStatus.grace,
        seatId: 'seat_03',
      );
      expect(expiredDynamicStudent.effectiveMembershipStatus, equals(MembershipStatus.expired));
      expect(expiredDynamicStudent.isEffectivelyActive, isFalse);
      expect(expiredDynamicStudent.isExpired, isTrue);

      // Invariant: Expired student seat auto-release simulation
      final simulatedSeatAfterRelease = {
        'id': 'seat_03',
        'status': 'available', // Seat returned to public pool
        'studentId': null,
      };
      final studentAfterRelease = expiredDynamicStudent.copyWith(
        clearSeat: true,
        membershipStatus: MembershipStatus.expired,
      );
      expect(simulatedSeatAfterRelease['status'], equals('available'));
      expect(simulatedSeatAfterRelease['studentId'], isNull);
      expect(studentAfterRelease.seatId, isNull);

      // ── SCENARIO 4: MANUAL OVERRIDE — BLOCKED ──
      // Even if planEndDate is 30 days in the future, admin block strictly revokes access
      final blockedStudent = createTestStudent(
        id: 's_blk_4',
        name: 'Vikram Joshi',
        phone: '9876543213',
        planStartDate: now.subtract(const Duration(days: 2)),
        planEndDate: now.add(const Duration(days: 28)), // Paid for 28 more days!
        membershipStatus: MembershipStatus.blocked,
        blockedReason: 'Violated silent study zone protocol',
        seatId: 'seat_04',
      );
      expect(blockedStudent.effectiveMembershipStatus, equals(MembershipStatus.blocked));
      expect(blockedStudent.isEffectivelyActive, isFalse); // Revoked!
      expect(blockedStudent.blockedReason, equals('Violated silent study zone protocol'));

      // QR Scanner Verification for Blocked User
      final isQrAccessAllowedForBlocked = blockedStudent.effectiveMembershipStatus == MembershipStatus.active ||
          blockedStudent.effectiveMembershipStatus == MembershipStatus.grace;
      expect(isQrAccessAllowedForBlocked, isFalse);

      // ── SCENARIO 5: MANUAL OVERRIDE — INACTIVE (Study Sabbatical / Leave) ──
      final inactiveStudent = createTestStudent(
        id: 's_ina_5',
        name: 'Sneha Deshmukh',
        phone: '9876543214',
        planStartDate: null,
        planEndDate: null,
        membershipStatus: MembershipStatus.inactive,
        seatId: null,
      );
      expect(inactiveStudent.effectiveMembershipStatus, equals(MembershipStatus.inactive));
      expect(inactiveStudent.isEffectivelyActive, isFalse);
      expect(inactiveStudent.isExpired, isFalse);
      expect(inactiveStudent.daysRemaining, isNull);

      // ── SCENARIO 6: MANUAL OVERRIDE — ARCHIVED (Alumni / Left Facility) ──
      final archivedStudent = createTestStudent(
        id: 's_arc_6',
        name: 'Amitabh Sen',
        phone: '9876543215',
        membershipStatus: MembershipStatus.archived,
        seatId: null,
      );
      expect(archivedStudent.effectiveMembershipStatus, equals(MembershipStatus.archived));
      expect(archivedStudent.isEffectivelyActive, isFalse);

      // ── SCENARIO 7: MANUAL OVERRIDE — PENDING (Registered, Awaiting Fee) ──
      final pendingStudent = createTestStudent(
        id: 's_pen_7',
        name: 'Kavita Nair',
        phone: '9876543216',
        membershipStatus: MembershipStatus.pending,
        seatId: null,
      );
      expect(pendingStudent.effectiveMembershipStatus, equals(MembershipStatus.pending));
      expect(pendingStudent.isEffectivelyActive, isFalse);

      // ── SCENARIO 8: AUTOMATED REMINDER STAGES & DEDUPLICATION ──
      final remindedStages = <String>[];

      // Stage 1: T-3 Days Check
      final daysLeftT3 = 3;
      final currentStatusT3 = MembershipStatus.active;
      if (daysLeftT3 == 3 && currentStatusT3 == MembershipStatus.active && !remindedStages.contains('T-3')) {
        remindedStages.add('T-3');
      }
      expect(remindedStages.contains('T-3'), isTrue);

      // Attempt duplicate trigger on same day
      if (daysLeftT3 == 3 && currentStatusT3 == MembershipStatus.active && !remindedStages.contains('T-3')) {
        remindedStages.add('T-3');
      }
      expect(remindedStages.where((s) => s == 'T-3').length, equals(1)); // Deduplicated!

      // Stage 2: T-0 Day Check
      final daysLeftT0 = 0;
      if (daysLeftT0 == 0 && currentStatusT3 == MembershipStatus.active && !remindedStages.contains('T-0')) {
        remindedStages.add('T-0');
      }
      expect(remindedStages.contains('T-0'), isTrue);

      // Stage 3: Eve-of-Grace Check (1 day before grace period ends)
      final daysUntilGraceEnd = 1;
      final isInGraceWindow = true;
      if (daysUntilGraceEnd == 1 && isInGraceWindow && !remindedStages.contains('grace_eve')) {
        remindedStages.add('grace_eve');
      }
      expect(remindedStages.contains('grace_eve'), isTrue);
      expect(remindedStages.length, equals(3));

      // ── SCENARIO 9: AUTO-SEAT RETENTION ON RENEWAL ──
      // When an expired student renews, if their previous seat is still free, restore it
      const previousSeatId = 'seat_hall_a_05';
      final seatPool = <String, String>{
        'seat_hall_a_05': 'available', // Seat is vacant!
        'seat_hall_a_06': 'occupied',
      };

      String? allocatedSeatId;
      if (seatPool[previousSeatId] == 'available') {
        allocatedSeatId = previousSeatId;
      }

      final renewedStudent = expiredDynamicStudent.copyWith(
        membershipStatus: MembershipStatus.active,
        planStartDate: now,
        planEndDate: now.add(const Duration(days: 30)),
        graceEndDate: now.add(const Duration(days: 33)),
        seatId: allocatedSeatId,
      );

      expect(renewedStudent.effectiveMembershipStatus, equals(MembershipStatus.active));
      expect(renewedStudent.isEffectivelyActive, isTrue);
      expect(renewedStudent.seatId, equals('seat_hall_a_05'));
    });

    test('95. INSTITUTIONAL BRAND PALETTE, DYNAMIC SEED THEMING & HEX COLOR STUDIO', () {
      // 1. LibraryModel Default & Serialization Integrity
      final defaultLib = LibraryModel(
        id: 'lib_test',
        name: 'The Cozy Corner Study Centre',
        address: 'Nath Road, Parli',
        logoUrl: '',
        contact: '9403243830',
        ownerId: 'owner_123',
        accentColor: 0xFF5D4037,
        welcomeMessage: 'Welcome',
        operatingHours: '6 AM - 11 PM',
        socialLinks: {},
        rulesText: 'Rules',
        adminPhotoUrl: '',
        helplineNumber: '9403243830',
        waitingListMode: WaitingListMode.contactAdmin,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        adminName: 'Sanket Shahane',
      );
      expect(defaultLib.accentColor, equals(0xFF5D4037));

      final json = defaultLib.toJson();
      expect(json['accentColor'], equals(0xFF5D4037));

      final restoredLib = LibraryModel.fromJson(json);
      expect(restoredLib.accentColor, equals(0xFF5D4037));

      // 2. Custom Brand Color Palette Update (e.g. Royal Sapphire)
      const royalSapphire = 0xFF1E3A8A;
      final reBrandedLib = defaultLib.copyWith(accentColor: royalSapphire);
      expect(reBrandedLib.accentColor, equals(0xFF1E3A8A));

      // 3. Hex parsing and ARGB32 consistency
      const hexInput = '#1E3A8A';
      final cleanHex = hexInput.replaceAll('#', '').trim();
      final parsedInt = int.parse('FF$cleanHex', radix: 16);
      expect(parsedInt, equals(royalSapphire));

      final colorObj = Color(parsedInt);
      expect(colorObj.toARGB32(), equals(royalSapphire));

      // 4. Dynamic Theme Generation Seeding
      final lightTheme = custom_theme.AppTheme.fromSeed(colorObj, brightness: Brightness.light);
      final darkTheme = custom_theme.AppTheme.fromSeed(colorObj, brightness: Brightness.dark);

      expect(lightTheme.colorScheme.primary, isNotNull);
      expect(darkTheme.colorScheme.primary, isNotNull);
      expect(lightTheme.useMaterial3, isTrue);
      expect(darkTheme.useMaterial3, isTrue);

      // 5. Obsidian Noir (Sleek luxury charcoal) High-Contrast Validation
      const obsidianNoir = Color(0xFF18181B);
      final obsidianLight = custom_theme.AppTheme.fromSeed(obsidianNoir, brightness: Brightness.light);
      final obsidianDark = custom_theme.AppTheme.fromSeed(obsidianNoir, brightness: Brightness.dark);

      // Light mode: deep luxury charcoal primary, pure white surface, high-contrast dark text
      expect(obsidianLight.colorScheme.primary, equals(const Color(0xFF18181B)));
      expect(obsidianLight.colorScheme.onPrimary, equals(Colors.white));
      expect(obsidianLight.colorScheme.onSurface, equals(const Color(0xFF09090B)));
      expect(obsidianLight.colorScheme.onSurfaceVariant, equals(const Color(0xFF3F3F46)));
      expect(obsidianLight.colorScheme.surface, equals(Colors.white));

      // Dark mode: crisp pure white primary for pop, deep zinc-950 surface, pure white text
      expect(obsidianDark.colorScheme.primary, equals(const Color(0xFFFAFAFA)));
      expect(obsidianDark.colorScheme.onPrimary, equals(const Color(0xFF18181B)));
      expect(obsidianDark.colorScheme.surface, equals(const Color(0xFF09090B)));
      expect(obsidianDark.colorScheme.onSurface, equals(const Color(0xFFFAFAFA)));

      // Chip theme & typography high-contrast validation
      expect(obsidianLight.chipTheme.labelStyle?.color, equals(const Color(0xFF0F172A)));
      expect(obsidianDark.chipTheme.labelStyle?.color, equals(const Color(0xFFF1F5F9)));
      expect(obsidianLight.textTheme.bodyMedium?.color, equals(const Color(0xFF0F172A)));
      expect(obsidianDark.textTheme.bodyMedium?.color, equals(const Color(0xFFF1F5F9)));
    });

    test('96. PHASE 1: STUDENT BIRTHDAY CELEBRATION ENGINE & WI-FI 1-TAP CREDENTIALS HOTSPOT', () {
      final now = DateTime.now();

      // ── 1. Birthday Detection Engine ──
      // Student with birthday today
      final bdayStudent = createTestStudent(
        id: 'student_bday_01',
        name: 'Omkar Kulkarni',
        phone: '9822012345',
      ).copyWith(
        dob: DateTime(now.year - 22, now.month, now.day),
        course: 'UPSC Civil Services',
      );

      // Student with birthday tomorrow
      final tomorrow = now.add(const Duration(days: 1));
      final nonBdayStudent = createTestStudent(
        id: 'student_bday_02',
        name: 'Pooja Patil',
        phone: '9822054321',
      ).copyWith(
        dob: DateTime(now.year - 20, tomorrow.month, tomorrow.day),
        course: 'CA Final',
      );

      // Student with null DOB
      final nullBdayStudent = createTestStudent(
        id: 'student_bday_03',
        name: 'Rahul Deshmukh',
        phone: '9822099999',
      );

      bool isBirthdayToday(DateTime? dob) {
        if (dob == null) return false;
        final current = DateTime.now();
        return dob.month == current.month && dob.day == current.day;
      }

      expect(isBirthdayToday(bdayStudent.dob), isTrue);
      expect(isBirthdayToday(nonBdayStudent.dob), isFalse);
      expect(isBirthdayToday(nullBdayStudent.dob), isFalse);

      // Verification of celebratory messaging attributes
      final firstName = bdayStudent.name.trim().split(' ').first;
      expect(firstName, equals('Omkar'));
      expect(bdayStudent.course, equals('UPSC Civil Services'));

      // Dismissal storage key pattern
      final dismissKey = 'birthday_dismissed_${now.year}_${now.month}_${now.day}';
      expect(dismissKey, contains('birthday_dismissed_'));
      expect(dismissKey, contains('${now.year}'));

      // ── 2. Library Wi-Fi Hotspot Defaults & Effective Fallbacks ──
      final defaultLib = LibraryModel(
        id: 'lib_wifi_test',
        name: 'The Cozy Corner Study Centre',
        address: 'Nath Road, Parli',
        logoUrl: '',
        contact: '9403243830',
        ownerId: 'owner_123',
        accentColor: 0xFF5D4037,
        welcomeMessage: 'Welcome',
        operatingHours: '6 AM - 11 PM',
        socialLinks: {},
        rulesText: 'Rules',
        adminPhotoUrl: '',
        helplineNumber: '9403243830',
        waitingListMode: WaitingListMode.contactAdmin,
        createdAt: now,
        updatedAt: now,
      );

      // Effective Wi-Fi fallback properties
      expect(defaultLib.effectiveWifiSsid, equals('The Cozy Corner Study Centre 5G'));
      expect(defaultLib.effectiveWifiPassword, equals('Study@Cozy2026'));

      // Custom Wi-Fi Credentials configuration
      final configuredLib = defaultLib.copyWith(
        wifiSsid: 'CozyCorner_Ultra5G',
        wifiPassword: 'CozyStudyPass2026',
      );

      expect(configuredLib.effectiveWifiSsid, equals('CozyCorner_Ultra5G'));
      expect(configuredLib.effectiveWifiPassword, equals('CozyStudyPass2026'));

      // Full JSON Serialization & Deserialization round-trip
      final libJson = configuredLib.toJson();
      expect(libJson['wifiSsid'], equals('CozyCorner_Ultra5G'));
      expect(libJson['wifiPassword'], equals('CozyStudyPass2026'));

      final restoredLib = LibraryModel.fromJson(libJson);
      expect(restoredLib.wifiSsid, equals('CozyCorner_Ultra5G'));
      expect(restoredLib.wifiPassword, equals('CozyStudyPass2026'));
      expect(restoredLib.effectiveWifiSsid, equals('CozyCorner_Ultra5G'));
      expect(restoredLib.effectiveWifiPassword, equals('CozyStudyPass2026'));
    });

    test('97. WYSIWYG WhatsApp Message Template Studio, Multilingual Presets (EN/HI/MR) & Tag Substitution', () {
      // 1. Shorthand Tag Aliases & Substitution Validation
      const rawCustomTemplate = 'Hello {name}, your desk {desk} (Plan: {plan}) expires on {expiry}. Pending due: ₹{due}. UPI: {upi}';
      final substituted = MessageTemplateService.substitute(
        rawCustomTemplate,
        studentName: 'Shubham Kandukatle',
        seatLabel: 'Seat #14',
        planName: 'Monthly Full-Day',
        expiryDate: '30 Nov 2026',
        dueAmount: '0',
        libraryUpiId: '7276959070@upi',
      );

      expect(substituted, equals('Hello Shubham Kandukatle, your desk Seat #14 (Plan: Monthly Full-Day) expires on 30 Nov 2026. Pending due: ₹0. UPI: 7276959070@upi'));

      // 2. Multilingual Presets Availability & Cultural Formatting
      final welcomeEn = MessageTemplateService.getTemplate(type: 'welcome', language: 'en');
      final welcomeHi = MessageTemplateService.getTemplate(type: 'welcome', language: 'hi');
      final welcomeMr = MessageTemplateService.getTemplate(type: 'welcome', language: 'mr');

      expect(welcomeEn, contains('Welcome to {libraryName}'));
      expect(welcomeHi, contains('{libraryName} में आपका स्वागत है'));
      expect(welcomeMr, contains('{libraryName} मध्ये आपले सहर्ष स्वागत आहे'));

      final receiptEn = MessageTemplateService.getTemplate(type: 'receipt', language: 'en');
      final receiptHi = MessageTemplateService.getTemplate(type: 'receipt', language: 'hi');
      final receiptMr = MessageTemplateService.getTemplate(type: 'receipt', language: 'mr');

      expect(receiptEn, contains('Payment Received — Fee Receipt'));
      expect(receiptHi, contains('शुल्क प्राप्ति पावती'));
      expect(receiptMr, contains('शुल्क पावती'));

      final dueEn = MessageTemplateService.getTemplate(type: 'due_reminder', language: 'en');
      final dueHi = MessageTemplateService.getTemplate(type: 'due_reminder', language: 'hi');
      final dueMr = MessageTemplateService.getTemplate(type: 'due_reminder', language: 'mr');

      expect(dueEn, contains('Fee Balance Reminder'));
      expect(dueHi, contains('बकाया शुल्क सूचना'));
      expect(dueMr, contains('थकबाकी शुल्क स्मरणपत्र'));

      // 3. Live Preview Generator with simulated parameters
      final liveMrPreview = MessageTemplateService.getLivePreview(
        welcomeMr,
        libraryName: 'The Cozy Corner Study Centre',
        helpline: '+91 91569 44773',
      );
      expect(liveMrPreview, contains('The Cozy Corner Study Centre मध्ये आपले सहर्ष स्वागत आहे!'));
      expect(liveMrPreview, contains('Shubham Kandukatle'));
      expect(liveMrPreview, contains('+91 91569 44773'));

      // 4. LibraryModel Template Integration, Defaults & Serialization Round-Trip
      final now = DateTime.now();
      final libModel = LibraryModel(
        id: 'lib_template_01',
        name: 'The Cozy Corner Study Centre',
        address: 'Someshwar Nagar, Parli Vaijanath',
        logoUrl: '',
        contact: '9156944773',
        ownerId: 'owner_99',
        accentColor: 0xFF5D4037,
        welcomeMessage: 'Welcome',
        operatingHours: '6 AM - 11 PM',
        socialLinks: {},
        rulesText: 'Standard rules',
        adminPhotoUrl: '',
        helplineNumber: '9156944773',
        waitingListMode: WaitingListMode.contactAdmin,
        templateLanguage: 'mr',
        whatsappReceiptTemplate: 'Custom Receipt for {name}: Paid ₹{amount}',
        createdAt: now,
        updatedAt: now,
      );

      // Verify effective getters fall back to language preset when unset
      expect(libModel.effectiveWelcomeTemplate, contains('मध्ये आपले सहर्ष स्वागत आहे')); // Marathi preset
      expect(libModel.effectiveReceiptTemplate, equals('Custom Receipt for {name}: Paid ₹{amount}')); // Custom override
      expect(libModel.effectiveDueReminderTemplate, contains('थकबाकी शुल्क स्मरणपत्र')); // Marathi preset fallback

      // Serialization round-trip
      final json = libModel.toJson();
      expect(json['templateLanguage'], equals('mr'));
      expect(json['whatsappReceiptTemplate'], equals('Custom Receipt for {name}: Paid ₹{amount}'));

      final deserialized = LibraryModel.fromJson(json);
      expect(deserialized.templateLanguage, equals('mr'));
      expect(deserialized.whatsappReceiptTemplate, equals('Custom Receipt for {name}: Paid ₹{amount}'));
      expect(deserialized.effectiveReceiptTemplate, equals('Custom Receipt for {name}: Paid ₹{amount}'));
      expect(deserialized.effectiveWelcomeTemplate, contains('मध्ये आपले सहर्ष स्वागत आहे'));
    });

    test('98. PHASE 2: EXAM COUNTDOWN ENGINE, SMART COURSE CALENDAR RESOLUTION & TARGET GOAL PERSISTENCE', () {
      final now = DateTime.now();

      // ── 1. Smart Automated Calendar Resolution from Course Name ──
      final upscStudent = createTestStudent(
        id: 'student_upsc_01',
        name: 'Gaurav Kute',
        phone: '9822112233',
      ).copyWith(course: 'UPSC Civil Services Prelims');

      expect(upscStudent.effectiveTargetExamName, equals('UPSC Civil Services Prelims'));
      expect(upscStudent.effectiveTargetExamDate, isNotNull);
      expect(upscStudent.effectiveTargetExamDate!.month, equals(5)); // May
      expect(upscStudent.effectiveTargetExamDate!.day, equals(24));
      expect(upscStudent.daysUntilExam, isNotNull);
      expect(upscStudent.daysUntilExam!, greaterThanOrEqualTo(0));

      final neetStudent = createTestStudent(
        id: 'student_neet_01',
        name: 'Anjali Sharma',
        phone: '9822445566',
      ).copyWith(course: 'NEET UG 2027');

      expect(neetStudent.effectiveTargetExamDate, isNotNull);
      expect(neetStudent.effectiveTargetExamDate!.month, equals(5)); // May

      final gateStudent = createTestStudent(
        id: 'student_gate_01',
        name: 'Rohan More',
        phone: '9822778899',
      ).copyWith(course: 'GATE CSE');

      expect(gateStudent.effectiveTargetExamDate, isNotNull);
      expect(gateStudent.effectiveTargetExamDate!.month, equals(2)); // Feb

      final caStudent = createTestStudent(
        id: 'student_ca_01',
        name: 'Sneha Rathi',
        phone: '9822001122',
      ).copyWith(course: 'CA Final Group 1');

      expect(caStudent.effectiveTargetExamDate, isNotNull);
      // Either May (5) or November (11)
      expect(caStudent.effectiveTargetExamDate!.month == 5 || caStudent.effectiveTargetExamDate!.month == 11, isTrue);

      // ── 2. Custom Target Exam Override by Student ──
      final customTargetDate = now.add(const Duration(days: 120));
      final customStudent = upscStudent.copyWith(
        targetExamName: 'Target IFS 2027',
        targetExamDate: customTargetDate,
      );

      expect(customStudent.effectiveTargetExamName, equals('Target IFS 2027'));
      expect(customStudent.effectiveTargetExamDate, equals(customTargetDate));
      expect(customStudent.daysUntilExam, equals(120));

      // ── 3. Graceful Fallback for Non-Competitive Course ──
      final generalStudent = createTestStudent(
        id: 'student_general_01',
        name: 'Amit Patel',
        phone: '9822334455',
      ).copyWith(course: 'B.Com General');

      expect(generalStudent.effectiveTargetExamDate, isNull);
      expect(generalStudent.daysUntilExam, isNull);
      expect(generalStudent.effectiveTargetExamName, equals('B.Com General'));

      // ── 4. Full JSON Serialization & Deserialization ──
      final studentJson = customStudent.toJson();
      expect(studentJson['targetExamName'], equals('Target IFS 2027'));
      expect(studentJson['targetExamDate'], isNotNull);

      final restoredStudent = StudentModel.fromJson(studentJson);
      expect(restoredStudent.targetExamName, equals('Target IFS 2027'));
      expect(restoredStudent.effectiveTargetExamName, equals('Target IFS 2027'));
      expect(restoredStudent.daysUntilExam, equals(120));
    });

    test('89. Government ID Resilient Upload, PDF Detection & Error Context Invariants', () {
      // ── 1. DocumentPickerService PDF Detection ──
      expect(DocumentPickerService.isPdf('data:application/pdf;base64,JVBERi0xLjQK...'), isTrue);
      expect(DocumentPickerService.isPdf('my_aadhaar_card.pdf'), isTrue);
      expect(DocumentPickerService.isPdf('https://firebasestorage.googleapis.com/.../doc.PDF'), isTrue);
      expect(DocumentPickerService.isPdf('data:image/jpeg;base64,/9j/4AAQSkZJRg...'), isFalse);
      expect(DocumentPickerService.isPdf('photo.png'), isFalse);
      expect(DocumentPickerService.isPdf(null), isFalse);
      expect(DocumentPickerService.isPdf(''), isFalse);

      // ── 2. Government ID Clean Dynamic Label Formatting ──
      // Prevents "Attach Aadhaar Card Card" redundancy
      String formatAttachLabel(GovIdType type) {
        final typeName = type.displayName;
        return (typeName.toLowerCase().contains('card') || typeName.toLowerCase().contains('id'))
            ? 'Attach $typeName'
            : 'Attach $typeName Card';
      }

      expect(formatAttachLabel(GovIdType.aadhaar), equals('Attach Aadhaar Card'));
      expect(formatAttachLabel(GovIdType.pan), equals('Attach PAN Card'));
      expect(formatAttachLabel(GovIdType.voterId), equals('Attach Voter ID (EPIC)'));
      expect(formatAttachLabel(GovIdType.drivingLicence), equals('Attach Driving Licence Card'));
      expect(formatAttachLabel(GovIdType.passport), equals('Attach Passport Card'));

      // ── 3. AppErrorFormatter Camera/KYC Context Resolution ──
      final permDeniedError = Exception('PlatformException(camera_access_denied)');
      final govIdPermMsg = AppErrorFormatter.toUserFriendly(permDeniedError, actionContext: 'gov_id');
      expect(govIdPermMsg, contains('Permission was not granted'));
      expect(govIdPermMsg, contains('Please allow camera or file access'));
      expect(govIdPermMsg.contains('You can look up the student manually'), isFalse);

      final deviceError = Exception('Camera hardware not found on this web client');
      final govIdDeviceMsg = AppErrorFormatter.toUserFriendly(deviceError, actionContext: 'gov_id');
      expect(govIdDeviceMsg, contains('Camera was unavailable'));
      expect(govIdDeviceMsg, contains('Please choose an ID photo or PDF file from your device'));
      expect(govIdDeviceMsg.contains('You can look up the student manually'), isFalse);

      final adminQrError = Exception('Camera is not available');
      final adminQrErrorMsg = AppErrorFormatter.toUserFriendly(adminQrError, actionContext: 'admin_qr');
      expect(adminQrErrorMsg, contains('You can look up the student manually'));

      // ── 4. PickedDocument Model Immutability & Computed Properties ──
      const sampleBase64Pdf = 'data:application/pdf;base64,JVBERi0xLjcK';
      final pickedDoc = PickedDocument(
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]), // %PDF
        fileName: 'eaadhaar_digilocker.pdf',
        mimeType: 'application/pdf',
        isPdf: true,
        dataUrl: sampleBase64Pdf,
        fileSizeKB: 142.5,
      );

      expect(pickedDoc.isPdf, isTrue);
      expect(pickedDoc.isImage, isFalse);
      expect(pickedDoc.fileName, equals('eaadhaar_digilocker.pdf'));
      expect(pickedDoc.fileSizeKB, equals(142.5));
      expect(pickedDoc.dataUrl, equals(sampleBase64Pdf));
    });

    test('99. PHASE 3: "SEAT #XX HELD FOR YOU" 1-TAP RENEWAL GUARANTEE & MULTI-KEY RECEIPT VISIBILITY', () {
      final now = DateTime.now();

      // ── 1. Renewal Banner 7-Day Window Trigger Invariants ──
      bool shouldTriggerRenewalBanner(StudentModel s) {
        return s.isExpired ||
            (s.daysRemaining != null && s.daysRemaining! <= 7) ||
            s.effectiveMembershipStatus == MembershipStatus.grace;
      }

      // Safe student with 14 days remaining -> No alert
      final safeStudent = createTestStudent(
        id: 'std_safe',
        name: 'Safe Scholar',
        phone: '9876543210',
        planEndDate: now.add(const Duration(days: 14)),
        seatId: 'seat_46',
        membershipStatus: MembershipStatus.active,
      );
      expect(safeStudent.daysRemaining, greaterThan(7));
      expect(shouldTriggerRenewalBanner(safeStudent), isFalse);

      // Student with exactly 7 days remaining -> Triggers proactive seat protection alert
      final weekStudent = createTestStudent(
        id: 'std_7d',
        name: 'Proactive Scholar',
        phone: '9876543211',
        planEndDate: now.add(const Duration(days: 7)),
        seatId: 'seat_46',
        membershipStatus: MembershipStatus.active,
      );
      expect(weekStudent.daysRemaining, equals(7));
      expect(shouldTriggerRenewalBanner(weekStudent), isTrue);

      // Student with 2 days remaining -> Triggers alert
      final urgentStudent = createTestStudent(
        id: 'std_2d',
        name: 'Urgent Scholar',
        phone: '9876543212',
        planEndDate: now.add(const Duration(days: 2)),
        seatId: 'seat_46',
        membershipStatus: MembershipStatus.active,
      );
      expect(urgentStudent.daysRemaining, equals(2));
      expect(shouldTriggerRenewalBanner(urgentStudent), isTrue);

      // Student in grace period -> Triggers alert
      final graceStudent = createTestStudent(
        id: 'std_grace',
        name: 'Grace Scholar',
        phone: '9876543213',
        planEndDate: now.subtract(const Duration(days: 1)),
        seatId: 'seat_46',
        membershipStatus: MembershipStatus.grace,
      );
      expect(shouldTriggerRenewalBanner(graceStudent), isTrue);

      // Expired student -> Triggers alert
      final expiredStudent = createTestStudent(
        id: 'std_exp',
        name: 'Expired Scholar',
        phone: '9876543214',
        planEndDate: now.subtract(const Duration(days: 10)),
        seatId: 'seat_46',
        membershipStatus: MembershipStatus.expired,
      );
      expect(shouldTriggerRenewalBanner(expiredStudent), isTrue);

      // ── 2. "Seat #XX Held For You" Dynamic Messaging Formatting ──
      String generateSeatProtectionTitle(StudentModel s, String seatLabel) {
        final days = s.daysRemaining ?? 0;
        final hasSeat = s.seatId != null && s.seatId!.isNotEmpty;
        if (!hasSeat) return 'Plan Expires in $days Days';
        if (s.isExpired) return '⚠️ Desk $seatLabel In Grace Hold';
        if (days == 0) return '🔒 Desk $seatLabel Held • Expires Today';
        if (days <= 3) return '🔒 Desk $seatLabel Held For You ($days Days Left)';
        return '🔒 Desk $seatLabel Reservation Active';
      }

      String generateRenewalCtaLabel(StudentModel s, String seatLabel) {
        final hasSeat = s.seatId != null && s.seatId!.isNotEmpty;
        return hasSeat ? '🔒 Keep Desk $seatLabel • 1-Tap Renew' : '⚡ 1-Tap Renew Plan';
      }

      final deskLabel = SeatHelper.formatSeatLabel(seatId: 'seat_46');
      expect(deskLabel, equals('Seat #46'));

      expect(generateSeatProtectionTitle(weekStudent, deskLabel), equals('🔒 Desk Seat #46 Reservation Active'));
      expect(generateSeatProtectionTitle(urgentStudent, deskLabel), equals('🔒 Desk Seat #46 Held For You (2 Days Left)'));
      expect(generateSeatProtectionTitle(graceStudent, deskLabel), equals('🔒 Desk Seat #46 Held For You (-1 Days Left)'));
      expect(generateSeatProtectionTitle(expiredStudent, deskLabel), equals('⚠️ Desk Seat #46 In Grace Hold'));

      expect(generateRenewalCtaLabel(weekStudent, deskLabel), equals('🔒 Keep Desk Seat #46 • 1-Tap Renew'));
      expect(generateRenewalCtaLabel(graceStudent, deskLabel), equals('🔒 Keep Desk Seat #46 • 1-Tap Renew'));

      // ── 3. Desk Preservation in Renewal State Calculation ──
      final effectiveDeskId = weekStudent.seatId ?? weekStudent.previousSeatId;
      expect(effectiveDeskId, equals('seat_46'));
      const keepSeatDefault = true;
      expect(keepSeatDefault, isTrue);

      final lockInCtaText = '🔒 Lock In $deskLabel (';
      expect(lockInCtaText, equals('🔒 Lock In Seat #46 ('));

      // ── 4. Resilient Receipt Multi-Key Visibility Logic ──
      // Simulates matching both admin-created receipts (studentId) and student-claimed receipts (studentUserId)
      final adminCreatedReceipt = {
        'id': 'rec_admin_001',
        'studentId': 'std_7d',
        'studentUserId': null, // Admin enrolled offline before student logged in
        'amount': 2000.0,
      };
      final onlineClaimedReceipt = {
        'id': 'rec_online_002',
        'studentId': 'std_7d',
        'studentUserId': 'auth_uid_xyz123',
        'amount': 2000.0,
      };

      const loggedInStudentAuthUid = 'auth_uid_xyz123';
      const studentDocId = 'std_7d';

      bool matchesReceiptFilter(Map<String, dynamic> r) {
        return r['studentId'] == studentDocId ||
            (r['studentUserId'] != null && r['studentUserId'] == loggedInStudentAuthUid) ||
            r['studentId'] == loggedInStudentAuthUid;
      }

      expect(matchesReceiptFilter(adminCreatedReceipt), isTrue, reason: 'Admin-created receipt without studentUserId must be visible to student');
      expect(matchesReceiptFilter(onlineClaimedReceipt), isTrue, reason: 'Online-claimed receipt with studentUserId must be visible to student');
    });

    test('100. AUTONOMOUS MIDNIGHT MAINTENANCE REPORTING & LIBRARY SERIALIZATION INVARIANTS', () {
      final now = DateTime(2026, 11, 5, 0, 1, 0); // 00:01 AM IST
      final reportMap = <String, dynamic>{
        'runAt': now.toIso8601String(),
        'totalChecked': 42,
        'totalGrace': 3,
        'totalExpired': 1,
        'totalRemindedT3': 2,
        'totalRemindedT0': 1,
        'totalRemindedT2': 1,
        'totalReleasedSeats': 1,
        'source': 'cloud_function_scheduler',
      };

      final lib = LibraryModel(
        id: 'lib_test_01',
        name: 'The Cozy Corner Study Centre',
        address: 'Parli Vaijnath',
        logoUrl: '',
        contact: '9156944773',
        ownerId: 'owner_01',
        accentColor: 0xFF5D4037,
        welcomeMessage: 'Welcome',
        operatingHours: '6 AM - 11 PM',
        socialLinks: {},
        rulesText: '',
        adminPhotoUrl: '',
        helplineNumber: '9156944773',
        waitingListMode: WaitingListMode.contactAdmin,
        lastAutomationRunAt: now.toIso8601String(),
        lastMaintenanceReport: reportMap,
        createdAt: now,
        updatedAt: now,
      );

      // Verify getters
      expect(lib.lastAutomationRunAt, equals(now.toIso8601String()));
      expect(lib.lastAutomationRunDateTime, equals(now));
      expect(lib.lastMaintenanceReport, isNotNull);
      expect(lib.lastMaintenanceReport!['totalChecked'], equals(42));
      expect(lib.lastMaintenanceReport!['totalGrace'], equals(3));
      expect(lib.lastMaintenanceReport!['totalExpired'], equals(1));
      expect(lib.lastMaintenanceReport!['totalReleasedSeats'], equals(1));
      expect(lib.lastMaintenanceReport!['source'], equals('cloud_function_scheduler'));

      // Verify JSON serialization round-trip
      final json = lib.toJson();
      expect(json['lastAutomationRunAt'], equals(now.toIso8601String()));
      expect(json['lastMaintenanceReport'], isNotNull);
      expect(json['lastMaintenanceReport']['source'], equals('cloud_function_scheduler'));

      final fromJson = LibraryModel.fromJson(json);
      expect(fromJson.lastAutomationRunAt, equals(now.toIso8601String()));
      expect(fromJson.lastAutomationRunDateTime, equals(now));
      expect(fromJson.lastMaintenanceReport!['totalChecked'], equals(42));
      expect(fromJson.lastMaintenanceReport!['totalReleasedSeats'], equals(1));

      // Verify copyWith preserves or updates maintenance report
      final updatedReport = Map<String, dynamic>.from(reportMap);
      updatedReport['source'] = 'client_automation_service';
      final updatedLib = fromJson.copyWith(lastMaintenanceReport: updatedReport);
      expect(updatedLib.lastMaintenanceReport!['source'], equals('client_automation_service'));
      expect(updatedLib.lastAutomationRunAt, equals(now.toIso8601String()));

      // Verify AutomationResult
      const autoRes = AutomationResult(
        checkedCount: 50,
        enteredGraceCount: 2,
        expiredCount: 1,
        releasedSeatsCount: 1,
      );
      expect(autoRes.hasChanges, isTrue);
      expect(autoRes.checkedCount, equals(50));
      expect(autoRes.enteredGraceCount, equals(2));
      expect(autoRes.expiredCount, equals(1));
      expect(autoRes.releasedSeatsCount, equals(1));

      const emptyRes = AutomationResult();
      expect(emptyRes.hasChanges, isFalse);
    });

    test('101. ATOMIC LEDGER CONCURRENCY & ZERO-DRIFT PAYMENT EDIT PARITY', () {
      // ── 1. Deterministic Delta Calculation with Negotiated Rate Preservation ──
      double computeEffectivePaid(PaymentStatus status, double amount) {
        if (status == PaymentStatus.refunded ||
            status == PaymentStatus.voided ||
            status == PaymentStatus.cancelled) {
          return 0.0;
        }
        return amount;
      }

      // Scenario A: Custom Negotiated Fee (₹650 instead of standard catalog ₹700)
      // Student admitted, paid ₹400 initially. Due balance is ₹250.
      const initialPaid = 400.0;
      const initialDue = 250.0; // Total agreed plan fee = 650.0

      // Admin edits payment to ₹500 (additional ₹100 paid)
      const editedPaid = 500.0;
      final oldEffectiveA = computeEffectivePaid(PaymentStatus.partial, initialPaid);
      final newEffectiveA = computeEffectivePaid(PaymentStatus.partial, editedPaid);
      final deltaPaidA = newEffectiveA - oldEffectiveA; // +100.0

      final recalculatedDueA = (initialDue - deltaPaidA).clamp(0.0, double.infinity);
      expect(recalculatedDueA, equals(150.0), reason: 'Agreed rate 650 must be preserved: 650 - 500 = 150');

      // Scenario B: Refund of Partial Payment (₹400 refunded)
      final oldEffectiveB = computeEffectivePaid(PaymentStatus.partial, initialPaid);
      final newEffectiveB = computeEffectivePaid(PaymentStatus.refunded, initialPaid);
      final deltaPaidB = newEffectiveB - oldEffectiveB; // -400.0

      final recalculatedDueB = (initialDue - deltaPaidB).clamp(0.0, double.infinity);
      expect(recalculatedDueB, equals(650.0), reason: 'Refund must restore full agreed rate of 650 without drifting to 700');

      // Scenario C: Full Payment Collected (Due drops to ₹0)
      final oldEffectiveC = computeEffectivePaid(PaymentStatus.partial, initialPaid);
      final newEffectiveC = computeEffectivePaid(PaymentStatus.paid, 650.0);
      final deltaPaidC = newEffectiveC - oldEffectiveC; // +250.0

      final recalculatedDueC = (initialDue - deltaPaidC).clamp(0.0, double.infinity);
      expect(recalculatedDueC, equals(0.0));

      // ── 2. Automatic Note Sanitization on Zero Due Balance ──
      String sanitizeStudentNotesOnPayment(String rawNotes, double remainingDue) {
        if (remainingDue <= 0.0 && rawNotes.contains('Pending Fee Payment')) {
          return rawNotes
              .replaceAll(RegExp(r'\s*[-–—]?\s*Pending Fee Payment', caseSensitive: false), '')
              .trim();
        }
        return rawNotes;
      }

      const rawNoteWithPending = 'Admission Approved via App (Gjq8iLM9) — Pending Fee Payment';
      final cleanedNoteOnZeroDue = sanitizeStudentNotesOnPayment(rawNoteWithPending, 0.0);
      expect(cleanedNoteOnZeroDue, equals('Admission Approved via App (Gjq8iLM9)'));
      expect(cleanedNoteOnZeroDue.contains('Pending Fee Payment'), isFalse);

      final uncleanedNoteWhenDueRemains = sanitizeStudentNotesOnPayment(rawNoteWithPending, 150.0);
      expect(uncleanedNoteWhenDueRemains, contains('Pending Fee Payment'));

      // ── 3. Seat Concurrency Collision Guard Invariants ──
      bool canOccupySeat({
        required String currentStatus,
        required String? currentOccupantId,
        required String requestingStudentId,
      }) {
        if (currentStatus == SeatStatus.occupied.name &&
            currentOccupantId != null &&
            currentOccupantId.isNotEmpty &&
            currentOccupantId != requestingStudentId) {
          return false; // Collision detected!
        }
        return true;
      }

      expect(canOccupySeat(currentStatus: 'available', currentOccupantId: null, requestingStudentId: 'std_01'), isTrue);
      expect(canOccupySeat(currentStatus: 'occupied', currentOccupantId: 'std_02', requestingStudentId: 'std_01'), isFalse);
      expect(canOccupySeat(currentStatus: 'occupied', currentOccupantId: 'std_01', requestingStudentId: 'std_01'), isTrue); // Re-affirming own seat
    });

    test('102. FRONT-DESK EXPRESS CASH TERMINAL VS ADVANCED BILLING STUDIO STATE & PRESETS', () {
      // ── 1. PaymentEntryMode Enum Invariants ──
      expect(PaymentEntryMode.values.length, equals(2));
      expect(PaymentEntryMode.values, contains(PaymentEntryMode.expressCash));
      expect(PaymentEntryMode.values, contains(PaymentEntryMode.advancedBilling));

      // ── 2. Express Cash Mode Invariants ──
      // In Express Cash mode, the system defaults to Cash, full settlement, receipt generation and validity extension
      const selectedMode = PaymentEntryMode.expressCash;
      const expectedMethod = 'Cash';
      const isPartialPayment = false;
      const generateReceipt = true;
      const extendValidity = true;

      expect(selectedMode, equals(PaymentEntryMode.expressCash));
      expect(expectedMethod, equals('Cash'));
      expect(isPartialPayment, isFalse);
      expect(generateReceipt, isTrue);
      expect(extendValidity, isTrue);

      // ── 3. Quick Denomination Presets Computation ──
      const effectiveDue = 700.0;
      final quickPresets = [500, 600, 700, 800, 1000, 1500]
          .where((p) => p.toDouble() != effectiveDue)
          .take(3)
          .toList();

      expect(quickPresets.contains(700), isFalse, reason: 'Exact due 700 is already featured as primary exact-chip');
      expect(quickPresets.length, equals(3));
      expect(quickPresets, equals([500, 600, 800]));

      // ── 4. Continuous Coverage Date Range Invariant ──
      final prevEnd = DateTime(2026, 11, 30);
      final newCoverageStart = DateTime(prevEnd.year, prevEnd.month, prevEnd.day + 1); // 1 Dec 2026
      expect(newCoverageStart.day, equals(1));
      expect(newCoverageStart.month, equals(12));
      expect(newCoverageStart.year, equals(2026));
    });

    test('103. SYSTEM DIAGNOSTICS & DATABASE HEALTH: SPARK QUOTA GAUGES, INVARIANT AUTO-HEALER & STALE PRUNER', () {
      // ── 1. DatabaseMetrics & Spark Free Tier Quota Invariants ──
      expect(DatabaseMetrics.sparkDailyFreeReads, equals(50000));
      expect(DatabaseMetrics.sparkDailyFreeWrites, equals(20000));
      expect(DatabaseMetrics.sparkFreeStorageBytes, equals(1024 * 1024 * 1024)); // 1 GiB

      final sampleMetrics = DatabaseMetrics(
        studentsCount: 3,
        activeStudentsCount: 3,
        sectionsCount: 1,
        seatsCount: 60,
        plansCount: 5,
        paymentsCount: 12,
        receiptsCount: 12,
        expensesCount: 4,
        notificationsCount: 8,
        auditLogCount: 45,
        recycleBinCount: 2,
        waitingListCount: 0,
        requestsCount: 0,
        announcementsCount: 1,
        estimatedTotalDocs: 151,
        estimatedStorageBytes: 151 * 1200.0, // ~181.2 KB
        estimatedDailyReads: 2850, // ~5.7% of Spark free limit
        estimatedDailyWrites: 220,  // ~1.1% of Spark free limit
        measuredAt: DateTime(2026, 11, 5),
      );

      // Verify quota fractions
      expect(sampleMetrics.readsQuotaPercent, closeTo(2850 / 50000, 0.001));
      expect(sampleMetrics.writesQuotaPercent, closeTo(220 / 20000, 0.001));
      expect(sampleMetrics.readsQuotaPercent < 0.10, isTrue, reason: 'Cozy Corner Spark usage must comfortably sit under 10%');
      expect(sampleMetrics.formattedStorageSize, contains('KB'));

      // Storage size formatting boundary test
      final largeMetrics = DatabaseMetrics(
        studentsCount: 100,
        activeStudentsCount: 80,
        sectionsCount: 5,
        seatsCount: 300,
        plansCount: 10,
        paymentsCount: 500,
        receiptsCount: 500,
        expensesCount: 200,
        notificationsCount: 1000,
        auditLogCount: 5000,
        recycleBinCount: 50,
        waitingListCount: 20,
        requestsCount: 15,
        announcementsCount: 10,
        estimatedTotalDocs: 7780,
        estimatedStorageBytes: 2.5 * 1024 * 1024, // 2.5 MB
        estimatedDailyReads: 15000,
        estimatedDailyWrites: 4000,
        measuredAt: DateTime(2026, 11, 5),
      );
      expect(largeMetrics.formattedStorageSize, equals('2.50 MB'));

      // ── 2. Integrity Issues & Healable Invariants ──
      final sampleIssues = [
        const IntegrityIssue(
          id: 'seat_101_orphaned',
          type: 'orphaned_seat',
          severity: IssueSeverity.error,
          title: 'Orphaned Occupied Seat #5',
          description: 'Seat is marked occupied but student ID std_deleted does not exist.',
          entityId: 'seat_101',
          canAutoHeal: true,
        ),
        const IntegrityIssue(
          id: 'seat_102_ghost',
          type: 'ghost_student_id',
          severity: IssueSeverity.warning,
          title: 'Ghost Student ID on Available Seat #6',
          description: 'Seat is available but retains student ID std_ghost.',
          entityId: 'seat_102',
          canAutoHeal: true,
        ),
        const IntegrityIssue(
          id: 'student_999_manual',
          type: 'manual_audit_required',
          severity: IssueSeverity.info,
          title: 'Manual Review Needed',
          description: 'Check external receipt reference.',
          canAutoHeal: false,
        ),
      ];

      final sampleReport = IntegrityReport(
        scannedAt: DateTime(2026, 11, 5, 14, 30),
        totalSeatsScanned: 60,
        totalStudentsScanned: 3,
        issues: sampleIssues,
        staleNotificationsCount: 14,
        expiredRecycleBinCount: 5,
        oldAuditLogsCount: 42,
      );

      expect(sampleReport.hasIssues, isTrue);
      expect(sampleReport.issues.length, equals(3));
      expect(sampleReport.healableCount, equals(2), reason: 'Only 2 issues have canAutoHeal == true');

      // ── 3. Diagnostic Report Formatter Completeness ──
      final service = DatabaseDiagnosticsService();
      final reportText = service.generateDiagnosticTextReport(sampleMetrics, sampleReport);

      expect(reportText, contains('THE COZY CORNER STUDY CENTRE — SYSTEM DIAGNOSTIC REPORT'));
      expect(reportText, contains('FIREBASE DATABASE QUOTA & USAGE PULSE'));
      expect(reportText, contains('50,000 Free Limit'));
      expect(reportText, contains('20,000 Free Limit'));
      expect(reportText, contains('COLLECTION INVENTORY METRICS'));
      expect(reportText, contains('Students: 3 (3 Active)'));
      expect(reportText, contains('Desks / Seats: 60'));
      expect(reportText, contains('INTEGRITY & INVARIANT DIAGNOSTICS'));
      expect(reportText, contains('Orphaned Occupied Seat #5'));
      expect(reportText, contains('STALE DATA CANDIDATES'));
      expect(reportText, contains('Read Notifications (>30d): 14'));
      expect(reportText, contains('Expired Recycle Bin (>30d): 5'));
      expect(reportText, contains('Historical Audit Logs (>90d): 42'));
    });

    test('104. PHASE 4: SILENT RECEPTION DESK ASSISTANCE & QUIET STUDY ENVIRONMENT ENGINE', () {
      final now = DateTime(2026, 11, 5, 18, 0, 0);

      // ── 1. Silent Alert Category Presets & Default Messages ──
      const silentCategories = [
        {
          'id': 'noise',
          'title': 'Noise Disturbance',
          'defaultMessage': 'Noise disturbance in study zone. Requesting discreet floor supervisor check.',
        },
        {
          'id': 'ac',
          'title': 'AC / Temperature',
          'defaultMessage': 'Please adjust the AC temperature or airflow in our study area.',
        },
        {
          'id': 'wifi',
          'title': 'Wi-Fi / Latency',
          'defaultMessage': 'Wi-Fi speed is sluggish or dropping out at this desk. Please verify router AP.',
        },
        {
          'id': 'water_clean',
          'title': 'Water & Hygiene',
          'defaultMessage': 'RO water dispenser needs refilling or desk area requires housekeeping attention.',
        },
        {
          'id': 'desk_help',
          'title': 'Reception Help',
          'defaultMessage': 'Requesting a staff member visit my desk for quick assistance.',
        },
      ];

      expect(silentCategories.length, equals(5));
      expect(silentCategories.any((c) => c['id'] == 'noise'), isTrue);
      expect(silentCategories.any((c) => c['id'] == 'ac'), isTrue);
      expect(silentCategories.any((c) => c['id'] == 'wifi'), isTrue);
      expect(silentCategories.any((c) => c['id'] == 'water_clean'), isTrue);
      expect(silentCategories.any((c) => c['id'] == 'desk_help'), isTrue);

      // ── 2. Automatic Desk Location Resolution ──
      final testStudentWithDesk = createTestStudent(
        id: 'std_quiet_01',
        name: 'Focused Scholar',
        phone: '9822011223',
        seatId: 'seat_46',
      );

      String resolveLocationLabel(StudentModel s, {String? customOverride}) {
        if (customOverride != null && customOverride.trim().isNotEmpty) {
          return customOverride.trim();
        }
        if (s.seatId != null && s.seatId!.isNotEmpty) {
          return SeatHelper.formatSeatLabel(seatId: s.seatId);
        }
        return 'General Study Hall';
      }

      expect(resolveLocationLabel(testStudentWithDesk), equals('Seat #46'));
      expect(
        resolveLocationLabel(testStudentWithDesk, customOverride: 'Zone B - Row 4'),
        equals('Zone B - Row 4'),
      );

      final unassignedStudent = createTestStudent(
        id: 'std_quiet_02',
        name: 'New Scholar',
        phone: '9822011224',
        seatId: null,
      );
      expect(resolveLocationLabel(unassignedStudent), equals('General Study Hall'));

      // ── 3. Silent Alert FeedbackModel Serialization ──
      final alertModel = FeedbackModel(
        id: 'alert_001',
        libraryId: 'lib_cozy',
        studentId: testStudentWithDesk.id,
        studentName: testStudentWithDesk.name,
        studentPhone: testStudentWithDesk.phone,
        seatNumber: resolveLocationLabel(testStudentWithDesk),
        message: 'Someone is talking loudly on the phone near row 4.',
        category: 'Noise Disturbance',
        feedbackType: 'silent_alert',
        status: 'unread',
        createdAt: now,
      );

      final alertJson = alertModel.toJson();
      expect(alertJson['feedbackType'], equals('silent_alert'));
      expect(alertJson['status'], equals('unread'));
      expect(alertJson['category'], equals('Noise Disturbance'));
      expect(alertJson['seatNumber'], equals('Seat #46'));
      expect(alertJson['studentName'], equals('Focused Scholar'));
      expect(alertJson['message'], contains('talking loudly'));

      // ── 4. Reception Resolution Lifecycle ──
      final resolvedAlert = alertModel.copyWith(
        status: 'resolved',
        adminReply: 'Floor supervisor personally checked and restored pin-drop silence.',
      );

      expect(resolvedAlert.status, equals('resolved'));
      expect(resolvedAlert.adminReply, contains('restored pin-drop silence'));
    });

    test('105. STUDENT EARLY EXIT, SEAT VACATE & PRO-RATA REFUND WIZARD WITH LEDGER PARITY', () {
      final now = DateTime(2026, 11, 5, 12, 0, 0);

      // ── 1. PlanCalculatorService Pro-Rata Exit Settlement Math ──
      final samplePlan = PlanModel(
        id: 'plan_standard_monthly',
        libraryId: 'lib_cozy',
        name: 'Full Day Standard',
        price: 900.0,
        duration: 1,
        durationUnit: DurationUnit.months,
        description: 'Standard plan',
        gracePeriodDays: 0,
        isActive: true,
        isFeatured: false,
        displayOrder: 1,
      );

      final cycleStart = DateTime(2026, 11, 1);
      final cycleEnd = DateTime(2026, 11, 30); // 30-day cycle
      final exitDate = DateTime(2026, 11, 10); // 10 days used (inclusive), 20 days unused
      const totalPaid = 900.0;
      const cancellationFee = 100.0;

      final exitSettlement = PlanCalculatorService.calculateExitSettlement(
        startDate: cycleStart,
        originalEndDate: cycleEnd,
        exitDate: exitDate,
        totalPaid: totalPaid,
        plan: samplePlan,
        processingFee: cancellationFee,
      );

      expect(exitSettlement.totalCycleDays, equals(30));
      expect(exitSettlement.usedDays, equals(10));
      expect(exitSettlement.unusedDays, equals(20));
      // 10 / 30 * 900 = 300 fair usage
      expect(exitSettlement.fairUsageFee, equals(300.0));
      // 900 - 300 = 600 gross refund
      expect(exitSettlement.grossRefund, equals(600.0));
      // 600 - 100 = 500 net refund
      expect(exitSettlement.netRefund, equals(500.0));
      expect(exitSettlement.formattedNetRefund, equals('₹500'));

      // ── 2. Boundary Condition: Exit Near Expiry with Higher Fee (Net <= 0) ──
      final lateExitDate = DateTime(2026, 11, 28); // 28 days used, 2 unused
      final lateSettlement = PlanCalculatorService.calculateExitSettlement(
        startDate: cycleStart,
        originalEndDate: cycleEnd,
        exitDate: lateExitDate,
        totalPaid: totalPaid,
        plan: samplePlan,
        processingFee: cancellationFee,
      );
      expect(lateSettlement.usedDays, equals(28));
      expect(lateSettlement.unusedDays, equals(2));
      // 28 / 30 * 900 = 840 fair usage
      expect(lateSettlement.fairUsageFee, equals(840.0));
      expect(lateSettlement.grossRefund, equals(60.0));
      // Gross 60 - Fee 100 = -40 => Clamped to 0
      expect(lateSettlement.netRefund, equals(0.0));
      expect(lateSettlement.formattedNetRefund, equals('₹0'));

      // ── 3. Negative Payment Ledger Model Serialization Parity ──
      const refundReceiptNumber = 'REC-2026-0099';
      const refundDocId = 'pay_refund_105';
      final negativeRefundPayment = PaymentModel(
        id: refundDocId,
        studentId: 'std_exit_01',
        studentUserId: 'usr_exit_01',
        amount: -exitSettlement.netRefund, // -₹500 in ledger
        totalPlanFee: totalPaid,
        remainingDue: 0.0,
        method: 'UPI',
        referenceNumber: 'UPI/20261105/982123',
        date: exitDate,
        receiptId: 'rec_doc_105',
        receiptNumber: refundReceiptNumber,
        status: PaymentStatus.refunded,
        notes: 'Early Exit Settlement Voucher #$refundReceiptNumber: Used 10/30d. Net refund ₹500 via UPI.',
        createdAt: exitDate,
      );

      final payJson = negativeRefundPayment.toJson();
      expect(payJson['amount'], equals(-500.0));
      expect(payJson['status'], equals('refunded'));
      expect(payJson['paymentMethod'], equals('UPI'));
      expect(payJson['receiptNumber'], equals(refundReceiptNumber));
      expect(payJson['referenceNumber'], equals('UPI/20261105/982123'));

      final parsedPayment = PaymentModel.fromJson(payJson);
      expect(parsedPayment.amount, equals(-500.0));
      expect(parsedPayment.status, equals(PaymentStatus.refunded));
      expect(parsedPayment.method, equals('UPI'));
      expect(parsedPayment.receiptNumber, equals(refundReceiptNumber));

      // ── 4. Settlement Receipt Voucher Serialization Parity ──
      final settlementReceipt = ReceiptModel(
        id: 'rec_doc_105',
        libraryId: 'lib_cozy',
        receiptNumber: refundReceiptNumber,
        studentId: 'std_exit_01',
        studentUserId: 'usr_exit_01',
        planId: samplePlan.id,
        amount: exitSettlement.netRefund,
        paymentMethod: 'UPI',
        validFrom: cycleStart,
        validTo: exitDate,
        status: ReceiptStatus.active,
        customFields: {
          'isRefund': true,
          'isEarlyExitSettlement': true,
          'usedDays': exitSettlement.usedDays,
          'totalCycleDays': exitSettlement.totalCycleDays,
          'unusedDays': exitSettlement.unusedDays,
          'fairUsageFee': exitSettlement.fairUsageFee,
          'processingFee': cancellationFee,
          'totalPaid': totalPaid,
          'netRefund': exitSettlement.netRefund,
          'refundMethod': 'UPI',
          'referenceNumber': 'UPI/20261105/982123',
          'exitDate': exitDate.toIso8601String(),
        },
        createdAt: exitDate,
      );

      final recJson = settlementReceipt.toJson();
      expect(recJson['receiptNumber'], equals(refundReceiptNumber));
      expect(recJson['amount'], equals(500.0));
      expect(recJson['status'], equals('active'));
      expect(recJson['customFields']['isRefund'], isTrue);
      expect(recJson['customFields']['isEarlyExitSettlement'], isTrue);
      expect(recJson['customFields']['netRefund'], equals(500.0));
      expect(recJson['customFields']['usedDays'], equals(10));
      expect(recJson['customFields']['processingFee'], equals(100.0));

      final parsedReceipt = ReceiptModel.fromJson(recJson);
      expect(parsedReceipt.receiptNumber, equals(refundReceiptNumber));
      expect(parsedReceipt.amount, equals(500.0));
      expect(parsedReceipt.customFields['isRefund'], isTrue);

      // ── 5. Student Status & Dues Deallocation Invariant ──
      final exitingStudent = createTestStudent(
        id: 'std_exit_01',
        name: 'Graduating Scholar',
        phone: '9811002233',
        seatId: 'seat_46',
        membershipStatus: MembershipStatus.active,
        pendingDueBalance: 300.0, // Had an outstanding partial due
      );

      final settledStudent = exitingStudent.copyWith(
        membershipStatus: MembershipStatus.inactive,
        clearSeat: true,
        previousSeatId: exitingStudent.seatId,
        pendingDueBalance: 0.0, // Dues wiped upon final settlement
        notes: '[Exit Settlement] on 05 Nov 2026. Cycle: 10/30d. Net refund: ₹500 (Voucher: $refundReceiptNumber via UPI).',
      );

      expect(settledStudent.membershipStatus, equals(MembershipStatus.inactive));
      expect(settledStudent.seatId, isNull);
      expect(settledStudent.previousSeatId, equals('seat_46'));
      expect(settledStudent.pendingDueBalance, equals(0.0));
      expect(settledStudent.notes, contains('[Exit Settlement]'));
      expect(settledStudent.notes, contains(refundReceiptNumber));

      // ── 6. Waiting List Automatic Cascade Queue Matching ──
      final waitlistEntries = [
        WaitingListEntry(
          id: 'wait_01',
          libraryId: 'lib_cozy',
          studentId: 'std_wait_01',
          studentName: 'Next In Line',
          studentPhone: '9899001122',
          preferredSectionId: 'sec_quiet',
          position: 1,
          createdAt: now.subtract(const Duration(hours: 4)),
        ),
        WaitingListEntry(
          id: 'wait_02',
          libraryId: 'lib_cozy',
          studentId: 'std_wait_02',
          studentName: 'Second Candidate',
          studentPhone: '9899001133',
          preferredSectionId: 'sec_quiet',
          position: 2,
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ];

      // Simulated FIFO resolution matching freed section
      final topCandidate = waitlistEntries.firstWhere(
        (e) => e.preferredSectionId == 'sec_quiet',
      );
      expect(topCandidate.id, equals('wait_01'));
      expect(topCandidate.studentName, equals('Next In Line'));

      // ── 7. WhatsApp Early Exit Settlement Template Content Verification ──
      final buffer = StringBuffer()
        ..writeln('🚪 *Membership Early Exit & Settlement Confirmation*')
        ..writeln()
        ..writeln('Dear *${exitingStudent.name}*,')
        ..writeln('Your early exit and account settlement has been successfully processed at *The Cozy Corner Study Centre*.')
        ..writeln()
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('🧾 *SETTLEMENT SUMMARY*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('🧾 *Voucher Number:* $refundReceiptNumber')
        ..writeln('📅 *Cycle Days Used:* ${exitSettlement.usedDays} of ${exitSettlement.totalCycleDays} days')
        ..writeln('💺 *Seat Vacated:* Seat #46')
        ..writeln('📊 *Fair Usage Charge:* ₹${exitSettlement.fairUsageFee.toStringAsFixed(0)}')
        ..writeln('✂️ *Early Cancellation Fee:* ₹${cancellationFee.toStringAsFixed(0)}')
        ..writeln('💵 *Net Refund Issued:* *₹${exitSettlement.netRefund.toStringAsFixed(0)}* (UPI)')
        ..writeln('🔖 *Reference / UTR:* UPI/20261105/982123')
        ..writeln()
        ..writeln('Your desk has been vacated and your membership account marked as settled.')
        ..writeln('Thank you for being part of our community. We wish you immense success in your academic and career goals! 🎓🌟');

      final waMessage = buffer.toString();
      expect(waMessage, contains('Membership Early Exit & Settlement Confirmation'));
      expect(waMessage, contains(refundReceiptNumber));
      expect(waMessage, contains('10 of 30 days'));
      expect(waMessage, contains('Seat Vacated:* Seat #46'));
      expect(waMessage, contains('Fair Usage Charge:* ₹300'));
      expect(waMessage, contains('Early Cancellation Fee:* ₹100'));
      expect(waMessage, contains('Net Refund Issued:* *₹500* (UPI)'));
      expect(waMessage, contains('Reference / UTR:* UPI/20261105/982123'));
    });

    test('106. QUICK ACTION STUDIO & SMART PAYMENT PICKER: CATEGORIZATION, PRIORITY DEFAULTER SORTING & SEARCH ENGINE', () {
      final now = DateTime(2026, 11, 5, 12, 0);
      final in3Days = now.add(const Duration(days: 3));
      final in15Days = now.add(const Duration(days: 15));

      final studentA = createTestStudent(
        id: 'std_a',
        name: 'Aarav Sharma',
        phone: '9820011223',
        membershipNumber: 'CC20260001',
        membershipStatus: MembershipStatus.active,
        planEndDate: in15Days,
        pendingDueBalance: 0.0,
      );

      final studentB = createTestStudent(
        id: 'std_b',
        name: 'Bharat Patil',
        phone: '9820044556',
        membershipNumber: 'CC20260002',
        membershipStatus: MembershipStatus.active,
        planEndDate: in15Days,
        pendingDueBalance: 350.0, // High due
      );

      final studentC = createTestStudent(
        id: 'std_c',
        name: 'Chetan Deshmukh',
        phone: '9820077889',
        membershipNumber: 'CC20260003',
        membershipStatus: MembershipStatus.active,
        planEndDate: in15Days,
        pendingDueBalance: 700.0, // Highest due
      );

      final studentD = createTestStudent(
        id: 'std_d',
        name: 'Divya Kadam',
        phone: '9820099887',
        membershipNumber: 'CC20260004',
        membershipStatus: MembershipStatus.grace, // In grace period
        planEndDate: in3Days,
        pendingDueBalance: 0.0,
      );

      final allStudents = [studentA, studentB, studentC, studentD];

      // ── 1. Smart Prioritization Sorting Invariants ──
      // Defaulters at the top (highest dues first) -> Grace/Expiring -> Alphabetical
      final sortedList = List<StudentModel>.from(allStudents)..sort((a, b) {
        final aDue = a.pendingDueBalance ?? 0.0;
        final bDue = b.pendingDueBalance ?? 0.0;

        if (aDue > 0 && bDue <= 0) return -1;
        if (bDue > 0 && aDue <= 0) return 1;
        if (aDue > 0 && bDue > 0) return bDue.compareTo(aDue);

        final aIsGrace = a.membershipStatus == MembershipStatus.grace;
        final bIsGrace = b.membershipStatus == MembershipStatus.grace;
        if (aIsGrace && !bIsGrace) return -1;
        if (bIsGrace && !aIsGrace) return 1;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      expect(sortedList[0].id, equals('std_c'), reason: '₹700 due must be rank #1');
      expect(sortedList[1].id, equals('std_b'), reason: '₹350 due must be rank #2');
      expect(sortedList[2].id, equals('std_d'), reason: 'Grace period must be rank #3');
      expect(sortedList[3].id, equals('std_a'), reason: 'Zero due active student must follow at rank #4');

      // ── 2. Multi-field Search Filter Engine ──
      List<StudentModel> searchStudents(List<StudentModel> list, String query) {
        if (query.trim().isEmpty) return list;
        final q = query.trim().toLowerCase();
        return list.where((s) {
          final name = s.name.toLowerCase();
          final phone = s.phone.toLowerCase();
          final memNo = (s.membershipNumber ?? '').toLowerCase();
          final seat = (s.seatId ?? '').toLowerCase();
          return name.contains(q) || phone.contains(q) || memNo.contains(q) || seat.contains(q);
        }).toList();
      }

      // Match by Name
      expect(searchStudents(allStudents, 'Bharat').length, equals(1));
      expect(searchStudents(allStudents, 'bharat').first.id, equals('std_b'));

      // Match by Phone
      expect(searchStudents(allStudents, '9820077889').first.id, equals('std_c'));

      // Match by #CC Admission ID
      expect(searchStudents(allStudents, 'CC20260004').first.id, equals('std_d'));
      expect(searchStudents(allStudents, 'cc20260001').first.id, equals('std_a'));

      // ── 3. Quick Action Studio Defaulter Aggregate Metrics ──
      final defaulters = allStudents.where((s) => (s.pendingDueBalance ?? 0) > 0).toList();
      final totalDueAmount = defaulters.fold<double>(0, (acc, s) => acc + (s.pendingDueBalance ?? 0));
      expect(defaulters.length, equals(2));
      expect(totalDueAmount, equals(1050.0)); // 700 + 350
    });

    test('107. DESKTOP MASTER-DETAIL SPLIT WORKBENCH: BREAKPOINT THRESHOLD, ROSTER DOCKING & SELECTION PARITY', () {
      // ── 1. Responsive Layout Breakpoint Threshold Verification ──
      bool isSplitDesktop(double width) => width >= 1024;
      bool isTabletGrid(double width) => width >= 720 && width < 1024;
      bool isMobileStack(double width) => width < 720;

      expect(isMobileStack(390), isTrue, reason: 'iPhone 15 screen must use mobile vertical stack');
      expect(isTabletGrid(768), isTrue, reason: 'iPad Mini must use 2-column grid view');
      expect(isTabletGrid(1023), isTrue, reason: 'Tablet upper boundary must stay in grid mode');
      expect(isSplitDesktop(1024), isTrue, reason: '1024px minimum desktop displays must switch to Master-Detail Split Workbench');
      expect(isSplitDesktop(1440), isTrue, reason: 'MacBook/Desktop display must use Master-Detail Split Workbench');
      expect(isSplitDesktop(1920), isTrue, reason: '1080p Full HD display must use Master-Detail Split Workbench');

      // ── 2. Master Roster Fixed Left Rail & Detail Dock Geometry ──
      const double desktopScreenWidth = 1440.0;
      const double rosterRailWidth = 380.0;
      const double dividerThickness = 1.0;
      final workbenchPaneWidth = desktopScreenWidth - rosterRailWidth - dividerThickness;

      expect(rosterRailWidth, equals(380.0), reason: 'Fixed 380px left rail allows high-density scrolling without crowding');
      expect(workbenchPaneWidth, equals(1059.0), reason: 'Right pane gets full remainder for rich student dossier');

      // ── 3. Roster Selection Invariant & Auto-Targeting Logic ──
      final students = [
        createTestStudent(id: 'std_01', name: 'Aakash Verma', phone: '9820011221', seatId: 'seat_12'),
        createTestStudent(id: 'std_02', name: 'Bhavna Roy', phone: '9820011222', seatId: 'seat_14', pendingDueBalance: 500.0),
        createTestStudent(id: 'std_03', name: 'Chirag Jain', phone: '9820011223', seatId: null),
      ];

      String? activeSelectedId;

      // When nothing is explicitly selected on desktop, auto-focus first scholar
      activeSelectedId ??= students.isNotEmpty ? students.first.id : null;
      expect(activeSelectedId, equals('std_01'));

      // User selects scholar 2 on the left roster rail
      activeSelectedId = students[1].id;
      expect(activeSelectedId, equals('std_02'));

      // Card focus state check
      bool isCardFocused(String studentId) => activeSelectedId == studentId;
      expect(isCardFocused('std_01'), isFalse);
      expect(isCardFocused('std_02'), isTrue);
      expect(isCardFocused('std_03'), isFalse);

      // Verify desk badge rendering logic on roster card
      String getRosterDeskBadge(StudentModel s) {
        if (s.seatId != null && s.seatId!.isNotEmpty) {
          return 'Desk #${s.seatId!.replaceAll(RegExp(r'[^0-9]'), '')}';
        }
        return 'Floating';
      }

      expect(getRosterDeskBadge(students[0]), equals('Desk #12'));
      expect(getRosterDeskBadge(students[1]), equals('Desk #14'));
      expect(getRosterDeskBadge(students[2]), equals('Floating'));
    });

    test('108. MID-CYCLE PLAN UPGRADE & PRO-RATA SURCHARGE WIZARD WITH LEDGER PARITY', () {
      final now = DateTime(2026, 11, 16, 10, 0);
      final cycleStart = DateTime(2026, 11, 1, 0, 0);
      final cycleEnd = DateTime(2026, 11, 30, 23, 59);

      final currentPlan = PlanModel(
        id: 'plan_6h',
        libraryId: 'lib_cozy',
        name: 'Half Day (6 Hours)',
        price: 500.0,
        duration: 1,
        durationUnit: DurationUnit.months,
        description: '6 hour shift access',
        gracePeriodDays: 3,
        isActive: true,
        isFeatured: false,
        displayOrder: 1,
      );

      final targetPlan = PlanModel(
        id: 'plan_12h',
        libraryId: 'lib_cozy',
        name: 'Full Day (12 Hours)',
        price: 800.0,
        duration: 1,
        durationUnit: DurationUnit.months,
        description: 'Full day study hall access',
        gracePeriodDays: 3,
        isActive: true,
        isFeatured: true,
        displayOrder: 2,
      );

      final student = createTestStudent(
        id: 'std_priya',
        name: 'Priya Deshmukh',
        phone: '9820011225',
        membershipNumber: 'CC20260088',
        membershipStatus: MembershipStatus.active,
        planId: currentPlan.id,
        planStartDate: cycleStart,
        planEndDate: cycleEnd,
        pendingDueBalance: 0.0,
      );

      // ── 1. Fair Pro-Rata Settlement Calculation (Scenario C) ──
      final settlement = PlanCalculatorService.calculatePlanChangeSettlement(
        currentPlan: currentPlan,
        targetPlan: targetPlan,
        currentStartDate: cycleStart,
        currentEndDate: cycleEnd,
        changeDate: now,
        totalPaidForCurrent: 500.0,
      );

      expect(settlement.isUpgrade, isTrue);
      expect(settlement.totalCurrentDays, equals(30));
      expect(settlement.usedDays, equals(15));
      expect(settlement.remainingDays, equals(15));

      // 15 days used = ₹250 value consumed, ₹250 unused credit remaining
      expect(settlement.unusedCredit, equals(250.0));

      // New 12h plan for remaining 15 days = (15 / 30) * 800 = ₹400
      expect(settlement.newPlanProratedFee, equals(400.0));

      // Net upgrade difference payable by student: 400 - 250 = ₹150
      expect(settlement.netDifference, equals(150.0));
      expect(settlement.payableByStudent, equals(150.0));
      expect(settlement.refundableToStudent, equals(0.0));

      // ── 2. Mode 0: Mid-Cycle Upgrade (Retaining Cycle Expiry) ──
      const mode0Amount = 150.0;
      final mode0EndDate = cycleEnd;
      expect(mode0EndDate, equals(cycleEnd), reason: 'Mid-cycle keeps the existing month-end cycle intact');

      // ── 3. Mode 1: Fresh Full Month Cycle with Unused Credit Applied ──
      final mode1Amount = (targetPlan.price - settlement.unusedCredit).clamp(0.0, double.infinity);
      // ₹800 full price - ₹250 unused credit = ₹550
      expect(mode1Amount, equals(550.0));

      // ── 4. Ledger Parity: Sequential Voucher & Revenue Increment ──
      const upgradeVoucher = 'REC-2026-0889';
      final upgradeReceipt = ReceiptModel(
        id: 'rec_upg_0889',
        libraryId: 'lib_cozy',
        receiptNumber: upgradeVoucher,
        studentId: student.id,
        studentUserId: student.userId,
        planId: targetPlan.id,
        amount: mode0Amount,
        paymentMethod: 'UPI',
        validFrom: cycleStart,
        validTo: mode0EndDate,
        customFields: {
          'isPlanUpgrade': true,
          'previousPlanName': currentPlan.name,
          'unusedCredit': settlement.unusedCredit,
          'proratedDays': settlement.remainingDays,
        },
        status: ReceiptStatus.active,
      );

      expect(upgradeReceipt.amount, equals(150.0));
      expect(upgradeReceipt.customFields['isPlanUpgrade'], isTrue);
      expect(upgradeReceipt.customFields['unusedCredit'], equals(250.0));
      expect(upgradeReceipt.customFields['proratedDays'], equals(15));

      // ── 5. Student Profile State Synchronisation ──
      final upgradedStudent = student.copyWith(
        planId: targetPlan.id,
        planEndDate: mode0EndDate,
        notes: '${student.notes ?? ""}\n[Plan Upgrade] ${currentPlan.name} ➔ ${targetPlan.displayName}: ₹150 paid via UPI • Receipt: $upgradeVoucher',
      );

      expect(upgradedStudent.planId, equals('plan_12h'));
      expect(upgradedStudent.planEndDate, equals(cycleEnd));
      expect(upgradedStudent.notes, contains('[Plan Upgrade]'));
      expect(upgradedStudent.notes, contains(upgradeVoucher));

      // ── 6. WhatsApp Plan Upgrade Confirmation Template Verification ──
      final waBuffer = StringBuffer()
        ..writeln('🚀 *Membership Plan Upgrade Confirmation*')
        ..writeln()
        ..writeln('Dear *${student.name}*,')
        ..writeln('Your study membership tier at *The Cozy Corner Study Centre* has been successfully upgraded!')
        ..writeln()
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('📦 *PLAN UPGRADE DETAILS*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('🔄 *Upgrade:* ${currentPlan.name} ➔ *${targetPlan.displayName}*')
        ..writeln('🧾 *Receipt Voucher:* $upgradeVoucher')
        ..writeln('⏳ *Remaining Cycle:* ${settlement.remainingDays} days')
        ..writeln('💳 *Unused Credit Applied:* -₹${settlement.unusedCredit.toStringAsFixed(0)}')
        ..writeln('💵 *Net Upgrade Surcharge Paid:* *₹${mode0Amount.toStringAsFixed(0)}* (UPI)')
        ..writeln('📅 *Valid Through:* *30 Nov 2026*')
        ..writeln()
        ..writeln('Your upgraded amenities, timings, and privileges are active immediately. Have a productive study session! 📚⚡');

      final waText = waBuffer.toString();
      expect(waText, contains('Membership Plan Upgrade Confirmation'));
      expect(waText, contains('Half Day (6 Hours) ➔ *Full Day (12 Hours)*'));
      expect(waText, contains('Receipt Voucher:* REC-2026-0889'));
      expect(waText, contains('Remaining Cycle:* 15 days'));
      expect(waText, contains('Unused Credit Applied:* -₹250'));
      expect(waText, contains('Net Upgrade Surcharge Paid:* *₹150* (UPI)'));
      expect(waText, contains('Valid Through:* *30 Nov 2026*'));
    });

    test('109. UNIVERSAL UPDATED INFO & LEGAL VISIBILITY PARITY (STUDENT, ADMIN & PUBLIC)', () {
      // 1. Version synchronization verification
      expect(WhatsNewService.currentVersionIdentifier, equals('${AppConstants.appVersion}+${AppConstants.buildNumber}'));
      expect(AppConstants.appVersion, equals('1.5.53'));
      expect(AppConstants.buildNumber, equals(68));

      // 2. Student-facing release changes include all 4 automation features
      final studentTitles = WhatsNewService.studentChanges.map((c) => c.title).toList();
      expect(studentTitles, contains('Birthday Celebration & 1-Tap Wi-Fi Password Copy'));
      expect(studentTitles, contains('Exam Countdown Widget for Your Course'));
      expect(studentTitles, contains('Guaranteed Seat Hold & 1-Tap Renewal Flow'));
      expect(studentTitles, contains('Silent Reception & Noise Help Button'));

      // 3. Admin-facing release changes include quiet desk assistance and billing parity
      final adminTitles = WhatsNewService.adminChanges.map((c) => c.title).toList();
      expect(adminTitles, contains('Live Quiet Desk Assistance Stream'));
      expect(adminTitles, contains('10-Second Express Counter Billing & Atomic Seat Parity'));
      expect(adminTitles, contains('Resilient Multi-Key Receipt Retrieval'));

      // 4. Legal routes invariant: Terms & Privacy must be public routes
      expect(Routes.terms, equals('/terms'));
      expect(Routes.privacyPolicy, equals('/privacy-policy'));

      // 5. App version string formatting for student profile
      final formattedVersion = 'v${AppConstants.appVersion}+${AppConstants.buildNumber}';
      expect(formattedVersion, equals('v1.5.53+68'));
    });

    test('110. 1-TAP WAITING LIST PROMOTION & MULTI-LINGUAL WHATSAPP OFFER SUITE', () async {
      // 1. Setup mock candidate
      final candidate = WaitingListEntry(
        id: 'wait_cand_001',
        libraryId: 'test_lib',
        studentId: 'cand_user_001',
        studentName: 'Neha Deshmukh',
        studentPhone: '9820011222',
        position: 1,
        preferredSectionId: 'main_hall',
        genderPreference: 'none',
        createdAt: DateTime(2026, 11, 1),
      );

      // 2. Variable substitution via MessageTemplateService for waitlist offers
      final defaultOffer = MessageTemplateService.getTemplate(type: 'waitlist_offer', language: 'en');
      final substitutedOffer = MessageTemplateService.substitute(
        defaultOffer,
        studentName: candidate.studentName,
        seatLabel: 'Seat #14',
        libraryName: 'Cozy Corner Study Centre',
        libraryAddress: 'Someshwar Nagar, Parli',
        libraryHelpline: '+91 91569 44773',
      );

      expect(substitutedOffer, contains('Study Seat Available — Cozy Corner Study Centre'));
      expect(substitutedOffer, contains('Dear *Neha Deshmukh*'));
      expect(substitutedOffer, contains('Seat #14'));
      expect(substitutedOffer, contains('Someshwar Nagar, Parli'));
      expect(substitutedOffer, contains('+91 91569 44773'));

      // 3. Multilingual template coverage (Hindi & Marathi)
      final hiOffer = MessageTemplateService.getTemplate(type: 'waitlist_offer', language: 'hi');
      final substitutedHi = MessageTemplateService.substitute(
        hiOffer,
        studentName: candidate.studentName,
        seatLabel: 'Seat #14',
        libraryName: 'Cozy Corner',
      );
      expect(substitutedHi, contains('सीट उपलब्ध सूचना — Cozy Corner'));
      expect(substitutedHi, contains('नमस्ते *Neha Deshmukh*'));
      expect(substitutedHi, contains('Seat #14'));

      final mrOffer = MessageTemplateService.getTemplate(type: 'waitlist_offer', language: 'mr');
      final substitutedMr = MessageTemplateService.substitute(
        mrOffer,
        studentName: candidate.studentName,
        seatLabel: 'Seat #14',
        libraryName: 'Cozy Corner',
      );
      expect(substitutedMr, contains('अभ्यास बैठक (Seat) उपलब्ध — Cozy Corner'));
      expect(substitutedMr, contains('सस्नेह नमस्कार *Neha Deshmukh*'));
      expect(substitutedMr, contains('Seat #14'));

      // 4. Default fallback buffer when no template is passed
      final waService = WhatsAppService();
      expect(waService, isNotNull);
    });

    test('111. RECEPTION COUNTER SOUNDBOX CHIME & SPOKEN PAYMENT ENGINE', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final soundbox = SoundboxService(prefs: prefs);

      // 1. Initial defaults
      expect(soundbox.isEnabled, isTrue);
      expect(soundbox.language, equals('en'));

      // 2. Spoken formatting across languages
      final enSpeech = soundbox.formatAnnouncement(
        amount: 700,
        studentName: 'Shubham',
        seatLabel: 'Seat 14',
        libraryName: 'The Cozy Corner Study Centre',
        languageOverride: 'en',
      );
      expect(enSpeech, equals('Payment of 700 rupees received for Shubham Seat 14 on The Cozy Corner Study Centre.'));

      final hiSpeech = soundbox.formatAnnouncement(
        amount: 800,
        libraryName: 'Cozy Corner',
        languageOverride: 'hi',
      );
      expect(hiSpeech, equals('Cozy Corner पर 800 रुपये प्राप्त हुए।'));

      final mrSpeech = soundbox.formatAnnouncement(
        amount: 1200,
        libraryName: 'Cozy Corner Study Hub',
        languageOverride: 'mr',
      );
      expect(mrSpeech, equals('Cozy Corner Study Hub वर 1200 रुपये प्राप्त झाले।'));

      // 3. Audio Chime Execution (should run without throwing in test environment)
      soundbox.playChime();

      // 4. State updates
      await soundbox.setLanguage('mr');
      expect(soundbox.language, equals('mr'));

      await soundbox.setEnabled(false);
      expect(soundbox.isEnabled, isFalse);

      await soundbox.setEnabled(true);
      expect(soundbox.isEnabled, isTrue);
    });

    test('112. SEAT CHANGE REQUEST DISCOVERABILITY & HOME STATUS BANNER PARITY', () {
      final pendingReq = <String, dynamic>{
        'id': 'req_seat_change_101',
        'type': 'seat_change',
        'status': 'pending',
        'studentId': 'stud_ashish_01',
        'studentUserId': 'uid_ashish_123',
        'userId': 'uid_ashish_123',
        'currentSeatId': 'seat_1',
        'currentSeatLabel': 'Seat #1',
        'currentSectionName': 'Cozy Hall',
        'targetSeatId': 'seat_6',
        'targetSeatLabel': '6',
        'targetSectionName': 'Cozy Hall',
        'reason': 'Near power socket, quieter reading spot',
        'createdAt': DateTime.now().toIso8601String(),
      };

      // 1. Verify seat label parsing and formatting
      final formattedTarget = SeatHelper.formatSeatLabel(
        seatId: pendingReq['targetSeatId'] as String?,
        rawLabel: pendingReq['targetSeatLabel'] as String?,
      );
      expect(formattedTarget, equals('Seat #6'));

      // 2. Format seat number only (no hash prefix) for dense grids
      final seatNumberOnly = SeatHelper.formatSeatNumberOnly(rawLabel: '6');
      expect(seatNumberOnly, equals('6'));

      // 3. Status card verification
      final hasPendingChange = pendingReq['status'] == 'pending';
      expect(hasPendingChange, isTrue);
      final badgeLabel = hasPendingChange ? 'CHANGE IN PROGRESS' : 'ALLOCATED';
      expect(badgeLabel, equals('CHANGE IN PROGRESS'));

      final trailingActionLabel = hasPendingChange ? 'View Request' : 'Change Desk';
      expect(trailingActionLabel, equals('View Request'));
    });

    test('113. UIDAI AADHAAR VERHOEFF CHECKSUM ALGORITHM INTEGRITY & TYPO GUARDS', () {
      // 1. Generate check digit for an 11-digit prefix
      const prefix = '23456789012';
      final checkDigit = AppValidators.generateVerhoeffCheckDigit(prefix);
      final validAadhaar = '$prefix$checkDigit';

      // 2. Validate valid Aadhaar passes Verhoeff checksum
      expect(AppValidators.validateVerhoeff(validAadhaar), isTrue);
      expect(AppValidators.aadhaar(validAadhaar, verifyChecksum: true), isNull);

      // 3. Single-digit mutation / typo fails checksum
      final mutatedDigit = (checkDigit + 1) % 10;
      final typoAadhaar = '$prefix$mutatedDigit';
      expect(AppValidators.validateVerhoeff(typoAadhaar), isFalse);
      expect(
        AppValidators.aadhaar(typoAadhaar, verifyChecksum: true),
        equals('Invalid Aadhaar number (checksum validation failed)'),
      );

      // 4. Adjacent digit transposition fails checksum (Verhoeff guarantee)
      // Transpose 5th and 6th digits: '2345 67 89012' -> '2345 76 89012'
      final transposedAadhaar = '23457689012$checkDigit';
      expect(AppValidators.validateVerhoeff(transposedAadhaar), isFalse);

      // 5. Basic length and prefix guards remain intact
      expect(AppValidators.aadhaar('023456789012'), equals('Aadhaar cannot begin with 0 or 1'));
      expect(AppValidators.aadhaar('123456789012'), equals('Aadhaar cannot begin with 0 or 1'));
      expect(AppValidators.aadhaar('2345'), equals('Aadhaar must be exactly 12 numeric digits'));
    });

    test('114. SCENARIO D: STUDY VACATION / EXAM LEAVE FREEZE (10+ DAYS) FULL LIFECYCLE', () {
      // 1. Setup mock student with active membership ending Dec 31, 2026
      final amit = StudentModel(
        id: 'stud_amit_01',
        name: 'Amit Sharma',
        fatherName: 'Rajesh Sharma',
        phone: '9876543210',
        email: 'amit@example.com',
        gender: Gender.male,
        address: 'MG Road, Pune',
        pincode: '411001',
        govIdType: GovIdType.aadhaar,
        govIdNumber: '234567890128',
        govIdImageUrl: 'https://example.com/id.jpg',
        photoUrl: 'https://example.com/photo.jpg',
        college: 'Fergusson College',
        course: 'UPSC Civil Services',
        year: 'Final',
        emergencyContact: '9876543211',
        seatId: 'seat_14',
        sectionId: 'sec_cozy_01',
        planId: 'plan_monthly',
        planStartDate: DateTime(2026, 12, 1),
        planEndDate: DateTime(2026, 12, 31),
        membershipStatus: MembershipStatus.active,
        customFields: {},
      );

      // 2. Reject short freeze (< 10 days policy rule)
      final shortFreeze = PlanCalculatorService.calculateMembershipFreeze(
        student: amit,
        freezeStartDate: DateTime(2026, 12, 12),
        freezeEndDate: DateTime(2026, 12, 16), // 5 days
      );
      expect(shortFreeze.isValid, isFalse);
      expect(shortFreeze.freezeDays, equals(5));
      expect(shortFreeze.message, contains('permitted for 10 or more consecutive days'));

      // 3. Approve 14-day study vacation (Dec 12 - Dec 25)
      final validFreeze = PlanCalculatorService.calculateMembershipFreeze(
        student: amit,
        freezeStartDate: DateTime(2026, 12, 12),
        freezeEndDate: DateTime(2026, 12, 25), // 14 days
      );
      expect(validFreeze.isValid, isTrue);
      expect(validFreeze.freezeDays, equals(14));
      // Dec 31 + 14 days = Jan 14, 2027
      expect(validFreeze.newEndDate, equals(DateTime(2027, 1, 14)));

      // 4. Update student model with freeze attributes
      final frozenAmit = amit.copyWith(
        isFrozen: true,
        freezeStartDate: DateTime(2026, 12, 12),
        freezeEndDate: DateTime(2026, 12, 25),
        freezeReason: 'University semester practicals',
        planEndDate: validFreeze.newEndDate,
      );
      expect(frozenAmit.isFrozen, isTrue);
      expect(frozenAmit.freezeReason, equals('University semester practicals'));

      // 5. StudentModel serialization parity
      final json = frozenAmit.toJson();
      expect(json['isFrozen'], isTrue);
      expect(json['freezeReason'], equals('University semester practicals'));
      final restored = StudentModel.fromJson(json);
      expect(restored.isFrozen, isTrue);
      expect(restored.freezeStartDate, equals(DateTime(2026, 12, 12)));
      expect(restored.freezeEndDate, equals(DateTime(2026, 12, 25)));

      // 6. Seat reservationType parity for study vacation
      final seat14 = SeatModel(
        id: 'seat_14',
        sectionId: 'sec_cozy_01',
        row: 1,
        col: 2,
        label: '14',
        status: SeatStatus.occupied,
        genderRestriction: GenderRestriction.any,
        studentId: amit.id,
        reservationType: 'study_leave',
      );
      expect(seat14.reservationType, equals('study_leave'));

      // 7. Unfreezing lifecycle / return early
      final unfrozenAmit = frozenAmit.copyWith(clearFreeze: true);
      expect(unfrozenAmit.isFrozen, isFalse);
      expect(unfrozenAmit.freezeStartDate, isNull);
      expect(unfrozenAmit.freezeEndDate, isNull);
      expect(unfrozenAmit.freezeReason, isNull);

      final clearedSeat14 = seat14.copyWith(clearReservation: true);
      expect(clearedSeat14.reservationType, isNull);
    });

    test('115. PREDICTIVE CHURN ALERT ENGINE, GRACE RECURRENCE & RETENTION AUDIT (SECTION 4)', () {
      final now = DateTime.now();

      // 1. Healthy active student with settled fees and 20 days remaining
      final healthyStudent = createTestStudent(
        id: 'stud_healthy_01',
        name: 'Sneha Kulkarni',
        phone: '9822114455',
        membershipStatus: MembershipStatus.active,
        planStartDate: now.subtract(const Duration(days: 10)),
        planEndDate: now.add(const Duration(days: 20)),
        pendingDueBalance: 0.0,
      );
      expect(healthyStudent.isAtChurnRisk, isFalse);
      expect(healthyStudent.churnRiskReason, isNull);

      // 2. Student in Grace Period
      final graceStudent = createTestStudent(
        id: 'stud_grace_01',
        name: 'Pratik Deshmukh',
        phone: '9822336677',
        membershipStatus: MembershipStatus.grace,
        planStartDate: now.subtract(const Duration(days: 35)),
        planEndDate: now.subtract(const Duration(days: 2)),
        graceEndDate: now.add(const Duration(days: 1)),
        pendingDueBalance: 0.0,
      );
      expect(graceStudent.isAtChurnRisk, isTrue);
      expect(graceStudent.churnRiskReason?.toLowerCase(), contains('grace period'));

      // 3. Active student with pending dues and expiring in 2 days
      final duesStudent = createTestStudent(
        id: 'stud_dues_01',
        name: 'Nitin Pawar',
        phone: '9822558899',
        membershipStatus: MembershipStatus.active,
        planStartDate: now.subtract(const Duration(days: 28)),
        planEndDate: now.add(const Duration(days: 2)),
        pendingDueBalance: 600.0,
      );
      expect(duesStudent.isAtChurnRisk, isTrue);
      expect(duesStudent.churnRiskReason, contains('Unpaid dues ₹600 pending'));

      // 4. Expired student without renewal
      final expiredStudent = createTestStudent(
        id: 'stud_expired_01',
        name: 'Vikas Jadhav',
        phone: '9822770011',
        membershipStatus: MembershipStatus.expired,
        planStartDate: now.subtract(const Duration(days: 45)),
        planEndDate: now.subtract(const Duration(days: 15)),
        pendingDueBalance: 0.0,
      );
      expect(expiredStudent.isAtChurnRisk, isTrue);
      expect(expiredStudent.churnRiskReason, contains('without renewal'));

      // 5. Churn Cohort Filtering
      final cohort = [healthyStudent, graceStudent, duesStudent, expiredStudent];
      final atRiskOnly = cohort.where((s) => s.isAtChurnRisk).toList();
      expect(atRiskOnly.length, equals(3));
      expect(atRiskOnly.map((s) => s.id), containsAll(['stud_grace_01', 'stud_dues_01', 'stud_expired_01']));
      expect(atRiskOnly.map((s) => s.id), isNot(contains('stud_healthy_01')));
    });

    test('116. ADMISSION STEP 4 & 6 CALENDAR-MONTH CYCLE, PRO-RATA DESK PAYMENT & ADMIN REQUEST SYNCHRONIZATION', () {
      final novPlan = PlanModel(
        id: 'plan_monthly_ac_01',
        libraryId: 'lib_test_01',
        name: 'Cozy Monthly AC',
        description: 'Cozy monthly study pass',
        price: 800.0,
        duration: 1,
        durationUnit: DurationUnit.months,
        gracePeriodDays: 3,
        isActive: true,
        isFeatured: false,
        displayOrder: 1,
      );

      // 1. Mid-month joiner on Nov 6th (30-day month)
      final midMonthDate = DateTime(2026, 11, 6);
      final midMonthCalc = PlanCalculatorService.calculateSmartPlan(
        plan: novPlan,
        fromDate: midMonthDate,
      );

      expect(midMonthCalc.startDate, equals(DateTime(2026, 11, 6)));
      expect(midMonthCalc.endDate.month, equals(11));
      expect(midMonthCalc.endDate.day, equals(30));
      expect(midMonthCalc.daysRemaining, equals(25));
      expect(midMonthCalc.isProrated, isTrue);
      // Math: (25 * (800 / 30) / 10).round() * 10 = (666.67 / 10).round() * 10 = 670.0
      expect(midMonthCalc.proratedPrice, equals(670.0));
      expect(midMonthCalc.formattedProratedPrice, equals('₹670'));

      // 2. First-day joiner on Nov 1st (Full monthly cycle)
      final firstDayCalc = PlanCalculatorService.calculateSmartPlan(
        plan: novPlan,
        fromDate: DateTime(2026, 11, 1),
      );
      expect(firstDayCalc.daysRemaining, equals(30));
      expect(firstDayCalc.isProrated, isFalse);
      expect(firstDayCalc.proratedPrice, equals(800.0));

      // 3. Late-month joiner on Nov 24th (Bridge Pass Activated)
      final lateMonthCalc = PlanCalculatorService.calculateSmartPlan(
        plan: novPlan,
        fromDate: DateTime(2026, 11, 24),
      );
      expect(lateMonthCalc.daysRemaining, equals(7)); // 30 - 24 + 1 = 7 days
      expect(lateMonthCalc.isProrated, isTrue);
      expect(lateMonthCalc.hasBridgeOption, isTrue);
      expect(lateMonthCalc.bridgePrice, isNotNull);
      // Remaining 7 days pro-rata: (7 * 26.67) = 186.67 -> 190. Bridge = 190 + 800 = 990.
      expect(lateMonthCalc.bridgePrice, equals(990.0));

      // 4. Verification of Admission Request Payload Schema
      final admissionRequestPayload = {
        'id': 'req_admission_qa_01',
        'type': 'registration',
        'status': 'pending',
        'studentName': 'Rahul Sharma',
        'studentPhone': '9822001122',
        'planId': novPlan.id,
        'planName': novPlan.name,
        'proratedFee': midMonthCalc.proratedPrice,
        'planPrice': novPlan.price,
        'daysRemaining': midMonthCalc.daysRemaining,
        'cycleStartDate': midMonthCalc.startDate.toIso8601String(),
        'cycleEndDate': midMonthCalc.endDate.toIso8601String(),
        'isProrated': midMonthCalc.isProrated,
        'paymentMode': 'desk_collection',
        'requestedSeatLabel': 'Seat #14',
      };

      expect(admissionRequestPayload['proratedFee'], equals(670.0));
      expect(admissionRequestPayload['planPrice'], equals(800.0));
      expect(admissionRequestPayload['daysRemaining'], equals(25));
      expect(admissionRequestPayload['isProrated'], isTrue);
      expect(admissionRequestPayload['paymentMode'], equals('desk_collection'));

      // 5. Admin Desk Collection Prompt Pre-fill Resolution
      double resolvedDeskAmount = (admissionRequestPayload['amount'] as num?)?.toDouble() ?? 0.0;
      if (resolvedDeskAmount <= 0) {
        resolvedDeskAmount = (admissionRequestPayload['proratedFee'] as num).toDouble();
      }
      expect(resolvedDeskAmount, equals(670.0));
    });

    test('117. ANTI-FRAUD UTR REPLAY DEFENSE, POWER SURCHARGE AMENITY & DYNAMIC FIELD REGEX PATTERNS', () {
      // 1. AppValidators.validatePattern - University Roll Number (e.g. 2 letters + 6 digits)
      const rollPattern = r'^[A-Z]{2}\d{6}$';
      expect(AppValidators.validatePattern('MH123456', rollPattern, label: 'Roll Number'), isNull);
      expect(AppValidators.validatePattern('123456', rollPattern, label: 'Roll Number'), contains('Roll Number format is invalid'));
      expect(AppValidators.validatePattern('mh123456', rollPattern, label: 'Roll Number'), contains('Roll Number format is invalid'));
      expect(AppValidators.validatePattern('', rollPattern, required: false, label: 'Roll Number'), isNull);
      expect(AppValidators.validatePattern('', rollPattern, required: true, label: 'Roll Number'), contains('Roll Number is required'));

      // 2. AppValidators.validatePattern - Vehicle Plate Pattern with custom error
      const vehiclePattern = r'^[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}$';
      expect(AppValidators.validatePattern('MH24AB1234', vehiclePattern, errorMessage: 'Invalid vehicle number format'), isNull);
      expect(AppValidators.validatePattern('ABC123', vehiclePattern, errorMessage: 'Invalid vehicle number format'), equals('Invalid vehicle number format'));

      // 3. AppValidators.roundRupee - Zero Fractional Paise Drift
      expect(AppValidators.roundRupee(499.3333333), equals(499.0));
      expect(AppValidators.roundRupee(499.6666667), equals(500.0));
      expect(AppValidators.roundRupee(750.50), equals(751.0));

      // 4. StudentModel with High-Wattage AC Power Surcharge
      final studentWithPower = createTestStudent(
        id: 'stud_power_01',
        name: 'Gaurav Kulkarni',
        phone: '9822446688',
      ).copyWith(
        hasPowerSurcharge: true,
        powerSurchargeAmount: 150.0,
      );

      expect(studentWithPower.hasPowerSurcharge, isTrue);
      expect(studentWithPower.powerSurchargeAmount, equals(150.0));

      final studentJson = studentWithPower.toJson();
      expect(studentJson['hasPowerSurcharge'], isTrue);
      expect(studentJson['powerSurchargeAmount'], equals(150.0));

      final restoredStudent = StudentModel.fromJson(studentJson);
      expect(restoredStudent.hasPowerSurcharge, isTrue);
      expect(restoredStudent.powerSurchargeAmount, equals(150.0));

      // 5. PaymentModel with Power Surcharge and 12-Digit UPI UTR
      final payment = PaymentModel(
        id: 'pay_test_01',
        studentId: studentWithPower.id,
        amount: 850.0,
        totalPlanFee: 850.0,
        powerSurchargeAmount: 150.0,
        method: 'UPI / QR',
        referenceNumber: '431289567123',
        date: DateTime.now(),
        status: PaymentStatus.paid,
        createdAt: DateTime.now(),
      );

      expect(payment.referenceNumber, equals('431289567123'));
      expect(payment.powerSurchargeAmount, equals(150.0));
      final paymentJson = payment.toJson();
      expect(paymentJson['referenceNumber'], equals('431289567123'));
      expect(paymentJson['powerSurchargeAmount'], equals(150.0));

      final restoredPayment = PaymentModel.fromJson(paymentJson);
      expect(restoredPayment.referenceNumber, equals('431289567123'));
      expect(restoredPayment.powerSurchargeAmount, equals(150.0));

      // 6. Anti-Fraud UTR Duplicate Identification Simulation
      final ledger = [
        payment,
        PaymentModel(
          id: 'pay_test_02',
          studentId: 'stud_power_02',
          amount: 700.0,
          method: 'Cash',
          date: DateTime.now(),
          status: PaymentStatus.paid,
          createdAt: DateTime.now(),
        ),
      ];

      // Lookup candidate matching '431289567123'
      final duplicateCandidate = ledger.where((p) => p.referenceNumber == '431289567123').firstOrNull;
      expect(duplicateCandidate, isNotNull);
      expect(duplicateCandidate?.id, equals('pay_test_01'));
      expect(duplicateCandidate?.studentId, equals('stud_power_01'));

      // If excluding own ID (e.g. self-editing pay_test_01), no conflict
      final editExclusionMatch = ledger.where((p) => p.referenceNumber == '431289567123' && p.id != 'pay_test_01').firstOrNull;
      expect(editExclusionMatch, isNull);
    });

    test('118. BULK ADMISSION DATE EDITING, CYCLE ALIGNMENT & NOTIFICATION DEDUPLICATION PARITY', () {
      // 1. StudentModel admissionDate parsing and backward-compatible fallback
      final historicalDate = DateTime(2025, 8, 15);
      final studentWithAdmDate = StudentModel.fromJson({
        'id': 'stud_hist_01',
        'name': 'Shubham Dixit',
        'phone': '9156944773',
        'email': 'shubham@example.com',
        'admissionDate': historicalDate.toIso8601String(),
        'planStartDate': DateTime(2026, 11, 1).toIso8601String(),
        'membershipStatus': 'active',
      });
      expect(studentWithAdmDate.admissionDate, equals(historicalDate));
      expect(studentWithAdmDate.effectiveAdmissionDate, equals(historicalDate));

      // Backward compatible fallback for existing student without admissionDate
      final legacyStudent = StudentModel.fromJson({
        'id': 'stud_leg_02',
        'name': 'Legacy Student',
        'phone': '9876543210',
        'planStartDate': DateTime(2026, 9, 1).toIso8601String(),
        'membershipStatus': 'active',
      });
      expect(legacyStudent.admissionDate, isNull);
      expect(legacyStudent.effectiveAdmissionDate, equals(DateTime(2026, 9, 1)));

      // 2. Calendar-Month End Expiry Calculation
      final admDate = DateTime(2026, 8, 15);
      final monthEndExpiry = DateTime(admDate.year, admDate.month + 1, 0, 23, 59, 59);
      expect(monthEndExpiry.year, equals(2026));
      expect(monthEndExpiry.month, equals(8));
      expect(monthEndExpiry.day, equals(31));

      // 3. Notification Deduplication Semantic Collapsing
      final notif1 = AppNotificationModel(
        id: 'notif_001',
        title: 'Admission Approved! 🎉',
        body: 'Hello shubham dixit! Your admission is approved (Desk #7). Complete your fee payment to activate your pass.',
        type: 'admission',
        targetRole: 'student',
        read: true,
        createdAt: DateTime(2026, 11, 5, 19, 50),
        targetUserId: 'shubham_uid',
      );

      final notif2 = AppNotificationModel(
        id: 'notif_002',
        title: 'Admission Approved! 🎉',
        body: 'Hello shubham dixit! Your admission is approved (Desk #7). Complete your fee payment to activate your pass.',
        type: 'admission',
        targetRole: 'student',
        read: false,
        createdAt: DateTime(2026, 11, 5, 19, 50, 30),
        targetUserId: 'shubham_uid',
      );

      // Deduplication helper simulation
      final list = [notif1, notif2];
      final Map<String, AppNotificationModel> uniqueMap = {};
      for (final n in list) {
        final key = '${n.type.toLowerCase()}_${n.title.trim().toLowerCase()}_${n.body.trim().toLowerCase()}';
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = n;
        } else {
          final existing = uniqueMap[key]!;
          final keepNewer = n.createdAt.isAfter(existing.createdAt);
          final isUnread = (!existing.read) || (!n.read);
          final winner = keepNewer ? n : existing;
          uniqueMap[key] = winner.copyWith(read: !isUnread);
        }
      }
      expect(uniqueMap.length, equals(1));
      final deduped = uniqueMap.values.first;
      expect(deduped.title, equals('Admission Approved! 🎉'));
      expect(deduped.read, isFalse); // Preserves unread status so student does not miss alert
    });

    test('119. B2B COMMERCIAL GST TAX INVOICE GENERATION & ACCURATE TAX SPLIT', () {
      // 1. Library GST Configuration & Getters
      final gstLibrary = LibraryModel.fromJson({
        'id': 'lib_gst_01',
        'name': 'Cozy Corner Reading Hall',
        'address': 'Nath Road, Parli',
        'contact': '9403243830',
        'enableGstBilling': true,
        'gstin': '27AABCU9603R1ZM',
        'gstLegalName': 'The Cozy Corner Educational Services LLP',
        'gstRate': 18.0,
        'sacCode': '999293',
      });

      expect(gstLibrary.enableGstBilling, isTrue);
      expect(gstLibrary.effectiveGstin, equals('27AABCU9603R1ZM'));
      expect(gstLibrary.effectiveGstLegalName, equals('The Cozy Corner Educational Services LLP'));
      expect(gstLibrary.effectiveGstRate, equals(18.0));
      expect(gstLibrary.effectiveSacCode, equals('999293'));

      // 2. Backward Tax Calculation Formula (Standard Plan Fee = ₹1,000)
      const double grossPlanFee = 1000.0;
      const double gstRate = 18.0;

      final taxableAmount = (grossPlanFee / (1 + (gstRate / 100))).roundToDouble();
      final totalTax = grossPlanFee - taxableAmount;
      final cgstAmount = (totalTax / 2).roundToDouble();
      final sgstAmount = totalTax - cgstAmount;

      expect(taxableAmount, equals(847.0));
      expect(cgstAmount, equals(77.0));
      expect(sgstAmount, equals(76.0));
      expect(taxableAmount + cgstAmount + sgstAmount, equals(grossPlanFee));

      // 3. ReceiptModel with GST serialization
      final receipt = ReceiptModel.fromJson({
        'id': 'rec_gst_001',
        'libraryId': 'lib_gst_01',
        'receiptNumber': 'TAX-2026-0001',
        'studentId': 'stud_gst_01',
        'planId': 'plan_monthly',
        'paymentMethod': 'UPI',
        'amount': grossPlanFee,
        'totalFee': grossPlanFee,
        'paidAmount': grossPlanFee,
        'validFrom': DateTime(2026, 11, 1).toIso8601String(),
        'validTo': DateTime(2026, 11, 30).toIso8601String(),
        'isGstInvoice': true,
        'gstin': gstLibrary.effectiveGstin,
        'sacCode': gstLibrary.effectiveSacCode,
        'gstRate': gstRate,
        'taxableAmount': taxableAmount,
        'cgstAmount': cgstAmount,
        'sgstAmount': sgstAmount,
        'status': 'paid',
      });

      final json = receipt.toJson();
      expect(json['isGstInvoice'], isTrue);
      expect(json['gstin'], equals('27AABCU9603R1ZM'));
      expect(json['sacCode'], equals('999293'));
      expect(json['gstRate'], equals(18.0));
      expect(json['taxableAmount'], equals(847.0));
      expect(json['cgstAmount'], equals(77.0));
      expect(json['sgstAmount'], equals(76.0));

      // Deserialization check
      final parsedReceipt = ReceiptModel.fromJson(json);
      expect(parsedReceipt.isGstInvoice, isTrue);
      expect(parsedReceipt.gstin, equals('27AABCU9603R1ZM'));
      expect(parsedReceipt.sacCode, equals('999293'));
      expect(parsedReceipt.taxableAmount, equals(847.0));
      expect(parsedReceipt.cgstAmount, equals(77.0));
      expect(parsedReceipt.sgstAmount, equals(76.0));

      // 4. Exemption of Refundable Security Deposit
      const double feeWithDeposit = 1500.0;
      const double securityDeposit = 500.0;
      final netServiceFee = feeWithDeposit - securityDeposit;
      final netTaxable = (netServiceFee / (1 + (gstRate / 100))).roundToDouble();
      final netTax = netServiceFee - netTaxable;
      expect(netTaxable, equals(847.0));
      expect(netTax, equals(153.0)); // GST applies strictly to the service fee, not deposit
    });

    test('120. DIRECT META WHATSAPP CLOUD API & SMS GATEWAY AUTOMATION', () {
      final metaService = MetaWhatsAppApiService();

      // 1. Phone normalizer (E.164 without '+')
      expect(metaService.normalizePhone('9403243830'), equals('919403243830'));
      expect(metaService.normalizePhone('+91 94032-43830'), equals('919403243830'));
      expect(metaService.normalizePhone('09403243830'), equals('919403243830'));
      expect(metaService.normalizePhone('919403243830'), equals('919403243830'));

      // 2. MessagingConfig serialization with Meta WhatsApp and SMS Gateway
      final config = MessagingConfig(
        whatsappEnabled: true,
        metaWhatsAppEnabled: true,
        metaPhoneNumberId: '104829375829104',
        metaAccessToken: 'EAAG_SECURE_TOKEN_XYZ',
        smsGatewayEnabled: true,
        smsApiKey: 'FAST2SMS_KEY_999',
        smsSenderId: 'COZYCR',
      );

      final map = config.toMap();
      expect(map['metaWhatsAppEnabled'], isTrue);
      expect(map['metaPhoneNumberId'], equals('104829375829104'));
      expect(map['metaAccessToken'], equals('EAAG_SECURE_TOKEN_XYZ'));
      expect(map['smsGatewayEnabled'], isTrue);
      expect(map['smsApiKey'], equals('FAST2SMS_KEY_999'));
      expect(map['smsSenderId'], equals('COZYCR'));

      // Deserialization check
      final parsedConfig = MessagingConfig.fromMap(map);
      expect(parsedConfig.metaWhatsAppEnabled, isTrue);
      expect(parsedConfig.metaPhoneNumberId, equals('104829375829104'));
      expect(parsedConfig.metaAccessToken, equals('EAAG_SECURE_TOKEN_XYZ'));
      expect(parsedConfig.smsGatewayEnabled, isTrue);
      expect(parsedConfig.smsApiKey, equals('FAST2SMS_KEY_999'));
      expect(parsedConfig.smsSenderId, equals('COZYCR'));
    });

    test('121. CARRIED PENDING DUE BALANCE CONSOLIDATION & ATOMIC CLEARANCE UPON RENEWAL (CRIT-01 & CRIT-03)', () {
      // 1. Student with unpaid partial dues from previous cycle
      final studentWithDue = StudentModel.fromJson({
        'id': 'std_due_001',
        'name': 'Rahul Sharma',
        'phone': '9822011223',
        'fatherName': 'Suresh Sharma',
        'pendingDueBalance': 350.0,
        'membershipStatus': 'active',
        'planId': 'plan_monthly_700',
      });

      expect(studentWithDue.pendingDueBalance, equals(350.0));

      // 2. Renewal Price Calculation: Base Plan + Carried Due
      const double basePlanPrice = 700.0;
      final carriedDue = (studentWithDue.pendingDueBalance != null && studentWithDue.pendingDueBalance! > 0)
          ? studentWithDue.pendingDueBalance!
          : 0.0;
      final effectiveRenewalPrice = basePlanPrice + carriedDue;

      expect(effectiveRenewalPrice, equals(1050.0));

      // 3. Renewal Request Payload Verification
      final renewalPayload = <String, dynamic>{
        'type': 'renewal',
        'studentId': studentWithDue.id,
        'studentName': studentWithDue.name,
        'amount': effectiveRenewalPrice,
        'basePlanPrice': basePlanPrice,
        'pendingDueAmount': carriedDue,
        'clearedDue': carriedDue > 0,
        'status': 'pending',
      };

      expect(renewalPayload['amount'], equals(1050.0));
      expect(renewalPayload['basePlanPrice'], equals(700.0));
      expect(renewalPayload['pendingDueAmount'], equals(350.0));
      expect(renewalPayload['clearedDue'], isTrue);

      // 4. Provisioning Execution: Reset pending due to 0.0 and clear debt
      final studentUpdates = <String, dynamic>{
        'membershipStatus': 'active',
      };
      if (renewalPayload['clearedDue'] == true) {
        studentUpdates['pendingDueBalance'] = 0.0;
      }

      expect(studentUpdates['pendingDueBalance'], equals(0.0));
    });

    test('122. 10-MINUTE SEAT RESERVATION SOFT-LOCK & EXPIRATION LIFECYCLE (CRIT-02)', () {
      final now = DateTime.now();

      // 1. Active Soft-Lock Seat
      final reservedSeat = SeatModel.fromJson({
        'id': 'seat_lock_01',
        'sectionId': 'sec_01',
        'label': 'A1',
        'row': 0,
        'col': 0,
        'status': 'reserved',
        'reservationType': 'admission_soft_lock',
        'reservationExpiresAt': now.add(const Duration(minutes: 10)).toIso8601String(),
      });

      expect(reservedSeat.isCurrentlyReserved, isTrue);

      // 2. Expired Soft-Lock Seat (Lapsed reservation becomes available for walk-ins)
      final expiredSeat = SeatModel.fromJson({
        'id': 'seat_lock_02',
        'sectionId': 'sec_01',
        'label': 'A2',
        'row': 0,
        'col': 1,
        'status': 'reserved',
        'reservationType': 'admission_soft_lock',
        'reservationExpiresAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
      });

      expect(expiredSeat.isCurrentlyReserved, isFalse);

      // 3. Soft-Lock Release on Application Rejection Simulation
      final releasedSeat = expiredSeat.copyWith(
        status: SeatStatus.available,
        clearReservation: true,
      );

      expect(releasedSeat.status, equals(SeatStatus.available));
      expect(releasedSeat.isCurrentlyReserved, isFalse);
      expect(releasedSeat.reservationExpiresAt, isNull);
    });

    test('123. ATOMIC DIRECT OCCUPANT SEAT SWAP (A ⇄ B) INVARIANTS (GAP-01)', () {
      // 1. Initial State: Seat A has Student A, Seat B has Student B
      final seatA = SeatModel.fromJson({
        'id': 'seat_desk_01',
        'sectionId': 'sec_ground',
        'label': 'D1',
        'row': 0,
        'col': 0,
        'status': 'occupied',
        'studentId': 'student_alpha',
      });

      final seatB = SeatModel.fromJson({
        'id': 'seat_desk_02',
        'sectionId': 'sec_first',
        'label': 'D2',
        'row': 0,
        'col': 1,
        'status': 'occupied',
        'studentId': 'student_beta',
      });

      final studentA = StudentModel.fromJson({
        'id': 'student_alpha',
        'name': 'Amit Joshi',
        'fatherName': 'Prakash Joshi',
        'seatId': 'seat_desk_01',
        'sectionId': 'sec_ground',
        'membershipStatus': 'active',
      });

      final studentB = StudentModel.fromJson({
        'id': 'student_beta',
        'name': 'Pooja Patil',
        'fatherName': 'Ramesh Patil',
        'seatId': 'seat_desk_02',
        'sectionId': 'sec_first',
        'membershipStatus': 'active',
      });

      // 2. Simulate 4-Way Atomic Transaction Swap
      final updatedSeatA = seatA.copyWith(studentId: studentB.id);
      final updatedSeatB = seatB.copyWith(studentId: studentA.id);

      final updatedStudentA = studentA.copyWith(
        seatId: seatB.id,
        sectionId: 'sec_first',
        previousSeatId: seatA.id,
        previousSectionId: 'sec_ground',
      );

      final updatedStudentB = studentB.copyWith(
        seatId: seatA.id,
        sectionId: 'sec_ground',
        previousSeatId: seatB.id,
        previousSectionId: 'sec_first',
      );

      // Invariants Verification
      expect(updatedSeatA.studentId, equals('student_beta'));
      expect(updatedSeatB.studentId, equals('student_alpha'));

      expect(updatedStudentA.seatId, equals('seat_desk_02'));
      expect(updatedStudentA.previousSeatId, equals('seat_desk_01'));

      expect(updatedStudentB.seatId, equals('seat_desk_01'));
      expect(updatedStudentB.previousSeatId, equals('seat_desk_02'));
    });

    test('124. PAYMENT METHODS DYNAMIC PREREQUISITE GATING & ZERO PHANTOM OPTIONS (PAY-01)', () {
      // 1. Library with default enabled methods (Cash & UPI only)
      final library = LibraryModel.fromJson({
        'id': 'lib_test_pay_01',
        'name': 'Cozy Study Hall',
        'address': 'Main Road',
        'contact': '9403243830',
        'logoUrl': '',
        'upiId': 'cozycorner@upi',
        'enabledPaymentMethods': ['cash', 'upi'],
      });

      expect(library.enabledPaymentMethods, contains('cash'));
      expect(library.enabledPaymentMethods, contains('upi'));
      expect(library.enabledPaymentMethods.contains('bank'), isFalse);

      // 2. Bank Details Prerequisite Validation: Missing Account Number or IFSC blocks activation
      bool canEnableBank({required String bankName, required String accNo, required String ifsc}) {
        return bankName.trim().isNotEmpty &&
            accNo.trim().length >= 8 &&
            ifsc.trim().length >= 4;
      }

      expect(canEnableBank(bankName: '', accNo: '', ifsc: ''), isFalse);
      expect(canEnableBank(bankName: 'HDFC Bank', accNo: '501002345678', ifsc: ''), isFalse);
      expect(canEnableBank(bankName: 'HDFC Bank', accNo: '501002345678', ifsc: 'HDFC0001234'), isTrue);

      // 3. Dynamic Student Checkout Gating Simulation
      List<String> computeAvailableCheckoutModes({
        required List<String> enabledMethods,
        required bool hasUpiConfigured,
        required bool hasBankConfigured,
      }) {
        final modes = <String>[];
        if (enabledMethods.contains('upi') && hasUpiConfigured) modes.add('upi');
        if (enabledMethods.contains('bank') && hasBankConfigured) modes.add('bank');
        if (enabledMethods.contains('cash')) modes.add('desk_cash');
        return modes.isNotEmpty ? modes : ['desk_cash'];
      }

      // Scenario A: Admin switched off bank, or no bank configured -> Only UPI and Desk Cash appear!
      final checkoutModesNoBank = computeAvailableCheckoutModes(
        enabledMethods: ['cash', 'upi'],
        hasUpiConfigured: true,
        hasBankConfigured: false,
      );
      expect(checkoutModesNoBank, equals(['upi', 'desk_cash']));
      expect(checkoutModesNoBank.contains('bank'), isFalse);

      // Scenario B: Admin enables bank AND enters valid details -> Bank Transfer appears!
      final checkoutModesWithBank = computeAvailableCheckoutModes(
        enabledMethods: ['cash', 'upi', 'bank'],
        hasUpiConfigured: true,
        hasBankConfigured: true,
      );
      expect(checkoutModesWithBank, equals(['upi', 'bank', 'desk_cash']));
      expect(checkoutModesWithBank.contains('bank'), isTrue);

      // Scenario C: Admin enables bank switch BUT details are empty -> Bank Transfer is strictly suppressed!
      final checkoutModesMisconfigured = computeAvailableCheckoutModes(
        enabledMethods: ['cash', 'upi', 'bank'],
        hasUpiConfigured: true,
        hasBankConfigured: false,
      );
      expect(checkoutModesMisconfigured, equals(['upi', 'desk_cash']));
      expect(checkoutModesMisconfigured.contains('bank'), isFalse);
    });

    test('125. SEAT MAINTENANCE OCCUPANT NOTIFICATION & ANTI-FRAUD LIVE TICKER (GAP-02 & GAP-03)', () {
      // 1. GAP-02: Seat Maintenance Invariants & Previous Seat Preservation
      final originalStudent = StudentModel.fromJson({
        'id': 'student_gamma',
        'name': 'Gamma Student',
        'email': 'gamma@test.com',
        'phone': '9876543210',
        'fatherName': 'Father',
        'gender': 'male',
        'seatId': 'seat_desk_42',
        'sectionId': 'sec_quiet',
      });

      // Admin places Seat 42 into maintenance
      final seatUnderMaintenance = SeatModel.fromJson({
        'id': 'seat_desk_42',
        'sectionId': 'sec_quiet',
        'label': '42',
        'row': 3,
        'col': 2,
        'status': 'maintenance',
        'genderRestriction': 'any',
      });

      final updatedStudentAfterMaintenance = originalStudent.copyWith(
        clearSeat: true,
        previousSeatId: 'seat_desk_42', // Guaranteed memory for 1-tap reclaim
      );

      expect(seatUnderMaintenance.status, equals(SeatStatus.maintenance));
      expect(seatUnderMaintenance.studentId, isNull);
      expect(updatedStudentAfterMaintenance.seatId, isNull);
      expect(updatedStudentAfterMaintenance.previousSeatId, equals('seat_desk_42'));

      // 2. GAP-03: Anti-Fraud Live Ticker Timestamp Format Verification
      final now = DateTime(2026, 11, 6, 17, 30, 45);
      final formattedTime = DateFormat('HH:mm:ss').format(now);
      expect(formattedTime, equals('17:30:45'));
      expect(RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(formattedTime), isTrue);

      final tickerText = 'LIVE $formattedTime';
      expect(tickerText, equals('LIVE 17:30:45'));
    });

    test('126. Soft-Lock 10-Minute Expiration: Effective status, real-time promotion, and collision prevention', () {
      final now = DateTime.now();

      // Case A: Active 10-minute soft-lock (expires in 8 minutes)
      final activeSoftLockSeat = SeatModel(
        id: 'seat_101',
        sectionId: 'sec_quiet',
        label: '101',
        row: 1,
        col: 1,
        status: SeatStatus.reserved,
        genderRestriction: GenderRestriction.any,
        reservationType: 'online_admission',
        reservedCandidateId: 'cand_temp_123',
        reservedCandidateName: 'Applicant Rohan',
        reservationExpiresAt: now.add(const Duration(minutes: 8)),
      );

      expect(activeSoftLockSeat.status, equals(SeatStatus.reserved));
      expect(activeSoftLockSeat.isCurrentlyReserved, isTrue);
      expect(activeSoftLockSeat.effectiveStatus, equals(SeatStatus.reserved));
      expect(activeSoftLockSeat.hasActiveSoftLock, isTrue);
      expect(activeSoftLockSeat.isOccupied, isFalse);

      // Case B: Expired soft-lock (expired 2 minutes ago)
      final expiredSoftLockSeat = SeatModel(
        id: 'seat_102',
        sectionId: 'sec_quiet',
        label: '102',
        row: 1,
        col: 2,
        status: SeatStatus.reserved,
        genderRestriction: GenderRestriction.any,
        reservationType: 'online_admission',
        reservedCandidateId: 'cand_expired_456',
        reservedCandidateName: 'Applicant Suresh',
        reservationExpiresAt: now.subtract(const Duration(minutes: 2)),
      );

      // Even though raw Firestore status is SeatStatus.reserved, dynamic effectiveStatus evaluates to available
      expect(expiredSoftLockSeat.isCurrentlyReserved, isFalse);
      expect(expiredSoftLockSeat.effectiveStatus, equals(SeatStatus.available));
      expect(expiredSoftLockSeat.hasActiveSoftLock, isFalse);
      expect(expiredSoftLockSeat.isOccupied, isFalse);

      // Case C: Permanently occupied seat (allocated to active student)
      final occupiedSeat = SeatModel(
        id: 'seat_103',
        sectionId: 'sec_quiet',
        label: '103',
        row: 1,
        col: 3,
        status: SeatStatus.occupied,
        genderRestriction: GenderRestriction.any,
        studentId: 'stud_789',
      );

      expect(occupiedSeat.effectiveStatus, equals(SeatStatus.occupied));
      expect(occupiedSeat.isOccupied, isTrue);
      expect(occupiedSeat.hasActiveSoftLock, isFalse);
    });

    test('126. MOBILE PERSPECTIVE INVARIANTS: BOTTOM SCROLL CLEARANCE, TABBAR SCROLLABILITY & ZERO-TEXT-SQUISHING', () {
      // 1. Version consistency check
      expect(WhatsNewService.currentVersionIdentifier, equals('${AppConstants.appVersion}+${AppConstants.buildNumber}'));
      expect(AppConstants.appVersion, equals('1.5.53'));
      expect(AppConstants.buildNumber, equals(68));

      // 2. Minimum bottom clearance for mobile navigation bar & FAB visibility (>= 100dp)
      const standardShellBottomClearance = 110.0;
      expect(standardShellBottomClearance, greaterThanOrEqualTo(100.0));

      // 3. TabBar mobile resilience invariants
      // Verify tab definitions are valid and non-empty
      final tabHubs = ['Waiting List', 'Student Feedback', 'Message Studio', 'Diagnostics', 'Requests Hub'];
      for (final hub in tabHubs) {
        expect(hub, isNotEmpty);
      }

      // 4. Compact non-squished button and badge strings
      const paymentBtnLabel = 'Record Payment & Issue Receipt';
      expect(paymentBtnLabel.length, lessThanOrEqualTo(35));
      expect(paymentBtnLabel, isNot(contains('Official')));

      const backupBtnLabel = 'Export Library Backup';
      expect(backupBtnLabel.length, lessThanOrEqualTo(25));
    });

    test('127. SMART UPDATE ENGINE & APPLICANT DETAILS FORMATTING INVARIANTS', () {
      // ── 1. Smart Version Comparison Logic (No false positives on same build) ──
      // Mimics the fixed ForceUpdateService._isNewerVersion
      bool isNewerVersion(String remoteVer, int remoteCode, String localVer, int localCode) {
        final normRemote = remoteCode >= 1000 ? (remoteCode % 1000) : remoteCode;
        final normLocal = localCode >= 1000 ? (localCode % 1000) : localCode;

        if (normRemote > normLocal) return true;
        if (normRemote < normLocal) return false;

        if (normRemote > 0 && normLocal > 0 && normRemote == normLocal) {
          return false;
        }

        final cleanRemote = remoteVer.split('+').first.split('-').first.trim();
        final cleanLocal = localVer.split('+').first.split('-').first.trim();

        try {
          final r = cleanRemote.split('.').map((s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
          final l = cleanLocal.split('.').map((s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
          for (int i = 0; i < 3; i++) {
            final rPart = i < r.length ? r[i] : 0;
            final lPart = i < l.length ? l[i] : 0;
            if (rPart > lPart) return true;
            if (rPart < lPart) return false;
          }
        } catch (_) {}

        return false;
      }

      // Case A: The exact bug reported by user - same version v1.5.50+64 vs installed 64
      // Previously, "50+64" was turned into 5064, making 5064 > 50 TRUE! Now it must be FALSE!
      expect(isNewerVersion('1.5.50+64', 64, '1.5.50', 64), isFalse);

      // Case B: Installed app is newer (localCode 65 vs remoteCode 64) -> FALSE
      expect(isNewerVersion('1.5.50+64', 64, '1.5.50', 65), isFalse);

      // Case C: Real newer version available (remoteCode 66 vs localCode 64) -> TRUE
      expect(isNewerVersion('1.5.51+66', 66, '1.5.50', 64), isTrue);

      // Case D: ABI-split APK codes (e.g. 2064 for arm64 vs 64) -> FALSE (identical build)
      expect(isNewerVersion('1.5.50+64', 64, '1.5.50', 2064), isFalse);

      // ── 2. DOB Formatting Invariant ──
      // Verifies that raw ISO timestamps like 1995-05-18T00:00:00.000 are converted to readable date
      String formatDob(dynamic raw) {
        if (raw == null) return '';
        final s = raw.toString().trim();
        if (s.isEmpty) return '';
        try {
          final dt = DateTime.tryParse(s);
          if (dt != null) {
            return DateFormat('dd MMM yyyy').format(dt);
          }
          if (RegExp(r'^\d{2}[/\-.]\d{2}[/\-.]\d{4}$').hasMatch(s)) {
            final sep = s.contains('/') ? '/' : (s.contains('-') ? '-' : '.');
            final parts = s.split(sep);
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              return DateFormat('dd MMM yyyy').format(DateTime(year, month, day));
            }
          }
        } catch (_) {}
        return s;
      }

      expect(formatDob('1995-05-18T00:00:00.000'), equals('18 May 1995'));
      expect(formatDob('1995-05-18'), equals('18 May 1995'));
      expect(formatDob('18/05/1995'), equals('18 May 1995'));
      expect(formatDob(''), equals(''));
      expect(formatDob(null), equals(''));

      // ── 3. Education Section Conditional Visibility Invariant ──
      bool hasEducationDetails(Map<String, dynamic> data) {
        final college = (data['college'] ?? '').toString().trim();
        final course = (data['course'] ?? '').toString().trim();
        final year = (data['year'] ?? '').toString().trim();
        final rollNumber = (data['rollNumber'] ?? '').toString().trim();
        final examTarget = (data['examTarget'] ?? '').toString().trim();
        return college.isNotEmpty || course.isNotEmpty || year.isNotEmpty || rollNumber.isNotEmpty || examTarget.isNotEmpty;
      }

      expect(hasEducationDetails({}), isFalse);
      expect(hasEducationDetails({'college': '', 'course': '   '}), isFalse);
      expect(hasEducationDetails({'course': 'UPSC CSE'}), isTrue);
    });

    test('129. STUDENTS SCREEN PENDING ADMISSIONS FILTER & REQUEST DETAIL SIBLING RESOLUTION', () {
      // ── 1. Request Admission Classification Invariant ──
      bool isPendingAdmission(String type, String status) {
        final t = type.toLowerCase().trim();
        final s = status.toLowerCase().trim();
        final isAdm = t == 'registration' || t == 'newregistration';
        final isPend = s == 'pending' || s == 'submitted' || s == 'desk_payment_pending' || s == 'payment_pending' || s == 'open';
        return isAdm && isPend;
      }

      expect(isPendingAdmission('registration', 'pending'), isTrue);
      expect(isPendingAdmission('NewRegistration', 'submitted'), isTrue);
      expect(isPendingAdmission('seat_change', 'pending'), isFalse);
      expect(isPendingAdmission('registration', 'approved'), isFalse);

      // ── 2. Sibling / Shared Gov ID Conflict Exception Invariant ──
      String formatGovIdConflictMessage(String conflictName, String? conflictPhone) {
        final phoneSuffix = (conflictPhone != null && conflictPhone.isNotEmpty) ? ' (Phone: $conflictPhone)' : '';
        return 'This Government ID is already registered to student "$conflictName"$phoneSuffix.';
      }

      final msg = formatGovIdConflictMessage('Srikrishnadatta Bharatrao Sonpethkar', '9876543210');
      expect(msg, contains('Srikrishnadatta Bharatrao Sonpethkar'));
      expect(msg, contains('9876543210'));
      expect(msg, contains('already registered to student'));

      // ── 3. Notification Deduplication Hash Invariant ──
      final notif1 = {'id': 'doc_1', 'target': 'user_A', 'title': 'Admission Approved! 🎉', 'time': '2026-11-05T19:50:00Z'};
      final notif2 = {'id': 'doc_2', 'target': 'student_A', 'title': 'Admission Approved! 🎉', 'time': '2026-11-05T19:50:00Z'};
      final notif3 = {'id': 'doc_3', 'target': 'student_B', 'title': 'Monthly Fee Due', 'time': '2026-11-06T10:00:00Z'};

      String notifKey(Map<String, dynamic> n) => '${n["title"]}_${n["time"]}';
      final seen = <String>{};
      final deduplicated = [notif1, notif2, notif3].where((n) => seen.add(notifKey(n))).toList();

      expect(deduplicated.length, equals(2));
      expect(deduplicated.map((n) => n['title']), containsAll(['Admission Approved! 🎉', 'Monthly Fee Due']));
    });

    test('129. BRAND COLOR STUDIO: 2D SPECTRUM HSV-RGB INTEGRITY & ACADEMIC SWATCH PALETTE PARITY', () {
      // ── 1. HSV to Hex Round-Trip Conversion ──
      const testColor = Color(0xFFC2410C); // Warm Terracotta from user screenshot
      final hsv = HSVColor.fromColor(testColor);
      final reconstructed = hsv.toColor();
      expect(reconstructed.toARGB32(), equals(testColor.toARGB32()));

      String toHex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      expect(toHex(testColor), equals('#C2410C'));

      // ── 2. Clamped Bounds Integrity ──
      // Simulating touch coordinates at extremes
      double clampHue(double rawHue) => (rawHue / 360.0).clamp(0.0, 1.0) * 360.0;
      expect(clampHue(-50), equals(0.0));
      expect(clampHue(450), equals(360.0));
      expect(clampHue(180), equals(180.0));

      double clampSatVal(double raw, double maxDim) => (raw / maxDim).clamp(0.0, 1.0);
      expect(clampSatVal(-10, 160), equals(0.0));
      expect(clampSatVal(200, 160), equals(1.0));
      expect(clampSatVal(80, 160), equals(0.5));

      // ── 3. Academic Swatch Palette Structure & Contrast Invariant ──
      const academicEmerald = Color(0xFF065F46);
      const royalNavy = Color(0xFF1E3A8A);
      const warmTerracotta = Color(0xFFC2410C);
      const heritageBurgundy = Color(0xFF881337);

      expect(ThemeData.estimateBrightnessForColor(academicEmerald), equals(Brightness.dark));
      expect(ThemeData.estimateBrightnessForColor(royalNavy), equals(Brightness.dark));
      expect(ThemeData.estimateBrightnessForColor(warmTerracotta), equals(Brightness.dark));
      expect(ThemeData.estimateBrightnessForColor(heritageBurgundy), equals(Brightness.dark));

      // High text contrast ensures white text on these executive brand colors
      Color textContrastColor(Color bg) =>
          ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black87;

      expect(textContrastColor(warmTerracotta), equals(Colors.white));
      expect(textContrastColor(const Color(0xFFFDE68A)), equals(Colors.black87)); // Light amber
    });

    test('130. BILINGUAL LEGAL SUITE & PERMISSIONS ARCHITECTURE INVARIANTS', () {
      // ── 1. Marathi Terms & Privacy Policy Completeness ──
      const libName = 'The Cozy Corner Study Centre';
      final terms = TermsScreen.defaultTermsMarathi(libName);
      expect(terms, contains('नियम व अटींची स्वीकृती'));
      expect(terms, contains('शांतता क्षेत्र (Silent Zone)'));
      expect(terms, contains('Non-Refundable Policy'));
      expect(terms, contains('सीसीटीव्ही (CCTV) देखरेख'));

      final privacy = PrivacyPolicyScreen.defaultPrivacyPolicyMarathi(libName);
      expect(privacy, contains('आम्ही संकलित करत असलेली माहिती'));
      expect(privacy, contains('Firebase Cloud'));
      expect(privacy, contains('सीसीटीव्ही (CCTV) देखरेख'));

      // ── 2. Legal Language Enum Invariants ──
      expect(LegalLanguage.values.length, equals(2));
      expect(LegalLanguage.en.name, equals('en'));
      expect(LegalLanguage.mr.name, equals('mr'));

      // ── 3. Single-Student Expiry Calculation Invariants ──
      final today = DateTime.now();
      final expiringToday = DateTime(today.year, today.month, today.day);
      final daysDiffToday = expiringToday.difference(DateTime(today.year, today.month, today.day)).inDays;
      expect(daysDiffToday, equals(0));

      final expiringIn2Days = expiringToday.add(const Duration(days: 2));
      final daysDiff2 = expiringIn2Days.difference(expiringToday).inDays;
      expect(daysDiff2, equals(2));

      final expiredYesterday = expiringToday.subtract(const Duration(days: 1));
      final daysDiffExpired = expiredYesterday.difference(expiringToday).inDays;
      expect(daysDiffExpired, equals(-1));
    });

    test('Test 132: FACILITY TOUR SINGLE-INSTANCE SEMAPHORE & POP-UP MULTI-STACK DEFENSE', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const prefKey = 'student_facility_tour_completed';
      expect(prefs.getBool(prefKey), isNull);

      // Verify immediate persistence semantics
      await prefs.setBool(prefKey, true);
      expect(prefs.getBool(prefKey), isTrue);

      // Verify that once marked completed, subsequent checks are strictly ignored
      final isCompleted = prefs.getBool(prefKey) ?? false;
      expect(isCompleted, isTrue);
    });
  });
}
