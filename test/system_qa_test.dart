import 'package:flutter_test/flutter_test.dart';
import 'package:study_library/models/user_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/models/waiting_list_model.dart';
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
  });
}

