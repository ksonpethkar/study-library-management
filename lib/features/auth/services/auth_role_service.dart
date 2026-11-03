import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/auth/services/admin_whitelist_service.dart';

/// Centralized role authority service following leading SaaS membership architecture.
/// 
/// Principle of Least Privilege & Student Precedence:
/// 1. An account can ONLY be an Admin if it is explicitly on the master admin whitelist
///    or registered in the library's staff directory.
/// 2. If an account is an enrolled student in the library roster, it is ALWAYS resolved
///    as a STUDENT, overriding any accidental test organization ownership or stale admin cache.
/// 3. Orphan test libraries created during development are quarantined/disassociated so
///    they never hijack an enrolled student into an empty admin screen.
class AuthRoleService {
  /// Check if the currently authenticated user is an enrolled student.
  static Future<bool> isEnrolledStudent(dynamic ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final email = user.email?.trim().toLowerCase() ?? '';
    final defaultLibId = CurrentLibraryNotifier.defaultLibraryId;

    // Master admin whitelist — real admin
    if (email.isNotEmpty) {
      final isWhitelisted = await AdminWhitelistService.isEmailWhitelisted(email);
      if (isWhitelisted) return false;
    }

    // Staff directory check — real staff
    try {
      final staffDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(defaultLibId)
          .collection('staff')
          .doc(user.uid)
          .get();
      if (staffDoc.exists && (staffDoc.data()?['isActive'] ?? true) == true) {
        return false;
      }
    } catch (_) { /* intentionally silent */ }

    final studentDoc = await findStudentDocumentForUser(user, defaultLibId);
    return studentDoc != null;
  }

