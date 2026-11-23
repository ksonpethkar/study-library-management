import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/features/seats/data/repositories/seat_repository.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';

final seatRepositoryProvider = Provider<SeatRepository>((ref) {
  return SeatRepository();
});

final sectionsProvider = StreamProvider<List<SectionModel>>((ref) {
  final repository = ref.watch(seatRepositoryProvider);
  final libraryId = ref.watch(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
  if (libraryId.isEmpty) return Stream.value([]);
  return repository.getSections(libraryId);
});

final seatsProvider = StreamProvider.family<List<SeatModel>, String>((
  ref,
  sectionId,
) {
  final repository = ref.watch(seatRepositoryProvider);
  final libraryId = ref.watch(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
  if (libraryId.isEmpty) return Stream.value([]);
  return repository.getSeats(libraryId, sectionId);
});

final availableSeatsProvider = StreamProvider<List<SeatModel>>((ref) {
  final repository = ref.watch(seatRepositoryProvider);
  final libraryId = ref.watch(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
  if (libraryId.isEmpty) return Stream.value([]);
  return repository.getAvailableSeats(libraryId);
});

final allSeatsProvider = Provider<List<SeatModel>>((ref) {
  final sections = ref.watch(sectionsProvider).value ?? [];
  if (sections.isEmpty) return const [];

  final allSeats = <SeatModel>[];
  for (final section in sections) {
    final sectionSeats = ref.watch(seatsProvider(section.id)).value ?? [];
    allSeats.addAll(sectionSeats);
  }
  return allSeats;
});

final occupancyProvider = StreamProvider<Map<String, int>>((ref) async* {
  final libraryId = ref.watch(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
  if (libraryId.isEmpty) {
    yield {'total': 0, 'occupied': 0, 'available': 0};
    return;
  }

  final sections = ref.watch(sectionsProvider).value ?? [];
  final students = ref.watch(studentsStreamProvider).value ?? [];
  final allSeats = ref.watch(allSeatsProvider);

  if (sections.isNotEmpty) {
    final totalCapacity = sections
        .where((s) => s.isActive)
        .fold<int>(0, (sum, s) => sum + s.capacity);

    final occupiedSeatKeys = <String>{};
    final reservedSeatKeys = <String>{};
    final maintenanceSeatKeys = <String>{};

    for (final s in students) {
      if ((s.membershipStatus == MembershipStatus.active || s.membershipStatus == MembershipStatus.grace) &&
          s.seatId != null &&
          s.seatId!.isNotEmpty) {
        // Normalize seat key using SeatHelper so legacy/composite keys map consistently
        final numOnly = SeatHelper.formatSeatNumberOnly(seatId: s.seatId);
        occupiedSeatKeys.add(numOnly.isNotEmpty ? 'seat_num_$numOnly' : s.seatId!);
      }
    }
    for (final seat in allSeats) {
      final numOnly = SeatHelper.formatSeatNumberOnly(seatId: seat.id, rawLabel: seat.label);
      final key = numOnly.isNotEmpty ? 'seat_num_$numOnly' : seat.id;
      if (seat.isOccupied || (seat.studentId != null && seat.studentId!.isNotEmpty)) {
        occupiedSeatKeys.add(key);
      } else if (seat.status == SeatStatus.reserved || seat.hasActiveSoftLock) {
        reservedSeatKeys.add(key);
      } else if (seat.status == SeatStatus.maintenance) {
        maintenanceSeatKeys.add(key);
      }
    }

    final occupiedSeats = occupiedSeatKeys.length;
    final reservedSeats = reservedSeatKeys.length;
    final maintenanceSeats = maintenanceSeatKeys.length;
    final availableSeats = (totalCapacity - occupiedSeats - reservedSeats - maintenanceSeats).clamp(0, totalCapacity).toInt();

    yield {
      'total': totalCapacity,
      'occupied': occupiedSeats,
      'available': availableSeats,
      'reserved': reservedSeats,
      'maintenance': maintenanceSeats,
    };
  } else {
    // Initial / fallback count
    final fallback = await ref.watch(seatRepositoryProvider).getOccupancyCount(libraryId);
    yield fallback;
  }
});

/// Selected seats for bulk operations: maps seatId -> sectionId
class SelectedSeatsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  void toggleSelection(String seatId, String sectionId) {
    HapticFeedback.selectionClick();
    if (state.containsKey(seatId)) {
      final updated = Map<String, String>.from(state)..remove(seatId);
      state = updated;
    } else {
      state = {...state, seatId: sectionId};
    }
  }

  void selectMultiple(Map<String, String> seats) {
    HapticFeedback.selectionClick();
    state = {...state, ...seats};
  }

  void deselectMultiple(Iterable<String> seatIds) {
    HapticFeedback.selectionClick();
    final updated = Map<String, String>.from(state);
    for (final id in seatIds) {
      updated.remove(id);
    }
    state = updated;
  }

  void clearSelection() {
    state = {};
  }

  void clear() => clearSelection();
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
