import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/auth/services/admin_whitelist_service.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/services/image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/security/device_security_check.dart';
import 'package:study_library/services/force_update_service.dart';
import 'package:study_library/services/membership_automation_service.dart';
import 'package:study_library/services/remote_config_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _pulseAnimation;

  // Cached Brand Identity (Loaded instantly from local storage on Frame 1)
  String _libraryName = 'The Cozy Corner Centre';
  String? _logoUrl;
  Color? _accentColor = const Color(0xFFFFB74D);
  String _tagline = 'Smart Study Library & Co-Working Hub';
  final bool _hasCustomBranding = true; // set once — load from Firebase on initState

  @override
  void initState() {
    super.initState();

    // ── 1. Choreograph Material 3 Motion Suite ─────────────────────────────
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Spring entrance for logo badge (0.7 -> 1.0 with subtle overshoot)
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    // Staggered upward slide & fade for typography
    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.95, curve: Curves.easeIn),
      ),
    );

    // Breathing ambient glow pulse
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController.forward();

    // ── 2. Load Local Brand Identity from Cache (Frame 1 Instant Display) ──
    _loadCachedBranding();

    // ── 3. Start Responsive Auth Check in Parallel ─────────────────────────
    _checkAuth();
  }

  void _loadCachedBranding() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final cachedName = prefs.getString('cached_library_name');
      final cachedLogo = prefs.getString('cached_library_logo_url');
      final cachedColor = prefs.getInt('cached_library_accent_color');
      final cachedTagline = prefs.getString('cached_library_tagline');

      if (cachedName != null && cachedName.isNotEmpty) {
        _libraryName = cachedName;
      }
      if (cachedLogo != null && cachedLogo.isNotEmpty) {
        _logoUrl = cachedLogo;
      }
      if (cachedColor != null && cachedColor != 0) {
        _accentColor = Color(cachedColor);
      }
      if (cachedTagline != null && cachedTagline.isNotEmpty) {
        _tagline = cachedTagline;
      }
    } catch (_) {}
  }

  Future<void> _checkAuth() async {
    final startTime = DateTime.now();

    // Security: warn if device is rooted/jailbroken
    final isCompromised = await DeviceSecurityCheck.isDeviceCompromised();
    if (isCompromised && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Security Warning'),
          content: const Text(
            'This device appears to be rooted or jailbroken. '
            'For security of your personal data, some features may be restricted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('I Understand'),
            ),
          ],
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final termsAccepted = prefs.getBool('terms_accepted') ?? false;
    if (!termsAccepted) {
      if (!mounted) return;
      context.go(Routes.consent);
      return;
    }

    // Check maintenance mode
    if (RemoteConfigService.maintenanceMode) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.build_circle_rounded, size: 72, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('Under Maintenance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'We are making improvements. Please check back in a few minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return;
    }

    // Check for forced app update
    try {
      await ref.read(updateServiceProvider.notifier).checkForUpdate();
    } catch (_) {}

    // Wait for Firebase Auth to restore session from local device storage
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        user = FirebaseAuth.instance.currentUser;
      }
    }

    if (user == null) {
      await _ensureMinAnimationDuration(startTime);
      if (mounted) context.go(Routes.login);
      return;
    }

    try {
      // ── Step 1: Try persisted role from local storage / Firestore ─────────
      final persisted = await readPersistedUserRole(user.uid);
      if (!mounted) return;

      if (persisted != null && persisted['role'] != null) {
        final roleStr = persisted['role'] as String;
        final libId = (persisted['libraryId'] ?? CurrentLibraryNotifier.defaultLibraryId) as String;

        if (roleStr == 'admin') {
          ref.read(currentLibraryIdProvider.notifier).set(libId);
          ref.read(userRoleProvider.notifier).setRole(AppUserRole.admin);
          final isLocked = await BiometricService.isLockEnabled();
          await _ensureMinAnimationDuration(startTime);
          if (!mounted) return;
          context.go(isLocked ? Routes.biometricLock : Routes.adminHome);
          return;
        }

        if (roleStr == 'student') {
          ref.read(currentLibraryIdProvider.notifier).set(libId);
          ref.read(userRoleProvider.notifier).setRole(AppUserRole.student);
          await _ensureMinAnimationDuration(startTime);
          if (!mounted) return;
          context.go(Routes.studentHome);
          return;
        }
      }

      // ── Step 2: Full Firestore Check (First launch after install) ─────────

      // 2a. Owner lookup
      final library =
          await ref.read(libraryRepositoryProvider).getLibraryByOwnerId(user.uid);
      if (!mounted) return;

      if (library != null) {
        ref.read(currentLibraryIdProvider.notifier).set(library.id);
        ref.read(userRoleProvider.notifier).setRole(AppUserRole.admin);
        await persistUserRole(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          role: AppUserRole.admin,
          libraryId: library.id,
        );
        final isLocked = await BiometricService.isLockEnabled();
        await _ensureMinAnimationDuration(startTime);
        if (!mounted) return;
        context.go(isLocked ? Routes.biometricLock : Routes.adminHome);
        return;
      }

      // 2b. Staff lookup
      if (user.email != null && user.email!.isNotEmpty) {
        final staffDocs = await FirebaseFirestore.instance
            .collectionGroup('staff')
            .where('email', isEqualTo: user.email!.toLowerCase())
            .limit(1)
            .get();
        if (!mounted) return;

        if (staffDocs.docs.isNotEmpty) {
          final staffDoc = staffDocs.docs.first;
          final libId = staffDoc.reference.parent.parent?.id;
          if (libId != null) {
            ref.read(currentLibraryIdProvider.notifier).set(libId);
            ref.read(userRoleProvider.notifier).setRole(AppUserRole.admin);
            await persistUserRole(
              uid: user.uid,
              email: user.email ?? '',
              displayName: user.displayName ?? '',
              role: AppUserRole.admin,
              libraryId: libId,
            );
            if ((staffDoc.data()['userId'] ?? '').toString().isEmpty) {
              await staffDoc.reference.update({'userId': user.uid});
            }
            await _ensureMinAnimationDuration(startTime);
            if (!mounted) return;
            context.go(Routes.adminHome);
            return;
          }
        }
      }

      // 2c. Enrolled student lookup
      final studentByUid = await FirebaseFirestore.instance
          .collectionGroup('students')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (!mounted) return;

      if (studentByUid.docs.isNotEmpty) {
        final doc = studentByUid.docs.first;
        final libId = doc.reference.parent.parent?.id ?? '';
        if (libId.isNotEmpty) {
          ref.read(currentLibraryIdProvider.notifier).set(libId);
        }
        ref.read(userRoleProvider.notifier).setRole(AppUserRole.student);
        await persistUserRole(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          role: AppUserRole.student,
          libraryId: libId,
        );
        await _ensureMinAnimationDuration(startTime);
        if (!mounted) return;
        context.go(Routes.studentHome);
        return;
      }

      // 2d. Whitelist check for new admin onboarding
      final isWhitelisted =
          await AdminWhitelistService.isEmailWhitelisted(user.email);
      if (!mounted) return;

      await _ensureMinAnimationDuration(startTime);
      if (!mounted) return;

      if (isWhitelisted) {
        ref.read(userRoleProvider.notifier).setRole(AppUserRole.admin);
        context.go(Routes.setupWizard);
      } else {
        // User is signed in but not an enrolled student yet -> take them to Student Registration
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
      await _ensureMinAnimationDuration(startTime);
      if (mounted) context.go(Routes.login);
    }
  }

  Future<void> _runDailyAutomation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRun = prefs.getString('lastAutomationRun');
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      if (lastRun != today) {
        final libId = ref.read(currentLibraryIdProvider);
        if (libId != null && libId.isNotEmpty) {
          await MembershipAutomationService.runDailyMaintenance(libId);
          await prefs.setString('lastAutomationRun', today);
        }
      }
    } catch (_) {}
  }

  /// Ensures the entrance animation has time to cleanly complete (~1600ms)
  /// before navigating away, presenting a smooth, branded entrance experience.
  Future<void> _ensureMinAnimationDuration(DateTime startTime) async {
    await _runDailyAutomation();
    const minDurationMs = 1600;
    final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsedMs < minDurationMs) {
      await Future.delayed(Duration(milliseconds: minDurationMs - elapsedMs));
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = _accentColor ?? theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Subtle Ambient Radial Gradient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 1.1,
                  colors: [
                    primaryColor.withValues(alpha: 0.10),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),

          // Central Choreographed Brand Hero
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Logo Badge with Spring Entrance & Ambient Breathing Pulse
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(
                                    alpha: 0.18 * _pulseAnimation.value,
                                  ),
                                  blurRadius: 28 * _pulseAnimation.value,
                                  spreadRadius: 4 * _pulseAnimation.value,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: _logoUrl != null && _logoUrl!.isNotEmpty
                                ? ImageService.buildImageWidget(
                                    _logoUrl!,
                                    fit: BoxFit.cover,
                                    width: 104,
                                    height: 104,
                                  )
                                : Container(
                                    color: primaryColor.withValues(alpha: 0.08),
                                    child: Center(
                                      child: Icon(
                                        Icons.local_library_rounded,
                                        size: 52,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 2. Staggered Organization Name & Welcome Tagline
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          Text(
                            _libraryName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _tagline,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (_hasCustomBranding) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'OFFICIAL STUDY PORTAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Refined Material 3 Micro-Indicator
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: FadeTransition(
              opacity: _textFade,
              child: Center(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      primaryColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
