import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/features/recycle_bin/data/repositories/recycle_bin_repository.dart';
import 'package:study_library/models/announcement_model.dart';
import 'package:study_library/services/app_notification_service.dart';

class AnnouncementsRepository {
  final FirebaseFirestore _firestore;

  AnnouncementsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _announcementsRef(String libraryId) =>
      _firestore.collection('libraries').doc(libraryId).collection('announcements');

  Stream<List<AnnouncementModel>> watchAnnouncements(String libraryId) {
    if (libraryId.isEmpty) return Stream.value([]);

    return _announcementsRef(libraryId).snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) {
        return AnnouncementModel.fromJson({
          ...doc.data(),
          'id': doc.id,
        });
      }).toList();

      // Sort in Dart by createdAt descending
      items.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return items;
    });
  }

  Future<void> createAnnouncement(String libraryId, AnnouncementModel announcement) async {
    final docRef = _announcementsRef(libraryId).doc();
    final data = {
      ...announcement.toJson(),
      'id': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await docRef.set(data);

    // Audit log
    try {
      await AuditLogger().log(
        action: AuditAction.created,
        entityType: AuditEntity.announcement,
        libraryId: libraryId,
        entityId: docRef.id,
        details: {'title': announcement.title, 'priority': announcement.priority.name},
      );
    } catch (_) {}

    // Broadcast in-app push/notification if urgent or general
    try {
      await AppNotificationService.sendNotification(
        libraryId: libraryId,
        title: '📢 ${announcement.title}',
        body: announcement.message,
        type: 'announcement',
        targetRole: 'student',
        actionRoute: '/student/announcements',
        metadata: {'announcementId': docRef.id},
      );
    } catch (_) {}
  }

  Future<void> updateAnnouncement(String libraryId, AnnouncementModel announcement) async {
    await _announcementsRef(libraryId).doc(announcement.id).update(announcement.toJson());

    try {
      await AuditLogger().log(
        action: AuditAction.updated,
        entityType: AuditEntity.announcement,
        libraryId: libraryId,
        entityId: announcement.id,
        details: {'title': announcement.title, 'priority': announcement.priority.name},
      );
    } catch (_) {}
  }

  Future<void> toggleActive(String libraryId, String id, bool isActive) async {
    await _announcementsRef(libraryId).doc(id).update({'isActive': isActive});
  }

  Future<void> moveToRecycleBin(String libraryId, AnnouncementModel announcement) async {
    await RecycleBinRepository().moveToRecycleBin(
      libraryId,
      'announcement',
      {
        ...announcement.toJson(),
        'id': announcement.id,
      },
    );

    await _announcementsRef(libraryId).doc(announcement.id).delete();

    try {
      await AuditLogger().log(
        action: AuditAction.deleted,
        entityType: AuditEntity.announcement,
        libraryId: libraryId,
        entityId: announcement.id,
        details: {'title': announcement.title, 'movedToRecycleBin': true},
      );
    } catch (_) {}
  }

  Future<void> markAsRead(String libraryId, String announcementId, String studentId) async {
    if (studentId.isEmpty || libraryId.isEmpty) return;
    await _announcementsRef(libraryId).doc(announcementId).update({
      'readBy': FieldValue.arrayUnion([studentId]),
    });
  }
}
