import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/settings/presentation/screens/security_settings_dialog.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/services/force_update_service.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/badge_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:study_library/services/remote_config_service.dart';
import 'package:study_library/features/requests/presentation/providers/request_providers.dart';

String _getSafePlatformName() {
  if (kIsWeb) return 'Web Browser';
  try {
    return Platform.operatingSystem.toUpperCase();
  } catch (_) {
    return 'Web/Client';
  }
}

String _getSafePlatformVersion() {
  if (kIsWeb) return 'Web Client (Browser)';
  try {
    return '${Platform.operatingSystem} (${Platform.operatingSystemVersion})';
  } catch (_) {
    return 'Web Environment';
  }
}

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});



class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pkgInfo = ref.watch(_packageInfoProvider).value;
    final ver = pkgInfo?.version ?? '1.5.0';
    final build = pkgInfo?.buildNumber ?? '6';
    final requestCounts = ref.watch(requestModuleCountsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminHome),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Top Library Profile Card
          Builder(
            builder: (ctx) {
              final theme = Theme.of(ctx);
              final lib = ref.watch(currentLibraryProvider).value;
              final imageProvider = ImageService.getImageProvider(lib?.logoUrl);
              return Card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showOrganizationDetailsDialog(context, lib),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage: imageProvider,
                          child: imageProvider == null
                              ? Icon(Icons.business_rounded, size: 30, color: theme.colorScheme.primary)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lib?.name.isNotEmpty == true ? lib!.name : 'Study Library',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (lib?.address.isNotEmpty ?? false) ...[
                                const SizedBox(height: 2),
                                Text(
                                  lib!.address,
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if ((lib?.contact.isNotEmpty ?? false) || (lib?.email.isNotEmpty ?? false)) ...[
                                const SizedBox(height: 2),
                                Text(
                                  [if (lib?.contact.isNotEmpty ?? false) lib!.contact, if (lib?.email.isNotEmpty ?? false) lib!.email].join(' • '),
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
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
                ),
              );
            },
          ),
          // ── Action Required Pending Requests Hero Card ──
          if (requestCounts.hasAnyActionable)
            _buildPendingActionsHeroCard(context, requestCounts),

          // ── High-Frequency Quick Launch Tiles ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: _QuickLaunchCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Revenue',
                    subtitle: 'Profit & Trends',
                    color: const Color(0xFF059669),
                    onTap: () => context.push(Routes.adminRevenue),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickLaunchCard(
                    icon: Icons.assignment_rounded,
                    title: 'Plans',
                    subtitle: 'Tiers & Pricing',
                    color: const Color(0xFF2563EB),
                    onTap: () => context.push(Routes.adminPlans),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickLaunchCard(
                    icon: Icons.campaign_rounded,
                    title: 'Broadcast',
                    subtitle: 'Notices & Alerts',
                    color: const Color(0xFFD97706),
                    onTap: () => context.push(Routes.adminAnnouncements),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickLaunchCard(
                    icon: Icons.cloud_sync_rounded,
                    title: 'Backup',
                    subtitle: 'Database Backup',
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.push(Routes.adminBackup),
                  ),
                ),
              ],
            ),
          ),

          // ── Group 1: Operations & Management ──
          _buildGroupedSection(
            context,
            title: 'OPERATIONS & MANAGEMENT',
            children: [
              _buildSettingsTile(
                icon: Icons.assignment_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Membership Plans',
                subtitle: 'Pricing tiers, validity durations & discounts',
                onTap: () => context.push(Routes.adminPlans),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.receipt_rounded,
                iconColor: const Color(0xFF059669),
                title: 'Receipts & Invoices',
                subtitle: 'View, download, and share fee receipts',
                onTap: () => context.push(Routes.adminReceipts),
              ),
              if (RemoteConfigService.enableRevenueDashboard) ...[
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Revenue & Analytics',
                  subtitle: 'Track revenue, expenses, net profit & trends',
                  onTap: () => context.push(Routes.adminRevenue),
                ),
              ],
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.campaign_rounded,
                iconColor: const Color(0xFFD97706),
                title: 'Announcements & Notices',
                subtitle: 'Publish notice board alerts and banners to students',
                onTap: () => context.push(Routes.adminAnnouncements),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFFDC2626),
                title: 'Holidays & Closures',
                subtitle: 'Manage library holidays and closed dates',
                onTap: () => context.push(Routes.adminHolidays),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.feedback_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: 'Student Feedback & Complaints',
                subtitle: 'Review student suggestions, queries & issues',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (requestCounts.openFeedbackCount > 0)
                      _buildCountBadge(requestCounts.openFeedbackCount, color: const Color(0xFF7C3AED), suffix: 'Open'),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
                onTap: () => context.push(Routes.adminFeedback),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.move_to_inbox_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Admissions & Seat Requests',
                subtitle: 'Approve or reject new registrations & seat changes',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (requestCounts.totalPending > 0)
                      _buildCountBadge(requestCounts.totalPending, color: Colors.red.shade600, suffix: 'Pending'),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
                onTap: () => context.push(Routes.adminRequests),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.hourglass_top_rounded,
                iconColor: const Color(0xFF6366F1),
                title: 'Waiting List Queue',
                subtitle: 'Track students in line for seats & notify availability',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (requestCounts.waitingListCount > 0)
                      _buildCountBadge(requestCounts.waitingListCount, color: const Color(0xFF6366F1), suffix: 'Waiting'),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
                onTap: () => context.push(Routes.adminWaitingList),
              ),
            ],
          ),

          // ── Group 2: Library Profile & Templates ──
          _buildGroupedSection(
            context,
            title: 'FACILITY PROFILE & TEMPLATES',
            children: [
              _buildSettingsTile(
                icon: Icons.business_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Library Profile & Facilities',
                subtitle: 'Name, logo, contact, operating hours & amenities',
                onTap: () => context.push(Routes.adminLibraryProfile),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.qr_code_2_rounded,
                iconColor: const Color(0xFF059669),
                title: 'Entrance QR Poster & Portal',
                subtitle: 'Print A4 entrance poster and share live portal link',
                onTap: () => context.push(Routes.adminQrShare),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.badge_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: 'Student ID Card Template',
                subtitle: 'Customize card layout, visible fields & back-side rules',
                onTap: () => context.push(Routes.adminIdCardTemplate),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFFD97706),
                title: 'Receipt Template & Branding',
                subtitle: 'Customize layout, digital stamp, watermark & terms',
                onTap: () => context.push(Routes.adminReceiptTemplate),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.app_registration_rounded,
                iconColor: const Color(0xFF0284C7),
                title: 'Admission Form Builder',
                subtitle: 'Configure required fields and student signup preview',
                onTap: () => context.push(Routes.adminFormCustomizer),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.payment_rounded,
                iconColor: const Color(0xFF059669),
                title: 'Payment Methods & UPI',
                subtitle: 'Configure UPI QR, bank account details & cash desk',
                onTap: () => context.push(Routes.adminPaymentMethods),
              ),
            ],
          ),

          // ── Group 3: Preferences & Automation ──
          _buildGroupedSection(
            context,
            title: 'PREFERENCES & AUTOMATION',
            children: [
              _buildSettingsTile(
                icon: Icons.hub_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Communications & Automation',
                subtitle: 'WhatsApp, SMS, Telegram channels & automated alerts',
                onTap: () => context.push(Routes.adminCommunications),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.hourglass_top_rounded,
                iconColor: const Color(0xFFD97706),
                title: 'Grace Period & Renewal Buffer',
                subtitle: 'Buffer days allowed before releasing expired seats',
                onTap: () => context.push(Routes.adminGracePeriod),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.assignment_return_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Cancellation & Study Freeze Policy',
                subtitle: 'Early exit processing fee, refund policy & 10+ days freeze',
                onTap: () => _showCancellationPolicyDialog(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.people_outline_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: 'Waiting List & Capacity',
                subtitle: 'Live queue, seat holding window & waitlist policies',
                onTap: () => context.push(Routes.adminWaitingList),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.gavel_rounded,
                iconColor: const Color(0xFFDC2626),
                title: 'Library Rules & Guidelines',
                subtitle: 'Code of conduct displayed inside student apps',
                onTap: () => context.push(Routes.adminRules),
              ),
            ],
          ),

          // ── Group 4: Security & Access Control ──
          _buildGroupedSection(
            context,
            title: 'SECURITY & ACCESS CONTROL',
            children: [
              _buildSettingsTile(
                icon: Icons.fingerprint_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'App Lock & Biometrics',
                subtitle: 'Fingerprint, PIN lock, auto-lock & screen privacy',
                onTap: () {
                  final user = FirebaseAuth.instance.currentUser;
                  SecuritySettingsDialog.show(
                    context,
                    isStudent: false,
                    authUid: user?.uid,
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.admin_panel_settings_rounded,
                iconColor: const Color(0xFF059669),
                title: 'Staff & Permissions',
                subtitle: 'Invite team members and configure role-based access',
                onTap: () => context.push(Routes.adminStaff),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.devices_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: 'Device & Session Security',
                subtitle: 'Review active logins, device details & revoke sessions',
                onTap: () => _showDeviceSessionSecurityDialog(context, ref),
              ),
            ],
          ),

          // ── Group 5: Data & Maintenance ──
          _buildGroupedSection(
            context,
            title: 'DATA & MAINTENANCE',
            children: [
              _buildSettingsTile(
                icon: Icons.cloud_sync_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Database Backup & Restore',
                subtitle: 'Export or restore complete library database (JSON)',
                onTap: () => context.push(Routes.adminBackup),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.file_download_outlined,
                iconColor: const Color(0xFF059669),
                title: 'Data Export & Reports',
                subtitle: 'Download Excel/CSV reports for students, dues & finances',
                onTap: () => context.push(Routes.adminDataExport),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.history_rounded,
                iconColor: const Color(0xFFD97706),
                title: 'Audit Trail & Activity Log',
                subtitle: 'Track staff actions, financial changes & system events',
                onTap: () => context.push(Routes.adminAuditLog),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.delete_outline_rounded,
                iconColor: const Color(0xFFDC2626),
                title: 'Recycle Bin',
                subtitle: 'Restore soft-deleted students, payments, plans & sections',
                onTap: () => context.push(Routes.adminRecycleBin),
              ),
            ],
          ),

          // ── Group 6: System & About ──
          _buildGroupedSection(
            context,
            title: 'SYSTEM PREFERENCES & ABOUT',
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final themeMode = ref.watch(themeNotifierProvider);
                  final isDark = themeMode == ThemeMode.dark;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        size: 20,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    title: const Text('Dark Theme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text(isDark ? 'Dark theme enabled' : 'Light theme enabled', style: const TextStyle(fontSize: 11.5)),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) => ref.read(themeNotifierProvider.notifier).toggleTheme(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'About Cozy Corner',
                subtitle: 'App version, build details & system info',
                onTap: () => _showAboutAppDialog(context, ref, ver, build),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.system_update_rounded,
                iconColor: const Color(0xFF059669),
                title: 'Check for Updates',
                subtitle: 'Check for the latest version and features',
                onTap: () {
                  ref.read(updateServiceProvider.notifier).checkForUpdate(manualCheck: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Checking for updates…'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: "What's New",
                subtitle: 'View recent updates and release notes',
                onTap: () => WhatsNewService.showChangelog(context, isStudent: false),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF64748B),
                title: 'Terms of Service',
                subtitle: 'Usage terms and conditions',
                onTap: () => context.push(Routes.terms),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF64748B),
                title: 'Privacy Policy',
                subtitle: 'Data protection and privacy guidelines',
                onTap: () => context.push(Routes.privacyPolicy),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.headset_mic_rounded,
                iconColor: const Color(0xFF059669),
                title: 'Support & Help Desk',
                subtitle: 'Contact support via WhatsApp, phone, or email',
                onTap: () => _showSupportDialog(context, ref, ver, build),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                final lib = ref.read(currentLibraryProvider).value;
                final libName = lib?.name.isNotEmpty == true ? ' from ${lib!.name}' : '';
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: Text('Are you sure you want to sign out$libName?'),
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

  Widget _buildCountBadge(int count, {Color? color, String? suffix}) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? Colors.red.shade600,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        suffix != null ? '$count $suffix' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPendingActionsHeroCard(BuildContext context, RequestModuleCounts counts) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D1F08) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : const Color(0xFFFCD34D),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notification_important_rounded, size: 20, color: Color(0xFFD97706)),
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
                              'Action Required: ${counts.totalActionableItems} Pending Item${counts.totalActionableItems > 1 ? "s" : ""}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${counts.totalActionableItems}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        counts.detailedSummary,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Clickable Quick-Jump Pills to specific modules
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (counts.admissionsPending > 0)
                  _buildHeroPill(
                    label: '${counts.admissionsPending} Admissions',
                    icon: Icons.school_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () => context.push('${Routes.adminRequests}?category=registration'),
                  ),
                if (counts.seatChangesPending > 0)
                  _buildHeroPill(
                    label: '${counts.seatChangesPending} Seat Shifts',
                    icon: Icons.event_seat_rounded,
                    color: const Color(0xFFD97706),
                    onTap: () => context.push('${Routes.adminRequests}?category=seat_change'),
                  ),
                if (counts.renewalsPending > 0)
                  _buildHeroPill(
                    label: '${counts.renewalsPending} Plan Renewals',
                    icon: Icons.autorenew_rounded,
                    color: const Color(0xFF059669),
                    onTap: () => context.push('${Routes.adminRequests}?category=renewal'),
                  ),
                if (counts.profileUpdatesPending > 0)
                  _buildHeroPill(
                    label: '${counts.profileUpdatesPending} Profile Edits',
                    icon: Icons.person_outline_rounded,
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.push('${Routes.adminRequests}?category=profile_update'),
                  ),
                if (counts.openFeedbackCount > 0)
                  _buildHeroPill(
                    label: '${counts.openFeedbackCount} Feedbacks',
                    icon: Icons.feedback_outlined,
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.push(Routes.adminFeedback),
                  ),
                if (counts.waitingListCount > 0)
                  _buildHeroPill(
                    label: '${counts.waitingListCount} in Waiting List',
                    icon: Icons.hourglass_top_rounded,
                    color: const Color(0xFF6366F1),
                    onTap: () => context.push(Routes.adminWaitingList),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => context.push(Routes.adminRequests),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Open Requests Hub',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPill({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 3),
            Icon(Icons.arrow_forward_ios_rounded, size: 9, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedSection(BuildContext context, {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E28) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFF64748B)).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? const Color(0xFF475569)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  void _showDeviceSessionSecurityDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final lastSignIn = user?.metadata.lastSignInTime;
    final creationTime = user?.metadata.creationTime;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollController,
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
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.devices_rounded, color: Colors.blue, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Device & Session Security',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Current Session Card (Theme-Aware High Contrast)
              Card(
                elevation: 0,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFEFF6FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                        : const Color(0xFF93C5FD),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green.withValues(alpha: 0.15),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Active Session',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? 'Logged In Administrator',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF1E40AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Last authenticated: ${lastSignIn != null ? dateFormat.format(lastSignIn.toLocal()) : "Active"} • Created: ${creationTime != null ? dateFormat.format(creationTime.toLocal()) : "Active"}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Remote Logout Action
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.deepOrange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Remote Session Invalidation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lost a phone or logged in on a public computer? Invalidate tokens on all other devices immediately while staying signed in here.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Revoke Other Sessions?'),
                                content: const Text(
                                  'This will sign out all other devices logged into this account. Continue?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Revoke Sessions'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await FirebaseAuth.instance.currentUser?.getIdToken(true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('All other remote sessions invalidated successfully! ✓'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.phonelink_erase_rounded, size: 18),
                          label: const Text('Sign Out All Other Devices'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepOrange,
                            side: const BorderSide(color: Colors.deepOrange),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Login History
              Text(
                'Recent Authentications & Devices',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (user != null)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            'No previous login history recorded yet.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final rawTs = data['timestamp'];
                        final ts = rawTs is Timestamp
                            ? rawTs.toDate()
                            : rawTs is DateTime
                                ? rawTs
                                : rawTs is String
                                    ? DateTime.tryParse(rawTs)
                                    : null;
                        final platform = data['platform'] ?? 'Web/Desktop';
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
                          title: Text(
                            '$method ($platform)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            ts != null ? dateFormat.format(ts.toLocal()) : 'Recently',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutAppDialog(BuildContext context, WidgetRef ref, String ver, String build) {
    final theme = Theme.of(context);
    final lib = ref.watch(currentLibraryProvider).value;
    final imageProvider = ImageService.getImageProvider(lib?.logoUrl);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageProvider != null
                    ? Image(
                        image: imageProvider,
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      )
                    : Image.asset(
                        'assets/images/app_logo_transparent.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.local_library_rounded,
                          color: theme.colorScheme.primary,
                          size: 26,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lib?.name.isNotEmpty == true ? lib!.name : 'Cozy Corner',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    lib?.tagline.isNotEmpty == true ? lib!.tagline : 'Study Library Management System',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Library Center Profile Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: imageProvider,
                            child: imageProvider == null
                                ? Icon(Icons.business_rounded, color: theme.colorScheme.primary, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lib?.name.isNotEmpty == true ? lib!.name : 'Study Library',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 2,
                                ),
                                if (lib?.tagline.isNotEmpty == true)
                                  Text(
                                    lib!.tagline,
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (lib?.address.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lib!.address,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (lib?.operatingHours.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Hours: ${lib!.operatingHours}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (lib?.facilities.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: lib!.facilities.take(5).map((facility) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                facility,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text('Edit Library Profile', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push(Routes.adminLibraryProfile);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // System Specs Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      _buildInfoRow(context, Icons.verified_outlined, 'Version', 'v$ver (Build $build)'),
                      const SizedBox(height: 8),
                      _buildInfoRow(context, Icons.cloud_done_outlined, 'Backend', 'Firebase Cloud Services (Live)'),
                      const SizedBox(height: 8),
                      _buildInfoRow(context, Icons.devices_rounded, 'Platform', _getSafePlatformName()),
                      const SizedBox(height: 8),
                      _buildInfoRow(context, Icons.copyright_rounded, 'Copyright', '© 2026 Cozy Corner'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Info'),
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'Cozy Corner (Study Library)\n'
                    'Version: v$ver (Build $build)\n'
                    'Platform: ${_getSafePlatformVersion()}\n'
                    'Library: ${lib?.name ?? 'Cozy Corner'} (ID: ${lib?.id ?? 'N/A'})',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App details copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showLicensePage(
                context: context,
                applicationName: 'Cozy Corner',
                applicationVersion: 'v$ver (Build $build)',
              );
            },
            child: const Text('Licenses'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showOrganizationDetailsDialog(BuildContext context, dynamic lib) {
    final theme = Theme.of(context);
    final logoProvider = ImageService.getImageProvider(lib?.logoUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        title: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: logoProvider,
              child: logoProvider == null
                  ? Icon(Icons.business_rounded, color: theme.colorScheme.primary, size: 24)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lib?.name.isNotEmpty == true ? lib!.name : 'Study Library',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Organization Profile',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            if (lib?.address.isNotEmpty == true) ...[
              _buildInfoRow(context, Icons.location_on_outlined, 'Address', lib!.address),
              const SizedBox(height: 8),
            ],
            if (lib?.contact.isNotEmpty == true || lib?.helplineNumber.isNotEmpty == true) ...[
              _buildInfoRow(
                context,
                Icons.phone_outlined,
                'Helpline',
                lib?.effectiveContact.isNotEmpty == true
                    ? lib!.effectiveContact
                    : (lib?.effectiveHelpline ?? ''),
              ),
              const SizedBox(height: 8),
            ],
            if (lib?.email.isNotEmpty == true) ...[
              _buildInfoRow(context, Icons.email_outlined, 'Email', lib!.email),
              const SizedBox(height: 8),
            ],
            if (lib?.operatingHours.isNotEmpty == true) ...[
              _buildInfoRow(context, Icons.access_time_rounded, 'Hours', lib!.operatingHours),
              const SizedBox(height: 8),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(Routes.adminLibraryProfile);
            },
            child: const Text('Edit Profile'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editDeveloperEmail(BuildContext context, String libraryId, String currentEmail) async {
    final controller = TextEditingController(text: currentEmail);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, size: 22),
            SizedBox(width: 8),
            Text('Developer Support Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the developer or platform support email for receiving bug reports and inquiries:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Developer Support Email *',
                  hintText: 'e.g. dev@thecozycorner.in',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a valid email address';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dlgCtx, controller.text.trim());
              }
            },
            child: const Text('Save Email'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty && context.mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('settings')
            .doc('support')
            .set({
          'developerEmail': updated,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .set({
          'developerEmail': updated,
        }, SetOptions(merge: true));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Developer support email updated to $updated'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update email: $e')),
          );
        }
      }
    }
  }

  void _showSupportDialog(BuildContext context, WidgetRef ref, String ver, String build) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final lib = ref.watch(currentLibraryProvider).value;
          final helpline = lib?.effectiveContact.isNotEmpty == true
              ? lib!.effectiveContact
              : (lib?.effectiveHelpline ?? '');
          final whatsapp = lib?.whatsappNumber.isNotEmpty == true
              ? lib!.whatsappNumber
              : helpline;
          final hours = lib?.operatingHours.isNotEmpty == true
              ? lib!.operatingHours
              : '6:00 AM – 11:00 PM';

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.support_agent_rounded, color: theme.colorScheme.primary, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Support & Help Desk',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                lib?.name.isNotEmpty == true ? lib!.name : 'Facility & Technical Assistance',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                    // Facility Help Desk Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.storefront_rounded, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Library Member Help Desk',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Live Desk',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Desk Hours: $hours',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (helpline.isNotEmpty)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.phone_outlined, size: 18),
                                    label: const Text('Call Desk', style: TextStyle(fontSize: 13)),
                                    onPressed: () async {
                                      final uri = Uri.parse('tel:$helpline');
                                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                                    },
                                  ),
                                ),
                              if (helpline.isNotEmpty && whatsapp.isNotEmpty)
                                const SizedBox(width: 10),
                              if (whatsapp.isNotEmpty)
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                    label: const Text('WhatsApp', style: TextStyle(fontSize: 13)),
                                    onPressed: () async {
                                      final cleanNum = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
                                      final msg = Uri.encodeComponent('Hello ${lib?.name ?? 'Library'}, I need assistance.');
                                      final uri = Uri.parse('https://wa.me/$cleanNum?text=$msg');
                                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                                    },
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('Edit Help Desk Details', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.push(Routes.adminLibraryProfile);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Technical Support Section
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: (lib?.id != null && lib!.id.isNotEmpty)
                          ? FirebaseFirestore.instance
                              .collection('libraries')
                              .doc(lib.id)
                              .collection('settings')
                              .doc('support')
                              .snapshots()
                          : const Stream.empty(),
                      builder: (context, supportSnap) {
                        final devEmail = supportSnap.data?.data()?['developerEmail'] as String? ??
                            (lib?.email.isNotEmpty == true ? lib!.email : 'thecozycornersc@gmail.com');

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.terminal_rounded, size: 18, color: theme.colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Platform & Bug Support',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    icon: const Icon(Icons.edit_outlined, size: 14),
                                    label: const Text('Edit Email', style: TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      if (lib?.id != null) {
                                        _editDeveloperEmail(context, lib!.id, devEmail);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Icon(Icons.email_outlined, color: theme.colorScheme.primary),
                                title: const Text('Email Developer Support', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(devEmail, style: const TextStyle(fontSize: 12)),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                onTap: () async {
                                  final uri = Uri.parse('mailto:$devEmail?subject=Support%20Request%20-%20v$ver%20(Build%20$build)&body=Library:%20${lib?.name}%20(ID:%20${lib?.id})%0APlatform:%20${_getSafePlatformVersion()}');
                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCancellationPolicyDialog(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    double fee = 100.0;
    bool autoRelease = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('cancellation_policy')
          .get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        fee = (d['cancellationFee'] as num?)?.toDouble() ?? 100.0;
        autoRelease = d['autoReleaseSeat'] as bool? ?? true;
      }
    } catch (_) {}

    if (!context.mounted) return;

    final feeCtrl = TextEditingController(text: fee.toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: const Icon(Icons.assignment_return_rounded, color: Colors.red),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cancellation & Exit Policy',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure how refunds, early seat exits, and study vacation freezes are processed for your library.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: feeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      decoration: InputDecoration(
                        labelText: 'Processing / Seat Cancellation Fee (₹)',
                        hintText: 'e.g. 100',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Deducted from gross refund during mid-cycle exits',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.ac_unit_rounded, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Study Vacation / Freeze Threshold',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Enforced rule: Memberships can only be frozen for 10 or more consecutive days. Breaks of less than 10 days do not extend validity or cycle ends.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-release seat on exit', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Instantly marks the desk as vacant when student early exit is confirmed', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                      value: autoRelease,
                      onChanged: (val) => setDlgState(() => autoRelease = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save Policy'),
                onPressed: () async {
                  final newFee = double.tryParse(feeCtrl.text.trim()) ?? fee;
                  try {
                    await FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('settings')
                        .doc('cancellation_policy')
                        .set({
                      'cancellationFee': newFee,
                      'minFreezeDays': 10,
                      'autoReleaseSeat': autoRelease,
                      'updatedAt': FieldValue.serverTimestamp(),
                      'updatedBy': user?.email ?? 'admin',
                    }, SetOptions(merge: true));

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cancellation & study freeze policy updated ✓'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save policy: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}


class _QuickLaunchCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickLaunchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: isDark ? 0.3 : 0.15),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isDark ? Colors.white : color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
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
