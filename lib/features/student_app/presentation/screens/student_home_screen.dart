import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/dashboard/presentation/widgets/app_update_banner.dart';
import 'package:study_library/features/dashboard/presentation/widgets/notification_center_sheet.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/settings/presentation/screens/security_settings_dialog.dart';
import 'package:study_library/services/biometric_service.dart';
import 'package:study_library/features/announcements/presentation/screens/announcement_list_screen.dart';
import 'package:study_library/features/holidays/presentation/screens/holiday_calendar_screen.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/providers/theme_provider.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/services/expiry_scheduler_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/services/quick_actions_service.dart';
import 'package:study_library/core/widgets/update_reminder_dialog.dart';
import 'package:study_library/core/widgets/facility_tour_sheet.dart';
import 'package:study_library/core/error/error_handler.dart';
import 'package:study_library/features/student_app/presentation/widgets/silent_reception_help_sheet.dart';

/// Real-time stream of the current student's pending registration request.
/// Returns the request document if status == 'pending', null otherwise.
/// This enables the home screen to auto-update when admin approves without restart.
final pendingRequestProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (libraryId == null || libraryId.isEmpty || uid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('requests')
      .where('studentId', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isNotEmpty ? snap.docs.first.data() : null);
});

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _refreshAnimController;
  late final AnimationController _cardFlipController;
  late final Animation<double> _cardFlipAnimation;
  bool _birthdayDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkBirthdayDismissed();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _cardFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardFlipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardFlipController, curve: Curves.easeInOutCubic),
    );

    QuickActionsService.initializeForStudent(context, (shortcutType) {
      if (!mounted) return;
      switch (shortcutType) {
        case 'my_membership':
          context.push(Routes.studentMembership);
          break;
        case 'my_id_card':
          context.push(Routes.studentIdCard);
          break;
      }
    });
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    _cardFlipController.dispose();
    super.dispose();
  }

  void _toggleCardFlip() {
    HapticFeedback.selectionClick();
    if (_cardFlipController.status == AnimationStatus.completed) {
      _cardFlipController.reverse();
    } else {
      _cardFlipController.forward();
    }
  }

  Future<void> _checkBirthdayDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = 'birthday_dismissed_${now.year}_${now.month}_${now.day}';
      if (prefs.getBool(todayKey) == true && mounted) {
        setState(() => _birthdayDismissed = true);
      }
    } catch (_) {}
  }

  Future<void> _dismissBirthdayBanner(String studentId) async {
    HapticFeedback.lightImpact();
    setState(() => _birthdayDismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = 'birthday_dismissed_${now.year}_${now.month}_${now.day}';
      await prefs.setBool(todayKey, true);
    } catch (_) {}
  }

  bool _isBirthdayToday(DateTime? dob) {
    if (dob == null) return false;
    final now = DateTime.now();
    return dob.month == now.month && dob.day == now.day;
  }

  Future<void> _refreshAll() async {
    HapticFeedback.mediumImpact();
    _refreshAnimController.forward(from: 0.0);
    ref.invalidate(currentLibraryProvider);
    ref.invalidate(currentStudentProvider);
    ref.invalidate(sectionsProvider);
    ref.invalidate(plansStreamProvider);
    ref.invalidate(announcementsStreamProvider);
    ref.invalidate(pendingRequestProvider);
    final studentId = ref.read(currentStudentProvider).value?.id;
    if (studentId != null && studentId.isNotEmpty) {
      ref.invalidate(studentNotificationsStreamProvider(studentId));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Synchronized latest library & profile data'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _scheduleRemindersIfNeeded(StudentModel student, {String libraryName = '', int renewalDays = 7}) {
    final planEndDate = student.planEndDate;
    if (planEndDate == null) return;
    if (student.membershipStatus != MembershipStatus.active &&
        student.membershipStatus != MembershipStatus.grace) {
      return;
    }

    ExpirySchedulerService.scheduleExpiryReminders(
      expiryDate: planEndDate,
      studentName: student.name,
      libraryName: libraryName,
      reminderDays: renewalDays,
    ).ignore();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        WhatsNewService.checkAndShow(context, isStudent: true);
        UpdateReminderDialog.checkAndShow(context, ref);
        FacilityTourSheet.checkAndShow(context);
      }
    });

    final theme = Theme.of(context);
    final libraryAsync = ref.watch(currentLibraryProvider);
    final studentAsync = ref.watch(currentStudentProvider);
    final announcementsAsync = ref.watch(announcementsStreamProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final pendingSeatChange = ref.watch(studentPendingSeatChangeProvider).value;
    final pendingRenewal = ref.watch(studentPendingRenewalProvider).value;

    final library = libraryAsync.value;
    final libraryName = library?.name.isNotEmpty == true ? library!.name : 'Study Library';
    final sections = sectionsAsync.value ?? [];

    ref.listen<AsyncValue<StudentModel?>>(currentStudentProvider, (_, next) {
      next.whenData((student) {
        if (student != null) _scheduleRemindersIfNeeded(student, libraryName: libraryName, renewalDays: library?.renewalReminderDays ?? 7);
      });
    });

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: library?.logoUrl.isNotEmpty == true
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: ImageService.getImageProvider(library!.logoUrl),
                ),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              libraryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (library?.tagline.isNotEmpty == true)
              Text(
                library!.tagline,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // 1. Theme Toggle (Direct on Dashboard per user request)
          Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeNotifierProvider);
              final isDark = themeMode == ThemeMode.dark;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? Colors.amber : null,
                ),
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeNotifierProvider.notifier).toggleTheme();
                },
              );
            },
          ),
          // 2. Student Notification Center with Live Unread Badge
          Consumer(
            builder: (context, ref, _) {
              final student = studentAsync.value;
              final studentId = student?.id;
              final effectiveId = (studentId != null && studentId.isNotEmpty)
                  ? studentId
                  : FirebaseAuth.instance.currentUser?.uid;
              if (effectiveId == null || effectiveId.isEmpty) return const SizedBox.shrink();
              final notifs = ref.watch(studentNotificationsStreamProvider(effectiveId)).value ?? [];
              final unreadCount = notifs.where((n) => !n.read).length;

              return Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                backgroundColor: Colors.redAccent,
                child: IconButton(
                  icon: Icon(
                    unreadCount > 0
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_outlined,
                  ),
                  tooltip: 'My Notifications ($unreadCount)',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final libId = library?.id ?? ref.read(currentLibraryIdProvider) ?? '';
                    NotificationCenterSheet.show(
                      context,
                      libraryId: libId,
                      role: 'student',
                      studentId: effectiveId,
                    );
                  },
                ),
              );
            },
          ),
          // 3. Smooth Rotating Refresh Button
          RotationTransition(
            turns: _refreshAnimController,
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshAll,
              tooltip: 'Sync Data',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: studentAsync.when(
        data: (student) {
          final studentName = student?.name ?? 'Student';
          final photoUrl = student?.photoUrl ?? '';

          // Look up assigned seat & section
          final seatId = student?.seatId;
          final sectionId = student?.sectionId;
          final planId = student?.planId;

          final section = sections.where((s) => s.id == sectionId).firstOrNull;
          final sectionName = section?.name ?? (sectionId != null && sectionId.isNotEmpty ? 'Main Hall' : '');
          final seatLabel = (seatId != null && seatId.isNotEmpty)
              ? SeatHelper.formatSeatLabel(seatId: seatId, cols: section?.cols)
              : 'No Seat Assigned';

          // Look up plan details
          final plans = plansAsync.value ?? [];
          final plan = plans.where((p) => p.id == planId).firstOrNull ??
              (student?.planId == 'custom'
                  ? PlanModel(
                      id: 'custom',
                      libraryId: ref.read(currentLibraryIdProvider) ?? '',
                      name: student?.customPlanName?.isNotEmpty == true ? student!.customPlanName! : 'Custom Plan',
                      price: student?.customPlanFee ?? 500.0,
                      duration: 1,
                      durationUnit: DurationUnit.months,
                      description: student?.customDiscountReason ?? '',
                      gracePeriodDays: 0,
                      isActive: true,
                      isFeatured: false,
                      displayOrder: 0,
                    )
                  : null);

          // No student doc yet — check for a pending registration request in real-time
          if (student == null) {
            final pendingAsync = ref.watch(pendingRequestProvider);
            return pendingAsync.when(
              data: (request) {
                if (request != null && request['status'] == 'pending') {
                  // Student has a pending request — show waiting UI
                  // This view auto-disappears when admin approves (stream emits null)
                  return _buildRealTimePendingView(context, theme, request);
                }
                // No request and no student profile — safely route back to login screen.
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (context.mounted) {
                    ref.read(userRoleProvider.notifier).clear();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('cached_current_user_role');
                    await prefs.remove('persisted_role');
                    await prefs.remove('persisted_uid');
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) context.go(Routes.login);
                  }
                });
                return const Center(child: CircularProgressIndicator());
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text(
                          'Offline Mode Active',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Could not sync with the library server. Check your connection or retry.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () {
                            ref.invalidate(currentStudentProvider);
                            ref.invalidate(pendingRequestProvider);
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry Connection'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () async {
                            ref.read(userRoleProvider.notifier).clear();
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) context.go(Routes.login);
                          },
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          if (student.membershipStatus == MembershipStatus.pending) {
            return _buildPendingApprovalView(context, theme, student);
          }
          if (student.membershipStatus == MembershipStatus.blocked) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.block_rounded, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Account Blocked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        student.blockedReason ?? 'Your account has been temporarily suspended. Please contact the library admin.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).signOut();
                          if (context.mounted) context.go(Routes.login);
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 110.0),
              children: [
                _buildHolidayNoticeBanner(context, ref),
                const AppUpdateBanner(),
                _buildPinResetNoticeBanner(context, ref, student),
                // Header Greeting
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (photoUrl.isNotEmpty) {
                          ImageService.showImageViewer(context, imageUrl: photoUrl, title: studentName);
                        }
                      },
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: photoUrl.isNotEmpty ? ImageService.getImageProvider(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          Text(
                            studentName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: studentName.length > 25 ? 16.5 : 18.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(student.effectiveMembershipStatus.name.toUpperCase()),
                      backgroundColor: student.effectiveMembershipStatus == MembershipStatus.active
                          ? Colors.green.shade100
                          : (student.effectiveMembershipStatus == MembershipStatus.grace
                              ? Colors.orange.shade100
                              : Colors.red.shade100),
                      labelStyle: TextStyle(
                        color: student.effectiveMembershipStatus == MembershipStatus.active
                            ? Colors.green.shade900
                            : (student.effectiveMembershipStatus == MembershipStatus.grace
                                ? Colors.orange.shade900
                                : Colors.red.shade900),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Birthday Celebration Banner (Delightful immediate celebration for enrolled students)
                if (!_birthdayDismissed && _isBirthdayToday(student.dob)) ...[
                  _buildBirthdayBanner(context, theme, student, libraryName),
                ],

                // Active Announcement Banner (if any)
                announcementsAsync.when(
                  data: (announcements) {
                    final activeAnnouncements = announcements.where((a) => a.isActive).toList();
                    if (activeAnnouncements.isEmpty) return const SizedBox.shrink();
                    final topAnnouncement = activeAnnouncements.first;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.campaign_rounded, color: theme.colorScheme.tertiary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topAnnouncement.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  topAnnouncement.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // Contextual Renewal In-Progress Banner OR Expiry Alert Banner
                if (pendingRenewal != null) ...[
                  _buildPendingRenewalCard(
                    context: context,
                    theme: theme,
                    libraryId: library?.id ?? ref.read(currentLibraryIdProvider) ?? '',
                    pendingData: pendingRenewal,
                    student: student,
                    library: library,
                  ),
                  const SizedBox(height: 14),
                ] else if (student.isExpired ||
                    (student.daysRemaining != null && student.daysRemaining! <= 7) ||
                    student.effectiveMembershipStatus == MembershipStatus.grace) ...[
                  _buildStudentExpiryAlertBanner(context, theme, student, seatLabel),
                  const SizedBox(height: 14),
                ],

                // 1. 3D Holographic Flip Smart Access Pass
                _buildDigitalSmartPass(
                  context: context,
                  theme: theme,
                  student: student,
                  plan: plan,
                  seatLabel: seatLabel,
                  sectionName: sectionName,
                  library: library,
                  libraryName: libraryName,
                ),
                const SizedBox(height: 16),

                // 2. Inspiring Exam Countdown & Daily Focus Widget
                _buildExamCountdownWidget(
                  context,
                  theme,
                  student,
                  library?.id ?? ref.read(currentLibraryIdProvider) ?? '',
                ),
                const SizedBox(height: 16),

                // Dedicated Seat Change In-Progress Card (Prominently informs student of pending move)
                if (pendingSeatChange != null) ...[
                  _buildPendingSeatChangeCard(
                    context: context,
                    theme: theme,
                    libraryId: library?.id ?? ref.read(currentLibraryIdProvider) ?? '',
                    pendingData: pendingSeatChange,
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. High-Readability Seat Radar Card
                _buildAssignedSeatCard(
                  context,
                  theme,
                  seatLabel,
                  sectionName,
                  seatId,
                  effectiveStatus: student.effectiveMembershipStatus,
                  pendingSeatChange: pendingSeatChange,
                ),
                const SizedBox(height: 16),

                // Wi-Fi 1-Tap Quick Access & Password Copy Card
                _buildWifiCard(context, theme, library),
                const SizedBox(height: 16),

                // 4. Ergonomic Quick Services Dock (4-column primary + 2-item secondary)
                _buildQuickServicesDock(
                  context,
                  theme,
                  library,
                  student: student,
                  seatLabel: seatLabel,
                  libraryId: library?.id ?? ref.read(currentLibraryIdProvider) ?? '',
                ),
                const SizedBox(height: 20),

                // 5. Compact Manager & Helpline Contact Dock
                _buildCompactContactCard(context, theme, library, libraryName),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              ErrorHandler.handleError(err),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentExpiryAlertBanner(
    BuildContext context,
    ThemeData theme,
    StudentModel student,
    String seatLabel,
  ) {
    final isExpired = student.isExpired;
    final isInGrace = student.effectiveMembershipStatus == MembershipStatus.grace;
    final days = student.daysRemaining ?? 0;
    final hasSeat = student.seatId != null && student.seatId!.isNotEmpty;
    final isDark = theme.brightness == Brightness.dark;

    // Palette: Red for expired, Amber for imminent (<3d), Emerald for 4-7d proactive protection
    final Color color;
    final Color bgColor;
    final Color borderColor;

    if (isExpired) {
      color = const Color(0xFFEF4444);
      bgColor = isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEF2F2);
      borderColor = isDark ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFFFECACA);
    } else if (isInGrace || days <= 3) {
      color = const Color(0xFFD97706);
      bgColor = isDark ? const Color(0xFF3B2D12) : const Color(0xFFFFFBEB);
      borderColor = isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.45) : const Color(0xFFFDE68A);
    } else {
      // 4-7 days: Reassuring proactive hold guarantee
      color = const Color(0xFF0D9488);
      bgColor = isDark ? const Color(0xFF132E2B) : const Color(0xFFF0FDFA);
      borderColor = isDark ? const Color(0xFF14B8A6).withValues(alpha: 0.45) : const Color(0xFFCCFBF1);
    }

    final String titleText;
    final String bodyText;
    final String buttonLabel;

    if (hasSeat) {
      if (isExpired) {
        titleText = '⚠️ Desk $seatLabel In Grace Hold';
        bodyText = 'Your membership has ended. Desk $seatLabel is reserved temporarily before reallocation. Renew now to retain your spot.';
        buttonLabel = '🔒 Keep Desk $seatLabel • 1-Tap Renew';
      } else if (days == 0) {
        titleText = '🔒 Desk $seatLabel Held • Expires Today';
        bodyText = 'Keep your personal study desk $seatLabel locked in with 1-tap instant renewal without interruption.';
        buttonLabel = '🔒 Keep Desk $seatLabel • 1-Tap Renew';
      } else if (days <= 3) {
        titleText = '🔒 Desk $seatLabel Held For You ($days Days Left)';
        bodyText = 'Your dedicated desk $seatLabel is protected. Renew online anytime to keep your spot guaranteed.';
        buttonLabel = '🔒 Keep Desk $seatLabel • 1-Tap Renew';
      } else {
        titleText = '🔒 Desk $seatLabel Reservation Active';
        bodyText = 'Valid until ${student.planEndDate != null ? DateFormat("dd MMM yyyy").format(student.planEndDate!) : "soon"} ($days days). Renew early to guarantee your desk stays locked.';
        buttonLabel = '🔒 Keep Desk $seatLabel • 1-Tap Renew';
      }
    } else {
      if (isExpired) {
        titleText = 'Membership Expired';
        bodyText = 'Your plan has ended. Renew online to immediately restore your digital library pass and facilities.';
        buttonLabel = '⚡ 1-Tap Renew Membership';
      } else if (days == 0) {
        titleText = 'Plan Expires Today!';
        bodyText = 'Renew today to maintain continuous access to high-speed Wi-Fi, air conditioning, and library perks.';
        buttonLabel = '⚡ 1-Tap Renew Plan';
      } else {
        titleText = 'Plan Expires in $days Day${days > 1 ? "s" : ""}';
        bodyText = 'Valid until ${student.planEndDate != null ? DateFormat("dd MMM yyyy").format(student.planEndDate!) : "soon"}. Renew now to enjoy uninterrupted library access.';
        buttonLabel = '⚡ 1-Tap Renew Plan';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSeat
                  ? Icons.lock_rounded
                  : (isExpired ? Icons.error_outline_rounded : Icons.schedule_rounded),
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        titleText,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                              : (days <= 3 || isInGrace
                                  ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                                  : (isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E))),
                        ),
                      ),
                    ),
                    if (hasSeat) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Seat Held',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  bodyText,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isExpired
                        ? const Color(0xFFDC2626)
                        : (days <= 3 || isInGrace ? const Color(0xFFD97706) : const Color(0xFF0D9488)),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push(Routes.studentRenew);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(hasSeat ? Icons.lock_open_rounded : Icons.autorenew_rounded, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        buttonLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalSmartPass({
    required BuildContext context,
    required ThemeData theme,
    required StudentModel student,
    required dynamic plan,
    required String seatLabel,
    required String sectionName,
    required dynamic library,
    required String libraryName,
  }) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _toggleCardFlip,
        child: AnimatedBuilder(
          animation: _cardFlipAnimation,
          builder: (context, child) {
            final angle = _cardFlipAnimation.value * pi;
            final isFront = angle < (pi / 2);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: isFront
                  ? _buildPassFront(student, plan, seatLabel, sectionName, library, libraryName, theme)
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _buildPassBack(student, library, libraryName, theme, seatLabel: seatLabel),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPassFront(
    StudentModel student,
    dynamic plan,
    String seatLabel,
    String sectionName,
    dynamic library,
    String libraryName,
    ThemeData theme,
  ) {
    final photoUrl = student.photoUrl;
    final studentName = student.name;
    final membershipId = student.membershipNumber?.isNotEmpty == true
        ? student.membershipNumber!
        : 'CC${student.id.length >= 8 ? student.id.substring(0, 8).toUpperCase() : student.id.toUpperCase()}';

    final daysLeft = student.planEndDate != null
        ? student.planEndDate!.difference(DateTime.now()).inDays
        : 0;
    final totalDays = (student.planStartDate != null && student.planEndDate != null)
        ? student.planEndDate!.difference(student.planStartDate!).inDays
        : 30;
    final progress = totalDays > 0 ? (daysLeft / totalDays).clamp(0.0, 1.0) : 0.0;
    final progressColor = daysLeft > 7
        ? const Color(0xFF10B981)
        : daysLeft > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    final status = student.effectiveMembershipStatus;
    final (statusColor, statusLabel, statusIcon) = switch (status) {
      MembershipStatus.active => (const Color(0xFF10B981), 'ACTIVE PASS', Icons.verified_rounded),
      MembershipStatus.grace => (const Color(0xFFF59E0B), 'GRACE PERIOD', Icons.hourglass_top_rounded),
      MembershipStatus.expired => (const Color(0xFFEF4444), 'EXPIRED', Icons.error_outline_rounded),
      MembershipStatus.blocked => (const Color(0xFFEF4444), 'LOCKED / BLOCKED', Icons.gpp_bad_rounded),
      _ => (const Color(0xFF6366F1), 'PENDING', Icons.schedule_rounded),
    };

    final logoUrl = (library != null && (library.logoUrl as String?)?.isNotEmpty == true)
        ? library.logoUrl as String
        : '';
    final logoProvider = logoUrl.isNotEmpty ? ImageService.getImageProvider(logoUrl) : null;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.75), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.22),
                blurRadius: 14,
                spreadRadius: 1.0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.6), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: logoProvider != null
                              ? Image(
                                  image: logoProvider,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(Icons.school_rounded, color: Color(0xFF4F46E5), size: 18),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.school_rounded, color: Color(0xFF4F46E5), size: 18),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                libraryName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Text(
                                'STUDENT SMART ACCESS CARD',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.75), width: 1.1),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 11, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 14),
          // Student Profile Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFF312E81),
                    backgroundImage: photoUrl.isNotEmpty ? ImageService.getImageProvider(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Text(
                            studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'VERIFIED',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4338CA).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ID: $membershipId',
                        style: const TextStyle(
                          color: Color(0xFFC7D2FE),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phone: ${student.phone}',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                    ),
                    if (student.college.isNotEmpty)
                      Text(
                        'College: ${student.college}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (student.course.isNotEmpty)
                      Text(
                        'Course: ${student.course}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'SEAT: $seatLabel',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (student.isCurrentlyFrozen)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.ac_unit_rounded, size: 10, color: Color(0xFFFCD34D)),
                                const SizedBox(width: 3),
                                Text(
                                  student.freezeEndDate != null
                                      ? 'FROZEN: Resumes ${DateFormat('dd MMM').format(student.freezeEndDate!.add(const Duration(days: 1)))}'
                                      : 'PASS FROZEN',
                                  style: const TextStyle(
                                    color: Color(0xFFFCD34D),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (student.planEndDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'VALID TILL: ${DateFormat('dd MMM yyyy').format(student.planEndDate!)}',
                              style: const TextStyle(
                                color: Color(0xFFFCD34D),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (student.hasPowerSurcharge)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAB308).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, size: 10, color: Color(0xFFFDE047)),
                                SizedBox(width: 2),
                                Text(
                                  'AC POWER',
                                  style: TextStyle(
                                    color: Color(0xFFFDE047),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 10),
          // Progress bar & Settled indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                student.isCurrentlyFrozen
                    ? (student.freezeEndDate != null
                        ? 'Pass Frozen • Resumes ${DateFormat('dd MMM yyyy').format(student.freezeEndDate!.add(const Duration(days: 1)))}'
                        : 'Pass Frozen (Study Leave)')
                    : (daysLeft == 1
                        ? '1 Day Remaining'
                        : (daysLeft > 1
                            ? '$daysLeft Days Remaining'
                            : (student.planEndDate != null ? 'Expired ${-daysLeft}d ago' : 'No Active Plan'))),
                style: TextStyle(
                  color: student.isCurrentlyFrozen ? const Color(0xFFFCD34D) : progressColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    plan != null ? 'Fee ₹${plan.price.toStringAsFixed(0)} Settled' : 'Active Pass',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              color: progressColor,
              backgroundColor: const Color(0xFF334155),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          // Flip hint footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flip_to_back_rounded, size: 12, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                'Tap card to flip for Barcode & Emergency Contacts 🔄',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
        // Subtle 3D Watermark of Organization Logo in Background (Dead Center)
        if (logoProvider != null)
          Positioned.fill(
            child: Center(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.08,
                  child: ClipOval(
                    child: Image(
                      image: logoProvider,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPassBack(
    StudentModel student,
    dynamic library,
    String libraryName,
    ThemeData theme, {
    String seatLabel = '',
  }) {
    final membershipId = student.membershipNumber?.isNotEmpty == true
        ? student.membershipNumber!
        : 'CC${student.id.length >= 8 ? student.id.substring(0, 8).toUpperCase() : student.id.toUpperCase()}';

    final status = student.effectiveMembershipStatus;
    final statusColor = switch (status) {
      MembershipStatus.active => const Color(0xFF10B981),
      MembershipStatus.grace => const Color(0xFFF59E0B),
      MembershipStatus.expired || MembershipStatus.blocked => const Color(0xFFEF4444),
      _ => const Color(0xFF6366F1),
    };

    final logoUrl = (library != null && (library.logoUrl as String?)?.isNotEmpty == true)
        ? library.logoUrl as String
        : '';
    final logoProvider = logoUrl.isNotEmpty ? ImageService.getImageProvider(logoUrl) : null;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.75), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.22),
                blurRadius: 14,
                spreadRadius: 1.0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TERMS OF ACCESS & EMERGENCY INFO',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Issued: ${student.createdAt != null ? DateFormat('dd MMM yyyy').format(student.createdAt!) : 'Active'}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('• Card is non-transferable; must be produced upon entry.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, height: 1.3)),
          const Text('• Maintain complete silence inside study zones at all times.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, height: 1.3)),
          Text('• Guardian: ${student.fatherName.isNotEmpty ? student.fatherName : "On Record"}',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, height: 1.3)),
          Text('• Blood Group: ${student.bloodGroup?.isNotEmpty == true ? student.bloodGroup : "O+"}',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, height: 1.3)),
          const SizedBox(height: 10),
          // Emergency Red Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EMERGENCY: ${student.emergencyContact.isNotEmpty ? student.emergencyContact : student.phone}',
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Reception: ${library?.helplineNumber.isNotEmpty == true ? library.helplineNumber : (library?.contact ?? "Desk")}',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // QR Barcode & Seal Row
          Row(
            children: [
              GestureDetector(
                onTap: () => _showEnlargedQrDialog(
                  context,
                  student: student,
                  membershipId: membershipId,
                  seatLabel: seatLabel,
                  libraryName: libraryName,
                  library: library,
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: QrImageView(
                          data: jsonEncode({
                            'type': 'STUDENT_PASS',
                            'id': student.id,
                            'lib': library?.id ?? '',
                            'name': student.name,
                            'memNo': membershipId,
                            'phone': student.phone,
                            'bloodGroup': student.bloodGroup ?? '',
                            'emergency': student.emergencyContact,
                            'seat': seatLabel.isNotEmpty ? seatLabel : (student.seatId ?? 'Unassigned'),
                            'expiry': student.planEndDate != null ? DateFormat('dd/MM/yyyy').format(student.planEndDate!) : 'Active',
                            'isFrozen': student.isCurrentlyFrozen,
                          }),
                          size: 78,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '🔍 Tap to Zoom',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membershipId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Official property of $libraryName. Card must be presented upon request.',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Flip back hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flip_to_front_rounded, size: 12, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                'Tap card to flip back 🔄',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
        // Subtle 3D Watermark of Organization Logo in Background (Dead Center)
        if (logoProvider != null)
          Positioned.fill(
            child: Center(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.08,
                  child: ClipOval(
                    child: Image(
                      image: logoProvider,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showEnlargedQrDialog(
    BuildContext context, {
    required StudentModel student,
    required String membershipId,
    required String seatLabel,
    required String libraryName,
    dynamic library,
  }) {
    final qrData = jsonEncode({
      'type': 'STUDENT_PASS',
      'id': student.id,
      'lib': library?.id ?? '',
      'name': student.name,
      'memNo': membershipId,
      'phone': student.phone,
      'bloodGroup': student.bloodGroup ?? '',
      'emergency': student.emergencyContact,
      'seat': seatLabel.isNotEmpty ? seatLabel : (student.seatId ?? 'Unassigned'),
      'expiry': student.planEndDate != null
          ? DateFormat('dd/MM/yyyy').format(student.planEndDate!)
          : 'Active',
    });

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student QR Pass',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          membershipId,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0F172A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                student.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Desk: ${seatLabel.isNotEmpty ? seatLabel : (student.seatId ?? "Seat Assigned")} • $libraryName',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'Ready for Biometric & Desk Scanner',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingSeatChangeCard({
    required BuildContext context,
    required ThemeData theme,
    required String libraryId,
    required Map<String, dynamic> pendingData,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final requestId = (pendingData['id'] ?? pendingData['requestId'] ?? '').toString();
    final targetLabel = SeatHelper.formatSeatLabel(
      seatId: pendingData['targetSeatId'] as String?,
      rawLabel: pendingData['targetSeatLabel'] as String?,
    );
    final targetSec = (pendingData['targetSectionName'] as String?) ?? 'Cozy Hall';
    final reason = (pendingData['reason'] as String?)?.trim();
    final ts = pendingData['createdAt'] as Timestamp?;
    final createdDate = ts?.toDate();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E200C) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.6 : 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seat Change Request In Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'WAITING FOR ADMIN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Requested Desk: $targetLabel ($targetSec)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
            ),
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: "$reason"',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                createdDate != null
                    ? 'Submitted: ${DateFormat("dd MMM, hh:mm a").format(createdDate)}'
                    : 'Submitted to library admin',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    icon: const Icon(Icons.map_rounded, size: 15),
                    label: const Text('View Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.push(Routes.studentSeatMap);
                    },
                  ),
                  if (requestId.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        foregroundColor: Colors.red.shade700,
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 15),
                      label: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _confirmCancelSeatChange(context, libraryId, requestId),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancelSeatChange(
    BuildContext context,
    String libraryId,
    String requestId,
  ) async {
    HapticFeedback.mediumImpact();
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFFEE2E2),
                child: Icon(Icons.cancel_outlined, size: 30, color: Colors.red),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cancel Seat Change Request?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to cancel your pending seat change request? You can select another available desk at any time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cancel Request'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep Current Request'),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('requests')
            .doc(requestId)
            .delete();
        ref.invalidate(studentPendingSeatChangeProvider);
        if (context.mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seat change request cancelled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
        }
      }
    }
  }

  Widget _buildPendingRenewalCard({
    required BuildContext context,
    required ThemeData theme,
    required String libraryId,
    required Map<String, dynamic> pendingData,
    required StudentModel student,
    required LibraryModel? library,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final requestId = (pendingData['id'] ?? pendingData['requestId'] ?? '').toString();
    final planName = (pendingData['requestedPlanName'] ?? 'Membership Plan').toString();
    final amount = (pendingData['amount'] as num?)?.toDouble() ?? 0.0;
    final status = (pendingData['status'] ?? 'pending').toString().toLowerCase();
    final isDeskPayment = status == 'desk_payment_pending' ||
        (pendingData['paymentMethod'] ?? '').toString().toLowerCase().contains('cash') ||
        (pendingData['paymentMethod'] ?? '').toString().toLowerCase().contains('desk');
    final refNumber = (pendingData['referenceNumber'] ?? '').toString().trim();
    final ts = pendingData['createdAt'] as Timestamp?;
    final createdDate = ts?.toDate();
    final seatLabel = SeatHelper.formatSeatLabel(seatId: student.seatId ?? student.previousSeatId);

    final borderColor = isDeskPayment
        ? const Color(0xFF0284C7).withValues(alpha: isDark ? 0.6 : 0.45)
        : const Color(0xFF10B981).withValues(alpha: isDark ? 0.6 : 0.45);
    final bgColor = isDeskPayment
        ? (isDark ? const Color(0xFF0C243B) : const Color(0xFFF0F9FF))
        : (isDark ? const Color(0xFF063327) : const Color(0xFFF0FDF4));
    final headerTextColor = isDeskPayment
        ? (isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1))
        : (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46));
    final badgeBgColor = isDeskPayment
        ? (isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD))
        : (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0));
    final badgeTextColor = isDeskPayment
        ? (isDark ? Colors.white : const Color(0xFF0369A1))
        : (isDark ? Colors.white : const Color(0xFF065F46));

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (isDeskPayment ? const Color(0xFF0284C7) : const Color(0xFF10B981)).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDeskPayment ? Icons.storefront_rounded : Icons.hourglass_top_rounded,
                color: isDeskPayment ? const Color(0xFF0284C7) : const Color(0xFF059669),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDeskPayment ? 'Desk Renewal Registered' : 'Renewal Payment In Review',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: headerTextColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDeskPayment ? 'PAY AT DESK' : 'VERIFYING UTR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDeskPayment
                          ? 'Please deposit fee at reception to activate pass'
                          : (refNumber.isNotEmpty && !refNumber.startsWith('Desk')
                              ? 'Submitted UTR: $refNumber'
                              : 'Online payment submitted for verification'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isDeskPayment ? const Color(0xFF0284C7) : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_rounded, size: 14, color: isDeskPayment ? const Color(0xFF0284C7) : const Color(0xFF059669)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    student.seatId != null
                        ? 'Your allocated $seatLabel is locked & protected while request is active'
                        : 'Your pass will be activated immediately upon admin confirmation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: borderColor.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                createdDate != null
                    ? 'Submitted ${DateFormat('dd MMM, hh:mm a').format(createdDate)}'
                    : 'Submitted recently',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (library?.whatsappNumber.isNotEmpty == true || library?.contact.isNotEmpty == true) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        foregroundColor: const Color(0xFF25D366),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 14),
                      label: const Text('Contact Desk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final rawPhone = (library?.whatsappNumber.isNotEmpty == true
                                ? library!.whatsappNumber
                                : library?.contact ?? '')
                            .replaceAll(RegExp(r'\D'), '');
                        if (rawPhone.isNotEmpty) {
                          final targetPhone = rawPhone.length == 10 ? '91$rawPhone' : rawPhone;
                          final msg = Uri.encodeComponent(
                            'Hi, I have submitted a renewal request for $planName (₹${amount.toStringAsFixed(0)}). ${refNumber.isNotEmpty && !refNumber.startsWith("Desk") ? "UTR: $refNumber" : ""}\nPlease review and activate.',
                          );
                          final uri = Uri.parse('https://wa.me/$targetPhone?text=$msg');
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (_) {}
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.redAccent,
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Cancel', style: TextStyle(fontSize: 11)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancel Renewal Request?'),
                          content: const Text(
                            'Are you sure you want to cancel this renewal request? You can submit another request or pay at the desk anytime.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Cancel Request'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await FirebaseFirestore.instance
                              .collection('libraries')
                              .doc(libraryId)
                              .collection('requests')
                              .doc(requestId)
                              .delete();
                          ref.invalidate(studentPendingRenewalProvider);
                          if (context.mounted) {
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Renewal request cancelled.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedSeatCard(
    BuildContext context,
    ThemeData theme,
    String seatLabel,
    String sectionName,
    String? seatId, {
    MembershipStatus effectiveStatus = MembershipStatus.active,
    Map<String, dynamic>? pendingSeatChange,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final isExpired = effectiveStatus == MembershipStatus.expired || effectiveStatus == MembershipStatus.blocked;
    final isGrace = effectiveStatus == MembershipStatus.grace;
    final bool hasPendingChange = pendingSeatChange != null;

    final String targetSeatLabel = hasPendingChange
        ? SeatHelper.formatSeatLabel(
            seatId: pendingSeatChange['targetSeatId'] as String?,
            rawLabel: pendingSeatChange['targetSeatLabel'] as String?,
          )
        : '';
    final String targetSecName = hasPendingChange
        ? (pendingSeatChange['targetSectionName'] as String? ?? sectionName)
        : sectionName;

    final Color accentColor = isExpired
        ? const Color(0xFFEF4444)
        : (hasPendingChange
            ? const Color(0xFFF59E0B)
            : (isGrace ? const Color(0xFFF59E0B) : const Color(0xFF10B981)));

    final String badgeLabel = isExpired
        ? 'EXPIRED'
        : (hasPendingChange
            ? 'CHANGE IN PROGRESS'
            : (isGrace ? 'GRACE PERIOD' : 'ALLOCATED'));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? (hasPendingChange ? 0.6 : 0.35) : (hasPendingChange ? 0.5 : 0.25)),
          width: hasPendingChange ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: hasPendingChange ? 14 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: accentColor.withValues(alpha: 0.15),
          child: Icon(
            hasPendingChange
                ? Icons.swap_horiz_rounded
                : (isExpired ? Icons.event_seat_rounded : Icons.chair_rounded),
            color: accentColor,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seatLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (hasPendingChange) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Text(
                        targetSeatLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                isExpired
                    ? 'Desk access inactive • Renew to reactivate'
                    : (hasPendingChange
                        ? 'Requested move to $targetSeatLabel ($targetSecName) • Waiting for admin approval'
                        : (isGrace
                            ? 'Desk temporarily reserved • Grace active'
                            : (sectionName.isNotEmpty ? 'Section: $sectionName • Tap Change Desk to choose a new seat' : 'Reserved Study Desk • Tap Change Desk to choose a new seat'))),
                style: TextStyle(
                  color: isExpired
                      ? const Color(0xFFEF4444)
                      : (hasPendingChange
                          ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                          : (isGrace ? const Color(0xFFD97706) : theme.colorScheme.onSurfaceVariant)),
                  fontSize: 12,
                  fontWeight: isExpired || isGrace || hasPendingChange ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (!isExpired && !isGrace && !hasPendingChange)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Pin Drop Silence 🟢',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                  ),
                ),
            ],
          ),
        ),
        trailing: OutlinedButton.icon(
          icon: Icon(
            isExpired
                ? Icons.refresh_rounded
                : (hasPendingChange ? Icons.hourglass_top_rounded : Icons.swap_horiz_rounded),
            size: 15,
          ),
          label: Text(
            isExpired
                ? 'Renew'
                : (hasPendingChange ? 'View Request' : 'Change Desk'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            foregroundColor: isExpired
                ? const Color(0xFFDC2626)
                : (hasPendingChange ? const Color(0xFFD97706) : null),
            side: hasPendingChange ? const BorderSide(color: Color(0xFFF59E0B), width: 1.2) : null,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (isExpired) {
              context.push(Routes.studentRenew);
            } else {
              context.push(Routes.studentSeatMap);
            }
          },
        ),
      ),
    );
  }

  Widget _buildQuickServicesDock(
    BuildContext context,
    ThemeData theme,
    dynamic library, {
    StudentModel? student,
    String? seatLabel,
    String? libraryId,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 360;
    final isDark = theme.brightness == Brightness.dark;

    final primaryActions = [
      _CompactQuickAction(
        icon: Icons.badge_rounded,
        label: 'ID Pass',
        color: const Color(0xFF2563EB),
        onTap: () => context.push(Routes.studentIdCard),
      ),
      _CompactQuickAction(
        icon: Icons.autorenew_rounded,
        label: 'Renew',
        color: const Color(0xFFEA580C),
        onTap: () => context.push(Routes.studentRenew),
      ),
      _CompactQuickAction(
        icon: Icons.receipt_long_rounded,
        label: 'Receipts',
        color: const Color(0xFF059669),
        onTap: () => context.push(Routes.studentReceipts),
      ),
      _CompactQuickAction(
        icon: Icons.history_rounded,
        label: 'History',
        color: const Color(0xFF0284C7),
        onTap: () => context.push(Routes.studentPaymentHistory),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Services', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              '8 Services',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isVerySmall) ...[
          // 2x2 adaptive grid on extra small screens
          Row(
            children: [
              Expanded(child: primaryActions[0]),
              const SizedBox(width: 10),
              Expanded(child: primaryActions[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: primaryActions[2]),
              const SizedBox(width: 10),
              Expanded(child: primaryActions[3]),
            ],
          ),
        ] else ...[
          // Primary 4-column compact dock on standard screens
          Row(
            children: [
              Expanded(child: primaryActions[0]),
              const SizedBox(width: 10),
              Expanded(child: primaryActions[1]),
              const SizedBox(width: 10),
              Expanded(child: primaryActions[2]),
              const SizedBox(width: 10),
              Expanded(child: primaryActions[3]),
            ],
          ),
        ],
        const SizedBox(height: 10),

        // Phase 4: Silent Reception Help & Quiet Study Environment Card
        InkWell(
          onTap: () {
            SilentReceptionHelpSheet.show(
              context,
              libraryId: libraryId ?? '',
              student: student,
              deskLabel: seatLabel,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF132E2B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF0FDFA), const Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.45 : 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.12 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_off_rounded,
                    color: Color(0xFF0D9488),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Quiet Desk Assistance',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Discrete',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '1-Tap silent alert to Reception • Noise, AC, Wi-Fi, Water or Desk help',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Action: Dedicated Notice Board & Circulars Hub
        _SecondaryQuickAction(
          icon: Icons.campaign_rounded,
          label: 'Notice Board & Circulars',
          color: const Color(0xFF2563EB),
          onTap: () => context.push(Routes.studentAnnouncements),
        ),
        const SizedBox(height: 10),
        // Secondary 2-column slim row
        Row(
          children: [
            Expanded(
              child: _SecondaryQuickAction(
                icon: Icons.explore_rounded,
                label: 'Facilities & Rules',
                color: const Color(0xFF7C3AED),
                onTap: () => FacilityTourSheet.show(context, force: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SecondaryQuickAction(
                icon: Icons.rate_review_rounded,
                label: 'Feedback & Support',
                color: const Color(0xFFD97706),
                onTap: () => context.push(Routes.studentFeedback),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactContactCard(BuildContext context, ThemeData theme, dynamic library, String libraryName) {
    if (library?.contact == null || (library!.contact as String).isEmpty) return const SizedBox.shrink();
    final contactStr = library.contact as String;
    final adminNameStr = (library.adminName as String?) ?? '';
    final adminPhotoUrlStr = (library.adminPhotoUrl as String?) ?? '';
    final addressStr = (library.address as String?) ?? '';
    final whatsappStr = (library.whatsappNumber as String?) ?? '';
    final socialLinks = (library.socialLinks as Map<String, dynamic>?) ?? {};

    final personnel = (library is LibraryModel) ? library.populatedPersonnel : <Map<String, String>>[];
    final isMultiPersonnel = personnel.length > 1;

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: adminPhotoUrlStr.isNotEmpty
                      ? ImageService.getImageProvider(adminPhotoUrlStr)
                      : null,
                  child: adminPhotoUrlStr.isEmpty
                      ? Icon(Icons.support_agent_rounded, color: theme.colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMultiPersonnel ? 'Need Help? Key Personnel & Contacts' : 'Need Help? Contact Admin',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (!isMultiPersonnel && personnel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 13, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${personnel.first['role']}: ${personnel.first['name']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isMultiPersonnel) ...[
                        const SizedBox(height: 2),
                        Text(contactStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                      if (addressStr.isNotEmpty)
                        Text(
                          addressStr,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (!isMultiPersonnel)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.phone_rounded, color: Colors.green, size: 18),
                        tooltip: 'Call Support',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.15),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final uri = Uri.parse('tel:$contactStr');
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 18),
                        tooltip: 'WhatsApp Admin',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final rawPhone = whatsappStr.isNotEmpty
                              ? whatsappStr
                              : contactStr;
                          final clean = rawPhone.replaceAll(RegExp(r'\D'), '');
                          final withCode = clean.startsWith('91') || clean.length > 10
                              ? clean
                              : '91$clean';
                          final adminGreeting = adminNameStr.isNotEmpty ? 'Hello $adminNameStr, ' : 'Hello Admin, ';
                          final msg = Uri.encodeComponent(
                              '${adminGreeting}I need help with my membership at $libraryName.');
                          final uri = Uri.parse('https://wa.me/$withCode?text=$msg');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
            if (isMultiPersonnel) ...[
              const SizedBox(height: 12),
              ...personnel.map((p) {
                final role = p['role'] ?? 'Staff';
                final name = p['name'] ?? '';
                final phone = p['contact'] ?? contactStr;
                final clean = phone.replaceAll(RegExp(r'\D'), '');
                final withCode = clean.startsWith('91') || clean.length > 10 ? clean : '91$clean';
                final msg = Uri.encodeComponent('Hello $name ($role), I need assistance with my library membership at $libraryName.');

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        role.toLowerCase().contains('owner')
                            ? Icons.person_pin_rounded
                            : (role.toLowerCase().contains('admin')
                                ? Icons.admin_panel_settings_rounded
                                : Icons.support_agent_rounded),
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$role: $name',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(phone, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.phone_rounded, color: Colors.green, size: 16),
                        tooltip: 'Call $role',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.15),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                        ),
                        onPressed: () async {
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 16),
                        tooltip: 'WhatsApp $role',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                        ),
                        onPressed: () async {
                          final uri = Uri.parse('https://wa.me/$withCode?text=$msg');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (socialLinks.values.any((v) => (v as String).trim().isNotEmpty)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: socialLinks.entries
                    .where((e) => (e.value as String).trim().isNotEmpty)
                    .map((e) {
                      final key = e.key.toLowerCase().trim();
                      final url = (e.value as String).trim();
                      IconData icon = Icons.language;
                      String label = key;
                      Color iconColor = theme.colorScheme.primary;

                      if (key.contains('instagram')) {
                        icon = Icons.camera_alt_outlined;
                        label = 'Instagram';
                        iconColor = const Color(0xFFE1306C);
                      } else if (key.contains('facebook')) {
                        icon = Icons.facebook;
                        label = 'Facebook';
                        iconColor = const Color(0xFF1877F2);
                      } else if (key.contains('youtube')) {
                        icon = Icons.smart_display_outlined;
                        label = 'YouTube';
                        iconColor = const Color(0xFFFF0000);
                      } else if (key.contains('website') || key.contains('web')) {
                        icon = Icons.language;
                        label = 'Website';
                        iconColor = theme.colorScheme.primary;
                      }

                      return ActionChip(
                        avatar: Icon(icon, size: 14, color: iconColor),
                        label: Text(label, style: const TextStyle(fontSize: 11)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      );
                    }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayNoticeBanner(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final holidaysAsync = ref.watch(holidaysStreamProvider);

    return holidaysAsync.when(
      data: (holidays) {
        final todayHoliday = holidays.where((h) {
          final d = DateTime(h.date.year, h.date.month, h.date.day);
          return d == todayKey && h.isFullDay;
        }).firstOrNull;

        if (todayHoliday == null) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_busy_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🔒 Library Closed Today',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    if (todayHoliday.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        todayHoliday.reason,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildPinResetNoticeBanner(BuildContext context, WidgetRef ref, StudentModel student) {
    if (!student.pinResetByAdmin) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.orange.shade700 : Colors.orange.shade300,
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.orange.shade800 : Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Lock Was Reset by Admin',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your security PIN was reset by your library admin. Protect your profile by creating a new 4-digit PIN.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  final libId = ref.read(currentLibraryIdProvider);
                  if (libId != null && libId.isNotEmpty) {
                    await BiometricService.clearAdminPinResetFlag(
                      libraryId: libId,
                      studentId: student.id,
                    );
                    ref.invalidate(currentStudentProvider);
                  }
                },
                child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.pin_rounded, size: 16),
                label: const Text('Set New PIN'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () {
                  SecuritySettingsDialog.show(
                    context,
                    isStudent: true,
                    studentId: student.id,
                    authUid: student.userId ?? FirebaseAuth.instance.currentUser?.uid,
                    libraryId: ref.read(currentLibraryIdProvider),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayBanner(BuildContext context, ThemeData theme, StudentModel student, String libraryName) {
    final firstName = student.name.trim().split(' ').first;
    final course = student.course.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF92400E), Color(0xFFD97706), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 12,
            bottom: -6,
            child: Opacity(
              opacity: 0.18,
              child: Text(
                '🎉',
                style: TextStyle(fontSize: 84),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🎂', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SPECIAL CELEBRATION',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Happy Birthday, $firstName! 🎉',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      tooltip: 'Dismiss for today',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _dismissBirthdayBanner(student.id),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'The entire team at $libraryName wishes you a joyful birthday filled with wisdom, good health, and glorious success in your ${course.isNotEmpty ? course : 'competitive studies'}! Keep shining bright! ✨',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 14, color: Colors.amberAccent),
                          SizedBox(width: 4),
                          Text(
                            'VIP Study Day',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF92400E),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _dismissBirthdayBanner(student.id),
                      child: const Text('Thank You! ❤️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWifiCard(BuildContext context, ThemeData theme, dynamic library) {
    final ssid = (library is LibraryModel) ? library.effectiveWifiSsid : 'Cozy Corner 5G';
    final password = (library is LibraryModel) ? library.effectiveWifiPassword : 'Study@Cozy2026';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _copyWifiPassword(context, ssid, password),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ssid,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('High-Speed 5G', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to copy password: $password',
                        style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _copyWifiPassword(context, ssid, password),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyWifiPassword(BuildContext context, String ssid, String password) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: password));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('✅ Wi-Fi password copied! Network: "$ssid"'),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DONE',
          textColor: Colors.amberAccent,
          onPressed: () {},
        ),
      ),
    );
  }

  static const List<String> _studyQuotes = [
    'Quiet hours at your desk today become proud moments tomorrow.',
    'Consistency beats motivation every single day. Keep showing up!',
    'The seat you occupy today is building the rank you celebrate tomorrow.',
    'Focus on the daily process; the extraordinary result will follow.',
    'Small daily disciplines compound into life-changing triumphs.',
    'Discipline is choosing between what you want now and what you want most.',
    'Silence in the study hall, absolute strength in your exam score.',
  ];

  String _getDailyStudyQuote() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return _studyQuotes[dayOfYear % _studyQuotes.length];
  }

  Widget _buildExamCountdownWidget(
    BuildContext context,
    ThemeData theme,
    StudentModel student,
    String libraryId,
  ) {
    final targetDate = student.effectiveTargetExamDate;
    final examName = student.effectiveTargetExamName;
    final daysLeft = student.daysUntilExam;
    final isDark = theme.brightness == Brightness.dark;

    if (targetDate == null) {
      // Prompt banner to set target exam
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.track_changes_rounded, color: Color(0xFF6366F1), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Exam Countdown',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track days left for UPSC, NEET, CA, GATE or your custom degree.',
                    style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                foregroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showEditTargetExamDialog(context, student, libraryId),
              child: const Text('Set Goal 🎯', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // Active Countdown Card
    final formattedDate = DateFormat('dd MMM yyyy').format(targetDate);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showEditTargetExamDialog(context, student, libraryId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.3 : 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.track_changes_rounded, size: 16, color: Color(0xFF6366F1)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          examName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: isDark ? Colors.white : const Color(0xFF3730A3),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _showEditTargetExamDialog(context, student, libraryId),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.edit_calendar_rounded, size: 14, color: isDark ? Colors.indigo.shade200 : const Color(0xFF4338CA)),
                            const SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.indigo.shade200 : const Color(0xFF4338CA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$daysLeft',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAYS REMAINING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                          ),
                        ),
                        Text(
                          'Target: $formattedDate',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getDailyStudyQuote(),
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF374151),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditTargetExamDialog(
    BuildContext context,
    StudentModel student,
    String libraryId,
  ) async {
    final nameController = TextEditingController(text: student.effectiveTargetExamName);
    DateTime selectedDate = student.effectiveTargetExamDate ?? DateTime.now().add(const Duration(days: 90));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.track_changes_rounded, color: Color(0xFF6366F1), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Set Exam Countdown 🎯',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track exact days left to stay focused during your study shifts.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Exam or Goal Name',
                      hintText: 'e.g. UPSC Prelims, NEET UG, CA Final',
                      prefixIcon: const Icon(Icons.school_rounded),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate.isBefore(DateTime.now())
                            ? DateTime.now().add(const Duration(days: 30))
                            : selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerLowest,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF6366F1)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Target Exam Date', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                                Text(
                                  DateFormat('EEEE, dd MMMM yyyy').format(selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Save & Start Countdown', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final examName = nameController.text.trim().isNotEmpty
                            ? nameController.text.trim()
                            : student.effectiveTargetExamName;

                        Navigator.pop(sheetCtx);
                        HapticFeedback.mediumImpact();

                        try {
                          await FirebaseFirestore.instance
                              .collection('libraries')
                              .doc(libraryId)
                              .collection('students')
                              .doc(student.id)
                              .set({
                            'targetExamName': examName,
                            'targetExamDate': selectedDate.toIso8601String(),
                            'course': examName,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          ref.invalidate(currentStudentProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎯 Target countdown set for "$examName"! Keep going!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not save exam target: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CompactQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CompactQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: isDark ? 0.3 : 0.15),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isDark ? Colors.white : color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SecondaryQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildPendingApprovalView(BuildContext context, ThemeData theme, StudentModel student) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pending_actions_rounded, size: 48, color: Colors.amber.shade700),
          ),
          const SizedBox(height: 24),
          Text(
            'Application Under Review',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Text('⏳ Pending Admin Approval', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(height: 20),
          Text(
            'Hello ${student.name.split(' ').first}! 👋\n\nYour registration is currently being reviewed by the library administrator. You will receive a notification once your membership is confirmed.\n\nThis usually takes less than 24 hours.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Shown when student has a pending request doc but no student record yet.
/// Reacts in real-time: auto-transitions to full home when admin approves.
Widget _buildRealTimePendingView(BuildContext context, ThemeData theme, Map<String, dynamic> request) {
  final studentName = (request['studentName'] as String? ?? 'Student').split(' ').first;
  final requestId = request['id'] as String? ?? '';
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: Colors.amber.shade100, shape: BoxShape.circle),
            child: Icon(Icons.pending_actions_rounded, size: 48, color: Colors.amber.shade700),
          ),
          const SizedBox(height: 24),
          Text(
            'Application Under Review',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Text('⏳ Pending Admin Approval',
                style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(height: 20),
          Text(
            'Hello $studentName! 👋\n\nYour registration is being reviewed by the library administrator. You will be notified once your membership is confirmed.\n\nThis usually takes less than 24 hours.',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.6),
            textAlign: TextAlign.center,
          ),
          if (requestId.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Reference: #${requestId.substring(0, 8).toUpperCase()}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontFamily: 'monospace')),
          ],
          const SizedBox(height: 8),
          Text('🔄 This screen will update automatically when approved.',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    ),
  );
}

