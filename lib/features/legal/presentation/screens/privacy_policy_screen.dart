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
import 'terms_screen.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  final String? libraryId;
  const PrivacyPolicyScreen({super.key, this.libraryId});

  static String defaultPrivacyPolicyMarathi(String libraryName) => '''
१. आम्ही संकलित करत असलेली माहिती
आपण $libraryName मध्ये नोंदणी करता आणि अभ्यास केंद्राचा वापर करता, तेव्हा आम्ही पुढील माहिती संकलित करतो:
• ओळख व संपर्क माहिती: पूर्ण नाव, मोबाईल क्रमांक, ईमेल, पत्ता आणि पालकांचा/आपत्कालीन संपर्क क्रमांक.
• शैक्षणिक व ओळख पुरावा: स्पर्धा परीक्षांचे नाव, शासकीय ओळखपत्र (Mandatory ID proof), आणि डिजिटल ओळखपत्रासाठी छायाचित्र.
• उपस्थिती व लॉग नोंदी: दैनंदिन चेक-इन आणि चेक-आउट वेळ, निवडलेली शिफ्ट आणि जागा वाटप तपशील.
• शुल्क व पावती नोंदी: सदस्यत्व पावती क्रमांक, देय रक्कम इतिहास, आणि व्यवहार संदर्भ (आम्ही बँकेचे पासवर्ड किंवा कार्ड पिन संचयित करत नाही).

२. माहितीचा वापर व कायदेशीर आधार
आपली माहिती केवळ पुढील कारणांसाठी वापरली जाते:
• अभ्यास टेबल आरक्षण, वेळेचे व्यवस्थापन, आणि लॉकर वाटप सुलभ करणे.
• महत्त्वाची सूचना देणे — जसे की सदस्यत्व नूतनीकरण स्मरणपत्रे, फी पावत्या, आणि सुट्टीच्या सूचना (SMS किंवा WhatsApp द्वारे).
• अभ्यास केंद्रातील सुरक्षा सुनिश्चित करणे, अनधिकृत प्रवेश रोखणे, आणि वादांचे निराकरण करणे.

३. डेटा सुरक्षितता व क्लाउड स्टोअरेज
सर्व विद्यार्थ्यांचा डेटा Firebase Cloud वरील एन्क्रिप्टेड (TLS/SSL) सर्व्हरवर सुरक्षित साठवला जातो. हा डेटा केवळ अधिकृत ग्रंथालय प्रशासकांसाठीच उपलब्ध असतो.

४. तृतीय पक्षांशी (Third-Party) डेटा शेअरिंग
$libraryName विद्यार्थ्यांचा वैयक्तिक डेटा कोणत्याही जाहिरातदार किंवा विपणन कंपन्यांना विकत नाही.
डेटा केवळ अधिकृत संवाद सेवा पुरवठादार (WhatsApp/SMS गेटवे) आणि कायदेशीर न्यायालयीन प्रक्रियेसाठीच वापरला जातो.

५. सीसीटीव्ही (CCTV) देखरेख व सुरक्षितता
विद्यार्थ्यांच्या आणि मालमत्तेच्या सुरक्षेसाठी सार्वजनिक भागात २४/७ सीसीटीव्ही देखरेख असते. सुरक्षिततेच्या कारणाव्यतिरिक्त हे फुटेज इतर कोणालाही दिले जात नाही.

६. आपले हक्क व गोपनीयता संपर्क
आपल्याला आपल्या नोंदणीकृत प्रोफाइलचे पुनरावलोकन करण्याचा आणि दुरुस्तीची विनंती करण्याचा पूर्ण हक्क आहे. कोणत्याही शंका किंवा विनंतीसाठी थेट ग्रंथालय व्यवस्थापनाशी संपर्क साधावा.
''';

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
  LegalLanguage _selectedLanguage = LegalLanguage.en;

  void _openEditor(
    BuildContext context,
    String libraryId,
    String initialText,
    String libraryName, [
    LegalLanguage? language,
  ]) {
    final activeLanguage = language ?? _selectedLanguage;
    final controller = TextEditingController(text: initialText);
    final theme = Theme.of(context);
    final isMr = activeLanguage == LegalLanguage.mr;

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
              Expanded(
                child: Text(
                  isMr ? 'Edit Privacy Policy (मराठी)' : 'Edit Privacy Policy (English)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      isMr ? 'Custom Marathi Privacy Guidelines (गोपनीयता धोरण)' : 'Custom Library Privacy Guidelines',
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
                          controller.text = isMr
                              ? PrivacyPolicyScreen.defaultPrivacyPolicyMarathi(libraryName)
                              : PrivacyPolicyScreen.defaultPrivacyPolicy(libraryName);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isMr ? 'Standard Marathi privacy template loaded' : 'Standard privacy policy template loaded',
                            ),
                            duration: const Duration(seconds: 1),
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
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(12),
                      border: InputBorder.none,
                      hintText: isMr
                          ? 'गोपनीयता नियम, डेटा संरक्षण मार्गदर्शक तत्त्वे प्रविष्ट करा...'
                          : 'Enter privacy clauses, data protection guidelines, and student rights...',
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
                        final fieldKey = isMr ? 'privacyPolicy_mr' : 'privacyPolicy';
                        await FirebaseFirestore.instance
                            .collection('libraries')
                            .doc(libraryId)
                            .collection('settings')
                            .doc('legal')
                            .set({
                              fieldKey: controller.text.trim(),
                              'privacyUpdatedAt': FieldValue.serverTimestamp(),
                              'privacyUpdatedBy':
                                  FirebaseAuth.instance.currentUser?.email ??
                                  'Admin',
                            }, SetOptions(merge: true));

                        if (context.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isMr ? 'Privacy Policy (मराठी) published successfully!' : 'Privacy Policy published successfully!',
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
    final isMarathi = _selectedLanguage == LegalLanguage.mr;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('legal')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final rawPolicy = isMarathi
            ? (data?['privacyPolicy_mr'] as String?)?.trim()
            : (data?['privacyPolicy'] as String?)?.trim();
        final displayPolicy = (rawPolicy != null && rawPolicy.isNotEmpty)
            ? rawPolicy
            : (isMarathi ? PrivacyPolicyScreen.defaultPrivacyPolicyMarathi(libraryName) : PrivacyPolicyScreen.defaultPrivacyPolicy(libraryName));
        final updatedAt = data?['privacyUpdatedAt'] as Timestamp?;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => context.canPop() ? context.pop() : (Navigator.canPop(context) ? Navigator.pop(context) : context.go(Routes.login)),
            ),
            title: Text(isMarathi ? 'गोपनीयता धोरण (Privacy)' : 'Privacy Policy'),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: isMarathi ? 'धोरण कॉपी करा' : 'Copy Policy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: displayPolicy));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isMarathi ? 'गोपनीयता धोरण क्लिपबोर्डवर कॉपी झाले' : 'Privacy Policy copied to clipboard'),
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
                    _selectedLanguage,
                  ),
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
                              _selectedLanguage,
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
