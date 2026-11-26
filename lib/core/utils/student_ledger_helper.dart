import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/plan_calculator_service.dart';

/// Shared single source of truth for student receipt synthesis, payment ledger
/// deduplication, plan duration resolution, and approval soundbox gating.
class StudentLedgerHelper {
  StudentLedgerHelper._();

  static const Set<String> _unpaidOrVoidedStatuses = {
    'voided',
    'void',
    'cancelled',
    'canceled',
    'pending',
    'desk_payment_pending',
    'payment_pending',
    'rejected',
    'refunded',
    'failed',
  };

  static const Set<String> _confirmedPaidStatuses = {
    'paid',
    'active',
    'completed',
    'settled',
  };

  /// Returns true ONLY when the student has an actively paid membership with
  /// valid start and end cycle dates. Never returns true on `planId != null` alone.
  static bool isPaidAdmissionEligible(StudentModel student) {
    return student.membershipStatus == MembershipStatus.active &&
        student.planStartDate != null &&
        student.planEndDate != null;
  }

  /// Returns true ONLY for genuinely collected/confirmed payment statuses.
  static bool isConfirmedPaidStatus(String? status) {
    final normalized = (status ?? 'paid').trim().toLowerCase();
    if (_unpaidOrVoidedStatuses.contains(normalized)) return false;
    return _confirmedPaidStatuses.contains(normalized);
  }

  /// Returns true only when Soundbox audio announcement should fire on request approval.
  /// Pure approval of registration, seat_change, profile_update, freeze, or ₹0 collected
  /// renewals must NEVER trigger payment announcements.
  static bool shouldAnnounceApprovalPayment({
    required bool isRenewal,
    required bool isDuePayment,
    required double collectedAmount,
  }) {
    if (collectedAmount <= 0) return false;
    return isRenewal || isDuePayment;
  }

  /// Resolves a plan end date without ever hardcoding an arbitrary 90-day quarterly jump.
  static DateTime resolvePlanEndDate({
    required DateTime startDate,
    PlanModel? plan,
  }) => resolveFallbackPlanEndDate(startDate: startDate, plan: plan);

  /// Resolves a plan end date without ever hardcoding an arbitrary 90-day quarterly jump.
  static DateTime resolveFallbackPlanEndDate({
    required DateTime startDate,
    PlanModel? plan,
  }) {
    if (plan != null) {
      return PlanCalculatorService.calculateSmartPlan(
        plan: plan,
        fromDate: startDate,
      ).endDate;
    }
    return startDate.add(const Duration(days: 30));
  }

  /// Synthesizes a fallback enrollment receipt ONLY if the student has a genuine
  /// active paid membership (`isPaidAdmissionEligible(student)`).
  static ReceiptModel? buildSyntheticEnrollmentReceipt({
    required String libraryId,
    required StudentModel student,
    required List<PlanModel> plans,
    String? effectiveUid,
  }) {
    if (!isPaidAdmissionEligible(student)) {
      return null;
    }

    final matchedPlan = plans.where((p) => p.id == student.planId).firstOrNull;
    final planName = matchedPlan?.name ?? student.customPlanName ?? 'Study Pass';
    final planPrice = matchedPlan?.price ?? student.customPlanFee ?? 0.0;
    final startDate = student.planStartDate!;
    final endDate = student.planEndDate!;

    final uniqueSuffix = student.membershipNumber?.isNotEmpty == true
        ? student.membershipNumber!
        : (student.id.length >= 6
            ? student.id.substring(0, 6).toUpperCase()
            : student.id.toUpperCase());

    return ReceiptModel(
      id: 'active_enrollment_${student.id}',
      libraryId: libraryId,
      receiptNumber: 'REC-${startDate.year}-$uniqueSuffix',
      studentId: student.id,
      studentUserId: (effectiveUid != null && effectiveUid.isNotEmpty)
          ? effectiveUid
          : student.userId,
      planId: student.planId ?? 'membership_enrollment',
      amount: planPrice,
      totalFee: planPrice,
      paidAmount: planPrice,
      remainingDue: 0.0,
      paymentMethod: 'Desk / Confirmed',
      validFrom: startDate,
      validTo: endDate,
      status: ReceiptStatus.active,
      customFields: {
        'planName': planName,
        if (student.seatId != null && student.seatId!.isNotEmpty)
          'seatLabel': SeatHelper.formatSeatLabel(seatId: student.seatId),
        'admissionType': 'Official Enrollment Receipt',
      },
      createdAt: startDate,
      updatedAt: startDate,
    );
  }

