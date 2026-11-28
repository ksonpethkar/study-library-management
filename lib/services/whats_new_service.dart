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
      case 'form':
      case 'tune':
        return Icons.tune_rounded;
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
      case 'sync':
      case 'refresh':
        return Icons.sync_rounded;
      case 'support_agent':
        return Icons.support_agent_rounded;
      case 'notifications':
      case 'notifications_active':
        return Icons.notifications_active_rounded;
      case 'navigation':
        return Icons.arrow_back_rounded;
      case 'image':
        return Icons.image_rounded;
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
    if (icon == Icons.document_scanner_rounded || icon == Icons.tune_rounded) return 'tune';
    if (icon == Icons.lock_outline_rounded) return 'lock';
    if (icon == Icons.sentiment_satisfied_alt_rounded) return 'sentiment_satisfied_alt';
    if (icon == Icons.event_seat_rounded) return 'seat';
    if (icon == Icons.receipt_long_rounded) return 'receipt';
    if (icon == Icons.campaign_rounded) return 'announcement';
    if (icon == Icons.palette_rounded) return 'palette';
    if (icon == Icons.qr_code_2_rounded) return 'qr_code';
    if (icon == Icons.system_update_rounded) return 'system_update';
    if (icon == Icons.sync_rounded) return 'sync';
    return 'default';
  }
}

class ReleaseVersionEntry {
  final String version;
  final int buildNumber;
  final String date;
  final String summary;
  final List<ReleaseChange> adminFeatures;
  final List<ReleaseChange> studentFeatures;

  const ReleaseVersionEntry({
    required this.version,
    required this.buildNumber,
    required this.date,
    required this.summary,
    required this.adminFeatures,
    required this.studentFeatures,
  });

  List<ReleaseChange> featuresForRole({required bool isStudent}) =>
      isStudent ? studentFeatures : adminFeatures;

  Map<String, dynamic> toJson() => {
        'version': version,
        'buildNumber': buildNumber,
        'date': date,
        'summary': summary,
        'adminFeatures': adminFeatures.map((e) => e.toJson()).toList(),
        'studentFeatures': studentFeatures.map((e) => e.toJson()).toList(),
      };

