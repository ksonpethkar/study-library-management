import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/expiry_notification_service.dart';

/// Summary report returned after running membership automation.
class AutomationResult {
  final int checkedCount;
  final int enteredGraceCount;
  final int expiredCount;
  final int releasedSeatsCount;

  const AutomationResult({
    this.checkedCount = 0,
    this.enteredGraceCount = 0,
    this.expiredCount = 0,
    this.releasedSeatsCount = 0,
  });

  bool get hasChanges =>
      enteredGraceCount > 0 || expiredCount > 0 || releasedSeatsCount > 0;
}

/// 100% Free Client-Side Automation Service for Firebase Spark Tier.
///
/// Runs daily maintenance whenever the admin opens the dashboard:
/// - Detects plans that reached their end date.
/// - Transitions active students to `grace` during their grace period.
/// - Once the grace period expires, transitions students to `expired`
///   and auto-releases their seat back to `available` on the seat map.
/// - Fires local notification alerts for upcoming expiries.
class MembershipAutomationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _isRunning = false;

  /// Runs daily maintenance for the specified library.
  /// Set [force] = true to bypass the 4-hour cooldown (e.g. from Settings screen).
  static Future<AutomationResult> runDailyMaintenance(
    String libraryId, {
    bool force = false,
  }) async {
    if (_isRunning || libraryId.isEmpty) return const AutomationResult();
    _isRunning = true;

    try {
      final now = DateTime.now();
      final libRef = _firestore.collection('libraries').doc(libraryId);
      final libDoc = await libRef.get();

      if (!libDoc.exists) return const AutomationResult();

      final data = libDoc.data() ?? {};

      // 4-hour cooldown unless forced
      if (!force) {
        final lastRunStr = data['lastAutomationRunAt'] as String?;
        if (lastRunStr != null) {
          final lastRun = DateTime.tryParse(lastRunStr);
          if (lastRun != null && now.difference(lastRun).inHours < 4) {
            return const AutomationResult();
          }
        }
      }

      // Default library grace period (defaults to 3 days if not set)
      final defaultGraceDays = (data['defaultGraceDays'] as num?)?.toInt() ?? 3;

      // Query all students who are currently active or in grace
      final studentsSnap = await libRef
          .collection('students')
          .where('membershipStatus', whereIn: [
            MembershipStatus.active.name,
            MembershipStatus.grace.name,
          ])
          .get();

      int checked = studentsSnap.docs.length;
      int enteredGrace = 0;
      int expired = 0;
      int releasedSeats = 0;

      final batch = _firestore.batch();
      bool hasBatchOps = false;

      for (final doc in studentsSnap.docs) {
        final studentData = doc.data();
        final planEndRaw = studentData['planEndDate'];
        if (planEndRaw == null) continue;

        DateTime? planEnd;
        if (planEndRaw is Timestamp) {
          planEnd = planEndRaw.toDate();
        } else if (planEndRaw is String) {
          planEnd = DateTime.tryParse(planEndRaw);
        } else if (planEndRaw is int) {
          planEnd = DateTime.fromMillisecondsSinceEpoch(planEndRaw);
        }

        if (planEnd == null) continue;

        // Calculate grace end
        DateTime graceEnd;
        final graceEndRaw = studentData['graceEndDate'];
        if (graceEndRaw is Timestamp) {
          graceEnd = graceEndRaw.toDate();
        } else if (graceEndRaw is String) {
          graceEnd = DateTime.tryParse(graceEndRaw) ??
              planEnd.add(Duration(days: defaultGraceDays));
        } else {
          graceEnd = planEnd.add(Duration(days: defaultGraceDays));
        }

        final currentStatus =
            studentData['membershipStatus'] as String? ?? 'active';
        final seatId = studentData['seatId'] as String?;
        final sectionId = studentData['sectionId'] as String?;
        final studentName = studentData['name'] as String? ?? 'Student';

        // ── SCENARIO A: Expired past grace period ──────────────────────────
        if (now.isAfter(graceEnd)) {
          expired++;
          final studentUpdate = <String, dynamic>{
            'membershipStatus': MembershipStatus.expired.name,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // Auto-release seat if assigned
          if (seatId != null &&
              seatId.isNotEmpty &&
              sectionId != null &&
              sectionId.isNotEmpty) {
            final seatRef = libRef
                .collection('sections')
                .doc(sectionId)
                .collection('seats')
                .doc(seatId);

            batch.update(seatRef, {
              'status': SeatStatus.available.name,
              'studentId': null,
            });

            studentUpdate['seatId'] = null;
            studentUpdate['sectionId'] = null;
            releasedSeats++;
          }

          batch.update(doc.reference, studentUpdate);
          hasBatchOps = true;

          // Write audit log entry
          final auditRef = libRef.collection('audit_log').doc();
          batch.set(auditRef, {
            'action': 'expired',
            'entityType': 'student',
            'entityId': doc.id,
            'userId': 'system_automation',
            'timestamp': FieldValue.serverTimestamp(),
            'details': {
              'studentName': studentName,
              'seatReleased': seatId != null && seatId.isNotEmpty,
              'releasedSeatId': seatId,
              'reason': 'Plan and grace period expired',
            },
          });
        }
        // ── SCENARIO B: Plan expired, currently in grace period ────────────
        else if (now.isAfter(planEnd) &&
            currentStatus != MembershipStatus.grace.name) {
          enteredGrace++;
          batch.update(doc.reference, {
            'membershipStatus': MembershipStatus.grace.name,
            'graceEndDate': Timestamp.fromDate(graceEnd),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          hasBatchOps = true;

          // Write audit log entry
          final auditRef = libRef.collection('audit_log').doc();
          batch.set(auditRef, {
            'action': 'updated',
            'entityType': 'student',
            'entityId': doc.id,
            'userId': 'system_automation',
            'timestamp': FieldValue.serverTimestamp(),
            'details': {
              'studentName': studentName,
              'note': 'Plan expired. Entered grace period until ${graceEnd.toLocal().toString().split(" ")[0]}',
            },
          });
        }
      }

      // Record last run time
      batch.update(libRef, {
        'lastAutomationRunAt': now.toIso8601String(),
      });

      if (hasBatchOps) {
        await batch.commit();
      }

      // Also trigger upcoming expiry notification checks
      try {
        await ExpiryNotificationService.checkExpiringPlans(libraryId);
      } catch (e) {
        debugPrint('Expiry notification check error: $e');
      }

      return AutomationResult(
        checkedCount: checked,
        enteredGraceCount: enteredGrace,
        expiredCount: expired,
        releasedSeatsCount: releasedSeats,
      );
    } catch (e) {
      debugPrint('Membership automation failed: $e');
      return const AutomationResult();
    } finally {
      _isRunning = false;
    }
  }
}
