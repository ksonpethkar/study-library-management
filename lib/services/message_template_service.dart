
/// Service for substituting template variables in admin-configurable messages.
/// Variables: {studentName}, {planName}, {expiryDate}, {membershipId}, {seatLabel},
///            {libraryName}, {amount}, {paymentMethod}, {phone}
class MessageTemplateService {
  static String substitute(
    String template, {
    String? studentName,
    String? planName,
    String? expiryDate,
    String? membershipId,
    String? seatLabel,
    String? libraryName,
    String? amount,
    String? paymentMethod,
    String? phone,
  }) {
    return template
        .replaceAll('{studentName}', studentName ?? '')
        .replaceAll('{planName}', planName ?? '')
        .replaceAll('{expiryDate}', expiryDate ?? '')
        .replaceAll('{membershipId}', membershipId ?? '')
        .replaceAll('{seatLabel}', seatLabel ?? '')
        .replaceAll('{libraryName}', libraryName ?? '')
        .replaceAll('{amount}', amount ?? '')
        .replaceAll('{paymentMethod}', paymentMethod ?? '')
        .replaceAll('{phone}', phone ?? '');
  }

  /// Default WhatsApp welcome message template (used if admin hasn't set one)
  static const defaultWelcomeTemplate =
      'Hello {studentName}! 🎉\n\n'
      'Welcome to {libraryName}! Your membership has been confirmed.\n\n'
      '📋 Plan: {planName}\n'
      '🆔 Membership ID: {membershipId}\n'
      '💺 Seat: {seatLabel}\n'
      '📅 Valid until: {expiryDate}\n'
      '💰 Amount Paid: ₹{amount} ({paymentMethod})\n\n'
      'We wish you a productive study session! 📚';

  /// Default receipt footer template
  static const defaultReceiptFooter =
      'Thank you for choosing {libraryName}. We wish you great success!';

  /// Available variables to show user in template editor
  static const availableVariables = [
    '{studentName}', '{planName}', '{expiryDate}', '{membershipId}',
    '{seatLabel}', '{libraryName}', '{amount}', '{paymentMethod}', '{phone}',
  ];
}
