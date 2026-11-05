import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/constants/app_constants.dart';
import 'package:study_library/core/router/app_router.dart';

class ReleaseChange {
  final IconData icon;
  final String title;
  final String description;
  final String? badge;
  final String? rawIconName;
  final String? actionRoute;
  final String? actionLabel;

  const ReleaseChange({
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
    this.rawIconName,
    this.actionRoute,
    this.actionLabel,
  });

  Map<String, dynamic> toJson() {
    return {
      'icon': rawIconName ?? _iconToString(icon),
      'title': title,
      'description': description,
      if (badge != null) 'badge': badge,
      if (actionRoute != null) 'actionRoute': actionRoute,
      if (actionLabel != null) 'actionLabel': actionLabel,
    };
  }

  factory ReleaseChange.fromJson(Map<String, dynamic> json) {
    final iconStr = (json['icon'] ?? '').toString();
    return ReleaseChange(
      icon: _resolveIcon(iconStr),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      badge: json['badge'] as String?,
      rawIconName: iconStr,
      actionRoute: json['actionRoute'] as String?,
      actionLabel: json['actionLabel'] as String?,
    );
  }

  static IconData _resolveIcon(String iconStr) {
    switch (iconStr.toLowerCase()) {
      case 'badge':
      case 'id_card':
      case 'atm':
        return Icons.badge_rounded;
      case 'approval':
      case 'stamp':
        return Icons.approval_rounded;
      case 'opacity':
      case 'watermark':
        return Icons.opacity_rounded;
      case 'auto_awesome':
      case 'splash':
      case 'sparkles':
        return Icons.auto_awesome_rounded;
      case 'card_membership':
      case 'plan':
      case 'plans':
        return Icons.card_membership_rounded;
      case 'document_scanner':
      case 'ocr':
      case 'scanner':
        return Icons.document_scanner_rounded;
      case 'lock':
      case 'security':
      case 'shield':
        return Icons.lock_outline_rounded;
      case 'sentiment_satisfied_alt':
      case 'friendly':
      case 'error':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'event_seat':
      case 'seat':
      case 'chair':
        return Icons.event_seat_rounded;
      case 'receipt':
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'campaign':
      case 'announcement':
        return Icons.campaign_rounded;
      case 'palette':
      case 'theme':
        return Icons.palette_rounded;
      case 'qr_code':
      case 'qr':
        return Icons.qr_code_2_rounded;
      case 'system_update':
      case 'update':
        return Icons.system_update_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  static String _iconToString(IconData icon) {
    if (icon == Icons.badge_rounded) return 'badge';
    if (icon == Icons.approval_rounded) return 'approval';
    if (icon == Icons.opacity_rounded) return 'opacity';
    if (icon == Icons.auto_awesome_rounded) return 'auto_awesome';
    if (icon == Icons.card_membership_rounded) return 'card_membership';
    if (icon == Icons.document_scanner_rounded) return 'document_scanner';
    if (icon == Icons.lock_outline_rounded) return 'lock';
    if (icon == Icons.sentiment_satisfied_alt_rounded) return 'sentiment_satisfied_alt';
    if (icon == Icons.event_seat_rounded) return 'seat';
    if (icon == Icons.receipt_long_rounded) return 'receipt';
    if (icon == Icons.campaign_rounded) return 'announcement';
    if (icon == Icons.qr_code_2_rounded) return 'qr_code';
    if (icon == Icons.system_update_rounded) return 'system_update';
    return 'default';
  }
}

class WhatsNewService {
  static const String currentVersionIdentifier = '1.5.50+61';
  static const String _keySeenAdmin = 'last_seen_whats_new_admin';
  static const String _keySeenStudent = 'last_seen_whats_new_student';
  static const String _keyCachedAdminFeatures = 'cached_whats_new_admin_features';
  static const String _keyCachedStudentFeatures = 'cached_whats_new_student_features';
  static const String _updateJsonUrl = 'https://study-lib-mgmt-2026.web.app/update.json';

  static bool _isShowingDialog = false;

  /// Concrete features exclusively relevant for Library Admins & Staff (v1.5.50)
  static final List<ReleaseChange> adminChanges = [
    const ReleaseChange(
      icon: Icons.volume_off_rounded,
      rawIconName: 'volume_off',
      badge: 'Front Desk',
      title: 'Live Quiet Desk Assistance Stream',
      description:
          'Real-time alert banner on the admin console alerting front desk staff immediately with student desk numbers when quiet assistance or noise help is requested.',
      actionRoute: Routes.adminFeedback,
      actionLabel: 'View Desk Alerts',
    ),
    const ReleaseChange(
      icon: Icons.point_of_sale_rounded,
      rawIconName: 'point_of_sale',
      badge: 'Billing & Parity',
      title: '10-Second Express Counter Billing & Atomic Seat Parity',
      description:
          'Lightning-fast cash payment recording with instant digital receipts and zero-drift concurrency safety ensuring double-seat allocations are completely prevented.',
      actionRoute: Routes.adminHome,
      actionLabel: 'Collect Fee',
    ),
    const ReleaseChange(
      icon: Icons.receipt_long_rounded,
      rawIconName: 'receipt_long',
      badge: 'Receipts',
      title: 'Resilient Multi-Key Receipt Retrieval',
      description:
          'Multi-field indexing ensures every student fee receipt is immediately visible in student and admin histories across student IDs, auth UIDs, and mobile numbers.',
      actionRoute: Routes.adminReceipts,
      actionLabel: 'View Receipts',
    ),
    const ReleaseChange(
      icon: Icons.bolt_rounded,
      rawIconName: 'bolt',
      badge: 'Quick Action Studio',
      title: 'Categorized Quick Action Studio & Instant Petty Cash Logging',
      description:
          'Upgraded the bottom (+) button into a high-speed Quick Action Studio grouped into Daily Transactions and Admissions/Notices. Added 5-second petty cash expense logging directly updating the Net Facility Profit.',
      actionRoute: Routes.adminHome,
      actionLabel: 'Try Studio (+)',
    ),
    const ReleaseChange(
      icon: Icons.payments_rounded,
      rawIconName: 'payments',
      badge: 'Smart Picker',
      title: 'Smart Payment Picker with Defaulter Prioritization',
      description:
          'Payment collection sheet now places students with overdue dues strictly at the top with prominent due badges, instant multimodal search (Name, Phone, #CC Admission ID, Desk), and offline cache loading.',
      actionRoute: Routes.adminHome,
      actionLabel: 'Collect Fee',
    ),
    const ReleaseChange(
      icon: Icons.campaign_rounded,
      rawIconName: 'campaign',
      badge: 'Broadcast Hub',
      title: 'Priority Announcements & Expiration Control',
      description:
          'Create prioritized announcements (Urgent, Holiday, Maintenance, General) with optional auto-expiry dates, live read receipt metrics, and automatic sync to student notification centers.',
      actionRoute: Routes.adminAnnouncements,
      actionLabel: 'Open Announcements',
    ),
    const ReleaseChange(
      icon: Icons.arrow_back_rounded,
      rawIconName: 'navigation',
      badge: 'Smart Back',
      title: 'Leading-App Navigation & Accidental Exit Prevention',
      description:
          'Secondary bottom navigation tabs (Seats, Students, Settings) now smoothly navigate back to Home on back press. Accidental app closure is prevented with a 2-second double-tap exit guard.',
    ),
    const ReleaseChange(
      icon: Icons.verified_user_rounded,
      rawIconName: 'approval',
      badge: 'Real-Time Sync',
      title: 'Dynamic Student Pass Validity & Expiration Engine',
      description:
          'Pass status now evaluates dynamically based on wall-clock time and plan duration. Expired passes are automatically flagged in real time with 1-tap renewal payment recording.',
      actionRoute: Routes.adminStudents,
      actionLabel: 'View Students',
    ),
    const ReleaseChange(
      icon: Icons.qr_code_scanner_rounded,
      rawIconName: 'qr_code',
      badge: 'Admin Scanner',
      title: 'Instant QR Scan Expiration Verification',
      description:
          'Scanning a student QR instantly displays valid, grace, or expired states with instant action to record renewal payments directly from the check-in sheet.',
      actionRoute: Routes.adminQrScanner,
      actionLabel: 'Open Scanner',
    ),
    const ReleaseChange(
      icon: Icons.image_rounded,
      rawIconName: 'image',
      badge: 'Zero Blinking',
      title: 'Stable Student Profile Photos & Image Caching',
      description:
          'Eliminated profile photo blinking across student passes by caching decoded base64 images in memory and removing redundant animation loops.',
    ),
    const ReleaseChange(
      icon: Icons.account_balance_rounded,
      rawIconName: 'account_balance',
      badge: 'Brand Identity',
      title: 'Dynamic Organization Logo on Digital Pass',
      description:
          'The digital smart access card now displays your official library logo dynamically on the front header with a subtle 3D watermark on the card background.',
    ),
    const ReleaseChange(
      icon: Icons.notifications_active_rounded,
      rawIconName: 'notifications',
      badge: 'Admin Header',
      title: 'Admin Notification Center & Theme Toggle',
      description:
          'Quick 1-tap Dark/Light theme toggle and real-time Notification Center added directly to the Admin Dashboard header with live unread alert badges.',
      actionRoute: Routes.adminHome,
      actionLabel: 'Go to Dashboard',
    ),
    const ReleaseChange(
      icon: Icons.badge_rounded,
      rawIconName: 'badge',
      badge: '100% Digital',
      title: 'Digital-Only Pass Architecture',
      description:
          'Streamlined student credentials into modern, interactive 3D virtual cards with dynamic verification QR codes, removing all redundant print layouts and PDF downloads.',
    ),
  ];

  /// Student-Friendly Highlights (v1.5.50)
  static final List<ReleaseChange> studentChanges = [
    const ReleaseChange(
      icon: Icons.cake_rounded,
      rawIconName: 'cake',
      badge: 'Student Delight',
      title: 'Birthday Celebration & 1-Tap Wi-Fi Password Copy',
      description:
          'Celebrate your special day with festive greetings and copy the high-speed study Wi-Fi password with a single tap directly from your dashboard.',
      actionRoute: Routes.studentHome,
      actionLabel: 'View Dashboard',
    ),
    const ReleaseChange(
      icon: Icons.timer_outlined,
      rawIconName: 'timer',
      badge: 'Focus Radar',
      title: 'Exam Countdown Widget for Your Course',
      description:
          'Stay locked in on your academic dreams with a live daily countdown timer dynamically tailored to your course (UPSC, MPSC, NEET, JEE, GATE, Banking, etc.).',
      actionRoute: Routes.studentHome,
      actionLabel: 'Check Countdown',
    ),
    const ReleaseChange(
      icon: Icons.lock_rounded,
      rawIconName: 'lock',
      badge: 'Seat Protection',
      title: 'Guaranteed Seat Hold & 1-Tap Renewal Flow',
      description:
          'Never lose your favorite desk. Active students get an exclusive seat reservation hold badge and a streamlined 1-tap renewal flow to lock in their seat effortlessly.',
      actionRoute: Routes.studentRenew,
      actionLabel: 'Review Renewals',
    ),
    const ReleaseChange(
      icon: Icons.volume_off_rounded,
      rawIconName: 'volume_off',
      badge: 'Quiet Study',
      title: 'Silent Reception & Noise Help Button',
      description:
          'Study in complete peace. Discreetly alert reception about noise, AC temperature, Wi-Fi issues, or desk hygiene without leaving your seat or causing a disturbance.',
      actionRoute: Routes.studentFeedback,
      actionLabel: 'Explore Help Desk',
    ),
    const ReleaseChange(
      icon: Icons.campaign_rounded,
      rawIconName: 'campaign',
      badge: 'Notice Board',
      title: 'Multi-Notice Carousel & Dedicated Notice Board',
      description:
          'Browse library announcements in a swipeable dashboard carousel with instant dismiss and view full historical circulars in the new Notice Board & Circulars hub.',
      actionRoute: Routes.studentAnnouncements,
      actionLabel: 'View Notices',
    ),
    const ReleaseChange(
      icon: Icons.arrow_back_rounded,
      rawIconName: 'navigation',
      badge: 'Seamless Nav',
      title: 'Smart Back Navigation & Zero Accidental Exits',
      description:
          'Pressing back from your Profile, Receipts, or Membership smoothly returns to your Home dashboard. Explicit back buttons added across all pages with double-tap exit protection.',
    ),
    const ReleaseChange(
      icon: Icons.badge_rounded,
      rawIconName: 'badge',
      badge: 'Smart Pass',
      title: 'Dynamic Pass Validity & 1-Tap Renewal',
      description:
          'Your Digital ID Card now dynamically reflects real-time status (Active, Grace, or Expired) with instant 1-tap renewal action to ensure your seat is retained.',
      actionRoute: Routes.studentRenew,
      actionLabel: 'Check Renewals',
    ),
    const ReleaseChange(
      icon: Icons.image_rounded,
      rawIconName: 'image',
      badge: 'Crisp Display',
      title: 'Rock-Solid Profile Photo & Smooth Pass',
      description:
          'Your profile photo on the digital smart pass now renders smoothly without any flickering or blinking, backed by instant image caching.',
    ),
    const ReleaseChange(
      icon: Icons.account_balance_rounded,
      rawIconName: 'account_balance',
      badge: 'Official Pass',
      title: 'Library Logo & 3D Security Seal',
      description:
          'Your digital pass now displays the official organization logo and authentic background watermark for verification.',
    ),
    const ReleaseChange(
      icon: Icons.dashboard_customize_rounded,
      rawIconName: 'dashboard',
      badge: 'Clean Home',
      title: 'Streamlined Student Dashboard',
      description:
          'Removed study streak and check-in widgets to give you instant, uninterrupted access to your Digital Smart Pass and desk allocation right at the top of your screen.',
    ),
    const ReleaseChange(
      icon: Icons.shield_outlined,
      rawIconName: 'shield',
      badge: 'Real Perks',
      title: 'Accurate Study Privileges & Facilities',
      description:
          'The Perks and Environment sections now reflect only the genuine facilities provided by your library. Air Conditioning and extra perks only appear if actually equipped.',
      actionRoute: Routes.studentHome,
      actionLabel: 'Explore Facilities',
    ),
    const ReleaseChange(
      icon: Icons.support_agent_rounded,
      rawIconName: 'support_agent',
      badge: 'Direct Contacts',
      title: 'Direct Owner, Admin & Manager Helplines',
      description:
          'Access separate direct contact numbers for the Library Owner, Admin, and Manager with instant Call and WhatsApp buttons directly from your profile and dashboard.',
      actionRoute: Routes.studentProfile,
      actionLabel: 'View Contacts',
    ),
    const ReleaseChange(
      icon: Icons.chair_rounded,
      rawIconName: 'chair',
      badge: 'Readable Desk',
      title: 'Universal Clean Seat Numbering',
      description:
          'Your assigned seat number is now formatted cleanly across all screens (Seat #2 [Cozy Hall]) instead of showing complex internal database coordinates.',
      actionRoute: Routes.studentSeatMap,
      actionLabel: 'View Seat Map',
    ),
    const ReleaseChange(
      icon: Icons.badge_rounded,
      rawIconName: 'badge',
      badge: 'Private & Secure',
      title: 'Clean Masked Government ID',
      description:
          'Your Aadhaar and Government ID numbers are now displayed securely in a standard masked format on your profile card.',
    ),
    const ReleaseChange(
      icon: Icons.support_agent_rounded,
      rawIconName: 'support_agent',
      badge: 'Manager Sync',
      title: 'Dynamic Library Admin Contact',
      description:
          'Instant real-time connection to your library administrator and manager with 1-tap call and pre-formatted WhatsApp assistance.',
    ),
    const ReleaseChange(
      icon: Icons.refresh_rounded,
      rawIconName: 'refresh',
      badge: 'Live Sync',
      title: 'Animated Instant Sync Button',
      description:
          'Smooth rotating sync button with haptic feedback to instantly synchronize your latest profile data, seat allocations, and library details.',
    ),
  ];

  /// Get role-specific items
  static List<ReleaseChange> getItemsForRole({required bool isStudent}) {
    return isStudent ? studentChanges : adminChanges;
  }

  /// Automatically check on app launch if the current version changelog has been shown
  static Future<void> checkAndShow(BuildContext context, {required bool isStudent}) async {
    if (_isShowingDialog) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final verName = packageInfo.version.isNotEmpty ? packageInfo.version : AppConstants.appVersion;
      final verCode = int.tryParse(packageInfo.buildNumber) ?? AppConstants.buildNumber;
      final verIdentifier = '$verName+$verCode';

      final prefs = await SharedPreferences.getInstance();
      final key = isStudent ? _keySeenStudent : _keySeenAdmin;
      final lastSeen = prefs.getString(key);

      // If already shown for this exact version, do not interrupt
      if (lastSeen == verIdentifier) {
        return;
      }

      // App has been updated or opened on new release! Show immediately!
      if (!context.mounted) return;

      _isShowingDialog = true;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WhatsNewDialog(
          isStudent: isStudent,
          versionName: verName,
          versionCode: verCode,
          isOnDemand: false,
          onDismiss: () async {
            _isShowingDialog = false;
            await prefs.setString(key, verIdentifier);
          },
        ),
      );
    } catch (e) {
      _isShowingDialog = false;
      if (kDebugMode) debugPrint('WhatsNewService checkAndShow failed: $e');
    }
  }

