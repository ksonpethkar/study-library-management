import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/models/waiting_list_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/services/app_notification_service.dart';

class WaitingListPromotionService {
  final FirebaseFirestore _firestore;

  WaitingListPromotionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Find the top candidate in the waiting list matching section and gender criteria
  Future<WaitingListEntry?> findNextEligibleCandidate({
    required String libraryId,
    required String sectionId,
    String? seatGender,
  }) async {
    try {
      final snap = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.waitingList)
          .orderBy('createdAt')
          .get();

      final entries = snap.docs
          .map((d) => WaitingListEntry.fromJson({...d.data(), 'id': d.id}))
          .toList();

      for (final entry in entries) {
        // Section preference check: matches if null, empty, or equals sectionId
        final sectionMatches = entry.preferredSectionId == null ||
            entry.preferredSectionId!.isEmpty ||
            entry.preferredSectionId == sectionId;

        if (!sectionMatches) continue;

        // Gender preference check: if seat has specific gender, candidate should match or have 'none'
        if (seatGender != null &&
            seatGender.isNotEmpty &&
            seatGender != 'none' &&
            seatGender != 'any') {
          if (entry.genderPreference != 'none' &&
              entry.genderPreference != seatGender) {
            continue;
          }
        }

        return entry; // FIFO top match
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error finding eligible waiting list candidate: $e');
    }
    return null;
  }

