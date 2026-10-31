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
    final batch = _firestore.batch();
    final libRef = _firestore.collection(FirestorePaths.libraries).doc(libraryId);

    // 1. If student exists, update student record; if not, create student doc
    String studentDocId = entry.studentId;
    if (studentDocId.isEmpty) {
      // Create student document
      final newStudentRef = libRef.collection(FirestorePaths.students).doc();
      studentDocId = newStudentRef.id;
      batch.set(newStudentRef, {
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
      final studentRef = libRef.collection(FirestorePaths.students).doc(studentDocId);
      batch.update(studentRef, {
        'seatId': seatId,
        'sectionId': sectionId,
        'membershipStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 2. Mark seat as occupied
    final seatRef = libRef
        .collection(FirestorePaths.sections)
        .doc(sectionId)
        .collection(FirestorePaths.seats)
        .doc(seatId);

    batch.update(seatRef, {
      'status': SeatStatus.occupied.name,
      'studentId': studentDocId,
      'studentName': entry.studentName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3. Remove entry from waiting list
    final waitRef = libRef.collection(FirestorePaths.waitingList).doc(entry.id);
    batch.delete(waitRef);

    // 4. Log audit entry
    final auditRef = libRef.collection(FirestorePaths.auditLog).doc();
    batch.set(auditRef, {
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
      },
    });

    await batch.commit();
  }

  /// Launch WhatsApp with candidate notification message
  static Future<bool> launchWhatsAppNotification({
    required WaitingListEntry entry,
    required String seatLabel,
    required String libraryName,
  }) async {
    final cleanPhone = entry.studentPhone.replaceAll(RegExp(r'\D'), '');
    final withCode = cleanPhone.startsWith('91') || cleanPhone.length > 10
        ? cleanPhone
        : '91$cleanPhone';

    final message =
        'Hello ${entry.studentName}, exciting news! Seat $seatLabel has just become available for you at $libraryName. Your position on the waiting list has arrived! Please visit or contact us to confirm your admission.';

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
  }) async {
    final candidate = await findNextEligibleCandidate(
      libraryId: libraryId,
      sectionId: sectionId,
    );

    if (candidate != null) {
      final libRef = _firestore.collection(FirestorePaths.libraries).doc(libraryId);

      // Stamp candidate with promotion suggestion
      await libRef.collection(FirestorePaths.waitingList).doc(candidate.id).update({
        'suggestedSeatId': seatId,
        'suggestedSectionId': sectionId,
        'suggestedSeatLabel': seatLabel,
        'notifiedAt': FieldValue.serverTimestamp(),
      });

      // Dispatch high priority in-app notification to Admin
      await AppNotificationService.sendNotification(
        libraryId: libraryId,
        title: 'Seat $seatLabel Available for Waitlist',
        body: '${candidate.studentName} is #1 on the waiting list for Seat $seatLabel. Tap to assign or notify candidate on WhatsApp.',
        type: 'seat',
        targetRole: 'admin',
        actionRoute: '/admin/students?filter=waiting',
        metadata: {
          'candidateId': candidate.id,
          'candidateName': candidate.studentName,
          'candidatePhone': candidate.studentPhone,
          'seatId': seatId,
          'seatLabel': seatLabel,
          'sectionId': sectionId,
        },
      );

      // Log high priority audit entry
      await libRef.collection(FirestorePaths.auditLog).add({
        'action': 'waiting_list_promotion_ready',
        'entityType': 'waiting_list',
        'entityId': candidate.id,
        'userId': 'system_automation',
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'candidateName': candidate.studentName,
          'candidatePhone': candidate.studentPhone,
          'seatLabel': seatLabel,
          'sectionId': sectionId,
          'seatId': seatId,
        },
      });
    }

    return candidate;
  }
}

final waitingListPromotionServiceProvider = Provider<WaitingListPromotionService>((ref) {
  return WaitingListPromotionService();
});
