import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
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

/// Immutable snapshot of a student's live position & status in the waiting queue
class StudentQueueInfo {
  final WaitingListEntry entry;
  final int position;
  final int totalInQueue;
  final bool isSeatReady;
  final String? suggestedSeatLabel;

  const StudentQueueInfo({
    required this.entry,
    required this.position,
    required this.totalInQueue,
    required this.isSeatReady,
    this.suggestedSeatLabel,
  });
}

/// Real-time stream of the current student's / prospective user's active waiting list entry.
/// Matches against studentId, Auth UID, phone numbers, and email.
final studentWaitingQueueProvider =
    StreamProvider.autoDispose<StudentQueueInfo?>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  final student = ref.watch(currentStudentProvider).value;
  final user = FirebaseAuth.instance.currentUser;
  final uid = user?.uid ?? '';
  final email = (user?.email ?? '').trim().toLowerCase();

  if (libraryId == null || libraryId.isEmpty) return Stream.value(null);

  return ref
      .watch(waitingListRepositoryProvider)
      .getWaitingList(libraryId)
      .map((entries) {
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final sId = entry.studentId;
      final sPhone = entry.studentPhone.replaceAll(RegExp(r'\D'), '');
      final myPhone = (student?.phone ?? '').replaceAll(RegExp(r'\D'), '');
      final userPhone = (user?.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
      final myStudentId = student?.id ?? '';
      final myStudentUserId = (student?.userId ?? '').toString();

      bool isMatch = false;
      if (myStudentId.isNotEmpty && sId == myStudentId) isMatch = true;
      if (uid.isNotEmpty && sId == uid) isMatch = true;
      if (myStudentUserId.isNotEmpty && sId == myStudentUserId) isMatch = true;
      if (myPhone.isNotEmpty && sPhone.isNotEmpty && (myPhone == sPhone || myPhone.endsWith(sPhone) || sPhone.endsWith(myPhone))) {
        isMatch = true;
      }
      if (userPhone.isNotEmpty && sPhone.isNotEmpty && (userPhone == sPhone || userPhone.endsWith(sPhone) || sPhone.endsWith(userPhone))) {
        isMatch = true;
      }
      if (email.isNotEmpty && entry.studentPhone.isNotEmpty && email.contains(entry.studentPhone)) {
        isMatch = true;
      }

      if (isMatch) {
        return StudentQueueInfo(
          entry: entry,
          position: i + 1,
          totalInQueue: entries.length,
          isSeatReady: entry.suggestedSeatLabel != null &&
              entry.suggestedSeatLabel!.isNotEmpty,
          suggestedSeatLabel: entry.suggestedSeatLabel,
        );
      }
    }
    return null;
  });
});
