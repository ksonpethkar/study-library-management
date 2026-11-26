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

    // Invariant 1c: Multiple Active Students Assigned to the Same Desk (Duplicate Allocation)
    final seatToStudents = <String, List<StudentModel>>{};
    for (final student in students) {
      if (student.membershipStatus == MembershipStatus.active &&
          student.seatId != null &&
          student.seatId!.isNotEmpty) {
        seatToStudents.putIfAbsent(student.seatId!, () => []).add(student);
      }
    }

    for (final entry in seatToStudents.entries) {
      if (entry.value.length > 1) {
        final assignedSeatId = entry.key;
        final conflictingStudents = entry.value;
        final studentNames = conflictingStudents.map((s) => s.name).join(', ');
        final seat = seatMap[assignedSeatId];

        anomalies.add(
          SentinelAnomaly(
            id: 'duplicate_allocation_seat_$assignedSeatId',
            title: 'Duplicate Desk Allocation: ${SeatHelper.formatDeskLabel(seatId: assignedSeatId, rawLabel: seat?.label)}',
            description: '${conflictingStudents.length} students ($studentNames) are linked to the same desk simultaneously.',
            severity: SentinelSeverity.critical,
            domain: SentinelDomain.seats,
            entityId: assignedSeatId,
            detectedAt: DateTime.now(),
            canAutoHeal: true,
            rootCauseDiagnosis: 'Seat was assigned to a new student without releasing previous occupant pointer, or concurrent un-isolated assignment occurred.',
            remediationSuggestion: 'Retain desk on actual verified occupant and clear duplicate desk pointer from secondary student.',
            metadata: {
              'seatId': assignedSeatId,
              'sectionId': seat?.sectionId,
              'conflictingStudentIds': conflictingStudents.map((s) => s.id).toList(),
              'occupantStudentId': seat?.studentId,
            },
          ),
        );
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

  /// Invariant 5: Student Profile Photo Integrity & Shared/Swapped Avatar Collision Hunter.
  /// Detects students with missing profile photos, and critically flags when two distinct
  /// students share the exact same photo data or avatar URL.
  List<SentinelAnomaly> auditPhotoIntegrity(List<StudentModel> students) {
    final anomalies = <SentinelAnomaly>[];
    final photoToStudents = <String, List<StudentModel>>{};

    for (final student in students) {
      if (student.membershipStatus == MembershipStatus.active) {
        final photo = student.photoUrl.trim();
        if (photo.isEmpty) {
          anomalies.add(
            SentinelAnomaly(
              id: 'missing_photo_${student.id}',
              title: 'Missing Profile Photo: ${student.name}',
              description: 'Active scholar #${student.membershipNumber ?? student.id} has no profile photo attached.',
              severity: SentinelSeverity.advisory,
              domain: SentinelDomain.students,
              entityId: student.id,
              detectedAt: DateTime.now(),
              canAutoHeal: false,
              rootCauseDiagnosis: 'Student was registered without uploading a passport photo or photo capture was skipped.',
              remediationSuggestion: 'Open student profile and upload a passport-size photo.',
              metadata: {'studentId': student.id},
            ),
          );
        } else {
          // Normalize key: if data URL or long string, use hash + length to match identical images
          final key = photo.length > 120 ? '${photo.substring(0, 80)}_${photo.length}' : photo;
          photoToStudents.putIfAbsent(key, () => []).add(student);
        }
      }
    }

    // Flag cross-student photo collisions / swaps
    for (final entry in photoToStudents.entries) {
      if (entry.value.length > 1) {
        final conflictList = entry.value;
        final names = conflictList.map((s) => '${s.name} (#${s.membershipNumber ?? s.id})').join(', ');
        anomalies.add(
          SentinelAnomaly(
            id: 'duplicate_photo_${conflictList.first.id}_${conflictList.last.id}',
            title: 'Shared / Swapped Profile Photo Collision',
            description: '${conflictList.length} distinct scholars ($names) share the exact same profile photo data!',
            severity: SentinelSeverity.critical,
            domain: SentinelDomain.students,
            entityId: conflictList.first.id,
            detectedAt: DateTime.now(),
            canAutoHeal: false,
            rootCauseDiagnosis: 'Same Google Sign-In avatar or cached camera image was submitted during consecutive registrations on a shared device.',
            remediationSuggestion: 'Open scholar dossier and re-upload distinct verified photos for each student.',
            metadata: {
              'studentIds': conflictList.map((s) => s.id).toList(),
              'studentNames': conflictList.map((s) => s.name).toList(),
            },
          ),
        );
      }
    }

    return anomalies;
  }

  /// Invariant 6: Identity Uniqueness (Duplicate Aadhaar / Gov ID & Contact Number Collision).
  /// Enforces that two active students cannot share the same Aadhaar/Gov ID number or personal phone.
  List<SentinelAnomaly> auditIdentityUniqueness(List<StudentModel> students) {
    final anomalies = <SentinelAnomaly>[];
    final activeStudents = students.where((s) => s.membershipStatus == MembershipStatus.active).toList();

    // 1. Phone collision
    final phoneToStudents = <String, List<StudentModel>>{};
    for (final s in activeStudents) {
      final clean = s.phone.replaceAll(RegExp(r'\D'), '');
      if (clean.length >= 10) {
        final standardPhone = clean.substring(clean.length - 10);
        phoneToStudents.putIfAbsent(standardPhone, () => []).add(s);
      }
    }
    for (final entry in phoneToStudents.entries) {
      if (entry.value.length > 1) {
        final list = entry.value;
        final names = list.map((s) => '${s.name} (#${s.membershipNumber ?? s.id})').join(', ');
        anomalies.add(
          SentinelAnomaly(
            id: 'duplicate_phone_${entry.key}',
            title: 'Shared Contact Number: ${entry.key}',
            description: '${list.length} active scholars ($names) share the exact same mobile phone.',
            severity: SentinelSeverity.warning,
            domain: SentinelDomain.students,
            entityId: list.first.id,
            detectedAt: DateTime.now(),
            canAutoHeal: false,
            rootCauseDiagnosis: 'Family registration or duplicate account creation with same mobile number.',
            remediationSuggestion: 'Verify if students are genuine family members or merge duplicate records.',
            metadata: {
              'phone': entry.key,
              'studentIds': list.map((s) => s.id).toList(),
            },
          ),
        );
      }
    }

    // 2. Gov ID / Aadhaar collision
    final govIdToStudents = <String, List<StudentModel>>{};
    for (final s in activeStudents) {
      final cleanId = s.govIdNumber.replaceAll(RegExp(r'\s|-'), '').toUpperCase();
      if (cleanId.length >= 6) {
        govIdToStudents.putIfAbsent(cleanId, () => []).add(s);
      }
    }
    for (final entry in govIdToStudents.entries) {
      if (entry.value.length > 1) {
        final list = entry.value;
        final names = list.map((s) => '${s.name} (#${s.membershipNumber ?? s.id})').join(', ');
        anomalies.add(
          SentinelAnomaly(
            id: 'duplicate_govid_${entry.key}',
            title: 'Duplicate Gov ID / Aadhaar Collision: ${entry.key}',
            description: '${list.length} active scholars ($names) share the exact same Gov ID number.',
            severity: SentinelSeverity.critical,
            domain: SentinelDomain.students,
            entityId: list.first.id,
            detectedAt: DateTime.now(),
            canAutoHeal: false,
            rootCauseDiagnosis: 'Duplicate enrollment under same identity or erroneous ID number input.',
            remediationSuggestion: 'Verify physical Aadhaar/Pan card and correct document numbers.',
            metadata: {
              'govId': entry.key,
              'studentIds': list.map((s) => s.id).toList(),
            },
          ),
        );
      }
    }

    return anomalies;
  }

  /// Invariant 7: Desk Format & Raw Matrix Identifier Leaks.
  /// Detects unformatted database matrix IDs (e.g. `1790647291016_r0_c2`) or double prefixes (`Seat Seat #`).
  List<SentinelAnomaly> auditDeskFormatIntegrity({
    required List<SeatModel> seats,
    required List<StudentModel> students,
  }) {
    final anomalies = <SentinelAnomaly>[];

    for (final seat in seats) {
      final raw = seat.label.trim();
      if (raw.contains('_r') && raw.contains('_c')) {
        anomalies.add(
          SentinelAnomaly(
            id: 'raw_desk_label_${seat.id}',
            title: 'Raw Matrix ID in Desk Label',
            description: 'Desk ${seat.id} has unformatted coordinate label "$raw".',
            severity: SentinelSeverity.warning,
            domain: SentinelDomain.seats,
            entityId: seat.id,
            detectedAt: DateTime.now(),
            canAutoHeal: true,
            rootCauseDiagnosis: 'Desk layout generator saved raw coordinate string as display label.',
            remediationSuggestion: 'Auto-heal to normalize desk label to clean human number.',
            metadata: {'seatId': seat.id, 'sectionId': seat.sectionId, 'rawLabel': raw},
          ),
        );
      } else if (raw.toLowerCase().contains('seat seat') || raw.toLowerCase().contains('desk #seat')) {
        anomalies.add(
          SentinelAnomaly(
            id: 'double_prefix_label_${seat.id}',
            title: 'Double Prefix in Desk Label: "$raw"',
            description: 'Desk label contains recursive prefix.',
            severity: SentinelSeverity.warning,
            domain: SentinelDomain.seats,
            entityId: seat.id,
            detectedAt: DateTime.now(),
            canAutoHeal: true,
            rootCauseDiagnosis: 'Multiple widgets concatenated prefixes on top of already prefixed labels.',
            remediationSuggestion: 'Normalize desk label using SeatHelper.',
            metadata: {'seatId': seat.id, 'sectionId': seat.sectionId, 'rawLabel': raw},
          ),
        );
      }
    }

    for (final student in students) {
      if (student.seatId != null && student.seatId!.isNotEmpty) {
        final label = SeatHelper.formatDeskLabel(seatId: student.seatId);
        if (label.toLowerCase().contains('seat seat') || label.toLowerCase().contains('desk #seat')) {
          anomalies.add(
            SentinelAnomaly(
              id: 'student_seat_label_anomaly_${student.id}',
              title: 'Malformed Desk String for ${student.name}',
              description: 'Formatted desk label produces recursive prefix: "$label".',
              severity: SentinelSeverity.warning,
              domain: SentinelDomain.students,
              entityId: student.id,
              detectedAt: DateTime.now(),
              canAutoHeal: false,
              rootCauseDiagnosis: 'Historical database record holds malformed seat identifier.',
              remediationSuggestion: 'Re-save desk assignment via Desk Allocator.',
              metadata: {'studentId': student.id, 'seatId': student.seatId},
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
          'studentName': FieldValue.delete(),
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
          'studentName': FieldValue.delete(),
          'reservedCandidateName': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (studentSeatId != seatId) {
        await seatRef.update({
          'status': 'available',
          'studentId': FieldValue.delete(),
          'studentName': FieldValue.delete(),
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
          'studentName': FieldValue.delete(),
          'reservedCandidateName': FieldValue.delete(),
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

  /// Autonomously resolves duplicate seat allocation across multiple students.
  Future<bool> autoHealDuplicateSeatAllocation({
    required String libraryId,
    required String seatId,
    required List<String> conflictingStudentIds,
    String? preferredOccupantId,
    String? sectionId,
  }) async {
    try {
      final libRef = _db.collection(FirestorePaths.libraries).doc(libraryId);

      DocumentReference? targetSeatRef;
      String? targetSectionId = sectionId;
      String? actualOccupant = preferredOccupantId;
      String? actualOccupantName;

      // 1. Locate physical seat in designated section
      if (targetSectionId != null && targetSectionId.isNotEmpty) {
        final seatDoc = await libRef
            .collection(FirestorePaths.sections)
            .doc(targetSectionId)
            .collection(FirestorePaths.seats)
            .doc(seatId)
            .get();
        if (seatDoc.exists) {
          targetSeatRef = seatDoc.reference;
          actualOccupant ??= seatDoc.data()?['studentId'] as String?;
          actualOccupantName ??= seatDoc.data()?['studentName'] as String?;
        }
      }

      // 2. Multi-section fallback search (when sectionId is null or seat not found)
      if (targetSeatRef == null) {
        final sectionsSnap = await libRef.collection(FirestorePaths.sections).get();
        for (final secDoc in sectionsSnap.docs) {
          // Direct ID lookup
          final sDoc = await secDoc.reference.collection(FirestorePaths.seats).doc(seatId).get();
          if (sDoc.exists) {
            targetSeatRef = sDoc.reference;
            targetSectionId = secDoc.id;
            actualOccupant ??= sDoc.data()?['studentId'] as String?;
            actualOccupantName ??= sDoc.data()?['studentName'] as String?;
            break;
          }

          // Match by seat number/label (e.g. '20')
          final numOnly = SeatHelper.formatSeatNumberOnly(seatId: seatId);
          if (numOnly.isNotEmpty) {
            final labelMatches = await secDoc.reference
                .collection(FirestorePaths.seats)
                .where('label', isEqualTo: numOnly)
                .limit(1)
                .get();
            if (labelMatches.docs.isNotEmpty) {
              final matched = labelMatches.docs.first;
              targetSeatRef = matched.reference;
              targetSectionId = secDoc.id;
              actualOccupant ??= matched.data()['studentId'] as String?;
              actualOccupantName ??= matched.data()['studentName'] as String?;
              break;
            }
          }
        }
      }

      // 3. Fallback to root seats collection if vintage single-section
      if (targetSeatRef == null) {
        final rootSeatDoc = await libRef.collection(FirestorePaths.seats).doc(seatId).get();
        if (rootSeatDoc.exists) {
          targetSeatRef = rootSeatDoc.reference;
          actualOccupant ??= rootSeatDoc.data()?['studentId'] as String?;
          actualOccupantName ??= rootSeatDoc.data()?['studentName'] as String?;
        }
      }

      // 4. Resolve legitimate occupant if still undetermined
      if (actualOccupant == null || !conflictingStudentIds.contains(actualOccupant)) {
        StudentModel? bestStudent;
        for (final sId in conflictingStudentIds) {
          final sDoc = await libRef.collection(FirestorePaths.students).doc(sId).get();
          if (sDoc.exists) {
            final student = StudentModel.fromJson({'id': sDoc.id, ...sDoc.data() ?? {}});
            if (bestStudent == null) {
              bestStudent = student;
            } else if (student.membershipStatus == MembershipStatus.active &&
                bestStudent.membershipStatus != MembershipStatus.active) {
              bestStudent = student;
            }
          }
        }
        if (bestStudent != null) {
          actualOccupant = bestStudent.id;
          actualOccupantName = bestStudent.name;
        } else if (conflictingStudentIds.isNotEmpty) {
          actualOccupant = conflictingStudentIds.first;
        }
      }

      // If name is still missing, fetch it from student doc
      if (actualOccupant != null && (actualOccupantName == null || actualOccupantName.isEmpty)) {
        final studentDoc = await libRef.collection(FirestorePaths.students).doc(actualOccupant).get();
        if (studentDoc.exists) {
          actualOccupantName = studentDoc.data()?['name'] as String?;
        }
      }

      if (actualOccupant != null) {
        final batch = _db.batch();

        // (a) Clear duplicate seat references from all other students
        for (final sId in conflictingStudentIds) {
          if (sId != actualOccupant) {
            final sRef = libRef.collection(FirestorePaths.students).doc(sId);
            final sSnap = await sRef.get();
            if (sSnap.exists) {
              batch.set(
                sRef,
                {
                  'seatId': FieldValue.delete(),
                  'previousSeatId': seatId,
                  if (targetSectionId != null && targetSectionId.isNotEmpty)
                    'previousSectionId': targetSectionId,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
            }
          }
        }

        // (b) Confirm double-binding on legitimate retained student
        final retainedRef = libRef.collection(FirestorePaths.students).doc(actualOccupant);
        final retSnap = await retainedRef.get();
        if (retSnap.exists) {
          batch.set(
            retainedRef,
            {
              'seatId': targetSeatRef != null ? targetSeatRef.id : seatId,
              if (targetSectionId != null && targetSectionId.isNotEmpty)
                'sectionId': targetSectionId,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        // (c) Update physical seat document to reflect legitimate occupant without public PII
        if (targetSeatRef != null) {
          batch.set(
            targetSeatRef,
            {
              'studentId': actualOccupant,
              'studentName': FieldValue.delete(),
              'reservedCandidateName': FieldValue.delete(),
              'status': 'occupied',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
      }

      try {
        await _auditLogger?.log(
          action: AuditAction.updated,
          entityType: AuditEntity.seat,
          libraryId: libraryId,
          entityId: seatId,
          entityName: 'Desk $seatId',
          details: {
            'action': 'sentinel_auto_heal_duplicate_seat_allocation',
            'retainedOccupant': actualOccupant,
            'clearedStudentIds': conflictingStudentIds.where((id) => id != actualOccupant).toList(),
          },
        );
      } catch (_) {}

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Sentinel Invariant Engine] Auto-heal duplicate seat failed: $e');
      return false;
    }
  }
}
