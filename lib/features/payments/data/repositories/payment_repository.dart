import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/models/payment_model.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore;

  PaymentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _paymentsRef(String libraryId) =>
      _firestore.collection('libraries').doc(libraryId).collection('payments');

  Future<String> recordPayment(String libraryId, String studentId, PaymentModel payment) async {
    final doc = _paymentsRef(libraryId).doc();
    final newPayment = payment.copyWith(
      id: doc.id,
      studentId: studentId,
      createdAt: DateTime.now(),
    );
    await doc.set(newPayment.toJson());
    return doc.id;
  }

  Stream<List<PaymentModel>> getPayments(String libraryId, String studentId) {
    return _paymentsRef(libraryId)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
          final payments = snap.docs.map((doc) => PaymentModel.fromJson(doc.data())).toList();
          payments.sort((a, b) => b.date.compareTo(a.date));
          return payments;
        });
  }

  Future<bool> checkDuplicatePayment(String libraryId, String studentId, double amount) async {
    final fiveMinsAgo = DateTime.now().subtract(const Duration(minutes: 5));
    final snapshot = await _paymentsRef(libraryId)
        .where('studentId', isEqualTo: studentId)
        .get();
    
    return snapshot.docs.any((doc) {
      final data = doc.data();
      final docAmount = (data['amount'] ?? 0).toDouble();
      final docDate = DateTime.tryParse(data['date'] ?? '') ?? DateTime(2000);
      return docAmount == amount && docDate.isAfter(fiveMinsAgo);
    });
  }

  Future<void> updatePaymentStatus(String libraryId, String paymentId, PaymentStatus status) async {
    await _paymentsRef(libraryId).doc(paymentId).update({
      'status': status.name,
    });
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

