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

enum LegalLanguage { en, mr }

class TermsScreen extends ConsumerStatefulWidget {
  final String? libraryId;
  const TermsScreen({super.key, this.libraryId});

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

  static String defaultTermsMarathi(String libraryName) => '''
१. नियम व अटींची स्वीकृती
$libraryName मध्ये प्रवेश घेऊन, शुल्क भरून किंवा अभ्यास केंद्राच्या सुविधांचा वापर करून, आपण व्यवस्थापनाने जारी केलेल्या सर्व नियमांचे व शिस्तभंगाच्या सूचनांचे काटेकोरपणे पालन करण्याचे मान्य करता.

२. अभ्यास कक्ष शिस्त व शांतता क्षेत्र (Silent Zone)
• अभ्यास कक्ष, केबिन आणि वाचन विभागात संपूर्ण शांतता राखणे बंधनकारक आहे.
• मोबाईल फोन नेहमी सायलेंट किंवा व्हायब्रेशन मोडवर ठेवणे अनिवार्य आहे. अभ्यास कक्षात फोनवर बोलणे, गेम खेळणे किंवा गटचर्चा करण्यास सक्त मनाई आहे.
• आवश्यक फोन कॉल्स घेण्यासाठी कृपया नियुक्त कॅफेटेरिया किंवा बाहेरील लॉबी परिसराचा वापर करावा.

३. जागा (Seat) वाटप व सदस्यत्व नूतनीकरण
• आपण निवडलेल्या शिफ्टनुसार किंवा २४/७ योजनेनुसार जागा वाटप केले जाते.
• आरक्षित केलेली जागा फक्त संबंधित नोंदणीकृत सदस्यासाठीच मर्यादित आहे. आपली जागा दुसऱ्याला देणे, शेअर करणे किंवा मित्राला बसू देणे सक्त निषिद्ध आहे.
• मुदत संपण्यापूर्वी सदस्यत्वाचे नूतनीकरण करणे आवश्यक आहे. मुदत व सवलत कालावधी (Grace Period) संपल्यानंतर सदर जागा आपोआप रिक्त करून प्रतीक्षा यादीतील विद्यार्थ्याला दिली जाईल.

४. वैयक्तिक वस्तू व लॉकर सुरक्षा
• लॅपटॉप, टॅब्लेट, पुस्तके, रोख रक्कम व इतर मौल्यवान वस्तूंची जबाबदारी पूर्णपणे सदस्याची राहील.
• कोणत्याही वस्तू गहाळ झाल्यास, चोरीस गेल्यास किंवा नुकसान झाल्यास $libraryName व्यवस्थापन जबाबदार राहणार नाही.
• लॉकर वाटप केले असल्यास, स्वतःचे मजबूत कुलूप लावणे आणि चावी सुरक्षित ठेवणे अनिवार्य आहे.

५. शुल्क व परतावा धोरण (Non-Refundable Policy)
• एकदा भरलेले प्रवेश शुल्क किंवा मासिक/त्रैमासिक सदस्यत्व शुल्क कोणत्याही परिस्थितीत परत (Refund) केले जाणार नाही किंवा हस्तांतरित केले जाणार नाही.
• महिन्याच्या मध्यात जागा सोडल्यास कोणत्याही प्रकारचे सवलतीचे शुल्क परत दिले जाणार नाही.
• अनामत रक्कम (Security Deposit) सर्व देणी पूर्ण झाल्यावर ७ कामकाजाच्या दिवसांत परत केली जाईल.

६. मालमत्तेची काळजी व सीसीटीव्ही (CCTV) देखरेख
• सुरक्षिततेसाठी संपूर्ण परिसरावर २४ तास सीसीटीव्ही कॅमेऱ्यांची नजर असते. कॅमेरे, वायरिंग किंवा अग्निशामक साधनांशी छेडछाड करणे हा कायदेशीर गुन्हा आहे.
• अभ्यास टेबल, खुर्च्या, चार्जिंग सॉकेट्स, किंवा वाय-फाय उपकरणांचे नुकसान केल्यास त्याचा संपूर्ण दंड संबंधित सदस्याकडून वसूल केला जाईल.

७. व्यवस्थापनाचे अधिकार व नियम सुधारणा
• गैरवर्तन, कर्मचाऱ्यांशी असभ्य भाषा, किंवा नियमांचे वारंवार उल्लंघन केल्यास कोणतीही पूर्वसूचना किंवा शुल्क परतावा न देता सदस्यत्व रद्द करण्याचा अधिकार व्यवस्थापनाकडे राखीव आहे.
• सुविधांचा दर्जा सुधारण्यासाठी नियमांमध्ये वेळोवेळी बदल केले जाऊ शकतात.
''';

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _isSaving = false;
  LegalLanguage _selectedLanguage = LegalLanguage.en;

