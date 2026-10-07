import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// NotificationWebhookService dispatches JSON webhooks to custom endpoints
/// (e.g. WhatsApp gateways, Zapier, Make, Telegram bots) for automated alerts.
class NotificationWebhookService {
  final FirebaseFirestore _firestore;

  NotificationWebhookService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetch webhook configuration for the given library.
  Future<Map<String, dynamic>?> _getWebhookConfig(String libraryId) async {
    try {
      final doc = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('webhooks')
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('Error fetching webhook config: $e');
    }
    return null;
  }

  /// Sends a POST request with JSON payload to the configured endpoint.
  Future<bool> _postWebhook(String url, Map<String, dynamic> payload) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Webhook dispatch error: $e');
      return false;
    } finally {
      client?.close();
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
      debugPrint('Failed to dispatch payment webhook: $e');
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
      debugPrint('Failed to dispatch expiry webhook: $e');
    }
  }
}

final notificationWebhookServiceProvider = Provider<NotificationWebhookService>((ref) {
  return NotificationWebhookService();
});
