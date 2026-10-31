/// Service for substituting template variables in admin-configurable messages.
/// Variables: {studentName}, {planName}, {expiryDate}, {validFromDate}, {membershipId}, {seatLabel},
///            {libraryName}, {amount}, {paymentMethod}, {phone}, {libraryAddress},
///            {libraryHelpline}, {receiptNumber}, {receiptUrl}, {dueAmount}, {dueDate},
///            {shiftName}, {shiftTiming}, {libraryUpiId}, {paymentDate}
class MessageTemplateService {
  static String substitute(
    String template, {
    String? studentName,
    String? planName,
    String? expiryDate,
    String? validFromDate,
    String? membershipId,
    String? seatLabel,
    String? libraryName,
    String? amount,
    String? paymentMethod,
    String? phone,
    String? libraryAddress,
    String? libraryHelpline,
    String? receiptNumber,
    String? receiptUrl,
    String? dueAmount,
    String? dueDate,
    String? shiftName,
    String? shiftTiming,
    String? libraryUpiId,
    String? paymentDate,
  }) {
    return template
        .replaceAll('{studentName}', studentName ?? '')
        .replaceAll('{planName}', planName ?? '')
        .replaceAll('{expiryDate}', expiryDate ?? '')
        .replaceAll('{validFromDate}', validFromDate ?? '')
        .replaceAll('{membershipId}', membershipId ?? '')
        .replaceAll('{seatLabel}', seatLabel ?? '')
        .replaceAll('{libraryName}', libraryName ?? '')
        .replaceAll('{amount}', amount ?? '')
        .replaceAll('{paymentMethod}', paymentMethod ?? '')
        .replaceAll('{phone}', phone ?? '')
        .replaceAll('{libraryAddress}', libraryAddress ?? '')
        .replaceAll('{libraryHelpline}', libraryHelpline ?? '')
        .replaceAll('{receiptNumber}', receiptNumber ?? '')
        .replaceAll('{receiptUrl}', receiptUrl ?? '')
        .replaceAll('{dueAmount}', dueAmount ?? '')
        .replaceAll('{dueDate}', dueDate ?? '')
        .replaceAll('{shiftName}', shiftName ?? '')
        .replaceAll('{shiftTiming}', shiftTiming ?? '')
        .replaceAll('{libraryUpiId}', libraryUpiId ?? '')
        .replaceAll('{paymentDate}', paymentDate ?? '');
  }

  /// Default WhatsApp welcome message template (used if admin hasn't set one)
  static const defaultWelcomeTemplate =
      '🎉 *Welcome to {libraryName}!*\n\n'
      'Dear *{studentName}*,\n'
      'We are delighted to welcome you to our study community! Your library membership registration has been successfully confirmed.\n\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '📋 *MEMBERSHIP SUMMARY*\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *Student Name:* {studentName}\n'
      '🆔 *Admission ID:* {membershipId}\n'
      '📦 *Plan Enrolled:* {planName}\n'
      '💺 *Allocated Seat:* {seatLabel}\n'
      '📅 *Valid Until:* {expiryDate}\n'
      '💰 *Fee Paid:* ₹{amount} ({paymentMethod})\n\n'
      '📍 *Location:* {libraryAddress}\n'
      '📞 *Admin Desk / Helpline:* {libraryHelpline}\n\n'
      'We wish you a deeply focused, disciplined, and successful study journey! 📚✨\n\n'
      '— *Team {libraryName}*';

  /// Default WhatsApp payment receipt template
  static const defaultPaymentReceiptTemplate =
      '✅ *Payment Received — Fee Receipt*\n\n'
      'Dear *{studentName}*,\n'
      'Thank you for your payment. Your official fee receipt has been recorded.\n\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '🧾 *RECEIPT PARTICULARS*\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '🧾 *Receipt Number:* {receiptNumber}\n'
      '📅 *Date of Payment:* {paymentDate}\n'
      '💳 *Amount Received:* *₹{amount}*\n'
      '💳 *Payment Mode:* {paymentMethod}\n'
      '📦 *Subscription Plan:* {planName}\n'
      '💺 *Seat Number:* {seatLabel}\n'
      '🗓️ *Validity:* {validFromDate} to {expiryDate}\n\n'
      '🔗 *View Official Receipt:* {receiptUrl}\n\n'
      'Thank you for choosing *{libraryName}*! 🙏';

  /// Default WhatsApp pending dues reminder template
  static const defaultDueReminderTemplate =
      '📌 *Fee Balance Reminder — {libraryName}*\n\n'
      'Dear *{studentName}*,\n'
      'Greetings from {libraryName}! This is a gentle reminder regarding your pending fee balance for your *{planName}* subscription.\n\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '💰 *DUES DETAILS*\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *Student Name:* {studentName}\n'
      '🆔 *Admission ID:* {membershipId}\n'
      '💺 *Allocated Seat:* {seatLabel}\n'
      '💵 *Pending Balance Due:* *₹{dueAmount}*\n\n'
      'Kindly settle the balance at the reception desk to ensure uninterrupted seat reservation.\n'
      '📞 Helpline: {libraryHelpline}\n\n'
      'Warm regards,\n'
      '*Admin Desk · {libraryName}*';

  /// Default receipt footer template
  static const defaultReceiptFooter =
      'Thank you for choosing {libraryName}. We wish you great success!';

  /// Available variables to show user in template editor
  static const availableVariables = [
    '{studentName}',
    '{planName}',
    '{expiryDate}',
    '{validFromDate}',
    '{membershipId}',
    '{seatLabel}',
    '{libraryName}',
    '{amount}',
    '{paymentMethod}',
    '{phone}',
    '{libraryAddress}',
    '{libraryHelpline}',
    '{receiptNumber}',
    '{receiptUrl}',
    '{dueAmount}',
    '{dueDate}',
    '{shiftName}',
    '{shiftTiming}',
    '{libraryUpiId}',
    '{paymentDate}',
  ];
}
