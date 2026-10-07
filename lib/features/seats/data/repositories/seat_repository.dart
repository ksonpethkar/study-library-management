import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';

import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/seat_model.dart';

class SeatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // CRUD for sections
  Future<void> createSection({
    required String libraryId,
    required SectionModel section,
    SeatNamingStyle namingStyle = SeatNamingStyle.alphanumeric,
    int startNumber = 1,
    String customPrefix = 'CAB',
    int? totalSeats,
  }) async {
    try {
      final nameCheck = section.name.trim().toLowerCase();
      final existingSections = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .get();
      for (final doc in existingSections.docs) {
        if ((doc.data()['name'] ?? '').toString().trim().toLowerCase() ==
            nameCheck) {
          throw Exception("A section with this name already exists.");
        }
      }

      final batch = _firestore.batch();

      // Auto-generate ID if empty
      final sectionRef = section.id.isEmpty
          ? _firestore
                .collection(FirestorePaths.libraries)
                .doc(libraryId)
                .collection(FirestorePaths.sections)
                .doc()
          : _firestore
                .collection(FirestorePaths.libraries)
                .doc(libraryId)
                .collection(FirestorePaths.sections)
                .doc(section.id);

      final sectionId = sectionRef.id;
      final newSection = section.copyWith(id: sectionId, libraryId: libraryId);
      batch.set(sectionRef, newSection.toJson());

      // Auto-generate seat documents based on layout and exact totalSeats
      final limit = totalSeats ?? (section.rows * section.cols);
      int count = 0;

      outerLoop:
      for (int r = 0; r < section.rows; r++) {
        for (int c = 0; c < section.cols; c++) {
          if (count >= limit) break outerLoop;

          final seatId = '${sectionId}_r${r}_c$c';
          final seatRef = sectionRef
              .collection(FirestorePaths.seats)
              .doc(seatId);

          String label;
          switch (namingStyle) {
            case SeatNamingStyle.alphanumeric:
              label = '${String.fromCharCode(65 + r)}${c + 1}'; // A1, A2
              break;
            case SeatNamingStyle.numeric:
              label = '${startNumber + count}'; // Continuous: 1, 2, 3...
              break;
            case SeatNamingStyle.customPrefix:
              final idx = count + 1;
              final p = customPrefix.trim().isNotEmpty
                  ? customPrefix.trim().toUpperCase()
                  : 'CAB';
              label = '$p-${idx.toString().padLeft(2, '0')}'; // CAB-01, CAB-02
              break;
            case SeatNamingStyle.sectionPrefixAlphanumeric:
              final sCode = section.name.isNotEmpty
                  ? section.name.trim().substring(0, 1).toUpperCase()
                  : 'S';
              label =
                  '$sCode-${String.fromCharCode(65 + r)}${c + 1}'; // S-A1, S-A2
              break;
          }

          final seat = SeatModel(
            id: seatId,
            sectionId: sectionId,
            label: label,
            row: r,
            col: c,
            status: SeatStatus.available,
            genderRestriction: GenderRestriction.any,
          );

          batch.set(seatRef, seat.toJson());
          count++;
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to create section: $e');
    }
  }

  Future<void> updateSection({
    required String libraryId,
    required SectionModel section,
  }) async {
    try {
      final nameCheck = section.name.trim().toLowerCase();
      final existingSections = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .get();
      for (final doc in existingSections.docs) {
        if (doc.id != section.id &&
            (doc.data()['name'] ?? '').toString().trim().toLowerCase() ==
                nameCheck) {
          throw Exception("A section with this name already exists.");
        }
      }

      final sectionRef = _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(section.id);

      await sectionRef.update(section.toJson());
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update section. Please try again.');
    }
  }

  Future<void> deleteSection(String libraryId, String sectionId) async {
    try {
      // Check for occupied seats first
      final occupiedSnapshot = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .collection(FirestorePaths.seats)
          .where('status', isEqualTo: SeatStatus.occupied.name)
          .limit(1)
          .get();

      if (occupiedSnapshot.docs.isNotEmpty) {
        throw Exception(
          'Cannot delete section. There are occupied seats. Please transfer students first.',
        );
      }

      // Fetch the section document
      final sectionRef = _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId);
      final sectionDoc = await sectionRef.get();

      if (!sectionDoc.exists) return;

      // Fetch all child seats to delete them
      final seatsSnapshot = await sectionRef
          .collection(FirestorePaths.seats)
          .get();

      final batch = _firestore.batch();

      // Soft delete -> move to library-scoped recycle bin
      final recycleBinRef = _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.recycleBin)
          .doc(sectionId);

      batch.set(recycleBinRef, {
        if (sectionDoc.data() != null) ...sectionDoc.data()!,
        'deletedAt': FieldValue.serverTimestamp(),
        'type': 'section',
        'libraryId': libraryId,
      });

      // Delete all child seats
      for (final sDoc in seatsSnapshot.docs) {
        batch.delete(sDoc.reference);
      }

      // Delete section document
      batch.delete(sectionRef);
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting section: $e');
      throw Exception(
        e.toString().contains('Cannot delete')
            ? e.toString().replaceAll('Exception: ', '')
            : 'Failed to delete section: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  Future<void> duplicateSection({
    required String libraryId,
    required String sourceSectionId,
    required String newSectionName,
  }) async {
    try {
      final sourceSectionDoc = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sourceSectionId)
          .get();

      if (!sourceSectionDoc.exists) {
        throw Exception('Source section not found.');
      }

      final sourceSection = SectionModel.fromJson({
        ...sourceSectionDoc.data()!,
        'id': sourceSectionDoc.id,
      });

      final newSection = sourceSection.copyWith(
        id: _firestore.collection(FirestorePaths.sections).doc().id,
        name: newSectionName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await createSection(libraryId: libraryId, section: newSection);
    } catch (e) {
      throw Exception('Failed to duplicate section. Please try again.');
    }
  }

  Future<void> toggleSectionActive(
    String libraryId,
    String sectionId,
    bool isActive,
  ) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .update({'isActive': isActive});
    } catch (e) {
      throw Exception('Failed to change section status.');
    }
  }

  // CRUD for seats
  Future<void> updateSeat(
    String libraryId,
    String sectionId,
    SeatModel seat,
  ) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .collection(FirestorePaths.seats)
          .doc(seat.id)
          .update(seat.toJson());
    } catch (e) {
      throw Exception('Failed to update seat.');
    }
  }

  Future<void> updateSeatStatus(
    String libraryId,
    String sectionId,
    String seatId,
    SeatStatus status,
  ) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .collection(FirestorePaths.seats)
          .doc(seatId)
          .update({
            'status': status.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to update seat status.');
    }
  }

  Future<void> updateSeatLabel(
    String libraryId,
    String sectionId,
    String seatId,
    String newLabel,
  ) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .collection(FirestorePaths.seats)
          .doc(seatId)
          .update({
            'label': newLabel.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to rename seat.');
    }
  }

  Future<void> assignGender(
    String libraryId,
    String sectionId,
    String seatId,
    GenderRestriction gender,
  ) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .collection(FirestorePaths.seats)
          .doc(seatId)
          .update({
            'genderRestriction': gender.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to assign gender to seat.');
    }
  }

  Future<void> assignStudent(
    String libraryId,
    String sectionId,
    String seatId,
    String studentId,
  ) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(sectionId)
          .collection(FirestorePaths.seats)
          .doc(seatId)
          .update({
            'status': SeatStatus.occupied.name,
            'studentId': studentId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to assign student to seat.');
    }
  }

  Future<void> transferStudent(
    String libraryId,
    String fromSectionId,
    String fromSeatId,
    String toSectionId,
    String toSeatId,
    String studentId,
  ) async {
    try {
      final batch = _firestore.batch();

      final fromSeatRef = _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(fromSectionId)
          .collection(FirestorePaths.seats)
          .doc(fromSeatId);

      final toSeatRef = _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(toSectionId)
          .collection(FirestorePaths.seats)
          .doc(toSeatId);

      batch.update(fromSeatRef, {
        'status': SeatStatus.available.name,
        'studentId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(toSeatRef, {
        'status': SeatStatus.occupied.name,
        'studentId': studentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to transfer student.');
    }
  }

  Future<void> bulkUpdateStatus(
    String libraryId,
    String sectionId,
    List<String> seatIds,
    SeatStatus status,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final seatId in seatIds) {
        final seatRef = _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.sections)
            .doc(sectionId)
            .collection(FirestorePaths.seats)
            .doc(seatId);

        batch.update(seatRef, {
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update seats status in bulk.');
    }
  }

  Future<void> bulkAssignGender(
    String libraryId,
    String sectionId,
    List<String> seatIds,
    GenderRestriction gender,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final seatId in seatIds) {
        final seatRef = _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.sections)
            .doc(sectionId)
            .collection(FirestorePaths.seats)
            .doc(seatId);

        batch.update(seatRef, {
          'genderRestriction': gender.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to assign gender in bulk.');
    }
  }

  Future<void> bulkDeleteSeats(
    String libraryId,
    String sectionId,
    List<String> seatIds,
  ) async {
    try {
      for (final seatId in seatIds) {
        final seatDoc = await _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.sections)
            .doc(sectionId)
            .collection(FirestorePaths.seats)
            .doc(seatId)
            .get();

        if (seatDoc.exists &&
            seatDoc.data()?['status'] == SeatStatus.occupied.name) {
          throw Exception(
            'Cannot delete occupied seats. Please clear them first.',
          );
        }
      }

      final batch = _firestore.batch();

      for (final seatId in seatIds) {
        final seatRef = _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.sections)
            .doc(sectionId)
            .collection(FirestorePaths.seats)
            .doc(seatId);

        batch.delete(seatRef);
      }

      await batch.commit();
    } catch (e) {
      throw Exception(
        e.toString().contains('Cannot delete')
            ? e.toString()
            : 'Failed to delete seats.',
      );
    }
  }

  Stream<List<SectionModel>> getSections(String libraryId) {
    return _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.sections)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map(
                (doc) => SectionModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList();
          list.sort((a, b) {
            final orderComp = a.order.compareTo(b.order);
            if (orderComp != 0) return orderComp;
            return a.createdAt.compareTo(b.createdAt);
          });
          return list;
        });
  }

  /// Updates the display order of sections in batch.
  Future<void> reorderSections(String libraryId, List<String> sectionIds) async {
    try {
      final batch = _firestore.batch();
      for (int i = 0; i < sectionIds.length; i++) {
        final docRef = _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.sections)
            .doc(sectionIds[i]);
        batch.update(docRef, {
          'order': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to reorder sections.');
    }
  }

  Stream<List<SeatModel>> getSeats(String libraryId, String sectionId) {
    return _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.sections)
        .doc(sectionId)
        .collection(FirestorePaths.seats)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SeatModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
        });
  }

  Future<List<SeatModel>> getSeatsOnce(
    String libraryId,
    String sectionId,
  ) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.sections)
        .doc(sectionId)
        .collection(FirestorePaths.seats)
        .get();
    return snapshot.docs
        .map((doc) => SeatModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Stream<List<SeatModel>> getAvailableSeats(
    String libraryId, {
    GenderRestriction? gender,
  }) async* {
    Query query = _firestore
        .collectionGroup(FirestorePaths.seats)
        .where('libraryId', isEqualTo: libraryId)
        .where('status', isEqualTo: SeatStatus.available.name);

    if (gender != null) {
      query = query.where('genderRestriction', isEqualTo: gender.name);
    }

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => SeatModel.fromJson({
              ...doc.data() as Map<String, dynamic>,
              'id': doc.id,
            }),
          )
          .toList();
    });
  }

  Future<Map<String, int>> getOccupancyCount(String libraryId) async {
    try {
      // Get all sections first
      final sectionsSnapshot = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .get();

      int total = 0;
      int occupied = 0;
      int available = 0;

      // For each section, count seats
      for (var sectionDoc in sectionsSnapshot.docs) {
        final seatsSnapshot = await _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.sections)
            .doc(sectionDoc.id)
            .collection(FirestorePaths.seats)
            .get();

        total += seatsSnapshot.docs.length;
        for (var seatDoc in seatsSnapshot.docs) {
          final status = seatDoc.data()['status'];
          if (status == SeatStatus.occupied.name) {
            occupied++;
          } else if (status == SeatStatus.available.name) {
            available++;
          }
        }
      }

      return {'total': total, 'occupied': occupied, 'available': available};
    } catch (e) {
      return {'total': 0, 'occupied': 0, 'available': 0};
    }
  }
}
