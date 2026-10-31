import 'package:cloud_firestore/cloud_firestore.dart';

class AdminWhitelistService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _whitelistRef =
      _firestore.collection('admin_whitelist');

  /// Compile-time fallback — only used if Firestore app_config is unreachable.
  /// In production, master admin emails are read from Firestore app_config/default.
  static const Set<String> _fallbackMasterEmails = {
    'ksonpethkar@gmail.com',
    'thecozycornersc@gmail.com',
  };

  /// Cached master admin emails (loaded once from Firestore).
  static Set<String>? _cachedMasterEmails;

  /// Load master admin emails from Firestore app_config, falling back to compile-time set.
  static Future<Set<String>> _getMasterEmails() async {
    if (_cachedMasterEmails != null) return _cachedMasterEmails!;
    try {
      final doc = await _firestore.collection('app_config').doc('default').get();
      if (doc.exists && doc.data()?['masterAdminEmails'] != null) {
        final list = (doc.data()!['masterAdminEmails'] as List)
            .map((e) => e.toString().trim().toLowerCase())
            .toSet();
        if (list.isNotEmpty) {
          _cachedMasterEmails = list;
          return list;
        }
      }
    } catch (_) { /* intentionally silent */ }
    _cachedMasterEmails = _fallbackMasterEmails;
    return _fallbackMasterEmails;
  }

  /// Check if an email is authorized to act as or create an admin account.
  static Future<bool> isEmailWhitelisted(String? email) async {
    if (email == null || email.trim().isEmpty) return false;
    final normalized = email.trim().toLowerCase();

    // 0. Primary master admin failsafe (loaded from Firestore app_config)
    final masterEmails = await _getMasterEmails();
    if (masterEmails.contains(normalized)) {
      return true;
    }

    try {
      // 1. Direct check in admin_whitelist collection
      final doc = await _whitelistRef.doc(normalized).get();
      if (doc.exists && (doc.data()?['isActive'] ?? true) == true) {
        return true;
      }

      // 1b. Check if email matches the default library email
      final libDoc = await _firestore.collection('libraries').limit(1).get();
      if (libDoc.docs.isNotEmpty) {
        final libEmail = (libDoc.docs.first.data()['email'] as String?)?.trim().toLowerCase();
        if (libEmail != null && libEmail.isNotEmpty && libEmail == normalized) {
          return true;
        }
      } else {
        // 2. If 0 libraries exist in the entire database, allow the first user to set up the system.
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
