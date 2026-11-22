import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/student_model.dart';
import 'sentinel_models.dart';

/// The Invariant Engine evaluates the 8 operational invariants of Cozy Corner
/// and executes automated or 1-tap self-healing operations.
class SentinelInvariantEngine {
  final FirebaseFirestore? firestore;
  final AuditLogger? auditLogger;

  SentinelInvariantEngine({
    this.firestore,
    this.auditLogger,
  });

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
  AuditLogger? get _auditLogger => auditLogger;

  /// Invariant 1: Seat ↔ Student Double-Binding Integrity.
  /// Verifies that every occupied seat points to a valid active student,
  /// and every active student with an assigned seat points back to that exact seat.
  List<SentinelAnomaly> auditSeatStudentBindings({
    required List<SeatModel> seats,
    required List<StudentModel> students,
  }) {
    final anomalies = <SentinelAnomaly>[];
    final studentMap = {for (final s in students) s.id: s};
    final seatMap = {for (final s in seats) s.id: s};

    // Check from Seat perspective
    for (final seat in seats) {
      if (seat.status == SeatStatus.occupied) {
        if (seat.studentId == null || seat.studentId!.isEmpty) {
          anomalies.add(
            SentinelAnomaly(
              id: 'mismatch_seat_${seat.id}_no_student',
              title: 'Ghost Occupancy on ${SeatHelper.formatDeskLabel(seatId: seat.id, rawLabel: seat.label)}',
              description: 'Desk is marked as occupied but has no student ID attached.',
              severity: SentinelSeverity.warning,
              domain: SentinelDomain.seats,
              entityId: seat.id,
              detectedAt: DateTime.now(),
              canAutoHeal: true,
              rootCauseDiagnosis: 'A student may have been unassigned without clearing the seat status.',
              remediationSuggestion: 'Reset desk to available or attach the correct student record.',
              metadata: {'seatId': seat.id, 'sectionId': seat.sectionId},
            ),
          );
        } else {
          final student = studentMap[seat.studentId];
          if (student == null) {
            anomalies.add(
              SentinelAnomaly(
                id: 'mismatch_seat_${seat.id}_missing_student',
                title: 'Orphaned Desk Binding on ${SeatHelper.formatDeskLabel(seatId: seat.id, rawLabel: seat.label)}',
                description: 'Desk points to student ID ${seat.studentId}, but that student no longer exists in the roster.',
                severity: SentinelSeverity.critical,
                domain: SentinelDomain.seats,
                entityId: seat.id,
                detectedAt: DateTime.now(),
                canAutoHeal: true,
                rootCauseDiagnosis: 'Student was deleted or archived without releasing their desk.',
                remediationSuggestion: 'Release the desk so it becomes available for new admissions.',
                metadata: {'seatId': seat.id, 'studentId': seat.studentId, 'sectionId': seat.sectionId},
              ),
            );
          } else if (student.seatId != seat.id) {
            anomalies.add(
              SentinelAnomaly(
                id: 'mismatch_seat_${seat.id}_student_${student.id}',
                title: 'Desk ↔ Student Desync: ${SeatHelper.formatDeskLabel(seatId: seat.id, rawLabel: seat.label)}',
                description: 'Desk is assigned to ${student.name}, but the student profile points to desk ${student.seatId ?? "none"}.',
                severity: SentinelSeverity.warning,
                domain: SentinelDomain.seats,
                entityId: seat.id,
                detectedAt: DateTime.now(),
                canAutoHeal: true,
                rootCauseDiagnosis: 'Desk reassignment was interrupted before both documents completed saving.',
                remediationSuggestion: 'Re-sync double-binding between student and desk.',
                metadata: {
                  'seatId': seat.id,
                  'studentId': student.id,
                  'sectionId': seat.sectionId,
                  'studentAssignedSeat': student.seatId,
                },
              ),
            );
          }
        }
      }
    }

    // Check from Student perspective
    for (final student in students) {
      if (student.membershipStatus == MembershipStatus.active &&
          student.seatId != null &&
          student.seatId!.isNotEmpty) {
        final seat = seatMap[student.seatId];
        if (seat == null) {
          anomalies.add(
            SentinelAnomaly(
              id: 'mismatch_student_${student.id}_missing_seat',
              title: 'Invalid Desk Reference for ${student.name}',
              description: 'Student has desk ID ${student.seatId}, but that desk does not exist in any section.',
              severity: SentinelSeverity.warning,
              domain: SentinelDomain.students,
              entityId: student.id,
              detectedAt: DateTime.now(),
              canAutoHeal: true,
              rootCauseDiagnosis: 'The assigned desk or section was deleted without clearing student desk pointers.',
              remediationSuggestion: 'Assign an active desk or clear the invalid desk reference.',
              metadata: {'studentId': student.id, 'invalidSeatId': student.seatId},
            ),
          );
        } else if (seat.status != SeatStatus.occupied || seat.studentId != student.id) {
          anomalies.add(
            SentinelAnomaly(
              id: 'mismatch_student_${student.id}_seat_${seat.id}',
              title: 'Unclaimed Desk Pointer for ${student.name}',
              description: 'Student is assigned to ${SeatHelper.formatDeskLabel(seatId: seat.id, rawLabel: seat.label)}, but the desk is not marked as occupied by them.',
              severity: SentinelSeverity.warning,
              domain: SentinelDomain.students,
              entityId: student.id,
              detectedAt: DateTime.now(),
              canAutoHeal: true,
              rootCauseDiagnosis: 'Seat occupancy status write failed or was overwritten by concurrent update.',
              remediationSuggestion: 'Mark desk as occupied by ${student.name}.',
              metadata: {'studentId': student.id, 'seatId': seat.id, 'sectionId': seat.sectionId},
            ),
          );
        }
      }
    }

    return anomalies;
  }

