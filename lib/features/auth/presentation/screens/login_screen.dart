import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/auth/services/admin_whitelist_service.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/services/notification_service.dart';
import 'package:study_library/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:study_library/features/legal/presentation/screens/terms_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String _libraryName = 'Cozy Corner';
  String? _libraryLogoUrl;
  String? _libraryTagline;

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
  }

  /// Restore last-known branding from SharedPreferences (instant, no network).
  Future<void> _restoreCachedBranding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLogo = prefs.getString(_prefLogoUrl);
      final cachedName = prefs.getString(_prefLibName);
      final cachedTagline = prefs.getString(_prefTagline);
      if (mounted && (cachedLogo != null || cachedName != null)) {
        setState(() {
          if (cachedLogo != null && cachedLogo.isNotEmpty) _libraryLogoUrl = cachedLogo;
          if (cachedName != null && cachedName.isNotEmpty) _libraryName = cachedName;
          if (cachedTagline != null) _libraryTagline = cachedTagline;
        });
      }
    } catch (_) {}
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
            : 'Cozy Corner';
        final logoUrl = data['logoUrl'] as String?;
        final tagline = data['tagline'] as String?;

        setState(() {
          _libraryName = name;
          _libraryLogoUrl = logoUrl;
          _libraryTagline = tagline;
        });

        // Cache to SharedPreferences so next time it shows instantly
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefLibName, name);
        if (logoUrl != null) await prefs.setString(_prefLogoUrl, logoUrl);
        if (tagline != null) await prefs.setString(_prefTagline, tagline);
      }
    } catch (_) {}
  }

  Future<void> _handleSignIn() async {
    if (_isLoading) return; // Guard against double-tap
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();
      if (!mounted) return;

      final user = authRepo.getCurrentUser();
      if (user == null) return;

      // ── Step 1: Check persisted role (fastest path for returning users) ──
      final persisted = await readPersistedUserRole(user.uid);
      if (!mounted) return;

      if (persisted != null && persisted['role'] != null) {
        final roleStr = persisted['role'] as String;
        final libId = (persisted['libraryId'] ?? '') as String;

        if (roleStr == AppUserRole.admin.name) {
          if (libId.isNotEmpty) {
            ref.read(currentLibraryIdProvider.notifier).set(libId);
          }
          ref.read(userRoleProvider.notifier).setRole(AppUserRole.admin);
          if (!mounted) return;
          final isLocked = await BiometricService.isLockEnabled();
          if (!mounted) return;
          context.go(isLocked ? Routes.biometricLock : Routes.adminHome);
          return;
        }

        if (roleStr == AppUserRole.student.name) {
          if (libId.isNotEmpty) {
            ref.read(currentLibraryIdProvider.notifier).set(libId);
          }
          ref.read(userRoleProvider.notifier).setRole(AppUserRole.student);
          if (!mounted) return;
          context.go(Routes.studentHome);
          return;
        }
      }

      // ── Step 2: Check if user owns a library (Admin/Owner) ─────────────
      LibraryModel? library;
      try {
        library = await ref
            .read(libraryRepositoryProvider)
            .getLibraryByOwnerId(user.uid);
      } catch (e) {
        debugPrint('Library lookup: $e');
      }
      if (!mounted) return;

      if (library != null) {
        await _goAdmin(user: user, libId: library.id);
        return;
      }

      // ── Step 3: Check if user is staff of a library ─────────────────────
      if (user.email != null && user.email!.isNotEmpty) {
        try {
          final staffDocs = await FirebaseFirestore.instance
              .collectionGroup('staff')
              .where('email', isEqualTo: user.email!.toLowerCase())
              .limit(1)
              .get();
          if (!mounted) return;
          if (staffDocs.docs.isNotEmpty) {
            final staffDoc = staffDocs.docs.first;
            final libId = staffDoc.reference.parent.parent?.id;
            if (libId != null && libId.isNotEmpty) {
              await _goAdmin(user: user, libId: libId, staffResult: staffDocs);
              return;
            }
          }
        } catch (e) {
          debugPrint('Staff lookup: $e');
        }
      }
      if (!mounted) return;

      // ── Step 4: Check if user is an enrolled student ────────────────────
      try {
        final studentDocs = await FirebaseFirestore.instance
            .collectionGroup('students')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (!mounted) return;
        if (studentDocs.docs.isNotEmpty) {
          final doc = studentDocs.docs.first;
          final libId = doc.reference.parent.parent?.id ?? '';
          await _goStudent(user: user, libId: libId);
          return;
        }
      } catch (e) {
        debugPrint('Student UID lookup: $e');
      }
      if (!mounted) return;

      if (user.email != null && user.email!.isNotEmpty) {
        try {
          final emailDocs = await FirebaseFirestore.instance
              .collectionGroup('students')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          if (!mounted) return;
          if (emailDocs.docs.isNotEmpty) {
            final doc = emailDocs.docs.first;
            final libId = doc.reference.parent.parent?.id ?? '';
            await doc.reference.update({'userId': user.uid});
            await _goStudent(user: user, libId: libId);
            return;
          }
        } catch (e) {
          debugPrint('Student Email lookup: $e');
        }
      }
      if (!mounted) return;

      // ── Step 5: New user — check admin whitelist ─────────────────────────
      bool isWhitelisted = false;
      try {
        isWhitelisted =
            await AdminWhitelistService.isEmailWhitelisted(user.email);
      } catch (e) {
        debugPrint('Whitelist lookup: $e');
      }
      if (!mounted) return;

      if (isWhitelisted) {
        ref.read(userRoleProvider.notifier).setRole(AppUserRole.admin);
        context.go(Routes.setupWizard);
      } else {
        // Prospective student signing in -> route to Student Registration
        ref.read(currentLibraryIdProvider.notifier).set(CurrentLibraryNotifier.defaultLibraryId);
        ref.read(userRoleProvider.notifier).setRole(AppUserRole.student);
        await persistUserRole(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          role: AppUserRole.student,
          libraryId: CurrentLibraryNotifier.defaultLibraryId,
        );
        if (!mounted) return;
        context.go(Routes.studentRegister);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      // Subscribe to library-specific admin topic (no Cloud Functions needed)
      final ns = NotificationService();
      await ns.subscribeToTopic('admin-$libId');
      await ns.subscribeToTopic('lib-$libId'); // also receives library-wide announcements
    } catch (_) {}
    // Link staff userId if missing
    if (staffResult != null && staffResult.docs.isNotEmpty) {
      final staffDoc = staffResult.docs.first;
      if ((staffDoc.data() as Map)['userId']?.toString().isEmpty ?? true) {
        await staffDoc.reference.update({'userId': user.uid});
      }
    }
    if (!mounted) return;
    final isLocked = await BiometricService.isLockEnabled();
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
    // Save FCM token and subscribe to library topic for push notifications
    try {
      final token = await NotificationService.getToken();
      if (token != null && effectiveLibId.isNotEmpty && user.uid != null) {
        // Try to update student doc that matches this userId
        final q = await FirebaseFirestore.instance
            .collection('libraries').doc(effectiveLibId)
            .collection('students')
            .where('userId', isEqualTo: user.uid)
            .limit(1).get();
        if (q.docs.isNotEmpty) {
          q.docs.first.reference.update({'fcmToken': token, 'fcmUpdatedAt': FieldValue.serverTimestamp()}).ignore();
        }
      }
      // Subscribe to library-wide topic (receives announcements without Cloud Functions)
      final ns = NotificationService();
      await ns.subscribeToTopic('lib-$effectiveLibId');
    } catch (_) {}
    if (!mounted) return;
    context.go(Routes.studentHome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon — dynamic org branding
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: (_libraryLogoUrl != null && _libraryLogoUrl!.isNotEmpty)
                        ? Image.network(
                            _libraryLogoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) => Icon(
                              Icons.local_library_rounded,
                              size: 56, color: theme.colorScheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.local_library_rounded,
                            size: 56, color: theme.colorScheme.primary,
                          ),
                  ),
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
                  _libraryTagline ?? 'Smart Library Management',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 56),

                // Single sign-in button — industry standard
                if (_isLoading)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Verifying your access…',
                          style: TextStyle(color: Colors.grey)),
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
                      onPressed: () {
                        ref.read(currentLibraryIdProvider.notifier).set(CurrentLibraryNotifier.defaultLibraryId);
                        context.push(Routes.studentRegister);
                      },
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

                // Trust indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Text(
                      'Your access is determined automatically and securely.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
                      child: const Text('Terms', style: TextStyle(fontSize: 11)),
                    ),
                    const Text('•', style: TextStyle(color: Colors.grey)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                      child: const Text('Privacy Policy', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
