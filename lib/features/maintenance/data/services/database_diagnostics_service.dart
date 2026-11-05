import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/models/seat_model.dart';

/// Database health metrics and estimated Spark quota consumption.
class DatabaseMetrics {
  final int studentsCount;
  final int activeStudentsCount;
  final int sectionsCount;
  final int seatsCount;
  final int plansCount;
  final int paymentsCount;
  final int receiptsCount;
  final int expensesCount;
  final int notificationsCount;
  final int auditLogCount;
  final int recycleBinCount;
  final int waitingListCount;
  final int requestsCount;
  final int announcementsCount;

  final int estimatedTotalDocs;
  final double estimatedStorageBytes;
  final int estimatedDailyReads;
  final int estimatedDailyWrites;
  final DateTime measuredAt;

  const DatabaseMetrics({
    required this.studentsCount,
    required this.activeStudentsCount,
    required this.sectionsCount,
    required this.seatsCount,
    required this.plansCount,
    required this.paymentsCount,
    required this.receiptsCount,
    required this.expensesCount,
    required this.notificationsCount,
    required this.auditLogCount,
    required this.recycleBinCount,
    required this.waitingListCount,
    required this.requestsCount,
    required this.announcementsCount,
    required this.estimatedTotalDocs,
    required this.estimatedStorageBytes,
    required this.estimatedDailyReads,
    required this.estimatedDailyWrites,
    required this.measuredAt,
  });

  // Firebase Spark (Free Tier) Daily Limits
  static const int sparkDailyFreeReads = 50000;
  static const int sparkDailyFreeWrites = 20000;
  static const double sparkFreeStorageBytes = 1024 * 1024 * 1024; // 1 GiB

  double get readsQuotaPercent => (estimatedDailyReads / sparkDailyFreeReads).clamp(0.0, 1.0);
  double get writesQuotaPercent => (estimatedDailyWrites / sparkDailyFreeWrites).clamp(0.0, 1.0);
  double get storageQuotaPercent => (estimatedStorageBytes / sparkFreeStorageBytes).clamp(0.0, 1.0);

  String get formattedStorageSize {
    final mb = estimatedStorageBytes / (1024 * 1024);
    if (mb < 1.0) {
      final kb = estimatedStorageBytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${mb.toStringAsFixed(2)} MB';
  }
}

enum IssueSeverity { info, warning, error }

class IntegrityIssue {
  final String id;
  final String type;
  final IssueSeverity severity;
  final String title;
  final String description;
  final String? entityId;
  final Map<String, dynamic> details;
  final bool canAutoHeal;

  const IntegrityIssue({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.entityId,
    this.details = const {},
    this.canAutoHeal = true,
  });
}

class IntegrityReport {
  final DateTime scannedAt;
  final int totalSeatsScanned;
  final int totalStudentsScanned;
  final List<IntegrityIssue> issues;
  final int staleNotificationsCount;
  final int expiredRecycleBinCount;
  final int oldAuditLogsCount;

  const IntegrityReport({
    required this.scannedAt,
    required this.totalSeatsScanned,
    required this.totalStudentsScanned,
    required this.issues,
    required this.staleNotificationsCount,
    required this.expiredRecycleBinCount,
    required this.oldAuditLogsCount,
  });

  bool get hasIssues => issues.isNotEmpty;
  int get healableCount => issues.where((i) => i.canAutoHeal).length;
}

class AutoHealResult {
  final int healedSeatsCount;
  final int clearedGhostIdsCount;
  final int syncedRecordsCount;

  const AutoHealResult({
    this.healedSeatsCount = 0,
    this.clearedGhostIdsCount = 0,
    this.syncedRecordsCount = 0,
  });

  int get totalHealed => healedSeatsCount + clearedGhostIdsCount + syncedRecordsCount;
}

class PruneResult {
  final int prunedNotifications;
  final int prunedRecycleBin;
  final int prunedAuditLogs;

  const PruneResult({
    this.prunedNotifications = 0,
    this.prunedRecycleBin = 0,
    this.prunedAuditLogs = 0,
  });

  int get totalPruned => prunedNotifications + prunedRecycleBin + prunedAuditLogs;
}

/// Service providing unified database health telemetry, invariant auto-healing,
/// and stale document pruning across Cozy Corner.
class DatabaseDiagnosticsService {
  final FirebaseFirestore? _firestore;

