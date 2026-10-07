import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/firestore_paths.dart';
import 'package:study_library/models/recycle_bin_model.dart';

class RecycleBinRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> moveToRecycleBin(String libraryId, String type, Map<String, dynamic> originalData) async {
    final itemId = originalData['id'] ?? _firestore.collection(FirestorePaths.recycleBin).doc().id;
    final currentUser = FirebaseAuth.instance.currentUser;
    final item = RecycleBinItem(
      id: itemId,
      type: type,
      originalData: originalData,
      deletedBy: currentUser?.email ?? currentUser?.uid ?? 'system',
      deletedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      displayName: originalData['name'] ?? originalData['label'] ?? 'Deleted Item',
    );
    
    await _firestore
        .collection(FirestorePaths.recycleBin)
        .doc(itemId)
        .set({...item.toJson(), 'libraryId': libraryId});
  }

  Future<void> restoreFromRecycleBin(String libraryId, String itemId) async {
    final docRef = _firestore.collection(FirestorePaths.recycleBin).doc(itemId);
    final doc = await docRef.get();
    
    if (doc.exists) {
      final data = RecycleBinItem.fromJson(doc.data()!);
      final collectionPath = _getCollectionPath(data.type);
      
      if (collectionPath.isNotEmpty) {
        await _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(collectionPath)
            .doc(data.id)
            .set(data.originalData);
            
        await docRef.delete();
      }
    }
  }

  Future<void> permanentlyDelete(String libraryId, String itemId) async {
    await _firestore.collection(FirestorePaths.recycleBin).doc(itemId).delete();
  }

  Stream<List<RecycleBinItem>> getRecycleBinItems(String libraryId, {String? typeFilter}) {
    Query query = _firestore.collection(FirestorePaths.recycleBin).where('libraryId', isEqualTo: libraryId);
    
    if (typeFilter != null) {
      query = query.where('type', isEqualTo: typeFilter);
    }
    
    return query.snapshots().map((snapshot) => 
      snapshot.docs.map((doc) => RecycleBinItem.fromJson(doc.data() as Map<String, dynamic>)).toList()
    );
  }

  Future<void> restoreAll(String libraryId) async {
    final snapshot = await _firestore.collection(FirestorePaths.recycleBin).where('libraryId', isEqualTo: libraryId).get();
    for (var doc in snapshot.docs) {
      await restoreFromRecycleBin(libraryId, doc.id);
    }
  }

  Future<void> deleteAll(String libraryId) async {
    final snapshot = await _firestore.collection(FirestorePaths.recycleBin).where('libraryId', isEqualTo: libraryId).get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> cleanupExpired(String libraryId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.recycleBin)
        .where('libraryId', isEqualTo: libraryId)
        .where('expiresAt', isLessThanOrEqualTo: Timestamp.now())
        .get();
        
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  String _getCollectionPath(String type) {
    switch (type) {
      case 'student': return FirestorePaths.students;
      case 'section': return FirestorePaths.sections;
      case 'plan': return FirestorePaths.plans;
      case 'receipt': return FirestorePaths.receipts;
      default: return '';
    }
  }
}
