import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/firestore_paths.dart';
import 'package:study_library/models/recycle_bin_model.dart';

class RecycleBinRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _libBinRef(String libraryId) =>
      _firestore.collection(FirestorePaths.libraries).doc(libraryId).collection(FirestorePaths.recycleBin);

  Future<void> moveToRecycleBin(String libraryId, String type, Map<String, dynamic> originalData) async {
    final itemId = originalData['id'] ?? _libBinRef(libraryId).doc().id;
    final currentUser = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();

    final payload = {
      ...originalData,
      'id': itemId,
      'type': type.toLowerCase(),
      'libraryId': libraryId,
      'deletedBy': currentUser?.email ?? currentUser?.uid ?? 'system',
      'deletedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
      'displayName': originalData['name'] ?? originalData['title'] ?? originalData['label'] ?? 'Deleted Item',
      'originalData': originalData,
    };

    // Primary: Library-scoped multi-tenant store
    await _libBinRef(libraryId).doc(itemId).set(payload, SetOptions(merge: true));

    // Secondary root backup (safely ignored if non-master admin lacks root write permissions)
    try {
      await _firestore.collection(FirestorePaths.recycleBin).doc(itemId).set(payload, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> restoreFromRecycleBin(String libraryId, String itemId) async {
    final docRef = _libBinRef(libraryId).doc(itemId);
    var doc = await docRef.get();
    Map<String, dynamic>? data;

    if (doc.exists) {
      data = doc.data();
    } else {
      try {
        final rootDoc = await _firestore.collection(FirestorePaths.recycleBin).doc(itemId).get();
        if (rootDoc.exists) data = rootDoc.data();
      } catch (_) {}
    }

    if (data == null) return;

    final type = (data['type'] ?? 'student').toString().toLowerCase();
    final collectionPath = _getCollectionPath(type);
    if (collectionPath.isEmpty) return;

    final rawData = data['originalData'] is Map
        ? Map<String, dynamic>.from(data['originalData'] as Map)
        : Map<String, dynamic>.from(data);

    final restorePayload = Map<String, dynamic>.from(rawData);
    restorePayload.remove('deletedAt');
    restorePayload.remove('type');
    restorePayload.remove('libraryId');
    restorePayload.remove('displayName');
    restorePayload.remove('expiresAt');
    restorePayload.remove('deletedBy');
    restorePayload.remove('originalData');

    if (type == 'student' && restorePayload['seatId'] != null) {
      final seatId = restorePayload['seatId'] as String;
      final occupied = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .where('seatId', isEqualTo: seatId)
          .where('membershipStatus', isEqualTo: 'active')
          .get();
      if (occupied.docs.isNotEmpty) {
        restorePayload['seatId'] = null;
      }
    }

    final targetRef = _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(collectionPath)
        .doc(itemId);

    if (type == 'plan') {
      restorePayload['deletedAt'] = null;
    }

    await targetRef.set(restorePayload, SetOptions(merge: true));
    await docRef.delete();

    try {
      await _firestore.collection(FirestorePaths.recycleBin).doc(itemId).delete();
    } catch (_) {}
  }

  Future<void> permanentlyDelete(String libraryId, String itemId) async {
    await _libBinRef(libraryId).doc(itemId).delete();
    try {
      await _firestore.collection(FirestorePaths.recycleBin).doc(itemId).delete();
    } catch (_) {}
  }

  Stream<List<RecycleBinItem>> getRecycleBinItems(String libraryId, {String? typeFilter}) {
    Query<Map<String, dynamic>> query = _libBinRef(libraryId);
    if (typeFilter != null) {
      query = query.where('type', isEqualTo: typeFilter.toLowerCase());
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => RecycleBinItem.fromJson(doc.data())).toList());
  }

  Future<void> restoreAll(String libraryId) async {
    final snapshot = await _libBinRef(libraryId).get();
    for (var doc in snapshot.docs) {
      await restoreFromRecycleBin(libraryId, doc.id);
    }
  }

  Future<void> deleteAll(String libraryId) async {
    final snapshot = await _libBinRef(libraryId).get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    try {
      final rootSnap = await _firestore.collection(FirestorePaths.recycleBin).where('libraryId', isEqualTo: libraryId).get();
      final rootBatch = _firestore.batch();
      for (var doc in rootSnap.docs) {
        rootBatch.delete(doc.reference);
      }
      await rootBatch.commit();
    } catch (_) {}
  }

  Future<void> cleanupExpired(String libraryId) async {
    final snapshot = await _libBinRef(libraryId)
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
      case 'announcement': return 'announcements';
      default: return '';
    }
  }
}
