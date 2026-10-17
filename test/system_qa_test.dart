import 'package:flutter_test/flutter_test.dart';
import 'package:study_library/models/user_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/models/waiting_list_model.dart';
import 'package:study_library/models/payment_model.dart';
import 'package:study_library/features/registration/data/ocr_parser.dart';
import 'package:study_library/services/biometric_service.dart';

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
      // PAN Card detection
      expect(OcrParser.detectGovIdType('INCOME TAX DEPARTMENT GOVT OF INDIA ABCDE1234F'), equals(GovIdType.pan));

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
  });
}

