/// Service for substituting template variables and providing multilingual presets (EN, HI, MR)
/// for admin-customizable WhatsApp and SMS messages.
class TemplateVariable {
  final String tag;
  final String label;
  final String example;
  final String description;

  const TemplateVariable({
    required this.tag,
    required this.label,
    required this.example,
    this.description = '',
  });
}

class MessageTemplateService {
  /// Friendly metadata for all available variable tags for UI insertion chips
  static const List<TemplateVariable> variableDefinitions = [
    TemplateVariable(tag: '{studentName}', label: 'Student Name', example: 'Shubham Kandukatle', description: 'Full name of student (alias: {name})'),
    TemplateVariable(tag: '{membershipId}', label: 'Member ID', example: 'CC20260014', description: 'Student admission / membership ID'),
    TemplateVariable(tag: '{seatLabel}', label: 'Desk / Seat', example: 'Seat #14', description: 'Allocated study desk label (alias: {seat}, {desk})'),
    TemplateVariable(tag: '{planName}', label: 'Plan Name', example: 'Monthly Full-Day', description: 'Enrolled plan name (alias: {plan})'),
    TemplateVariable(tag: '{amount}', label: 'Amount', example: '700', description: 'Payment amount received (in ₹)'),
    TemplateVariable(tag: '{dueAmount}', label: 'Due Balance', example: '350', description: 'Pending dues balance (alias: {due})'),
    TemplateVariable(tag: '{expiryDate}', label: 'Expiry Date', example: '30 Nov 2026', description: 'Membership expiration date (alias: {expiry})'),
    TemplateVariable(tag: '{validFromDate}', label: 'Start Date', example: '01 Nov 2026', description: 'Plan starting date (alias: {validFrom})'),
    TemplateVariable(tag: '{receiptNumber}', label: 'Receipt #', example: 'REC-2026-0842', description: 'Official receipt number (alias: {receiptNo})'),
    TemplateVariable(tag: '{paymentMethod}', label: 'Payment Mode', example: 'Cash / Reception', description: 'Payment method used'),
    TemplateVariable(tag: '{paymentDate}', label: 'Payment Date', example: '05 Nov 2026', description: 'Date payment was recorded'),
    TemplateVariable(tag: '{libraryName}', label: 'Library Name', example: 'The Cozy Corner', description: 'Institution name (alias: {library})'),
    TemplateVariable(tag: '{libraryHelpline}', label: 'Helpline', example: '+91 91569 44773', description: 'Library phone / contact (alias: {helpline})'),
    TemplateVariable(tag: '{libraryUpiId}', label: 'UPI ID / VPA', example: '7276959070@upi', description: 'Library UPI ID for online fees (alias: {upi})'),
    TemplateVariable(tag: '{receiptUrl}', label: 'Receipt Link', example: 'https://study-lib-mgmt-2026.web.app/receipts/REC-01', description: 'Direct link to online receipt'),
    TemplateVariable(tag: '{libraryAddress}', label: 'Address', example: 'Someshwar Nagar, Parli', description: 'Physical branch address (alias: {address})'),
    TemplateVariable(tag: '{shiftName}', label: 'Shift', example: 'Full Day', description: 'Enrolled study shift name'),
    TemplateVariable(tag: '{shiftTiming}', label: 'Shift Timing', example: '07:00 AM – 11:00 PM', description: 'Study shift operating hours'),
    TemplateVariable(tag: '{daysRemaining}', label: 'Days Left', example: '3', description: 'Number of days left before expiry (alias: {days})'),
    TemplateVariable(tag: '{holdingHours}', label: 'Holding Window', example: '24', description: 'Seat reservation holding window in hours (alias: {holdHours})'),
  ];

  static List<String> get availableVariables =>
      variableDefinitions.map((v) => v.tag).toList();