  /// Helper to locate an enrolled student record by UID, email, or phone number variants.
  static Future<DocumentSnapshot?> findStudentDocumentForUser(User user, String defaultLibId) async {
    final email = user.email?.trim().toLowerCase() ?? '';
    final rawEmail = user.email?.trim() ?? '';
    
    // Collect potential phone numbers
    final phoneVariants = <String>{};
    if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty) {
      final p = user.phoneNumber!.trim();
      phoneVariants.add(p);
      final digits = p.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        phoneVariants.add(digits.substring(digits.length - 10)); // e.g. 7385817571
        phoneVariants.add('+91${digits.substring(digits.length - 10)}');
      }
    }

    // Also check Firestore users/{uid} for phone if available
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final uData = userDoc.data();
        final uPhone = (uData?['phone'] ?? uData?['mobile'])?.toString().trim() ?? '';
        if (uPhone.isNotEmpty) {
          phoneVariants.add(uPhone);
          final digits = uPhone.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 10) {
            phoneVariants.add(digits.substring(digits.length - 10));
            phoneVariants.add('+91${digits.substring(digits.length - 10)}');
          }
        }
      }
    } catch (_) {}

    // 1. Direct search by userId in default library
    try {
      final byUid = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(defaultLibId)
          .collection('students')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (byUid.docs.isNotEmpty) return byUid.docs.first;
    } catch (_) {}

    // 2. Search by email in default library
    if (email.isNotEmpty) {
      try {
        final byEmail = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(defaultLibId)
            .collection('students')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) return byEmail.docs.first;
      } catch (_) {}

      if (rawEmail.isNotEmpty && rawEmail != email) {
        try {
          final byRawEmail = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(defaultLibId)
              .collection('students')
              .where('email', isEqualTo: rawEmail)
              .limit(1)
              .get();
          if (byRawEmail.docs.isNotEmpty) return byRawEmail.docs.first;
        } catch (_) {}
      }
    }

    // 3. Search by phone number variants in default library
    for (final phone in phoneVariants) {
      try {
        final byPhone = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(defaultLibId)
            .collection('students')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();
        if (byPhone.docs.isNotEmpty) return byPhone.docs.first;
      } catch (_) {}
    }

    // 4. Fallback search across collectionGroup('students')
    try {
      final groupUid = await FirebaseFirestore.instance
          .collectionGroup('students')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (groupUid.docs.isNotEmpty) return groupUid.docs.first;

      if (email.isNotEmpty) {
        final groupEmail = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (groupEmail.docs.isNotEmpty) return groupEmail.docs.first;
      }

      for (final phone in phoneVariants) {
        final groupPhone = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();
        if (groupPhone.docs.isNotEmpty) return groupPhone.docs.first;
      }
    } catch (_) {}

    return null;
  }

  /// Checks if the currently authenticated user is an enrolled student in the default library.
  /// If so, cleanses any accidental admin role or test library ownership, updates
  /// Firestore and local storage, points providers to defaultLibraryId, and switches to student mode.
  /// 
  /// Returns `true` if the user was healed/switched to student, `false` otherwise.
  static Future<bool> healEnrolledStudentRole(
    dynamic ref, {
    BuildContext? context,
    bool navigate = false,
    bool showFeedback = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final email = user.email?.trim().toLowerCase() ?? '';
    final defaultLibId = CurrentLibraryNotifier.defaultLibraryId;

    // 1. Master admin whitelist check — if verified master admin, never demote
    if (email.isNotEmpty) {
      final isWhitelisted = await AdminWhitelistService.isEmailWhitelisted(email);
      if (isWhitelisted) return false;
    }

    // 2. Staff directory check — if active staff member, never demote
    try {
      final staffDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(defaultLibId)
          .collection('staff')
          .doc(user.uid)
          .get();
      if (staffDoc.exists && (staffDoc.data()?['isActive'] ?? true) == true) {
        return false;
      }
    } catch (_) { /* intentionally silent */ }

    // 3. Enrolled student check
    final studentDoc = await findStudentDocumentForUser(user, defaultLibId);

    if (studentDoc != null) {
      // ── Enrolled student confirmed! Cleanse role & quarantine test libraries ──
      try {
        final effectiveLibId = studentDoc.reference.parent.parent?.id ?? defaultLibId;

        // Link userId in student document if not linked yet
        final data = studentDoc.data() as Map<String, dynamic>?;
        if (data?['userId'] != user.uid) {
          studentDoc.reference.update({'userId': user.uid}).ignore();
        }

        // Quarantine / disassociate any test libraries created during development
        final testLibs = await FirebaseFirestore.instance
            .collection('libraries')
            .where('ownerId', isEqualTo: user.uid)
            .get();
        for (final doc in testLibs.docs) {
          if (doc.id != defaultLibId) {
            await doc.reference.update({
              'ownerId': 'quarantined_test_owner',
              'quarantinedReason': 'Disassociated orphan test library - owner is student',
              'quarantinedAt': FieldValue.serverTimestamp(),
            }).catchError((_) {});
          }
        }

        // Update Firestore users collection
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'role': AppUserRole.student.name,
          'libraryId': effectiveLibId,
          'email': email,
          'displayName': user.displayName ?? (data?['name'] ?? ''),
          'phone': data?['phone'] ?? user.phoneNumber ?? '',
          'lastHealedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Overwrite SharedPreferences cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('persisted_role', AppUserRole.student.name);
        await prefs.setString('persisted_uid', user.uid);
        await prefs.setString('persisted_library_id', effectiveLibId);
        await prefs.setString('cached_current_library_id', effectiveLibId);
        await prefs.setString('cached_current_user_role', AppUserRole.student.name);

        // Update Riverpod states
        ref.read(currentLibraryIdProvider.notifier).set(effectiveLibId);
        ref.read(userRoleProvider.notifier).setRole(AppUserRole.student);

        if (showFeedback && context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Switched to Student Portal successfully! 🎓'),
              backgroundColor: Colors.teal,
              duration: Duration(seconds: 2),
            ),
          );
        }

        if (navigate && context != null && context.mounted) {
          context.go(Routes.studentHome);
        }

        return true;
      } catch (e) {
        debugPrint('[AuthRoleService] Error during student role healing: $e');
      }
    }

    return false;
  }
}