  /// Show changelog on-demand (e.g. from Settings or Profile) with ZERO latency
  static Future<void> showChangelog(BuildContext context, {required bool isStudent}) async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final verName = packageInfo.version.isNotEmpty ? packageInfo.version : AppConstants.appVersion;
      final verCode = int.tryParse(packageInfo.buildNumber) ?? AppConstants.buildNumber;

      if (!context.mounted) {
        _isShowingDialog = false;
        return;
      }

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => WhatsNewDialog(
          isStudent: isStudent,
          versionName: verName,
          versionCode: verCode,
          isOnDemand: true,
          onDismiss: () {
            _isShowingDialog = false;
          },
        ),
      );
    } catch (_) { /* intentionally silent */ }
    _isShowingDialog = false;
  }

  /// Fetch remote features in background (non-blocking)
  static Future<List<ReleaseChange>?> fetchRemoteFeatures({required bool isStudent}) async {
    try {
      final url = Uri.parse('$_updateJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(
        url,
        headers: {'Cache-Control': 'no-cache, no-store'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final fieldName = isStudent ? 'studentFeatures' : 'adminFeatures';
        final rawFeatures = json[fieldName] ?? json['features'];

        if (rawFeatures is List && rawFeatures.isNotEmpty) {
          final list = rawFeatures
              .whereType<Map<String, dynamic>>()
              .map((e) => ReleaseChange.fromJson(e))
              .toList();

          if (list.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            final cacheKey = isStudent ? _keyCachedStudentFeatures : _keyCachedAdminFeatures;
            await prefs.setString(cacheKey, jsonEncode(rawFeatures));
            return list;
          }
        }
      }
    } catch (_) { /* intentionally silent */ }
    return null;
  }
}

