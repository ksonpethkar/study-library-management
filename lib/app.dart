import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart' as custom_theme;
import 'core/providers/font_settings_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/auth/services/auth_role_service.dart';
import 'features/students/presentation/providers/student_providers.dart';
import 'services/biometric_service.dart';
import 'services/inactivity_lock_service.dart';
import 'services/telemetry_service.dart';
import 'core/utils/secure_screen_mixin.dart';
import 'core/widgets/connectivity_banner.dart';

class StudyLibraryApp extends ConsumerStatefulWidget {
  const StudyLibraryApp({super.key});

  @override
  ConsumerState<StudyLibraryApp> createState() => _StudyLibraryAppState();
}

class _StudyLibraryAppState extends ConsumerState<StudyLibraryApp> with WidgetsBindingObserver {
  // S10: Listener that forces sign-out when user role is revoked server-side
  StreamSubscription<DocumentSnapshot>? _roleChangeSubscription;
  StreamSubscription<DocumentSnapshot>? _securitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Apply native screenshot protection immediately on startup based on cached setting
    isScreenshotProtectionEnabled().then((enabled) {
      applyNativeSecureFlag(enabled);
    }).catchError((_) {});

    InactivityLockService.initialize(
      onLock: () {
        if (mounted) {
          ref.read(appRouterProvider).go(Routes.biometricLock);
        }
      },
      checkLockEnabled: () async {
        final role = ref.read(userRoleProvider);
        if (role == AppUserRole.admin) {
          return await BiometricService.isLockEnabled(isAdmin: true);
        } else if (role == AppUserRole.student) {
          final student = ref.read(currentStudentProvider).value;
          final authUid = FirebaseAuth.instance.currentUser?.uid;
          final libId = ref.read(currentLibraryIdProvider);
          return await BiometricService.isLockEnabled(
            userId: student?.id,
            authUid: authUid,
            libraryId: libId,
            candidateIds: [if (student?.id != null) student!.id, ?authUid],
            isAdmin: false,
          );
        }
        return false;
      },
    );
    // Start watching for role revocation after a short delay (auth must be ready)
    Future.delayed(const Duration(seconds: 2), _watchRoleRevocation);
  }

  /// S10: Listens to the current user's Firestore document.
  /// If their role is changed to 'none' or removed, force sign-out immediately.
  void _watchRoleRevocation() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _roleChangeSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) return;
      final role = snap.data()?['role'] as String? ?? '';
      final currentRole = ref.read(userRoleProvider);
      // If server says role is 'none' but client still thinks they're admin/student → verify or force sign-out
      if (role == 'none' && currentRole != AppUserRole.none) {
        if (currentRole == AppUserRole.student) {
          try {
            final defaultLibId = CurrentLibraryNotifier.defaultLibraryId;
            final studentDoc = await AuthRoleService.findStudentDocumentForUser(user, defaultLibId);
            if (studentDoc != null && studentDoc.exists) {
              await snap.reference.set({'role': 'student'}, SetOptions(merge: true)).catchError((_) {});
              return;
            }
          } catch (_) {}
        }
        await FirebaseAuth.instance.signOut();
        ref.read(userRoleProvider.notifier).clear();
        ref.read(currentLibraryIdProvider.notifier).clear();
        if (mounted) {
          ref.read(appRouterProvider).go(Routes.splash);
        }
      }
    });
  }

  @override
  void dispose() {
    _roleChangeSubscription?.cancel();
    _securitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    InactivityLockService.dispose();
    super.dispose();
  }

  void _watchScreenshotProtection(String libraryId) {
    _securitySubscription?.cancel();
    if (libraryId.isEmpty) return;

    // Listen to libraries/{id}/settings/security in real-time
    _securitySubscription = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('security')
        .snapshots()
        .listen((snap) async {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        if (data.containsKey('screenshotProtectionEnabled') &&
            data['screenshotProtectionEnabled'] is bool) {
          final enabled = data['screenshotProtectionEnabled'] as bool;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('screenshot_protection_global', enabled);
          await prefs.setBool('screenshot_protection_configured', true);
          await prefs.setBool('screenshot_protection_admin_disabled', !enabled);
          await applyNativeSecureFlag(enabled);
        }
      }
    }, onError: (_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      BiometricService.onAppPaused();
      // Save current route so it can be restored after biometric unlock
      _saveCurrentRoute();
    } else if (state == AppLifecycleState.resumed) {
      final role = ref.read(userRoleProvider);
      final isAdmin = role == AppUserRole.admin;
      final student = ref.read(currentStudentProvider).value;
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final libId = ref.read(currentLibraryIdProvider);

      final shouldLock = await BiometricService.shouldLockOnResume(
        userId: student?.id,
        authUid: authUid,
        libraryId: libId,
        candidateIds: [if (student?.id != null) student!.id, ?authUid],
        isAdmin: isAdmin,
      );
      if (shouldLock && mounted) {
        final router = ref.read(appRouterProvider);
        router.go(Routes.biometricLock);
      }
    }
  }

  /// Persists the current GoRouter location to SharedPreferences.
  Future<void> _saveCurrentRoute() async {
    try {
      final router = ref.read(appRouterProvider);
      final location = router.routerDelegate.currentConfiguration.uri.toString();
      if (location.isNotEmpty &&
          location != Routes.biometricLock &&
          location != Routes.splash) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_active_route', location);
      }
    } catch (_) { /* intentionally silent */ }
  }

  @override
  Widget build(BuildContext context) {
    // Keep Crashlytics telemetry metadata in sync with active user session
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null) {
        TelemetryService.setUser(
          uid: next.uid,
          email: next.email,
          libraryId: ref.read(currentLibraryIdProvider),
        );
      } else {
        TelemetryService.clearUser();
      }
    });

    ref.listen(currentLibraryIdProvider, (previous, next) {
      if (next != null) {
        TelemetryService.setLibrary(next);
        loadScreenshotProtectionFromFirestore(next);
        _watchScreenshotProtection(next);
      }
    });

    final themeMode = ref.watch(themeNotifierProvider);
    final fontSettings = ref.watch(fontSettingsProvider);
    final router = ref.watch(appRouterProvider);

    // --- Dynamic brand color ---
    // 1. Try live Firestore library first (updates instantly when admin changes color)
    // 2. Fall back to cached value from SharedPreferences (available instantly on startup)
    // 3. Final fallback: default brown from AppColors
    final liveLibrary = ref.watch(currentLibraryProvider).value;
    final prefs = ref.watch(sharedPreferencesProvider);

    final Color seedColor;
    if (liveLibrary != null && liveLibrary.accentColor != 0) {
      seedColor = Color(liveLibrary.accentColor);
    } else {
      final cached = prefs.getInt('cached_library_accent_color');
      seedColor = cached != null && cached != 0
          ? Color(cached)
          : const Color(0xFF5D4037); // deep brown default
    }

    final cachedName = prefs.getString('cached_library_name');
    final effectiveAppTitle = liveLibrary?.name.isNotEmpty == true
        ? liveLibrary!.name
        : (cachedName != null && cachedName.trim().isNotEmpty
            ? cachedName.trim()
            : 'The Cozy Corner Study Centre');

    return MaterialApp.router(
      title: effectiveAppTitle,
      debugShowCheckedModeBanner: false,
      theme: custom_theme.AppTheme.fromSeed(seedColor, fontFamily: fontSettings.family),
      darkTheme: custom_theme.AppTheme.fromSeed(seedColor, brightness: Brightness.dark, fontFamily: fontSettings.family),
      themeMode: themeMode,
      scrollBehavior: const SmoothBouncingScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final clampedScaler = TextScaler.linear(fontSettings.scale.factor).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.30,
        );
        Widget content = child ?? const SizedBox.shrink();
        if (kIsWeb) {
          content = LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 920) {
                return ColoredBox(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 920,
                        minHeight: constraints.maxHeight,
                        maxHeight: constraints.maxHeight,
                      ),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return child ?? const SizedBox.shrink();
            },
          );
        }
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: ConnectivityBanner(
            child: InactivityDetectorWrapper(
              child: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                behavior: HitTestBehavior.translucent,
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }
}

class SmoothBouncingScrollBehavior extends MaterialScrollBehavior {
  const SmoothBouncingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
