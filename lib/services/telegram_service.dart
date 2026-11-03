import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// TelegramService enables 100% free messaging and alerts via the official Telegram Bot API.
/// Requires zero servers, zero credit card, and offers unlimited free messages across Web, Android, iOS, and Desktop.
class TelegramService {
  /// Sends a message via the Telegram Bot API.
  Future<bool> sendMessage({
    required String botToken,
    required String chatId,
    required String message,
  }) async {
    final cleanToken = botToken.trim();
    final cleanChatId = chatId.trim();

    if (cleanToken.isEmpty || cleanChatId.isEmpty) {
      if (kDebugMode) debugPrint('TelegramService: Bot token or chat ID is empty');
      return false;
    }

    try {
      final url = Uri.parse('https://api.telegram.org/bot$cleanToken/sendMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': cleanChatId,
          'text': message,
          'parse_mode': 'HTML',
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        if (kDebugMode) debugPrint('TelegramService: Message sent successfully');
        return true;
      } else {
        if (kDebugMode) debugPrint('TelegramService error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('TelegramService network error: $e');
      return false;
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
    String? libraryName,
  }) async {
    final header = libraryName?.isNotEmpty == true ? libraryName! : 'The Cozy Corner Study Centre';
    final message = '🚀 <b>$header</b>\n\n'
        'Telegram Bot notification integration is <b>active & verified</b>! ✅\n'
        '<i>Timestamp: ${DateTime.now().toIso8601String()}</i>';
    return await sendMessage(botToken: botToken, chatId: chatId, message: message);
  }
}

final telegramServiceProvider = Provider<TelegramService>((ref) => TelegramService());