  /// Builds a unified, deduplicated transaction list for Membership & Payment History screens.
  /// Never fabricates paid receipts/transactions when no payment was recorded for unpaid students.
  static List<Map<String, dynamic>> buildTransactionsLedger({
    required String libraryId,
    required StudentModel student,
    required List<Map<String, dynamic>> receiptDocs,
    required List<Map<String, dynamic>> paymentDocs,
    required List<PlanModel> plans,
    String? effectiveUid,
  }) {
    final List<Map<String, dynamic>> transactions = [];
    final Set<String> seenReceiptIds = {};
    final Set<String> seenPaymentIds = {};
    final Set<String> seenReceiptNumbers = {};
    final Set<String> seenRequestIds = {};

    // 1. Official Receipts
    for (final data in receiptDocs) {
      if (data['deletedAt'] != null) continue;
      final rId = (data['id'] ?? '').toString();
      if (rId.isEmpty) continue;
      seenReceiptIds.add(rId);

      final pId = data['paymentId'] as String?;
      if (pId != null && pId.isNotEmpty) seenPaymentIds.add(pId);
      final rNum = data['receiptNumber'] as String?;
      if (rNum != null && rNum.isNotEmpty) seenReceiptNumbers.add(rNum);
      final reqId = (data['customFields'] as Map?)?['requestId'] as String?;
      if (reqId != null && reqId.isNotEmpty) seenRequestIds.add(reqId);

      final date = _parseDate(data['createdAt'] ?? data['validFrom']);
      final amount = (data['paidAmount'] as num?)?.toDouble() ??
          (data['amount'] as num?)?.toDouble() ??
          0.0;
      final planId = data['planId']?.toString();
      final matchedPlan = plans.where((p) => p.id == planId).firstOrNull;
      ReceiptModel? rModel;
      try {
        rModel = ReceiptModel.fromJson({...data, 'id': rId});
      } catch (_) {}

      transactions.add({
        'id': rId,
        'receiptId': rId,
        'title': data['receiptNumber'] ?? 'Official Receipt',
        'amount': amount,
        'date': date,
        'method': data['paymentMethod'] ?? data['method'] ?? 'Paid',
        'planName': data['planName'] ??
            (data['customFields'] as Map?)?['planName'] ??
            matchedPlan?.name ??
            '',
        'status': (data['status'] ?? 'paid').toString(),
        'isOfficialReceipt': true,
        'receiptModel': ?rModel,
        'planModel': ?matchedPlan,
      });
    }

    // 2. Payments (deduplicated against receipts)
    for (final data in paymentDocs) {
      if (data['deletedAt'] != null) continue;
      final pId = (data['id'] ?? '').toString();
      if (pId.isEmpty || seenPaymentIds.contains(pId)) continue;

      final rId = data['receiptId'] as String?;
      if (rId != null &&
          (seenReceiptIds.contains(rId) || seenReceiptNumbers.contains(rId))) {
        continue;
      }
      final rNum = data['receiptNumber'] as String?;
      if (rNum != null && seenReceiptNumbers.contains(rNum)) continue;
      final reqId = data['requestId'] as String?;
      if (reqId != null && seenRequestIds.contains(reqId)) continue;

      final date = _parseDate(data['date'] ?? data['paymentDate'] ?? data['createdAt']);
      final pAmount = (data['paidAmount'] as num?)?.toDouble() ??
          (data['amount'] as num?)?.toDouble() ??
          0.0;

      // Fuzzy duplicate check: same amount within 15 minutes of an already included receipt
      final isFuzzyDup = transactions.any((t) =>
          ((t['amount'] as double? ?? 0.0) - pAmount).abs() < 0.01 &&
          ((t['date'] as DateTime).difference(date).abs().inMinutes < 15));
      if (isFuzzyDup) continue;

      final shortId = pId.length >= 6 ? pId.substring(0, 6).toUpperCase() : pId.toUpperCase();
      transactions.add({
        'id': pId,
        'receiptId': rId,
        'title': data['referenceNumber']?.toString().isNotEmpty == true
            ? 'Ref: ${data['referenceNumber']}'
            : (rNum?.isNotEmpty == true ? rNum : 'Payment #$shortId'),
        'amount': pAmount,
        'date': date,
        'method': data['paymentMethod'] ?? data['method'] ?? 'Cash',
        'planName': data['planName'] ?? '',
        'status': (data['status'] ?? 'paid').toString(),
        'isOfficialReceipt': rId != null,
      });
    }

    // 3. Fallback ONLY for genuine active paid admissions (never unpaid pending students!)
    if (transactions.isEmpty) {
      final syntheticReceipt = buildSyntheticEnrollmentReceipt(
        libraryId: libraryId,
        student: student,
        plans: plans,
        effectiveUid: effectiveUid,
      );
      if (syntheticReceipt != null) {
        final matchedPlan =
            plans.where((p) => p.id == student.planId).firstOrNull;
        final planName =
            syntheticReceipt.customFields['planName']?.toString() ??
                matchedPlan?.name ??
                'Study Pass';
        transactions.add({
          'id': syntheticReceipt.id,
          'receiptId': syntheticReceipt.id,
          'title': '$planName Enrollment',
          'amount': syntheticReceipt.amount,
          'date': syntheticReceipt.validFrom,
          'method': syntheticReceipt.paymentMethod,
          'planName': planName,
          'status': 'active',
          'isOfficialReceipt': true,
          'receiptModel': syntheticReceipt,
          'planModel': ?matchedPlan,
        });
      }
    }

    transactions.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
    return transactions;
  }

  /// Computes total confirmed fee payments, excluding voided, cancelled, pending, and refunded rows.
  static double computeTotalPaid(List<Map<String, dynamic>> transactions) {
    double total = 0.0;
    for (final t in transactions) {
      if (isConfirmedPaidStatus(t['status']?.toString())) {
        total += (t['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.now();
  }
}
