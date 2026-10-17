import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// SmsService enables 100% free SMS messaging via the admin device's native SIM card.
/// Uses Android's official SMS intent with prefilled recipient and message (zero dangerous permissions).
class SmsService {

  /// Cleans phone number to standard format.
  String sanitizePhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    return digits;
  }

  /// Sends SMS by launching the default SMS composer with recipient and text prefilled.
  /// 100% permission-free, uses device SIM quota, and complies with Google Play Protect.
  Future<bool> sendDirectSms({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = sanitizePhone(phone);
    if (cleanPhone.length < 10) {
      debugPrint('SmsService: Invalid phone number: $phone');
      return false;
    }

    try {
      final uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('SmsService error: $e');
    }
    return false;
  }

  /// Sends automated payment confirmation SMS.
  Future<bool> sendPaymentReceiptSms({
    required String phone,
    required String studentName,
    required String libraryName,
    required double amount,
    required String receiptNumber,
    double? remainingDue,
  }) async {
    final dueText = (remainingDue != null && remainingDue > 0)
        ? ' Remaining Due: ₹${remainingDue.toStringAsFixed(0)}.'
        : '';
    final message = 'Payment Confirmed!\n'
        'Hi $studentName, payment of ₹${amount.toStringAsFixed(0)} received at $libraryName. '
        'Receipt No: $receiptNumber.$dueText Thank you!';
    return await sendDirectSms(phone: phone, message: message);
  }

  /// Sends membership expiry reminder SMS.
  Future<bool> sendExpiryAlertSms({
    required String phone,
    required String studentName,
    required String libraryName,
    required int daysRemaining,
  }) async {
    final daysText = daysRemaining == 0
        ? 'today'
        : (daysRemaining == 1 ? 'in 1 day' : 'in $daysRemaining days');
    final message = 'Renewal Reminder:\n'
        'Hi $studentName, your library membership at $libraryName expires $daysText. '
        'Please renew soon to keep your seat reserved!';
    return await sendDirectSms(phone: phone, message: message);
  }

  /// Sends welcome SMS to newly registered student.
  Future<bool> sendWelcomeSms({
    required String phone,
    required String studentName,
    required String libraryName,
    String membershipId = '',
    String seatLabel = '',
  }) async {
    final idText = membershipId.isNotEmpty ? ' Member ID: $membershipId.' : '';
    final seatText = seatLabel.isNotEmpty ? ' Seat: $seatLabel.' : '';
    final message = 'Welcome to $libraryName!\n'
        'Hi $studentName, your library registration is confirmed.$idText$seatText '
        'Happy studying!';
    return await sendDirectSms(phone: phone, message: message);
  }
}

final smsServiceProvider = Provider<SmsService>((ref) => SmsService());
