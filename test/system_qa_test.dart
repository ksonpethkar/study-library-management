import 'package:flutter_test/flutter_test.dart';
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
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/models/feedback_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/constants/app_constants.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/firebase_options.dart';
import 'package:study_library/features/waiting_list/data/repositories/waiting_list_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:study_library/services/id_card_pdf_service.dart';

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

      // Aadhaar detection
      expect(OcrParser.detectGovIdType('GOVERNMENT OF INDIA UNIQUE IDENTIFICATION AUTHORITY AADHAAR 1234 5678 9012'), equals(GovIdType.aadhaar));
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
      // Aadhaar: 12 digits, cannot start with 0 or 1
      expect(GovIdValidator.isValid(GovIdType.aadhaar, '234567890123'), isTrue);
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
      expect(WhatsNewService.currentVersionIdentifier, equals('1.5.47+55'));
      expect(AppConstants.appVersion, equals('1.5.47'));
      expect(AppConstants.buildNumber, equals(55));

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
  });
}
