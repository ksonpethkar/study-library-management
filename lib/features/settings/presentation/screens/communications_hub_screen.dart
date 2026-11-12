import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/telegram_service.dart';
import 'package:study_library/services/local_bridge_service.dart';
import 'package:study_library/services/notification_service.dart';
import 'package:study_library/services/owner_digest_service.dart';
import 'package:study_library/services/waiting_list_promotion_service.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:study_library/services/meta_whatsapp_api_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/services/soundbox_service.dart';

class CommunicationsHubScreen extends ConsumerStatefulWidget {
  const CommunicationsHubScreen({super.key});

  @override
  ConsumerState<CommunicationsHubScreen> createState() => _CommunicationsHubScreenState();
}

class _CommunicationsHubScreenState extends ConsumerState<CommunicationsHubScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // ── Action Queue (Tab 1) ──────────────────────────────────────────────────
  String _actionFilter = 'all';
  String? _sendingStudentId;

  // ── Channels (Tab 1) ──────────────────────────────────────────────────────
  bool _pushEnabled = true;
  bool _smsEnabled = false;
  bool _telegramEnabled = false;
  final _telegramTokenController = TextEditingController();
  final _telegramChatIdController = TextEditingController();
  bool _isTestingTelegram = false;

  bool _whatsappEnabled = true;
  bool _localBridgeEnabled = false;
  final _localBridgeUrlController = TextEditingController();
  bool _isTestingBridge = false;

  bool _customWebhookEnabled = false;
  final _customWebhookUrlController = TextEditingController();

  // ── Meta WhatsApp Cloud API & SMS Gateway ──
  bool _metaWhatsAppEnabled = false;
  final _metaPhoneIdController = TextEditingController();
  final _metaTokenController = TextEditingController();
  bool _isTestingMeta = false;

  bool _smsGatewayEnabled = false;
  final _smsApiKeyController = TextEditingController();
  final _smsSenderIdController = TextEditingController();
  bool _isTestingSmsGateway = false;

  // ── Automation Rules (Tab 2) ──────────────────────────────────────────────
  bool _allNotifications = true;
  bool _newStudentRequest = true;
  bool _dailyExpirySummary = true;
  bool _studentIssuesAlert = true;

  bool _paymentReceipts = true;
  bool _planExpiring = true;
  bool _planExpired = true;
  bool _announcementPush = true;

  // ── Roadmapped Core Automations (Phases 1, 2, 3) ─────────────────────────
  bool _multiStageRenewals = true;
  bool _morningBriefing = true;
  bool _nightlySettlement = true;
  bool _waitlistCascade = true;

  bool _isSendingMorningBriefing = false;
  bool _isSendingNightlySettlement = false;
  bool _isTestingCascade = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      libraryId = ref.read(currentLibraryProvider).value?.id;
    }
    if (libraryId == null || libraryId.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 250));
      libraryId = ref.read(currentLibraryIdProvider) ??
          ref.read(currentLibraryProvider).value?.id ??
          CurrentLibraryNotifier.defaultLibraryId;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Load Channels Config (Isolated catch to guarantee resilience)
      Map<String, dynamic> mData = {};
      try {
        final messagingDoc = await firestore
            .collection('libraries')
            .doc(libraryId)
            .collection('settings')
            .doc('messaging')
            .get()
            .timeout(const Duration(seconds: 4));
        mData = messagingDoc.data() ?? {};
      } catch (e) {
        if (kDebugMode) debugPrint('Messaging settings fetch fallback: $e');
      }

      // 2. Load Rules Config
      Map<String, dynamic> nData = {};
      try {
        final libDoc = await firestore
            .collection('libraries')
            .doc(libraryId)
            .get()
            .timeout(const Duration(seconds: 4));
        nData = (libDoc.data()?['notificationSettings'] as Map<String, dynamic>?) ?? {};
      } catch (e) {
        if (kDebugMode) debugPrint('Library notification settings fetch fallback: $e');
      }

      // 3. Load unified communications settings doc
      Map<String, dynamic> cChannels = {};
      Map<String, dynamic> cRules = {};
      try {
        final commDoc = await firestore
            .collection('libraries')
            .doc(libraryId)
            .collection('settings')
            .doc('communications')
            .get()
            .timeout(const Duration(seconds: 4));
        final cData = commDoc.data() ?? {};
        cChannels = (cData['channels'] as Map<String, dynamic>?) ?? {};
        cRules = (cData['rules'] as Map<String, dynamic>?) ?? {};
      } catch (e) {
        if (kDebugMode) debugPrint('Communications settings fetch fallback: $e');
      }

      if (mounted) {
        setState(() {
          // Channels
          _pushEnabled = cChannels['pushEnabled'] as bool? ?? true;
          _smsEnabled = cChannels['smsEnabled'] as bool? ?? (mData['smsEnabled'] as bool? ?? false);
          _telegramEnabled = cChannels['telegramEnabled'] as bool? ?? (mData['telegramEnabled'] as bool? ?? false);
          _telegramTokenController.text = (cChannels['telegramBotToken'] as String?) ?? (mData['telegramBotToken'] as String? ?? '');
          _telegramChatIdController.text = (cChannels['telegramChatId'] as String?) ?? (mData['telegramChatId'] as String? ?? '');
          _whatsappEnabled = cChannels['whatsappEnabled'] as bool? ?? (mData['whatsappEnabled'] as bool? ?? true);
          _localBridgeEnabled = cChannels['localBridgeEnabled'] as bool? ?? (mData['localBridgeEnabled'] as bool? ?? false);
          _localBridgeUrlController.text = (cChannels['localBridgeUrl'] as String?) ?? (mData['localBridgeUrl'] as String? ?? '');
          _customWebhookEnabled = cChannels['customWebhookEnabled'] as bool? ?? (mData['customWebhookEnabled'] as bool? ?? false);
          _customWebhookUrlController.text = (cChannels['customWebhookUrl'] as String?) ?? (mData['customWebhookUrl'] as String? ?? '');

          // Meta WhatsApp Cloud API & SMS Gateway
          _metaWhatsAppEnabled = cChannels['metaWhatsAppEnabled'] as bool? ?? (mData['metaWhatsAppEnabled'] as bool? ?? false);
          _metaPhoneIdController.text = (cChannels['metaPhoneNumberId'] as String?) ?? (mData['metaPhoneNumberId'] as String? ?? '');
          _metaTokenController.text = (cChannels['metaAccessToken'] as String?) ?? (mData['metaAccessToken'] as String? ?? '');

          _smsGatewayEnabled = cChannels['smsGatewayEnabled'] as bool? ?? (mData['smsGatewayEnabled'] as bool? ?? false);
          _smsApiKeyController.text = (cChannels['smsApiKey'] as String?) ?? (mData['smsApiKey'] as String? ?? '');
          _smsSenderIdController.text = (cChannels['smsSenderId'] as String?) ?? (mData['smsSenderId'] as String? ?? '');

          // Rules
          _allNotifications = cRules['allNotifications'] as bool? ?? (nData['allNotifications'] as bool? ?? true);
          _newStudentRequest = cRules['newStudentRequest'] as bool? ?? (nData['newRequest'] as bool? ?? true);
          _dailyExpirySummary = cRules['dailyExpirySummary'] as bool? ?? true;
          _studentIssuesAlert = cRules['studentIssuesAlert'] as bool? ?? true;

          _paymentReceipts = cRules['paymentReceipts'] as bool? ?? true;
          _planExpiring = cRules['planExpiring'] as bool? ?? (nData['planExpiring'] as bool? ?? true);
          _planExpired = cRules['planExpired'] as bool? ?? (nData['planExpired'] as bool? ?? true);
          _announcementPush = cRules['announcementPush'] as bool? ?? (nData['announcementPush'] as bool? ?? true);

          // Roadmapped Automations
          _multiStageRenewals = cRules['multiStageRenewals'] as bool? ?? true;
          _morningBriefing = cRules['morningBriefing'] as bool? ?? true;
          _nightlySettlement = cRules['nightlySettlement'] as bool? ?? true;
          _waitlistCascade = cRules['waitlistCascade'] as bool? ?? true;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading communications settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerTestMorningBriefing() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    if (libraryId.isEmpty) return;

    setState(() => _isSendingMorningBriefing = true);
    final digest = OwnerDigestService();
    final tg = ref.read(telegramServiceProvider);
    final ok = await digest.sendMorningBriefing(libraryId: libraryId, telegramService: tg);
    if (mounted) {
      setState(() => _isSendingMorningBriefing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '🌅 8:00 AM Morning Briefing Dispatched to Telegram & In-App Alerts! ✅' : 'Failed to dispatch morning briefing.'),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _triggerTestNightlySettlement() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    if (libraryId.isEmpty) return;

    setState(() => _isSendingNightlySettlement = true);
    final digest = OwnerDigestService();
    final tg = ref.read(telegramServiceProvider);
    final ok = await digest.sendNightlySettlement(libraryId: libraryId, telegramService: tg);
    if (mounted) {
      setState(() => _isSendingNightlySettlement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '🌙 11:00 PM Nightly Financial Settlement Dispatched to Telegram! ✅' : 'Failed to dispatch nightly settlement.'),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _triggerTestWaitlistCascade() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    if (libraryId.isEmpty) return;

    setState(() => _isTestingCascade = true);
    final promo = WaitingListPromotionService();
    final count = await promo.checkAndCascadeExpiredHolds(libraryId);
    if (mounted) {
      setState(() => _isTestingCascade = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? '🚀 $count expired hold(s) auto-cascaded to candidate #2!' : '⏳ Waitlist checked: No expired holds. Queue is active and in-sync! ✅'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _triggerTestRenewalPush() async {
    try {
      final lib = ref.read(currentLibraryProvider).value;
      final libName = lib?.name.isNotEmpty == true ? lib!.name : 'The Cozy Corner Study Centre';
      await NotificationService.showNotification(
        title: '📅 Test: Plan Expiring in 3 Days',
        body: 'Hello Student, your membership for Seat #2 at $libName completes in 3 days. Renew now to retain your reserved desk!',
        channelId: NotificationService.channelGeneral,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upcoming renewal reminder preview delivered to status bar! 📲'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'announcement');
      }
    }
  }

  Future<void> _saveSettings() async {
    var libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      libraryId = ref.read(currentLibraryProvider).value?.id ?? CurrentLibraryNotifier.defaultLibraryId;
    }
    if (libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    final firestore = FirebaseFirestore.instance;

    final channelsMap = {
      'pushEnabled': _pushEnabled,
      'smsEnabled': _smsEnabled,
      'telegramEnabled': _telegramEnabled,
      'telegramBotToken': _telegramTokenController.text.trim(),
      'telegramChatId': _telegramChatIdController.text.trim(),
      'whatsappEnabled': _whatsappEnabled,
      'localBridgeEnabled': _localBridgeEnabled,
      'localBridgeUrl': _localBridgeUrlController.text.trim(),
      'customWebhookEnabled': _customWebhookEnabled,
      'customWebhookUrl': _customWebhookUrlController.text.trim(),
      'metaWhatsAppEnabled': _metaWhatsAppEnabled,
      'metaPhoneNumberId': _metaPhoneIdController.text.trim(),
      'metaAccessToken': _metaTokenController.text.trim(),
      'smsGatewayEnabled': _smsGatewayEnabled,
      'smsApiKey': _smsApiKeyController.text.trim(),
      'smsSenderId': _smsSenderIdController.text.trim(),
    };

    final rulesMap = {
      'allNotifications': _allNotifications,
      'newStudentRequest': _newStudentRequest,
      'dailyExpirySummary': _dailyExpirySummary,
      'studentIssuesAlert': _studentIssuesAlert,
      'paymentReceipts': _paymentReceipts,
      'planExpiring': _planExpiring,
      'planExpired': _planExpired,
      'announcementPush': _announcementPush,
      'multiStageRenewals': _multiStageRenewals,
      'morningBriefing': _morningBriefing,
      'nightlySettlement': _nightlySettlement,
      'waitlistCascade': _waitlistCascade,
    };

    try {
      final batch = firestore.batch();

      // 1. Unified communications doc
      final commRef = firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('communications');
      batch.set(commRef, {
        'channels': channelsMap,
        'rules': rulesMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Messaging doc for backward compatibility with MessagingHubService
      final msgRef = firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('messaging');
      batch.set(msgRef, {
        ...channelsMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Library doc notificationSettings for backward compatibility
      final libRef = firestore.collection('libraries').doc(libraryId);
      batch.update(libRef, {
        'notificationSettings': {
          'allNotifications': _allNotifications,
          'newRequest': _newStudentRequest,
          'planExpiring': _planExpiring,
          'planExpired': _planExpired,
          'announcementPush': _announcementPush,
          'paymentReceipts': _paymentReceipts,
          'dailySummary': _dailyExpirySummary,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Communications & Automation Hub saved successfully! ✅'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testTelegram() async {
    final token = _telegramTokenController.text.trim();
    final chatId = _telegramChatIdController.text.trim();
    if (token.isEmpty || chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Bot Token and Chat ID first!')),
      );
      return;
    }

    setState(() => _isTestingTelegram = true);
    final tg = ref.read(telegramServiceProvider);
    final lib = ref.read(currentLibraryProvider).value;
    final ok = await tg.testConnection(botToken: token, chatId: chatId, libraryName: lib?.name);
    if (mounted) {
      setState(() => _isTestingTelegram = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Telegram Test Alert Sent Successfully! 🚀' : 'Failed to reach Telegram Bot. Check Token & Chat ID.'),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testBridge() async {
    final url = _localBridgeUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the Reception Desk Connector address first!')),
      );
      return;
    }

    setState(() => _isTestingBridge = true);
    final bridge = ref.read(localBridgeServiceProvider);
    final ok = await bridge.pingBridge(bridgeUrl: url);
    if (mounted) {
      setState(() => _isTestingBridge = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Reception Desk Connector Connected! ✅' : 'Could not reach reception desk computer. Check local network connection.'),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testLocalPush() async {
    try {
      final lib = ref.read(currentLibraryProvider).value;
      final libName = lib?.name.isNotEmpty == true ? lib!.name : 'Study Library';
      await NotificationService.showNotification(
        title: '🔔 Test Push Notification',
        body: 'Your device is successfully receiving notifications from $libName!',
        channelId: NotificationService.channelGeneral,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification dispatched to your status bar! 📲'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'announcement');
      }
    }
  }

  Future<void> _testMetaWhatsApp() async {
    final phoneId = _metaPhoneIdController.text.trim();
    final token = _metaTokenController.text.trim();
    final lib = ref.read(currentLibraryProvider).value;
    final testPhone = lib?.contact.isNotEmpty == true ? lib!.contact : '';

    if (phoneId.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Meta Phone Number ID and Access Token!')),
      );
      return;
    }
    if (testPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure an official library helpline/phone number in profile first!')),
      );
      return;
    }

    setState(() => _isTestingMeta = true);
    final metaService = ref.read(metaWhatsAppApiServiceProvider);
    final ok = await metaService.testMetaConnection(
      phoneNumberId: phoneId,
      accessToken: token,
      testPhone: testPhone,
      libraryName: lib?.name ?? 'Study Library',
    );
    if (mounted) {
      setState(() => _isTestingMeta = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Meta WhatsApp Cloud API Test Delivered to $testPhone! 🚀'
              : 'Failed to deliver Meta WhatsApp message. Please verify Phone Number ID and Access Token permissions.'),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testSmsGateway() async {
    final apiKey = _smsApiKeyController.text.trim();
    final lib = ref.read(currentLibraryProvider).value;
    final testPhone = lib?.contact.isNotEmpty == true ? lib!.contact : '';

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your SMS Gateway API Key first!')),
      );
      return;
    }
    if (testPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure an official library helpline/phone number in profile first!')),
      );
      return;
    }

    setState(() => _isTestingSmsGateway = true);
    final metaService = ref.read(metaWhatsAppApiServiceProvider);
    final ok = await metaService.testSmsConnection(
      apiKey: apiKey,
      testPhone: testPhone,
      libraryName: lib?.name ?? 'Study Library',
    );
    if (mounted) {
      setState(() => _isTestingSmsGateway = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'SMS Gateway Test Ping Delivered to $testPhone! 📲'
              : 'SMS Gateway delivery failed. Check your API key and account balance.'),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _telegramTokenController.dispose();
    _telegramChatIdController.dispose();
    _localBridgeUrlController.dispose();
    _customWebhookUrlController.dispose();
    _metaPhoneIdController.dispose();
    _metaTokenController.dispose();
    _smsApiKeyController.dispose();
    _smsSenderIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isCompact = MediaQuery.of(context).size.width < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.adminMore);
        }
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Settings',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(Routes.adminMore);
                }
              },
            ),
            title: const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Communications Hub',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF25D366)),
                tooltip: 'WhatsApp & Message Template Studio',
                onPressed: () => context.push(Routes.adminMessageTemplates),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(
                    _isSaving ? 'Saving...' : (isCompact ? 'Save' : 'Save Changes'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bolt_rounded), text: 'Queue'),
              Tab(icon: Icon(Icons.hub_rounded), text: 'Channels'),
              Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'Automations'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildActionQueueTab(theme),
                  _buildChannelsTab(theme),
                  _buildRulesTab(theme),
                ],
              ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: DELIVERY CHANNELS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildChannelsTab(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      children: [
        // Info Banner
        Card(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hub_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Configure your 100% free communication channels. Automated receipts, expiry warnings, and admission alerts dispatch across your enabled rails with zero paid API fees.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Channel 1: Push Notifications (FCM)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.deepOrange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mobile & Web Push Notifications', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('100% Free Instant Mobile & Web Notifications (In-App Push Alerts)', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _pushEnabled,
                      onChanged: (val) => setState(() => _pushEnabled = val),
                    ),
                  ],
                ),
                if (_pushEnabled) ...[
                  const Divider(height: 24),
                  Text(
                    'Pops notifications directly in the student and admin status bar on Android, iOS, and Web browsers.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _testLocalPush,
                    icon: const Icon(Icons.phonelink_ring_rounded, size: 18),
                    label: const Text('Send Test Push on This Device'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Channel 2: 1-Tap WhatsApp
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_rounded, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WhatsApp Direct (1-Tap)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Direct WhatsApp links prefilled with receipts & fee reminders', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _whatsappEnabled,
                  onChanged: (val) => setState(() => _whatsappEnabled = val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Channel 2.5: Direct Meta WhatsApp Cloud API (Automated Background Dispatch)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF075E54).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.mark_chat_read_rounded, color: Color(0xFF075E54)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Direct Meta WhatsApp Cloud API', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('100% hands-free background delivery of payment receipts & alerts (0 taps)', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _metaWhatsAppEnabled,
                      onChanged: (val) => setState(() => _metaWhatsAppEnabled = val),
                    ),
                  ],
                ),
                if (_metaWhatsAppEnabled) ...[
                  const Divider(height: 24),
                  TextField(
                    controller: _metaPhoneIdController,
                    decoration: const InputDecoration(
                      labelText: 'Meta Phone Number ID',
                      hintText: 'e.g. 104829375829104',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                      helperText: 'Found in Meta WhatsApp App Dashboard > API Setup',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _metaTokenController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'System User Permanent Access Token',
                      hintText: 'EAAG...',
                      prefixIcon: Icon(Icons.vpn_key_rounded),
                      border: OutlineInputBorder(),
                      helperText: 'Permanent access token with whatsapp_business_messaging scope',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isTestingMeta ? null : _testMetaWhatsApp,
                    icon: _isTestingMeta
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    label: const Text('Send Test Meta Cloud WhatsApp Message'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Channel 3: Local Desk PC WhatsApp Bridge
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.desktop_windows_rounded, color: Colors.teal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reception Desk WhatsApp Connector', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Automated background WhatsApp via reception desk computer', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _localBridgeEnabled,
                      onChanged: (val) => setState(() => _localBridgeEnabled = val),
                    ),
                  ],
                ),
                if (_localBridgeEnabled) ...[
                  const Divider(height: 24),
                  TextField(
                    controller: _localBridgeUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Reception Desk Connector Address (URL)',
                      hintText: 'e.g. http://192.168.1.50:3000/send',
                      prefixIcon: Icon(Icons.link_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isTestingBridge ? null : _testBridge,
                    icon: _isTestingBridge
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('Test Reception Desk Connection'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Channel 4: Telegram Bot API
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.lightBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Telegram Bot Alerts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Free admin briefings, receipts & system alerts', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _telegramEnabled,
                      onChanged: (val) => setState(() => _telegramEnabled = val),
                    ),
                  ],
                ),
                if (_telegramEnabled) ...[
                  const Divider(height: 24),
                  TextField(
                    controller: _telegramTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Telegram Bot Token',
                      hintText: 'e.g. 123456789:ABCdefGhIJKlmNoPQR',
                      prefixIcon: Icon(Icons.key_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _telegramChatIdController,
                    decoration: const InputDecoration(
                      labelText: 'Chat ID or Channel Username',
                      hintText: 'e.g. -1001234567890 or @mylibrary_alerts',
                      prefixIcon: Icon(Icons.tag_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isTestingTelegram ? null : _testTelegram,
                    icon: _isTestingTelegram
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_outlined),
                    label: const Text('Send Test Telegram Message'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Channel 5: Native Android Direct SMS
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sms_rounded, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Native Device SMS', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Free SMS dispatch using your phone SIM plan', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _smsEnabled,
                      onChanged: (val) => setState(() => _smsEnabled = val),
                    ),
                  ],
                ),
                if (_smsEnabled) ...[
                  const Divider(height: 24),
                  Text(
                    'Pre-fills recipient and fee confirmation into your native SMS app without requiring dangerous SMS read permissions.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Channel 5.5: Commercial SMS Gateway (Automated Background SMS)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.send_to_mobile_rounded, color: Colors.indigo),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SMS Gateway (Fast2SMS / DLT)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Automated background SMS delivery to students', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _smsGatewayEnabled,
                      onChanged: (val) => setState(() => _smsGatewayEnabled = val),
                    ),
                  ],
                ),
                if (_smsGatewayEnabled) ...[
                  const Divider(height: 24),
                  TextField(
                    controller: _smsApiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'SMS Gateway API Key',
                      hintText: 'e.g. Fast2SMS Authorization Key',
                      prefixIcon: Icon(Icons.vpn_key_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _smsSenderIdController,
                    decoration: const InputDecoration(
                      labelText: 'Sender ID / DLT Header (Optional)',
                      hintText: 'e.g. COZYCR or FSTSMS',
                      prefixIcon: Icon(Icons.branding_watermark_rounded),
                      border: OutlineInputBorder(),
                      helperText: 'Default: Fast2SMS Quick Route (DLT-free)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isTestingSmsGateway ? null : _testSmsGateway,
                    icon: _isTestingSmsGateway
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sms_outlined),
                    label: const Text('Send Test Gateway SMS'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Channel 6: Custom Webhook Endpoint
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.webhook_rounded, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('External Webhooks (Zapier & Make)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Trigger external workflows and automations on key events', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _customWebhookEnabled,
                      onChanged: (val) => setState(() => _customWebhookEnabled = val),
                    ),
                  ],
                ),
                if (_customWebhookEnabled) ...[
                  const Divider(height: 24),
                  TextField(
                    controller: _customWebhookUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Connector Webhook URL',
                      hintText: 'https://hooks.zapier.com/hooks/catch/...',
                      prefixIcon: Icon(Icons.http_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Channel 7: Soundbox Counter Voice & Chime Alerts
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Consumer(
              builder: (ctx, cRef, _) {
                final soundbox = cRef.watch(soundboxServiceProvider);
                final libName = cRef.watch(currentLibraryProvider).value?.name ?? 'Cozy Corner';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF059669).withValues(alpha: 0.15),
                          child: const Icon(Icons.speaker_phone_rounded, color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payment Soundbox Audio Alerts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text('Audio chime and vocal payment announcements at the reception desk', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: soundbox.isEnabled,
                          activeTrackColor: const Color(0xFF059669),
                          onChanged: (val) async {
                            await soundbox.setEnabled(val);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                    if (soundbox.isEnabled) ...[
                      const Divider(height: 24),
                      Text('Spoken Readout Language', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('English (en-IN)'),
                            selected: soundbox.language == 'en',
                            onSelected: (sel) async {
                              if (sel) {
                                await soundbox.setLanguage('en');
                                if (mounted) setState(() {});
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('हिन्दी (Hindi)'),
                            selected: soundbox.language == 'hi',
                            onSelected: (sel) async {
                              if (sel) {
                                await soundbox.setLanguage('hi');
                                if (mounted) setState(() {});
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('मराठी (Marathi)'),
                            selected: soundbox.language == 'mr',
                            onSelected: (sel) async {
                              if (sel) {
                                await soundbox.setLanguage('mr');
                                if (mounted) setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.record_voice_over_rounded, size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                soundbox.formatAnnouncement(
                                  amount: 700,
                                  studentName: 'Shubham',
                                  seatLabel: '14',
                                  libraryName: libName,
                                ),
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.music_note_rounded, size: 16),
                            label: const Text('Test Chime'),
                            onPressed: () => soundbox.playChime(),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                            icon: const Icon(Icons.volume_up_rounded, size: 16),
                            label: const Text('Test ₹500 Announcement'),
                            onPressed: () => soundbox.testAnnouncement(soundbox.language, libraryName: libName),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  ),
);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: AUTOMATION RULES & TRIGGERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRulesTab(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      children: [
        // Master Automation Switch
        Card(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
          child: SwitchListTile(
            title: const Text('All Automations', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Master toggle for all automated reminders & alerts'),
            value: _allNotifications,
            onChanged: (val) {
              setState(() {
                _allNotifications = val;
                if (!val) {
                  _newStudentRequest = false;
                  _dailyExpirySummary = false;
                  _studentIssuesAlert = false;
                  _paymentReceipts = false;
                  _planExpiring = false;
                  _planExpired = false;
                  _announcementPush = false;
                }
              });
            },
          ),
        ),
        const SizedBox(height: 18),

        // ── SECTION 1: CORE AUTOMATION ENGINE ───────────────────────────────
        Text(
          'CORE AUTOMATIONS',
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        // Phase 1 Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.autorenew_rounded, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Renewal Reminders', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Notify students before and upon membership expiry', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _multiStageRenewals && _allNotifications,
                      onChanged: _allNotifications ? (val) => setState(() => _multiStageRenewals = val) : null,
                    ),
                  ],
                ),
                if (_multiStageRenewals && _allNotifications) ...[
                  const Divider(height: 20),
                  const Text('Reminder Schedule:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  _buildStageChip('3 Days Before', 'Advance reminder sent to student app', Colors.indigo),
                  const SizedBox(height: 4),
                  _buildStageChip('Expiry Day', 'Due date alert with instant UPI renewal link', Colors.amber.shade900),
                  const SizedBox(height: 4),
                  _buildStageChip('Grace Period', 'Final notice before seat is released to waitlist', Colors.red.shade800),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _triggerTestRenewalPush,
                    icon: const Icon(Icons.send_to_mobile_rounded, size: 16),
                    label: const Text('Send Test Reminder'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Phase 2 Card: Owner Digests
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.mark_email_read_rounded, color: Colors.teal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Daily Owner Briefings", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Morning occupancy & nightly revenue summaries', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.wb_sunny_rounded, color: Colors.orange),
                  title: const Text('8:00 AM Morning Briefing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Occupancy, expiring memberships & pending requests', style: TextStyle(fontSize: 11)),
                  value: _morningBriefing && _allNotifications,
                  onChanged: _allNotifications ? (val) => setState(() => _morningBriefing = val) : null,
                ),
                if (_morningBriefing && _allNotifications)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: _isSendingMorningBriefing ? null : _triggerTestMorningBriefing,
                      icon: _isSendingMorningBriefing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 15),
                      label: Text(_isSendingMorningBriefing ? 'Dispatching...' : 'Preview Morning Briefing'),
                    ),
                  ),
                const Divider(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.nightlight_round, color: Colors.indigo),
                  title: const Text('11:00 PM Nightly Settlement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Daily collections, UPI vs Cash split & receipts', style: TextStyle(fontSize: 11)),
                  value: _nightlySettlement && _allNotifications,
                  onChanged: _allNotifications ? (val) => setState(() => _nightlySettlement = val) : null,
                ),
                if (_nightlySettlement && _allNotifications)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 4),
                    child: OutlinedButton.icon(
                      onPressed: _isSendingNightlySettlement ? null : _triggerTestNightlySettlement,
                      icon: _isSendingNightlySettlement
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 15),
                      label: Text(_isSendingNightlySettlement ? 'Dispatching...' : 'Preview Nightly Settlement'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Phase 3 Card: Waiting List Cascade
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.purple.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.hourglass_bottom_rounded, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Auto Waitlist Allocation', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Fills newly opened seats quickly and fairly', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _waitlistCascade && _allNotifications,
                      onChanged: _allNotifications ? (val) => setState(() => _waitlistCascade = val) : null,
                    ),
                  ],
                ),
                if (_waitlistCascade && _allNotifications) ...[
                  const Divider(height: 20),
                  Text(
                    'When a seat becomes available, it is held for 2 hours for the first student on the waiting list before offering it to the next in line.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isTestingCascade ? null : _triggerTestWaitlistCascade,
                    icon: _isTestingCascade
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(_isTestingCascade ? 'Scanning Waitlist...' : 'Check & Allocate Seats'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── SECTION 2: ADMIN DESK ALERTS ────────────────────────────────────
        Text(
          'ADMIN DESK ALERTS',
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.person_add_alt_1_rounded, color: Colors.blue),
                title: const Text('New Admission Requests', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Instant alert when a student submits an admission form'),
                value: _newStudentRequest && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _newStudentRequest = val) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.alarm_on_rounded, color: Colors.amber),
                title: const Text('Daily Expiry Morning Summary', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('8:00 AM digest of expired seats & renewals due'),
                value: _dailyExpirySummary && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _dailyExpirySummary = val) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.report_problem_rounded, color: Colors.orange),
                title: const Text('Student Issue & Seat Change Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Instant alert when students report issues or request seat changes'),
                value: _studentIssuesAlert && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _studentIssuesAlert = val) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── SECTION 3: STUDENT AUTOMATIONS ──────────────────────────────────
        Text(
          'STUDENT AUTOMATIONS',
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.receipt_long_rounded, color: Colors.green),
                title: const Text('Fee Payment Receipts', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Automatic receipt dispatch via WhatsApp & SMS upon payment'),
                value: _paymentReceipts && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _paymentReceipts = val) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.timelapse_rounded, color: Colors.deepOrange),
                title: const Text('Upcoming Expiry Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Remind students 7 days and 3 days before membership expires'),
                value: _planExpiring && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _planExpiring = val) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.event_busy_rounded, color: Colors.red),
                title: const Text('Plan Expiry Notice', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Notice sent on the day of membership expiry'),
                value: _planExpired && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _planExpired = val) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.campaign_rounded, color: Colors.purple),
                title: const Text('Broadcast Announcements', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Instant push to all enrolled students on new announcements'),
                value: _announcementPush && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _announcementPush = val) : null,
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
  }

  Widget _buildStageChip(String label, String desc, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            desc,
            style: const TextStyle(fontSize: 11.5, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: ACTION QUEUE (1-TAP WHATSAPP NUDGES)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildActionQueueTab(ThemeData theme) {
    var libraryId = ref.watch(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      libraryId = ref.watch(currentLibraryProvider).value?.id ?? CurrentLibraryNotifier.defaultLibraryId;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .where('membershipStatus', whereIn: ['active', 'grace'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(AppErrorFormatter.toUserFriendly(snapshot.error, actionContext: 'announcement')),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        final todayMid = DateTime(now.year, now.month, now.day);
        final todayNudgeKey = 'whatsapp_nudge_${DateFormat('yyyyMMdd').format(now)}';

        final List<Map<String, dynamic>> queueItems = [];

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] as String? ?? 'Student';
          final phone = data['phone'] as String? ?? '';
          final status = data['membershipStatus'] as String? ?? 'active';
          final planId = data['planId'] as String?;
          final planName = data['customPlanName'] ?? data['planName'] ?? (planId != null ? planId.toUpperCase() : 'Monthly');
          final seatId = data['seatId'] as String?;
          final seatLabel = data['seatLabel'] as String? ?? (seatId != null && seatId.isNotEmpty ? 'Seat #$seatId' : null);
          final fee = (data['amount'] as num?)?.toDouble() ?? (data['totalPlanFee'] as num?)?.toDouble() ?? 0.0;
          final remindedStages = List<String>.from(data['remindedStages'] as List<dynamic>? ?? []);
          final isNudgeSentToday = remindedStages.contains(todayNudgeKey);

          DateTime? planEnd;
          final pEndRaw = data['planEndDate'];
          if (pEndRaw is Timestamp) {
            planEnd = pEndRaw.toDate();
          } else if (pEndRaw is String) {
            planEnd = DateTime.tryParse(pEndRaw);
          }

          DateTime? graceEnd;
          final gEndRaw = data['graceEndDate'];
          if (gEndRaw is Timestamp) {
            graceEnd = gEndRaw.toDate();
          } else if (gEndRaw is String) {
            graceEnd = DateTime.tryParse(gEndRaw);
          } else if (planEnd != null) {
            graceEnd = planEnd.add(const Duration(days: 3));
          }

          if (planEnd == null) continue;

          final planEndMid = DateTime(planEnd.year, planEnd.month, planEnd.day);
          final daysLeft = planEndMid.difference(todayMid).inDays;

          final isGrace = status == 'grace' || (now.isAfter(planEnd) && (graceEnd == null || now.isBefore(graceEnd)));

          if (isGrace) {
            final graceEndMid = graceEnd != null ? DateTime(graceEnd.year, graceEnd.month, graceEnd.day) : planEndMid.add(const Duration(days: 3));
            final daysUntilDealloc = graceEndMid.difference(todayMid).inDays;

            queueItems.add({
              'id': doc.id,
              'name': name,
              'phone': phone,
              'status': status,
              'planName': planName,
              'seatLabel': seatLabel,
              'planEnd': planEnd,
              'graceEnd': graceEnd,
              'planFee': fee,
              'category': 'grace',
              'stage': 'T+2',
              'badgeText': daysUntilDealloc <= 1 ? 'GRACE: RELEASES TOMORROW' : 'GRACE: SEAT HELD ($daysUntilDealloc DAYS LEFT)',
              'badgeColor': const Color(0xFFF59E0B),
              'isNudgeSentToday': isNudgeSentToday,
              'daysLeft': daysLeft,
            });
          } else if (daysLeft == 0) {
            queueItems.add({
              'id': doc.id,
              'name': name,
              'phone': phone,
              'status': status,
              'planName': planName,
              'seatLabel': seatLabel,
              'planEnd': planEnd,
              'graceEnd': graceEnd,
              'planFee': fee,
              'category': 'today',
              'stage': 'T-0',
              'badgeText': 'EXPIRES TODAY',
              'badgeColor': const Color(0xFFEF4444),
              'isNudgeSentToday': isNudgeSentToday,
              'daysLeft': daysLeft,
            });
          } else if (daysLeft > 0 && daysLeft <= 3) {
            queueItems.add({
              'id': doc.id,
              'name': name,
              'phone': phone,
              'status': status,
              'planName': planName,
              'seatLabel': seatLabel,
              'planEnd': planEnd,
              'graceEnd': graceEnd,
              'planFee': fee,
              'category': 'upcoming',
              'stage': 'T-3',
              'badgeText': daysLeft == 1 ? 'EXPIRES IN 1 DAY' : 'EXPIRES IN $daysLeft DAYS',
              'badgeColor': const Color(0xFF6366F1),
              'isNudgeSentToday': isNudgeSentToday,
              'daysLeft': daysLeft,
            });
          }
        }

        // Sort: grace first, then today, then upcoming
        queueItems.sort((a, b) {
          final catOrder = {'grace': 0, 'today': 1, 'upcoming': 2};
          final cA = catOrder[a['category']] ?? 3;
          final cB = catOrder[b['category']] ?? 3;
          if (cA != cB) return cA.compareTo(cB);
          return (a['daysLeft'] as int).compareTo(b['daysLeft'] as int);
        });

        final totalGrace = queueItems.where((i) => i['category'] == 'grace').length;
        final totalToday = queueItems.where((i) => i['category'] == 'today').length;
        final totalUpcoming = queueItems.where((i) => i['category'] == 'upcoming').length;

        final filteredItems = _actionFilter == 'all'
            ? queueItems
            : queueItems.where((i) => i['category'] == _actionFilter).toList();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              children: [
                // Top Action Banner
                Card(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bolt_rounded, color: Color(0xFF25D366), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Priority Action Queue',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '1-Tap WhatsApp follow-ups for students expiring soon, due today, or in grace period.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // KPI Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'In Grace',
                        count: totalGrace,
                        color: const Color(0xFFF59E0B),
                        icon: Icons.hourglass_top_rounded,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Expires Today',
                        count: totalToday,
                        color: const Color(0xFFEF4444),
                        icon: Icons.notification_important_rounded,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Upcoming (3d)',
                        count: totalUpcoming,
                        color: const Color(0xFF6366F1),
                        icon: Icons.calendar_today_rounded,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _actionFilter == 'all',
                        label: Text('All Actions (${queueItems.length})'),
                        onSelected: (_) => setState(() => _actionFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _actionFilter == 'grace',
                        label: Text('In Grace ($totalGrace)'),
                        selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _actionFilter = 'grace'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _actionFilter == 'today',
                        label: Text('Expires Today ($totalToday)'),
                        selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _actionFilter = 'today'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _actionFilter == 'upcoming',
                        label: Text('Upcoming ($totalUpcoming)'),
                        selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _actionFilter = 'upcoming'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Empty state or list
                if (filteredItems.isEmpty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
                          const SizedBox(height: 12),
                          Text(
                            'All Student Memberships Up to Date!',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No members are currently in grace period or expiring within the next 3 days.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  for (final item in filteredItems) ...[
                    _buildStudentActionCard(item, theme),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                count.toString(),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentActionCard(Map<String, dynamic> item, ThemeData theme) {
    final name = item['name'] as String;
    final phone = item['phone'] as String;
    final seatLabel = item['seatLabel'] as String?;
    final planName = item['planName'] as String;
    final planFee = item['planFee'] as double;
    final badgeText = item['badgeText'] as String;
    final badgeColor = item['badgeColor'] as Color;
    final isNudgeSentToday = item['isNudgeSentToday'] as bool;
    final isSending = _sendingStudentId == item['id'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: badgeColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: badgeColor.withValues(alpha: 0.15),
                  foregroundColor: badgeColor,
                  radius: 20,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                phone.isNotEmpty ? phone : 'No phone',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          if (seatLabel != null) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chair_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  seatLabel,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                planName,
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isNudgeSentToday)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Nudge Sent Today',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                else
                  Text(
                    planFee > 0 ? 'Fee: ₹${planFee.toStringAsFixed(0)}' : 'Renewal Pending',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSending ? null : () => _sendWhatsAppNudge(item),
                  icon: isSending
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.chat_bubble_rounded, size: 14),
                  label: Text(
                    isNudgeSentToday ? 'Re-send WhatsApp' : 'Nudge on WhatsApp',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppNudge(Map<String, dynamic> item) async {
    final studentName = item['name'] as String;
    final phone = item['phone'] as String;
    final seatLabel = item['seatLabel'] as String?;
    final stage = item['stage'] as String;
    final planEnd = item['planEnd'] as DateTime?;
    final planFee = item['planFee'] as double?;
    final studentDocId = item['id'] as String;

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No phone number recorded for $studentName')),
      );
      return;
    }

    setState(() => _sendingStudentId = studentDocId);
    try {
      final libraryName = ref.read(currentLibraryProvider).value?.name ?? 'The Cozy Corner Study Centre';
      final libraryHelpline = ref.read(currentLibraryProvider).value?.phone ?? '';
      final libraryUpiId = ref.read(currentLibraryProvider).value?.upiId ?? '';

      final success = await WhatsAppService().sendStageRenewalReminder(
        phone,
        studentName,
        stage,
        libraryName: libraryName,
        seatLabel: seatLabel ?? '',
        expiryDate: planEnd != null ? DateFormat('dd MMM yyyy').format(planEnd) : null,
        libraryHelpline: libraryHelpline,
        libraryUpiId: libraryUpiId,
        renewalAmount: planFee,
        context: mounted ? context : null,
      );

      if (success && mounted) {
        final now = DateTime.now();
        final todayNudgeKey = 'whatsapp_nudge_${DateFormat('yyyyMMdd').format(now)}';
        var libraryId = ref.read(currentLibraryIdProvider);
        if (libraryId == null || libraryId.isEmpty) {
          libraryId = ref.read(currentLibraryProvider).value?.id ?? CurrentLibraryNotifier.defaultLibraryId;
        }

        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .doc(studentDocId)
            .update({
          'remindedStages': FieldValue.arrayUnion([todayNudgeKey]),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ WhatsApp reminder opened for $studentName!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'announcement');
      }
    } finally {
      if (mounted) {
        setState(() => _sendingStudentId = null);
      }
    }
  }
}
