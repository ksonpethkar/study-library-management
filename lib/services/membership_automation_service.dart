import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/expiry_notification_service.dart';
import 'package:study_library/services/waiting_list_promotion_service.dart';

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

      // Load grace period from settings/grace_period document (admin-configured).
      // Falls back to 3 days if not configured yet.
      // Key is 'defaultDays' and 'planOverrides' (as saved by GracePeriodScreen).
      int defaultGraceDays = 3;
      final planOverrides = <String, int>{};
      try {
        final gracePeriodDoc = await libRef
            .collection('settings')
            .doc('grace_period')
            .get();
        if (gracePeriodDoc.exists) {
          final data = gracePeriodDoc.data();
          if (data != null) {
            defaultGraceDays =
                (data['defaultDays'] as num?)?.toInt() ?? 3;
            final rawOverrides = data['planOverrides'] as Map<String, dynamic>?;
            if (rawOverrides != null) {
              rawOverrides.forEach((k, v) {
                if (v is num) {
                  planOverrides[k] = v.toInt();
                } else if (v is String) {
                  final parsed = int.tryParse(v);
                  if (parsed != null) planOverrides[k] = parsed;
                }
              });
            }
          }
        }
      } catch (_) {
        // Use default if settings not found
      }

      // Query catalog plans to load plan-level gracePeriodDays (Recommendation 1: Single Source of Truth)
      final planGraceDays = <String, int>{};
      try {
        final plansSnap = await libRef.collection('plans').get();
        for (final pDoc in plansSnap.docs) {
          final pData = pDoc.data();
          final gDays = (pData['gracePeriodDays'] as num?)?.toInt();
          if (gDays != null) planGraceDays[pDoc.id] = gDays;
        }
      } catch (_) {}

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
      final newlyReleasedSeats = <Map<String, String>>[];

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

        // Resolve plan-specific override, catalog plan setting, or global default (3-tier resolution)
        final studentPlanId = studentData['planId'] as String?;
        final int effectiveGraceDays = (studentPlanId != null && planOverrides.containsKey(studentPlanId))
            ? planOverrides[studentPlanId]!
            : (studentPlanId != null && planGraceDays.containsKey(studentPlanId)
                ? planGraceDays[studentPlanId]!
                : defaultGraceDays);

        // Calculate grace end safely anchored to the current planEnd
        DateTime graceEnd;
        final graceEndRaw = studentData['graceEndDate'];
        if (graceEndRaw is Timestamp) {
          final parsed = graceEndRaw.toDate();
          graceEnd = parsed.isAfter(planEnd) ? parsed : planEnd.add(Duration(days: effectiveGraceDays));
        } else if (graceEndRaw is String) {
          final parsed = DateTime.tryParse(graceEndRaw);
          graceEnd = (parsed != null && parsed.isAfter(planEnd))
              ? parsed
              : planEnd.add(Duration(days: effectiveGraceDays));
        } else {
          graceEnd = planEnd.add(Duration(days: effectiveGraceDays));
        }

        final currentStatus =
            studentData['membershipStatus'] as String? ?? 'active';
        final seatId = studentData['seatId'] as String?;
        final sectionId = studentData['sectionId'] as String?;
        final studentName = studentData['name'] as String? ?? 'Student';
        final studentUserId = studentData['userId'] as String? ?? doc.id;
        final seatText = studentData['seatLabel'] != null
            ? 'Seat #${studentData['seatLabel']}'
            : (seatId != null && seatId.isNotEmpty ? 'Seat #$seatId' : 'your study desk');

        // Multi-stage renewal tracking
        final remindedStages = List<String>.from(studentData['remindedStages'] as List<dynamic>? ?? []);
        bool updatedStages = false;

        final todayMid = DateTime(now.year, now.month, now.day);
        final planEndMid = DateTime(planEnd.year, planEnd.month, planEnd.day);
        final daysLeft = planEndMid.difference(todayMid).inDays;

        // Stage 1: T-3 Days (Upcoming Expiry Reminder)
        if (daysLeft == 3 && currentStatus == MembershipStatus.active.name) {
          if (!remindedStages.contains('T-3')) {
            remindedStages.add('T-3');
            updatedStages = true;
            libRef.collection('notifications').add({
              'title': '📅 Membership Expiring in 3 Days',
              'body': 'Hello $studentName, your membership for $seatText expires in 3 days. Renew now to retain your seat!',
              'targetRole': 'student',
              'targetUserId': studentUserId,
              'type': 'plan_expiring',
              'actionRoute': '/student/renew',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // Stage 2: T-0 Day (Expires Today Urgent Notice)
        if (daysLeft == 0 && currentStatus == MembershipStatus.active.name) {
          if (!remindedStages.contains('T-0')) {
            remindedStages.add('T-0');
            updatedStages = true;
            libRef.collection('notifications').add({
              'title': '⚠️ Membership Expires Today!',
              'body': 'Dear $studentName, today is the final day of your current pass for $seatText. Tap to renew now.',
              'targetRole': 'student',
              'targetUserId': studentUserId,
              'type': 'plan_expiring',
              'actionRoute': '/student/renew',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // Stage 3: T+2 Days (Grace Period Final Warning)
        if (daysLeft == -2 && currentStatus == MembershipStatus.grace.name) {
          if (!remindedStages.contains('T+2')) {
            remindedStages.add('T+2');
            updatedStages = true;
            libRef.collection('notifications').add({
              'title': '🚨 Final Grace Warning: Desk Release Tomorrow',
              'body': '$studentName, your grace period ends tomorrow. Renew today to retain your allocated $seatText!',
              'targetRole': 'student',
              'targetUserId': studentUserId,
              'type': 'plan_expired',
              'actionRoute': '/student/renew',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        if (updatedStages) {
          batch.update(doc.reference, {'remindedStages': remindedStages});
          hasBatchOps = true;
        }

        // ── SCENARIO A: Expired past grace period ──────────────────────────
        // Only release seat if BOTH the plan and the grace period have elapsed.
        if (now.isAfter(planEnd) && (now.isAfter(graceEnd) || now.isAtSameMomentAs(graceEnd))) {
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
            studentUpdate['previousSeatId'] = seatId;
            studentUpdate['previousSectionId'] = sectionId;
            releasedSeats++;
            newlyReleasedSeats.add({
              'seatId': seatId,
              'sectionId': sectionId,
              'studentName': studentName,
            });
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
            now.isBefore(graceEnd) &&
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

      // Phase 3 Automation Cascade: Link Seat Release directly to Waiting List Promotion Pipeline
      if (newlyReleasedSeats.isNotEmpty) {
        final promotionService = WaitingListPromotionService();
        for (final rel in newlyReleasedSeats) {
          try {
            await promotionService.handleSeatReleaseCascade(
              libraryId: libraryId,
              sectionId: rel['sectionId']!,
              seatId: rel['seatId']!,
              seatLabel: 'Seat ${rel['seatId']}',
            );
          } catch (e) {
            if (kDebugMode) debugPrint('Waiting list auto-promotion error: $e');
          }
        }
      }

      // Also trigger upcoming expiry notification checks
      try {
        await ExpiryNotificationService.checkExpiringPlans(libraryId);
      } catch (e) {
        if (kDebugMode) debugPrint('Expiry notification check error: $e');
      }

      // Check and cascade expired 2-hour waiting list holds
      try {
        await WaitingListPromotionService().checkAndCascadeExpiredHolds(libraryId);
      } catch (e) {
        if (kDebugMode) debugPrint('Expired waiting list hold cascade check error: $e');
      }

      return AutomationResult(
        checkedCount: checked,
        enteredGraceCount: enteredGrace,
        expiredCount: expired,
        releasedSeatsCount: releasedSeats,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Membership automation failed: $e');
      return const AutomationResult();
    } finally {
      _isRunning = false;
    }
  }
}