  void _openEditor(BuildContext context, String libraryId, String initialText, String libraryName, [LegalLanguage? language]) {
    final activeLanguage = language ?? _selectedLanguage;
    final controller = TextEditingController(text: initialText);
    final theme = Theme.of(context);
    final isMr = activeLanguage == LegalLanguage.mr;

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
                      Expanded(
                        child: Text(
                          isMr ? 'Edit Terms of Service (मराठी)' : 'Edit Terms of Service (English)',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                              isMr ? 'Custom Marathi Rules (नियम व अटी)' : 'Custom Library Terms & Rules',
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
                                  controller.text = isMr
                                      ? TermsScreen.defaultTermsMarathi(libraryName)
                                      : TermsScreen.defaultTerms(libraryName);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isMr ? 'Standard Marathi template loaded' : 'Standard study library template loaded'),
                                    duration: const Duration(seconds: 1),
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
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.all(12),
                                border: InputBorder.none,
                                hintText: isMr
                                    ? 'ग्रंथालय नियम, शांतता सूचना आणि अटी प्रविष्ट करा...'
                                    : 'Enter library terms, rules, and student conduct guidelines...',
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
                                  final fieldKey = isMr ? 'termsOfService_mr' : 'termsOfService';
                                  await FirebaseFirestore.instance
                                      .collection('libraries')
                                      .doc(libraryId)
                                      .collection('settings')
                                      .doc('legal')
                                      .set({
                                    fieldKey: controller.text.trim(),
                                    'termsUpdatedAt': FieldValue.serverTimestamp(),
                                    'termsUpdatedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
                                  }, SetOptions(merge: true));

                                  if (context.mounted) {
                                    Navigator.pop(dialogCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isMr ? 'Terms (मराठी) published successfully!' : 'Terms of Service published successfully!'),
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
    final currentLibId = ref.watch(currentLibraryIdProvider);
    final libraryId = (widget.libraryId != null && widget.libraryId!.isNotEmpty)
        ? widget.libraryId!
        : (currentLibId != null && currentLibId.isNotEmpty
            ? currentLibId
            : CurrentLibraryNotifier.defaultLibraryId);
    final lib = ref.watch(currentLibraryProvider).value;
    final libraryName = lib?.name.isNotEmpty == true ? lib!.name : 'The Cozy Corner Study Centre';


    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('legal')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final isMarathi = _selectedLanguage == LegalLanguage.mr;
        final rawTerms = isMarathi
            ? (data?['termsOfService_mr'] as String?)?.trim()
            : (data?['termsOfService'] as String?)?.trim();
        final displayTerms = (rawTerms != null && rawTerms.isNotEmpty)
            ? rawTerms
            : (isMarathi ? TermsScreen.defaultTermsMarathi(libraryName) : TermsScreen.defaultTerms(libraryName));
        final updatedAt = data?['termsUpdatedAt'] as Timestamp?;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => context.canPop() ? context.pop() : (Navigator.canPop(context) ? Navigator.pop(context) : context.go(Routes.login)),
            ),
            title: Text(isMarathi ? 'नियम व अटी (Terms)' : 'Terms of Service'),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: isMarathi ? 'नियम कॉपी करा' : 'Copy Terms',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: displayTerms));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isMarathi ? 'नियम क्लिपबोर्डवर कॉपी झाले' : 'Terms copied to clipboard'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded),
                  tooltip: 'Edit Terms & Policies',
                  onPressed: () => _openEditor(context, libraryId, displayTerms, libraryName, _selectedLanguage),
                ),
            ],
          ),
          body: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
                // Bilingual Language Switcher
                Center(
                  child: SegmentedButton<LegalLanguage>(
                    segments: const [
                      ButtonSegment(
                        value: LegalLanguage.en,
                        label: Text('English'),
                        icon: Icon(Icons.language_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: LegalLanguage.mr,
                        label: Text('मराठी (Marathi)'),
                        icon: Icon(Icons.translate_rounded, size: 16),
                      ),
                    ],
                    selected: {_selectedLanguage},
                    onSelectionChanged: (set) => setState(() => _selectedLanguage = set.first),
                  ),
                ),
                const SizedBox(height: 16),

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
                              onPressed: () => _openEditor(context, libraryId, displayTerms, libraryName, _selectedLanguage),
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
