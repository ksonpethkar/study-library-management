import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  Future<String> getNextReceiptNumber(String libraryId) async {
    final effectiveLibId = libraryId.isNotEmpty ? libraryId : RemoteConfigService.defaultLibraryId;
    final counterRef = _firestore
        .collection('libraries')
        .doc(effectiveLibId)
        .collection('metadata')
        .doc('receiptCounter');

    String prefix = 'REC';
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

  Future<String> generateReceipt(
    String libraryId,
    ReceiptModel receipt, {
    bool recordMatchingPayment = true,
  }) async {
    final doc = _receiptsRef(libraryId).doc();
    final newReceipt = receipt.copyWith(
      id: doc.id,
      libraryId: libraryId,
      createdAt: receipt.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await doc.set(newReceipt.toJson());

    // Atomically increment revenue aggregate
    final amt = newReceipt.amount;
    final dateStr = (newReceipt.createdAt ?? DateTime.now()).toIso8601String();
    final month = dateStr.substring(0, 7);
    if (amt > 0) {
      _firestore.collection('libraries').doc(libraryId).collection('settings').doc('revenue_aggregate').set({
        'totalRevenue': FieldValue.increment(amt),
        'totalPayments': FieldValue.increment(1),
        'monthlyRevenue.$month': FieldValue.increment(amt),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).ignore();
    }

    // Atomically create matching payment document if not already recorded
    if (recordMatchingPayment) {
      try {
        final paymentDoc = _firestore.collection('libraries').doc(libraryId).collection('payments').doc();
        await paymentDoc.set({
          'id': paymentDoc.id,
          'studentId': newReceipt.studentId,
          if (newReceipt.studentUserId != null && newReceipt.studentUserId!.isNotEmpty)
            'studentUserId': newReceipt.studentUserId,
          'amount': newReceipt.amount,
          'totalPlanFee': newReceipt.totalFee ?? newReceipt.amount,
          'remainingDue': newReceipt.remainingDue ?? 0.0,
          'installmentNumber': newReceipt.installmentNumber,
          'method': newReceipt.paymentMethod.isNotEmpty ? newReceipt.paymentMethod : 'Cash',
          'date': newReceipt.createdAt != null ? Timestamp.fromDate(newReceipt.createdAt!) : FieldValue.serverTimestamp(),
          'receiptId': doc.id,
          'receiptNumber': newReceipt.receiptNumber,
          'status': 'paid',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Failed to record matching payment for receipt ${doc.id}: $e');
      }
    }

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

    // Also sync linked payment and decrement revenue aggregate
    final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final createdAtRaw = data['createdAt'];
    final dateStr = createdAtRaw is String ? createdAtRaw : (createdAtRaw is Timestamp ? createdAtRaw.toDate().toIso8601String() : DateTime.now().toIso8601String());
    final month = dateStr.substring(0, 7);

    if (amt > 0) {
      _firestore.collection('libraries').doc(libraryId).collection('settings').doc('revenue_aggregate').set({
        'totalRevenue': FieldValue.increment(-amt),
        'monthlyRevenue.$month': FieldValue.increment(-amt),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).ignore();
    }

    // Void any payment linked to this receipt
    try {
      final pSnap = await _firestore.collection('libraries').doc(libraryId).collection('payments')
          .where('receiptId', isEqualTo: receiptId).get();
      for (final pDoc in pSnap.docs) {
        await pDoc.reference.update({
          'status': 'voided',
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
    };

    final libBinRef = _firestore
        .collection('libraries')
        .doc(libraryId)
        .collection('recycle_bin')
        .doc(receiptId);
    batch.set(libBinRef, recycleBinData);

    // 2. Hard-delete from receipts collection
    batch.delete(receiptRef);

    await batch.commit();

    try {
      final globalBinRef = _firestore.collection('recycle_bin').doc(receiptId);
      await globalBinRef.set(recycleBinData);
    } catch (_) {}

    // 3. Decrement revenue aggregate
    final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final createdAtRaw = data['createdAt'];
    final dateStr = createdAtRaw is String ? createdAtRaw : (createdAtRaw is Timestamp ? createdAtRaw.toDate().toIso8601String() : DateTime.now().toIso8601String());
    final month = dateStr.substring(0, 7);

    if (amt > 0) {
      _firestore.collection('libraries').doc(libraryId).collection('settings').doc('revenue_aggregate').set({
        'totalRevenue': FieldValue.increment(-amt),
        'monthlyRevenue.$month': FieldValue.increment(-amt),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).ignore();
    }

    // 4. Soft-delete / remove linked payment record
    try {
      final pSnap = await _firestore.collection('libraries').doc(libraryId).collection('payments')
          .where('receiptId', isEqualTo: receiptId).get();
      for (final pDoc in pSnap.docs) {
        await pDoc.reference.delete();
      }
    } catch (_) { /* intentionally silent */ }

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
