import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/services/sms_service.dart';
import 'package:study_library/services/telegram_service.dart';
import 'package:study_library/services/local_bridge_service.dart';
import 'package:study_library/services/notification_webhook_service.dart';

/// MessagingConfig holds the unified configuration for all notification channels.
class MessagingConfig {
  final bool smsEnabled;
  final bool telegramEnabled;
  final String telegramBotToken;
  final String telegramChatId;
  final bool localBridgeEnabled;
  final String localBridgeUrl;
  final bool whatsappEnabled;
  final bool customWebhookEnabled;
  final String customWebhookUrl;

  const MessagingConfig({
    this.smsEnabled = false,
    this.telegramEnabled = false,
    this.telegramBotToken = '',
    this.telegramChatId = '',
    this.localBridgeEnabled = false,
    this.localBridgeUrl = '',
    this.whatsappEnabled = true,
    this.customWebhookEnabled = false,
    this.customWebhookUrl = '',
  });

  factory MessagingConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const MessagingConfig();
    return MessagingConfig(
      smsEnabled: data['smsEnabled'] as bool? ?? false,
      telegramEnabled: data['telegramEnabled'] as bool? ?? false,
      telegramBotToken: data['telegramBotToken'] as String? ?? '',
      telegramChatId: data['telegramChatId'] as String? ?? '',
      localBridgeEnabled: data['localBridgeEnabled'] as bool? ?? false,
      localBridgeUrl: data['localBridgeUrl'] as String? ?? '',
      whatsappEnabled: data['whatsappEnabled'] as bool? ?? true,
      customWebhookEnabled: data['customWebhookEnabled'] as bool? ?? false,
      customWebhookUrl: data['customWebhookUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'smsEnabled': smsEnabled,
    'telegramEnabled': telegramEnabled,
    'telegramBotToken': telegramBotToken,
    'telegramChatId': telegramChatId,
    'localBridgeEnabled': localBridgeEnabled,
    'localBridgeUrl': localBridgeUrl,
    'whatsappEnabled': whatsappEnabled,
    'customWebhookEnabled': customWebhookEnabled,
    'customWebhookUrl': customWebhookUrl,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// MessagingHubService coordinates dispatches across all active free communication channels.
class MessagingHubService {
  final FirebaseFirestore _firestore;
  final SmsService _sms;
  final TelegramService _telegram;
  final LocalBridgeService _bridge;
  final NotificationWebhookService _webhook;

  MessagingHubService({
    FirebaseFirestore? firestore,
    SmsService? sms,
    TelegramService? telegram,
    LocalBridgeService? bridge,
    NotificationWebhookService? webhook,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _sms = sms ?? SmsService(),
        _telegram = telegram ?? TelegramService(),
        _bridge = bridge ?? LocalBridgeService(),
        _webhook = webhook ?? NotificationWebhookService();

  /// Fetches messaging configuration for the given library.
  Future<MessagingConfig> getConfig(String libraryId) async {
    if (libraryId.isEmpty) return const MessagingConfig();
    try {
      final doc = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('messaging')
          .get();
      return MessagingConfig.fromMap(doc.data());
    } catch (e) {
      debugPrint('Error loading messaging config: $e');
      return const MessagingConfig();
    }
  }

  /// Saves updated messaging configuration.
  Future<bool> saveConfig(String libraryId, MessagingConfig config) async {
    if (libraryId.isEmpty) return false;
    try {
      await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('messaging')
          .set(config.toMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error saving messaging config: $e');
      return false;
    }
  }

  /// Dispatches payment confirmation across all enabled channels simultaneously.
  Future<Map<String, bool>> dispatchPaymentConfirmation({
    required String libraryId,
    required String studentName,
    required String studentPhone,
    required String libraryName,
    required double amount,
    required String receiptNumber,
    required String paymentMethod,
    double? remainingDue,
  }) async {
    final config = await getConfig(libraryId);
    final results = <String, bool>{};

    // 1. Android Direct SMS (Native SIM)
    if (config.smsEnabled && studentPhone.trim().isNotEmpty) {
      try {
        final smsSuccess = await _sms.sendPaymentReceiptSms(
          phone: studentPhone,
          studentName: studentName,
          libraryName: libraryName,
          amount: amount,
          receiptNumber: receiptNumber,
          remainingDue: remainingDue,
        );
        results['sms'] = smsSuccess;
      } catch (e) {
        debugPrint('Dispatch SMS error: $e');
        results['sms'] = false;
      }
    }

    // 2. Telegram Bot API
    if (config.telegramEnabled && config.telegramBotToken.isNotEmpty && config.telegramChatId.isNotEmpty) {
      try {
        final tgSuccess = await _telegram.sendPaymentAlert(
          botToken: config.telegramBotToken,
          chatId: config.telegramChatId,
          studentName: studentName,
          libraryName: libraryName,
          amount: amount,
          receiptNumber: receiptNumber,
          paymentMethod: paymentMethod,
          remainingDue: remainingDue,
        );
        results['telegram'] = tgSuccess;
      } catch (e) {
        debugPrint('Dispatch Telegram error: $e');
        results['telegram'] = false;
      }
    }

    // 3. Local Desk PC WhatsApp Bridge
    if (config.localBridgeEnabled && config.localBridgeUrl.isNotEmpty && studentPhone.trim().isNotEmpty) {
      try {
        final dueText = (remainingDue != null && remainingDue > 0)
            ? ' Remaining Due: ₹${remainingDue.toStringAsFixed(0)}.'
            : '';
        final message = '✅ Payment Received!\n'
            'Hi $studentName, payment of ₹${amount.toStringAsFixed(0)} received at $libraryName. '
            'Receipt No: $receiptNumber.$dueText Thank you! 🙏';
        final bridgeSuccess = await _bridge.sendMessage(
          bridgeUrl: config.localBridgeUrl,
          phone: studentPhone,
          message: message,
        );
        results['local_bridge'] = bridgeSuccess;
      } catch (e) {
        debugPrint('Dispatch Local Bridge error: $e');
        results['local_bridge'] = false;
      }
    }

    // 4. Custom Webhook
    if (config.customWebhookEnabled && config.customWebhookUrl.isNotEmpty) {
      try {
        await _webhook.dispatchPaymentWebhook(
          libraryId: libraryId,
          studentName: studentName,
          studentPhone: studentPhone,
          amount: amount,
          planName: 'Library Subscription',
          receiptId: receiptNumber,
        );
        results['webhook'] = true;
      } catch (e) {
        debugPrint('Dispatch Webhook error: $e');
        results['webhook'] = false;
      }
    }

    return results;
  }
}

final messagingHubServiceProvider = Provider<MessagingHubService>((ref) {
  return MessagingHubService(
    sms: ref.read(smsServiceProvider),
    telegram: ref.read(telegramServiceProvider),
    bridge: ref.read(localBridgeServiceProvider),
    webhook: ref.read(notificationWebhookServiceProvider),
  );
});
