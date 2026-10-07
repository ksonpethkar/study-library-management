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

  /// Adds a new staff member and automatically authorizes their email
  Future<void> addStaff(String libraryId, StaffModel staff) async {
    final docRef = _staffRef(libraryId).doc();
    final newStaff = staff.copyWith(id: docRef.id, libraryId: libraryId);
    await docRef.set(newStaff.toJson());

    // Automatically whitelist their Google email so they can log in
    await AdminWhitelistService.addWhitelistedAdmin(
      staff.email,
      addedBy: 'library_owner',
      notes: '${staff.role.name.toUpperCase()} for Library $libraryId',
    );
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
