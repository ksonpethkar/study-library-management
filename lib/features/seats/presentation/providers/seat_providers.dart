import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/features/seats/data/repositories/seat_repository.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/core/providers/library_provider.dart';

final seatRepositoryProvider = Provider<SeatRepository>((ref) {
  return SeatRepository();
});

final sectionsProvider = StreamProvider<List<SectionModel>>((ref) {
  final repository = ref.watch(seatRepositoryProvider);
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null) return Stream.value([]);
  return repository.getSections(libraryId);
});

final seatsProvider = StreamProvider.family<List<SeatModel>, String>((
  ref,
  sectionId,
) {
  final repository = ref.watch(seatRepositoryProvider);
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null) return Stream.value([]);
  return repository.getSeats(libraryId, sectionId);
});

final availableSeatsProvider = StreamProvider<List<SeatModel>>((ref) {
  final repository = ref.watch(seatRepositoryProvider);
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null) return Stream.value([]);
  return repository.getAvailableSeats(libraryId);
});

final occupancyProvider = FutureProvider<Map<String, int>>((ref) {
  final repository = ref.watch(seatRepositoryProvider);
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null) return {'total': 0, 'occupied': 0, 'available': 0};
  return repository.getOccupancyCount(libraryId);
});

/// Selected seats for bulk operations: maps seatId -> sectionId
class SelectedSeatsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  void toggleSelection(String seatId, String sectionId) {
    if (state.containsKey(seatId)) {
      final updated = Map<String, String>.from(state)..remove(seatId);
      state = updated;
    } else {
      state = {...state, seatId: sectionId};
    }
  }

  void selectMultiple(Map<String, String> seats) {
    state = {...state, ...seats};
  }

  void deselectMultiple(Iterable<String> seatIds) {
    final updated = Map<String, String>.from(state);
    for (final id in seatIds) {
      updated.remove(id);
    }
    state = updated;
  }

  void clearSelection() {
    state = {};
  }
}

final selectedSeatsProvider =
    NotifierProvider<SelectedSeatsNotifier, Map<String, String>>(
      SelectedSeatsNotifier.new,
    );

/// Seat action notifier for CRUD
class SeatActionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> updateSeat(String sectionId, SeatModel seat) async {
    state = true;
    try {
      final libId = ref.read(currentLibraryIdProvider) ?? '';
      await ref.read(seatRepositoryProvider).updateSeat(libId, sectionId, seat);
    } finally {
      state = false;
    }
  }

  Future<void> createSection(SectionModel section) async {
    state = true;
    try {
      final libId = ref.read(currentLibraryIdProvider) ?? '';
      await ref
          .read(seatRepositoryProvider)
          .createSection(libraryId: libId, section: section);
    } finally {
      state = false;
    }
  }

  Future<void> deleteSection(String sectionId) async {
    state = true;
    try {
      final libId = ref.read(currentLibraryIdProvider) ?? '';
      await ref.read(seatRepositoryProvider).deleteSection(libId, sectionId);
    } finally {
      state = false;
    }
  }
}

final seatActionProvider = NotifierProvider<SeatActionNotifier, bool>(
  SeatActionNotifier.new,
);
