import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  final String? libraryId;
  const PrivacyPolicyScreen({super.key, this.libraryId});

  static String defaultPrivacyPolicy(String libraryName) =>
      '''
1. Information We Collect
When you register and use the facilities at $libraryName, we collect the following categories of information:
• Identity & Contact Details: Full name, mobile number, email address, address, and emergency contact details.
• Academic & Profile Information: Target examinations/courses, government ID proof (where mandated), and profile photo for desk access cards.
• Attendance & Access Logs: Daily check-in and check-out timestamps, shift allocations, and desk occupancy data.
• Payment Records: Subscription receipts, dues history, payment mode references, and transaction IDs (we do not store raw debit/credit card numbers or banking passwords).

2. Purpose & Legal Basis for Processing
We process your personal information strictly to:
• Facilitate desk reservations, time slot scheduling, and locker assignments.
• Deliver essential administrative notifications, including seat renewal reminders, fee receipts, and operational updates via SMS or WhatsApp.
• Ensure the security and safety of all members, verify authorized admission, and resolve disputes.

3. Data Storage & Cloud Security
All student and operational data is stored on secure cloud databases powered by Firebase Cloud Services with end-to-end TLS/SSL encryption during transmission. Access is restricted to authorized library administrators and staff.

4. Third-Party Sharing & Disclosure
$libraryName does NOT sell, rent, or trade your personal data to marketing agencies or third parties. We only share information with:
• Official communication service providers (e.g. WhatsApp / SMS gateways) strictly to deliver your transaction alerts and receipts.
• Law enforcement or regulatory authorities only when required by valid legal process or court order.

5. CCTV & Physical Security Surveillance
To protect library members and facility assets, public and common areas (entrance corridors, reading halls, cafeteria) are monitored by 24/7 CCTV surveillance. CCTV recordings are overwritten periodically and accessed solely in event of security incidents or rule violations.

6. Your Rights & Data Retention
You have the right to review your registered profile data, request corrections, or request deactivation of your membership records upon settling all dues. For any privacy queries or data removal requests, contact the library desk administration.
''';

  @override
  ConsumerState<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  bool _isSaving = false;

  void _openEditor(
    BuildContext context,
    String libraryId,
    String initialText,
    String libraryName,
  ) {
    final controller = TextEditingController(text: initialText);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Edit Privacy Policy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Custom Library Privacy Guidelines',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text(
                        'Load Standard',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          controller.text =
                              PrivacyPolicyScreen.defaultPrivacyPolicy(
                                libraryName,
                              );
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Standard privacy policy template loaded',
                            ),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 350,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                      hintText: 'Enter privacy clauses, data protection guidelines, and student rights...',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_isSaving ? 'Saving…' : 'Save & Publish'),
              onPressed: _isSaving
                  ? null
                  : () async {
                      setDialogState(() => _isSaving = true);
                      setState(() => _isSaving = true);

                      try {
                        await FirebaseFirestore.instance
                            .collection('libraries')
                            .doc(libraryId)
                            .collection('settings')
                            .doc('legal')
                            .set({
                              'privacyPolicy': controller.text.trim(),
                              'privacyUpdatedAt': FieldValue.serverTimestamp(),
                              'privacyUpdatedBy':
                                  FirebaseAuth.instance.currentUser?.email ??
                                  'Admin',
                            }, SetOptions(merge: true));

                        if (context.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Privacy Policy published successfully!',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'announcement');
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = ref.watch(userRoleProvider);
    final isAdmin = role == AppUserRole.admin;
    final currentLibId = ref.watch(currentLibraryIdProvider);
    final libraryId = (widget.libraryId != null && widget.libraryId!.isNotEmpty)
        ? widget.libraryId!
        : (currentLibId != null && currentLibId.isNotEmpty
            ? currentLibId
            : CurrentLibraryNotifier.defaultLibraryId);
    final lib = ref.watch(currentLibraryProvider).value;
    final libraryName = lib?.name.isNotEmpty == true
        ? lib!.name
        : 'The Cozy Corner Study Centre';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('legal')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final rawPolicy = (data?['privacyPolicy'] as String?)?.trim();
        final displayPolicy = (rawPolicy != null && rawPolicy.isNotEmpty)
            ? rawPolicy
            : PrivacyPolicyScreen.defaultPrivacyPolicy(libraryName);
        final updatedAt = data?['privacyUpdatedAt'] as Timestamp?;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => context.canPop() ? context.pop() : (Navigator.canPop(context) ? Navigator.pop(context) : context.go(Routes.login)),
            ),
            title: const Text('Privacy Policy'),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy Policy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: displayPolicy));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Privacy Policy copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded),
                  tooltip: 'Edit Privacy Policy',
                  onPressed: () => _openEditor(
                    context,
                    libraryId,
                    displayPolicy,
                    libraryName,
                  ),
                ),
            ],
          ),
          body: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              // Header Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                libraryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                updatedAt != null
                                    ? 'Last Updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(updatedAt.toDate())}'
                                    : 'Data Protection & Member Privacy Standards',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isAdmin)
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: const Text(
                              'Edit Policy',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _openEditor(
                              context,
                              libraryId,
                              displayPolicy,
                              libraryName,
                            ),
                          ),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Admin Note: You can customize data retention, CCTV clauses, and student information policies for your library.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Policy Content
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: Text(
                  displayPolicy,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.65,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
