import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/models/receipt_model.dart';

class ReceiptRepository {
  final FirebaseFirestore _firestore;

  ReceiptRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _receiptsRef(String libraryId) =>
      _firestore.collection('libraries').doc(libraryId).collection('receipts');

  Future<String> getNextReceiptNumber(String libraryId) async {
    final counterRef = _firestore
        .collection('libraries')
        .doc(libraryId)
        .collection('metadata')
        .doc('receiptCounter');

    String prefix = 'REC';
    try {
      final templateDoc = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('receipt_template')
          .get();
      if (templateDoc.exists) {
        final customPrefix = templateDoc.data()?['prefix'] as String?;
        if (customPrefix != null && customPrefix.trim().isNotEmpty) {
          prefix = customPrefix.trim().replaceAll(RegExp(r'[-/]+$'), '');
        }
      }
    } catch (_) {}

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
  }

  Future<String> generateReceipt(String libraryId, ReceiptModel receipt) async {
    final doc = _receiptsRef(libraryId).doc();
    final newReceipt = receipt.copyWith(
      id: doc.id,
      libraryId: libraryId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await doc.set(newReceipt.toJson());
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
    await _receiptsRef(libraryId).doc(receiptId).update({
      'status': ReceiptStatus.voided.name,
      'voidReason': reason,
      'updatedAt': DateTime.now().toIso8601String(),
    });
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

    // 1. Write a copy to the global recycle_bin collection
    final binRef = _firestore.collection('recycle_bin').doc(receiptId);
    batch.set(binRef, {
      ...data,
      'id': receiptId,
      'type': 'receipt',
      'libraryId': libraryId,
      'deletedAt': now.toIso8601String(),
      'deletedBy': currentUser?.email ?? currentUser?.uid ?? 'admin',
      'displayName': 'Receipt #${data['receiptNumber'] ?? receiptId}',
      'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
    });

    // 2. Hard-delete from receipts collection
    batch.delete(receiptRef);

    await batch.commit();
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
    await _receiptsRef(libraryId).doc(receiptId).update({
      'status': ReceiptStatus.active.name,
      'voidReason': null,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