  /// Assign a candidate from the waiting list to a freed seat
  Future<void> assignSeatToCandidate({
    required String libraryId,
    required WaitingListEntry entry,
    required String sectionId,
    required String seatId,
    required String seatLabel,
  }) async {
    final libRef = _firestore.collection(FirestorePaths.libraries).doc(libraryId);
    final seatRef = libRef
        .collection(FirestorePaths.sections)
        .doc(sectionId)
        .collection(FirestorePaths.seats)
        .doc(seatId);
    final waitRef = libRef.collection(FirestorePaths.waitingList).doc(entry.id);
    final auditRef = libRef.collection(FirestorePaths.auditLog).doc();

    String studentDocId = entry.studentId;
    final newStudentRef =
        studentDocId.isEmpty ? libRef.collection(FirestorePaths.students).doc() : null;
    if (studentDocId.isEmpty) {
      studentDocId = newStudentRef!.id;
    }
    final studentRef = libRef.collection(FirestorePaths.students).doc(studentDocId);

    // Atomic Transaction: Guarantee zero collisions during promotion
    await _firestore.runTransaction((tx) async {
      // 1. READS FIRST
      final seatSnap = await tx.get(seatRef);
      if (!seatSnap.exists) {
        throw Exception('Target seat does not exist.');
      }
      final seatData = seatSnap.data() ?? {};
      final currentOccupant = seatData['studentId'] as String?;
      final currentStatus = seatData['status'] as String?;

      if (currentStatus == SeatStatus.occupied.name &&
          currentOccupant != null &&
          currentOccupant.isNotEmpty &&
          currentOccupant != studentDocId) {
        throw Exception('Seat is already occupied by another student.');
      }

      // 2. WRITES
      if (newStudentRef != null) {
        tx.set(newStudentRef, {
          'id': studentDocId,
          'libraryId': libraryId,
          'name': entry.studentName,
          'phone': entry.studentPhone,
          'seatId': seatId,
          'sectionId': sectionId,
          'membershipStatus': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(studentRef, {
          'seatId': seatId,
          'sectionId': sectionId,
          'membershipStatus': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      tx.update(seatRef, {
        'status': SeatStatus.occupied.name,
        'studentId': studentDocId,
        'studentName': entry.studentName,
        'reservationType': null,
        'reservedCandidateId': null,
        'reservedCandidateName': null,
        'reservationExpiresAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.delete(waitRef);

      tx.set(auditRef, {
        'action': 'waiting_list_promoted',
        'entityType': 'seat',
        'entityId': seatId,
        'userId': 'admin_promotion_pipeline',
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'candidateName': entry.studentName,
          'candidatePhone': entry.studentPhone,
          'seatLabel': seatLabel,
          'sectionId': sectionId,
          'operation': 'Waiting List Promotion (Atomic Transaction)',
        },
      });
    });
  }

  /// Automated 2-hour reservation hold placed on a vacated seat for candidate #1
  Future<void> holdSeatForCandidate({
    required String libraryId,
    required WaitingListEntry entry,
    required String sectionId,
    required String seatId,
    required String seatLabel,
    String? libraryName,
    int holdHours = 2,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(Duration(hours: holdHours));
    final libRef = _firestore.collection(FirestorePaths.libraries).doc(libraryId);
    final seatRef = libRef
        .collection(FirestorePaths.sections)
        .doc(sectionId)
        .collection(FirestorePaths.seats)
        .doc(seatId);
    final waitRef = libRef.collection(FirestorePaths.waitingList).doc(entry.id);
    final auditRef = libRef.collection(FirestorePaths.auditLog).doc();

    // Atomic Transaction: Guarantee candidate hold does not overwrite active seat
    await _firestore.runTransaction((tx) async {
      // 1. READS FIRST
      final seatSnap = await tx.get(seatRef);
      if (!seatSnap.exists) {
        throw Exception('Seat does not exist.');
      }
      final sData = seatSnap.data() ?? {};
      final currentStatus = sData['status'] as String?;
      final currentOccupant = sData['studentId'] as String?;
      if (currentStatus == SeatStatus.occupied.name &&
          currentOccupant != null &&
          currentOccupant.isNotEmpty) {
        throw Exception('Cannot place hold: Seat is currently occupied.');
      }

      // 2. WRITES
      tx.update(seatRef, {
        'status': SeatStatus.reserved.name,
        'reservationType': 'waitlist_hold',
        'reservedCandidateId': entry.id,
        'reservedCandidateName': entry.studentName,
        'reservationExpiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(waitRef, {
        'status': 'offered',
        'offeredSeatId': seatId,
        'offeredSectionId': sectionId,
        'offeredSeatLabel': seatLabel,
        'reservationExpiresAt': Timestamp.fromDate(expiresAt),
        'notifiedAt': FieldValue.serverTimestamp(),
      });

      tx.set(auditRef, {
        'action': 'waiting_list_hold_placed',
        'entityType': 'seat',
        'entityId': seatId,
        'userId': 'system_automation',
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'candidateId': entry.id,
          'candidateName': entry.studentName,
          'candidatePhone': entry.studentPhone,
          'seatLabel': seatLabel,
          'sectionId': sectionId,
          'holdHours': holdHours,
          'expiresAt': expiresAt.toIso8601String(),
          'operation': 'Waitlist Hold Placed (Atomic Transaction)',
        },
      });
    });

    // 4. Notify admin via in-app alert
    await AppNotificationService.sendNotification(
      libraryId: libraryId,
      title: '⏳ 2-Hour Waitlist Hold: Seat $seatLabel',
      body: 'Seat $seatLabel is held for 2 hours for ${entry.studentName}. Awaiting confirmation.',
      type: 'seat',
      targetRole: 'admin',
      actionRoute: '/admin/students?filter=waiting',
      metadata: {
        'candidateId': entry.id,
        'candidateName': entry.studentName,
        'candidatePhone': entry.studentPhone,
        'seatId': seatId,
        'seatLabel': seatLabel,
        'sectionId': sectionId,
        'expiresAt': expiresAt.toIso8601String(),
      },
    );
  }

  /// Scans for expired 2-hour holds and cascades to candidate #2
  Future<int> checkAndCascadeExpiredHolds(String libraryId) async {
    final now = DateTime.now();
    int cascadedCount = 0;

    try {
      final libRef = _firestore.collection(FirestorePaths.libraries).doc(libraryId);
      final expiredWaitlistSnap = await libRef
          .collection(FirestorePaths.waitingList)
          .where('status', isEqualTo: 'offered')
          .get();

      for (final doc in expiredWaitlistSnap.docs) {
        final data = doc.data();
        final rawExp = data['reservationExpiresAt'];
        DateTime? expiresAt;
        if (rawExp is Timestamp) {
          expiresAt = rawExp.toDate();
        } else if (rawExp is String) {
          expiresAt = DateTime.tryParse(rawExp);
        }

        if (expiresAt != null && now.isAfter(expiresAt)) {
          // Hold expired!
          final seatId = data['offeredSeatId'] as String?;
          final sectionId = data['offeredSectionId'] as String?;
          final seatLabel = data['offeredSeatLabel'] as String? ?? seatId ?? '';

          // Mark current candidate as offer_expired
          await doc.reference.update({
            'status': 'offer_expired',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Cascade to candidate #2
          if (sectionId != null && seatId != null) {
            final nextCandidate = await findNextEligibleCandidate(
              libraryId: libraryId,
              sectionId: sectionId,
            );

            if (nextCandidate != null) {
              await holdSeatForCandidate(
                libraryId: libraryId,
                entry: nextCandidate,
                sectionId: sectionId,
                seatId: seatId,
                seatLabel: seatLabel,
              );
              cascadedCount++;
            } else {
              // No more candidates on waitlist, release seat back to available
              final seatRef = libRef
                  .collection(FirestorePaths.sections)
                  .doc(sectionId)
                  .collection(FirestorePaths.seats)
                  .doc(seatId);

              await seatRef.update({
                'status': SeatStatus.available.name,
                'reservationType': FieldValue.delete(),
                'reservedCandidateId': FieldValue.delete(),
                'reservedCandidateName': FieldValue.delete(),
                'reservationExpiresAt': FieldValue.delete(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking and cascading expired holds: $e');
    }

    return cascadedCount;
  }

  /// Launch WhatsApp with candidate notification message
  static Future<bool> launchWhatsAppNotification({
    required WaitingListEntry entry,
    required String seatLabel,
    required String libraryName,
    int holdHours = 2,
  }) async {
    final cleanPhone = entry.studentPhone.replaceAll(RegExp(r'\D'), '');
    final withCode = cleanPhone.startsWith('91') || cleanPhone.length > 10
        ? cleanPhone
        : '91$cleanPhone';

    final message =
        'Hello ${entry.studentName}, exciting news! 💺 Seat #$seatLabel has just become available for you at $libraryName! We have placed a priority $holdHours-hour reservation hold on this desk for you. Please confirm your admission within $holdHours hours to secure this desk.';

    final uri = Uri.parse('https://wa.me/$withCode?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Automated background handler called when membership automation releases seats
  Future<WaitingListEntry?> handleSeatReleaseCascade({
    required String libraryId,
    required String sectionId,
    required String seatId,
    required String seatLabel,
    String? libraryName,
  }) async {
    final candidate = await findNextEligibleCandidate(
      libraryId: libraryId,
      sectionId: sectionId,
    );

    if (candidate != null) {
      await holdSeatForCandidate(
        libraryId: libraryId,
        entry: candidate,
        sectionId: sectionId,
        seatId: seatId,
        seatLabel: seatLabel,
        libraryName: libraryName,
      );
    }

    return candidate;
  }
}

final waitingListPromotionServiceProvider = Provider<WaitingListPromotionService>((ref) {
  return WaitingListPromotionService();
});
