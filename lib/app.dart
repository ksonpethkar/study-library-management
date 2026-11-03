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
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/students/presentation/providers/student_providers.dart';
import 'services/biometric_service.dart';
import 'services/inactivity_lock_service.dart';
import 'core/widgets/connectivity_banner.dart';

class StudyLibraryApp extends ConsumerStatefulWidget {
  const StudyLibraryApp({super.key});

  @override
  ConsumerState<StudyLibraryApp> createState() => _StudyLibraryAppState();
}

class _StudyLibraryAppState extends ConsumerState<StudyLibraryApp> with WidgetsBindingObserver {
  // S10: Listener that forces sign-out when user role is revoked server-side
  StreamSubscription<DocumentSnapshot>? _roleChangeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      // If server says role is 'none' but client still thinks they're admin/student → force sign-out
      if (role == 'none' && currentRole != AppUserRole.none) {
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
    WidgetsBinding.instance.removeObserver(this);
    InactivityLockService.dispose();
    super.dispose();
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
    final themeMode = ref.watch(themeNotifierProvider);
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
      theme: custom_theme.AppTheme.fromSeed(seedColor),
      darkTheme: custom_theme.AppTheme.fromSeed(seedColor, brightness: Brightness.dark),
      themeMode: themeMode,
      scrollBehavior: const SmoothBouncingScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
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
        return ConnectivityBanner(
          child: InactivityDetectorWrapper(
            child: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: content,
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
