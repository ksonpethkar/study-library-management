import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/waiting_list_model.dart';

class WaitingListRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addToWaitingList(String libraryId, WaitingListEntry entry) async {
    final docRef = _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.waitingList)
        .doc();

    final newEntry = entry.copyWith(id: docRef.id, createdAt: DateTime.now());
    await docRef.set(newEntry.toJson());
  }

  Future<void> removeFromWaitingList(String libraryId, String entryId) async {
    await _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.waitingList)
        .doc(entryId)
        .delete();
  }

  Stream<List<WaitingListEntry>> getWaitingList(String libraryId) {
    return _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.waitingList)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                WaitingListEntry.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> notifyEntry(String libraryId, String entryId) async {
    await _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.waitingList)
        .doc(entryId)
        .update({'notifiedAt': FieldValue.serverTimestamp()});
  }

  Future<void> notifyNextInLine(String libraryId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.waitingList)
        .orderBy('createdAt')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final entryId = snapshot.docs.first.id;
      await notifyEntry(libraryId, entryId);
    }
  }

  Future<int> getPosition(String libraryId, String studentId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.waitingList)
        .orderBy('createdAt')
        .get();

    for (int i = 0; i < snapshot.docs.length; i++) {
      if (snapshot.docs[i].data()['studentId'] == studentId) {
        return i + 1;
      }
    }
    return -1;
  }
}

final waitingListRepositoryProvider = Provider<WaitingListRepository>((ref) {
  return WaitingListRepository();
});

final waitingListStreamProvider =
    StreamProvider.autoDispose<List<WaitingListEntry>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(waitingListRepositoryProvider).getWaitingList(libraryId);
});
