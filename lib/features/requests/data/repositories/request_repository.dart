import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
// Note: Assuming RequestModel exists
// import 'package:study_library/models/request_model.dart';

class RequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createRequest(String libraryId, dynamic requestModel) async {
    try {
      final docRef = _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.requests)
          .doc();
      await docRef.set(requestModel.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create request.');
    }
  }

  Stream<List<dynamic>> getPendingRequests(String libraryId) {
    return _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.requests)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()); // Assuming RequestModel.fromMap(doc.data()) in real app
  }

  Stream<List<dynamic>> getAllRequests(String libraryId) {
    return _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.requests)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> approveRequest(String libraryId, String requestId) async {
    try {
      // In a real app, this should be a transaction or batch to assign seat + create student
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.requests)
          .doc(requestId)
          .update({'status': 'approved', 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to approve request.');
    }
  }

  Future<void> rejectRequest(String libraryId, String requestId, String reason) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.requests)
          .doc(requestId)
          .update({'status': 'rejected', 'rejectReason': reason, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to reject request.');
    }
  }

  Future<int> getRequestCount(String libraryId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.requests)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
