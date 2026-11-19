import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:study_library/features/legal/presentation/screens/terms_screen.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/student_model.dart';

/// Mandatory, non-dismissable dialog presented to students whenever library rules,
/// terms of service, or privacy policies are updated by administration.
class PolicyAgreementDialog extends StatefulWidget {
  final StudentModel student;
  final LibraryModel library;
  final String rulesText;
  final String termsTextEn;
  final String termsTextMr;
  final String privacyTextEn;
  final String privacyTextMr;
  final DateTime policyUpdatedAt;

  const PolicyAgreementDialog({
    super.key,
    required this.student,
    required this.library,
    required this.rulesText,
    required this.termsTextEn,
    required this.termsTextMr,
    required this.privacyTextEn,
    required this.privacyTextMr,
    required this.policyUpdatedAt,
  });

  static bool _isShowing = false;

  /// Evaluates whether the current student needs to review and accept updated policies.
  /// If [library.policyUpdatedAt] is more recent than [student.lastAcceptedPolicyAt],
  /// the non-dismissable agreement dialog is displayed automatically.
  static Future<void> checkAndShow(
    BuildContext context, {
    required StudentModel student,
    required LibraryModel library,
  }) async {
    if (_isShowing || student.id.isEmpty || library.id.isEmpty) return;

    try {
      DateTime? policyUpdatedAt = library.policyUpdatedAt;
      Map<String, dynamic> legalData = {};

      // If policyUpdatedAt is not present on the root library doc, check settings/legal
      final legalDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(library.id)
          .collection('settings')
          .doc('legal')
          .get();

      if (legalDoc.exists && legalDoc.data() != null) {
        legalData = legalDoc.data()!;
        final legalTs = legalData['policyUpdatedAt'] ?? legalData['updatedAt'];
        if (legalTs != null) {
          final parsed = legalTs is Timestamp
              ? legalTs.toDate()
              : DateTime.tryParse(legalTs.toString());
          if (parsed != null && (policyUpdatedAt == null || parsed.isAfter(policyUpdatedAt))) {
            policyUpdatedAt = parsed;
          }
        }
      }

      // If the library has no policy timestamp at all, default to library creation time or skip
      if (policyUpdatedAt == null) return;

      // Check local SharedPreferences mirror for rapid zero-latency re-checks
      final prefs = await SharedPreferences.getInstance();
      final localAcceptedStr = prefs.getString('last_accepted_policy_at_${student.id}');
      final localAcceptedAt = localAcceptedStr != null ? DateTime.tryParse(localAcceptedStr) : null;

      final effectiveAcceptedAt = (student.lastAcceptedPolicyAt != null && localAcceptedAt != null)
          ? (student.lastAcceptedPolicyAt!.isAfter(localAcceptedAt)
              ? student.lastAcceptedPolicyAt!
              : localAcceptedAt)
          : (student.lastAcceptedPolicyAt ?? localAcceptedAt);

      // Condition: Never accepted OR policy was updated after last acceptance
      if (effectiveAcceptedAt == null || policyUpdatedAt.isAfter(effectiveAcceptedAt)) {
        if (!context.mounted) return;
        _isShowing = true;

        final rulesText = library.rulesText.trim().isNotEmpty
            ? library.rulesText.trim()
            : (legalData['rulesText'] as String?)?.trim() ?? '';

        final termsEn = (legalData['termsOfService'] as String?)?.trim().isNotEmpty == true
            ? legalData['termsOfService'] as String
            : TermsScreen.defaultTerms(library.name);

        final termsMr = (legalData['termsOfService_mr'] as String?)?.trim().isNotEmpty == true
            ? legalData['termsOfService_mr'] as String
            : TermsScreen.defaultTermsMarathi(library.name);

        final privacyEn = (legalData['privacyPolicy'] as String?)?.trim().isNotEmpty == true
            ? legalData['privacyPolicy'] as String
            : PrivacyPolicyScreen.defaultPrivacyPolicy(library.name);

        final privacyMr = (legalData['privacyPolicy_mr'] as String?)?.trim().isNotEmpty == true
            ? legalData['privacyPolicy_mr'] as String
            : PrivacyPolicyScreen.defaultPrivacyPolicyMarathi(library.name);

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: PolicyAgreementDialog(
              student: student,
              library: library,
              rulesText: rulesText,
              termsTextEn: termsEn,
              termsTextMr: termsMr,
              privacyTextEn: privacyEn,
              privacyTextMr: privacyMr,
              policyUpdatedAt: policyUpdatedAt!,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[PolicyAgreementDialog] Evaluation error: $e');
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<PolicyAgreementDialog> createState() => _PolicyAgreementDialogState();
}

class _PolicyAgreementDialogState extends State<PolicyAgreementDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isMarathi = false;
  bool _agreed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submitConsent() async {
    if (!_agreed || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final policyVersion = widget.policyUpdatedAt.toIso8601String();

    try {
      // 1. Update Student document in Firestore
      await FirebaseFirestore.instance.collection('students').doc(widget.student.id).update({
        'lastAcceptedPolicyAt': nowIso,
        'acceptedPolicyVersion': policyVersion,
        'customFields.lastAcceptedPolicyAt': nowIso,
        'customFields.acceptedPolicyVersion': policyVersion,
        'updatedAt': nowIso,
      });

      // 2. Append permanent legal audit log in student's subcollection
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.student.id)
          .collection('policy_consents')
          .add({
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedAtIso': nowIso,
        'policyVersion': policyVersion,
        'studentName': widget.student.name,
        'studentPhone': widget.student.phone,
        'libraryId': widget.library.id,
        'language': _isMarathi ? 'mr' : 'en',
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      });

      // 3. Mirror to local SharedPreferences for zero-latency startup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_accepted_policy_at_${widget.student.id}', nowIso);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record consent: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = Color(widget.library.accentColor != 0 ? widget.library.accentColor : 0xFF5D4037);

    final defaultRulesFallback = _isMarathi
        ? '१. अभ्यास कक्षात संपूर्ण शांतता राखणे बंधनकारक आहे.\n'
          '२. मोबाईल फोन नेहमी सायलेंट किंवा व्हायब्रेशन मोडवर ठेवावा.\n'
          '३. आरक्षित जागा फक्त नोंदणीकृत विद्यार्थ्यासाठीच आहे; जागा बदलणे सक्त मनाई आहे.\n'
          '४. अभ्यासाच्या टेबलावर फक्त पाण्याची बाटली चालेल. नाश्ता/जेवण फक्त कॅन्टीनमध्ये करावे.\n'
          '५. अभ्यास केंद्रात प्रवेशासाठी व सीट पडताळणीसाठी डिजिटल विद्यार्थी पास जवळ असणे आवश्यक आहे.\n'
          '६. मुदत संपण्यापूर्वी सदस्यत्वाचे नूतनीकरण करणे आवश्यक आहे.'
        : '1. Maintain complete silence in all study areas at all times.\n'
          '2. Mobile phones must be kept on silent or vibration mode.\n'
          '3. Desk allocation is strictly for single-member use; seat swapping is prohibited.\n'
          '4. Only closed water bottles are permitted on study desks. Food must be consumed in cafeteria.\n'
          '5. Digital Student Pass must be available on mobile phone for entry and desk verification.\n'
          '6. Monthly subscriptions must be renewed on or before the due date.';

    final effectiveRules = widget.rulesText.isNotEmpty ? widget.rulesText : defaultRulesFallback;
    final effectiveTerms = _isMarathi ? widget.termsTextMr : widget.termsTextEn;
    final effectivePrivacy = _isMarathi ? widget.privacyTextMr : widget.privacyTextEn;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          children: [
            // Header Bar with Library Badge & Language Switcher
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.08),
                border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isMarathi ? 'सुधारित नियम व अटी' : 'Updated Policies & Rules',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              widget.library.name.isNotEmpty ? widget.library.name : 'Smart Study Library',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Language Switcher Pill
                      InkWell(
                        onTap: () => setState(() => _isMarathi = !_isMarathi),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.translate_rounded, size: 14, color: primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                _isMarathi ? 'मराठी' : 'English',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tab selector: Rules | Terms | Privacy
                  TabBar(
                    controller: _tabController,
                    labelColor: primaryColor,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    indicatorColor: primaryColor,
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                    tabs: [
                      Tab(text: _isMarathi ? 'नियम' : 'Rules'),
                      Tab(text: _isMarathi ? 'अटी' : 'Terms'),
                      Tab(text: _isMarathi ? 'गोपनीयता' : 'Privacy'),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views: Scrollable policy text
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PolicyContentCard(
                    title: _isMarathi ? 'अभ्यास केंद्र नियमावली' : 'Study Hall Conduct Rules',
                    body: effectiveRules,
                    icon: Icons.menu_book_rounded,
                    accentColor: primaryColor,
                  ),
                  _PolicyContentCard(
                    title: _isMarathi ? 'सेवेच्या अटी व शर्ती' : 'Terms & Conditions',
                    body: effectiveTerms,
                    icon: Icons.assignment_outlined,
                    accentColor: primaryColor,
                  ),
                  _PolicyContentCard(
                    title: _isMarathi ? 'गोपनीयता धोरण' : 'Privacy & Security Policy',
                    body: effectivePrivacy,
                    icon: Icons.security_rounded,
                    accentColor: primaryColor,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Mandatory Consent & Action Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _isSubmitting ? null : () => setState(() => _agreed = !_agreed),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _agreed,
                            activeColor: primaryColor,
                            onChanged: _isSubmitting ? null : (v) => setState(() => _agreed = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              _isMarathi
                                  ? 'मी सुधारित नियम, सेवेच्या अटी आणि गोपनीयता धोरण वाचले असून त्याचे काटेकोरपणे पालन करण्याचे मान्य करतो.'
                                  : 'I have read, understood, and agree to abide by the updated Rules, Terms of Service, and Privacy Policy.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (_agreed && !_isSubmitting) ? _submitConsent : null,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.verified_user_rounded, size: 18),
                      label: Text(
                        _isSubmitting
                            ? (_isMarathi ? 'नोंदणी करत आहे...' : 'Recording Consent...')
                            : (_isMarathi ? 'मान्य करून पुढे जा' : 'Accept & Proceed'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyContentCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color accentColor;

  const _PolicyContentCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            body.trim().isNotEmpty ? body.trim() : 'No specifications provided by administration.',
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.6,
              fontSize: 12.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