  /// Normalizes any input string to Title Case (e.g. 'shubham dixit' -> 'Shubham Dixit').
  static String toTitleCase(String s) {
    if (s.trim().isEmpty) return s;
    return s
        .trim()
        .toLowerCase()
        .replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase());
  }

  /// Substitutes all canonical tags and user-friendly aliases with actual values.
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
    String? daysRemaining,
    String? holdingHours,
  }) {
    if (template.isEmpty) return '';

    // Automatically apply clean Title Casing to student name
    final cleanStudentName = (studentName != null && studentName.trim().isNotEmpty)
        ? toTitleCase(studentName)
        : '';

    // First normalize friendly short aliases to canonical tags
    var result = template
        .replaceAll('{name}', '{studentName}')
        .replaceAll('{seat}', '{seatLabel}')
        .replaceAll('{desk}', '{seatLabel}')
        .replaceAll('{due}', '{dueAmount}')
        .replaceAll('{expiry}', '{expiryDate}')
        .replaceAll('{validFrom}', '{validFromDate}')
        .replaceAll('{receipt}', '{receiptNumber}')
        .replaceAll('{receiptNo}', '{receiptNumber}')
        .replaceAll('{plan}', '{planName}')
        .replaceAll('{library}', '{libraryName}')
        .replaceAll('{upi}', '{libraryUpiId}')
        .replaceAll('{helpline}', '{libraryHelpline}')
        .replaceAll('{address}', '{libraryAddress}')
        .replaceAll('{days}', '{daysRemaining}')
        .replaceAll('{holdHours}', '{holdingHours}');

    // Clean fallback for seatLabel
    final cleanSeat = (seatLabel != null && seatLabel.trim().isNotEmpty)
        ? seatLabel.trim()
        : 'फ्लेक्सिबल (General Shift)';

    // Substitute canonical tags
    result = result
        .replaceAll('{studentName}', cleanStudentName)
        .replaceAll('{planName}', planName ?? '')
        .replaceAll('{expiryDate}', expiryDate ?? '')
        .replaceAll('{validFromDate}', validFromDate ?? '')
        .replaceAll('{membershipId}', membershipId ?? '')
        .replaceAll('{seatLabel}', cleanSeat)
        .replaceAll('{libraryName}', libraryName ?? '')
        .replaceAll('{amount}', amount ?? '')
        .replaceAll('{paymentMethod}', paymentMethod ?? '')
        .replaceAll('{phone}', phone ?? '')
        .replaceAll('{libraryAddress}', libraryAddress ?? '')
        .replaceAll('{libraryHelpline}', libraryHelpline ?? '')
        .replaceAll('{receiptNumber}', receiptNumber ?? '')
        .replaceAll('{receiptUrl}', receiptUrl?.trim() ?? '')
        .replaceAll('{dueAmount}', dueAmount ?? '')
        .replaceAll('{dueDate}', dueDate ?? '')
        .replaceAll('{shiftName}', shiftName ?? '')
        .replaceAll('{shiftTiming}', shiftTiming ?? '')
        .replaceAll('{libraryUpiId}', libraryUpiId ?? '')
        .replaceAll('{paymentDate}', paymentDate ?? '')
        .replaceAll('{daysRemaining}', daysRemaining ?? '')
        .replaceAll('{holdingHours}', holdingHours ?? '24');

    // If receiptUrl is empty, cleanly strip empty receipt link lines so no dangling labels appear
    if (receiptUrl == null || receiptUrl.trim().isEmpty) {
      result = result
          .replaceAll(RegExp(r'🔗[^\n]*\n*'), '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    }

    // If libraryHelpline is empty, cleanly strip empty helpline lines
    if (libraryHelpline == null || libraryHelpline.trim().isEmpty) {
      result = result
          .replaceAll(RegExp(r'📞[^\n]*:\s*\n*'), '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    }

    // Clean up empty parentheses e.g. "₹2000 ()" or "₹ ()" -> "₹2000"
    result = result.replaceAll(RegExp(r'\s*\(\s*\)'), '');

    // If amount is empty, cleanly format or replace dangling currency symbols
    if (amount == null || amount.trim().isEmpty || amount.trim() == '0') {
      result = result.replaceAll(RegExp(r'₹\s*(?=\n|$)'), 'As per selected plan');
    }

    return result.trim();
  }

  /// Generates a realistic mock preview of the template
  static String getLivePreview(
    String template, {
    String? libraryName,
    String? helpline,
    String? upiId,
    String? address,
    String? prefix,
  }) {
    return substitute(
      template,
      studentName: 'Shubham Kandukatle',
      planName: 'Monthly Full-Day',
      expiryDate: '30 Nov 2026',
      validFromDate: '01 Nov 2026',
      membershipId: '${prefix ?? "CC"}20260014',
      seatLabel: 'Seat #14 (Cozy Hall)',
      libraryName: (libraryName != null && libraryName.isNotEmpty) ? libraryName : 'The Cozy Corner Study Centre',
      amount: '700',
      paymentMethod: 'Cash / Reception',
      phone: '+91 91569 44773',
      libraryAddress: (address != null && address.isNotEmpty) ? address : 'Someshwar Nagar, Parli Vaijanath',
      libraryHelpline: (helpline != null && helpline.isNotEmpty) ? helpline : '+91 91569 44773',
      receiptNumber: 'REC-2026-0842',
      receiptUrl: 'https://study-lib-mgmt-2026.web.app/receipts/REC-2026-0842',
      dueAmount: '0',
      dueDate: '05 Nov 2026',
      shiftName: 'Full Day (24/7)',
      shiftTiming: '07:00 AM – 11:00 PM',
      libraryUpiId: (upiId != null && upiId.isNotEmpty) ? upiId : '7276959070@upi',
      paymentDate: '05 Nov 2026',
      daysRemaining: '25',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. ADMISSION WELCOME PRESETS
  // ──────────────────────────────────────────────────────────────────────────
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
      '📞 *Helpline:* {libraryHelpline}\n\n'
      'We wish you a deeply focused, disciplined, and successful study journey! 📚✨\n\n'
      '— *Team {libraryName}*';

  static const welcomeHindi =
      '🎉 *{libraryName} में आपका स्वागत है!*\n\n'
      'नमस्ते *{studentName}*,\n'
      'हमें आपको हमारे अध्ययन परिवार में शामिल करते हुए अत्यंत प्रसन्नता हो रही है। आपका लाइब्रेरी प्रवेश सफलतापूर्वक सुनिश्चित हो गया है।\n\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '📋 *प्रवेश विवरण*\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *विद्यार्थी का नाम:* {studentName}\n'
      '🆔 *प्रवेश क्रमांक (ID):* {membershipId}\n'
      '📦 *चयनित प्लान:* {planName}\n'
      '💺 *आवंटित डेस्क:* {seatLabel}\n'
      '📅 *वैधता समाप्ति:* {expiryDate}\n'
      '💰 *जमा शुल्क:* ₹{amount} ({paymentMethod})\n\n'
      '📍 *पता:* {libraryAddress}\n'
      '📞 *सहायता केंद्र (Helpline):* {libraryHelpline}\n\n'
      'हम आपकी लगन, एकाग्रता और उज्ज्वल भविष्य की कामना करते हैं! 📚✨\n\n'
      '— *{libraryName} परिवार*';

  static const welcomeMarathi =
      '🎉 *{libraryName} मध्ये आपले सहर्ष स्वागत आहे!*\n\n'
      'सस्नेह नमस्कार *{studentName}*,\n'
      'आमच्या अभ्यास केंद्रात आपले मनःपूर्वक स्वागत! आपली लायब्ररी सदस्यता यशस्वीरीत्या नोंदणीकृत झाली आहे.\n\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '📋 *प्रवेश तपशील*\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *विद्यार्थ्याचे नाव:* {studentName}\n'
      '🆔 *नोंदणी क्रमांक (ID):* {membershipId}\n'
      '📦 *सदस्यता प्लॅन:* {planName}\n'
      '💺 *नेमून दिलेली डेस्क:* {seatLabel}\n'
      '📅 *अंतिम मुदत:* {expiryDate}\n'
      '💰 *भरलेले शुल्क:* ₹{amount} ({paymentMethod})\n\n'
      '📍 *पत्ता:* {libraryAddress}\n'
      '📞 *हेल्पलाईन:* {libraryHelpline}\n\n'
      'आपल्या अभ्यासाच्या आणि यशाच्या प्रवासास मनःपूर्वक शुभेच्छा! 📚✨\n\n'
      '— *{libraryName} व्यवस्थापन*';

  // ──────────────────────────────────────────────────────────────────────────
  // 2. FEE RECEIPT / PAYMENT CONFIRMATION PRESETS
  // ──────────────────────────────────────────────────────────────────────────
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

  static const paymentReceiptHindi =
      '✅ *शुल्क प्राप्ति पावती — {libraryName}*\n\n'
      'नमस्ते *{studentName}*,\n'
      'आपकी फीस सफलतापूर्वक प्राप्त हुई है और आधिकारिक रसीद दर्ज कर ली गई है।\n\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '🧾 *रसीद विवरण*\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '🧾 *रसीद क्रमांक:* {receiptNumber}\n'
      '📅 *भुगतान तिथि:* {paymentDate}\n'
      '💳 *प्राप्त राशि:* *₹{amount}*\n'
      '💳 *भुगतान माध्यम:* {paymentMethod}\n'
      '📦 *प्लान:* {planName}\n'
      '💺 *डेस्क क्रमांक:* {seatLabel}\n'
      '🗓️ *वैधता अवधि:* {validFromDate} से {expiryDate}\n\n'
      '🔗 *डिजिटल रसीद लिंक:* {receiptUrl}\n\n'
      '*{libraryName}* पर विश्वास करने के लिए धन्यवाद! 🙏';

  static const paymentReceiptMarathi =
      '✅ *शुल्क पावती — {libraryName}*\n\n'
      'सस्नेह नमस्कार *{studentName}*,\n'
      'आपले शुल्क यशस्वीरीत्या जमा झाले असून अधिकृत पावती नोंदवली आहे.\n\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '🧾 *पावती तपशील*\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '🧾 *पावती क्रमांक:* {receiptNumber}\n'
      '📅 *भरणा तारीख:* {paymentDate}\n'
      '💳 *जमा रक्कम:* *₹{amount}*\n'
      '💳 *भरणा पद्धत:* {paymentMethod}\n'
      '📦 *प्लॅन:* {planName}\n'
      '💺 *डेस्क क्रमांक:* {seatLabel}\n'
      '🗓️ *कालावधी:* {validFromDate} ते {expiryDate}\n\n'
      '🔗 *अधिकृत डिजिटल पावती लिंक:*\n{receiptUrl}\n\n'
      '📞 *मदत व हेल्पलाईन:* {libraryHelpline}\n\n'
      '*{libraryName}* ची निवड केल्याबद्दल मनःपूर्वक धन्यवाद! 🙏';

  // ──────────────────────────────────────────────────────────────────────────
  // 3. PENDING DUE REMINDER PRESETS
  // ──────────────────────────────────────────────────────────────────────────
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
      '📲 *UPI ID:* {libraryUpiId}\n'
      '📞 *Helpline:* {libraryHelpline}\n\n'
      'Warm regards,\n'
      '*Admin Desk · {libraryName}*';

  static const dueReminderHindi =
      '📌 *बकाया शुल्क सूचना — {libraryName}*\n\n'
      'नमस्ते *{studentName}*,\n'
      'यह आपके *{planName}* प्लान के बकाया शुल्क के संबंध में एक विनम्र स्मरणपत्र है।\n\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '💰 *बकाया विवरण*\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *विद्यार्थी:* {studentName}\n'
      '🆔 *प्रवेश ID:* {membershipId}\n'
      '💺 *डेस्क:* {seatLabel}\n'
      '💵 *कुल बकाया राशि:* *₹{dueAmount}*\n\n'
      'कृपया अपनी डेस्क आरक्षित रखने हेतु रिसेप्शन पर शेष राशि जमा करें।\n'
      '📲 *UPI ID:* {libraryUpiId}\n'
      '📞 *सहायता केंद्र:* {libraryHelpline}\n\n'
      'सधन्यवाद,\n'
      '*प्रबंधन डेस्क · {libraryName}*';

  static const dueReminderMarathi =
      '📌 *थकबाकी शुल्क स्मरणपत्र — {libraryName}*\n\n'
      'सस्नेह नमस्कार *{studentName}*,\n'
      'आपल्या *{planName}* सदस्यतेच्या उर्वरित शुल्काबाबत हे नम्र स्मरणपत्र आहे.\n\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '💰 *थकबाकी तपशील*\n'
      '━━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *विद्यार्थी:* {studentName}\n'
      '🆔 *प्रवेश ID:* {membershipId}\n'
      '💺 *डेस्क:* {seatLabel}\n'
      '💵 *उर्वरित थकबाकी:* *₹{dueAmount}*\n\n'
      'आपली बैठक जागा अखंडित सुरू ठेवण्यासाठी कृपया रिसेप्शनवर शिल्लक शुल्क जमा करावे.\n'
      '📲 *UPI द्वारे भरणा:* {libraryUpiId}\n'
      '📞 *हेल्पलाईन:* {libraryHelpline}\n\n'
      'आपला नम्र,\n'
      '*प्रशासन डेस्क · {libraryName}*';

  // ──────────────────────────────────────────────────────────────────────────
  // 4. PLAN EXPIRY / RENEWAL REMINDER PRESETS
  // ──────────────────────────────────────────────────────────────────────────
  static const defaultExpiryReminderTemplate =
      '⏰ *Seat Renewal Notice — {libraryName}*\n\n'
      'Dear *{studentName}*,\n'
      'Your study desk subscription for *{seatLabel}* at *{libraryName}* expires on *{expiryDate}*.\n\n'
      'To ensure uninterrupted daily study hours and maintain your dedicated seat reservation, please confirm your renewal at the reception desk.\n\n'
      '📲 *Quick Renew via UPI:* `{libraryUpiId}`\n'
      '📞 *Helpline:* {libraryHelpline}\n\n'
      'Best wishes for your studies & exams! 📚🎯\n'
      '— *{libraryName} Management*';

  static const expiryReminderHindi =
      '⏰ *प्लान नवीनीकरण सूचना — {libraryName}*\n\n'
      'नमस्ते *{studentName}*,\n'
      '*{libraryName}* में आपकी *{seatLabel}* डेस्क की सदस्यता *{expiryDate}* को समाप्त हो रही है।\n\n'
      'अपनी पढ़ाई बिना किसी रुकावट के जारी रखने और अपनी सीट सुरक्षित रखने के लिए कृपया समय पर नवीनीकरण करें।\n\n'
      '📲 *UPI द्वारा भुगतान:* `{libraryUpiId}`\n'
      '📞 *संपर्क क्रमांक:* {libraryHelpline}\n\n'
      'आपकी परीक्षा की तैयारी के लिए हार्दिक शुभकामनाएं! 📚🎯\n'
      '— *{libraryName} प्रबंधन*';

  static const expiryReminderMarathi =
      '⏰ *सदस्यत्व नूतनीकरण स्मरणपत्र — {libraryName}*\n\n'
      'सस्नेह नमस्कार *{studentName}*,\n'
      '*{libraryName}* मधील आपली *{seatLabel}* डेस्क सदस्यता *{expiryDate}* रोजी समाप्त होत आहे.\n\n'
      'आपला अभ्यास अखंडित चालू राहण्यासाठी आणि आपली निश्चित केलेली डेस्क आरक्षित ठेवण्यासाठी कृपया मुदतीपूर्वी नूतनीकरण करावे.\n\n'
      '📲 *UPI द्वारे त्वरित नूतनीकरण:* `{libraryUpiId}`\n'
      '📞 *हेल्पलाईन:* {libraryHelpline}\n\n'
      'आपल्या अभ्यासासाठी आणि आगामी परीक्षांसाठी हार्दिक शुभेच्छा! 📚🎯\n'
      '— *{libraryName} व्यवस्थापन*';

  // ──────────────────────────────────────────────────────────────────────────
  // 5. WAITING LIST PROMOTION PRESETS
  // ──────────────────────────────────────────────────────────────────────────
  static const defaultWaitlistOfferTemplate =
      '✨ *Study Seat Available — {libraryName}*\n\n'
      'Dear *{studentName}*,\n'
      'Great news! A dedicated study seat (*{seatLabel}*) is now available for you under the *{planName}* plan at *{libraryName}*.\n\n'
      'Kindly visit the library reception within {holdingHours} hours to confirm your admission and complete registration.\n\n'
      '📍 *Address:* {libraryAddress}\n'
      '📞 *Helpline:* {libraryHelpline}\n\n'
      'We look forward to welcoming you! 📖✨\n'
      '— *Team {libraryName}*';

  static const waitlistOfferHindi =
      '✨ *सीट उपलब्ध सूचना — {libraryName}*\n\n'
      'नमस्ते *{studentName}*,\n'
      'खुशखबरी! *{libraryName}* में आपके लिए *{planName}* के अंतर्गत एक सीट (*{seatLabel}*) उपलब्ध हो गई है।\n\n'
      'कृपया अगले {holdingHours} घंटों में रिसेप्शन पर आकर अपना प्रवेश सुनिश्चित करें।\n\n'
      '📍 *पता:* {libraryAddress}\n'
      '📞 *सहायता केंद्र:* {libraryHelpline}\n\n'
      '— *{libraryName}*';

  static const waitlistOfferMarathi =
      '✨ *अभ्यास बैठक (Seat) उपलब्ध — {libraryName}*\n\n'
      'सस्नेह नमस्कार *{studentName}*,\n'
      'आनंदाची बातमी! *{libraryName}* मध्ये आपल्यासाठी *{planName}* अंतर्गत डेस्क (*{seatLabel}*) उपलब्ध झाली आहे.\n\n'
      'कृपया पुढील {holdingHours} तासांत लायब्ररी रिसेप्शनला भेट देऊन आपला प्रवेश निश्चित करावा.\n\n'
      '📍 *पत्ता:* {libraryAddress}\n'
      '📞 *हेल्पलाईन:* {libraryHelpline}\n\n'
      '— *{libraryName} व्यवस्थापन*';

  // ──────────────────────────────────────────────────────────────────────────
  // 6. REGISTRATION RECEIVED PRESETS (Immediate Acknowledgement)
  // ──────────────────────────────────────────────────────────────────────────
  static const defaultRegistrationReceivedTemplate =
      '📋 *Application Received — {libraryName}*\n\n'
      'Dear *{studentName}*,\n'
      'Thank you for submitting your admission application! We have safely received your request and our desk management is reviewing your documents.\n\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '📌 *APPLICATION SUMMARY*\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *Applicant Name:* {studentName}\n'
      '📦 *Selected Plan:* {planName}\n'
      '💺 *Preferred Desk:* {seatLabel}\n'
      '⏱️ *Review Window:* Usually approved within 24 hours\n\n'
      'We will notify you immediately once your admission is approved. 🎓✨\n\n'
      '📞 *Helpline:* {libraryHelpline}\n'
      '📍 *Address:* {libraryAddress}\n\n'
      '— *Team {libraryName}*';

  static const registrationReceivedHindi =
      '📋 *प्रवेश आवेदन प्राप्त हुआ — {libraryName}*\n\n'
      'नमस्ते *{studentName}*,\n'
      'आपका प्रवेश आवेदन सफलतापूर्वक प्राप्त हो गया है। हमारा प्रबंधन दल आपके दस्तावेजों की समीक्षा कर रहा है।\n\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '📌 *आवेदन विवरण*\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *विद्यार्थी का नाम:* {studentName}\n'
      '📦 *चुना गया प्लान:* {planName}\n'
      '💺 *डेस्क:* {seatLabel}\n'
      '⏱️ *अनुमोदन समय:* सामान्यतः २४ घंटों के भीतर\n\n'
      'प्रवेश स्वीकृत होते ही आपको सूचित किया जाएगा। 📚\n\n'
      '📞 *हेल्पलाइन:* {libraryHelpline}\n'
      '— *{libraryName} प्रबंधन*';

  static const registrationReceivedMarathi =
      '📋 *प्रवेश अर्ज प्राप्त झाला — {libraryName}*\n\n'
      'सस्नेह नमस्कार *{studentName}*,\n'
      'आपला लायब्ररी प्रवेश अर्ज यशस्वीरीत्या प्राप्त झाला आहे. आपले कागदपत्रे पडताळणी प्रक्रियेत आहेत.\n\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '📌 *अर्जाचा संक्षिप्त तपशील*\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *विद्यार्थ्याचे नाव:* {studentName}\n'
      '📦 *निवडलेला प्लॅन:* {planName}\n'
      '💺 *आरक्षित डेस्क:* {seatLabel}\n'
      '⏱️ *मंजुरी कालावधी:* साधारण २४ तासांच्या आत\n\n'
      'प्रवेश मंजूर होताच आपणास त्वरित संदेश पाठविला जाईल. 📚✨\n\n'
      '📞 *हेल्पलाईन:* {libraryHelpline}\n'
      '— *{libraryName} व्यवस्थापन*';

  // ──────────────────────────────────────────────────────────────────────────
  // 7. SEAT REASSIGNMENT PRESETS
  // ──────────────────────────────────────────────────────────────────────────
  static const defaultSeatReassignmentTemplate =
      '🔄 *Seat Reassignment Notice — {libraryName}*\n\n'
      'Dear *{studentName}*,\n'
      'Please note that your study desk allocation has been updated by the library administration.\n\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '💺 *NEW DESK DETAILS*\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '🆔 *Member ID:* {membershipId}\n'
      '💺 *New Allocated Desk:* {seatLabel}\n'
      '📦 *Enrolled Plan:* {planName}\n\n'
      'Please report to your newly allocated study desk on your next visit.\n\n'
      '📞 *Helpline:* {libraryHelpline}\n'
      '— *Management, {libraryName}*';

  static const seatReassignmentHindi =
      '🔄 *सीट परिवर्तन सूचना — {libraryName}*\n\n'
      'नमस्ते *{studentName}*,\n'
      'कृपया ध्यान दें कि लाइब्रेरी प्रबंधन द्वारा आपकी अध्ययन सीट बदल दी गई है।\n\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '💺 *नई सीट विवरण*\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '🆔 *सदस्यता क्रमांक:* {membershipId}\n'
      '💺 *नई आवंटित सीट:* {seatLabel}\n\n'
      'कृपया अगली बार से अपनी नई सीट पर ही अध्ययन करें।\n\n'
      '📞 *हेल्पलाइन:* {libraryHelpline}\n'
      '— *{libraryName} प्रबंधन*';

  static const seatReassignmentMarathi =
      '🔄 *डेस्क बदल / पुनर्नियोजन सूचना — {libraryName}*\n\n'
      'सस्नेह नमस्कार *{studentName}*,\n'
      'लायब्ररी व्यवस्थापनाकडून आपल्या अभ्यासाची डेस्क बदलण्यात आली आहे याची नोंद घ्यावी.\n\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '💺 *नवीन डेस्क तपशील*\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '🆔 *नोंदणी क्रमांक:* {membershipId}\n'
      '💺 *नवीन नेमून दिलेली डेस्क:* {seatLabel}\n\n'
      'कृपया आपल्या पुढील अभ्यासाच्या वेळेस नवीन डेस्कवर बसावे.\n\n'
      '📞 *हेल्पलाईन:* {libraryHelpline}\n'
      '— *{libraryName} व्यवस्थापन*';

  // ──────────────────────────────────────────────────────────────────────────
  // 8. 7-DAY EXPIRY WARNING PRESETS (Proactive Protection)
  // ──────────────────────────────────────────────────────────────────────────
  static const defaultExpiryWarning7DaysTemplate =
      '⏳ *Membership Renewal Reminder — {libraryName}*\n\n'
      'Dear *{studentName}*,\n'
      'This is a friendly reminder that your library membership plan will expire in *{daysRemaining} days* on *{expiryDate}*.\n\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '🔒 *DESK PROTECTION SUMMARY*\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '💺 *Allocated Desk:* {seatLabel}\n'
      '📦 *Current Plan:* {planName}\n'
      '📅 *Expiry Date:* {expiryDate}\n\n'
      'To guarantee continuous study access and prevent your desk from being reallocated, please renew early.\n\n'
      '📲 *Instant UPI Renewal:* `{libraryUpiId}`\n'
      '📞 *Helpline:* {libraryHelpline}\n\n'
      'Wishing you uninterrupted focus & success in your studies! 📚🎯\n'
      '— *Team {libraryName}*';

  static const expiryWarning7DaysHindi =
      '⏳ *सदस्यता नवीनीकरण अग्रिम सूचना — {libraryName}*\n\n'
      'नमस्ते *{studentName}*,\n'
      'आपकी लाइब्रेरी सदस्यता अगले *{daysRemaining} दिनों* में (*{expiryDate}*) समाप्त हो रही है।\n\n'
      '💺 *आपकी सीट:* {seatLabel}\n'
      '📅 *अंतिम तिथि:* {expiryDate}\n\n'
      'अपनी सीट सुरक्षित रखने और निर्बाध अध्ययन के लिए कृपया समय पर नवीनीकरण कराएं।\n\n'
      '📲 *UPI भुगतान:* `{libraryUpiId}`\n'
      '📞 *हेल्पलाइन:* {libraryHelpline}\n'
      '— *{libraryName}*';

  static const expiryWarning7DaysMarathi =
      '⏳ *सदस्यता नूतनीकरण पूर्वसूचना — {libraryName}*\n\n'
      'सस्नेह नमस्कार *{studentName}*,\n'
      'आपल्या लायब्ररी सदस्यतेची मुदत पुढील *{daysRemaining} दिवसांत* म्हणजेच *{expiryDate}* रोजी संपत आहे.\n\n'
      '💺 *आपली आरक्षित डेस्क:* {seatLabel}\n'
      '📅 *मुदत संपण्याची तारीख:* {expiryDate}\n\n'
      'अभ्यासात खंड पडू नये व आपली डेस्क सुरक्षित राहावी यासाठी मुदतीपूर्वी नूतनीकरण करावे.\n\n'
      '📲 *UPI नूतनीकरण:* `{libraryUpiId}`\n'
      '📞 *हेल्पलाईन:* {libraryHelpline}\n'
      '— *{libraryName} व्यवस्थापन*';

  // ──────────────────────────────────────────────────────────────────────────
  // 9. DIGITAL ID CARD READY PRESETS
  // ──────────────────────────────────────────────────────────────────────────
  static const defaultIdCardReadyTemplate =
      '🪪 *Your Digital ID Card is Ready — {libraryName}*\n\n'
      'Dear *{studentName}*,\n'
      'Your official Digital Library Membership Card has been generated and is now active!\n\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '🆔 *ID CARD DETAILS*\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *Name:* {studentName}\n'
      '🆔 *Member ID:* {membershipId}\n'
      '💺 *Allocated Desk:* {seatLabel}\n'
      '📅 *Valid Till:* {expiryDate}\n\n'
      '📱 *How to access:* Open the Cozy Corner App ➔ Tap **My ID Card** to view, download, or show at reception.\n\n'
      '📞 *Helpline:* {libraryHelpline}\n'
      '— *Team {libraryName}*';

  static const idCardReadyHindi =
      '🪪 *डिजिटल आईडी कार्ड तैयार है — {libraryName}*\n\n'
      'नमस्ते *{studentName}*,\n'
      'आपका डिजिटल लाइब्रेरी पहचान पत्र (ID Card) तैयार हो चुका है!\n\n'
      '🆔 *सदस्यता आईडी:* {membershipId}\n'
      '💺 *सीट:* {seatLabel}\n\n'
      '📱 ऐप में जाकर "My ID Card" विकल्प पर अपना कार्ड देखें और डाउनलोड करें।\n\n'
      '📞 *हेल्पलाइन:* {libraryHelpline}\n'
      '— *{libraryName}*';

  static const idCardReadyMarathi =
      '🪪 *आपले डिजिटल ओळखपत्र तयार आहे — {libraryName}*\n\n'
      'सस्नेह नमस्कार *{studentName}*,\n'
      'आपले अधिकृत डिजिटल लायब्ररी ओळखपत्र (Smart ID Card) आता तयार झाले आहे!\n\n'
      '🆔 *नोंदणी क्रमांक (ID):* {membershipId}\n'
      '💺 *नेमून दिलेली डेस्क:* {seatLabel}\n'
      '📅 *वैधता:* {expiryDate}\n\n'
      '📱 Cozy Corner अ‍ॅप उघडून **My ID Card** पर्यायावर क्लिक करून आपले कार्ड डाऊनलोड करा.\n\n'
      '📞 *हेल्पलाईन:* {libraryHelpline}\n'
      '— *{libraryName} व्यवस्थापन*';

  /// Default receipt footer template
  static const defaultReceiptFooter =
      'Thank you for choosing {libraryName}. We wish you great success!';

  /// Resolves the default template for a given category and language code
  static String getTemplate({
    required String type,
    String language = 'en',
  }) {
    final lang = language.toLowerCase();
    switch (type) {
      case 'welcome':
        if (lang == 'hi') return welcomeHindi;
        if (lang == 'mr') return welcomeMarathi;
        return defaultWelcomeTemplate;

      case 'payment_receipt':
      case 'paymentReceipt':
      case 'receipt':
        if (lang == 'hi') return paymentReceiptHindi;
        if (lang == 'mr') return paymentReceiptMarathi;
        return defaultPaymentReceiptTemplate;

      case 'due_reminder':
      case 'dueReminder':
      case 'due':
        if (lang == 'hi') return dueReminderHindi;
        if (lang == 'mr') return dueReminderMarathi;
        return defaultDueReminderTemplate;

      case 'expiry_reminder':
      case 'expiryReminder':
      case 'expiry':
        if (lang == 'hi') return expiryReminderHindi;
        if (lang == 'mr') return expiryReminderMarathi;
        return defaultExpiryReminderTemplate;

      case 'waitlist_offer':
      case 'waitlistOffer':
      case 'waitlist':
        if (lang == 'hi') return waitlistOfferHindi;
        if (lang == 'mr') return waitlistOfferMarathi;
        return defaultWaitlistOfferTemplate;

      case 'registration_received':
      case 'registrationReceived':
      case 'application_received':
        if (lang == 'hi') return registrationReceivedHindi;
        if (lang == 'mr') return registrationReceivedMarathi;
        return defaultRegistrationReceivedTemplate;

      case 'seat_reassignment':
      case 'seatReassignment':
      case 'seat_changed':
        if (lang == 'hi') return seatReassignmentHindi;
        if (lang == 'mr') return seatReassignmentMarathi;
        return defaultSeatReassignmentTemplate;

      case 'expiry_warning_7days':
      case 'expiryWarning7Days':
      case 'expiry_7d':
        if (lang == 'hi') return expiryWarning7DaysHindi;
        if (lang == 'mr') return expiryWarning7DaysMarathi;
        return defaultExpiryWarning7DaysTemplate;

      case 'id_card_ready':
      case 'idCardReady':
        if (lang == 'hi') return idCardReadyHindi;
        if (lang == 'mr') return idCardReadyMarathi;
        return defaultIdCardReadyTemplate;

      default:
        return defaultWelcomeTemplate;
    }
  }
}
