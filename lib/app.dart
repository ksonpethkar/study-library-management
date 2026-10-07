import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart' as custom_theme;
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
    } else if (state == AppLifecycleState.resumed) {
      final shouldLock = await BiometricService.shouldLockOnResume();
      if (shouldLock && mounted) {
        final router = ref.read(appRouterProvider);
        router.go(Routes.biometricLock);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Cozy Corner',
      debugShowCheckedModeBanner: false,
      theme: custom_theme.AppTheme.lightTheme,
      darkTheme: custom_theme.AppTheme.darkTheme,
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
