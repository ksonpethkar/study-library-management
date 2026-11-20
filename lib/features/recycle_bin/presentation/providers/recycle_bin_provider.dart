import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/recycle_bin_repository.dart';

final recycleBinRepositoryProvider = Provider<RecycleBinRepository>((ref) {
  return RecycleBinRepository();
});

/// Streams all items in the Recycle Bin for the active library, ordered by deletion timestamp descending.
final recycleBinStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('recycle_bin')
      .snapshots()
      .map((snapshot) {
    final items = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    items.sort((a, b) {
      final aTime = a['deletedAt'];
      final bTime = b['deletedAt'];
      DateTime dtA = DateTime(1970);
      DateTime dtB = DateTime(1970);
      if (aTime is Timestamp) dtA = aTime.toDate();
      if (bTime is Timestamp) dtB = bTime.toDate();
      if (aTime is String) dtA = DateTime.tryParse(aTime) ?? dtA;
      if (bTime is String) dtB = DateTime.tryParse(bTime) ?? dtB;
      return dtB.compareTo(dtA);
    });
    return items;
  });
});