  /// Invariant 2: 5-Minute Cart Soft-Lock Expiry (Zombie Hold Hunter).
  /// Detects any seat held under 'registration_hold' where the 5-minute window has passed.
  List<SentinelAnomaly> auditExpiredCartHolds(List<SeatModel> seats) {
    final anomalies = <SentinelAnomaly>[];
    final now = DateTime.now();

    for (final seat in seats) {
      if (seat.status == SeatStatus.reserved) {
        if (seat.reservationExpiresAt != null && seat.reservationExpiresAt!.isBefore(now)) {
          final heldDurationMin = now.difference(seat.reservationExpiresAt!).inMinutes;
          anomalies.add(
            SentinelAnomaly(
              id: 'zombie_hold_${seat.id}',
              title: 'Expired Cart Hold on ${SeatHelper.formatDeskLabel(seatId: seat.id, rawLabel: seat.label)}',
              description:
                  'Seat reservation expired $heldDurationMin minutes ago (Type: ${seat.reservationType ?? "hold"}).',
              severity: SentinelSeverity.warning,
              domain: SentinelDomain.seats,
              entityId: seat.id,
              detectedAt: now,
              canAutoHeal: true,
              rootCauseDiagnosis: 'Applicant selected desk but closed browser tab before submitting registration.',
              remediationSuggestion: 'Release desk back to available pool.',
              metadata: {
                'seatId': seat.id,
                'sectionId': seat.sectionId,
                'expiresAt': seat.reservationExpiresAt?.toIso8601String(),
                'reservationType': seat.reservationType,
              },
            ),
          );
        }
      }
    }

    return anomalies;
  }

  /// Invariant 3: Financial Integrity & Non-Negative Dues Balance.
  /// A student's pending dues balance cannot be negative under normal accounting rules.
  List<SentinelAnomaly> auditFinancialInvariants(List<StudentModel> students) {
    final anomalies = <SentinelAnomaly>[];

    for (final student in students) {
      if (student.pendingDueBalance != null && student.pendingDueBalance! < -0.01) {
        anomalies.add(
          SentinelAnomaly(
            id: 'negative_due_${student.id}',
            title: 'Negative Dues Balance: ${student.name}',
            description:
                'Student record shows a negative outstanding balance of ₹${student.pendingDueBalance!.abs().toStringAsFixed(2)}.',
            severity: SentinelSeverity.warning,
            domain: SentinelDomain.payments,
            entityId: student.id,
            detectedAt: DateTime.now(),
            canAutoHeal: true,
            rootCauseDiagnosis: 'Double payment deduction or manual balance reduction exceeding outstanding due.',
            remediationSuggestion: 'Reset balance to ₹0.00 or record an advance balance credit.',
            metadata: {'studentId': student.id, 'negativeBalance': student.pendingDueBalance},
          ),
        );
      }
    }

    return anomalies;
  }

