import 'package:cloud_firestore/cloud_firestore.dart';

class AdminWhitelistService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _whitelistRef =
      _firestore.collection('admin_whitelist');

  /// Check if an email is authorized to act as or create an admin account.
  static Future<bool> isEmailWhitelisted(String? email) async {
    if (email == null || email.trim().isEmpty) return false;
    final normalized = email.trim().toLowerCase();

    try {
      // 1. Direct check in admin_whitelist collection
      final doc = await _whitelistRef.doc(normalized).get();
      if (doc.exists && (doc.data()?['isActive'] ?? true) == true) {
        return true;
      }

      // 2. Check if ANY library exists in Firestore.
      // If 0 libraries exist in the entire database, allow the first user to set up the system.
      final existingLibraries = await _firestore.collection('libraries').limit(1).get();
      if (existingLibraries.docs.isEmpty) {
        // Automatically add first user to whitelist
        await addWhitelistedAdmin(
          normalized,
          addedBy: 'initial_setup',
          notes: 'Master Initial Admin',
        );
        return true;
      }

      return false;
    } catch (e) {
      // If permission error or offline, fallback safely
      return false;
    }
  }

  /// Add an approved admin email
  static Future<void> addWhitelistedAdmin(
    String email, {
    required String addedBy,
    String? notes,
  }) async {
    final normalized = email.trim().toLowerCase();
    await _whitelistRef.doc(normalized).set({
      'email': normalized,
      'addedBy': addedBy,
      'notes': notes ?? '',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove or deactivate a whitelisted admin email
  static Future<void> removeWhitelistedAdmin(String email) async {
    final normalized = email.trim().toLowerCase();
    await _whitelistRef.doc(normalized).delete();
  }

  /// Stream of all whitelisted admin emails
  static Stream<List<Map<String, dynamic>>> streamWhitelistedAdmins() {
    return _whitelistRef.snapshots().map((snap) {
      return snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    });
  }
}
