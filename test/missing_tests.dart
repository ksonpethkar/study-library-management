// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/core/validators/gov_id_validator.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/core/constants/regex_patterns.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/payment_model.dart';
import 'package:study_library/services/plan_calculator_service.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // GROUP 1 — ENCRYPTION & SECURITY
  // ─────────────────────────────────────────────────────────────────────────
  group('🔐 Encryption & Security', () {
    const testSecret = 'test_library_id_abc123';
    const govId = '234567890123';
    const govIdWithSpaces = '2345 6789 0123';

    test('AES-256 encrypt → decrypt round-trip is lossless', () {
      final encrypted = EncryptionService.encrypt(govId, testSecret);
      final decrypted = EncryptionService.decrypt(encrypted, testSecret);
      expect(decrypted, equals(govId));
    });

    test('Encrypted output is base64, NOT the original plaintext', () {
      final encrypted = EncryptionService.encrypt(govId, testSecret);
      expect(encrypted, isNot(equals(govId)));
      // Must be valid base64
      expect(() => base64Decode(encrypted), returnsNormally);
    });

    test('Each encrypt call produces a DIFFERENT ciphertext (random IV)', () {
      final enc1 = EncryptionService.encrypt(govId, testSecret);
      final enc2 = EncryptionService.encrypt(govId, testSecret);
      // Same plaintext + same key → different output (random IV per call)
      expect(enc1, isNot(equals(enc2)));
      // But both decrypt to the same plaintext
      expect(EncryptionService.decrypt(enc1, testSecret), equals(govId));
      expect(EncryptionService.decrypt(enc2, testSecret), equals(govId));
    });

    test('Decrypt with wrong key throws, does not return garbage plaintext', () {
      final encrypted = EncryptionService.encrypt(govId, testSecret);
      expect(
        () => EncryptionService.decrypt(encrypted, 'completely_wrong_key'),
        throwsException,
      );
    });

    test('encryptGovId with empty appSecret throws immediately (fails safe)', () {
      expect(
        () => EncryptionService.encryptGovId(govId, ''),
        throwsException,
      );
    });

    test('decryptGovId with empty appSecret returns empty string', () {
      final encrypted = EncryptionService.encrypt(govId, testSecret);
      final result = EncryptionService.decryptGovId(encrypted, '');
      expect(result, equals(''));
    });

    test('safeDecryptGovId returns masked placeholder on total failure', () {
      const garbage = 'notvalidbase64!!!';
      final result = EncryptionService.safeDecryptGovId(garbage, '');
      // Should be masked bullets, not the raw garbage string
      expect(result, isNot(equals(garbage)));
    });

    test('safeDecryptGovId passes through already-plaintext Aadhaar', () {
      const plainAadhaar = '2345 6789 0123'; // looks like plaintext
      final result = EncryptionService.safeDecryptGovId(plainAadhaar, testSecret);
      expect(result, equals(plainAadhaar));
    });

    test('safeDecryptGovId passes through already-plaintext PAN', () {
      const plainPan = 'ABCDE1234F';
      final result = EncryptionService.safeDecryptGovId(plainPan, testSecret);
      expect(result, equals(plainPan));
    });

    test('Encrypted output has IV prepended (length > 16 bytes)', () {
      final encrypted = EncryptionService.encrypt(govId, testSecret);
      final decoded = base64Decode(encrypted);
      expect(decoded.length, greaterThan(16)); // IV (16) + at least 1 cipher block
    });

    test('SHA-256 PIN hash is deterministic and 64 hex chars', () {
      const pin = '7531';
      final hash1 = sha256.convert(utf8.encode(pin)).toString();
      final hash2 = sha256.convert(utf8.encode(pin)).toString();
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
    });

    test('Different PINs produce different hashes (no collision)', () {
      const h1 = '1234';
      const h2 = '1235';
      final hash1 = sha256.convert(utf8.encode(h1)).toString();
      final hash2 = sha256.convert(utf8.encode(h2)).toString();
      expect(hash1, isNot(equals(hash2)));
    });

    test('encryptGovId + decryptGovId with Aadhaar containing spaces', () {
      final encrypted = EncryptionService.encryptGovId(govIdWithSpaces, testSecret);
      final decrypted = EncryptionService.decryptGovId(encrypted, testSecret);
      expect(decrypted, equals(govIdWithSpaces));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP 2 — GOVERNMENT ID VALIDATION (All 7 Types)
  // ─────────────────────────────────────────────────────────────────────────
  group('🪪 Gov ID Validation — All 7 Types', () {
    // ── Aadhaar ──
    group('Aadhaar', () {
      test('Valid 12-digit Aadhaar passes', () {
        final check = AppValidators.generateVerhoeffCheckDigit('23456789012');
        expect(GovIdValidator.validate(GovIdType.aadhaar, '23456789012$check'), isNull);
      });

      test('Valid Aadhaar with spaces passes', () {
        final check = AppValidators.generateVerhoeffCheckDigit('23456789012');
        expect(GovIdValidator.validate(GovIdType.aadhaar, '2345 6789 012$check'), isNull);
      });

      test('Aadhaar starting with 0 fails', () {
        expect(GovIdValidator.validate(GovIdType.aadhaar, '012345678901'), isNotNull);
      });

      test('Aadhaar starting with 1 fails', () {
        expect(GovIdValidator.validate(GovIdType.aadhaar, '112345678901'), isNotNull);
      });

      test('11-digit Aadhaar fails', () {
        expect(GovIdValidator.validate(GovIdType.aadhaar, '23456789012'), isNotNull);
      });

      test('13-digit Aadhaar fails', () {
        expect(GovIdValidator.validate(GovIdType.aadhaar, '2345678901234'), isNotNull);
      });

      test('Aadhaar with letters fails', () {
        expect(GovIdValidator.validate(GovIdType.aadhaar, '23456789012A'), isNotNull);
      });

      test('Empty Aadhaar fails (required)', () {
        expect(GovIdValidator.validate(GovIdType.aadhaar, ''), isNotNull);
      });

      test('Empty Aadhaar passes when not required', () {
        expect(GovIdValidator.validate(GovIdType.aadhaar, '', isRequired: false), isNull);
      });

      test('Format: Aadhaar grouped into 4-digit blocks', () {
        final formatted = GovIdValidator.format(GovIdType.aadhaar, '234567890123');
        expect(formatted, equals('2345 6789 0123'));
      });
    });

    // ── PAN ──
    group('PAN', () {
      test('Valid PAN passes', () {
        expect(GovIdValidator.validate(GovIdType.pan, 'ABCDE1234F'), isNull);
      });

      test('Lowercase PAN: auto-normalizes to uppercase before validation (passes)', () {
        // GovIdValidator.validate() calls .toUpperCase() before regex check — same as DL, Voter ID, Passport.
        // This is intentional: the UI TextInputFormatter also auto-uppercases.
        // Behaviour: 'abcde1234f' → uppercased to 'ABCDE1234F' → valid → returns null.
        // The UI prevents lowercase entry; validator serves as a final safety net after normalisation.
        expect(GovIdValidator.validate(GovIdType.pan, 'abcde1234f'), isNull);
      });

      test('PAN with 9 chars fails', () {
        expect(GovIdValidator.validate(GovIdType.pan, 'ABCDE1234'), isNotNull);
      });

      test('PAN with 11 chars fails', () {
        expect(GovIdValidator.validate(GovIdType.pan, 'ABCDE12345F'), isNotNull);
      });

      test('PAN with wrong structure fails (digits in wrong place)', () {
        expect(GovIdValidator.validate(GovIdType.pan, '1BCDE1234F'), isNotNull);
      });

      test('Valid PAN uppercase formatted', () {
        final formatted = GovIdValidator.format(GovIdType.pan, 'abcde1234f');
        expect(formatted, equals('ABCDE1234F'));
      });
    });

    // ── Voter ID ──
    group('Voter ID (EPIC)', () {
      test('Valid Voter ID passes (3 letters + 7 digits)', () {
        expect(GovIdValidator.validate(GovIdType.voterId, 'ABC1234567'), isNull);
      });

      test('Voter ID with 9 chars fails', () {
        expect(GovIdValidator.validate(GovIdType.voterId, 'ABC123456'), isNotNull);
      });

      test('Voter ID with 11 chars fails', () {
        expect(GovIdValidator.validate(GovIdType.voterId, 'ABC12345678'), isNotNull);
      });

      test('Voter ID starting with digit fails', () {
        expect(GovIdValidator.validate(GovIdType.voterId, '1BC1234567'), isNotNull);
      });
    });

    // ── Passport ──
    group('Passport', () {
      test('Valid Passport passes (1 letter + 7 digits)', () {
        expect(GovIdValidator.validate(GovIdType.passport, 'A1234567'), isNull);
      });

      test('Passport with 7 chars fails', () {
        expect(GovIdValidator.validate(GovIdType.passport, 'A123456'), isNotNull);
      });

      test('Passport with 9 chars fails', () {
        expect(GovIdValidator.validate(GovIdType.passport, 'A12345678'), isNotNull);
      });

      test('Passport starting with digit fails', () {
        expect(GovIdValidator.validate(GovIdType.passport, '11234567'), isNotNull);
      });
    });

    // ── College ID ──
    group('College ID', () {
      test('Valid college ID (alphanumeric) passes', () {
        expect(GovIdValidator.validate(GovIdType.collegeId, 'CS2024001'), isNull);
      });

      test('Single character college ID fails', () {
        expect(GovIdValidator.validate(GovIdType.collegeId, 'A'), isNotNull);
      });

      test('College ID with 31 chars fails', () {
        expect(
          GovIdValidator.validate(GovIdType.collegeId, 'A' * 31),
          isNotNull,
        );
      });
    });

    // ── Other ──
    group('Other Gov ID', () {
      test('Valid 5-char other ID passes', () {
        expect(GovIdValidator.validate(GovIdType.other, 'ABC12'), isNull);
      });

      test('2-char other ID fails (min 3)', () {
        expect(GovIdValidator.validate(GovIdType.other, 'AB'), isNotNull);
      });

      test('36-char other ID fails (max 35)', () {
        expect(GovIdValidator.validate(GovIdType.other, 'A' * 36), isNotNull);
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP 3 — APP VALIDATORS (Phone, Email, Pincode, Amount, etc.)
  // ─────────────────────────────────────────────────────────────────────────
  group('✅ AppValidators — All Fields', () {
    group('Phone', () {
      test('Valid phone starting with 9 passes', () {
        expect(AppValidators.phone('9876543210'), isNull);
      });

      test('Valid phone starting with 6 passes', () {
        expect(AppValidators.phone('6543219870'), isNull);
      });

      test('Phone starting with 5 fails', () {
        expect(AppValidators.phone('5876543210'), isNotNull);
      });

      test('9-digit phone fails', () {
        expect(AppValidators.phone('987654321'), isNotNull);
      });

      test('11-digit phone fails', () {
        expect(AppValidators.phone('98765432100'), isNotNull);
      });

      test('All-same-digit phone fails (mock number)', () {
        expect(AppValidators.phone('9999999999'), isNotNull);
        expect(AppValidators.phone('8888888888'), isNotNull);
      });

      test('Empty phone fails when required', () {
        expect(AppValidators.phone(''), isNotNull);
      });
    });

    group('Email', () {
      test('Valid email passes', () {
        expect(AppValidators.email('student@gmail.com'), isNull);
      });

      test('Email without @ fails', () {
        expect(AppValidators.email('studentgmail.com'), isNotNull);
      });

      test('Email without domain fails', () {
        expect(AppValidators.email('student@'), isNotNull);
      });

      test('Email with subdomain passes', () {
        expect(AppValidators.email('student@mail.college.edu'), isNull);
      });

      test('Empty email passes when not required', () {
        expect(AppValidators.email('', required: false), isNull);
      });
    });

    group('Pincode', () {
      test('Valid 6-digit pincode passes', () {
        expect(AppValidators.pinCode('411001'), isNull);
      });

      test('Pincode starting with 0 fails', () {
        expect(AppValidators.pinCode('011001'), isNotNull);
      });

      test('5-digit pincode fails', () {
        expect(AppValidators.pinCode('41100'), isNotNull);
      });

      test('7-digit pincode fails', () {
        expect(AppValidators.pinCode('4110011'), isNotNull);
      });
    });

    group('Name', () {
      test('Simple English name passes', () {
        expect(AppValidators.name('Rahul Sharma'), isNull);
      });

      test('Name with dot passes (e.g. A. Kumar)', () {
        expect(AppValidators.name('A. Kumar'), isNull);
      });

      test('Name starting with digit fails', () {
        expect(AppValidators.name('1Rahul'), isNotNull);
      });

      test('Single char name fails (min 2)', () {
        expect(AppValidators.name('R'), isNotNull);
      });

      test('101-char name fails (max 100)', () {
        expect(AppValidators.name('R' * 101), isNotNull);
      });
    });

    group('Amount', () {
      test('Valid integer amount passes', () {
        expect(AppValidators.amount('1500'), isNull);
      });

      test('Valid decimal amount passes', () {
        expect(AppValidators.amount('1500.50'), isNull);
      });

      test('Zero amount fails', () {
        expect(AppValidators.amount('0'), isNotNull);
      });

      test('Negative amount fails', () {
        expect(AppValidators.amount('-100'), isNotNull);
      });

      test('Empty amount fails', () {
        expect(AppValidators.amount(''), isNotNull);
      });
    });

    group('Emergency Contact', () {
      test('Valid emergency contact different from student passes', () {
        expect(
          AppValidators.emergencyPhone('8876543210', primaryPhone: '9876543210'),
          isNull,
        );
      });

      test('Emergency contact same as student phone fails', () {
        expect(
          AppValidators.emergencyPhone('9876543210', primaryPhone: '9876543210'),
          isNotNull,
        );
      });
    });

    group('GSTIN', () {
      test('Valid GSTIN passes', () {
        expect(AppValidators.gstin('27AAAAA0000A1Z5'), isNull);
      });

      test('Invalid GSTIN (wrong length) fails', () {
        expect(AppValidators.gstin('27AAAAA0000A1Z'), isNotNull);
      });

      test('Empty GSTIN passes when not required', () {
        expect(AppValidators.gstin('', required: false), isNull);
      });
    });

    group('UPI ID', () {
      test('Valid UPI ID passes', () {
        expect(AppValidators.upiId('library@oksbi'), isNull);
      });

      test('UPI ID without @ fails', () {
        expect(AppValidators.upiId('libraryoksbi'), isNotNull);
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP 4 — REGEX PATTERNS
  // ─────────────────────────────────────────────────────────────────────────
  group('🔤 RegexPatterns', () {
    test('Blood group A+ matches', () {
      expect(RegExp(RegexPatterns.bloodGroup).hasMatch('A+'), isTrue);
    });
    test('Blood group AB- matches', () {
      expect(RegExp(RegexPatterns.bloodGroup).hasMatch('AB-'), isTrue);
    });
    test('Blood group C+ does NOT match', () {
      expect(RegExp(RegexPatterns.bloodGroup).hasMatch('C+'), isFalse);
    });
    test('Seat label A1 matches', () {
      expect(RegExp(RegexPatterns.seatLabel).hasMatch('A1'), isTrue);
    });
    test('Seat label with space does NOT match', () {
      expect(RegExp(RegexPatterns.seatLabel).hasMatch('A 1'), isFalse);
    });
    test('Cheque number 6 digits matches', () {
      expect(RegExp(RegexPatterns.cheque).hasMatch('123456'), isTrue);
    });
    test('Cheque number 5 digits does NOT match', () {
      expect(RegExp(RegexPatterns.cheque).hasMatch('12345'), isFalse);
    });
    // DL regex now supports hyphens (fixed in regex_patterns.dart)
    test('DL regex supports non-hyphenated format MH1220210001234', () {
      expect(RegExp(RegexPatterns.drivingLicence).hasMatch('MH1220210001234'), isTrue);
    });
    test('DL regex now supports hyphenated format MH-12-20210001234', () {
      // regex_patterns.dart updated: r'^[A-Z]{2}[\s\-]?[0-9]{2}[\s\-]?[0-9A-Z]{11,12}$'
      expect(RegExp(RegexPatterns.drivingLicence).hasMatch('MH-12-20210001234'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP 5 — PLAN CALCULATOR (BILLING LOGIC)
  // ─────────────────────────────────────────────────────────────────────────
  group('💰 PlanCalculatorService — Billing Logic', () {
    // Helper plans
    PlanModel monthlyPlan() => PlanModel(
          id: 'plan_monthly',
          libraryId: 'lib_001',
          name: 'Monthly',
          duration: 1,
          durationUnit: DurationUnit.months,
          price: 1500.0,
          description: 'Monthly plan',
          gracePeriodDays: 3,
          isActive: true,
          isFeatured: true,
          displayOrder: 1,
        );

    PlanModel thirtyDayPlan() => PlanModel(
          id: 'plan_30day',
          libraryId: 'lib_001',
          name: '30 Day',
          duration: 30,
          durationUnit: DurationUnit.days,
          price: 900.0,
          description: '30-day plan',
          gracePeriodDays: 0,
          isActive: true,
          isFeatured: false,
          displayOrder: 2,
        );

    PlanModel premiumPlan() => PlanModel(
          id: 'plan_premium',
          libraryId: 'lib_001',
          name: 'Premium Monthly',
          duration: 1,
          durationUnit: DurationUnit.months,
          price: 2500.0,
          description: 'Premium plan',
          gracePeriodDays: 5,
          isActive: true,
          isFeatured: false,
          displayOrder: 3,
        );

    group('calculateSmartPlan — Monthly', () {
      // SERVICE BEHAVIOUR (calendar-month-end alignment):
      // Monthly plan: cycleEnd = DateTime(year, month+1, 0, 23,59,59)
      // i.e. always snaps to the LAST DAY of the CURRENT calendar month at 23:59:59,
      // regardless of which day of the month the student joins.
      // Oct 1 → Oct 31 23:59:59 | Oct 15 → Oct 31 23:59:59

      test('Monthly plan starting 1st: ends last day of same month at 23:59:59', () {
        final calc = PlanCalculatorService.calculateSmartPlan(
          plan: monthlyPlan(),
          fromDate: DateTime(2026, 10, 1),
        );
        // Calendar snap: Oct → Oct 31 (last day of month)
        expect(calc.endDate.year,  equals(2026));
        expect(calc.endDate.month, equals(10));
        expect(calc.endDate.day,   equals(31));
        expect(calc.endDate.hour,  equals(23)); // service uses 23:59:59
        expect(calc.isProrated, isFalse);
      });

      test('Monthly plan starting 15th Oct: still ends Oct 31 (calendar snap, NOT +30 days)', () {
        final calc = PlanCalculatorService.calculateSmartPlan(
          plan: monthlyPlan(),
          fromDate: DateTime(2026, 10, 15),
        );
        // Calendar snap: month = Oct → end = Oct 31 at 23:59:59
        expect(calc.endDate.year,  equals(2026));
        expect(calc.endDate.month, equals(10));
        expect(calc.endDate.day,   equals(31));
        expect(calc.isProrated, isTrue); // mid-month join → prorated
      });

      test('Monthly plan starting Jan 31: ends Jan 31 (last day of Jan, NOT Feb)', () {
        final calc = PlanCalculatorService.calculateSmartPlan(
          plan: monthlyPlan(),
          fromDate: DateTime(2025, 1, 31),
        );
        // Calendar snap: month = Jan → cycleEnd = DateTime(2025, 2, 0, 23,59,59) = Jan 31 23:59:59
        expect(calc.endDate.year,  equals(2025));
        expect(calc.endDate.month, equals(1));
        expect(calc.endDate.day,   equals(31));
      });

      test('Monthly plan starting Jan 31 (leap year 2024): ends Jan 31', () {
        final calc = PlanCalculatorService.calculateSmartPlan(
          plan: monthlyPlan(),
          fromDate: DateTime(2024, 1, 31),
        );
        // Calendar snap: month = Jan → end = Jan 31 (unchanged by leap year)
        expect(calc.endDate.year,  equals(2024));
        expect(calc.endDate.month, equals(1));
        expect(calc.endDate.day,   equals(31));
      });

      test('Monthly plan start = 1st: NOT prorated (full month)', () {
        final calc = PlanCalculatorService.calculateSmartPlan(
          plan: monthlyPlan(),
          fromDate: DateTime(2026, 10, 1),
        );
        expect(calc.isProrated, isFalse);
        expect(calc.proratedPrice, equals(calc.fullPrice));
      });

      test('Monthly plan mid-month: IS prorated, price < full', () {
        final calc = PlanCalculatorService.calculateSmartPlan(
          plan: monthlyPlan(),
          fromDate: DateTime(2026, 10, 20),
        );
        expect(calc.isProrated, isTrue);
        expect(calc.proratedPrice, lessThan(calc.fullPrice));
        expect(calc.proratedPrice, greaterThan(0));
      });

      test('Daily rate = plan.price / getStandardCycleDays (30 for 1-month plan)', () {
        final calc = PlanCalculatorService.calculateSmartPlan(
          plan: monthlyPlan(),
          fromDate: DateTime(2026, 10, 1),
        );
        // getDailyRate uses getStandardCycleDays → returns 30 for DurationUnit.months with duration=1
        // This is the STANDARD rate shown on the plans screen (plan.price / 30)
        expect(calc.dailyRate, closeTo(1500.0 / 30, 0.01)); // 50.0/day
      });
    });

    group('calculateSmartPlan — Calendar Month Architecture (No Rolling 30 Days)', () {
      // SERVICE BEHAVIOUR: All plans snap strictly to current calendar month end at 23:59:59
      // Oct 1 start → Oct 31 23:59:59 (Full Month)
      // Oct 15 start → Oct 31 23:59:59 (Current Calendar Month, Prorated)

      test('30-day / 1-month plan starting 1st: ends last day of calendar month (Oct 31 at 23:59:59)', () {
        final calc = PlanCalculatorService.calculateSmartPlan(
          plan: thirtyDayPlan(),
          fromDate: DateTime(2026, 10, 1),
        );
        expect(calc.endDate.year,  equals(2026));
        expect(calc.endDate.month, equals(10));
        expect(calc.endDate.day,   equals(31));
        expect(calc.endDate.hour,  equals(23));
        expect(calc.isProrated, isFalse);
      });

      test('30-day / 1-month plan starting mid-month (Oct 15): snaps to Oct 31 (current month), never rolls to Nov', () {
        final calc = PlanCalculatorService.calculateSmartPlan(
          plan: thirtyDayPlan(),
          fromDate: DateTime(2026, 10, 15),
        );
        expect(calc.endDate.year,  equals(2026));
        expect(calc.endDate.month, equals(10));
        expect(calc.endDate.day,   equals(31));
        expect(calc.endDate.hour,  equals(23));
        expect(calc.isProrated, isTrue);
      });
    });

    group('calculateExitSettlement — Refunds', () {
      test('Early exit after 10 of 30 days — refund is positive', () {
        final settlement = PlanCalculatorService.calculateExitSettlement(
          startDate: DateTime(2026, 10, 1),
          originalEndDate: DateTime(2026, 10, 30),
          exitDate: DateTime(2026, 10, 10),
          totalPaid: 900.0,
          plan: thirtyDayPlan(),
        );
        expect(settlement.usedDays, equals(10));
        expect(settlement.unusedDays, equals(20));
        expect(settlement.netRefund, greaterThan(0));
        expect(settlement.fairUsageFee, lessThan(900.0));
        expect(settlement.grossRefund + settlement.fairUsageFee,
            closeTo(900.0, 1.0));
      });

      test('Exit on last day — no refund', () {
        final settlement = PlanCalculatorService.calculateExitSettlement(
          startDate: DateTime(2026, 10, 1),
          originalEndDate: DateTime(2026, 10, 30),
          exitDate: DateTime(2026, 10, 30),
          totalPaid: 900.0,
          plan: thirtyDayPlan(),
        );
        expect(settlement.netRefund, equals(0.0));
        expect(settlement.fairUsageFee, closeTo(900.0, 1.0));
      });

      test('Exit before start date — used days clamped to 0', () {
        final settlement = PlanCalculatorService.calculateExitSettlement(
          startDate: DateTime(2026, 10, 5),
          originalEndDate: DateTime(2026, 11, 4),
          exitDate: DateTime(2026, 10, 4), // day before start
          totalPaid: 1500.0,
          plan: monthlyPlan(),
        );
        expect(settlement.usedDays, equals(0));
        expect(settlement.fairUsageFee, equals(0.0));
        expect(settlement.grossRefund, equals(1500.0));
      });

      test('Processing fee correctly reduces net refund', () {
        final settlement = PlanCalculatorService.calculateExitSettlement(
          startDate: DateTime(2026, 10, 1),
          originalEndDate: DateTime(2026, 10, 30),
          exitDate: DateTime(2026, 10, 10),
          totalPaid: 900.0,
          plan: thirtyDayPlan(),
          processingFee: 50.0,
        );
        expect(settlement.netRefund, lessThan(settlement.grossRefund));
        expect(settlement.netRefund,
            closeTo(settlement.grossRefund - 50.0, 1.0));
      });
    });

    group('calculatePlanChangeSettlement — Upgrade / Downgrade', () {
      test('Upgrade: student pays positive net difference', () {
        final settlement = PlanCalculatorService.calculatePlanChangeSettlement(
          currentPlan: monthlyPlan(),   // ₹1500
          targetPlan: premiumPlan(),    // ₹2500
          currentStartDate: DateTime(2026, 10, 1),
          currentEndDate: DateTime(2026, 10, 31),
          changeDate: DateTime(2026, 10, 16), // mid-month
          totalPaidForCurrent: 1500.0,
        );
        expect(settlement.isUpgrade, isTrue);
        expect(settlement.payableByStudent, greaterThan(0));
        expect(settlement.refundableToStudent, equals(0.0));
      });

      test('Downgrade: student receives credit (refundable > 0)', () {
        final settlement = PlanCalculatorService.calculatePlanChangeSettlement(
          currentPlan: premiumPlan(),   // ₹2500
          targetPlan: monthlyPlan(),    // ₹1500
          currentStartDate: DateTime(2026, 10, 1),
          currentEndDate: DateTime(2026, 10, 31),
          changeDate: DateTime(2026, 10, 16),
          totalPaidForCurrent: 2500.0,
        );
        expect(settlement.isUpgrade, isFalse);
        expect(settlement.refundableToStudent, greaterThan(0));
        expect(settlement.payableByStudent, equals(0.0));
      });

      test('Plan change on first day: all remaining days available', () {
        final settlement = PlanCalculatorService.calculatePlanChangeSettlement(
          currentPlan: monthlyPlan(),
          targetPlan: premiumPlan(),
          currentStartDate: DateTime(2026, 10, 1),
          currentEndDate: DateTime(2026, 10, 31),
          changeDate: DateTime(2026, 10, 1), // same day as start
          totalPaidForCurrent: 1500.0,
        );
        // 0 days used, all 31 days remain as credit
        expect(settlement.usedDays, equals(0));
        expect(settlement.remainingDays, equals(31));
      });

      test('Plan change on last day: unusedCredit ≈ 0', () {
        final settlement = PlanCalculatorService.calculatePlanChangeSettlement(
          currentPlan: monthlyPlan(),
          targetPlan: premiumPlan(),
          currentStartDate: DateTime(2026, 10, 1),
          currentEndDate: DateTime(2026, 10, 31),
          changeDate: DateTime(2026, 10, 31), // last day
          totalPaidForCurrent: 1500.0,
        );
        expect(settlement.remainingDays, lessThanOrEqualTo(1));
        expect(settlement.unusedCredit, closeTo(0.0, 100.0)); // ≈ 0 or 1 day
      });
    });

    group('findMonthlyPlan', () {
      test('Finds DurationUnit.months plan correctly', () {
        final plans = [thirtyDayPlan(), monthlyPlan()];
        final found = PlanCalculatorService.findMonthlyPlan(plans);
        expect(found?.id, equals('plan_monthly'));
      });

      test('Falls back to 30-day plan when no monthly plan', () {
        final plans = [thirtyDayPlan()];
        final found = PlanCalculatorService.findMonthlyPlan(plans);
        expect(found?.id, equals('plan_30day'));
      });

      test('Returns null for empty list', () {
        final found = PlanCalculatorService.findMonthlyPlan([]);
        expect(found, isNull);
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP 6 — MEMBERSHIP STATUS & STUDENT MODEL
  // ─────────────────────────────────────────────────────────────────────────
  group('🎓 StudentModel — Membership Status & Computed Properties', () {
    StudentModel activeStudent() => StudentModel(
          id: 'std_001',
          name: 'Rahul Sharma',
          fatherName: 'Suresh Sharma',
          phone: '9876543210',
          email: 'rahul@test.com',
          gender: Gender.male,
          address: 'Pune',
          pincode: '411001',
          govIdType: GovIdType.aadhaar,
          govIdNumber: '234567890123',
          govIdImageUrl: '',
          photoUrl: '',
          college: 'Pune University',
          course: 'B.Sc',
          year: '2',
          emergencyContact: '8876543210',
          membershipStatus: MembershipStatus.active,
          planStartDate: DateTime.now().subtract(const Duration(days: 15)),
          planEndDate: DateTime.now().add(const Duration(days: 15)),
          customFields: const {},
        );

    StudentModel expiredStudent() => StudentModel(
          id: 'std_002',
          name: 'Priya Patel',
          fatherName: 'Vijay Patel',
          phone: '8765432109',
          email: 'priya@test.com',
          gender: Gender.female,
          address: 'Mumbai',
          pincode: '400001',
          govIdType: GovIdType.pan,
          govIdNumber: 'ABCDE1234F',
          govIdImageUrl: '',
          photoUrl: '',
          college: 'Mumbai University',
          course: 'M.A.',
          year: '1',
          emergencyContact: '9876543211',
          membershipStatus: MembershipStatus.expired,
          planStartDate: DateTime.now().subtract(const Duration(days: 35)),
          planEndDate: DateTime.now().subtract(const Duration(days: 5)),
          customFields: const {},
        );

    test('Active student with future endDate: isEffectivelyActive = true', () {
      expect(activeStudent().isEffectivelyActive, isTrue);
    });

    test('Expired student: isEffectivelyActive = false', () {
      expect(expiredStudent().isEffectivelyActive, isFalse);
    });

    test('Student with no planEndDate: isEffectivelyActive = false', () {
      final noEndDate = StudentModel(
        id: 'std_003',
        name: 'Test',
        fatherName: 'Father',
        phone: '7654321098',
        email: '',
        gender: Gender.other,
        address: 'City',
        pincode: '411001',
        govIdType: GovIdType.collegeId,
        govIdNumber: 'ROLL001',
        govIdImageUrl: '',
        photoUrl: '',
        college: 'College',
        course: 'BA',
        year: '1',
        emergencyContact: '',
        membershipStatus: MembershipStatus.active,
        planEndDate: null, // no end date
        customFields: const {},
      );
      expect(noEndDate.isEffectivelyActive, isFalse);
    });

    test('Grace student: membershipStatus = grace', () {
      final graceStudent = StudentModel(
        id: 'std_004',
        name: 'Amit',
        fatherName: 'Dad',
        phone: '6543210987',
        email: '',
        gender: Gender.male,
        address: 'Nagpur',
        pincode: '440001',
        govIdType: GovIdType.voterId,
        govIdNumber: 'MHA1234567',
        govIdImageUrl: '',
        photoUrl: '',
        college: 'Nagpur Uni',
        course: 'B.Com',
        year: '3',
        emergencyContact: '',
        membershipStatus: MembershipStatus.grace,
        planEndDate: DateTime.now().subtract(const Duration(days: 2)),
        graceEndDate: DateTime.now().add(const Duration(days: 1)),
        customFields: const {},
      );
      expect(graceStudent.membershipStatus, equals(MembershipStatus.grace));
      expect(graceStudent.effectiveMembershipStatus, equals(MembershipStatus.grace)); // status is grace, not active
      expect(graceStudent.isEffectivelyActive, isTrue); // retains study pass access during grace period
    });

    test('StudentModel toJson → fromJson round-trip preserves all fields', () {
      final original = activeStudent();
      final json = original.toJson();
      final restored = StudentModel.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.phone, equals(original.phone));
      expect(restored.membershipStatus, equals(original.membershipStatus));
      expect(restored.gender, equals(original.gender));
      expect(restored.govIdType, equals(original.govIdType));
      expect(restored.planEndDate?.day, equals(original.planEndDate?.day));
    });

    test('StudentModel pendingDueBalance null check', () {
      final student = activeStudent();
      expect(student.pendingDueBalance, isNull);
    });

    test('Student membership number format', () {
      final student = StudentModel(
        id: 'std_005',
        name: 'Test',
        fatherName: 'Parent',
        phone: '9123456780',
        email: '',
        gender: Gender.male,
        address: 'City',
        pincode: '411001',
        govIdType: GovIdType.aadhaar,
        govIdNumber: '234567890123',
        govIdImageUrl: '',
        photoUrl: '',
        college: '',
        course: '',
        year: '',
        emergencyContact: '',
        membershipStatus: MembershipStatus.active,
        membershipNumber: 'CC20260042',
        customFields: const {},
      );
      expect(student.membershipNumber, startsWith('CC'));
      expect(student.membershipNumber?.length, greaterThanOrEqualTo(8));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP 7 — SEAT MODEL
  // ─────────────────────────────────────────────────────────────────────────
  group('💺 SeatModel — Integrity & Assignment Rules', () {
    SeatModel availableSeat() => SeatModel(
          id: 'seat_a1',
          sectionId: 'sec_001',
          row: 0,
          col: 0,
          label: 'A1',
          status: SeatStatus.available,
          genderRestriction: GenderRestriction.any,
        );

    SeatModel occupiedSeat() => SeatModel(
          id: 'seat_b1',
          sectionId: 'sec_001',
          row: 1,
          col: 0,
          label: 'B1',
          status: SeatStatus.occupied,
          genderRestriction: GenderRestriction.any,
          studentId: 'std_001',
        );

    SeatModel femaleSeat() => SeatModel(
          id: 'seat_c1',
          sectionId: 'sec_001',
          row: 2,
          col: 0,
          label: 'C1',
          status: SeatStatus.available,
          genderRestriction: GenderRestriction.female,
        );

    test('Available seat has null studentId', () {
      expect(availableSeat().studentId, isNull);
    });

    test('Occupied seat has non-null studentId', () {
      expect(occupiedSeat().studentId, equals('std_001'));
    });

    test('copyWith: assign student to available seat', () {
      final assigned = availableSeat().copyWith(
        status: SeatStatus.occupied,
        studentId: 'std_new',
      );
      expect(assigned.status, equals(SeatStatus.occupied));
      expect(assigned.studentId, equals('std_new'));
    });

    test('copyWith with clearStudent: removes studentId', () {
      final cleared = occupiedSeat().copyWith(
        status: SeatStatus.available,
        clearStudent: true,
      );
      expect(cleared.status, equals(SeatStatus.available));
      expect(cleared.studentId, isNull);
    });

    test('SeatModel toJson → fromJson round-trip', () {
      final seat = occupiedSeat();
      final json = seat.toJson();
      final restored = SeatModel.fromJson(json);
      expect(restored.id, equals(seat.id));
      expect(restored.status, equals(seat.status));
      expect(restored.studentId, equals(seat.studentId));
      expect(restored.genderRestriction, equals(seat.genderRestriction));
    });

    test('Female-only seat has correct gender restriction', () {
      expect(femaleSeat().genderRestriction, equals(GenderRestriction.female));
    });

    test('Seat label is preserved correctly', () {
      expect(availableSeat().label, equals('A1'));
      expect(femaleSeat().label, equals('C1'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP 8 — PAYMENT MODEL
  // ─────────────────────────────────────────────────────────────────────────
  group('💳 PaymentModel — Serialization & Status', () {
    PaymentModel fullPayment() => PaymentModel(
          id: 'pay_001',
          studentId: 'std_001',
          amount: 1500.0,
          method: 'Cash',
          date: DateTime(2026, 10, 15),
          status: PaymentStatus.paid,
          createdAt: DateTime(2026, 10, 15, 10, 30),
          receiptNumber: 'RCP001',
          totalPlanFee: 1500.0,
          remainingDue: 0.0,
        );

    PaymentModel partialPayment() => PaymentModel(
          id: 'pay_002',
          studentId: 'std_001',
          amount: 500.0,
          method: 'UPI / QR',
          date: DateTime(2026, 10, 15),
          status: PaymentStatus.partial,
          createdAt: DateTime(2026, 10, 15, 11, 0),
          totalPlanFee: 1500.0,
          remainingDue: 1000.0,
          referenceNumber: 'UPI123456789',
        );

    test('Full payment: status is paid', () {
      expect(fullPayment().status, equals(PaymentStatus.paid));
    });

    test('Partial payment: remainingDue = totalFee - amount', () {
      final p = partialPayment();
      expect(p.remainingDue, equals(p.totalPlanFee! - p.amount));
    });

    test('PaymentModel toJson → fromJson round-trip', () {
      final p = fullPayment();
      final json = p.toJson();
      final restored = PaymentModel.fromJson(json);
      expect(restored.id, equals(p.id));
      expect(restored.amount, equals(p.amount));
      expect(restored.method, equals(p.method));
      expect(restored.status, equals(p.status));
      expect(restored.receiptNumber, equals(p.receiptNumber));
    });

    test('PaymentModel handles both "method" and "paymentMethod" keys in fromJson', () {
      // Backward compatibility: old docs use "paymentMethod" key
      final json = {
        'id': 'pay_003',
        'studentId': 'std_001',
        'amount': 900.0,
        'paymentMethod': 'Cheque / DD', // old key
        'date': '2026-10-15T00:00:00.000',
        'status': 'paid',
        'createdAt': '2026-10-15T10:00:00.000',
      };
      final p = PaymentModel.fromJson(json);
      expect(p.method, equals('Cheque / DD'));
    });

    test('PaymentModel handles both "receiptNumber" and "receiptNo" keys', () {
      final json = {
        'id': 'pay_004',
        'studentId': 'std_001',
        'amount': 1500.0,
        'method': 'Cash',
        'date': '2026-10-15T00:00:00.000',
        'status': 'paid',
        'createdAt': '2026-10-15T10:00:00.000',
        'receiptNo': 'RCP-LEGACY-001', // old key
      };
      final p = PaymentModel.fromJson(json);
      expect(p.receiptNumber, equals('RCP-LEGACY-001'));
    });

    test('Voided payment has correct status', () {
      final voided = fullPayment().copyWith(
        status: PaymentStatus.voided,
        cancellationReason: 'Entered by mistake',
      );
      expect(voided.status, equals(PaymentStatus.voided));
      expect(voided.cancellationReason, equals('Entered by mistake'));
    });

    test('Refunded payment status', () {
      final refunded = partialPayment().copyWith(status: PaymentStatus.refunded);
      expect(refunded.status, equals(PaymentStatus.refunded));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP 9 — SEAT GRID AUTO-LABEL GENERATION
  // ─────────────────────────────────────────────────────────────────────────
  group('🔢 Seat Grid Auto-Label Generation', () {
    List<String> generateLabels(int rows, int cols) {
      final labels = <String>[];
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          labels.add('${String.fromCharCode(65 + r)}${c + 1}');
        }
      }
      return labels;
    }

    test('3×4 grid generates 12 labels', () {
      final labels = generateLabels(3, 4);
      expect(labels.length, equals(12));
    });

    test('First label is A1', () {
      expect(generateLabels(3, 4).first, equals('A1'));
    });

    test('Last label in 3×4 is C4', () {
      expect(generateLabels(3, 4).last, equals('C4'));
    });

    test('Row boundary: first seat of second row is B1', () {
      expect(generateLabels(3, 4)[4], equals('B1'));
    });

    test('1×1 grid produces single label A1', () {
      expect(generateLabels(1, 1), equals(['A1']));
    });

    test('5×5 grid produces 25 unique labels', () {
      final labels = generateLabels(5, 5);
      expect(labels.length, equals(25));
      expect(labels.toSet().length, equals(25)); // all unique
    });

    test('Labels are unique within section', () {
      final labels = generateLabels(10, 10);
      expect(labels.toSet().length, equals(labels.length));
    });
  });
}
