import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/staff_model.dart';
import 'package:study_library/features/staff/data/repositories/staff_repository.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository();
});

/// Streams all staff/admin members for the current active library
final staffListStreamProvider = StreamProvider<List<StaffModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) return Stream.value([]);
  final repo = ref.watch(staffRepositoryProvider);
  return repo.streamStaff(libraryId);
});

/// Streams permissions for the current logged-in user in the active library
final currentUserStaffProvider = StreamProvider<StaffModel?>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  final library = ref.watch(currentLibraryProvider).value;
  final user = FirebaseAuth.instance.currentUser;

  if (libraryId == null || libraryId.isEmpty || user == null) {
    return Stream.value(null);
  }

  // If user is the library owner, grant full Owner permissions
  if (library != null && library.ownerId == user.uid) {
    return Stream.value(StaffModel.defaultForRole(
      id: 'owner_${user.uid}',
      libraryId: libraryId,
      userId: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? 'Owner',
      role: StaffRole.owner,
    ));
  }

  // Otherwise, stream staff doc by userId or email
  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('staff')
      .where('email', isEqualTo: user.email?.toLowerCase())
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isNotEmpty) {
      return StaffModel.fromJson({...snapshot.docs.first.data(), 'id': snapshot.docs.first.id});
    }
    return null;
  });
});

// ── Derived Permission Providers ────────────────────────────────────────────
// Each returns true when the current user has the specific permission.
// Owners always receive all permissions = true.
// Unknown users (null staff) default to false for destructive actions,
// and true for read-only/data entry to avoid locking out admins during setup.

/// Can view revenue dashboard and financial data.
final canViewRevenueProvider = Provider<bool>((ref) {
  final staff = ref.watch(currentUserStaffProvider).value;
  if (staff == null) return true; // owner / pre-load: allow
  return staff.canViewRevenue;
});

/// Can add, edit, or change student records.
final canManageStudentsProvider = Provider<bool>((ref) {
  final staff = ref.watch(currentUserStaffProvider).value;
  if (staff == null) return true;
  return staff.canManageStudents;
});

/// Can permanently delete a student (destructive).
final canDeleteStudentsProvider = Provider<bool>((ref) {
  final staff = ref.watch(currentUserStaffProvider).value;
  if (staff == null) return false;
  return staff.canDeleteStudents;
});

/// Can manage seats and sections.
final canManageSeatsProvider = Provider<bool>((ref) {
  final staff = ref.watch(currentUserStaffProvider).value;
  if (staff == null) return true;
  return staff.canManageSeats;
});

/// Can record and manage payments and receipts.
final canRecordPaymentsProvider = Provider<bool>((ref) {
  final staff = ref.watch(currentUserStaffProvider).value;
  if (staff == null) return true;
  return staff.canRecordPayments;
});

/// Can access Settings screens (library profile, customizer, backup, etc.).
final canManageSettingsProvider = Provider<bool>((ref) {
  final staff = ref.watch(currentUserStaffProvider).value;
  if (staff == null) return true;
  return staff.canManageSettings;
});
