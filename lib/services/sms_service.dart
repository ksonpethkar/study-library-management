import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// SmsService enables 100% free SMS messaging via the admin device's native SIM card.
/// Uses Android's native SmsManager API in the background.
class SmsService {
  static const _channel = MethodChannel('study_library/sms');

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

  /// Sends a direct background SMS using the device's native SIM card.
  /// Falls back to launching the default SMS app if background dispatch fails.
  Future<bool> sendDirectSms({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = sanitizePhone(phone);
    if (cleanPhone.length < 10) {
      debugPrint('SmsService: Invalid phone number: $phone');
      return false;
    }

    // Android native direct SMS dispatch
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      try {
        final status = await Permission.sms.request();
        if (status.isGranted) {
          final result = await _channel.invokeMethod<bool>('sendSms', {
            'phone': cleanPhone,
            'message': message,
          });
          if (result == true) {
            debugPrint('SmsService: SMS dispatched directly via SIM to $cleanPhone');
            return true;
          }
        } else {
          debugPrint('SmsService: SMS permission not granted: $status');
        }
      } catch (e) {
        debugPrint('SmsService native error: $e');
      }
    }

    // Fallback: Launch SMS app with pre-filled text
    try {
      final uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('SmsService fallback error: $e');
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
