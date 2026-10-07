import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// WhatsAppService provides methods to communicate with students via WhatsApp.
/// For now, it uses url_launcher to open the WhatsApp app with a pre-filled message.
/// TODO: Integrate Twilio API or official WhatsApp Cloud API later.
class WhatsAppService {
  /// Opens WhatsApp with the given phone number and message.
  Future<bool> sendMessage(String phone, String message) async {
    // Basic sanitization
    final sanitizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$sanitizedPhone?text=$encodedMessage');
    
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Sends a receipt URL to the student.
  Future<bool> sendReceipt(String phone, String receiptUrl) async {
    final message = 'Hello! Here is your payment receipt: $receiptUrl\nThank you!';
    return await sendMessage(phone, message);
  }

  /// Sends a welcome message to a newly registered student.
  Future<bool> sendWelcomeMessage(String phone, String studentName, String libraryName) async {
    final message = 'Welcome $studentName to $libraryName!\nWe are glad to have you. Let us know if you need any assistance.';
    return await sendMessage(phone, message);
  }

  /// Sends a reminder for an upcoming or past expiry.
  Future<bool> sendExpiryReminder(String phone, String studentName, int daysRemaining) async {
    String message;
    if (daysRemaining > 0) {
      message = 'Hello $studentName, your library plan at expires in $daysRemaining days. Please renew to keep your seat reserved!';
    } else if (daysRemaining == 0) {
      message = 'Hello $studentName, your library plan expires today. Please renew to continue your access.';
    } else {
      message = 'Hello $studentName, your library plan has expired. Please renew as soon as possible.';
    }
    return await sendMessage(phone, message);
  }
}

/// Provider for WhatsAppService
final whatsappServiceProvider = Provider<WhatsAppService>((ref) {
  return WhatsAppService();
});
