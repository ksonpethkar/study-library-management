import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/file_download_helper.dart';
import 'package:study_library/core/utils/seat_helper.dart';

enum ExportDateRange {
  allTime,
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  custom,
}

extension ExportDateRangeExtension on ExportDateRange {
  String get label {
    switch (this) {
      case ExportDateRange.allTime:
        return 'All Time';
      case ExportDateRange.today:
        return 'Today';
      case ExportDateRange.thisWeek:
        return 'This Week';
      case ExportDateRange.thisMonth:
        return 'This Month';
      case ExportDateRange.lastMonth:
        return 'Last Month';
      case ExportDateRange.custom:
        return 'Custom Range';
    }
  }

  DateTimeRange? getRange([DateTimeRange? customRange]) {
    final now = DateTime.now();
    switch (this) {
      case ExportDateRange.allTime:
        return null;
      case ExportDateRange.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case ExportDateRange.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(monday.year, monday.month, monday.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case ExportDateRange.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case ExportDateRange.lastMonth:
        final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDayOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
        return DateTimeRange(
          start: firstDayOfLastMonth,
          end: lastDayOfLastMonth,
        );
      case ExportDateRange.custom:
        return customRange;
    }
  }
}

class ExportResult {
  final bool success;
  final int count;
  final String fileName;
  final String? errorMessage;

  const ExportResult({
    required this.success,
    required this.count,
    required this.fileName,
    this.errorMessage,
  });
}

class ReportKpi {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;

  const ReportKpi({
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.color,
  });
}

class ReportPreviewData {
  final String reportKey;
  final String title;
  final String subtitle;
  final String badgeText;
  final List<ReportKpi> kpis;
  final List<String> headers;
  final List<List<String>> rows;
  final int totalCount;
  final List<Map<String, dynamic>>? rowMetadata;

  const ReportPreviewData({
    required this.reportKey,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.kpis,
    required this.headers,
    required this.rows,
    required this.totalCount,
    this.rowMetadata,
  });
}

class DataExportService {
  final FirebaseFirestore _firestore;

  DataExportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) {
      try {
        return DateTime.parse(val);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatDate(dynamic val, {bool includeTime = true}) {
    final dt = _parseDate(val);
    if (dt == null) return '';
    final fmt = includeTime ? DateFormat('yyyy-MM-dd HH:mm') : DateFormat('yyyy-MM-dd');
    return fmt.format(dt);
  }

  String _escapeCsv(dynamic val) {
    if (val == null) return '';
    var str = val.toString().replaceAll('\r', ' ').replaceAll('\n', ' ');
    // Neutralize formula injection risk in spreadsheet tools
    if (str.startsWith('=') || str.startsWith('+') || str.startsWith('-') || str.startsWith('@')) {
      str = "'$str";
    }
    if (str.contains(',') || str.contains('"')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  String _generateFileName(String libraryName, String reportType) {
    final libPrefix = libraryName.trim().isNotEmpty
        ? libraryName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')
        : 'cozy_corner';
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return '${libPrefix}_${reportType}_$dateStr.csv';
  }

  bool _isWithinRange(DateTime? date, DateTimeRange? range) {
    if (range == null) return true;
    if (date == null) return false;
    return (date.isAfter(range.start) || date.isAtSameMomentAs(range.start)) &&
        (date.isBefore(range.end) || date.isAtSameMomentAs(range.end));
  }

  /// Fetches all seats across both section subcollections (libraries/{libId}/sections/{secId}/seats)
  /// and direct seats (libraries/{libId}/seats), ensuring 100% comprehensive coverage.
  Future<List<Map<String, dynamic>>> _fetchAllSeats(String libraryId) async {
    final List<Map<String, dynamic>> allSeats = [];
    final Set<String> seenIds = {};

    // 1. Fetch from sections subcollection: libraries/{libraryId}/sections/{sectionId}/seats
    try {
      final sectionsSnap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('sections')
          .get();

      for (final secDoc in sectionsSnap.docs) {
        final secSeats = await _firestore
            .collection('libraries')
            .doc(libraryId)
            .collection('sections')
            .doc(secDoc.id)
            .collection('seats')
            .get();

        for (final seatDoc in secSeats.docs) {
          if (!seenIds.contains(seatDoc.id)) {
            seenIds.add(seatDoc.id);
            final data = seatDoc.data();
            allSeats.add({
              'id': seatDoc.id,
              ...data,
              'sectionId': data['sectionId'] ?? secDoc.id,
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching section seats: $e');
    }

    // 2. Fetch from direct library seats (fallback/legacy): libraries/{libraryId}/seats
    try {
      final directSeats = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('seats')
          .get();

      for (final seatDoc in directSeats.docs) {
        if (!seenIds.contains(seatDoc.id)) {
          seenIds.add(seatDoc.id);
          allSeats.add({
            'id': seatDoc.id,
            ...seatDoc.data(),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching direct seats: $e');
    }

    // Natural sequential sort: 1, 2, ... 10, 11, 12, A1, A2, B1...
    allSeats.sort(SeatHelper.compareSeatMaps);

    return allSeats;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. STUDENTS DIRECTORY EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportStudents({
    required String libraryId,
    required String libraryName,
    String statusFilter = 'all',
    DateTimeRange? dateRange,
  }) async {
    try {
      // 1. Auxiliary maps for seats, sections, and plans
      final allSeats = await _fetchAllSeats(libraryId);
      final seatLabels = {for (var d in allSeats) (d['id'] as String): (d['label'] as String? ?? d['id'] as String)};

      final sectionsSnap = await _firestore.collection('libraries').doc(libraryId).collection('sections').get();
      final sectionNames = {for (var d in sectionsSnap.docs) d.id: d.data()['name'] as String? ?? d.id};

      final plansSnap = await _firestore.collection('libraries').doc(libraryId).collection('plans').get();
      final planNames = {for (var d in plansSnap.docs) d.id: d.data()['name'] as String? ?? d.id};

      // 2. Fetch students
      final snap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();

      final filteredDocs = snap.docs.where((doc) {
        final d = doc.data();
        if (statusFilter != 'all') {
          final status = (d['membershipStatus'] as String?)?.toLowerCase() ?? '';
          if (status != statusFilter.toLowerCase()) return false;
        }
        if (dateRange != null) {
          final created = _parseDate(d['createdAt']);
          if (!_isWithinRange(created, dateRange)) return false;
        }
        return true;
      }).toList();

      // Fetch custom fields configuration from form_config if present
      List<Map<String, dynamic>> customFieldConfigs = [];
      try {
        final formDoc = await _firestore
            .collection('libraries')
            .doc(libraryId)
            .collection('settings')
            .doc('form_config')
            .get();
        if (formDoc.exists && formDoc.data()?['fields'] != null) {
          final rawFields = formDoc.data()!['fields'] as List<dynamic>;
          for (final f in rawFields) {
            if (f is Map<String, dynamic> && f['isCustom'] == true && f['visible'] != false) {
              customFieldConfigs.add(f);
            }
          }
        }
      } catch (_) {}

      // Fallback: If no builder fields found, scan student docs for any customKeys
      if (customFieldConfigs.isEmpty) {
        final dynamicKeys = <String>{};
        for (final doc in filteredDocs) {
          final cf = doc.data()['customFields'] as Map<String, dynamic>?;
          if (cf != null) dynamicKeys.addAll(cf.keys);
        }
        customFieldConfigs = dynamicKeys.map((k) => {'key': k, 'label': k}).toList();
      }

      final buf = StringBuffer();
      final headers = [
        'Membership ID',
        'Student Name',
        'Phone Number',
        'Email Address',
        'Gender',
        'Membership Status',
        'Assigned Seat',
        'Section / Shift',
        'Current Plan',
        'Plan Start Date',
        'Plan End Date',
        'Grace End Date',
        'Pending Due (₹)',
        'Father / Guardian Name',
        'Emergency Contact',
        'Blood Group',
        'Date of Birth',
        'Gov ID Type',
        'Gov ID Number',
        'College / Institution',
        'Course',
        'Academic Year',
        'Address',
        'Pincode',
        'Joined Date',
        'Notes / Remarks',
        ...customFieldConfigs.map((f) => (f['label'] as String?) ?? (f['key'] as String)),
      ];
      buf.writeln(headers.map(_escapeCsv).join(','));

      for (final doc in filteredDocs) {
        final d = doc.data();
        final customMap = (d['customFields'] as Map<String, dynamic>?) ?? {};
        final row = [
          d['membershipNumber'] ?? '',
          d['name'] ?? '',
          d['phone'] ?? '',
          d['email'] ?? '',
          d['gender'] ?? '',
          d['membershipStatus'] ?? '',
          seatLabels[d['seatId']] ?? d['seatId'] ?? 'Unassigned',
          sectionNames[d['sectionId']] ?? d['sectionId'] ?? 'General',
          planNames[d['planId']] ?? d['planId'] ?? 'None',
          _formatDate(d['planStartDate'], includeTime: false),
          _formatDate(d['planEndDate'], includeTime: false),
          _formatDate(d['graceEndDate'], includeTime: false),
          (d['pendingDueBalance'] as num?)?.toDouble() ?? 0.0,
          d['fatherName'] ?? '',
          d['emergencyContact'] ?? '',
          d['bloodGroup'] ?? '',
          _formatDate(d['dob'], includeTime: false),
          d['govIdType'] ?? '',
          d['govIdNumber'] ?? '',
          d['college'] ?? '',
          d['course'] ?? '',
          d['year'] ?? '',
          d['address'] ?? '',
          d['pincode'] ?? '',
          _formatDate(d['createdAt']),
          d['notes'] ?? '',
          ...customFieldConfigs.map((f) => customMap[f['key']] ?? ''),
        ];
        buf.writeln(row.map(_escapeCsv).join(','));
      }

      final fileName = _generateFileName(libraryName, 'students');
      final bytes = utf8.encode(buf.toString());

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      AuditLogger().log(
        action: AuditAction.exported,
        entityType: AuditEntity.student,
        libraryId: libraryId,
        details: {'type': 'students_csv', 'count': filteredDocs.length, 'fileName': fileName},
      ).ignore();

      return ExportResult(success: true, count: filteredDocs.length, fileName: fileName);
    } catch (e) {
      return ExportResult(success: false, count: 0, fileName: '', errorMessage: e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. PAYMENTS & COLLECTIONS LEDGER EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportPayments({
    required String libraryId,
    required String libraryName,
    DateTimeRange? dateRange,
    String? methodFilter,
  }) async {
    try {
      // 1. Auxiliary maps for student and plan info
      final studentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();
      final studentMap = {
        for (var d in studentsSnap.docs)
          d.id: {
            'name': d.data()['name'] as String? ?? 'Unknown',
            'phone': d.data()['phone'] as String? ?? '',
            'memNo': d.data()['membershipNumber'] as String? ?? '',
          }
      };

      // 2. Fetch payments
      final paymentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('payments').get();

      final filteredDocs = paymentsSnap.docs.where((doc) {
        final d = doc.data();
        final pDate = _parseDate(d['date'] ?? d['createdAt']);
        if (!_isWithinRange(pDate, dateRange)) return false;

        if (methodFilter != null && methodFilter != 'all') {
          final m = (d['paymentMethod'] ?? d['method'] as String?)?.toLowerCase() ?? '';
          if (m != methodFilter.toLowerCase()) return false;
        }
        return true;
      }).toList();

      // Sort by date descending
      filteredDocs.sort((a, b) {
        final da = _parseDate(a.data()['date'] ?? a.data()['createdAt']) ?? DateTime(1970);
        final db = _parseDate(b.data()['date'] ?? b.data()['createdAt']) ?? DateTime(1970);
        return db.compareTo(da);
      });

      final buf = StringBuffer();
      buf.writeln([
        'Payment ID / Ref',
        'Student Name',
        'Membership Number',
        'Phone Number',
        'Amount Paid (₹)',
        'Payment Method',
        'Method Details',
        'Payment Status',
        'Payment Date',
        'Total Plan Fee (₹)',
        'Remaining Due (₹)',
        'Installment #',
        'Reference / UTR',
        'Receipt ID',
        'Notes / Remarks',
      ].map(_escapeCsv).join(','));

      double totalAmount = 0.0;

      for (final doc in filteredDocs) {
        final d = doc.data();
        final sId = d['studentId'] as String? ?? '';
        final sInfo = studentMap[sId] ?? {'name': 'Unknown Student', 'phone': '', 'memNo': ''};
        final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
        totalAmount += amt;

        buf.writeln([
          d['id'] ?? doc.id,
          sInfo['name'],
          sInfo['memNo'],
          sInfo['phone'],
          amt,
          d['paymentMethod'] ?? d['method'] ?? 'Cash',
          d['methodDetails'] ?? '',
          d['status'] ?? 'paid',
          _formatDate(d['date'] ?? d['createdAt']),
          (d['totalPlanFee'] as num?)?.toDouble() ?? '',
          (d['remainingDue'] as num?)?.toDouble() ?? '',
          d['installmentNumber'] ?? '',
          d['referenceNumber'] ?? '',
          d['receiptId'] ?? '',
          d['notes'] ?? '',
        ].map(_escapeCsv).join(','));
      }

      // Summary row
      buf.writeln([
        'TOTAL SUMMARY',
        'Total Payments: ${filteredDocs.length}',
        '',
        '',
        totalAmount,
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
      ].map(_escapeCsv).join(','));

      final fileName = _generateFileName(libraryName, 'payments_ledger');
      final bytes = utf8.encode(buf.toString());

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      AuditLogger().log(
        action: AuditAction.exported,
        entityType: AuditEntity.payment,
        libraryId: libraryId,
        details: {'type': 'payments_csv', 'count': filteredDocs.length, 'totalAmount': totalAmount, 'fileName': fileName},
      ).ignore();

      return ExportResult(success: true, count: filteredDocs.length, fileName: fileName);
    } catch (e) {
      return ExportResult(success: false, count: 0, fileName: '', errorMessage: e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. FEE DEFAULTERS & OVERDUE BALANCES EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportFeeDefaulters({
    required String libraryId,
    required String libraryName,
  }) async {
    try {
      final allSeats = await _fetchAllSeats(libraryId);
      final seatLabels = {for (var d in allSeats) (d['id'] as String): (d['label'] as String? ?? d['id'] as String)};

      final sectionsSnap = await _firestore.collection('libraries').doc(libraryId).collection('sections').get();
      final sectionNames = {for (var d in sectionsSnap.docs) d.id: d.data()['name'] as String? ?? d.id};

      final plansSnap = await _firestore.collection('libraries').doc(libraryId).collection('plans').get();
      final planNames = {for (var d in plansSnap.docs) d.id: d.data()['name'] as String? ?? d.id};

      final studentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();
      final now = DateTime.now();

      final defaulters = studentsSnap.docs.where((doc) {
        final d = doc.data();
        final dueBalance = (d['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;
        final status = (d['membershipStatus'] as String?)?.toLowerCase() ?? '';
        final endDate = _parseDate(d['planEndDate']);

        final isOverdueByBalance = dueBalance > 0;
        final isOverdueByStatus = status == 'expired' || status == 'grace';
        final isOverdueByDate = endDate != null && endDate.isBefore(now);

        return isOverdueByBalance || isOverdueByStatus || isOverdueByDate;
      }).toList();

      final buf = StringBuffer();
      buf.writeln([
        'Membership ID',
        'Student Name',
        'Phone Number',
        'Emergency Phone',
        'Assigned Seat',
        'Section / Shift',
        'Current Plan',
        'Membership Status',
        'Plan Expiry Date',
        'Days Overdue',
        'Pending Due Balance (₹)',
        'Father / Guardian Name',
        'Notes',
      ].map(_escapeCsv).join(','));

      double totalDues = 0.0;

      for (final doc in defaulters) {
        final d = doc.data();
        final due = (d['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;
        totalDues += due;

        final endDate = _parseDate(d['planEndDate']);
        int daysOverdue = 0;
        if (endDate != null && endDate.isBefore(now)) {
          daysOverdue = now.difference(endDate).inDays;
        }

        buf.writeln([
          d['membershipNumber'] ?? '',
          d['name'] ?? '',
          d['phone'] ?? '',
          d['emergencyContact'] ?? '',
          seatLabels[d['seatId']] ?? d['seatId'] ?? 'Unassigned',
          sectionNames[d['sectionId']] ?? d['sectionId'] ?? 'General',
          planNames[d['planId']] ?? d['planId'] ?? 'None',
          d['membershipStatus'] ?? '',
          _formatDate(d['planEndDate'], includeTime: false),
          daysOverdue > 0 ? '$daysOverdue days' : 'Current',
          due,
          d['fatherName'] ?? '',
          d['notes'] ?? '',
        ].map(_escapeCsv).join(','));
      }

      // Summary row
      buf.writeln([
        'TOTAL SUMMARY',
        'Total Overdue Students: ${defaulters.length}',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'Total Pending Dues:',
        totalDues,
        '',
        '',
      ].map(_escapeCsv).join(','));

      final fileName = _generateFileName(libraryName, 'defaulters_and_dues');
      final bytes = utf8.encode(buf.toString());

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      AuditLogger().log(
        action: AuditAction.exported,
        entityType: AuditEntity.student,
        libraryId: libraryId,
        details: {'type': 'fee_defaulters_csv', 'count': defaulters.length, 'totalDues': totalDues, 'fileName': fileName},
      ).ignore();

      return ExportResult(success: true, count: defaulters.length, fileName: fileName);
    } catch (e) {
      return ExportResult(success: false, count: 0, fileName: '', errorMessage: e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. EXPENSES & OUTFLOWS EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportExpenses({
    required String libraryId,
    required String libraryName,
    DateTimeRange? dateRange,
    String? categoryFilter,
  }) async {
    try {
      final snap = await _firestore.collection('libraries').doc(libraryId).collection('expenses').get();

      final filteredDocs = snap.docs.where((doc) {
        final d = doc.data();
        if (d['isDeleted'] == true) return false;

        final eDate = _parseDate(d['date'] ?? d['createdAt']);
        if (!_isWithinRange(eDate, dateRange)) return false;

        if (categoryFilter != null && categoryFilter != 'all') {
          final cat = (d['category'] as String?)?.toLowerCase() ?? '';
          if (cat != categoryFilter.toLowerCase()) return false;
        }
        return true;
      }).toList();

      filteredDocs.sort((a, b) {
        final da = _parseDate(a.data()['date'] ?? a.data()['createdAt']) ?? DateTime(1970);
        final db = _parseDate(b.data()['date'] ?? b.data()['createdAt']) ?? DateTime(1970);
        return db.compareTo(da);
      });

      final buf = StringBuffer();
      buf.writeln([
        'Expense ID',
        'Title / Description',
        'Category',
        'Amount (₹)',
        'Expense Date',
        'Payment Mode',
        'Paid To (Vendor/Person)',
        'Created By',
        'Notes',
      ].map(_escapeCsv).join(','));

      double totalExpenses = 0.0;

      for (final doc in filteredDocs) {
        final d = doc.data();
        final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
        totalExpenses += amt;

        buf.writeln([
          d['id'] ?? doc.id,
          d['title'] ?? '',
          d['category'] ?? '',
          amt,
          _formatDate(d['date'] ?? d['createdAt']),
          d['paymentMethod'] ?? 'Cash',
          d['paidTo'] ?? '',
          d['createdBy'] ?? '',
          d['notes'] ?? '',
        ].map(_escapeCsv).join(','));
      }

      buf.writeln([
        'TOTAL SUMMARY',
        'Total Records: ${filteredDocs.length}',
        '',
        totalExpenses,
        '',
        '',
        '',
        '',
        '',
      ].map(_escapeCsv).join(','));

      final fileName = _generateFileName(libraryName, 'expenses_ledger');
      final bytes = utf8.encode(buf.toString());

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      AuditLogger().log(
        action: AuditAction.exported,
        entityType: AuditEntity.settings,
        libraryId: libraryId,
        details: {'type': 'expenses_csv', 'count': filteredDocs.length, 'totalExpenses': totalExpenses, 'fileName': fileName},
      ).ignore();

      return ExportResult(success: true, count: filteredDocs.length, fileName: fileName);
    } catch (e) {
      return ExportResult(success: false, count: 0, fileName: '', errorMessage: e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. SEAT ALLOCATIONS & OCCUPANCY MATRIX EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportSeatsAndOccupancy({
    required String libraryId,
    required String libraryName,
  }) async {
    try {
      final sectionsSnap = await _firestore.collection('libraries').doc(libraryId).collection('sections').get();
      final sectionMap = {for (var d in sectionsSnap.docs) d.id: d.data()['name'] as String? ?? 'General'};

      final studentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();
      final studentMap = {
        for (var d in studentsSnap.docs)
          d.id: {
            'name': d.data()['name'] as String? ?? '',
            'phone': d.data()['phone'] as String? ?? '',
            'memNo': d.data()['membershipNumber'] as String? ?? '',
            'endDate': _formatDate(d['planEndDate'], includeTime: false),
            'status': d.data()['membershipStatus'] as String? ?? '',
          }
      };

      final allSeats = await _fetchAllSeats(libraryId);

      final buf = StringBuffer();
      buf.writeln([
        'Seat Label',
        'Section / Shift Name',
        'Row',
        'Column',
        'Seat Status',
        'Gender Restriction',
        'Occupying Student Name',
        'Student Phone',
        'Membership ID',
        'Plan Expiry Date',
        'Student Status',
      ].map(_escapeCsv).join(','));

      int occupied = 0;
      int available = 0;

      for (final d in allSeats) {
        final sId = d['studentId'] as String?;
        final sInfo = (sId != null && sId.isNotEmpty) ? studentMap[sId] : null;
        final status = (d['status'] as String?)?.toLowerCase() ?? 'available';

        if (status == 'occupied' || sInfo != null) {
          occupied++;
        } else {
          available++;
        }

        final secId = d['sectionId'] as String? ?? '';

        buf.writeln([
          d['label'] ?? d['id'] ?? '',
          sectionMap[secId] ?? (secId.isNotEmpty ? secId : 'General'),
          d['row'] ?? '',
          d['col'] ?? '',
          d['status'] ?? 'available',
          d['genderRestriction'] ?? 'any',
          sInfo?['name'] ?? '',
          sInfo?['phone'] ?? '',
          sInfo?['memNo'] ?? '',
          sInfo?['endDate'] ?? '',
          sInfo?['status'] ?? '',
        ].map(_escapeCsv).join(','));
      }

      final rate = allSeats.isNotEmpty ? ((occupied / allSeats.length) * 100).toStringAsFixed(1) : '0';
      buf.writeln([
        'SUMMARY',
        'Total Seats: ${allSeats.length}',
        'Occupied: $occupied',
        'Available: $available',
        'Occupancy Rate: $rate%',
        '',
        '',
        '',
        '',
        '',
        '',
      ].map(_escapeCsv).join(','));

      final fileName = _generateFileName(libraryName, 'seat_occupancy');
      final bytes = utf8.encode(buf.toString());

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      AuditLogger().log(
        action: AuditAction.exported,
        entityType: AuditEntity.seat,
        libraryId: libraryId,
        details: {'type': 'seats_csv', 'count': allSeats.length, 'occupied': occupied, 'fileName': fileName},
      ).ignore();

      return ExportResult(success: true, count: allSeats.length, fileName: fileName);
    } catch (e) {
      return ExportResult(success: false, count: 0, fileName: '', errorMessage: e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 6. WAITING LIST QUEUE EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportWaitingList({
    required String libraryId,
    required String libraryName,
  }) async {
    try {
      final sectionsSnap = await _firestore.collection('libraries').doc(libraryId).collection('sections').get();
      final sectionMap = {for (var d in sectionsSnap.docs) d.id: d.data()['name'] as String? ?? 'Any'};

      final snap = await _firestore.collection('libraries').doc(libraryId).collection('waiting_list').get();
      final docs = snap.docs;

      docs.sort((a, b) {
        final posA = (a.data()['position'] as num?)?.toInt() ?? 0;
        final posB = (b.data()['position'] as num?)?.toInt() ?? 0;
        return posA.compareTo(posB);
      });

      final buf = StringBuffer();
      buf.writeln([
        'Queue Position',
        'Student Name',
        'Phone Number',
        'Preferred Section / Shift',
        'Gender Preference',
        'Registration Date',
        'Notified Date',
        'Suggested Seat',
        'Notes',
      ].map(_escapeCsv).join(','));

      for (final doc in docs) {
        final d = doc.data();
        buf.writeln([
          d['position'] ?? '',
          d['studentName'] ?? '',
          d['studentPhone'] ?? '',
          sectionMap[d['preferredSectionId']] ?? d['preferredSectionId'] ?? 'Any',
          d['genderPreference'] ?? 'none',
          _formatDate(d['createdAt']),
          _formatDate(d['notifiedAt']),
          d['suggestedSeatLabel'] ?? d['suggestedSeatId'] ?? '',
          d['notes'] ?? '',
        ].map(_escapeCsv).join(','));
      }

      final fileName = _generateFileName(libraryName, 'waiting_list');
      final bytes = utf8.encode(buf.toString());

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      AuditLogger().log(
        action: AuditAction.exported,
        entityType: AuditEntity.settings,
        libraryId: libraryId,
        details: {'type': 'waiting_list_csv', 'count': docs.length, 'fileName': fileName},
      ).ignore();

      return ExportResult(success: true, count: docs.length, fileName: fileName);
    } catch (e) {
      return ExportResult(success: false, count: 0, fileName: '', errorMessage: e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 7. FINANCIAL P&L SUMMARY EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportFinancialSummary({
    required String libraryId,
    required String libraryName,
    DateTimeRange? dateRange,
  }) async {
    try {
      // 1. Collections / Revenue
      final paymentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('payments').get();
      final filteredPayments = paymentsSnap.docs.where((doc) {
        final pDate = _parseDate(doc.data()['date'] ?? doc.data()['createdAt']);
        return _isWithinRange(pDate, dateRange);
      }).toList();

      double totalRevenue = 0.0;
      final Map<String, double> revenueByMethod = {};
      for (final doc in filteredPayments) {
        final d = doc.data();
        final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
        final method = (d['paymentMethod'] ?? d['method'] as String?) ?? 'Cash';
        totalRevenue += amt;
        revenueByMethod[method] = (revenueByMethod[method] ?? 0) + amt;
      }

      // 2. Expenses
      final expensesSnap = await _firestore.collection('libraries').doc(libraryId).collection('expenses').get();
      final filteredExpenses = expensesSnap.docs.where((doc) {
        final d = doc.data();
        if (d['isDeleted'] == true) return false;
        final eDate = _parseDate(d['date'] ?? d['createdAt']);
        return _isWithinRange(eDate, dateRange);
      }).toList();

      double totalExpenses = 0.0;
      final Map<String, double> expensesByCategory = {};
      for (final doc in filteredExpenses) {
        final d = doc.data();
        final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
        final cat = (d['category'] as String?) ?? 'other';
        totalExpenses += amt;
        expensesByCategory[cat] = (expensesByCategory[cat] ?? 0) + amt;
      }

      // 3. Students & Outstanding Dues
      final studentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();
      int activeStudents = 0;
      double totalDues = 0.0;
      for (final doc in studentsSnap.docs) {
        final d = doc.data();
        final status = (d['membershipStatus'] as String?)?.toLowerCase() ?? '';
        if (status == 'active') activeStudents++;
        totalDues += (d['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;
      }

      final netProfit = totalRevenue - totalExpenses;
      final margin = totalRevenue > 0 ? ((netProfit / totalRevenue) * 100).toStringAsFixed(1) : '0';

      final dateLabel = dateRange != null
          ? '${DateFormat('dd MMM yyyy').format(dateRange.start)} - ${DateFormat('dd MMM yyyy').format(dateRange.end)}'
          : 'All Time';

      final libDoc = await _firestore.collection('libraries').doc(libraryId).get();
      final libName = (libDoc.data()?['name'] as String?)?.trim().isNotEmpty == true
          ? libDoc.data()!['name'].toString().trim().toUpperCase()
          : 'STUDY CENTRE';

      final buf = StringBuffer();
      buf.writeln(['$libName - FINANCIAL P&L SUMMARY', ''].map(_escapeCsv).join(','));
      buf.writeln(['Reporting Period', dateLabel].map(_escapeCsv).join(','));
      buf.writeln(['Generated On', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())].map(_escapeCsv).join(','));
      buf.writeln(['', ''].map(_escapeCsv).join(','));

      buf.writeln(['KEY METRIC', 'VALUE'].map(_escapeCsv).join(','));
      buf.writeln(['Total Fee Collections (Revenue)', '₹${totalRevenue.toStringAsFixed(2)}'].map(_escapeCsv).join(','));
      buf.writeln(['Total Operating Expenses', '₹${totalExpenses.toStringAsFixed(2)}'].map(_escapeCsv).join(','));
      buf.writeln(['Net Operating Profit / (Loss)', '₹${netProfit.toStringAsFixed(2)}'].map(_escapeCsv).join(','));
      buf.writeln(['Operating Margin', '$margin%'].map(_escapeCsv).join(','));
      buf.writeln(['Active Students Enrolled', activeStudents].map(_escapeCsv).join(','));
      buf.writeln(['Total Outstanding Due Balances', '₹${totalDues.toStringAsFixed(2)}'].map(_escapeCsv).join(','));
      buf.writeln(['', ''].map(_escapeCsv).join(','));

      buf.writeln(['COLLECTIONS BY PAYMENT MODE', 'AMOUNT (₹)'].map(_escapeCsv).join(','));
      revenueByMethod.forEach((method, amt) {
        buf.writeln([method, '₹${amt.toStringAsFixed(2)}'].map(_escapeCsv).join(','));
      });
      buf.writeln(['', ''].map(_escapeCsv).join(','));

      buf.writeln(['EXPENSES BY CATEGORY', 'AMOUNT (₹)'].map(_escapeCsv).join(','));
      expensesByCategory.forEach((cat, amt) {
        buf.writeln([cat.toUpperCase(), '₹${amt.toStringAsFixed(2)}'].map(_escapeCsv).join(','));
      });

      final fileName = _generateFileName(libraryName, 'financial_summary_pnl');
      final bytes = utf8.encode(buf.toString());

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );

      AuditLogger().log(
        action: AuditAction.exported,
        entityType: AuditEntity.settings,
        libraryId: libraryId,
        details: {
          'type': 'pnl_summary_csv',
          'revenue': totalRevenue,
          'expenses': totalExpenses,
          'netProfit': netProfit,
          'fileName': fileName,
        },
      ).ignore();

      return ExportResult(success: true, count: 1, fileName: fileName);
    } catch (e) {
      return ExportResult(success: false, count: 0, fileName: '', errorMessage: e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PREVIEW FETCH METHODS (FOR IN-APP LIVE REPORT VIEWER)
  // ──────────────────────────────────────────────────────────────────────────

  Future<ReportPreviewData> fetchStudentsPreview({
    required String libraryId,
    String statusFilter = 'all',
    DateTimeRange? dateRange,
  }) async {
    final allSeats = await _fetchAllSeats(libraryId);
    final seatLabels = {for (var d in allSeats) (d['id'] as String): (d['label'] as String? ?? d['id'] as String)};

    final sectionsSnap = await _firestore.collection('libraries').doc(libraryId).collection('sections').get();
    final sectionNames = {for (var d in sectionsSnap.docs) d.id: d.data()['name'] as String? ?? d.id};

    final plansSnap = await _firestore.collection('libraries').doc(libraryId).collection('plans').get();
    final planNames = {for (var d in plansSnap.docs) d.id: d.data()['name'] as String? ?? d.id};

    final snap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();

    final filteredDocs = snap.docs.where((doc) {
      final d = doc.data();
      if (statusFilter != 'all') {
        final status = (d['membershipStatus'] as String?)?.toLowerCase() ?? '';
        if (status != statusFilter.toLowerCase()) return false;
      }
      if (dateRange != null) {
        final created = _parseDate(d['createdAt']);
        if (!_isWithinRange(created, dateRange)) return false;
      }
      return true;
    }).toList();

    filteredDocs.sort((a, b) {
      final da = _parseDate(a.data()['createdAt']) ?? DateTime(1970);
      final db = _parseDate(b.data()['createdAt']) ?? DateTime(1970);
      return db.compareTo(da);
    });

    int activeCount = 0;
    int expiredCount = 0;
    int graceCount = 0;
    double totalDues = 0.0;

    final rows = <List<String>>[];
    final metadata = <Map<String, dynamic>>[];

    for (final doc in filteredDocs) {
      final d = doc.data();
      final status = (d['membershipStatus'] as String?)?.toLowerCase() ?? '';
      if (status == 'active') {
        activeCount++;
      } else if (status == 'expired') {
        expiredCount++;
      } else if (status == 'grace') {
        graceCount++;
      }

      final due = (d['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;
      totalDues += due;

      final phone = (d['phone'] as String?) ?? '';
      final name = (d['name'] as String?) ?? 'Student';

      rows.add([
        d['membershipNumber']?.toString() ?? '—',
        name,
        phone.isNotEmpty ? phone : '—',
        seatLabels[d['seatId']] ?? d['seatId'] ?? 'Unassigned',
        sectionNames[d['sectionId']] ?? d['sectionId'] ?? 'General',
        planNames[d['planId']] ?? d['planId'] ?? 'None',
        _formatDate(d['planEndDate'], includeTime: false),
        (d['membershipStatus'] as String?)?.toUpperCase() ?? 'ACTIVE',
        due > 0 ? '₹${due.toStringAsFixed(0)}' : '₹0',
      ]);

      metadata.add({
        'id': doc.id,
        'name': name,
        'phone': phone,
        'due': due,
      });
    }

    return ReportPreviewData(
      reportKey: 'students',
      title: 'Students Master Directory',
      subtitle: 'Profiles, assigned seats, plans, and membership statuses',
      badgeText: statusFilter.toUpperCase(),
      totalCount: filteredDocs.length,
      kpis: [
        ReportKpi(
          label: 'Total Students',
          value: '${filteredDocs.length}',
          subtitle: 'Enrolled profiles',
          icon: Icons.people_alt_rounded,
          color: Colors.blue,
        ),
        ReportKpi(
          label: 'Active Members',
          value: '$activeCount',
          subtitle: 'Currently learning',
          icon: Icons.check_circle_rounded,
          color: Colors.green,
        ),
        ReportKpi(
          label: 'Grace / Expired',
          value: '$graceCount / $expiredCount',
          subtitle: 'Overdue renewal',
          icon: Icons.schedule_rounded,
          color: Colors.amber,
        ),
        ReportKpi(
          label: 'Unpaid Dues',
          value: '₹${totalDues.toStringAsFixed(0)}',
          subtitle: 'Outstanding balance',
          icon: Icons.money_off_rounded,
          color: Colors.red,
        ),
      ],
      headers: const ['Mem #', 'Student Name', 'Phone', 'Seat', 'Shift', 'Plan', 'Expiry Date', 'Status', 'Pending Due'],
      rows: rows,
      rowMetadata: metadata,
    );
  }

  Future<ReportPreviewData> fetchPaymentsPreview({
    required String libraryId,
    DateTimeRange? dateRange,
    String? methodFilter,
  }) async {
    final studentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();
    final studentMap = {
      for (var d in studentsSnap.docs)
        d.id: {
          'name': d.data()['name'] as String? ?? 'Unknown',
          'phone': d.data()['phone'] as String? ?? '',
          'memNo': d.data()['membershipNumber'] as String? ?? '',
        }
    };

    final paymentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('payments').get();

    final filteredDocs = paymentsSnap.docs.where((doc) {
      final d = doc.data();
      final pDate = _parseDate(d['date'] ?? d['createdAt']);
      if (!_isWithinRange(pDate, dateRange)) return false;

      if (methodFilter != null && methodFilter != 'all') {
        final m = (d['paymentMethod'] ?? d['method'] as String?)?.toLowerCase() ?? '';
        if (m != methodFilter.toLowerCase()) return false;
      }
      return true;
    }).toList();

    filteredDocs.sort((a, b) {
      final da = _parseDate(a.data()['date'] ?? a.data()['createdAt']) ?? DateTime(1970);
      final db = _parseDate(b.data()['date'] ?? b.data()['createdAt']) ?? DateTime(1970);
      return db.compareTo(da);
    });

    double totalAmount = 0.0;
    double totalDue = 0.0;
    int upiCount = 0;
    int cashCount = 0;

    final rows = <List<String>>[];
    final metadata = <Map<String, dynamic>>[];

    for (final doc in filteredDocs) {
      final d = doc.data();
      final sId = d['studentId'] as String? ?? '';
      final sInfo = studentMap[sId] ?? {'name': 'Unknown Student', 'phone': '', 'memNo': ''};
      final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
      final due = (d['remainingDue'] as num?)?.toDouble() ?? 0.0;
      totalAmount += amt;
      totalDue += due;

      final method = (d['paymentMethod'] ?? d['method'] as String?) ?? 'Cash';
      if (method.toLowerCase().contains('upi') || method.toLowerCase().contains('online')) {
        upiCount++;
      } else {
        cashCount++;
      }

      final dateStr = _formatDate(d['date'] ?? d['createdAt']);
      final status = (d['status'] as String?)?.toUpperCase() ?? 'PAID';

      rows.add([
        dateStr,
        sInfo['name'] ?? '',
        sInfo['phone'] ?? '',
        method,
        '₹${amt.toStringAsFixed(0)}',
        due > 0 ? '₹${due.toStringAsFixed(0)}' : '₹0',
        status,
        d['referenceNumber']?.toString() ?? '—',
      ]);

      metadata.add({
        'id': doc.id,
        'name': sInfo['name'],
        'phone': sInfo['phone'],
        'amount': amt,
        'receiptId': d['receiptId'] ?? '',
      });
    }

    return ReportPreviewData(
      reportKey: 'payments',
      title: 'Payments & Collections Ledger',
      subtitle: 'Transaction entries, payment channels, amounts, and remaining balances',
      badgeText: dateRange != null ? 'Filtered' : 'All Time',
      totalCount: filteredDocs.length,
      kpis: [
        ReportKpi(
          label: 'Total Collections',
          value: '₹${totalAmount.toStringAsFixed(0)}',
          subtitle: 'Gross revenue received',
          icon: Icons.currency_rupee_rounded,
          color: Colors.green,
        ),
        ReportKpi(
          label: 'Total Receipts',
          value: '${filteredDocs.length}',
          subtitle: 'Recorded transactions',
          icon: Icons.receipt_long_rounded,
          color: Colors.blue,
        ),
        ReportKpi(
          label: 'Payment Modes',
          value: '$upiCount UPI • $cashCount Cash',
          subtitle: 'Channel distribution',
          icon: Icons.payments_rounded,
          color: Colors.teal,
        ),
        ReportKpi(
          label: 'Remaining Dues',
          value: '₹${totalDue.toStringAsFixed(0)}',
          subtitle: 'Pending on these receipts',
          icon: Icons.warning_amber_rounded,
          color: Colors.amber,
        ),
      ],
      headers: const ['Date', 'Student Name', 'Phone', 'Mode', 'Amount Paid', 'Balance Due', 'Status', 'Ref / UTR'],
      rows: rows,
      rowMetadata: metadata,
    );
  }

  Future<ReportPreviewData> fetchFeeDefaultersPreview({
    required String libraryId,
  }) async {
    final allSeats = await _fetchAllSeats(libraryId);
    final seatLabels = {for (var d in allSeats) (d['id'] as String): (d['label'] as String? ?? d['id'] as String)};

    final sectionsSnap = await _firestore.collection('libraries').doc(libraryId).collection('sections').get();
    final sectionNames = {for (var d in sectionsSnap.docs) d.id: d.data()['name'] as String? ?? d.id};

    final plansSnap = await _firestore.collection('libraries').doc(libraryId).collection('plans').get();
    final planNames = {for (var d in plansSnap.docs) d.id: d.data()['name'] as String? ?? d.id};

    final studentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();
    final now = DateTime.now();

    final defaulters = studentsSnap.docs.where((doc) {
      final d = doc.data();
      final dueBalance = (d['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;
      final status = (d['membershipStatus'] as String?)?.toLowerCase() ?? '';
      final endDate = _parseDate(d['planEndDate']);

      final isOverdueByBalance = dueBalance > 0;
      final isOverdueByStatus = status == 'expired' || status == 'grace';
      final isOverdueByDate = endDate != null && endDate.isBefore(now);

      return isOverdueByBalance || isOverdueByStatus || isOverdueByDate;
    }).toList();

    double totalDues = 0.0;
    int criticalCount = 0;
    int graceCount = 0;

    final rows = <List<String>>[];
    final metadata = <Map<String, dynamic>>[];

    for (final doc in defaulters) {
      final d = doc.data();
      final due = (d['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;
      totalDues += due;

      final endDate = _parseDate(d['planEndDate']);
      int daysOverdue = 0;
      if (endDate != null && endDate.isBefore(now)) {
        daysOverdue = now.difference(endDate).inDays;
      }

      if (daysOverdue > 7) criticalCount++;
      if ((d['membershipStatus'] as String?)?.toLowerCase() == 'grace') graceCount++;

      final name = (d['name'] as String?) ?? 'Student';
      final phone = (d['phone'] as String?) ?? '';
      final planName = planNames[d['planId']] ?? d['planId'] ?? 'General Plan';

      rows.add([
        name,
        phone.isNotEmpty ? phone : '—',
        seatLabels[d['seatId']] ?? d['seatId'] ?? 'Unassigned',
        sectionNames[d['sectionId']] ?? d['sectionId'] ?? 'General',
        planName,
        _formatDate(d['planEndDate'], includeTime: false),
        daysOverdue > 0 ? '$daysOverdue Days' : 'Due Today',
        '₹${due.toStringAsFixed(0)}',
        (d['membershipStatus'] as String?)?.toUpperCase() ?? 'EXPIRED',
      ]);

      metadata.add({
        'id': doc.id,
        'name': name,
        'phone': phone,
        'due': due,
        'daysOverdue': daysOverdue,
        'planName': planName,
        'expiryDate': _formatDate(d['planEndDate'], includeTime: false),
      });
    }

    // Sort by due amount descending
    rows.sort((a, b) {
      final dueA = double.tryParse(a[6].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
      final dueB = double.tryParse(b[6].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
      return dueB.compareTo(dueA);
    });

    return ReportPreviewData(
      reportKey: 'defaulters',
      title: 'Fee Defaulters & Overdue Balances',
      subtitle: 'Students with unpaid dues, expired memberships, or active grace periods',
      badgeText: 'Action Required',
      totalCount: defaulters.length,
      kpis: [
        ReportKpi(
          label: 'Total Outstanding',
          value: '₹${totalDues.toStringAsFixed(0)}',
          subtitle: 'Pending fee collection',
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
        ),
        ReportKpi(
          label: 'Defaulters Count',
          value: '${defaulters.length} Students',
          subtitle: 'Need payment follow-up',
          icon: Icons.person_off_rounded,
          color: Colors.amber,
        ),
        ReportKpi(
          label: 'Critical (>7 Days)',
          value: '$criticalCount Students',
          subtitle: 'Long overdue accounts',
          icon: Icons.error_outline_rounded,
          color: Colors.deepOrange,
        ),
        ReportKpi(
          label: 'In Grace Period',
          value: '$graceCount Students',
          subtitle: 'Expiring shortly',
          icon: Icons.hourglass_bottom_rounded,
          color: Colors.teal,
        ),
      ],
      headers: const ['Student Name', 'Phone', 'Seat', 'Shift', 'Plan', 'Expiry Date', 'Overdue', 'Pending Due', 'Status'],
      rows: rows,
      rowMetadata: metadata,
    );
  }

  Future<ReportPreviewData> fetchExpensesPreview({
    required String libraryId,
    DateTimeRange? dateRange,
    String? categoryFilter,
  }) async {
    final snap = await _firestore.collection('libraries').doc(libraryId).collection('expenses').get();

    final filteredDocs = snap.docs.where((doc) {
      final d = doc.data();
      if (d['isDeleted'] == true) return false;

      final eDate = _parseDate(d['date'] ?? d['createdAt']);
      if (!_isWithinRange(eDate, dateRange)) return false;

      if (categoryFilter != null && categoryFilter != 'all') {
        final cat = (d['category'] as String?)?.toLowerCase() ?? '';
        if (cat != categoryFilter.toLowerCase()) return false;
      }
      return true;
    }).toList();

    filteredDocs.sort((a, b) {
      final da = _parseDate(a.data()['date'] ?? a.data()['createdAt']) ?? DateTime(1970);
      final db = _parseDate(b.data()['date'] ?? b.data()['createdAt']) ?? DateTime(1970);
      return db.compareTo(da);
    });

    double totalExpenses = 0.0;
    int cashCount = 0;
    int onlineCount = 0;
    final Map<String, double> catTotals = {};

    final rows = <List<String>>[];

    for (final doc in filteredDocs) {
      final d = doc.data();
      final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
      totalExpenses += amt;

      final cat = (d['category'] as String?) ?? 'other';
      catTotals[cat] = (catTotals[cat] ?? 0.0) + amt;

      final mode = (d['paymentMethod'] as String?) ?? 'Cash';
      if (mode.toLowerCase().contains('cash')) {
        cashCount++;
      } else {
        onlineCount++;
      }

      rows.add([
        _formatDate(d['date'] ?? d['createdAt']),
        d['title']?.toString() ?? '',
        cat.toUpperCase(),
        d['paidTo']?.toString() ?? '—',
        mode,
        '₹${amt.toStringAsFixed(0)}',
      ]);
    }

    String topCategory = 'None';
    double topCategoryAmount = 0.0;
    catTotals.forEach((cat, amt) {
      if (amt > topCategoryAmount) {
        topCategoryAmount = amt;
        topCategory = cat;
      }
    });

    return ReportPreviewData(
      reportKey: 'expenses',
      title: 'Expenses & Outflows Ledger',
      subtitle: 'Facility maintenance, utilities, salaries, and operational costs',
      badgeText: dateRange != null ? 'Filtered' : 'All Time',
      totalCount: filteredDocs.length,
      kpis: [
        ReportKpi(
          label: 'Total Outflows',
          value: '₹${totalExpenses.toStringAsFixed(0)}',
          subtitle: 'Operating expenditure',
          icon: Icons.trending_down_rounded,
          color: Colors.deepOrange,
        ),
        ReportKpi(
          label: 'Total Entries',
          value: '${filteredDocs.length}',
          subtitle: 'Logged vouchers',
          icon: Icons.format_list_bulleted_rounded,
          color: Colors.purple,
        ),
        ReportKpi(
          label: 'Top Expense',
          value: topCategory.toUpperCase(),
          subtitle: '₹${topCategoryAmount.toStringAsFixed(0)} spent',
          icon: Icons.pie_chart_outline_rounded,
          color: Colors.indigo,
        ),
        ReportKpi(
          label: 'Disbursement Mode',
          value: '$cashCount Cash • $onlineCount Online',
          subtitle: 'Payment method split',
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.teal,
        ),
      ],
      headers: const ['Date', 'Title / Description', 'Category', 'Paid To (Vendor)', 'Mode', 'Amount (₹)'],
      rows: rows,
    );
  }

  Future<ReportPreviewData> fetchSeatsAndOccupancyPreview({
    required String libraryId,
  }) async {
    final sectionsSnap = await _firestore.collection('libraries').doc(libraryId).collection('sections').get();
    final sectionMap = {for (var d in sectionsSnap.docs) d.id: d.data()['name'] as String? ?? 'General'};

    final studentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();
    final studentMap = {
      for (var d in studentsSnap.docs)
        d.id: {
          'name': d.data()['name'] as String? ?? '',
          'phone': d.data()['phone'] as String? ?? '',
          'memNo': d.data()['membershipNumber'] as String? ?? '',
          'endDate': _formatDate(d['planEndDate'], includeTime: false),
          'status': d.data()['membershipStatus'] as String? ?? '',
        }
    };

    final allSeats = await _fetchAllSeats(libraryId);

    int occupied = 0;
    int available = 0;

    final rows = <List<String>>[];

    for (final d in allSeats) {
      final sId = d['studentId'] as String?;
      final sInfo = (sId != null && sId.isNotEmpty) ? studentMap[sId] : null;
      final status = (d['status'] as String?)?.toLowerCase() ?? 'available';

      final isOccupied = status == 'occupied' || sInfo != null;
      if (isOccupied) {
        occupied++;
      } else {
        available++;
      }

      final label = (d['label'] ?? d['id'] ?? '').toString();
      final secId = d['sectionId'] as String? ?? '';

      rows.add([
        label,
        sectionMap[secId] ?? (secId.isNotEmpty ? secId : 'General'),
        isOccupied ? 'OCCUPIED' : 'AVAILABLE',
        sInfo?['name'] ?? '—',
        sInfo?['phone'] ?? '—',
        sInfo?['endDate'] ?? '—',
      ]);
    }

    final rate = allSeats.isNotEmpty ? ((occupied / allSeats.length) * 100).toStringAsFixed(1) : '0';

    return ReportPreviewData(
      reportKey: 'seats',
      title: 'Seat Allocation & Occupancy Matrix',
      subtitle: 'Real-time seat inventory, active occupants, and vacancy distribution',
      badgeText: 'Live Inventory',
      totalCount: allSeats.length,
      kpis: [
        ReportKpi(
          label: 'Total Capacity',
          value: '${allSeats.length} Seats',
          subtitle: 'Installed study desks',
          icon: Icons.chair_rounded,
          color: Colors.blue,
        ),
        ReportKpi(
          label: 'Occupied Desks',
          value: '$occupied Seats',
          subtitle: 'Active occupants',
          icon: Icons.airline_seat_recline_normal_rounded,
          color: Colors.teal,
        ),
        ReportKpi(
          label: 'Available / Vacant',
          value: '$available Seats',
          subtitle: 'Ready to allocate',
          icon: Icons.event_seat_rounded,
          color: Colors.green,
        ),
        ReportKpi(
          label: 'Occupancy Rate',
          value: '$rate%',
          subtitle: 'Space utilization',
          icon: Icons.pie_chart_rounded,
          color: Colors.indigo,
        ),
      ],
      headers: const ['Seat Label', 'Section / Hall', 'Status', 'Occupant Name', 'Phone', 'Plan Expiry'],
      rows: rows,
    );
  }

  Future<ReportPreviewData> fetchWaitingListPreview({
    required String libraryId,
  }) async {
    final sectionsSnap = await _firestore.collection('libraries').doc(libraryId).collection('sections').get();
    final sectionMap = {for (var d in sectionsSnap.docs) d.id: d.data()['name'] as String? ?? 'Any'};

    final snap = await _firestore.collection('libraries').doc(libraryId).collection('waiting_list').get();
    final docs = snap.docs;

    docs.sort((a, b) {
      final posA = (a.data()['position'] as num?)?.toInt() ?? 0;
      final posB = (b.data()['position'] as num?)?.toInt() ?? 0;
      return posA.compareTo(posB);
    });

    int suggestedCount = 0;
    final Map<String, int> sectionCount = {};
    final rows = <List<String>>[];
    final metadata = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final d = doc.data();
      final sec = sectionMap[d['preferredSectionId']] ?? d['preferredSectionId'] ?? 'Any';
      sectionCount[sec] = (sectionCount[sec] ?? 0) + 1;

      final suggestedSeat = d['suggestedSeatLabel'] ?? d['suggestedSeatId'] ?? '';
      if (suggestedSeat.toString().isNotEmpty) suggestedCount++;

      final name = d['studentName']?.toString() ?? 'Applicant';
      final phone = d['studentPhone']?.toString() ?? '';

      rows.add([
        '#${d['position'] ?? ''}',
        name,
        phone.isNotEmpty ? phone : '—',
        sec,
        (d['genderPreference'] ?? 'Any').toString().toUpperCase(),
        _formatDate(d['createdAt'], includeTime: false),
        suggestedSeat.toString().isNotEmpty ? suggestedSeat.toString() : 'Pending',
      ]);

      metadata.add({
        'id': doc.id,
        'name': name,
        'phone': phone,
      });
    }

    String topSection = 'General';
    int maxSecCount = 0;
    sectionCount.forEach((sec, cnt) {
      if (cnt > maxSecCount) {
        maxSecCount = cnt;
        topSection = sec;
      }
    });

    return ReportPreviewData(
      reportKey: 'waiting_list',
      title: 'Waiting List Queue Register',
      subtitle: 'Candidate priority, preferred study shifts, and provisional seat holds',
      badgeText: 'Waitlist',
      totalCount: docs.length,
      kpis: [
        ReportKpi(
          label: 'Queue Length',
          value: '${docs.length} Students',
          subtitle: 'Awaiting seat vacancy',
          icon: Icons.hourglass_top_rounded,
          color: Colors.indigo,
        ),
        ReportKpi(
          label: 'Seats Suggested',
          value: '$suggestedCount',
          subtitle: 'Ready for confirmation',
          icon: Icons.recommend_rounded,
          color: Colors.teal,
        ),
        ReportKpi(
          label: 'High Demand Shift',
          value: topSection,
          subtitle: 'Most requested section',
          icon: Icons.place_rounded,
          color: Colors.purple,
        ),
      ],
      headers: const ['Queue #', 'Student Name', 'Phone', 'Preferred Section', 'Gender Pref', 'Registered Date', 'Suggested Desk'],
      rows: rows,
      rowMetadata: metadata,
    );
  }

  Future<ReportPreviewData> fetchFinancialSummaryPreview({
    required String libraryId,
    DateTimeRange? dateRange,
  }) async {
    final paymentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('payments').get();
    final filteredPayments = paymentsSnap.docs.where((doc) {
      final pDate = _parseDate(doc.data()['date'] ?? doc.data()['createdAt']);
      return _isWithinRange(pDate, dateRange);
    }).toList();

    double totalRevenue = 0.0;
    final Map<String, double> revenueByMethod = {};
    for (final doc in filteredPayments) {
      final d = doc.data();
      final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
      final method = (d['paymentMethod'] ?? d['method'] as String?) ?? 'Cash';
      totalRevenue += amt;
      revenueByMethod[method] = (revenueByMethod[method] ?? 0) + amt;
    }

    final expensesSnap = await _firestore.collection('libraries').doc(libraryId).collection('expenses').get();
    final filteredExpenses = expensesSnap.docs.where((doc) {
      final d = doc.data();
      if (d['isDeleted'] == true) return false;
      final eDate = _parseDate(d['date'] ?? d['createdAt']);
      return _isWithinRange(eDate, dateRange);
    }).toList();

    double totalExpenses = 0.0;
    final Map<String, double> expensesByCategory = {};
    for (final doc in filteredExpenses) {
      final d = doc.data();
      final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
      final cat = (d['category'] as String?) ?? 'other';
      totalExpenses += amt;
      expensesByCategory[cat] = (expensesByCategory[cat] ?? 0) + amt;
    }

    final studentsSnap = await _firestore.collection('libraries').doc(libraryId).collection('students').get();
    int activeStudents = 0;
    double totalDues = 0.0;
    for (final doc in studentsSnap.docs) {
      final d = doc.data();
      final status = (d['membershipStatus'] as String?)?.toLowerCase() ?? '';
      if (status == 'active') activeStudents++;
      totalDues += (d['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;
    }

    final netProfit = totalRevenue - totalExpenses;
    final margin = totalRevenue > 0 ? ((netProfit / totalRevenue) * 100).toStringAsFixed(1) : '0';

    final rows = <List<String>>[];

    revenueByMethod.forEach((method, amt) {
      final share = totalRevenue > 0 ? ((amt / totalRevenue) * 100).toStringAsFixed(1) : '0';
      rows.add([
        'Fee Collection ($method)',
        'REVENUE',
        '₹${amt.toStringAsFixed(0)}',
        '$share% of gross inflows',
      ]);
    });

    expensesByCategory.forEach((cat, amt) {
      final share = totalExpenses > 0 ? ((amt / totalExpenses) * 100).toStringAsFixed(1) : '0';
      rows.add([
        cat.toUpperCase(),
        'EXPENSE',
        '₹${amt.toStringAsFixed(0)}',
        '$share% of gross outflows',
      ]);
    });

    rows.add([
      'Outstanding Member Dues',
      'RECEIVABLE',
      '₹${totalDues.toStringAsFixed(0)}',
      'From $activeStudents active accounts',
    ]);

    return ReportPreviewData(
      reportKey: 'pnl',
      title: 'Financial P&L Executive Summary',
      subtitle: 'Income statement, operational costs, net margin, and asset receivables',
      badgeText: 'P&L Report',
      totalCount: rows.length,
      kpis: [
        ReportKpi(
          label: 'Fee Revenue',
          value: '₹${totalRevenue.toStringAsFixed(0)}',
          subtitle: 'Gross collections',
          icon: Icons.trending_up_rounded,
          color: Colors.green,
        ),
        ReportKpi(
          label: 'Operating Expenses',
          value: '₹${totalExpenses.toStringAsFixed(0)}',
          subtitle: 'Total library costs',
          icon: Icons.trending_down_rounded,
          color: Colors.deepOrange,
        ),
        ReportKpi(
          label: 'Net Operating Profit',
          value: '₹${netProfit.toStringAsFixed(0)}',
          subtitle: netProfit >= 0 ? 'Net Surplus' : 'Net Deficit',
          icon: Icons.account_balance_rounded,
          color: netProfit >= 0 ? Colors.green : Colors.red,
        ),
        ReportKpi(
          label: 'Operating Margin',
          value: '$margin%',
          subtitle: 'Margin profitability',
          icon: Icons.percent_rounded,
          color: netProfit >= 0 ? Colors.teal : Colors.amber,
        ),
      ],
      headers: const ['Category / Stream', 'Type', 'Amount (₹)', 'Share / Details'],
      rows: rows,
    );
  }
}