  /// Invariant 4: Membership Plan Expiry vs Active Status.
  /// Warns when students whose plan expired more than grace period (e.g. 3 days) ago
  /// are still marked active.
  List<SentinelAnomaly> auditPlanExpiryInvariants(List<StudentModel> students, {int graceDays = 3}) {
    final anomalies = <SentinelAnomaly>[];
    final now = DateTime.now();

    for (final student in students) {
      if (student.membershipStatus == MembershipStatus.active && student.planEndDate != null) {
        final daysExpired = now.difference(student.planEndDate!).inDays;
        if (daysExpired > graceDays) {
          anomalies.add(
            SentinelAnomaly(
              id: 'overdue_plan_${student.id}',
              title: 'Overdue Active Membership: ${student.name}',
              description:
                  'Plan expired $daysExpired days ago (${student.planEndDate?.toIso8601String().substring(0, 10)}), exceeding the $graceDays-day grace window.',
              severity: SentinelSeverity.advisory,
              domain: SentinelDomain.students,
              entityId: student.id,
              detectedAt: now,
              canAutoHeal: false,
              rootCauseDiagnosis: 'Student has not renewed plan and counter staff has not suspended pass.',
              remediationSuggestion: 'Send 1-tap WhatsApp renewal reminder or mark membership as expired.',
              metadata: {'studentId': student.id, 'planEndDate': student.planEndDate?.toIso8601String()},
            ),
          );
        }
      }
    }

    return anomalies;
  }

  // ==========================================
  // AUTONOMOUS SELF-HEALING OPERATIONS
  // ==========================================

