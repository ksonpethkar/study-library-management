import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/announcements/data/repositories/announcements_repository.dart';
import 'package:study_library/models/announcement_model.dart';

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepository();
});

final announcementsStreamProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(announcementsRepositoryProvider).watchAnnouncements(libraryId);
});

final unreadAnnouncementsCountProvider = Provider.family<int, String>((ref, studentId) {
  final announcementsAsync = ref.watch(announcementsStreamProvider);
  return announcementsAsync.when(
    data: (announcements) {
      if (studentId.isEmpty) return 0;
      return announcements
          .where((a) => a.isActive && !a.isExpired && !a.readBy.contains(studentId))
          .length;
    },
    loading: () => 0,
    error: (error, stack) => 0,
  );
});