  factory ReleaseVersionEntry.fromJson(Map<String, dynamic> json) {
    final rawAdmin = (json['adminFeatures'] as List?)
            ?.whereType<Map>()
            .map((m) => ReleaseChange.fromJson(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
    final rawStudent = (json['studentFeatures'] as List?)
            ?.whereType<Map>()
            .map((m) => ReleaseChange.fromJson(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
    return ReleaseVersionEntry(
      version: (json['version'] ?? '').toString().trim(),
      buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 0,
      date: (json['date'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      adminFeatures: rawAdmin,
      studentFeatures: rawStudent,
    );
  }
}

class WhatsNewService {
  static const String currentVersionIdentifier = '1.5.62+2079';
  static const String _keySeenAdmin = 'last_seen_whats_new_admin';
  static const String _keySeenStudent = 'last_seen_whats_new_student';
  static const String _keyCachedAdminFeatures = 'cached_whats_new_admin_features';
  static const String _keyCachedStudentFeatures = 'cached_whats_new_student_features';
  static const String _keyCachedChangelog = 'cached_whats_new_changelog_v2';
  static const String _keyCachedBuildNumber = 'cached_whats_new_build_number';
  static const String _updateJsonUrl = 'https://study-lib-mgmt-2026.web.app/update.json';

  static bool _isShowingDialog = false;
  static List<ReleaseVersionEntry>? _memoryCachedChangelog;

  /// Fallback version-grouped changelog synced with v1.5.61 (Build 2078).
  static final List<ReleaseVersionEntry> builtInChangelog = [
    ReleaseVersionEntry(
      version: AppConstants.appVersion,
      buildNumber: AppConstants.buildNumber,
      date: '2026-11-26',
      summary:
          'Unified Form Builder parity across every form, Digital ID card, receipt & export; status-gated seat maps & canonical amenities; and live version-keyed release notes.',
      adminFeatures: [
        const ReleaseChange(
          icon: Icons.tune_rounded,
          rawIconName: 'tune',
          badge: 'Form Builder',
          title: 'Full Custom Field Parity Across Add, Edit, Cards & Exports',
          description:
              'Custom and built-in fields (Text, Long Text, Dropdown, Multi-Select, Date, Toggle, Regex Presets) now render live across Admin Add/Edit, Online Registration, Profile, ID Cards, Receipts, and CSV/Excel exports.',
          actionRoute: Routes.adminFormCustomizer,
          actionLabel: 'Open Form Builder',
        ),
        const ReleaseChange(
          icon: Icons.event_seat_rounded,
          rawIconName: 'seat',
          badge: 'Seat & Amenity Sync',
          title: 'Status-Gated Public Seat Maps & Single Amenity Catalog',
          description:
              'Reserved, Maintenance, and Occupied desks restrict booking on public/student seat maps, while Library Profile amenities act as the single canonical source of truth everywhere.',
          actionRoute: Routes.adminSeats,
          actionLabel: 'Open Seat Map',
        ),
        const ReleaseChange(
          icon: Icons.system_update_rounded,
          rawIconName: 'system_update',
          badge: 'Release Sync',
          title: 'Unified Version-Keyed What\'s New & Dynamic APK/Web Links',
          description:
              'What\'s New highlights now hydrate live per version across Web, APK, update banners, and the /download portal with verified release binary links.',
          actionRoute: Routes.adminMore,
          actionLabel: 'Check Updates',
        ),
      ],
      studentFeatures: [
        const ReleaseChange(
          icon: Icons.tune_rounded,
          rawIconName: 'tune',
          badge: 'Smart Forms',
          title: 'Upgraded Admission Forms & Full Profile Editing',
          description:
              'Registration & Profile Update forms now adapt dynamically with toggles, multi-select tags, custom validations, accurate blood group display, and Digital Pass custom tags.',
          actionRoute: Routes.studentProfile,
          actionLabel: 'View Profile',
        ),
        const ReleaseChange(
          icon: Icons.event_seat_rounded,
          rawIconName: 'seat',
          badge: 'Seat Map',
          title: 'Clear Status-Gated Seat Selection & Genuine Amenities',
          description:
              'See exact hall availability (Reserved, Maintenance, Occupied vs Available) and genuine library-equipped amenities without accidental booking triggers.',
          actionRoute: Routes.studentSeatMap,
          actionLabel: 'View Seat Map',
        ),
        const ReleaseChange(
          icon: Icons.system_update_rounded,
          rawIconName: 'system_update',
          badge: 'What\'s New',
          title: 'Version-Accurate Release Notes Across Web & App',
          description:
              'See the exact new features added in each build right inside What\'s New and when reloading a fresh web or APK release.',
          actionRoute: Routes.studentHome,
          actionLabel: 'Go Home',
        ),
      ],
    ),
    ReleaseVersionEntry(
      version: '1.5.59',
      buildNumber: 2076,
      date: '2026-11-23',
      summary: '3D Holographic Smart Pass specular tilt, live sonar radar desk map & spring micro-physics.',
      adminFeatures: [
        const ReleaseChange(
          icon: Icons.badge_rounded,
          rawIconName: 'badge',
          badge: 'Smart Pass',
          title: '3D Holographic Student Pass & Printable CR-80 PDFs',
          description:
              'Interactive 3D specular sheen virtual passes with live anti-screenshot ticker alongside printable CR-80 ID card PDFs and custom stamps.',
          actionRoute: Routes.adminIdCardTemplate,
          actionLabel: 'Customize Pass',
        ),
        const ReleaseChange(
          icon: Icons.calendar_month_rounded,
          rawIconName: 'card_membership',
          badge: 'Plan Engine',
          title: 'Dynamic Plan Transitions, Month-End Alignment & 48h Undo',
          description:
              'Seamless plan upgrades/downgrades, surplus wallet balance carry-forward, and 1-click 48-hour atomic plan reversion.',
          actionRoute: Routes.adminStudents,
          actionLabel: 'Student Directory',
        ),
        const ReleaseChange(
          icon: Icons.qr_code_2_rounded,
          rawIconName: 'qr_code',
          badge: 'QR & Ledger',
          title: 'Instant Pass Verification & Anti-Fraud UTR Defense',
          description:
              'Scan student passes at reception for instant validity checks plus duplicate UTR blocking and 10-second counter fee collection.',
          actionRoute: Routes.adminQrScanner,
          actionLabel: 'Open Scanner',
        ),
      ],
      studentFeatures: [
        const ReleaseChange(
          icon: Icons.badge_rounded,
          rawIconName: 'badge',
          badge: 'Digital Pass',
          title: 'Interactive 3D Holographic Pass & Live Verification QR',
          description:
              'Your digital pass features tilt physics, live status verification (Active, Grace, Expired), and 1-tap reception sharing.',
          actionRoute: Routes.studentIdCard,
          actionLabel: 'View My Pass',
        ),
        const ReleaseChange(
          icon: Icons.receipt_long_rounded,
          rawIconName: 'receipt',
          badge: 'Wallet & Plans',
          title: 'Month-End Aligned Plans, Credit Wallet & PDF Receipts',
          description:
              'Fair pro-rata plan adjustments, preserved wallet credits, and downloadable official PDF payment receipts.',
          actionRoute: Routes.studentReceipts,
          actionLabel: 'My Receipts',
        ),
        const ReleaseChange(
          icon: Icons.campaign_rounded,
          rawIconName: 'announcement',
          badge: 'Notice Board',
          title: 'Notice Board Carousel, Exam Countdown & Silent Desk Help',
          description:
              'Swipeable circulars with unread counts, live exam day countdown, and discreet reception assistance.',
          actionRoute: Routes.studentAnnouncements,
          actionLabel: 'View Notices',
        ),
      ],
    ),
  ];

  /// Concrete features exclusively relevant for Library Admins & Staff (flattened latest-first)
  static List<ReleaseChange> get adminChanges =>
      builtInChangelog.expand((e) => e.adminFeatures).toList();

  /// Student-Friendly Highlights (flattened latest-first)
  static List<ReleaseChange> get studentChanges =>
      builtInChangelog.expand((e) => e.studentFeatures).toList();

  /// Resolves version-grouped entries synchronously from memory cache or clean built-in fallback.
  static List<ReleaseVersionEntry> getVersionGroups({required bool isStudent}) {
    final mem = _memoryCachedChangelog;
    if (mem != null && mem.isNotEmpty) {
      final hasRoleItems = mem.any((e) => e.featuresForRole(isStudent: isStudent).isNotEmpty);
      if (hasRoleItems) return mem;
    }
    return builtInChangelog;
  }

  /// Get role-specific items synchronously (uses cached remote list if pre-hydrated!)
  static List<ReleaseChange> getItemsForRole({required bool isStudent}) {
    final groups = getVersionGroups(isStudent: isStudent);
    return groups.expand((g) => g.featuresForRole(isStudent: isStudent)).toList();
  }

  /// Hydrates `_memoryCachedChangelog` from SharedPreferences cleanly before dialog builds.
  static Future<void> _hydrateMemoryCache({int? currentBuildNumber}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBuild = prefs.getInt(_keyCachedBuildNumber) ?? 0;

      // Do not serve stale cached lists from an older build than the running app!
      if (currentBuildNumber != null && cachedBuild > 0 && cachedBuild < currentBuildNumber) {
        return;
      }

      final rawChangelog = prefs.getString(_keyCachedChangelog);
      if (rawChangelog != null && rawChangelog.isNotEmpty) {
        final decoded = jsonDecode(rawChangelog);
        if (decoded is List) {
          final parsed = decoded
              .whereType<Map>()
              .map((m) => ReleaseVersionEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          if (parsed.isNotEmpty) {
            _memoryCachedChangelog = parsed;
            return;
          }
        }
      }

      // Legacy flat-cache fallback hydration
      final rawAdminStr = prefs.getString(_keyCachedAdminFeatures);
      final rawStudentStr = prefs.getString(_keyCachedStudentFeatures);
      final adminList = (rawAdminStr != null && rawAdminStr.isNotEmpty)
          ? (jsonDecode(rawAdminStr) as List)
              .whereType<Map>()
              .map((e) => ReleaseChange.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <ReleaseChange>[];
      final studentList = (rawStudentStr != null && rawStudentStr.isNotEmpty)
          ? (jsonDecode(rawStudentStr) as List)
              .whereType<Map>()
              .map((e) => ReleaseChange.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <ReleaseChange>[];

      if (adminList.isNotEmpty || studentList.isNotEmpty) {
        _memoryCachedChangelog = [
          ReleaseVersionEntry(
            version: AppConstants.appVersion,
            buildNumber: cachedBuild > 0 ? cachedBuild : AppConstants.buildNumber,
            date: '',
            summary: '',
            adminFeatures: adminList,
            studentFeatures: studentList,
          ),
        ];
      }
    } catch (_) { /* intentionally silent */ }
  }

  static Future<({String versionName, int versionCode})> _resolveRuntimeVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final verName = packageInfo.version.isNotEmpty ? packageInfo.version : AppConstants.appVersion;
      final parsedCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final verCode = parsedCode > 0 ? parsedCode : AppConstants.buildNumber;
      return (versionName: verName, versionCode: verCode);
    } catch (_) {
      return (versionName: AppConstants.appVersion, versionCode: AppConstants.buildNumber);
    }
  }

  /// Automatically check on app launch if the current version changelog has been shown
  static Future<void> checkAndShow(BuildContext context, {required bool isStudent}) async {
    if (_isShowingDialog) return;

    try {
      final ver = await _resolveRuntimeVersion();
      final verIdentifier = '${ver.versionName}+${ver.versionCode}';

      final prefs = await SharedPreferences.getInstance();
      final key = isStudent ? _keySeenStudent : _keySeenAdmin;
      final lastSeen = prefs.getString(key);

      if (lastSeen == verIdentifier) {
        return;
      }

      await _hydrateMemoryCache(currentBuildNumber: ver.versionCode);
      if (!context.mounted) return;

      _isShowingDialog = true;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WhatsNewDialog(
          isStudent: isStudent,
          versionName: ver.versionName,
          versionCode: ver.versionCode,
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

  /// Show changelog on-demand (e.g. from Settings, Profile, or UpdateBanner)
  static Future<void> showChangelog(BuildContext context, {required bool isStudent}) async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    try {
      final ver = await _resolveRuntimeVersion();
      await _hydrateMemoryCache(currentBuildNumber: ver.versionCode);

      if (!context.mounted) {
        _isShowingDialog = false;
        return;
      }

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => WhatsNewDialog(
          isStudent: isStudent,
          versionName: ver.versionName,
          versionCode: ver.versionCode,
          isOnDemand: true,
          onDismiss: () {
            _isShowingDialog = false;
          },
        ),
      );
    } catch (_) { /* intentionally silent */ }
    _isShowingDialog = false;
  }

  /// Parses full version-keyed `changelog` (preferred) or falls back cleanly to top-level role arrays.
  static Future<List<ReleaseVersionEntry>?> fetchRemoteChangelog({required bool isStudent}) async {
    try {
      final url = Uri.parse('$_updateJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(
        url,
        headers: {'Cache-Control': 'no-cache, no-store'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final webObj = json['web'] as Map<String, dynamic>?;
        final remoteVer = (webObj?['version'] ?? json['latestVersion'] ?? AppConstants.appVersion).toString();
        final remoteBuild = (webObj?['buildNumber'] as num?)?.toInt() ??
            (json['latestBuild'] as num?)?.toInt() ??
            AppConstants.buildNumber;

        List<ReleaseVersionEntry> parsedEntries = [];
        final rawChangelog = json['changelog'];
        if (rawChangelog is List && rawChangelog.isNotEmpty) {
          parsedEntries = rawChangelog
              .whereType<Map>()
              .map((m) => ReleaseVersionEntry.fromJson(Map<String, dynamic>.from(m)))
              .where((e) => e.version.isNotEmpty)
              .toList();
        }

        // Also build single-entry fallback if changelog array isn't provided
        if (parsedEntries.isEmpty) {
          final rawAdmin = (json['adminFeatures'] as List?)
                  ?.whereType<Map>()
                  .map((e) => ReleaseChange.fromJson(Map<String, dynamic>.from(e)))
                  .toList() ??
              [];
          final rawStudent = (json['studentFeatures'] as List?)
                  ?.whereType<Map>()
                  .map((e) => ReleaseChange.fromJson(Map<String, dynamic>.from(e)))
                  .toList() ??
              [];
          if (rawAdmin.isNotEmpty || rawStudent.isNotEmpty) {
            parsedEntries = [
              ReleaseVersionEntry(
                version: remoteVer,
                buildNumber: remoteBuild,
                date: (webObj?['buildDate'] ?? '').toString(),
                summary: (json['releaseNotes'] ?? '').toString(),
                adminFeatures: rawAdmin,
                studentFeatures: rawStudent,
              ),
            ];
          }
        }

        if (parsedEntries.isNotEmpty) {
          _memoryCachedChangelog = parsedEntries;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_keyCachedBuildNumber, remoteBuild);
          await prefs.setString(
            _keyCachedChangelog,
            jsonEncode(parsedEntries.map((e) => e.toJson()).toList()),
          );
          final latestAdmin = parsedEntries.expand((e) => e.adminFeatures).map((f) => f.toJson()).toList();
          final latestStudent = parsedEntries.expand((e) => e.studentFeatures).map((f) => f.toJson()).toList();
          if (latestAdmin.isNotEmpty) {
            await prefs.setString(_keyCachedAdminFeatures, jsonEncode(latestAdmin));
          }
          if (latestStudent.isNotEmpty) {
            await prefs.setString(_keyCachedStudentFeatures, jsonEncode(latestStudent));
          }
          return parsedEntries;
        }
      }
    } catch (_) { /* intentionally silent */ }
    return null;
  }

  /// Legacy single-list API preserved for any caller wanting flat role features.
  static Future<List<ReleaseChange>?> fetchRemoteFeatures({required bool isStudent}) async {
    final groups = await fetchRemoteChangelog(isStudent: isStudent);
    if (groups == null || groups.isEmpty) return null;
    final items = groups.expand((g) => g.featuresForRole(isStudent: isStudent)).toList();
    return items.isNotEmpty ? items : null;
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
  late List<ReleaseVersionEntry> _entries;
  bool _showPreviousHistory = false;

  @override
  void initState() {
    super.initState();
    _entries = WhatsNewService.getVersionGroups(isStudent: widget.isStudent);

    // Fetch live multi-version changelog from update.json (non-blocking)
    WhatsNewService.fetchRemoteChangelog(isStudent: widget.isStudent).then((remoteGroups) {
      if (remoteGroups != null && remoteGroups.isNotEmpty && mounted) {
        final hasRoleItems = remoteGroups.any(
          (g) => g.featuresForRole(isStudent: widget.isStudent).isNotEmpty,
        );
        if (hasRoleItems) {
          setState(() {
            _entries = remoteGroups;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStudent = widget.isStudent;
    final accentColor = isStudent ? Colors.teal : theme.colorScheme.primary;

    final visibleEntries = _entries
        .where((e) => e.featuresForRole(isStudent: isStudent).isNotEmpty)
        .toList();
    final latestEntry = visibleEntries.isNotEmpty ? visibleEntries.first : null;
    final previousEntries = visibleEntries.length > 1 ? visibleEntries.sublist(1) : <ReleaseVersionEntry>[];

    final displayVer = latestEntry?.version.isNotEmpty == true ? latestEntry!.version : widget.versionName;
    final headerTitle = widget.isOnDemand
        ? (isStudent ? "What's New in v$displayVer" : "What's New in v$displayVer")
        : (isStudent ? "Welcome to v$displayVer!" : "Updated to v$displayVer!");

    final headerSubtitle = (latestEntry?.summary.isNotEmpty == true)
        ? latestEntry!.summary
        : (isStudent
            ? "Explore the latest features added in this release"
            : "Explore new library controls, reliability fixes, and tools");

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
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
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isStudent ? Icons.school_rounded : Icons.admin_panel_settings_rounded,
                      color: accentColor,
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
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isStudent ? 'STUDENT EDITION' : 'ADMIN WORKSPACE',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              'Running v${widget.versionName} (${widget.versionCode})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
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
              const SizedBox(height: 10),
              Text(
                headerSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Version-Grouped Feature List
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (latestEntry != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              '✨ NEW IN v${latestEntry.version}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: accentColor,
                              ),
                            ),
                          ),
                          if (latestEntry.date.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              latestEntry.date,
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final item in latestEntry.featuresForRole(isStudent: isStudent)) ...[
                        _buildFeatureCard(context, theme, item, accentColor, isHighlight: true),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (previousEntries.isNotEmpty) ...[
                      InkWell(
                        onTap: () => setState(() => _showPreviousHistory = !_showPreviousHistory),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                _showPreviousHistory ? Icons.expand_less_rounded : Icons.history_rounded,
                                size: 17,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _showPreviousHistory
                                      ? 'Hide Earlier Release Highlights'
                                      : 'View Earlier Updates (${previousEntries.map((e) => "v${e.version}").join(", ")})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Icon(
                                _showPreviousHistory ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 18,
                                color: theme.colorScheme.outline,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showPreviousHistory)
                        for (final entry in previousEntries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 6, left: 4),
                            child: Text(
                              'v${entry.version}${entry.date.isNotEmpty ? " • ${entry.date}" : ""}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                          for (final item in entry.featuresForRole(isStudent: isStudent)) ...[
                            _buildFeatureCard(context, theme, item, accentColor, isHighlight: false),
                            const SizedBox(height: 8),
                          ],
                        ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

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

  Widget _buildFeatureCard(
    BuildContext context,
    ThemeData theme,
    ReleaseChange item,
    Color accentColor, {
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isHighlight
            ? accentColor.withValues(alpha: 0.06)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: isHighlight
            ? Border.all(color: accentColor.withValues(alpha: 0.22))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: accentColor),
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
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.badge!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
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
  }
}
