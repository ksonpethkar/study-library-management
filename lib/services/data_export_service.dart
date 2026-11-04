import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/file_download_helper.dart';

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
      final seatsSnap = await _firestore.collection('libraries').doc(libraryId).collection('seats').get();
      final seatLabels = {for (var d in seatsSnap.docs) d.id: d.data()['label'] as String? ?? d.id};

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
      final seatsSnap = await _firestore.collection('libraries').doc(libraryId).collection('seats').get();
      final seatLabels = {for (var d in seatsSnap.docs) d.id: d.data()['label'] as String? ?? d.id};

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

      final seatsSnap = await _firestore.collection('libraries').doc(libraryId).collection('seats').get();
      final docs = seatsSnap.docs;

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

      for (final doc in docs) {
        final d = doc.data();
        final sId = d['studentId'] as String?;
        final sInfo = (sId != null && sId.isNotEmpty) ? studentMap[sId] : null;
        final status = (d['status'] as String?)?.toLowerCase() ?? 'available';

        if (status == 'occupied' || sInfo != null) {
          occupied++;
        } else {
          available++;
        }

        buf.writeln([
          d['label'] ?? '',
          sectionMap[d['sectionId']] ?? d['sectionId'] ?? '',
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

      final rate = docs.isNotEmpty ? ((occupied / docs.length) * 100).toStringAsFixed(1) : '0';
      buf.writeln([
        'SUMMARY',
        'Total Seats: ${docs.length}',
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
        details: {'type': 'seats_csv', 'count': docs.length, 'occupied': occupied, 'fileName': fileName},
      ).ignore();

      return ExportResult(success: true, count: docs.length, fileName: fileName);
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
}
