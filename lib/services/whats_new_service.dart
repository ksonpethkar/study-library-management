import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReleaseChange {
  final IconData icon;
  final String title;
  final String description;
  final String? badge;
  final String? rawIconName;

  const ReleaseChange({
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
    this.rawIconName,
  });

  Map<String, dynamic> toJson() {
    return {
      'icon': rawIconName ?? _iconToString(icon),
      'title': title,
      'description': description,
      if (badge != null) 'badge': badge,
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
  static const String currentVersionIdentifier = '1.5.14+21';
  static const String _keySeenAdmin = 'last_seen_whats_new_admin';
  static const String _keySeenStudent = 'last_seen_whats_new_student';
  static const String _keyCachedAdminFeatures = 'cached_whats_new_admin_features';
  static const String _keyCachedStudentFeatures = 'cached_whats_new_student_features';
  static const String _updateJsonUrl = 'https://study-lib-mgmt-2026.web.app/update.json';

  static bool _isShowingDialog = false;

  /// Concrete features exclusively relevant for Library Admins & Staff (v1.5.14)
  static final List<ReleaseChange> adminChanges = [
    const ReleaseChange(
      icon: Icons.history_edu_rounded,
      rawIconName: 'history_edu',
      badge: 'Fixed',
      title: 'Audit Logs Now Visible',
      description:
          'Fixed a critical path mismatch — audit log entries are now correctly written to and read from the library-scoped path. All activity is now visible in Admin → Audit Logs.',
    ),
    const ReleaseChange(
      icon: Icons.download_rounded,
      rawIconName: 'download',
      badge: 'Fixed',
      title: 'Export Data — Independent Loading',
      description:
          'Each export button (Students, Payments) now shows its own loading spinner independently. Clicking one no longer freezes the other.',
    ),
    const ReleaseChange(
      icon: Icons.backup_rounded,
      rawIconName: 'backup',
      badge: 'Fixed',
      title: 'Backup — Document IDs Preserved',
      description:
          'Backup now correctly stores each document\'s Firestore ID. Restore was previously skipping all documents due to missing IDs — now fully functional.',
    ),
    const ReleaseChange(
      icon: Icons.timer_rounded,
      rawIconName: 'timer',
      badge: 'Fixed',
      title: 'Grace Period — Respects Admin Setting',
      description:
          'The automation service now reads your saved grace period (Settings → Grace Period) instead of ignoring it. Admin-configured values are always honoured.',
    ),
    const ReleaseChange(
      icon: Icons.notifications_rounded,
      rawIconName: 'notifications',
      badge: 'Fixed',
      title: 'Notification Settings — Duplicate Button Removed',
      description:
          'The duplicate "Save" button in Notification Settings has been removed. Only one save button remains at the bottom of the screen.',
    ),
    const ReleaseChange(
      icon: Icons.payment_rounded,
      rawIconName: 'payment',
      badge: 'Fixed',
      title: 'Payment Methods — Settings Synced',
      description:
          'Recording a payment now shows the same methods you configured in Settings → Payment Methods. Hardcoded fallback list replaced.',
    ),
    const ReleaseChange(
      icon: Icons.picture_as_pdf_rounded,
      rawIconName: 'picture_as_pdf',
      badge: 'Fixed',
      title: 'Receipt Watermark in Shared PDF',
      description:
          'Organisation logo watermark now correctly appears in shared/downloaded receipt PDFs, not just in the preview.',
    ),
    const ReleaseChange(
      icon: Icons.screenshot_monitor_rounded,
      rawIconName: 'screenshot_monitor',
      badge: 'New',
      title: 'Screenshot Protection Toggle',
      description:
          'Admins can now enable or disable screenshot & screen-recording protection globally from Security Settings. Payment, ID Card, and Receipt screens always enforce protection.',
    ),
    const ReleaseChange(
      icon: Icons.badge_rounded,
      rawIconName: 'badge',
      badge: 'New',
      title: 'Membership ID in Student Profile',
      description:
          'Student membership ID is now prominently shown in the student detail header. Long-press to copy it to clipboard.',
    ),
    const ReleaseChange(
      icon: Icons.drag_handle_rounded,
      rawIconName: 'drag_handle',
      badge: 'Fixed',
      title: 'Field Reordering Now Works',
      description:
          'Drag-to-reorder in Admin Settings → Form Fields (and Payment Methods) was silently broken due to a wrong callback name. Now fully functional.',
    ),
    const ReleaseChange(
      icon: Icons.arrow_back_rounded,
      rawIconName: 'arrow_back',
      badge: 'Fixed',
      title: 'Back Button — No Longer Closes App',
      description:
          'Pressing back on a Student Profile no longer exits the app when it\'s the root screen. Now correctly navigates to the student list.',
    ),
    const ReleaseChange(
      icon: Icons.image_rounded,
      rawIconName: 'image',
      badge: 'Fixed',
      title: 'Login Logo — Instant Branding',
      description:
          'Organisation logo and name are now cached locally, so they appear instantly on the login screen without waiting for a network request.',
    ),
  ];


  /// Concrete features exclusively relevant for Students (v1.5.12)
  static final List<ReleaseChange> studentChanges = [
    const ReleaseChange(
      icon: Icons.shield_rounded,
      rawIconName: 'shield',
      badge: 'Account Security',
      title: 'Play Integrity App Protection',
      description:
          'App communication is verified with Google Play Integrity attestation to safeguard your membership and attendance records.',
    ),
    const ReleaseChange(
      icon: Icons.receipt_long_rounded,
      rawIconName: 'receipt',
      badge: 'Fee Receipts',
      title: 'Digital Receipts with Official Stamp & ₹',
      description:
          'Access and download official fee receipts featuring genuine ₹ rupee symbols and verified library watermark seals.',
    ),
    const ReleaseChange(
      icon: Icons.alarm_rounded,
      rawIconName: 'alarm',
      badge: 'Grace Period',
      title: 'Automated Membership Status Badges',
      description:
          'Your membership tab now shows clear Active, Grace Period (7 days), or Expired status chips with 1-tap seat renewal.',
    ),
    const ReleaseChange(
      icon: Icons.history_rounded,
      rawIconName: 'history',
      badge: 'Activity Log',
      title: 'Verified Student History Ledger',
      description:
          'View real-time database activity logs of your plan activations, renewals, and seat updates.',
    ),
    const ReleaseChange(
      icon: Icons.badge_rounded,
      rawIconName: 'badge',
      badge: 'Digital Pass',
      title: 'Digital Student ID Card & Offline Pocket Badge',
      description:
          'Access your official library ID card with verified barcode and assigned seat anytime right from your profile, with instant PDF download.',
    ),
    const ReleaseChange(
      icon: Icons.event_seat_rounded,
      rawIconName: 'seat',
      badge: 'Live Availability',
      title: 'Real-Time Seat Status & Quick Check',
      description:
          'Check your assigned seat and view real-time open seats in your reading section directly from your phone.',
    ),
    const ReleaseChange(
      icon: Icons.lock_outline_rounded,
      rawIconName: 'lock',
      badge: 'Data Privacy',
      title: 'Aadhaar & Personal Data Encryption',
      description:
          'Your government ID numbers are now encrypted with AES-256 and masked (•••• •••• 1234) with a secure 1-tap reveal toggle.',
    ),
    const ReleaseChange(
      icon: Icons.receipt_long_rounded,
      rawIconName: 'receipt',
      badge: 'Instant Receipts',
      title: 'Digital Fee Receipts with Official Stamp',
      description:
          'View and download authentic fee receipts featuring your library official stamp and watermark verification.',
    ),
    const ReleaseChange(
      icon: Icons.campaign_rounded,
      rawIconName: 'announcement',
      badge: 'Live Alerts',
      title: 'Library Notices & Upcoming Holidays',
      description:
          'Stay informed with instant schedule announcements and upcoming library holiday lists right on your home tab.',
    ),
    const ReleaseChange(
      icon: Icons.auto_awesome_rounded,
      rawIconName: 'auto_awesome',
      badge: 'Performance',
      title: 'Instant Launch & Offline Caching',
      description:
          'Lightning-fast app launch with your library branding and offline access to your membership profile and receipts.',
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
      final verName = packageInfo.version.isNotEmpty ? packageInfo.version : '1.5.13';
      final verCode = int.tryParse(packageInfo.buildNumber) ?? 20;
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
      debugPrint('WhatsNewService checkAndShow failed: $e');
    }
  }

  /// Show changelog on-demand (e.g. from Settings or Profile) with ZERO latency
  static Future<void> showChangelog(BuildContext context, {required bool isStudent}) async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final verName = packageInfo.version.isNotEmpty ? packageInfo.version : '1.5.13';
      final verCode = int.tryParse(packageInfo.buildNumber) ?? 20;

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
    } catch (_) {}
    _isShowingDialog = false;
  }

  /// Fetch remote features in background (non-blocking)
  static Future<List<ReleaseChange>?> fetchRemoteFeatures({required bool isStudent}) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final url = Uri.parse('$_updateJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        client.close();

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
      client.close();
    } catch (_) {}
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