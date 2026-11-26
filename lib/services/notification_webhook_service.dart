import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// NotificationWebhookService dispatches JSON webhooks to custom endpoints
/// (e.g. WhatsApp gateways, Zapier, Make, Telegram bots) for automated alerts.
/// Cross-platform: uses `package:http` so Web, Android, iOS, and Desktop all work safely.
class NotificationWebhookService {
  final FirebaseFirestore _firestore;

  NotificationWebhookService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetch unified webhook configuration (checks admin_secrets/communications + settings/communications, then legacy webhooks).
  Future<Map<String, dynamic>?> _getWebhookConfig(String libraryId) async {
    try {
      final libRef = _firestore.collection('libraries').doc(libraryId);
      final results = await Future.wait([
        libRef.collection('admin_secrets').doc('communications').get(),
        libRef.collection('settings').doc('communications').get(),
        libRef.collection('settings').doc('webhooks').get(),
      ]);

      final secretData = results[0].data() ?? {};
      final commsData = results[1].data() ?? {};
      final commsChannels = (commsData['channels'] as Map<String, dynamic>?) ?? {};
      final legacyData = results[2].data() ?? {};

      final unifiedUrl = (secretData['customWebhookUrl'] as String?)?.trim() ??
          (commsChannels['customWebhookUrl'] as String?)?.trim() ??
          (commsData['customWebhookUrl'] as String?)?.trim();
      final unifiedEnabled = (commsChannels['customWebhookEnabled'] as bool?) ??
          (commsData['customWebhookEnabled'] as bool? ?? false);

      if (unifiedEnabled && unifiedUrl != null && unifiedUrl.isNotEmpty) {
        return {
          'enablePaymentWebhooks': true,
          'enableExpiryWebhooks': true,
          'paymentWebhookUrl': unifiedUrl,
          'expiryWebhookUrl': unifiedUrl,
        };
      }

      if (legacyData.isNotEmpty) {
        return legacyData;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching webhook config: $e');
    }
    return null;
  }

  /// Sends a POST request with JSON payload to the configured endpoint.
  Future<bool> _postWebhook(String url, Map<String, dynamic> payload) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      if (kDebugMode) debugPrint('Webhook dispatch error: $e');
      return false;
    }
  }

  /// Dispatches automated payment receipt webhook.
  Future<void> dispatchPaymentWebhook({
    required String libraryId,
    required String studentName,
    required String studentPhone,
    required double amount,
    required String planName,
    required String receiptId,
  }) async {
    try {
      final config = await _getWebhookConfig(libraryId);
      if (config == null) return;

      final url = config['paymentWebhookUrl'] as String?;
      final enabled = config['enablePaymentWebhooks'] as bool? ?? false;
      if (!enabled || url == null || url.trim().isEmpty) return;

      final payload = {
        'event': 'PAYMENT_RECEIVED',
        'timestamp': DateTime.now().toIso8601String(),
        'libraryId': libraryId,
        'receiptId': receiptId,
        'student': {
          'name': studentName,
          'phone': studentPhone,
        },
        'payment': {
          'amount': amount,
          'plan': planName,
        },
      };

      await _postWebhook(url.trim(), payload);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to dispatch payment webhook: $e');
    }
  }

  /// Dispatches plan expiring reminder webhook.
  Future<void> dispatchExpiryAlertWebhook({
    required String libraryId,
    required String studentName,
    required String studentPhone,
    required String planName,
    required int daysRemaining,
  }) async {
    try {
      final config = await _getWebhookConfig(libraryId);
      if (config == null) return;

      final url = config['expiryWebhookUrl'] as String?;
      final enabled = config['enableExpiryWebhooks'] as bool? ?? false;
      if (!enabled || url == null || url.trim().isEmpty) return;

      final payload = {
        'event': 'PLAN_EXPIRING_SOON',
        'timestamp': DateTime.now().toIso8601String(),
        'libraryId': libraryId,
        'student': {
          'name': studentName,
          'phone': studentPhone,
        },
        'plan': {
          'name': planName,
          'daysRemaining': daysRemaining,
        },
      };

      await _postWebhook(url.trim(), payload);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to dispatch expiry webhook: $e');
    }
  }
}

final notificationWebhookServiceProvider = Provider<NotificationWebhookService>((ref) {
  return NotificationWebhookService();
});
