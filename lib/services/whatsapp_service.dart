import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/widgets/whatsapp_preview_sheet.dart';
import 'package:study_library/services/message_template_service.dart';

/// WhatsAppService provides methods to communicate with students via WhatsApp.
/// Uses url_launcher to open the WhatsApp app with a pre-filled message.
/// When [context] is provided, an interactive preview sheet is displayed first,
/// allowing the user to review, edit, or cancel before launching WhatsApp.
class WhatsAppService {
  /// Opens WhatsApp with the given phone number and message.
  /// If [context] is passed and mounted, displays a preview dialog first.
  Future<bool> sendMessage(
    String phone,
    String message, {
    BuildContext? context,
    String? recipientName,
    String? title,
  }) async {
    String finalMessage = message;
    if (context != null && context.mounted) {
      final confirmed = await WhatsAppPreviewSheet.show(
        context,
        phone: phone,
        message: message,
        recipientName: recipientName,
        title: title,
      );
      if (confirmed == null) return false;
      finalMessage = confirmed;
    }

    final sanitizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (sanitizedPhone.isEmpty) return false;
    // Prefix with country code if not present
    final withCode = sanitizedPhone.startsWith('91') || sanitizedPhone.length > 10
        ? sanitizedPhone
        : '91$sanitizedPhone';
    final encodedMessage = Uri.encodeComponent(finalMessage);
    final uri = Uri.parse('https://wa.me/$withCode?text=$encodedMessage');

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Sends a polite, itemized payment receipt confirmation to the student.
  /// Backward compatible with positional arguments (phone, studentName, libraryName, amount, receiptNumber).
  Future<bool> sendPaymentConfirmation(
    String phone,
    String studentName,
    String libraryName,
    double amount,
    String receiptNumber, {
    String? planName,
    String? seatLabel,
    String? validFromDate,
    String? expiryDate,
    String? paymentMethod,
    double? remainingDue,
    String? receiptUrl,
    String? libraryHelpline,
    String? paymentDate,
    String? adminTemplate,
    BuildContext? context,
  }) async {
    final formattedDate = paymentDate ?? DateFormat('dd MMM yyyy').format(DateTime.now());

    String finalMessage;
    if (adminTemplate != null && adminTemplate.trim().isNotEmpty) {
      finalMessage = MessageTemplateService.substitute(
        adminTemplate,
        studentName: studentName,
        libraryName: libraryName,
        amount: amount.toStringAsFixed(0),
        receiptNumber: receiptNumber,
        planName: planName,
        seatLabel: seatLabel,
        validFromDate: validFromDate,
        expiryDate: expiryDate,
        paymentMethod: paymentMethod,
        dueAmount: remainingDue?.toStringAsFixed(0) ?? '0',
        receiptUrl: receiptUrl,
        libraryHelpline: libraryHelpline,
        paymentDate: formattedDate,
      );
    } else {
      final dueBlock = (remainingDue != null && remainingDue > 0)
          ? '⚠️ *Remaining Balance Due:* ₹${remainingDue.toStringAsFixed(0)}\n'
          : '💰 *Balance Due:* ₹0.00 (Fully Settled)\n';

      final buffer = StringBuffer()
        ..writeln('✅ *Payment Received — Fee Receipt*')
        ..writeln()
        ..writeln('Dear *$studentName*,')
        ..writeln('Thank you for your payment. Your official fee receipt has been recorded at *$libraryName*.')
        ..writeln()
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('🧾 *RECEIPT PARTICULARS*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('🧾 *Receipt Number:* $receiptNumber')
        ..writeln('📅 *Payment Date:* $formattedDate')
        ..writeln('💳 *Amount Received:* *₹${amount.toStringAsFixed(0)}*');

      if (paymentMethod != null && paymentMethod.isNotEmpty) {
        buffer.writeln('💳 *Payment Mode:* $paymentMethod');
      }
      if (planName != null && planName.isNotEmpty) {
        buffer.writeln('📦 *Subscription Plan:* $planName');
      }
      if (seatLabel != null && seatLabel.isNotEmpty) {
        buffer.writeln('💺 *Seat Number:* $seatLabel');
      }
      if (validFromDate != null && expiryDate != null) {
        buffer.writeln('🗓️ *Validity:* $validFromDate to $expiryDate');
      } else if (expiryDate != null) {
        buffer.writeln('🗓️ *Valid Until:* $expiryDate');
      }

      buffer.write(dueBlock);

      if (receiptUrl != null && receiptUrl.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('🔗 *View & Download Official Receipt:*')
          ..writeln(receiptUrl);
      }

      if (libraryHelpline != null && libraryHelpline.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('📞 *Helpline:* $libraryHelpline');
      }

      buffer
        ..writeln()
        ..writeln('Thank you for choosing *$libraryName*! 🙏');

      finalMessage = buffer.toString();
    }

    return await sendMessage(
      phone,
      finalMessage,
      context: context,
      recipientName: studentName,
      title: 'Fee Receipt Preview',
    );
  }

  /// Sends a courteous dues balance reminder with UPI payment information.
  Future<bool> sendDueReminder({
    required String phone,
    required String studentName,
    required String libraryName,
    required double dueAmount,
    String? planName,
    String? seatLabel,
    String? dueDate,
    String? membershipId,
    String? libraryHelpline,
    String? libraryUpiId,
    String? adminTemplate,
    BuildContext? context,
  }) async {
    String finalMessage;
    if (adminTemplate != null && adminTemplate.trim().isNotEmpty) {
      finalMessage = MessageTemplateService.substitute(
        adminTemplate,
        studentName: studentName,
        libraryName: libraryName,
        dueAmount: dueAmount.toStringAsFixed(0),
        planName: planName,
        seatLabel: seatLabel,
        dueDate: dueDate,
        membershipId: membershipId,
        libraryHelpline: libraryHelpline,
        libraryUpiId: libraryUpiId,
      );
    } else {
      final buffer = StringBuffer()
        ..writeln('📌 *Fee Balance Reminder — $libraryName*')
        ..writeln()
        ..writeln('Dear *$studentName*,')
        ..writeln('Greetings from $libraryName! This is a gentle reminder regarding your pending fee balance for your *${planName ?? "membership"}* subscription.')
        ..writeln()
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💰 *DUES DETAILS*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('👤 *Student Name:* $studentName');

      if (membershipId != null && membershipId.isNotEmpty) {
        buffer.writeln('🆔 *Admission ID:* $membershipId');
      }
      if (seatLabel != null && seatLabel.isNotEmpty) {
        buffer.writeln('💺 *Allocated Seat:* $seatLabel');
      }

      buffer.writeln('💵 *Pending Balance Due:* *₹${dueAmount.toStringAsFixed(0)}*');

      if (dueDate != null && dueDate.isNotEmpty) {
        buffer.writeln('🗓️ *Due Date:* $dueDate');
      }

      buffer
        ..writeln()
        ..writeln('To ensure uninterrupted study hours and retain your dedicated seat, kindly settle the balance at the reception desk.');

      if (libraryUpiId != null && libraryUpiId.isNotEmpty) {
        buffer.writeln('📲 *UPI ID / GPay / PhonePe:* `$libraryUpiId`');
      }

      if (libraryHelpline != null && libraryHelpline.isNotEmpty) {
        buffer.writeln('📞 *Helpline:* $libraryHelpline');
      }

      buffer
        ..writeln()
        ..writeln('Warm regards,')
        ..writeln('*Admin Desk · $libraryName*');

      finalMessage = buffer.toString();
    }

    return await sendMessage(
      phone,
      finalMessage,
      context: context,
      recipientName: studentName,
      title: 'Fee Due Reminder Preview',
    );
  }

  /// Sends a receipt URL to the student.
  Future<bool> sendReceipt(
    String phone,
    String receiptUrl, {
    String libraryName = '',
    String? studentName,
    BuildContext? context,
  }) async {
    final libStr = libraryName.isNotEmpty ? ' from $libraryName' : '';
    final message = 'Hi! Here is your payment receipt$libStr:\n$receiptUrl\n\nThank you!';
    return await sendMessage(
      phone,
      message,
      context: context,
      recipientName: studentName,
      title: 'Payment Receipt Link Preview',
    );
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
    String validFromDate = '',
    String amount = '',
    String paymentMethod = '',
    String libraryAddress = '',
    String libraryHelpline = '',
    String shiftTiming = '',
    String shiftName = '',
    BuildContext? context,
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
      validFromDate: validFromDate,
      amount: amount,
      paymentMethod: paymentMethod,
      libraryAddress: libraryAddress,
      libraryHelpline: libraryHelpline,
      shiftTiming: shiftTiming,
      shiftName: shiftName,
    );
    return await sendMessage(
      phone,
      message,
      context: context,
      recipientName: studentName,
      title: 'Welcome Message Preview',
    );
  }

  /// Sends a courteous, encouraging renewal reminder for upcoming or past expiry.
  Future<bool> sendExpiryReminder(
    String phone,
    String studentName,
    int daysRemaining, {
    String libraryName = '',
    String seatLabel = '',
    String? expiryDate,
    String? libraryHelpline,
    String? libraryUpiId,
    String? adminTemplate,
    BuildContext? context,
  }) async {
    final libName = libraryName.isNotEmpty ? libraryName : 'Study Library';
    final seatText = seatLabel.isNotEmpty ? ' for *Seat $seatLabel*' : '';
    final helpText = (libraryHelpline != null && libraryHelpline.isNotEmpty)
        ? '\n📞 Reception Helpline: $libraryHelpline'
        : '';
    final upiText = (libraryUpiId != null && libraryUpiId.isNotEmpty)
        ? '\n📲 Renew via UPI: `$libraryUpiId`'
        : '';

    String message;
    if (adminTemplate != null && adminTemplate.trim().isNotEmpty) {
      message = MessageTemplateService.substitute(
        adminTemplate,
        studentName: studentName,
        libraryName: libName,
        seatLabel: seatLabel,
        expiryDate: expiryDate,
        libraryHelpline: libraryHelpline,
        libraryUpiId: libraryUpiId,
        daysRemaining: daysRemaining.toString(),
      );
    } else if (daysRemaining > 3) {
      message = '⏳ *Upcoming Plan Renewal Notice*\n\n'
          'Dear *$studentName*,\n'
          'Hope your study and exam preparation are going smoothly!\n\n'
          'This is a friendly reminder that your library membership$seatText at *$libName* will complete its cycle in *$daysRemaining days*${expiryDate != null ? " (on *$expiryDate*)" : ""}.\n\n'
          'To retain your preferred seat and avoid reassignment, you may renew in advance at the reception desk.$upiText$helpText\n\n'
          'Warm regards,\n'
          '*$libName Management*';
    } else if (daysRemaining > 0) {
      final dayStr = daysRemaining == 1 ? '1 day' : '$daysRemaining days';
      message = '⏰ *Seat Renewal Reminder — $dayStr Left*\n\n'
          'Dear *$studentName*,\n'
          'Your membership$seatText at *$libName* is scheduled to expire in *$dayStr*${expiryDate != null ? " (on *$expiryDate*)" : ""}.\n\n'
          'To guarantee continuous reservation of your study spot, please renew your plan before expiry.$upiText$helpText\n\n'
          'Best wishes for your studies! 📚';
    } else if (daysRemaining == 0) {
      message = '🔔 *Membership Expires Today*\n\n'
          'Dear *$studentName*,\n'
          'Your library membership$seatText at *$libName* concludes *today*.\n\n'
          'We want to ensure your daily study routine remains uninterrupted! Please visit the desk today to renew your subscription.$upiText$helpText\n\n'
          'Thank you for being a valued member! 📖';
    } else {
      message = '⚠️ *Membership Expiry & Seat Retention Notice*\n\n'
          'Dear *$studentName*,\n'
          'Your membership$seatText at *$libName* has expired.\n\n'
          'We are holding your seat under our temporary grace policy. If you would like to continue your preparation with us, kindly confirm your renewal today to prevent reassignment.$upiText$helpText\n\n'
          'We would love to continue supporting your preparation! 🎯';
    }
    return await sendMessage(
      phone,
      message,
      context: context,
      recipientName: studentName,
      title: 'Plan Renewal Reminder Preview',
    );
  }

  /// Sends multi-stage renewal reminder (T-3, T-0, T+2) with dynamic UPI pay-link
  Future<bool> sendStageRenewalReminder(
    String phone,
    String studentName,
    String stage, {
    String libraryName = '',
    String seatLabel = '',
    String? expiryDate,
    String? libraryHelpline,
    String? libraryUpiId,
    double? renewalAmount,
    BuildContext? context,
  }) async {
    final libName = libraryName.isNotEmpty ? libraryName : 'The Cozy Corner Study Centre';
    final seatText = seatLabel.isNotEmpty ? 'Seat #$seatLabel' : 'your allocated desk';
    final amtText = renewalAmount != null && renewalAmount > 0 ? '₹${renewalAmount.toStringAsFixed(0)}' : 'your membership fee';
    final isAbove2k = renewalAmount != null && renewalAmount > 2000;
    final upiLink = (libraryUpiId != null && libraryUpiId.isNotEmpty)
        ? (isAbove2k
            ? 'upi://pay?pa=$libraryUpiId&pn=${Uri.encodeComponent(libName)}&cu=INR'
            : 'upi://pay?pa=$libraryUpiId&pn=${Uri.encodeComponent(libName)}&am=${renewalAmount?.toStringAsFixed(0) ?? ""}&cu=INR')
        : null;

    final buffer = StringBuffer();
    if (stage == 'T-3') {
      buffer
        ..writeln('📅 *Upcoming Renewal in 3 Days — $libName*')
        ..writeln()
        ..writeln('Dear *$studentName*,')
        ..writeln('Your study desk subscription for *$seatText* completes in *3 days* (Valid till: *${expiryDate ?? "soon"}*).')
        ..writeln()
        ..writeln('To ensure uninterrupted study hours and retain your dedicated seat, please renew before expiration.')
        ..writeln()
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💳 *RENEWAL PAYMENT*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💰 Amount: *$amtText*');
      if (libraryUpiId != null && libraryUpiId.isNotEmpty) {
        buffer.writeln('📲 UPI ID: `$libraryUpiId`');
        if (upiLink != null) {
          buffer.writeln('🔗 Tap to Pay via UPI: $upiLink');
        }
      }
    } else if (stage == 'T-0') {
      buffer
        ..writeln('⚠️ *Membership Expires Today! — $libName*')
        ..writeln()
        ..writeln('Dear *$studentName*,')
        ..writeln('Today is the *final day* of your active pass for *$seatText*.')
        ..writeln()
        ..writeln('Kindly settle your renewal today to avoid entering the grace queue and retain your desk.')
        ..writeln()
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💳 *INSTANT RENEWAL*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💰 Amount: *$amtText*');
      if (libraryUpiId != null && libraryUpiId.isNotEmpty) {
        buffer.writeln('📲 UPI ID: `$libraryUpiId`');
        if (upiLink != null) {
          buffer.writeln('🔗 Tap to Pay via UPI: $upiLink');
        }
      }
    } else {
      buffer
        ..writeln('🚨 *Final Grace Period Notice — Desk Auto-Release Tomorrow*')
        ..writeln()
        ..writeln('Dear *$studentName*,')
        ..writeln('Your grace period for *$seatText* at *$libName* ends *tomorrow*.')
        ..writeln()
        ..writeln('As per study center policy, unrenewed desks are automatically released to the waiting list. Settle today to prevent desk reassignment.')
        ..writeln()
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💳 *URGENT SETTLEMENT*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💰 Amount: *$amtText*');
      if (libraryUpiId != null && libraryUpiId.isNotEmpty) {
        buffer.writeln('📲 UPI ID: `$libraryUpiId`');
        if (upiLink != null) {
          buffer.writeln('🔗 Tap to Pay via UPI: $upiLink');
        }
      }
    }

    if (libraryHelpline != null && libraryHelpline.isNotEmpty) {
      buffer.writeln('\n📞 Reception Helpline: $libraryHelpline');
    }
    buffer.writeln('\nThank you for studying with us! 🙏');

    return await sendMessage(
      phone,
      buffer.toString(),
      context: context,
      recipientName: studentName,
      title: 'Renewal Reminder ($stage)',
    );
  }

  /// Sends a 2-hour waitlist reservation offer message with hold countdown
  Future<bool> sendWaitlistHoldOffer(
    String phone,
    String studentName,
    String seatLabel, {
    String libraryName = '',
    String sectionName = '',
    int holdHours = 2,
    String? libraryHelpline,
    String? adminTemplate,
    BuildContext? context,
  }) async {
    final libName = libraryName.isNotEmpty ? libraryName : 'The Cozy Corner Study Centre';
    String finalMessage;
    if (adminTemplate != null && adminTemplate.trim().isNotEmpty) {
      finalMessage = MessageTemplateService.substitute(
        adminTemplate,
        studentName: studentName,
        libraryName: libName,
        seatLabel: seatLabel,
        libraryHelpline: libraryHelpline,
      );
    } else {
      final buffer = StringBuffer()
        ..writeln('🎉 *Seat Opportunity Alert — $libName*')
        ..writeln()
        ..writeln('Dear *$studentName*,')
        ..writeln('Good news! A desk has just been vacated and you are *#1 on our Waiting List*! 🌟')
        ..writeln()
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('💺 *RESERVED DESK DETAILS*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━')
        ..writeln('📍 Section: *${sectionName.isNotEmpty ? sectionName : "Main Hall"}*')
        ..writeln('💺 Desk: *Seat #$seatLabel*')
        ..writeln('⏳ Hold Timer: *Priority $holdHours-Hour Reservation*')
        ..writeln('━━━━━━━━━━━━━━━━━━━━━\n')
        ..writeln('We are holding this desk exclusively for you for the next *$holdHours hours*. Please visit the reception desk or reply to confirm your admission before the timer expires.\n');

      if (libraryHelpline != null && libraryHelpline.isNotEmpty) {
        buffer.writeln('📞 Reception Helpline: $libraryHelpline');
      }
      buffer.writeln('\nWe look forward to welcoming you! 📚✨');
      finalMessage = buffer.toString();
    }

    return await sendMessage(
      phone,
      finalMessage,
      context: context,
      recipientName: studentName,
      title: 'Waitlist Priority Hold Offer',
    );
  }

  /// Sends a seat assignment confirmation.
  Future<bool> sendSeatAssigned(
    String phone,
    String studentName,
    String seatLabel,
    String sectionName, {
    String libraryName = '',
    String? shiftName,
    String? shiftTiming,
    String? libraryHelpline,
    BuildContext? context,
  }) async {
    final libStr = libraryName.isNotEmpty ? ' at *$libraryName*' : '';
    final buffer = StringBuffer()
      ..writeln('💺 *Seat Allocation Update*')
      ..writeln()
      ..writeln('Dear *$studentName*,')
      ..writeln('Your seating arrangement$libStr has been confirmed:')
      ..writeln()
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('📍 *ASSIGNMENT DETAILS*')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('🏛️ *Section:* $sectionName')
      ..writeln('💺 *Assigned Seat:* *$seatLabel*');

    if (shiftName != null && shiftName.isNotEmpty) {
      final timeStr = (shiftTiming != null && shiftTiming.isNotEmpty) ? ' ($shiftTiming)' : '';
      buffer.writeln('⏰ *Shift:* $shiftName$timeStr');
    }

    buffer
      ..writeln()
      ..writeln('Please occupy your designated seat during your next visit. We appreciate your cooperation in maintaining study hall decorum!');

    if (libraryHelpline != null && libraryHelpline.isNotEmpty) {
      buffer.writeln('📞 *Helpline:* $libraryHelpline');
    }

    buffer
      ..writeln()
      ..writeln('Warm regards,')
      ..writeln('*Administration Team*');

    return await sendMessage(
      phone,
      buffer.toString(),
      context: context,
      recipientName: studentName,
      title: 'Seat Allocation Preview',
    );
  }

  /// Sends a seat shift/change confirmation when student moves to a new seat.
  Future<bool> sendSeatChanged({
    required String phone,
    required String studentName,
    required String libraryName,
    required String newSeatLabel,
    required String newSectionName,
    String? previousSeatLabel,
    String? shiftName,
    String? shiftTiming,
    BuildContext? context,
  }) async {
    final prevText = (previousSeatLabel != null && previousSeatLabel.isNotEmpty)
        ? ' from *$previousSeatLabel*'
        : '';
    final buffer = StringBuffer()
      ..writeln('🔄 *Seat Shift Confirmation — $libraryName*')
      ..writeln()
      ..writeln('Dear *$studentName*,')
      ..writeln('Your request to shift seats$prevText has been approved and updated.')
      ..writeln()
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('🆕 *NEW SEATING DETAILS*')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('🏛️ *New Section:* $newSectionName')
      ..writeln('💺 *New Seat Number:* *$newSeatLabel*');

    if (shiftName != null && shiftName.isNotEmpty) {
      final timeStr = (shiftTiming != null && shiftTiming.isNotEmpty) ? ' ($shiftTiming)' : '';
      buffer.writeln('⏰ *Shift:* $shiftName$timeStr');
    }

    buffer
      ..writeln()
      ..writeln('Your records have been synchronized on the library system. Happy studying! 📖✨')
      ..writeln()
      ..writeln('Warm regards,')
      ..writeln('*$libraryName Admin Desk*');

    return await sendMessage(
      phone,
      buffer.toString(),
      context: context,
      recipientName: studentName,
      title: 'Seat Shift Confirmation Preview',
    );
  }

  /// Sends a notification when a seat opens up for a waitlisted student.
  Future<bool> sendWaitingListPromotion({
    required String phone,
    required String studentName,
    required String libraryName,
    required String seatLabel,
    required String sectionName,
    String? planName,
    String? libraryHelpline,
    BuildContext? context,
  }) async {
    final buffer = StringBuffer()
      ..writeln('🎉 *Good News! Seat Available at $libraryName*')
      ..writeln()
      ..writeln('Dear *$studentName*,')
      ..writeln('A study seat has become available for your preferred subscription!')
      ..writeln()
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('💺 *RESERVED SEAT OFFER*')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('🏛️ *Section:* $sectionName')
      ..writeln('💺 *Seat:* *$seatLabel*');

    if (planName != null && planName.isNotEmpty) {
      buffer.writeln('📦 *Plan:* $planName');
    }

    buffer
      ..writeln()
      ..writeln('This seat is reserved for you for the next 24 hours. Kindly visit reception or confirm your admission to secure it.');

    if (libraryHelpline != null && libraryHelpline.isNotEmpty) {
      buffer.writeln('📞 *Helpline / WhatsApp:* $libraryHelpline');
    }

    buffer
      ..writeln()
      ..writeln('— *Team $libraryName*');

    return await sendMessage(
      phone,
      buffer.toString(),
      context: context,
      recipientName: studentName,
      title: 'Waiting List Seat Offer Preview',
    );
  }

  /// Sends an official early exit pro-rata settlement confirmation & refund voucher to the student.
  Future<bool> sendEarlyExitSettlement({
    required String phone,
    required String studentName,
    required String libraryName,
    required String voucherNumber,
    required int usedDays,
    required int totalDays,
    required double fairUsageFee,
    required double processingFee,
    required double netRefund,
    required String refundMethod,
    String? referenceNumber,
    String? seatLabel,
    String? libraryHelpline,
    BuildContext? context,
  }) async {
    final buffer = StringBuffer()
      ..writeln('🚪 *Membership Early Exit & Settlement Confirmation*')
      ..writeln()
      ..writeln('Dear *$studentName*,')
      ..writeln('Your early exit and account settlement has been successfully processed at *$libraryName*.')
      ..writeln()
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('🧾 *SETTLEMENT SUMMARY*')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('🧾 *Voucher Number:* $voucherNumber')
      ..writeln('📅 *Cycle Days Used:* $usedDays of $totalDays days');

    if (seatLabel != null && seatLabel.isNotEmpty) {
      buffer.writeln('💺 *Seat Vacated:* Seat #$seatLabel');
    }

    buffer
      ..writeln('📊 *Fair Usage Charge:* ₹${fairUsageFee.toStringAsFixed(0)}')
      ..writeln('✂️ *Early Cancellation Fee:* ₹${processingFee.toStringAsFixed(0)}');

    if (netRefund > 0) {
      buffer.writeln('💵 *Net Refund Issued:* *₹${netRefund.toStringAsFixed(0)}* ($refundMethod)');
      if (referenceNumber != null && referenceNumber.isNotEmpty) {
        buffer.writeln('🔖 *Reference / UTR:* $referenceNumber');
      }
    } else {
      buffer.writeln('💵 *Net Balance:* ₹0.00 (Account Fully Closed)');
    }

    buffer
      ..writeln()
      ..writeln('Your desk has been vacated and your membership account marked as settled.')
      ..writeln('Thank you for being part of our community. We wish you immense success in your academic and career goals! 🎓🌟');

    if (libraryHelpline != null && libraryHelpline.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('📞 *Helpline / Admin Desk:* $libraryHelpline');
    }

    buffer
      ..writeln()
      ..writeln('— *Management, $libraryName*');

    return await sendMessage(
      phone,
      buffer.toString(),
      context: context,
      recipientName: studentName,
      title: 'Exit Settlement Preview',
    );
  }

  /// Sends an official Mid-Cycle Plan Upgrade / Tier Change confirmation to the student.
  Future<bool> sendPlanUpgradeConfirmation({
    required String phone,
    required String studentName,
    required String libraryName,
    required String oldPlanName,
    required String newPlanName,
    required String receiptNumber,
    required int remainingDays,
    required double unusedCredit,
    required double newProratedFee,
    required double netPaid,
    required String paymentMethod,
    required DateTime newExpiryDate,
    String? referenceNumber,
    String? libraryHelpline,
    BuildContext? context,
  }) async {
    final buffer = StringBuffer()
      ..writeln('🚀 *Membership Plan Upgrade Confirmation*')
      ..writeln()
      ..writeln('Dear *$studentName*,')
      ..writeln('Your study membership tier at *$libraryName* has been successfully upgraded!')
      ..writeln()
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('📦 *PLAN UPGRADE DETAILS*')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('🔄 *Upgrade:* $oldPlanName ➔ *$newPlanName*')
      ..writeln('🧾 *Receipt Voucher:* $receiptNumber')
      ..writeln('⏳ *Remaining Cycle:* $remainingDays days');

    if (unusedCredit > 0) {
      buffer.writeln('💳 *Unused Credit Applied:* -₹${unusedCredit.toStringAsFixed(0)}');
    }

    if (netPaid > 0) {
      buffer.writeln('💵 *Net Upgrade Surcharge Paid:* *₹${netPaid.toStringAsFixed(0)}* ($paymentMethod)');
      if (referenceNumber != null && referenceNumber.isNotEmpty) {
        buffer.writeln('🔖 *Reference / UTR:* $referenceNumber');
      }
    } else {
      buffer.writeln('💵 *Net Surcharge Paid:* ₹0 (Fully Covered by Unused Credit)');
    }

    final formattedExpiry = '${newExpiryDate.day.toString().padLeft(2, '0')}/${newExpiryDate.month.toString().padLeft(2, '0')}/${newExpiryDate.year}';
    buffer
      ..writeln('📅 *Valid Through:* *$formattedExpiry*')
      ..writeln()
      ..writeln('Your upgraded amenities, timings, and privileges are active immediately. Have a productive study session! 📚⚡');

    if (libraryHelpline != null && libraryHelpline.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('📞 *Helpline / Admin Desk:* $libraryHelpline');
    }

    buffer
      ..writeln()
      ..writeln('— *Management, $libraryName*');

    return await sendMessage(
      phone,
      buffer.toString(),
      context: context,
      recipientName: studentName,
      title: 'Plan Upgrade Confirmation Preview',
    );
  }
}

/// Provider for WhatsAppService
final whatsappServiceProvider = Provider<WhatsAppService>((ref) {
  return WhatsAppService();
});
