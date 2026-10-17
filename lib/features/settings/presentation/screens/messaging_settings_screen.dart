import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/messaging_hub_service.dart';
import 'package:study_library/services/telegram_service.dart';
import 'package:study_library/services/local_bridge_service.dart';

class MessagingSettingsScreen extends ConsumerStatefulWidget {
  const MessagingSettingsScreen({super.key});

  @override
  ConsumerState<MessagingSettingsScreen> createState() => _MessagingSettingsScreenState();
}

class _MessagingSettingsScreenState extends ConsumerState<MessagingSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // SMS
  bool _smsEnabled = false;

  // Telegram
  bool _telegramEnabled = false;
  final _telegramTokenController = TextEditingController();
  final _telegramChatIdController = TextEditingController();
  bool _isTestingTelegram = false;

  // WhatsApp 1-tap
  bool _whatsappEnabled = true;

  // Local Bridge
  bool _localBridgeEnabled = false;
  final _localBridgeUrlController = TextEditingController();
  bool _isTestingBridge = false;

  // Custom Webhook
  bool _customWebhookEnabled = false;
  final _customWebhookUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final hub = ref.read(messagingHubServiceProvider);
    final config = await hub.getConfig(libraryId);

    if (mounted) {
      setState(() {
        _smsEnabled = config.smsEnabled;
        _telegramEnabled = config.telegramEnabled;
        _telegramTokenController.text = config.telegramBotToken;
        _telegramChatIdController.text = config.telegramChatId;
        _whatsappEnabled = config.whatsappEnabled;
        _localBridgeEnabled = config.localBridgeEnabled;
        _localBridgeUrlController.text = config.localBridgeUrl;
        _customWebhookEnabled = config.customWebhookEnabled;
        _customWebhookUrlController.text = config.customWebhookUrl;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    final hub = ref.read(messagingHubServiceProvider);
    final config = MessagingConfig(
      smsEnabled: _smsEnabled,
      telegramEnabled: _telegramEnabled,
      telegramBotToken: _telegramTokenController.text.trim(),
      telegramChatId: _telegramChatIdController.text.trim(),
      whatsappEnabled: _whatsappEnabled,
      localBridgeEnabled: _localBridgeEnabled,
      localBridgeUrl: _localBridgeUrlController.text.trim(),
      customWebhookEnabled: _customWebhookEnabled,
      customWebhookUrl: _customWebhookUrlController.text.trim(),
    );

    final success = await hub.saveConfig(libraryId, config);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Messaging settings saved successfully! ✅' : 'Failed to save settings ❌'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
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
    final ok = await tg.testConnection(botToken: token, chatId: chatId);
    if (mounted) {
      setState(() => _isTestingTelegram = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Telegram Test Message Sent Successfully! 🚀' : 'Failed to reach Telegram Bot. Check Token & Chat ID.'),
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
          content: Text(ok ? 'Desk PC Bridge Connected! ✅' : 'Could not reach Desk PC. Verify IP and port.'),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging & Notification Hub'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Saving Settings...' : 'Save Messaging Configuration'),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Info Header
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
                        Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Configure 100% free messaging channels. The system dispatches payment receipts and expiry alerts using your enabled channels without paid APIs.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Channel 1: Native Android Direct SMS
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
                            'Sends text SMS using the admin phone SIM card (utilizing your plan\'s 100 free SMS/day). Launches your native SMS app with recipient and receipt prefilled—100% permission-free and verified safe by Google Play Protect.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Chip(
                                label: const Text('Verified Safe • No Risky Permissions'),
                                avatar: const Icon(
                                  Icons.verified_user_rounded,
                                  color: Colors.green,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Channel 2: Official Telegram Bot API
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
                                  Text('Unlimited free receipts & channel alerts', style: theme.textTheme.bodySmall),
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
                const SizedBox(height: 16),

                // Channel 3: 1-Tap WhatsApp Intent
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
                              Text('Pre-fills receipt text & student number with 0 cost', style: theme.textTheme.bodySmall),
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
                const SizedBox(height: 16),

                // Channel 4: Local WhatsApp Desk PC Bridge
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
                                  Text('Free background WhatsApp via reception computer', style: theme.textTheme.bodySmall),
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
                const SizedBox(height: 16),

                // Channel 5: Custom Webhook Endpoint
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
    );
  }
}
