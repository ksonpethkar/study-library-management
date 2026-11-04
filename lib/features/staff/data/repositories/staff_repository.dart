import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/models/staff_model.dart';
import 'package:study_library/features/auth/services/admin_whitelist_service.dart';

class StaffRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _staffRef(String libraryId) =>
      _firestore.collection('libraries').doc(libraryId).collection('staff');

  /// Streams all staff/admin members for a library
  Stream<List<StaffModel>> streamStaff(String libraryId) {
    return _staffRef(libraryId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return StaffModel.fromJson({...doc.data(), 'id': doc.id});
      }).toList();
    });
  }

  /// Adds a new staff member and keys by their Auth UID if known
  Future<void> addStaff(String libraryId, StaffModel staff) async {
    String targetDocId = staff.userId;
    if (targetDocId.isEmpty) {
      try {
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: staff.email.trim().toLowerCase())
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          targetDocId = userQuery.docs.first.id;
        }
      } catch (_) {}
    }

    final docRef = targetDocId.isNotEmpty ? _staffRef(libraryId).doc(targetDocId) : _staffRef(libraryId).doc();
    final newStaff = staff.copyWith(
      id: docRef.id,
      libraryId: libraryId,
      userId: targetDocId.isNotEmpty ? targetDocId : staff.userId,
    );
    await docRef.set(newStaff.toJson());

    // Only add to master admin whitelist if role is explicitly Admin (Co-Owner)
    if (staff.role == StaffRole.admin) {
      await AdminWhitelistService.addWhitelistedAdmin(
        staff.email,
        addedBy: 'library_owner',
        notes: 'Co-Admin for Library $libraryId',
      );
    }
  }

  /// Ensures a staff record is keyed by the user's Auth UID so firestore.rules
  /// getStaff(libraryId) resolves successfully.
  Future<void> ensureStaffDocKeyedByUid(String libraryId, String uid, String email) async {
    try {
      final targetRef = _staffRef(libraryId).doc(uid);
      final targetDoc = await targetRef.get();
      if (targetDoc.exists) return; // already keyed by uid

      // Find by normalized email
      final emailQuery = await _staffRef(libraryId)
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        final oldDoc = emailQuery.docs.first;
        if (oldDoc.id != uid) {
          final data = Map<String, dynamic>.from(oldDoc.data());
          data['id'] = uid;
          data['userId'] = uid;
          data['updatedAt'] = DateTime.now().toIso8601String();
          await targetRef.set(data, SetOptions(merge: true));
          await oldDoc.reference.delete().catchError((_) {});
        }
      }
    } catch (_) {}
  }

  /// Updates staff permissions and role
  Future<void> updateStaff(String libraryId, StaffModel staff) async {
    await _staffRef(libraryId).doc(staff.id).update({
      ...staff.toJson(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Removes a staff member and revokes their admin whitelist entry
  Future<void> removeStaff(String libraryId, String staffId, String email) async {
    await _staffRef(libraryId).doc(staffId).delete();
    await AdminWhitelistService.removeWhitelistedAdmin(email);
  }

  /// Fetches staff record for a specific user ID
  Future<StaffModel?> getStaffByUserId(String libraryId, String userId) async {
    final query = await _staffRef(libraryId).where('userId', isEqualTo: userId).limit(1).get();
    if (query.docs.isNotEmpty) {
      return StaffModel.fromJson({...query.docs.first.data(), 'id': query.docs.first.id});
    }
    return null;
  }
}
