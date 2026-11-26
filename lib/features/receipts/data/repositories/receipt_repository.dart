import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/services/remote_config_service.dart';

class ReceiptRepository {
  final FirebaseFirestore _firestore;

  ReceiptRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _receiptsRef(String libraryId) {
    final effectiveLibId = libraryId.isNotEmpty ? libraryId : RemoteConfigService.defaultLibraryId;
    return _firestore.collection('libraries').doc(effectiveLibId).collection('receipts');
  }

  static String formatReceiptNumber({required String prefix, required int count, int? year}) {
    final y = year ?? DateTime.now().year;
    return '$prefix-$y-${count.toString().padLeft(4, '0')}';
  }

  Future<String> getNextReceiptNumber(String libraryId) async {
    final effectiveLibId = libraryId.isNotEmpty ? libraryId : RemoteConfigService.defaultLibraryId;
    final counterRef = _firestore
        .collection('libraries')
        .doc(effectiveLibId)
        .collection('metadata')
        .doc('receiptCounter');

    String prefix = 'CC';
    try {
      final templateDoc = await _firestore
          .collection('libraries')
          .doc(effectiveLibId)
          .collection('settings')
          .doc('receipt_template')
          .get();
      if (templateDoc.exists) {
        final customPrefix = templateDoc.data()?['prefix'] as String?;
        if (customPrefix != null && customPrefix.trim().isNotEmpty) {
          prefix = customPrefix.trim().replaceAll(RegExp(r'[-/]+$'), '');
        }
      } else {
        final libDoc = await _firestore.collection('libraries').doc(effectiveLibId).get();
        final libPrefix = libDoc.data()?['membershipPrefix'] as String?;
        if (libPrefix != null && libPrefix.trim().isNotEmpty) {
          prefix = libPrefix.trim();
        }
      }
    } catch (_) { /* intentionally silent */ }

    try {
      return await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(counterRef);
        int nextCount = 1;
        if (doc.exists) {
          nextCount = (doc.data()?['count'] as int? ?? 0) + 1;
        }
        transaction.set(
          counterRef,
          {'count': nextCount},
          SetOptions(merge: true),
        );
        final formattedPrefix = '$prefix-${DateTime.now().year}-';
        return '$formattedPrefix${nextCount.toString().padLeft(4, '0')}';
      });
    } catch (_) {
      // Resilient fallback: time-based sequential receipt number
      final timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      return '$prefix-${DateTime.now().year}-$timeStamp';
    }
  }

  /// Single source of truth for inclusive GST computation across all fee paths.
  static ({
    bool isGstInvoice,
    String gstin,
    String sacCode,
    double gstRate,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
  }) calculateGstBreakdown({
    required double amount,
    required bool isGstBilling,
    double gstRate = 18.0,
    String sacCode = '999293',
    String gstin = '',
  }) {
    double? taxableAmount;
    double? cgstAmount;
    double? sgstAmount;
    if (isGstBilling && amount > 0) {
      taxableAmount = (amount / (1 + (gstRate / 100))).roundToDouble();
      final totalTax = amount - taxableAmount;
      cgstAmount = (totalTax / 2).roundToDouble();
      sgstAmount = totalTax - cgstAmount;
    }
    return (
      isGstInvoice: isGstBilling,
      gstin: gstin.trim(),
      sacCode: isGstBilling ? sacCode : '',
      gstRate: isGstBilling ? gstRate : 0.0,
      taxableAmount: taxableAmount,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
    );
  }

  static String resolveMonthKey(dynamic rawDate) {
    DateTime? parsed;
    if (rawDate is DateTime) {
      parsed = rawDate;
    } else if (rawDate is Timestamp) {
      parsed = rawDate.toDate();
    } else if (rawDate is String) {
      parsed = DateTime.tryParse(rawDate);
    } else if (rawDate is int) {
      parsed = DateTime.fromMillisecondsSinceEpoch(rawDate);
    }
    return (parsed ?? DateTime.now()).toIso8601String().substring(0, 7);
  }

  static void addRevenueAggregateToBatch(
    WriteBatch batch,
    FirebaseFirestore firestore,
    String libraryId, {
    required double amountDelta,
    int paymentsDelta = 0,
    int refundsDelta = 0,
    dynamic referenceDate,
  }) {
    if (libraryId.isEmpty) return;
    if (amountDelta == 0 && paymentsDelta == 0 && refundsDelta == 0) return;
    final month = resolveMonthKey(referenceDate);
    final revRef = firestore
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('revenue_aggregate');
    batch.set(
      revRef,
      {
        if (amountDelta != 0) 'totalRevenue': FieldValue.increment(amountDelta),
        if (paymentsDelta != 0) 'totalPayments': FieldValue.increment(paymentsDelta),
        if (refundsDelta != 0) 'totalRefunds': FieldValue.increment(refundsDelta),
        if (amountDelta != 0) 'monthlyRevenue.$month': FieldValue.increment(amountDelta),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> applyRevenueAggregateDelta(
    FirebaseFirestore firestore,
    String libraryId, {
    required double amountDelta,
    int paymentsDelta = 0,
    int refundsDelta = 0,
    dynamic referenceDate,
  }) async {
    if (libraryId.isEmpty) return;
    if (amountDelta == 0 && paymentsDelta == 0 && refundsDelta == 0) return;
    final month = resolveMonthKey(referenceDate);
    await firestore
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('revenue_aggregate')
        .set({
      if (amountDelta != 0) 'totalRevenue': FieldValue.increment(amountDelta),
      if (paymentsDelta != 0) 'totalPayments': FieldValue.increment(paymentsDelta),
      if (refundsDelta != 0) 'totalRefunds': FieldValue.increment(refundsDelta),
      if (amountDelta != 0) 'monthlyRevenue.$month': FieldValue.increment(amountDelta),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> generateReceipt(
    String libraryId,
    ReceiptModel receipt, {
    bool recordMatchingPayment = true,
    bool updateRevenueAggregate = true,
    Map<String, dynamic>? extraPaymentFields,
  }) async {
    final doc = _receiptsRef(libraryId).doc();
    String rNum = receipt.receiptNumber.trim();
    if (rNum.isEmpty) {
      rNum = await getNextReceiptNumber(libraryId);
    }
    final newReceipt = receipt.copyWith(
      id: doc.id,
      libraryId: libraryId,
      receiptNumber: rNum,
      createdAt: receipt.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(doc, newReceipt.toJson());

    // Atomically increment revenue aggregate once on receipt creation
    final amt = newReceipt.amount;
    if (updateRevenueAggregate && amt > 0) {
      addRevenueAggregateToBatch(
        batch,
        _firestore,
        libraryId,
        amountDelta: amt,
        paymentsDelta: 1,
        referenceDate: newReceipt.createdAt,
      );
    }

    // Atomically create matching payment document if not already recorded separately
    if (recordMatchingPayment) {
      final paymentDoc = _firestore.collection('libraries').doc(libraryId).collection('payments').doc();
      batch.set(paymentDoc, {
        'id': paymentDoc.id,
        'studentId': newReceipt.studentId,
        if (newReceipt.studentUserId != null && newReceipt.studentUserId!.isNotEmpty)
          'studentUserId': newReceipt.studentUserId,
        'amount': newReceipt.amount,
        'totalPlanFee': newReceipt.totalFee ?? newReceipt.amount,
        'remainingDue': newReceipt.remainingDue ?? 0.0,
        'installmentNumber': newReceipt.installmentNumber,
        'method': newReceipt.paymentMethod.isNotEmpty ? newReceipt.paymentMethod : 'Cash',
        'paymentMethod': newReceipt.paymentMethod.isNotEmpty ? newReceipt.paymentMethod : 'Cash',
        'date': newReceipt.createdAt != null ? Timestamp.fromDate(newReceipt.createdAt!) : FieldValue.serverTimestamp(),
        'receiptId': doc.id,
        'receiptNumber': newReceipt.receiptNumber,
        'status': 'paid',
        if (updateRevenueAggregate && amt > 0) 'aggregateSyncedByClient': true,
        ...?extraPaymentFields,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return doc.id;
  }

  Stream<List<ReceiptModel>> getReceipts(String libraryId) {
    return _receiptsRef(libraryId)
        .snapshots()
        .map((snap) {
          final receipts = snap.docs
              .map((doc) => ReceiptModel.fromJson(doc.data()))
              .where((r) => r.deletedAt == null)
              .toList();
          receipts.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
          return receipts;
        });
  }

  Stream<List<ReceiptModel>> getReceiptsByStudent(String libraryId, String studentId) {
    return _receiptsRef(libraryId)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
          final receipts = snap.docs
              .map((doc) => ReceiptModel.fromJson(doc.data()))
              .where((r) => r.deletedAt == null)
              .toList();
          receipts.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
          return receipts;
        });
  }

  Future<void> voidReceipt(String libraryId, String receiptId, {String? reason}) async {
    final doc = await _receiptsRef(libraryId).doc(receiptId).get();
    if (!doc.exists) return;
    final data = doc.data()!;

    await _receiptsRef(libraryId).doc(receiptId).update({
      'status': ReceiptStatus.voided.name,
      'voidReason': reason,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // Also sync linked payment and decrement revenue aggregate cleanly
    final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
    if (amt > 0) {
      applyRevenueAggregateDelta(
        _firestore,
        libraryId,
        amountDelta: -amt,
        referenceDate: data['createdAt'],
      ).ignore();
    }

    // Void any payment linked to this receipt and tag aggregateSyncedStatus so Cloud Triggers don't double-decrement
    try {
      final pSnap = await _firestore.collection('libraries').doc(libraryId).collection('payments')
          .where('receiptId', isEqualTo: receiptId).get();
      for (final pDoc in pSnap.docs) {
        await pDoc.reference.update({
          'status': 'voided',
          'aggregateSyncedStatus': 'voided',
          'cancellationReason': reason ?? 'Receipt voided',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) { /* intentionally silent */ }

    // Invariant Cascade: Check if student has any other active receipts.
    // If not, revert student to inactive and clear plan dates to prevent phantom active access.
    final studentId = data['studentId'] as String?;
    if (studentId != null && studentId.isNotEmpty) {
      try {
        final remainingActiveSnap = await _receiptsRef(libraryId)
            .where('studentId', isEqualTo: studentId)
            .where('status', isEqualTo: ReceiptStatus.active.name)
            .get();
        final otherActiveReceipts = remainingActiveSnap.docs
            .where((d) => d.id != receiptId)
            .toList();

        if (otherActiveReceipts.isEmpty) {
          await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(studentId)
              .update({
            'membershipStatus': 'inactive',
            'planStartDate': null,
            'planEndDate': null,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      } catch (_) { /* intentionally silent */ }
    }
  }

  /// Deletes a receipt by moving it to the recycle_bin collection (restorable for 30 days).
  Future<void> deleteReceipt(String libraryId, String receiptId) async {
    final receiptRef = _receiptsRef(libraryId).doc(receiptId);
    final doc = await receiptRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final now = DateTime.now();
    final currentUser = FirebaseAuth.instance.currentUser;

    // Fetch linked payments BEFORE batch commit so recycle bin retains them for symmetrical restore
    final linkedPaymentSnaps = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    try {
      final pSnap = await _firestore.collection('libraries').doc(libraryId).collection('payments')
          .where('receiptId', isEqualTo: receiptId).get();
      linkedPaymentSnaps.addAll(pSnap.docs);
    } catch (_) {}

    final batch = _firestore.batch();

    // 1. Write a copy to both library-scoped and global recycle_bin collections
    final recycleBinData = {
      ...data,
      'id': receiptId,
      'name': 'Receipt #${data['receiptNumber'] ?? receiptId}',
      'type': 'receipt',
      'libraryId': libraryId,
      'deletedAt': now.toIso8601String(),
      'deletedBy': currentUser?.email ?? currentUser?.uid ?? 'admin',
      'displayName': 'Receipt #${data['receiptNumber'] ?? receiptId}',
      'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      if (linkedPaymentSnaps.isNotEmpty)
        'linkedPayments': linkedPaymentSnaps
            .map((p) => {'id': p.id, ...p.data()})
            .toList(),
    };

    final libBinRef = _firestore
        .collection('libraries')
        .doc(libraryId)
        .collection('recycle_bin')
        .doc(receiptId);
    batch.set(libBinRef, recycleBinData);

    // 2. Hard-delete from receipts collection
    batch.delete(receiptRef);

    // 3. Decrement revenue aggregate (unless already voided)
    final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final receiptStatusStr = (data['status'] ?? 'active').toString().toLowerCase();
    if (amt > 0 && receiptStatusStr != ReceiptStatus.voided.name) {
      addRevenueAggregateToBatch(
        batch,
        _firestore,
        libraryId,
        amountDelta: -amt,
        paymentsDelta: -1,
        referenceDate: data['createdAt'],
      );
    }

    // 4. Delete linked payment records atomically
    for (final pDoc in linkedPaymentSnaps) {
      batch.delete(pDoc.reference);
    }

    await batch.commit();

    try {
      final globalBinRef = _firestore.collection('recycle_bin').doc(receiptId);
      await globalBinRef.set(recycleBinData);
    } catch (_) {}

    // 5. Invariant Cascade: If deleted receipt was active, verify remaining active receipts
    final studentId = data['studentId'] as String?;
    final statusStr = data['status'] as String?;
    if (studentId != null && studentId.isNotEmpty && statusStr == ReceiptStatus.active.name) {
      try {
        final remainingActiveSnap = await _receiptsRef(libraryId)
            .where('studentId', isEqualTo: studentId)
            .where('status', isEqualTo: ReceiptStatus.active.name)
            .get();
        final otherActiveReceipts = remainingActiveSnap.docs
            .where((d) => d.id != receiptId)
            .toList();

        if (otherActiveReceipts.isEmpty) {
          await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(studentId)
              .update({
            'membershipStatus': 'inactive',
            'planStartDate': null,
            'planEndDate': null,
            'updatedAt': now.toIso8601String(),
          });
        }
      } catch (_) { /* intentionally silent */ }
    }
  }

  /// Update receipt notes (admin editable)
  Future<void> updateReceiptNotes(String libraryId, String receiptId, String notes) async {
    await _receiptsRef(libraryId).doc(receiptId).update({
      'customFields.adminNotes': notes,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Update payment method (admin editable)
  Future<void> updatePaymentMethod(String libraryId, String receiptId, String method) async {
    await _receiptsRef(libraryId).doc(receiptId).update({
      'paymentMethod': method,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Unvoid a receipt (restore to active)
  Future<void> unvoidReceipt(String libraryId, String receiptId) async {
    final doc = await _receiptsRef(libraryId).doc(receiptId).get();
    if (!doc.exists) return;
    final data = doc.data()!;

    await _receiptsRef(libraryId).doc(receiptId).update({
      'status': ReceiptStatus.active.name,
      'voidReason': null,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // Invariant Cascade: Re-activate student if receipt has valid future dates
    final studentId = data['studentId'] as String?;
    final validToRaw = data['validTo'];
    if (studentId != null && studentId.isNotEmpty && validToRaw != null) {
      DateTime? validTo = validToRaw is Timestamp
          ? validToRaw.toDate()
          : (validToRaw is String ? DateTime.tryParse(validToRaw) : null);
      if (validTo != null && validTo.isAfter(DateTime.now())) {
        final validFromRaw = data['validFrom'];
        DateTime? validFrom = validFromRaw is Timestamp
            ? validFromRaw.toDate()
            : (validFromRaw is String ? DateTime.tryParse(validFromRaw) : null);

        await _firestore
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .doc(studentId)
            .update({
          'membershipStatus': 'active',
          if (validFrom != null) 'planStartDate': validFrom.toIso8601String(),
          'planEndDate': validTo.toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  /// Backfill missing studentUserId on legacy receipts and payments for real-time visibility
  Future<void> healStudentReceiptsAndPayments(String libraryId, String studentId, String studentUserId) async {
    if (libraryId.isEmpty || studentId.isEmpty || studentUserId.isEmpty) return;
    try {
      final batch = _firestore.batch();
      var hasUpdates = false;

      final receiptsSnap = await _receiptsRef(libraryId)
          .where('studentId', isEqualTo: studentId)
          .limit(30)
          .get();

      for (final doc in receiptsSnap.docs) {
        final data = doc.data();
        if (data['studentUserId'] == null || (data['studentUserId'] as String).isEmpty) {
          batch.update(doc.reference, {'studentUserId': studentUserId});
          hasUpdates = true;
        }
      }

      final paymentsSnap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('payments')
          .where('studentId', isEqualTo: studentId)
          .limit(30)
          .get();

      for (final doc in paymentsSnap.docs) {
        final data = doc.data();
        if (data['studentUserId'] == null || (data['studentUserId'] as String).isEmpty) {
          batch.update(doc.reference, {'studentUserId': studentUserId});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (_) {
      // Non-blocking best-effort
    }
  }
}
