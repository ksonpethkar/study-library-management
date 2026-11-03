import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  /// Checks if the currently authenticated user is an enrolled student in the default library.
  /// If so, cleanses any accidental admin role or test library ownership, updates
  /// Firestore and local storage, points providers to defaultLibraryId, and switches to student mode.
  /// 
  /// Returns `true` if the user was healed/switched to student, `false` otherwise.
  static Future<bool> healEnrolledStudentRole(
    WidgetRef ref,
    BuildContext context, {
    bool navigate = true,
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

    // 3. Enrolled student check in default library
    DocumentSnapshot? studentDoc;
    try {
      // 3a. Search by userId
      final byUid = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(defaultLibId)
          .collection('students')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (byUid.docs.isNotEmpty) {
        studentDoc = byUid.docs.first;
      } else if (email.isNotEmpty) {
        // 3b. Search by email
        final byEmail = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(defaultLibId)
            .collection('students')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          studentDoc = byEmail.docs.first;
        }
      }

      // 3c. Fallback: Search across collectionGroup('students') if not in defaultLibId
      if (studentDoc == null) {
        final groupDocs = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (groupDocs.docs.isNotEmpty) {
          studentDoc = groupDocs.docs.first;
        } else if (email.isNotEmpty) {
          final groupEmailDocs = await FirebaseFirestore.instance
              .collectionGroup('students')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (groupEmailDocs.docs.isNotEmpty) {
            studentDoc = groupEmailDocs.docs.first;
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthRoleService] Error checking student records: $e');
    }

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
            await doc.reference.update({'ownerId': 'quarantined_test_owner'}).catchError((_) {});
          }
        }

        // Update Firestore users collection
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'role': AppUserRole.student.name,
          'libraryId': effectiveLibId,
          'email': email,
          'displayName': user.displayName ?? '',
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

        if (showFeedback && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Switched to Student Portal successfully! 🎓'),
              backgroundColor: Colors.teal,
              duration: Duration(seconds: 2),
            ),
          );
        }

        if (navigate && context.mounted) {
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
