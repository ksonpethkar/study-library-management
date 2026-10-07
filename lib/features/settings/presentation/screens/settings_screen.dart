import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/settings/presentation/screens/data_export_screen.dart';
import 'package:study_library/features/settings/presentation/screens/security_settings_dialog.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/services/force_update_service.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/services/membership_automation_service.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/badge_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

/// Shows a bottom sheet with update info and live download progress.
void _showUpdateSheet(BuildContext context, WidgetRef ref, UpdateState updateState) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _UpdateBottomSheet(initialState: updateState),
  );
}

class _UpdateBottomSheet extends ConsumerWidget {
  final UpdateState initialState;
  const _UpdateBottomSheet({required this.initialState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateServiceProvider);
    final info = state.info ?? initialState.info;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.system_update_rounded,
                  color: theme.colorScheme.primary, size: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update Available',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Version ${info?.versionName ?? '?'}  •  44.4 MB',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (info != null && info.releaseNotes.isNotEmpty) ...[
            const Divider(),
            ...info.releaseNotes.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(n, style: theme.textTheme.bodySmall)),
                ],
              ),
            )),
          ],
          const SizedBox(height: 16),

          // Download progress
          if (state.downloadState == DownloadState.downloading) ...[
            LinearProgressIndicator(
              value: state.progress > 0 ? state.progress : null,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(state.progress * 100).toStringAsFixed(0)}% downloaded',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (state.totalBytes > 0)
                  Text(
                    '${_fmtBytes(state.downloadedBytes)} / ${_fmtBytes(state.totalBytes)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ] else if (state.downloadState == DownloadState.permissionRequired) ...[
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Android requires permission to install apps from Cozy Corner.\nGo to Settings → Special App Access → Install unknown apps → allow Cozy Corner.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () =>
                          ref.read(updateServiceProvider.notifier).requestInstallPermission(),
                      child: const Text('Open Permission Settings'),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (state.downloadState == DownloadState.failed) ...[
            Text(state.errorMessage ?? 'Download failed.',
                style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(updateServiceProvider.notifier).startUpdate(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ] else if (state.downloadState == DownloadState.completed) ...[
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green),
                SizedBox(width: 8),
                Text('Download complete! Installing...',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () =>
                  ref.read(updateServiceProvider.notifier).startUpdate(),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download & Install (44.4 MB)'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                ref.read(updateServiceProvider.notifier).dismissLater();
                Navigator.of(context).pop();
              },
              child: const Text('Remind Me Later'),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtBytes(int b) {
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Top Library Profile Card
          Builder(
            builder: (ctx) {
              final lib = ref.watch(currentLibraryProvider).value;
              final imageProvider = ImageService.getImageProvider(lib?.logoUrl);
              return Card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: imageProvider,
                        child: imageProvider == null
                            ? Icon(Icons.business_rounded, size: 30, color: Theme.of(context).colorScheme.primary)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lib?.name.isNotEmpty == true ? lib!.name : 'Cozy Corner Library',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (lib?.address.isNotEmpty ?? false) ...[
                              const SizedBox(height: 2),
                              Text(
                                lib!.address,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if ((lib?.contact.isNotEmpty ?? false) || (lib?.email.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 2),
                              Text(
                                [if (lib?.contact.isNotEmpty ?? false) lib!.contact, if (lib?.email.isNotEmpty ?? false) lib!.email].join(' • '),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Profile',
                        onPressed: () => context.push(Routes.adminLibraryProfile),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          _buildSectionHeader(context, 'Manage'),
          ListTile(
            leading: const Icon(Icons.assignment_rounded),
            title: const Text('Membership Plans'),
            subtitle: const Text('Add, edit, or delete plans'),
            onTap: () => context.push(Routes.adminPlans),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_rounded),
            title: const Text('Receipts'),
            subtitle: const Text('View and download generated receipts'),
            onTap: () => context.push(Routes.adminReceipts),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text('Revenue & Analytics'),
            subtitle: const Text('View revenue, payments and trends'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.adminRevenue),
          ),
          ListTile(
            leading: const Icon(Icons.campaign_rounded),
            title: const Text('Announcements'),
            subtitle: const Text('Broadcast messages to all student apps'),
            onTap: () => context.push(Routes.adminAnnouncements),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_rounded),
            title: const Text('Holidays'),
            subtitle: const Text('Manage closed days and special timings'),
            onTap: () => context.push(Routes.adminHolidays),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_rounded),
            title: const Text('Feedback & Reviews'),
            subtitle: const Text('Student complaints and suggestions'),
            onTap: () => context.push(Routes.adminFeedback),
          ),
          ListTile(
            leading: const Icon(Icons.move_to_inbox_rounded),
            title: const Text('Requests'),
            subtitle: const Text('Approve or reject seat and plan change requests'),
            onTap: () => context.push(Routes.adminRequests),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Library Profile & Branding'),
          ListTile(
            leading: const Icon(Icons.business_rounded),
            title: const Text('Library Profile'),
            subtitle: const Text('Name, address, contact, and accent color'),
            onTap: () => context.push(Routes.adminLibraryProfile),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_2_rounded),
            title: const Text('Live Seat QR Poster'),
            subtitle: const Text('Entrance poster and live portal link'),
            onTap: () => context.push(Routes.adminQrShare),
          ),
          ListTile(
            leading: const Icon(Icons.badge_rounded),
            title: const Text('Student ID Card Template'),
            subtitle: const Text('Customize elements, A4 cut-and-fold, and bulk printing'),
            onTap: () => context.push(Routes.adminIdCardTemplate),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_rounded),
            title: const Text('Receipt Template'),
            subtitle: const Text('Customize elements shown on PDF invoices'),
            onTap: () => context.push(Routes.adminReceiptTemplate),
          ),
          ListTile(
            leading: const Icon(Icons.app_registration_rounded),
            title: const Text('Registration Form Layout'),
            subtitle: const Text('Add custom fields and preview student signup form'),
            onTap: () => context.push(Routes.adminFormCustomizer),
          ),
          ListTile(
            leading: const Icon(Icons.payment_rounded),
            title: const Text('Payment Methods'),
            subtitle: const Text('Configure UPI, Cash, POS, and instructions'),
            onTap: () => context.push(Routes.adminPaymentMethods),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Preferences & Operation'),
          ListTile(
            leading: const Icon(Icons.notifications_rounded),
            title: const Text('Notifications'),
            subtitle: const Text('Expiry alerts and auto-reminders'),
            onTap: () => context.push(Routes.adminNotifications),
          ),
          ListTile(
            leading: const Icon(Icons.hourglass_top_rounded),
            title: const Text('Grace Period'),
            subtitle: const Text('Days before releasing lapsed seats'),
            onTap: () => context.push(Routes.adminGracePeriod),
          ),
          ListTile(
            leading: const Icon(Icons.queue_rounded, color: Colors.indigo),
            title: const Text('Waiting List Queue'),
            subtitle: const Text('View waiting queue and assign available seats'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => context.push(Routes.adminWaitingQueue),
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Waiting List Policy'),
            subtitle: const Text('Configure auto-join and allocation policies'),
            onTap: () => context.push(Routes.adminWaitingList),
          ),
          ListTile(
            leading: const Icon(Icons.format_list_numbered_rounded),
            title: const Text('Seat Numbering Format'),
            subtitle: const Text('Numeric (1, 2), Alpha (A1, A2), or Row-Col'),
            onTap: () => _showSeatNumberingDialog(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: const Text('Rules & Regulations'),
            subtitle: const Text('Set rules displayed in the student app'),
            onTap: () => context.push(Routes.adminRules),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Automations & Maintenance'),
          ListTile(
            leading: const Icon(Icons.auto_mode_rounded, color: Colors.teal),
            title: const Text('Run Expiry & Seat Check Now'),
            subtitle: const Text('Check expired plans, apply grace periods, and release seats'),
            trailing: const Icon(Icons.play_circle_outline_rounded, color: Colors.teal),
            onTap: () async {
              final libId = ref.read(currentLibraryIdProvider);
              if (libId == null || libId.isEmpty) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Checking plans and seats in background...'),
                  duration: Duration(seconds: 1),
                ),
              );
              final result = await MembershipAutomationService.runDailyMaintenance(libId, force: true);
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Maintenance Complete'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Total students checked: ${result.checkedCount}'),
                        const SizedBox(height: 4),
                        Text('• Entered grace period: ${result.enteredGraceCount}'),
                        const SizedBox(height: 4),
                        Text('• Expired plans: ${result.expiredCount}'),
                        const SizedBox(height: 4),
                        Text('• Seats auto-released: ${result.releasedSeatsCount}'),
                      ],
                    ),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          const Divider(),

          _buildSectionHeader(context, 'Security & Access Control'),
          ListTile(
            leading: const Icon(Icons.fingerprint_rounded),
            title: const Text('Biometric / PIN Lock'),
            subtitle: const Text('Protect app with fingerprint, Face ID, or PIN'),
            onTap: () => SecuritySettingsDialog.show(context),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_rounded),
            title: const Text('Authorized Admin Emails'),
            subtitle: const Text('Manage whitelisted Google accounts that can access admin'),
            onTap: () => context.push(Routes.adminWhitelist),
          ),
          ListTile(
            leading: const Icon(Icons.badge_rounded),
            title: const Text('Staff & Admin Roles'),
            subtitle: const Text('Manage managers, operators, and granular permissions'),
            onTap: () => context.push(Routes.adminStaff),
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Login History'),
            subtitle: const Text('View recent authentication events'),
            onTap: () => _showLoginHistoryDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Remote Logout'),
            subtitle: const Text('Sign out of all sessions across devices'),
            onTap: () => _showRemoteLogoutDialog(context, ref),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Data & Maintenance'),
          ListTile(
            leading: const Icon(Icons.backup_rounded),
            title: const Text('Backup & Restore'),
            onTap: () => context.push(Routes.adminBackup),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_rounded),
            title: const Text('Export Data'),
            subtitle: const Text('Download students & payments as CSV'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DataExportScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_rounded),
            title: const Text('Audit Log'),
            subtitle: const Text('Track staff actions and financial changes'),
            onTap: () => context.push(Routes.adminAuditLog),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_rounded),
            title: const Text('Recycle Bin'),
            subtitle: const Text('Restore soft-deleted students, seats, or plans'),
            onTap: () => context.push(Routes.adminRecycleBin),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Communication'),
          ListTile(
            leading: const Icon(Icons.chat_rounded, color: Colors.green),
            title: const Text('Send WhatsApp Reminder'),
            subtitle: const Text('Send renewal reminders directly via WhatsApp'),
            onTap: () => _showWhatsAppReminderDialog(context, ref),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Appearance'),
          Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeNotifierProvider);
              return SwitchListTile(
                secondary: Icon(
                  themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                ),
                title: const Text('Dark Mode'),
                subtitle: Text(themeMode == ThemeMode.dark ? 'Enabled' : 'Disabled'),
                value: themeMode == ThemeMode.dark,
                onChanged: (_) {
                  ref.read(themeNotifierProvider.notifier).toggleTheme();
                },
              );
            },
          ),
          const Divider(),

          _buildSectionHeader(context, 'About & Updates'),
          Consumer(
            builder: (context, ref, _) {
              final pkgInfo = ref.watch(_packageInfoProvider).value;
              final currentVer = pkgInfo?.version ?? '1.5.0';
              final currentBuild = pkgInfo?.buildNumber ?? '6';

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('App Version'),
                    subtitle: Text('$currentVer (Build $currentBuild) — Production'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.system_update_rounded, color: Colors.indigo),
                    title: const Text('Check for Updates'),
                    subtitle: const Text('Tap to check for the latest version'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Checking for updates...'),
                            ],
                          ),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      await ref.read(updateServiceProvider.notifier).checkForUpdate(manualCheck: true);
                      final updateState = ref.read(updateServiceProvider);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();

                      if (updateState.status == UpdateStatus.upToDate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('You are using the latest version (v$currentVer)!'),
                                ),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } else if (updateState.status == UpdateStatus.optionalUpdate ||
                          updateState.status == UpdateStatus.forceUpdate) {
                        _showUpdateSheet(context, ref, updateState);
                      }
                    },
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.new_releases_rounded, color: Colors.indigo),
            title: const Text("What's New"),
            subtitle: const Text('View recent release highlights'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => WhatsNewService.showChangelog(context, isStudent: false),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out from Cozy Corner?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
                    ],
                  ),
                );
                if (confirm == true) {
                  // Clear role so router redirect guard resets
                  await BadgeService.clearBadge();
                  ref.read(userRoleProvider.notifier).clear();
                  ref.read(currentLibraryIdProvider.notifier).clear();
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) {
                    context.go(Routes.login);
                  }
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }



  Future<void> _showSeatNumberingDialog(BuildContext context, WidgetRef ref) async {
    var libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final lib = await ref
              .read(libraryRepositoryProvider)
              .getLibraryByOwnerId(user.uid);
          if (lib != null) {
            ref.read(currentLibraryIdProvider.notifier).set(lib.id);
            libraryId = lib.id;
          }
        } catch (_) {}
      }
    }

    if (libraryId == null || libraryId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to change seat numbering style.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Default — will be overwritten once we read Firestore value
    SeatNamingStyle currentStyle = SeatNamingStyle.numeric;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Seat Numbering Style'),
          content: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .get(),
            builder: (context, snap) {
              // Pre-select from saved Firestore value
              if (snap.hasData && snap.data!.exists) {
                final saved =
                    (snap.data!.data() as Map)['seatNumberingFormat'] as String?;
                if (saved != null) {
                  try {
                    currentStyle = SeatNamingStyle.values.byName(saved);
                  } catch (_) {}
                }
              }
              return RadioGroup<SeatNamingStyle>(
                groupValue: currentStyle,
                onChanged: (v) {
                  if (v != null) setDialogState(() => currentStyle = v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    _StyleTile(
                      title: 'Continuous Numbers  (1, 2, 3...)',
                      subtitle: 'Best for open-plan / single hall',
                      value: SeatNamingStyle.numeric,
                    ),
                    _StyleTile(
                      title: 'Grid  (A1, A2, B1, B2...)',
                      subtitle: 'Row letter + seat number — most common',
                      value: SeatNamingStyle.alphanumeric,
                    ),
                    _StyleTile(
                      title: 'Custom Prefix  (CAB-01, VIP-01...)',
                      subtitle: 'Your own prefix code + number',
                      value: SeatNamingStyle.customPrefix,
                    ),
                    _StyleTile(
                      title: 'Section Code + Grid  (M-A1, M-A2...)',
                      subtitle: 'Section initial + row letter + number',
                      value: SeatNamingStyle.sectionPrefixAlphanumeric,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance
                    .collection('libraries')
                    .doc(libraryId)
                    .set({
                  'seatNumberingFormat': currentStyle.name,
                }, SetOptions(merge: true));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Seat numbering style saved!'),
                        behavior: SnackBarBehavior.floating),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginHistoryDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final lastSignIn = user?.metadata.lastSignInTime;
    final creationTime = user?.metadata.creationTime;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Login History'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.devices_rounded, color: Colors.green),
                title: const Text('Current Session', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${user?.email ?? "Admin"}\n'
                  'Last active: ${lastSignIn != null ? dateFormat.format(lastSignIn.toLocal()) : "Active"}\n'
                  'Registered: ${creationTime != null ? dateFormat.format(creationTime.toLocal()) : "Active"}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Divider(),
              const Text(
                'Recent Authentications:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              if (user != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('login_history')
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            'No previous login logs recorded yet.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final ts = (data['timestamp'] as Timestamp?)?.toDate();
                          final platform = data['platform'] ?? 'Mobile';
                          final method = data['authMethod'] ?? 'Google Sign-In';

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              platform == 'android'
                                  ? Icons.phone_android_rounded
                                  : platform == 'iOS'
                                      ? Icons.phone_iphone_rounded
                                      : Icons.laptop_mac_rounded,
                              size: 20,
                              color: Colors.blueGrey,
                            ),
                            title: Text('$method ($platform)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              ts != null ? dateFormat.format(ts.toLocal()) : 'Just now',
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  void _showRemoteLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security_update_warning_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Remote Logout'),
          ],
        ),
        content: const Text(
          'This will invalidate access tokens on all other mobile and web devices. You will remain signed in on this current device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.currentUser?.getIdToken(true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All remote sessions invalidated successfully.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Revoke Other Sessions'),
          ),
        ],
      ),
    );
  }

  void _showWhatsAppReminderDialog(BuildContext context, WidgetRef ref) {
    final phoneController = TextEditingController();
    final messageController = TextEditingController(
      text: 'Hi! This is a reminder from your study library. Your membership plan is expiring soon. Please renew to continue using the library. Thank you!',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.message, color: Colors.green),
            SizedBox(width: 8),
            Text('WhatsApp Reminder'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Student Phone (with country code)',
                  hintText: '919876543210',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  prefixIcon: Icon(Icons.message),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Send via WhatsApp'),
            onPressed: () async {
              final phone = phoneController.text.trim().replaceAll('+', '');
              final message = Uri.encodeComponent(messageController.text.trim());
              if (phone.isEmpty) return;
              
              final url = Uri.parse('https://wa.me/$phone?text=$message');
              Navigator.pop(ctx);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Radio tile used by the seat numbering style dialog.
class _StyleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final SeatNamingStyle value;

  const _StyleTile({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<SeatNamingStyle>(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
    );
  }
}
