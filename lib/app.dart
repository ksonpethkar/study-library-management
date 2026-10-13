import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart' as custom_theme;
import 'features/auth/presentation/providers/auth_provider.dart';
import 'services/biometric_service.dart';
import 'services/inactivity_lock_service.dart';
import 'core/widgets/connectivity_banner.dart';

class StudyLibraryApp extends ConsumerStatefulWidget {
  const StudyLibraryApp({super.key});

  @override
  ConsumerState<StudyLibraryApp> createState() => _StudyLibraryAppState();
}

class _StudyLibraryAppState extends ConsumerState<StudyLibraryApp> with WidgetsBindingObserver {
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
    );
  }

  @override
  void dispose() {
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
      final shouldLock = await BiometricService.shouldLockOnResume();
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
    } catch (_) {}
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

    return MaterialApp.router(
      title: 'Cozy Corner',
      debugShowCheckedModeBanner: false,
      theme: custom_theme.AppTheme.fromSeed(seedColor),
      darkTheme: custom_theme.AppTheme.fromSeed(seedColor, brightness: Brightness.dark),
      themeMode: themeMode,
      scrollBehavior: const SmoothBouncingScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        return ConnectivityBanner(
          child: InactivityDetectorWrapper(
            child: child ?? const SizedBox.shrink(),
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