class WhatsNewDialog extends StatefulWidget {
  final bool isStudent;
  final String versionName;
  final int versionCode;
  final bool isOnDemand;
  final VoidCallback? onDismiss;

  const WhatsNewDialog({
    super.key,
    required this.isStudent,
    required this.versionName,
    required this.versionCode,
    this.isOnDemand = false,
    this.onDismiss,
  });

  @override
  State<WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<WhatsNewDialog> {
  late List<ReleaseChange> _items;

  @override
  void initState() {
    super.initState();
    // 1. Immediately initialize with the static role-specific items (0ms latency!)
    _items = WhatsNewService.getItemsForRole(isStudent: widget.isStudent);

    // 2. Fetch any remote overrides in background without blocking UI
    WhatsNewService.fetchRemoteFeatures(isStudent: widget.isStudent).then((remoteList) {
      if (remoteList != null && remoteList.isNotEmpty && mounted) {
        setState(() {
          _items = remoteList;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStudent = widget.isStudent;

    final headerTitle = widget.isOnDemand
        ? (isStudent ? "What's New for Students" : "What's New for Library Admins")
        : (isStudent ? "Welcome to Study Library v${widget.versionName}" : "App Updated to v${widget.versionName}!");

    final headerSubtitle = isStudent
        ? "Explore the latest student features and improvements"
        : "Explore new management tools, printing, and security controls";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isStudent
                          ? Colors.teal.withValues(alpha: 0.15)
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isStudent ? Icons.school_rounded : Icons.admin_panel_settings_rounded,
                      color: isStudent ? Colors.teal : theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isStudent ? Colors.teal : theme.colorScheme.primary)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isStudent ? 'STUDENT EDITION' : 'ADMIN WORKSPACE',
                                style: TextStyle(
                                  color: isStudent ? Colors.teal : theme.colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'v${widget.versionName} (${widget.versionCode})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () {
                      widget.onDismiss?.call();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                headerSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Feature List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isStudent
                                  ? Colors.teal.withValues(alpha: 0.12)
                                  : theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.icon,
                              size: 18,
                              color: isStudent ? Colors.teal : theme.colorScheme.primary,
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
                                        item.title,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (item.badge != null) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: (isStudent ? Colors.teal : theme.colorScheme.primary)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.badge!,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isStudent ? Colors.teal : theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                    fontSize: 11.5,
                                  ),
                                ),
                                if (item.actionRoute != null) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.arrow_forward_rounded, size: 12),
                                      label: Text(
                                        item.actionLabel ?? 'Try It Now',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () {
                                        widget.onDismiss?.call();
                                        Navigator.of(context).pop();
                                        context.push(item.actionRoute!);
                                      },
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
                ),
              ),

              const SizedBox(height: 16),

              // Action button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isStudent ? Colors.teal : null,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    widget.onDismiss?.call();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    widget.isOnDemand ? 'Done' : (isStudent ? 'Got it! Explore My Library' : 'Explore Admin Workspace'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
