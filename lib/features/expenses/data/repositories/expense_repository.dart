import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/models/expense_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String libraryId) {
    return _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.expenses);
  }

  Stream<List<ExpenseModel>> streamExpenses(String libraryId) {
    if (libraryId.isEmpty) return Stream.value([]);
    return _collection(libraryId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => ExpenseModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      // Sort descending by date
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<List<ExpenseModel>> getExpenses(
    String libraryId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (libraryId.isEmpty) return [];
    try {
      final snap = await _collection(libraryId).get();

      var list = snap.docs
          .map((doc) {
            try {
              return ExpenseModel.fromJson({...doc.data(), 'id': doc.id});
            } catch (_) {
              return null;
            }
          })
          .whereType<ExpenseModel>()
          .where((e) => !e.isDeleted)
          .toList();

      if (startDate != null) {
        list = list.where((e) => e.date.isAfter(startDate.subtract(const Duration(seconds: 1)))).toList();
      }
      if (endDate != null) {
        list = list.where((e) => e.date.isBefore(endDate.add(const Duration(seconds: 1)))).toList();
      }

      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<String> addExpense(String libraryId, ExpenseModel expense) async {
    final ref = _collection(libraryId).doc();
    final data = expense.copyWith(id: ref.id, libraryId: libraryId).toJson();
    await ref.set(data);
    return ref.id;
  }

  Future<void> updateExpense(String libraryId, ExpenseModel expense) async {
    await _collection(libraryId).doc(expense.id).update({
      ...expense.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense(String libraryId, String expenseId) async {
    await _collection(libraryId).doc(expenseId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }
}