  /// Autonomously releases an expired soft-lock on a seat.
  Future<bool> autoHealExpiredSeatHold({
    required String libraryId,
    required String sectionId,
    required String seatId,
  }) async {
    try {
      final seatRef = _db
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .collection(FirestorePaths.seats)
          .doc(seatId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(seatRef);
        if (!snap.exists) return;

        final data = snap.data() ?? {};
        final status = data['status'] as String?;
        final expiresAtTimestamp = data['reservationExpiresAt'] as Timestamp?;

        // Double check expiration inside transaction
        if (status == 'reserved' &&
            (expiresAtTimestamp == null || expiresAtTimestamp.toDate().isBefore(DateTime.now()))) {
          tx.update(seatRef, {
            'status': 'available',
            'reservationType': FieldValue.delete(),
            'reservedCandidateId': FieldValue.delete(),
            'reservedCandidateName': FieldValue.delete(),
            'reservationExpiresAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      await _auditLogger?.log(
        action: AuditAction.updated,
        entityType: AuditEntity.seat,
        libraryId: libraryId,
        entityId: seatId,
        entityName: 'Desk $seatId',
        details: {'action': 'sentinel_auto_heal_expired_hold'},
      );

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Sentinel Invariant Engine] Auto-heal seat failed: $e');
      return false;
    }
  }

  /// Autonomously cleans ghost occupancy or releases an orphaned desk.
  Future<bool> autoHealGhostOccupancy({
    required String libraryId,
    required String sectionId,
    required String seatId,
  }) async {
    try {
      final seatRef = _db
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .collection(FirestorePaths.seats)
          .doc(seatId);

      await seatRef.update({
        'status': 'available',
        'studentId': FieldValue.delete(),
        'assignedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _auditLogger?.log(
        action: AuditAction.updated,
        entityType: AuditEntity.seat,
        libraryId: libraryId,
        entityId: seatId,
        entityName: 'Desk $seatId',
        details: {'action': 'sentinel_auto_heal_ghost_occupancy'},
      );

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Sentinel Invariant Engine] Auto-heal ghost occupancy failed: $e');
      return false;
    }
  }

  /// Autonomously heals a desynchronized desk binding where a desk references a student
  /// but the student references a different desk or none.
  Future<bool> autoHealDesyncedSeatBinding({
    required String libraryId,
    required String sectionId,
    required String seatId,
    required String studentId,
  }) async {
    try {
      final seatRef = _db
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .collection(FirestorePaths.seats)
          .doc(seatId);

      final studentRef = _db
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId);

      final studentDoc = await studentRef.get();
      if (!studentDoc.exists) {
        await seatRef.update({
          'status': 'available',
          'studentId': FieldValue.delete(),
          'assignedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      final studentData = studentDoc.data() ?? {};
      final studentSeatId = studentData['seatId'] as String?;

      if (studentSeatId == null || studentSeatId.isEmpty) {
        final seatDoc = await seatRef.get();
        final seatLabel = seatDoc.data()?['label']?.toString() ?? seatId;
        await studentRef.update({
          'seatId': seatId,
          'sectionId': sectionId,
          'seatLabel': seatLabel,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await seatRef.update({
          'status': 'occupied',
          'studentId': studentId,
          'studentName': studentData['name'] ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (studentSeatId != seatId) {
        await seatRef.update({
          'status': 'available',
          'studentId': FieldValue.delete(),
          'assignedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _auditLogger?.log(
        action: AuditAction.updated,
        entityType: AuditEntity.seat,
        libraryId: libraryId,
        entityId: seatId,
        entityName: 'Desk $seatId',
        details: {
          'action': 'sentinel_auto_heal_desynced_binding',
          'studentId': studentId,
        },
      );

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Sentinel Invariant Engine] Auto-heal desynced binding failed: $e');
      return false;
    }
  }

  /// Autonomously resets negative dues balance back to ₹0.00.
  Future<bool> autoHealNegativeDueBalance({
    required String libraryId,
    required String studentId,
  }) async {
    try {
      final studentRef = _db
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId);

      await studentRef.update({
        'pendingDueBalance': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _auditLogger?.log(
        action: AuditAction.updated,
        entityType: AuditEntity.student,
        libraryId: libraryId,
        entityId: studentId,
        entityName: 'Student $studentId',
        details: {'action': 'sentinel_auto_heal_negative_due_balance'},
      );

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Sentinel Invariant Engine] Auto-heal negative due failed: $e');
      return false;
    }
  }

  /// Autonomously heals an invalid or desynchronized desk reference on a student record.
  /// If the desk actually exists in Firestore, it establishes the double-binding.
  /// If the desk was deleted, it clears the invalid seat pointer so the student can be cleanly assigned.
  Future<bool> autoHealInvalidDeskReference({
    required String libraryId,
    required String studentId,
    String? invalidSeatId,
  }) async {
    try {
      final studentRef = _db
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId);

      final studentDoc = await studentRef.get();
      if (!studentDoc.exists) return false;
      final studentData = studentDoc.data() ?? {};
      final targetSeatId = invalidSeatId ?? (studentData['seatId'] as String?);

      if (targetSeatId == null || targetSeatId.isEmpty) return true;

      // Check if target seat exists in any section
      final sectionsSnapshot = await _db
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .get();

      DocumentReference? foundSeatRef;
      String? foundSectionId;
      String? foundSeatLabel;

      for (final secDoc in sectionsSnapshot.docs) {
        // 1. Direct ID lookup
        final directSeatDoc = await secDoc.reference
            .collection(FirestorePaths.seats)
            .doc(targetSeatId)
            .get();
        if (directSeatDoc.exists) {
          foundSeatRef = directSeatDoc.reference;
          foundSectionId = secDoc.id;
          foundSeatLabel = directSeatDoc.data()?['label']?.toString();
          break;
        }

        // 2. Fallback: match by student ID already recorded on seat
        final studentSeats = await secDoc.reference
            .collection(FirestorePaths.seats)
            .where('studentId', isEqualTo: studentId)
            .limit(1)
            .get();
        if (studentSeats.docs.isNotEmpty) {
          final sDoc = studentSeats.docs.first;
          foundSeatRef = sDoc.reference;
          foundSectionId = secDoc.id;
          foundSeatLabel = sDoc.data()['label']?.toString();
          break;
        }

        // 3. Fallback: match by seat number / label if targetSeatId encodes row/col or number
        final numOnly = SeatHelper.formatSeatNumberOnly(seatId: targetSeatId);
        if (numOnly.isNotEmpty) {
          final labelSeats = await secDoc.reference
              .collection(FirestorePaths.seats)
              .where('label', isEqualTo: numOnly)
              .limit(1)
              .get();
          if (labelSeats.docs.isNotEmpty) {
            final sDoc = labelSeats.docs.first;
            foundSeatRef = sDoc.reference;
            foundSectionId = secDoc.id;
            foundSeatLabel = sDoc.data()['label']?.toString() ?? numOnly;
            break;
          }
        }
      }

      if (foundSeatRef != null) {
        // Seat exists! Re-bind double-binding on BOTH seat and student
        final resolvedLabel = foundSeatLabel ?? SeatHelper.formatSeatNumberOnly(seatId: foundSeatRef.id);
        await foundSeatRef.update({
          'status': SeatStatus.occupied.name,
          'studentId': studentId,
          'studentName': studentData['name'] ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await studentRef.update({
          'seatId': foundSeatRef.id,
          'sectionId': foundSectionId,
          'seatLabel': resolvedLabel,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Seat does not exist in any section: safely clear invalid pointer so student can be reassigned
        await studentRef.update({
          'seatId': FieldValue.delete(),
          'sectionId': FieldValue.delete(),
          'seatLabel': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _auditLogger?.log(
        action: AuditAction.updated,
        entityType: AuditEntity.student,
        libraryId: libraryId,
        entityId: studentId,
        entityName: studentData['name']?.toString() ?? 'Student $studentId',
        details: {
          'action': 'sentinel_auto_heal_desk_reference',
          'invalidSeatId': targetSeatId,
          'recovered': foundSeatRef != null,
        },
      );

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Sentinel Invariant Engine] Auto-heal invalid desk reference failed: $e');
      return false;
    }
  }
}
