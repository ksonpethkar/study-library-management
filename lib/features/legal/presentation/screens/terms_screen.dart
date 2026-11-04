import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';

class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  static String defaultTerms(String libraryName) => '''
1. Acceptance of Rules & Regulations
By enrolling, paying membership fees, or accessing the facilities of $libraryName, you agree to strictly abide by all rules, code of conduct, and administrative instructions issued by the library management.

2. Study Hall Conduct & Silent Zone
• Strict silence must be observed at all times within study rooms, cubicles, and reading zones.
• Mobile phones must be set to silent or vibration mode. Answering or making phone calls, gaming, and group discussions inside the study hall are strictly prohibited.
• Please use designated cafeteria or outdoor lobby areas for taking essential phone calls.

3. Seat Allocation & Subscriptions
• Seats are allocated in accordance with your chosen shift or 24/7 plan.
• Fixed seats are reserved exclusively for the registered member. Sub-letting, sharing, or allowing friends to use your reserved seat is strictly prohibited.
• Membership renewals must be completed prior to expiry. Expired seats will be released to the waiting list after a 24-hour grace period.

4. Personal Belongings & Lockers
• Members are solely responsible for their personal belongings, laptops, tablets, books, and cash.
• $libraryName management accepts no liability for loss, theft, or damage to unattended items.
• If assigned a locker, you must secure it with your own sturdy lock and keep the key safely.

5. Fees & Cancellation Policy
• Admission and recurring subscription fees once paid are strictly non-refundable and non-transferable under any circumstances.
• In case of seat cancellation mid-month, no pro-rata fee refunds or adjustments will be granted.
• Refundable security deposits (if applicable) will be settled within 7 working days post-clearance of all dues.

6. Property Care & CCTV Surveillance
• For safety and security, premises are monitored 24/7 by CCTV cameras. Tampering with cameras, electrical wiring, or fire safety equipment is a criminal violation.
• Any intentional damage to desks, ergonomic chairs, power sockets, or Wi-Fi hardware will be charged directly to the responsible member.

7. Administration Rights & Amendments
• Management reserves the right to suspend or terminate membership without refund for repeated indiscipline, verbal abuse of staff, or breach of these terms.
• Terms may be updated periodically to enhance facility standards. Continued use constitutes acceptance of revised terms.
''';

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _isSaving = false;

  void _openEditor(BuildContext context, String libraryId, String initialText, String libraryName) {
    final controller = TextEditingController(text: initialText);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Edit Terms of Service',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Editor Body
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Responsive Subtitle & Action Row
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Custom Library Terms & Rules',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              ),
                              icon: const Icon(Icons.restart_alt_rounded, size: 15),
                              label: const Text('Load Standard', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              onPressed: () {
                                setDialogState(() {
                                  controller.text = TermsScreen.defaultTerms(libraryName);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Standard study library template loaded'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
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
                                hintText: 'Enter library terms, rules, and student conduct guidelines...',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                                    'termsOfService': controller.text.trim(),
                                    'termsUpdatedAt': FieldValue.serverTimestamp(),
                                    'termsUpdatedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
                                  }, SetOptions(merge: true));

                                  if (context.mounted) {
                                    Navigator.pop(dialogCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Terms of Service published successfully!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to save terms: $e')),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _isSaving = false);
                                }
                              },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = ref.watch(userRoleProvider);
    final isAdmin = role == AppUserRole.admin;
    final libraryId = ref.watch(currentLibraryIdProvider);
    final lib = ref.watch(currentLibraryProvider).value;
    final libraryName = lib?.name.isNotEmpty == true ? lib!.name : 'Study Centre';

    if (libraryId == null || libraryId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => context.canPop() ? context.pop() : (Navigator.canPop(context) ? Navigator.pop(context) : context.go(Routes.login)),
          ),
          title: const Text('Terms of Service'),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Copy Terms',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: TermsScreen.defaultTerms(libraryName)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Terms copied to clipboard'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
          ],
        ),
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              TermsScreen.defaultTerms(libraryName),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('legal')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final rawTerms = (data?['termsOfService'] as String?)?.trim();
        final displayTerms = (rawTerms != null && rawTerms.isNotEmpty)
            ? rawTerms
            : TermsScreen.defaultTerms(libraryName);
        final updatedAt = data?['termsUpdatedAt'] as Timestamp?;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => context.canPop() ? context.pop() : (Navigator.canPop(context) ? Navigator.pop(context) : context.go(Routes.login)),
            ),
            title: const Text('Terms of Service'),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy Terms',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: displayTerms));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Terms copied to clipboard'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded),
                  tooltip: 'Edit Terms & Policies',
                  onPressed: () => _openEditor(context, libraryId, displayTerms, libraryName),
                ),
            ],
          ),
          body: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
            children: [
                // Header Badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  libraryName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  updatedAt != null
                                      ? 'Last Updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(updatedAt.toDate())}'
                                      : 'Official Rules & Code of Conduct',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          if (isAdmin)
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 14),
                              label: const Text('Edit Terms', style: TextStyle(fontSize: 12)),
                              onPressed: () => _openEditor(context, libraryId, displayTerms, libraryName),
                            ),
                        ],
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Admin Note: You can customize rules, silent hours, locker policies, and fee terms for your library.',
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
                // Terms Content
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    displayTerms,
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
