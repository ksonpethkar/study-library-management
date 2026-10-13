import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/services/message_template_service.dart';

/// WhatsAppService provides methods to communicate with students via WhatsApp.
/// Uses url_launcher to open the WhatsApp app with a pre-filled message.
/// For automated sending, integrate Twilio / WhatsApp Cloud API later.
class WhatsAppService {
  /// Opens WhatsApp with the given phone number and message.
  Future<bool> sendMessage(String phone, String message) async {
    final sanitizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    // Prefix with country code if not present
    final withCode = sanitizedPhone.startsWith('91') || sanitizedPhone.length > 10
        ? sanitizedPhone
        : '91$sanitizedPhone';
    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$withCode?text=$encodedMessage');

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Sends a payment receipt confirmation to the student.
  Future<bool> sendPaymentConfirmation(String phone, String studentName,
      String libraryName, double amount, String receiptNumber) async {
    final message = '✅ Payment Confirmed!\n\n'
        'Hi $studentName,\n'
        'Your payment of ₹${amount.toStringAsFixed(0)} has been received at *$libraryName*.\n'
        'Receipt No: $receiptNumber\n\n'
        'Thank you! 🙏';
    return await sendMessage(phone, message);
  }

  /// Sends a receipt URL to the student.
  Future<bool> sendReceipt(String phone, String receiptUrl,
      {String libraryName = ''}) async {
    final libStr = libraryName.isNotEmpty ? ' from $libraryName' : '';
    final message = 'Hi! Here is your payment receipt$libStr:\n$receiptUrl\n\nThank you!';
    return await sendMessage(phone, message);
  }

  /// Sends a welcome message to a newly registered student.
  /// If [adminTemplate] is provided (library.whatsappWelcomeTemplate), it is used
  /// with full variable substitution via MessageTemplateService.
  Future<bool> sendWelcomeMessage(
    String phone,
    String studentName,
    String libraryName, {
    String adminTemplate = '',
    String membershipId = '',
    String planName = '',
    String seatLabel = '',
    String expiryDate = '',
    String amount = '',
    String paymentMethod = '',
  }) async {
    final template = adminTemplate.isNotEmpty
        ? adminTemplate
        : MessageTemplateService.defaultWelcomeTemplate;
    final message = MessageTemplateService.substitute(
      template,
      studentName: studentName,
      libraryName: libraryName,
      membershipId: membershipId,
      planName: planName,
      seatLabel: seatLabel,
      expiryDate: expiryDate,
      amount: amount,
      paymentMethod: paymentMethod,
    );
    return await sendMessage(phone, message);
  }

  /// Sends a reminder for an upcoming or past expiry.
  Future<bool> sendExpiryReminder(String phone, String studentName,
      int daysRemaining, {String libraryName = ''}) async {
    final libStr = libraryName.isNotEmpty ? ' at *$libraryName*' : '';
    String message;
    if (daysRemaining > 3) {
      message = '⏰ Renewal Reminder\n\nHi $studentName,\n'
          'Your library membership$libStr expires in *$daysRemaining days*.\n'
          'Please renew soon to keep your seat reserved!';
    } else if (daysRemaining > 0) {
      message = '⚠️ Urgent: Renewal Due\n\nHi $studentName,\n'
          'Your library membership$libStr expires in just *$daysRemaining day${daysRemaining == 1 ? '' : 's'}*!\n'
          'Please renew immediately to avoid losing your seat.';
    } else if (daysRemaining == 0) {
      message = '🚨 Plan Expires Today\n\nHi $studentName,\n'
          'Your library membership$libStr *expires today*.\n'
          'Please renew to continue your access.';
    } else {
      message = '❌ Membership Expired\n\nHi $studentName,\n'
          'Your library membership$libStr has expired.\n'
          'Please renew as soon as possible to retain your seat.';
    }
    return await sendMessage(phone, message);
  }

  /// Sends a seat assignment confirmation.
  Future<bool> sendSeatAssigned(String phone, String studentName,
      String seatLabel, String sectionName, {String libraryName = ''}) async {
    final libStr = libraryName.isNotEmpty ? ' at *$libraryName*' : '';
    final message = '🪑 Seat Assigned\n\nHi $studentName,\n'
        'Your seat has been assigned$libStr:\n'
        'Section: *$sectionName* · Seat: *$seatLabel*\n\n'
        'Please occupy your seat from your next visit.';
    return await sendMessage(phone, message);
  }
}

/// Provider for WhatsAppService
final whatsappServiceProvider = Provider<WhatsAppService>((ref) {
  return WhatsAppService();
});