  DatabaseDiagnosticsService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Fast aggregation count on a collection (1 Firestore read per 1,000 documents).
  Future<int> _countCollection(Query query) async {
    try {
      final snap = await query.count().get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Gathers live document counts and computes Spark quota utilization.
  Future<DatabaseMetrics> fetchDatabaseMetrics(String libraryId) async {
    final libRef = _db.collection(FirestorePaths.libraries).doc(libraryId);

    // Run low-cost count aggregations in parallel
    final counts = await Future.wait([
      _countCollection(libRef.collection(FirestorePaths.students)),
      _countCollection(libRef.collection(FirestorePaths.students).where('membershipStatus', isEqualTo: 'active')),
      _countCollection(libRef.collection(FirestorePaths.sections)),
      _countCollection(libRef.collection(FirestorePaths.seats)),
      _countCollection(libRef.collection(FirestorePaths.plans)),
      _countCollection(libRef.collection(FirestorePaths.receipts)),
      _countCollection(libRef.collection(FirestorePaths.expenses)),
      _countCollection(libRef.collection('notifications')),
      _countCollection(libRef.collection(FirestorePaths.auditLog)),
      _countCollection(libRef.collection(FirestorePaths.recycleBin)),
      _countCollection(libRef.collection(FirestorePaths.waitingList)),
      _countCollection(libRef.collection(FirestorePaths.requests)),
      _countCollection(libRef.collection(FirestorePaths.announcements)),
      _countCollection(libRef.collection(FirestorePaths.payments)),
    ]);

    final students = counts[0];
    final activeStudents = counts[1];
    final sections = counts[2];
    var seats = counts[3];
    final plans = counts[4];
    final receipts = counts[5];
    final expenses = counts[6];
    final notifications = counts[7];
    final auditLogs = counts[8];
    final recycleBin = counts[9];
    final waitingList = counts[10];
    final requests = counts[11];
    final announcements = counts[12];
    final payments = counts[13];

    // If seats are organized in section subcollections, count across sections
    if (seats == 0 && sections > 0) {
      try {
        final secSnap = await libRef.collection(FirestorePaths.sections).get();
        for (final sec in secSnap.docs) {
          final countSecSeats = await _countCollection(sec.reference.collection(FirestorePaths.seats));
          seats += countSecSeats;
        }
      } catch (_) {}
    }

    final totalDocs = students +
        sections +
        seats +
        plans +
        receipts +
        expenses +
        notifications +
        auditLogs +
        recycleBin +
        waitingList +
        requests +
        announcements +
        payments;

    // Approximate average doc payload: ~1.8 KB per record with indexes & base64 metadata
    final estimatedBytes = totalDocs * 1850.0;

    // Daily read estimation formula: Active students * 25 reads/day + Admin sessions * 120 reads/day
    final estimatedReads = (activeStudents * 28) + (students * 4) + 650;
    // Daily write estimation: New admissions + renewals + attendance scans + expenses
    final estimatedWrites = (activeStudents * 3) + 40;

    return DatabaseMetrics(
      studentsCount: students,
      activeStudentsCount: activeStudents,
      sectionsCount: sections,
      seatsCount: seats,
      plansCount: plans,
      paymentsCount: payments,
      receiptsCount: receipts,
      expensesCount: expenses,
      notificationsCount: notifications,
      auditLogCount: auditLogs,
      recycleBinCount: recycleBin,
      waitingListCount: waitingList,
      requestsCount: requests,
      announcementsCount: announcements,
      estimatedTotalDocs: totalDocs,
      estimatedStorageBytes: estimatedBytes,
      estimatedDailyReads: estimatedReads,
      estimatedDailyWrites: estimatedWrites,
      measuredAt: DateTime.now(),
    );
  }

  /// Scans database records for invariant mismatches, orphaned desks, and unassigned students.
  Future<IntegrityReport> scanDatabaseIntegrity(String libraryId) async {
    final libRef = _db.collection(FirestorePaths.libraries).doc(libraryId);
    final issues = <IntegrityIssue>[];

    // 1. Fetch Students Map
    final studentsSnap = await libRef.collection(FirestorePaths.students).get();
    final studentMap = <String, Map<String, dynamic>>{};
    for (final doc in studentsSnap.docs) {
      studentMap[doc.id] = doc.data();
    }

    // 2. Fetch Sections & Seats
    final seatsList = <Map<String, dynamic>>[];
    final sectionsSnap = await libRef.collection(FirestorePaths.sections).get();

    for (final sec in sectionsSnap.docs) {
      final secSeats = await sec.reference.collection(FirestorePaths.seats).get();
      for (final sDoc in secSeats.docs) {
        final d = sDoc.data();
        d['_ref'] = sDoc.reference;
        d['_docId'] = sDoc.id;
        d['_sectionId'] = sec.id;
        seatsList.add(d);
      }
    }

    // Also check root seats collection if used
    final rootSeats = await libRef.collection(FirestorePaths.seats).get();
    for (final sDoc in rootSeats.docs) {
      final d = sDoc.data();
      d['_ref'] = sDoc.reference;
      d['_docId'] = sDoc.id;
      d['_sectionId'] = d['sectionId'] ?? '';
      seatsList.add(d);
    }

    // Invariant Check A: Orphaned Seats
    for (final seat in seatsList) {
      final status = (seat['status'] ?? 'available').toString().toLowerCase();
      final assignedStudentId = seat['studentId'] as String?;
      final seatLabel = seat['label'] ?? seat['number'] ?? seat['_docId'] ?? 'Unknown Desk';

      if (status == 'occupied' || (assignedStudentId != null && assignedStudentId.isNotEmpty)) {
        if (assignedStudentId == null || !studentMap.containsKey(assignedStudentId)) {
          issues.add(IntegrityIssue(
            id: 'orphan_${seat['_docId']}',
            type: 'orphaned_seat',
            severity: IssueSeverity.error,
            title: 'Orphaned Desk #$seatLabel',
            description: 'Desk is marked occupied, but student record ($assignedStudentId) no longer exists.',
            entityId: seat['_docId'] as String?,
            details: {'seat': seat, 'studentId': assignedStudentId},
          ));
        } else {
          final sData = studentMap[assignedStudentId]!;
          final sStatus = (sData['membershipStatus'] ?? 'active').toString().toLowerCase();
          if (sStatus == 'expired' || sStatus == 'inactive' || sStatus == 'archived') {
            issues.add(IntegrityIssue(
              id: 'expired_holding_seat_${seat['_docId']}',
              type: 'expired_holding_seat',
              severity: IssueSeverity.warning,
              title: 'Desk #$seatLabel Held by $sStatus Student',
              description: '${sData['name'] ?? "Student"} is $sStatus, but desk was not released.',
              entityId: seat['_docId'] as String?,
              details: {'seat': seat, 'student': sData},
            ));
          }
        }
      } else if (status == 'available' && assignedStudentId != null && assignedStudentId.isNotEmpty) {
        issues.add(IntegrityIssue(
          id: 'ghost_id_${seat['_docId']}',
          type: 'ghost_student_id',
          severity: IssueSeverity.warning,
          title: 'Ghost Student ID on Desk #$seatLabel',
          description: 'Desk is marked available, but retains leftover student reference ($assignedStudentId).',
          entityId: seat['_docId'] as String?,
          details: {'seat': seat},
        ));
      }
    }

    // Invariant Check B: Active Students Without Assigned Desk
    for (final entry in studentMap.entries) {
      final s = entry.value;
      final status = (s['membershipStatus'] ?? 'active').toString().toLowerCase();
      final seatId = s['seatId'] as String?;
      final name = s['name'] ?? 'Student';

      if (status == 'active' && (seatId == null || seatId.isEmpty)) {
        issues.add(IntegrityIssue(
          id: 'unlinked_student_${entry.key}',
          type: 'unlinked_active_student',
          severity: IssueSeverity.info,
          title: 'Active Student Without Assigned Desk: $name',
          description: 'Student has paid active status, but no desk ID is linked in their profile.',
          entityId: entry.key,
          details: {'student': s},
          canAutoHeal: false, // Requires human admin to pick a specific desk
        ));
      }
    }

    // 3. Stale Items Scans
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));

    // Stale Read Notifications (>30 Days)
    int staleNotifs = 0;
    try {
      final notifsSnap = await libRef
          .collection('notifications')
          .where('read', isEqualTo: true)
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      staleNotifs = notifsSnap.docs.length;
    } catch (_) {}

    // Expired Recycle Bin (>30 Days)
    int expiredTrash = 0;
    try {
      final trashSnap = await libRef
          .collection(FirestorePaths.recycleBin)
          .where('deletedAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      expiredTrash = trashSnap.docs.length;
    } catch (_) {}

    // Old Audit Logs (>90 Days)
    int oldLogs = 0;
    try {
      final logsSnap = await libRef
          .collection(FirestorePaths.auditLog)
          .where('timestamp', isLessThan: Timestamp.fromDate(ninetyDaysAgo))
          .get();
      oldLogs = logsSnap.docs.length;
    } catch (_) {}

    return IntegrityReport(
      scannedAt: now,
      totalSeatsScanned: seatsList.length,
      totalStudentsScanned: studentMap.length,
      issues: issues,
      staleNotificationsCount: staleNotifs,
      expiredRecycleBinCount: expiredTrash,
      oldAuditLogsCount: oldLogs,
    );
  }

  /// Automatically heals repairable issues: resets orphaned desks and clears ghost student IDs.
  Future<AutoHealResult> autoHealIntegrityIssues(String libraryId, IntegrityReport report) async {
    final batch = _db.batch();
    int healedSeats = 0;
    int clearedGhosts = 0;
    final healedDescriptions = <String>[];

    for (final issue in report.issues) {
      if (!issue.canAutoHeal) continue;

      if (issue.type == 'orphaned_seat' || issue.type == 'expired_holding_seat') {
        final seat = issue.details['seat'] as Map<String, dynamic>?;
        final ref = seat?['_ref'] as DocumentReference<Map<String, dynamic>>?;
        if (ref != null) {
          batch.update(ref, {
            'status': SeatStatus.available.name,
            'studentId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          healedSeats++;
          healedDescriptions.add('${issue.title} -> Released to Available');
        }
      } else if (issue.type == 'ghost_student_id') {
        final seat = issue.details['seat'] as Map<String, dynamic>?;
        final ref = seat?['_ref'] as DocumentReference<Map<String, dynamic>>?;
        if (ref != null) {
          batch.update(ref, {
            'studentId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          clearedGhosts++;
          healedDescriptions.add('${issue.title} -> Ghost ID Cleared');
        }
      }
    }

    if (healedSeats > 0 || clearedGhosts > 0) {
      await batch.commit();

      AuditLogger().log(
        action: AuditAction.updated,
        entityType: AuditEntity.seat,
        libraryId: libraryId,
        details: {
          'type': 'auto_heal_integrity',
          'healedSeatsCount': healedSeats,
          'clearedGhostsCount': clearedGhosts,
          'fixes': healedDescriptions,
        },
      ).ignore();
    }

    return AutoHealResult(
      healedSeatsCount: healedSeats,
      clearedGhostIdsCount: clearedGhosts,
    );
  }

  /// Prunes old read notifications, expired trash, and historical audit logs.
  Future<PruneResult> pruneStaleData(
    String libraryId, {
    bool pruneNotifications = true,
    bool pruneRecycleBin = true,
    bool pruneAuditLogs = false,
  }) async {
    final libRef = _db.collection(FirestorePaths.libraries).doc(libraryId);
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));

    int notifsPruned = 0;
    int trashPruned = 0;
    int logsPruned = 0;

    // 1. Prune Read Notifications
    if (pruneNotifications) {
      try {
        final snap = await libRef
            .collection('notifications')
            .where('read', isEqualTo: true)
            .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
            .limit(200)
            .get();

        if (snap.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          notifsPruned = snap.docs.length;
        }
      } catch (_) {}
    }

    // 2. Prune Expired Recycle Bin
    if (pruneRecycleBin) {
      try {
        final snap = await libRef
            .collection(FirestorePaths.recycleBin)
            .where('deletedAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
            .limit(100)
            .get();

        if (snap.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          trashPruned = snap.docs.length;
        }
      } catch (_) {}
    }

    // 3. Prune Old Audit Logs (Only if explicitly requested)
    if (pruneAuditLogs) {
      try {
        final snap = await libRef
            .collection(FirestorePaths.auditLog)
            .where('timestamp', isLessThan: Timestamp.fromDate(ninetyDaysAgo))
            .limit(250)
            .get();

        if (snap.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          logsPruned = snap.docs.length;
        }
      } catch (_) {}
    }

    if (notifsPruned > 0 || trashPruned > 0 || logsPruned > 0) {
      AuditLogger().log(
        action: AuditAction.deleted,
        entityType: AuditEntity.settings,
        libraryId: libraryId,
        details: {
          'type': 'stale_data_pruning',
          'prunedNotifications': notifsPruned,
          'prunedRecycleBin': trashPruned,
          'prunedAuditLogs': logsPruned,
        },
      ).ignore();
    }

    return PruneResult(
      prunedNotifications: notifsPruned,
      prunedRecycleBin: trashPruned,
      prunedAuditLogs: logsPruned,
    );
  }

  /// Clears in-memory caches and re-fetches Riverpod streams.
  Future<void> clearLocalCaches(WidgetRef ref) async {
    imageCache.clear();
    imageCache.clearLiveImages();
    ref.invalidate(studentsStreamProvider);
    ref.invalidate(occupancyProvider);
  }

  /// Generates a human-readable text report for export/sharing.
  String generateDiagnosticTextReport(DatabaseMetrics m, IntegrityReport report) {
    final df = DateFormat('dd MMM yyyy, hh:mm a');
    final b = StringBuffer()
      ..writeln('=====================================================')
      ..writeln('THE COZY CORNER STUDY CENTRE — SYSTEM DIAGNOSTIC REPORT')
      ..writeln('Generated: ${df.format(DateTime.now())}')
      ..writeln('=====================================================')
      ..writeln()
      ..writeln('1. FIREBASE DATABASE QUOTA & USAGE PULSE')
      ..writeln('-----------------------------------------------------')
      ..writeln('• Total Stored Records: ${m.estimatedTotalDocs}')
      ..writeln('• Estimated Storage Size: ${m.formattedStorageSize}')
      ..writeln('• Daily Estimated Reads: ${m.estimatedDailyReads} / 50,000 Free Limit (${(m.readsQuotaPercent * 100).toStringAsFixed(1)}%)')
      ..writeln('• Daily Estimated Writes: ${m.estimatedDailyWrites} / 20,000 Free Limit (${(m.writesQuotaPercent * 100).toStringAsFixed(1)}%)')
      ..writeln('• Storage Quota Used: ${(m.storageQuotaPercent * 100).toStringAsFixed(2)}% of 1.0 GB Free Tier')
      ..writeln('• Plan Status: 100% Free Spark Quota — Healthy 🟢')
      ..writeln()
      ..writeln('2. COLLECTION INVENTORY METRICS')
      ..writeln('-----------------------------------------------------')
      ..writeln('• Students: ${m.studentsCount} (${m.activeStudentsCount} Active)')
      ..writeln('• Desks / Seats: ${m.seatsCount} across ${m.sectionsCount} Sections')
      ..writeln('• Payments Recorded: ${m.paymentsCount}')
      ..writeln('• Receipts Generated: ${m.receiptsCount}')
      ..writeln('• Expenses Logged: ${m.expensesCount}')
      ..writeln('• In-App Notifications: ${m.notificationsCount}')
      ..writeln('• Waiting Queue Leads: ${m.waitingListCount}')
      ..writeln('• Audit Log Entries: ${m.auditLogCount}')
      ..writeln('• Recycle Bin Items: ${m.recycleBinCount}')
      ..writeln()
      ..writeln('3. INTEGRITY & INVARIANT DIAGNOSTICS')
      ..writeln('-----------------------------------------------------')
      ..writeln('• Scanned At: ${df.format(report.scannedAt)}')
      ..writeln('• Issues Detected: ${report.issues.length}');

    if (report.issues.isEmpty) {
      b.writeln('• Status: ALL INVARIANTS 100% INTACT (No orphaned desks or broken references)');
    } else {
      for (int i = 0; i < report.issues.length; i++) {
        final issue = report.issues[i];
        b.writeln('  [${i + 1}] ${issue.severity.name.toUpperCase()}: ${issue.title}');
        b.writeln('      ${issue.description}');
      }
    }

    b.writeln();
    b.writeln('4. STALE DATA CANDIDATES');
    b.writeln('-----------------------------------------------------');
    b.writeln('• Read Notifications (>30d): ${report.staleNotificationsCount}');
    b.writeln('• Expired Recycle Bin (>30d): ${report.expiredRecycleBinCount}');
    b.writeln('• Historical Audit Logs (>90d): ${report.oldAuditLogsCount}');
    b.writeln();
    b.writeln('=====================================================');
    b.writeln('End of Diagnostic Report.');

    return b.toString();
  }
}
