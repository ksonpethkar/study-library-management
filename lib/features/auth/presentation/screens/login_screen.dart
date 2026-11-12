import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/auth/services/admin_whitelist_service.dart';
import 'package:study_library/features/auth/services/auth_role_service.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/services/notification_service.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/features/registration/presentation/providers/registration_provider.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/core/widgets/cozy_pressable.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String _loadingStatus = 'Verifying your access…';
  String _libraryName = 'Study Library';
  String? _libraryLogoUrl;
  String? _libraryTagline = 'Smart Study Library & Co-Working Hub';

  static const String _prefLogoUrl = 'last_library_logo_url';
  static const String _prefLibName = 'last_library_name';
  static const String _prefTagline = 'last_library_tagline';

  @override
  void initState() {
    super.initState();
    // Warm up native Google Sign In in advance so first tap succeeds immediately
    ref.read(authRepositoryProvider).warmUpGoogleSignIn();
    _restoreCachedBranding(); // Show cached logo instantly
    _loadBranding();           // Then refresh from Firestore

    // Handle return from Google Sign-In redirect on Web
    if (kIsWeb) {
      FirebaseAuth.instance.getRedirectResult().then((result) {
        if (result.user != null && mounted) {
          _handleSignIn();
        }
      }).catchError((e) {
        if (kDebugMode) debugPrint('Redirect result on LoginScreen: $e');
      });
    }
  }

  /// Restore last-known branding from SharedPreferences (instant, no network).
  Future<void> _restoreCachedBranding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLogo = prefs.getString('cached_library_logo_url') ?? prefs.getString(_prefLogoUrl);
      final cachedName = prefs.getString('cached_library_name') ?? prefs.getString(_prefLibName);
      final cachedTagline = prefs.getString('cached_library_tagline') ?? prefs.getString(_prefTagline);
      if (mounted && (cachedLogo != null || cachedName != null || cachedTagline != null)) {
        setState(() {
          if (cachedLogo != null && cachedLogo.isNotEmpty) _libraryLogoUrl = cachedLogo;
          if (cachedName != null && cachedName.isNotEmpty) _libraryName = cachedName;
          if (cachedTagline != null && cachedTagline.isNotEmpty) _libraryTagline = cachedTagline;
        });
      }
    } catch (_) { /* intentionally silent */ }
  }

  Future<void> _loadBranding() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(CurrentLibraryNotifier.defaultLibraryId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final name = (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : 'Study Library';
        final logoUrl = data['logoUrl'] as String?;
        final tagline = (data['tagline'] as String?)?.trim().isNotEmpty == true
            ? data['tagline'] as String
            : (data['welcomeMessage'] as String?)?.trim().isNotEmpty == true
                ? data['welcomeMessage'] as String
                : 'Smart Study Library & Co-Working Hub';

        setState(() {
          _libraryName = name;
          _libraryLogoUrl = logoUrl;
          _libraryTagline = tagline;
        });

        // Cache to SharedPreferences so next time it shows instantly
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_library_name', name);
        await prefs.setString(_prefLibName, name);
        if (logoUrl != null && logoUrl.isNotEmpty) {
          await prefs.setString('cached_library_logo_url', logoUrl);
          await prefs.setString(_prefLogoUrl, logoUrl);
        }
        await prefs.setString('cached_library_tagline', tagline);
        await prefs.setString(_prefTagline, tagline);
      }
    } catch (_) { /* intentionally silent */ }
  }

  Future<void> _handleSignIn() async {
    if (_isLoading) return; // Guard against double-tap
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Signing in with Google…';
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();
      if (!mounted) return;

      final user = authRepo.getCurrentUser();
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _loadingStatus = 'Verifying admission records…');

      final rawEmail = user.email?.trim() ?? '';
      final normalizedEmail = rawEmail.toLowerCase();
      final defaultLibId = CurrentLibraryNotifier.defaultLibraryId;

      // ── Step 0: Priority Master Admin / Whitelist check ───────────────
      if (normalizedEmail.isNotEmpty) {
        final isWhitelisted = await AdminWhitelistService.isEmailWhitelisted(normalizedEmail)
            .timeout(const Duration(seconds: 4), onTimeout: () => false);
        if (isWhitelisted) {
          await _goAdmin(user: user, libId: defaultLibId);
          return;
        }
      }

      // ── Step 0b: Enrolled Student Precedence & Auto-Healing ─────────────
      // In professional SaaS apps (e.g. Mindbody, ClassPass), enrolled student
      // identity always takes strict precedence over orphan test workspaces.
      final wasStudentHealed = await AuthRoleService.healEnrolledStudentRole(
        ref,
        navigate: false,
      );
      if (wasStudentHealed) {
        await _goStudent(user: user, libId: defaultLibId);
        return;
      }

      // ── Step 1: Check persisted role (fastest path for returning users - 0ms if cached) ──
      final persisted = await readPersistedUserRole(user.uid)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (!mounted) return;

      if (persisted != null && persisted['role'] != null) {
        final roleStr = persisted['role'] as String;
        final libId = (persisted['libraryId'] ?? '') as String;

        if (roleStr == AppUserRole.admin.name) {
          // Strictly verify staff membership before granting admin access
          final isStaff = libId.isNotEmpty
              ? await FirebaseFirestore.instance
                  .collection('libraries').doc(libId)
                  .collection('staff').doc(user.uid).get()
                  .then((d) => d.exists && (d.data()?['isActive'] ?? true) == true, onError: (_) => false)
              : false;
          if (isStaff) {
            ref.read(currentLibraryIdProvider.notifier).set(libId);
            ref.read(userRoleProvider.notifier).setRole(AppUserRole.admin);
            if (!mounted) return;
            final isLocked = await BiometricService.isLockEnabled(isAdmin: true);
            if (!mounted) return;
            context.go(isLocked ? Routes.biometricLock : Routes.adminHome);
            return;
          }
          // Not staff or whitelisted — purge illegitimate admin role
          ref.read(userRoleProvider.notifier).clear();
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('cached_current_user_role');
          await prefs.remove('persisted_role');
          await prefs.remove('persisted_uid');
        }

        if (roleStr == AppUserRole.student.name) {
          final effectiveLibId = libId.isNotEmpty ? libId : defaultLibId;

          // Quick parallel verification of enrolled profile (strictly in students collection)
          try {
            final checkResults = await Future.wait([
              FirebaseFirestore.instance
                  .collection('libraries').doc(effectiveLibId)
                  .collection('students').where('userId', isEqualTo: user.uid)
                  .limit(1).get(),
              (normalizedEmail.isNotEmpty
                  ? FirebaseFirestore.instance
                      .collection('libraries').doc(effectiveLibId)
                      .collection('students').where('email', isEqualTo: normalizedEmail)
                      .limit(1).get()
                  : Future<QuerySnapshot?>.value(null)),
            ]).timeout(const Duration(seconds: 4));

            final studentByUid = checkResults[0];
            final studentByEmail = checkResults.length > 1 ? checkResults[1] : null;

            final validStudentDoc = (studentByUid?.docs.isNotEmpty == true)
                ? studentByUid!.docs.first
                : (studentByEmail?.docs.isNotEmpty == true ? studentByEmail!.docs.first : null);

            if (validStudentDoc != null) {
              if ((validStudentDoc.data() as Map<String, dynamic>?)?['userId'] != user.uid) {
                validStudentDoc.reference.update({'userId': user.uid}).ignore();
              }
              await _goStudent(user: user, libId: effectiveLibId);
              return;
            } else {
              // Stale or ghost role in cache — purge it immediately!
              ref.read(userRoleProvider.notifier).clear();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('cached_current_user_role');
              await prefs.remove('persisted_role');
              await prefs.remove('persisted_uid');
              await FirebaseFirestore.instance.collection('users').doc(user.uid).delete().catchError((_) {});
            }
          } catch (_) {}
        }
      }

      // ── Step 2: High-Speed Parallel Discovery (< 800ms total) ───────────
      // Run Library Owner, Local Student, Local Request, and Staff checks IN PARALLEL!
      final discoveryResults = await Future.wait<dynamic>([
        // [0] Check if user owns a library
        ref.read(libraryRepositoryProvider).getLibraryByOwnerId(user.uid)
            .timeout(const Duration(seconds: 6), onTimeout: () => null),

        // [1] Check if student is in default library by userId
        FirebaseFirestore.instance
            .collection('libraries').doc(defaultLibId)
            .collection('students').where('userId', isEqualTo: user.uid)
            .limit(1).get()
            .then<QuerySnapshot?>((v) => v, onError: (_) => null)
            .timeout(const Duration(seconds: 6), onTimeout: () => null),

        // [2] Check if student is in default library by normalized email
        (normalizedEmail.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('libraries').doc(defaultLibId)
                .collection('students').where('email', isEqualTo: normalizedEmail)
                .limit(1).get()
                .then<QuerySnapshot?>((v) => v, onError: (_) => null)
            : Future<QuerySnapshot?>.value(null))
            .timeout(const Duration(seconds: 6), onTimeout: () => null),

        // [3] Check if student is in default library by raw email (case-insensitive fallback)
        (rawEmail.isNotEmpty && rawEmail != normalizedEmail
            ? FirebaseFirestore.instance
                .collection('libraries').doc(defaultLibId)
                .collection('students').where('email', isEqualTo: rawEmail)
                .limit(1).get()
                .then<QuerySnapshot?>((v) => v, onError: (_) => null)
            : Future<QuerySnapshot?>.value(null))
            .timeout(const Duration(seconds: 6), onTimeout: () => null),

        // [4] Check if user has an existing admission request in default library by studentId
        FirebaseFirestore.instance
            .collection('libraries').doc(defaultLibId)
            .collection('requests').where('studentId', isEqualTo: user.uid)
            .limit(1).get()
            .then<QuerySnapshot?>((v) => v, onError: (_) => null)
            .timeout(const Duration(seconds: 6), onTimeout: () => null),

        // [5] Check if user has an existing admission request in default library by email
        (normalizedEmail.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('libraries').doc(defaultLibId)
                .collection('requests').where('email', isEqualTo: normalizedEmail)
                .limit(1).get()
                .then<QuerySnapshot?>((v) => v, onError: (_) => null)
            : Future<QuerySnapshot?>.value(null))
            .timeout(const Duration(seconds: 6), onTimeout: () => null),

        // [6] Check staff by email
        (normalizedEmail.isNotEmpty
            ? FirebaseFirestore.instance
                .collectionGroup('staff')
                .where('email', isEqualTo: normalizedEmail)
                .limit(1).get()
                .then<QuerySnapshot?>((v) => v, onError: (_) => null)
            : Future<QuerySnapshot?>.value(null))
            .timeout(const Duration(seconds: 6), onTimeout: () => null),
      ]).timeout(const Duration(seconds: 8), onTimeout: () => [null, null, null, null, null, null, null]);

      if (!mounted) return;

      final ownedLibrary = discoveryResults[0] as LibraryModel?;
      final studentByUid = discoveryResults[1] as QuerySnapshot?;
      final studentByNormEmail = discoveryResults[2] as QuerySnapshot?;
      final studentByRawEmail = discoveryResults[3] as QuerySnapshot?;
      final reqByUid = discoveryResults[4] as QuerySnapshot?;
      final reqByEmail = discoveryResults[5] as QuerySnapshot?;
      final staffByEmail = discoveryResults[6] as QuerySnapshot?;

      // Check Owner match (Strictly restricted to the official default library)
      if (ownedLibrary != null && ownedLibrary.id == defaultLibId) {
        await _goAdmin(user: user, libId: ownedLibrary.id);
        return;
      }

      // Check Staff match
      if (staffByEmail != null && staffByEmail.docs.isNotEmpty) {
        final staffDoc = staffByEmail.docs.first;
        final libId = staffDoc.reference.parent.parent?.id ?? defaultLibId;
        await _goAdmin(user: user, libId: libId, staffResult: staffByEmail);
        return;
      }

      // Check Student match (by UID or Email)
      final matchedStudentDoc = (studentByUid?.docs.isNotEmpty == true)
          ? studentByUid!.docs.first
          : ((studentByNormEmail?.docs.isNotEmpty == true)
              ? studentByNormEmail!.docs.first
              : ((studentByRawEmail?.docs.isNotEmpty == true)
                  ? studentByRawEmail!.docs.first
                  : null));

      if (matchedStudentDoc != null) {
        final libId = matchedStudentDoc.reference.parent.parent?.id ?? defaultLibId;
        // Link userId if it was matched by email
        if ((matchedStudentDoc.data() as Map<String, dynamic>?)?['userId'] != user.uid) {
          matchedStudentDoc.reference.update({'userId': user.uid}).ignore();
        }
        await _goStudent(user: user, libId: libId);
        return;
      }

      // Comprehensive student search by Phone / UID fallback via AuthRoleService
      final deepStudentDoc = await AuthRoleService.findStudentDocumentForUser(user, defaultLibId);
      if (deepStudentDoc != null && deepStudentDoc.exists) {
        final libId = deepStudentDoc.reference.parent.parent?.id ?? defaultLibId;
        if ((deepStudentDoc.data() as Map<String, dynamic>?)?['userId'] != user.uid) {
          deepStudentDoc.reference.update({'userId': user.uid}).ignore();
        }
        await _goStudent(user: user, libId: libId);
        return;
      }

      // Check Admission Request match (covers pending, approved, desk_payment_pending, etc.)
      final matchedReqDoc = (reqByUid?.docs.isNotEmpty == true)
          ? reqByUid!.docs.first
          : ((reqByEmail?.docs.isNotEmpty == true)
              ? reqByEmail!.docs.first
              : null);

      final reqData = matchedReqDoc?.data() as Map<String, dynamic>?;
      if (matchedReqDoc != null && reqData != null) {
        final reqStatus = (reqData['status'] ?? '').toString().toLowerCase();
        final createdStudentId = (reqData['createdStudentId'] ?? '').toString().trim();

        // 1. If request was already approved and created a student record, link UID and admit immediately!
        if (createdStudentId.isNotEmpty) {
          final studentDocRef = FirebaseFirestore.instance
              .collection('libraries')
              .doc(defaultLibId)
              .collection('students')
              .doc(createdStudentId);
          final studentDocSnap = await studentDocRef.get();
          if (studentDocSnap.exists) {
            final sData = studentDocSnap.data() ?? {};
            if (sData['userId'] != user.uid) {
              await studentDocRef.update({'userId': user.uid}).catchError((_) {});
            }
            await _goStudent(user: user, libId: defaultLibId);
            return;
          }
        }

        // 2. If request is active (pending, approved, or payment pending), admit student to portal
        if (reqStatus == 'pending' ||
            reqStatus == 'approved' ||
            reqStatus == 'desk_payment_pending' ||
            reqStatus == 'payment_pending' ||
            reqStatus.contains('pending')) {
          if (reqData['studentId'] != user.uid) {
            matchedReqDoc.reference.update({'studentId': user.uid}).ignore();
          }
          await _goStudent(user: user, libId: defaultLibId);
          return;
        }
      }

      // ── Step 3: Fast Multi-Library Fallback (collectionGroup) only if not in default library ──
      try {
        final multiLibResults = await Future.wait([
          FirebaseFirestore.instance
              .collectionGroup('students')
              .where('userId', isEqualTo: user.uid)
              .limit(1).get()
              .then<QuerySnapshot?>((v) => v, onError: (_) => null),
          if (normalizedEmail.isNotEmpty)
            FirebaseFirestore.instance
                .collectionGroup('students')
                .where('email', isEqualTo: normalizedEmail)
                .limit(1).get()
                .then<QuerySnapshot?>((v) => v, onError: (_) => null)
          else
            Future<QuerySnapshot?>.value(null),
        ]).timeout(const Duration(milliseconds: 1500));

        final globalStudentByUid = multiLibResults[0];
        final globalStudentByEmail = multiLibResults.length > 1 ? multiLibResults[1] : null;

        final globalMatch = (globalStudentByUid?.docs.isNotEmpty == true)
            ? globalStudentByUid!.docs.first
            : (globalStudentByEmail?.docs.isNotEmpty == true ? globalStudentByEmail!.docs.first : null);

        if (globalMatch != null) {
          final libId = globalMatch.reference.parent.parent?.id ?? defaultLibId;
          if ((globalMatch.data() as Map<String, dynamic>?)?['userId'] != user.uid) {
            globalMatch.reference.update({'userId': user.uid}).ignore();
          }
          await _goStudent(user: user, libId: libId);
          return;
        }
      } catch (_) {}

      // ── Step 4: No admission record found — Show dialog immediately! (NO ghost student write!) ──
      // Clean up session and cached roles so no unauthenticated student state exists
      await FirebaseAuth.instance.signOut();
      ref.read(userRoleProvider.notifier).clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_current_user_role');
      await prefs.remove('persisted_role');
      await prefs.remove('persisted_uid');

      if (!mounted) return;
      await _showAccountNotFoundDialog(user);
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'auth');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAccountNotFoundDialog(User user) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_search_rounded, color: Colors.brown, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Account Not Found', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No registered admission profile was found for:\n${user.email ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'If you are a new student looking to enroll, please submit a new admission registration application.',
              style: TextStyle(height: 1.4, fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              ref.read(userRoleProvider.notifier).clear();
            },
            child: const Text('Sign in with Another Email'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _startNewRegistration(user);
            },
            icon: const Icon(Icons.assignment_ind_rounded),
            label: const Text('Register New Admission'),
          ),
        ],
      ),
    );
  }

  void _startNewRegistration(User? user) {
    ref.read(currentLibraryIdProvider.notifier).set(CurrentLibraryNotifier.defaultLibraryId);
    ref.read(registrationStepProvider.notifier).reset();
    if (user != null) {
      ref.read(registrationNotifierProvider.notifier).updateFields({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
      });
    }
    context.push(Routes.studentRegister);
  }

  Future<void> _handleNewStudentRegisterClick() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _startNewRegistration(user);
      return;
    }

    // Prompt Google sign in first
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const Icon(Icons.assignment_ind_rounded, size: 48, color: Colors.brown),
              const SizedBox(height: 12),
              const Text(
                'Student Admission Registration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in with Google to quickly autofill your personal details, secure your application, and get live updates on admission approval.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: Image.network(
                    'https://www.google.com/favicon.ico',
                    width: 18, height: 18,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, size: 18),
                  ),
                  label: const Text('Continue with Google'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx, false);
                    _startNewRegistration(null);
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Fill Form Manually without Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );

    if (proceed == true) {
      setState(() => _isLoading = true);
      try {
        final authRepo = ref.read(authRepositoryProvider);
        await authRepo.signInWithGoogle();
        final signedInUser = authRepo.getCurrentUser();
        if (signedInUser != null) {
          _startNewRegistration(signedInUser);
        }
      } catch (e) {
        if (mounted) {
          AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'auth');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _goAdmin({
    required dynamic user,
    required String libId,
    QuerySnapshot? staffResult,
  }) async {
    ref.read(currentLibraryIdProvider.notifier).set(libId);
    ref.read(userRoleProvider.notifier).setRole(AppUserRole.admin);
    await persistUserRole(
      uid: user.uid as String,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      role: AppUserRole.admin,
      libraryId: libId,
    );
    AuditLogger().log(
      action: AuditAction.login,
      entityType: AuditEntity.library,
      libraryId: libId,
      details: {'email': FirebaseAuth.instance.currentUser?.email ?? ''},
    ).ignore();
    // Save FCM token and subscribe to admin topic for push notifications
    try {
      final token = await NotificationService.getToken();
      if (token != null && libId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('libraries').doc(libId)
            .update({'adminFcmToken': token, 'adminFcmUpdatedAt': FieldValue.serverTimestamp()});
      }
      // Subscribe to library-specific admin & announcement topics (no Cloud Functions needed)
      await NotificationService.subscribeToLibraryTopics(libraryId: libId, isAdmin: true);
    } catch (_) { /* intentionally silent */ }
    // Ensure staff record is keyed by user.uid so firestore.rules can evaluate isActiveStaff and staffCan
    if (libId.isNotEmpty && user.uid != null && user.email != null) {
      try {
        final repo = ref.read(staffRepositoryProvider);
        await repo.ensureStaffDocKeyedByUid(libId, user.uid as String, user.email as String);
      } catch (_) { /* intentionally silent */ }
    }
    if (!mounted) return;
    final isLocked = await BiometricService.isLockEnabled(isAdmin: true);
    if (!mounted) return;
    context.go(isLocked ? Routes.biometricLock : Routes.adminHome);
  }

  Future<void> _goStudent({
    required dynamic user,
    required String libId,
  }) async {
    final effectiveLibId =
        libId.isNotEmpty ? libId : CurrentLibraryNotifier.defaultLibraryId;
    ref.read(currentLibraryIdProvider.notifier).set(effectiveLibId);
    ref.read(userRoleProvider.notifier).setRole(AppUserRole.student);
    await persistUserRole(
      uid: user.uid as String,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      role: AppUserRole.student,
      libraryId: effectiveLibId,
    );
    AuditLogger().log(
      action: AuditAction.login,
      entityType: AuditEntity.library,
      libraryId: libId,
      details: {'email': FirebaseAuth.instance.currentUser?.email ?? ''},
    ).ignore();

    String targetStudentId = user.uid as String;
    // Save FCM token and subscribe to library topic for push notifications
    try {
      final token = await NotificationService.getToken();
      if (effectiveLibId.isNotEmpty && user.uid != null) {
        // Try to update student doc that matches this userId
        final q = await FirebaseFirestore.instance
            .collection('libraries').doc(effectiveLibId)
            .collection('students')
            .where('userId', isEqualTo: user.uid)
            .limit(1).get();
        if (q.docs.isNotEmpty) {
          targetStudentId = q.docs.first.id;
          if (token != null) {
            q.docs.first.reference.update({'fcmToken': token, 'fcmUpdatedAt': FieldValue.serverTimestamp()}).ignore();
          }
        }
      }
      // Subscribe to library-wide and student topics (receives announcements without Cloud Functions)
      await NotificationService.subscribeToLibraryTopics(libraryId: effectiveLibId, isAdmin: false);
    } catch (_) { /* intentionally silent */ }

    final authUid = user.uid as String;
    await BiometricService.restoreStudentSecurityFromFirestore(
      libraryId: effectiveLibId,
      studentId: targetStudentId,
      authUid: authUid,
      candidateIds: [targetStudentId, authUid],
    );
    final isLocked = await BiometricService.isLockEnabled(
      userId: targetStudentId,
      authUid: authUid,
      libraryId: effectiveLibId,
      candidateIds: [targetStudentId, authUid],
    );
    if (!mounted) return;
    context.go(isLocked ? Routes.biometricLock : Routes.studentHome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // App icon — dynamic org branding using ImageService (handles base64 and URLs)
                Builder(
                  builder: (context) {
                    final imageProvider = ImageService.getImageProvider(_libraryLogoUrl);
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        image: imageProvider != null
                            ? DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageProvider == null
                          ? Icon(
                              Icons.local_library_rounded,
                              size: 56,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  _libraryName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _libraryTagline ?? 'Smart Study Library & Co-Working Hub',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 56),

                // Single sign-in button — industry standard
                if (_isLoading)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _loadingStatus,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleSignIn,
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.login_rounded, size: 20),
                      ),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                // Direct Registration for New Students
                if (!_isLoading)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _handleNewStudentRegisterClick,
                      icon: const Icon(Icons.how_to_reg_rounded, size: 20),
                      label: const Text(
                        'New Student? Register Application',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Smart Unified Trust Badge (Centered & Responsive)
                // Clean Smart Portal Security Capsule (Line-by-line hierarchy)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Smart Portal Access',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Secure & Instant Sign-In',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Legal & Compliance Footer (Clean, elegant, line-by-line)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'By continuing, you agree to our',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CozyPressable(
                            onTap: () => context.push(Routes.terms),
                            pressScale: 0.95,
                            child: Text(
                              'Terms (नियम)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              '•',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          CozyPressable(
                            onTap: () => context.push(Routes.privacyPolicy),
                            pressScale: 0.95,
                            child: Text(
                              'Privacy Policy (गोपनीयता धोरण)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ).animate()
              .fadeIn(duration: 600.ms, curve: Curves.easeOut)
              .slideY(begin: 0.05, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
          ),
        ),
      ),
    ),
  );
  }
}
