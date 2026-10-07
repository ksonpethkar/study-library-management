import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/models/plan_model.dart';

class PlanRepository {
  final FirebaseFirestore _firestore;

  PlanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _plansRef(String libraryId) =>
      _firestore.collection('libraries').doc(libraryId).collection('plans');

  CollectionReference<Map<String, dynamic>> _studentsRef(String libraryId) =>
      _firestore.collection('libraries').doc(libraryId).collection('students');

  Future<String> createPlan(String libraryId, PlanModel plan) async {
    final doc = _plansRef(libraryId).doc();
    final newPlan = plan.copyWith(
      id: doc.id,
      libraryId: libraryId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await doc.set(newPlan.toJson());
    return doc.id;
  }

  Future<void> updatePlan(String libraryId, PlanModel plan) async {
    final updatedPlan = plan.copyWith(updatedAt: DateTime.now());
    await _plansRef(libraryId).doc(plan.id).update(updatedPlan.toJson());
  }

  Future<void> deletePlan(String libraryId, String planId) async {
    final hasStudents = await hasActiveStudents(libraryId, planId);
    if (hasStudents) {
      throw Exception('Cannot delete a plan with active students.');
    }
    await _plansRef(libraryId).doc(planId).update({
      'deletedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<String> duplicatePlan(String libraryId, String planId) async {
    final docSnap = await _plansRef(libraryId).doc(planId).get();
    if (!docSnap.exists) throw Exception('Plan not found.');
    final original = PlanModel.fromJson(docSnap.data()!);
    final newDoc = _plansRef(libraryId).doc();
    final duplicate = original.copyWith(
      id: newDoc.id,
      name: '${original.name} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await newDoc.set(duplicate.toJson());
    return newDoc.id;
  }

  Future<void> toggleActive(String libraryId, String planId, bool isActive) async {
    await _plansRef(libraryId).doc(planId).update({
      'isActive': isActive,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> toggleFeatured(String libraryId, String planId, bool isFeatured) async {
    await _plansRef(libraryId).doc(planId).update({
      'isFeatured': isFeatured,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> reorderPlans(String libraryId, List<String> planIds) async {
    final batch = _firestore.batch();
    for (int i = 0; i < planIds.length; i++) {
      final docRef = _plansRef(libraryId).doc(planIds[i]);
      batch.update(docRef, {
        'displayOrder': i,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit();
  }

  Future<void> bulkPriceUpdate(
    String libraryId, {
    double? addAmount,
    double? percentage,
  }) async {
    final snapshot = await _plansRef(libraryId).get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      final plan = PlanModel.fromJson(doc.data());
      double newPrice = plan.price;
      if (addAmount != null) {
        newPrice += addAmount;
      } else if (percentage != null) {
        newPrice += (newPrice * percentage / 100);
      }
      batch.update(doc.reference, {
        'price': newPrice,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit();
  }

  Stream<List<PlanModel>> getPlans(String libraryId) {
    return _plansRef(libraryId)
        .snapshots()
        .map((snapshot) {
          final plans = snapshot.docs
              .map((doc) => PlanModel.fromJson(doc.data()))
              .where((p) => p.deletedAt == null)
              .toList();
          plans.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
          return plans;
        });
  }

  Stream<List<PlanModel>> getActivePlans(String libraryId) {
    return _plansRef(libraryId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final plans = snapshot.docs
              .map((doc) => PlanModel.fromJson(doc.data()))
              .where((p) => p.deletedAt == null)
              .toList();
          plans.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
          return plans;
        });
  }

  Future<bool> hasActiveStudents(String libraryId, String planId) async {
    final snapshot = await _studentsRef(libraryId)
        .where('planId', isEqualTo: planId)
        .where('deletedAt', isNull: true)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
