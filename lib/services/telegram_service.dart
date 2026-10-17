import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TelegramService enables 100% free messaging and alerts via the official Telegram Bot API.
/// Requires zero servers, zero credit card, and offers unlimited free messages.
class TelegramService {
  /// Sends a message via the Telegram Bot API.
  Future<bool> sendMessage({
    required String botToken,
    required String chatId,
    required String message,
  }) async {
    if (botToken.trim().isEmpty || chatId.trim().isEmpty) {
      debugPrint('TelegramService: Bot token or chat ID is empty');
      return false;
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final url = Uri.parse('https://api.telegram.org/bot${botToken.trim()}/sendMessage');
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;

      final body = jsonEncode({
        'chat_id': chatId.trim(),
        'text': message,
        'parse_mode': 'HTML',
      });

      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        debugPrint('TelegramService: Message sent successfully');
        return true;
      } else {
        debugPrint('TelegramService error (${response.statusCode}): $responseBody');
        return false;
      }
    } catch (e) {
      debugPrint('TelegramService network error: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  /// Sends a formatted payment confirmation alert to a Telegram chat or channel.
  Future<bool> sendPaymentAlert({
    required String botToken,
    required String chatId,
    required String studentName,
    required String libraryName,
    required double amount,
    required String receiptNumber,
    required String paymentMethod,
    double? remainingDue,
  }) async {
    final dueLine = (remainingDue != null && remainingDue > 0)
        ? '\n⚠️ <b>Pending Balance:</b> ₹${remainingDue.toStringAsFixed(0)}'
        : '';
    final message = '💰 <b>Payment Received!</b>\n\n'
        '🏛️ <b>Library:</b> $libraryName\n'
        '👤 <b>Student:</b> $studentName\n'
        '💵 <b>Amount Paid:</b> ₹${amount.toStringAsFixed(0)}\n'
        '💳 <b>Mode:</b> $paymentMethod\n'
        '🧾 <b>Receipt No:</b> <code>$receiptNumber</code>'
        '$dueLine\n\n'
        '<i>Recorded at: ${DateTime.now().toString().substring(0, 16)}</i>';

    return await sendMessage(botToken: botToken, chatId: chatId, message: message);
  }

  /// Sends an expiry warning to the Telegram channel.
  Future<bool> sendExpiryAlert({
    required String botToken,
    required String chatId,
    required String studentName,
    required String libraryName,
    required int daysRemaining,
    String? phone,
  }) async {
    final phoneLine = (phone != null && phone.isNotEmpty) ? '\n📞 <b>Phone:</b> $phone' : '';
    final daysText = daysRemaining == 0
        ? '<b>Expires Today!</b>'
        : 'Expires in <b>$daysRemaining day(s)</b>';

    final message = '⏰ <b>Membership Expiry Warning</b>\n\n'
        '🏛️ <b>Library:</b> $libraryName\n'
        '👤 <b>Student:</b> $studentName'
        '$phoneLine\n'
        '📅 <b>Status:</b> $daysText\n\n'
        '<i>Action: Please contact the student for renewal.</i>';

    return await sendMessage(botToken: botToken, chatId: chatId, message: message);
  }

  /// Tests the Telegram bot connection by sending a ping message.
  Future<bool> testConnection({
    required String botToken,
    required String chatId,
  }) async {
    final message = '🚀 <b>Cozy Corner Library System</b>\n\n'
        'Telegram Bot notification integration is <b>active & verified</b>! ✅\n'
        '<i>Timestamp: ${DateTime.now().toIso8601String()}</i>';
    return await sendMessage(botToken: botToken, chatId: chatId, message: message);
  }
}

final telegramServiceProvider = Provider<TelegramService>((ref) => TelegramService());
