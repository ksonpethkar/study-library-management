import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/models/holiday_model.dart';

/// Stream of all holidays for the active library, sorted by date ascending in Dart.
final holidaysStreamProvider = StreamProvider.autoDispose<List<HolidayModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('holidays')
      .snapshots()
      .map((snapshot) {
    final holidays = snapshot.docs.map((doc) {
      return HolidayModel.fromJson({
        ...doc.data(),
        'id': doc.id,
      });
    }).toList();

    // Sort by date ascending in Dart (composite index avoided)
    holidays.sort((a, b) => a.date.compareTo(b.date));
    return holidays;
  });
});

/// Stream of upcoming holidays (today and future only).
final upcomingHolidaysProvider = Provider.autoDispose<List<HolidayModel>>((ref) {
  final holidays = ref.watch(holidaysStreamProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return holidays.where((h) {
    final hDate = DateTime(h.date.year, h.date.month, h.date.day);
    return !hDate.isBefore(today);
  }).toList();
});
