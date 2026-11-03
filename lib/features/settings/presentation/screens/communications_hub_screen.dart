import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/telegram_service.dart';
import 'package:study_library/services/local_bridge_service.dart';
import 'package:study_library/services/notification_service.dart';
import 'package:study_library/services/owner_digest_service.dart';
import 'package:study_library/services/waiting_list_promotion_service.dart';

class CommunicationsHubScreen extends ConsumerStatefulWidget {
  const CommunicationsHubScreen({super.key});

  @override
  ConsumerState<CommunicationsHubScreen> createState() => _CommunicationsHubScreenState();
}

class _CommunicationsHubScreenState extends ConsumerState<CommunicationsHubScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

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
        title: '📅 Test: Plan Expiring in 3 Days (T-3)',
        body: 'Hello Student, your membership for Seat #2 at $libName completes in 3 days. Renew now to retain your seat!',
        channelId: NotificationService.channelGeneral,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Multi-Stage Renewal (T-3) test prompt delivered to status bar! 📲'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error triggering prompt: $e'), backgroundColor: Colors.red),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
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
        const SnackBar(content: Text('Please enter the Local Desk PC Bridge URL first!')),
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
          content: Text(ok ? 'Desk PC Bridge Connected! ✅' : 'Could not reach Desk PC. Verify local IP and port.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error triggering notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _telegramTokenController.dispose();
    _telegramChatIdController.dispose();
    _localBridgeUrlController.dispose();
    _customWebhookUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Settings',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/admin/more');
              }
            },
          ),
          title: const Text('Communications & Automation'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.hub_rounded), text: 'Delivery Channels'),
              Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'Automation Rules'),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving Configuration...' : 'Save Communications Configuration', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildChannelsTab(theme),
                  _buildRulesTab(theme),
                ],
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
                          Text('100% Free Firebase Cloud Messaging (FCM)', style: theme.textTheme.bodySmall),
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

        // Channel 2: 1-Tap WhatsApp (wa.me)
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
                      Text('1-Tap WhatsApp (wa.me)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Direct WhatsApp links prefilled with receipt details & 0 cost', style: theme.textTheme.bodySmall),
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
                          Text('Local Desk PC WhatsApp Bridge', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Automated background WhatsApp via reception computer', style: theme.textTheme.bodySmall),
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
                      labelText: 'Desk PC Bridge URL',
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
                    label: const Text('Test Connection (Ping Desk PC)'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Channel 4: Official Telegram Bot API
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
                          Text('Official Telegram Bot API', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Unlimited free receipts & desk administration alerts', style: theme.textTheme.bodySmall),
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
                          Text('Native Android Direct SMS (SIM)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('100% Free via Jio/Airtel daily quota', style: theme.textTheme.bodySmall),
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
                          Text('Custom Webhook Endpoint', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Post JSON events to your own server or Zapier', style: theme.textTheme.bodySmall),
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
                      labelText: 'Webhook URL',
                      hintText: 'https://your-service.com/webhook',
                      prefixIcon: Icon(Icons.http_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
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
            title: const Text('Master Automation Switch', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Enable or pause all automated alerts across channels'),
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

        // ── SECTION 1: CORE AUTOMATION ENGINE (PHASES 1, 2, 3) ───────────────
        Text(
          'CORE LIBRARY AUTOMATIONS (PHASES 1, 2, 3)',
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
                          Text('Multi-Stage Renewal Engine (Phase 1)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Eliminates collection chasing with staged alerts', style: theme.textTheme.bodySmall),
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
                  const Text('Automated Lifecycle Alerts Dispatched:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  _buildStageChip('T-3 Days', 'Upcoming renewal reminder to student app & push', Colors.indigo),
                  const SizedBox(height: 4),
                  _buildStageChip('T-0 Today', 'Urgent expiration notice + 1-Tap UPI payment link', Colors.amber.shade900),
                  const SizedBox(height: 4),
                  _buildStageChip('T+2 Grace', 'Final warning: desk released to waitlist tomorrow', Colors.red.shade800),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _triggerTestRenewalPush,
                    icon: const Icon(Icons.send_to_mobile_rounded, size: 16),
                    label: const Text('Send Test T-3 Push Prompt (This Device)'),
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
                          Text("Owner's Daily Executive Digests (Phase 2)", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Automated operational & financial clarity zero searching', style: theme.textTheme.bodySmall),
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
                  subtitle: const Text('Occupancy %, expiring today, waitlist queue & pending requests', style: TextStyle(fontSize: 11)),
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
                      label: Text(_isSendingMorningBriefing ? 'Dispatching...' : 'Send 8 AM Morning Briefing Now (Preview)'),
                    ),
                  ),
                const Divider(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.nightlight_round, color: Colors.indigo),
                  title: const Text('11:00 PM Nightly Financial Settlement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Total revenue, UPI vs Cash breakdown, official receipts & admissions', style: TextStyle(fontSize: 11)),
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
                      label: Text(_isSendingNightlySettlement ? 'Dispatching...' : 'Send 11 PM Nightly Settlement Now (Preview)'),
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
                          Text('Automated Waiting-List Cascade (Phase 3)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Fills vacated seats within hours automatically', style: theme.textTheme.bodySmall),
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
                    'When a student vacates a seat after grace expiry, the desk is held exclusively for 2 hours for candidate #1. If unclaimed within 2 hours, it automatically cascades to candidate #2.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isTestingCascade ? null : _triggerTestWaitlistCascade,
                    icon: _isTestingCascade
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(_isTestingCascade ? 'Scanning Holds...' : 'Run Waiting List Cascade Check Now'),
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
                subtitle: const Text('8:00 AM summary of expired students & renewals due'),
                value: _dailyExpirySummary && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _dailyExpirySummary = val) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.report_problem_rounded, color: Colors.orange),
                title: const Text('Student Issue & Seat Change Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Immediate notification when students submit issues or seat requests'),
                value: _studentIssuesAlert && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _studentIssuesAlert = val) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── SECTION 2: STUDENT AUTOMATIONS ──────────────────────────────────
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
                title: const Text('Plan Expiring Reminders (7-day & 3-day)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Automated gentle reminder prompts to renew upcoming expirations'),
                value: _planExpiring && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _planExpiring = val) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.event_busy_rounded, color: Colors.red),
                title: const Text('Plan Expired Notice', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Notice sent on the day of membership expiry'),
                value: _planExpired && _allNotifications,
                onChanged: _allNotifications ? (val) => setState(() => _planExpired = val) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.campaign_rounded, color: Colors.purple),
                title: const Text('Library Announcements & Broadcasts', style: TextStyle(fontWeight: FontWeight.w600)),
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
}
