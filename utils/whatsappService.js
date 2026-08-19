/**
 * Zero-Cost WhatsApp Service
 * Provides automated dynamic template parsing, UPI deep-linking, reminder templates, and message dispatching
 */

const BusinessProfile = require('../models/BusinessProfile');
const Notification = require('../models/Notification');
const MessageTemplate = require('../models/MessageTemplate');

class WhatsAppService {
  /**
   * Format phone number to international 91XXXXXXXXXX format
   */
  static formatPhone(phone) {
    if (!phone) return '';
    let cleaned = String(phone).replace(/[^0-9]/g, '');
    if (cleaned.length === 10) {
      cleaned = '91' + cleaned;
    } else if (cleaned.startsWith('0') && cleaned.length === 11) {
      cleaned = '91' + cleaned.slice(1);
    }
    return cleaned;
  }

  /**
   * Build instant WhatsApp web / app click-to-chat URL
   */
  static getClickToChatUrl(phone, message) {
    const formattedPhone = this.formatPhone(phone);
    const encoded = encodeURIComponent(message || '');
    return `https://wa.me/${formattedPhone}?text=${encoded}`;
  }

  /**
   * Construct 1-tap UPI payment deep link
   * Format: upi://pay?pa=${upiId}&pn=${bizName}&am=${amount}&tn=${note}
   */
  static generateUpiDeepLink({ upiId, businessName = 'Study Library', amount = 0, note = 'SubscriptionRenewal' }) {
    if (!upiId) return '';
    const encodedBiz = encodeURIComponent(businessName || 'Study Library');
    const encodedNote = encodeURIComponent(note || 'LibraryFeePayment');
    let link = `upi://pay?pa=${upiId}&pn=${encodedBiz}`;
    const numAmount = Number(amount);
    if (!isNaN(numAmount) && numAmount > 0) {
      link += `&am=${numAmount}`;
    }
    link += `&tn=${encodedNote}`;
    return link;
  }

  /**
   * Resolve Dynamic Base Domain URL (Production Render URL or Header Host)
   */
  static getBaseUrl(req = null) {
    if (process.env.APP_URL && !process.env.APP_URL.includes('localhost')) {
      return process.env.APP_URL.replace(/\/+$/, '');
    }
    if (process.env.RENDER_EXTERNAL_URL) {
      return process.env.RENDER_EXTERNAL_URL.replace(/\/+$/, '');
    }
    if (req && req.get) {
      const host = req.get('host');
      if (host && !host.includes('localhost') && !host.includes('127.0.0.1')) {
        const protocol = (req.protocol === 'https' || req.get('x-forwarded-proto') === 'https') ? 'https' : 'http';
        return `${protocol}://${host}`;
      }
    }
    return 'https://study-library-management.onrender.com';
  }

  /**
   * Dynamic Template Parser & Placeholder Replacer
   * Replaces placeholders like {{studentName}}, {{studentId}}, {{planName}}, {{expiryDate}},
   * {{amount}}, {{balanceDue}}, {{seatNumber}}, {{shiftName}}, {{businessName}}, {{upiLink}}, {{portalLink}}, etc.
   * Supports both {{placeholder}} and {placeholder} syntax along with snake_case aliases.
   */
  static renderTemplate(templateText, variables = {}) {
    if (!templateText) return '';
    let rendered = templateText;

    const map = {};
    const register = (aliases, value) => {
      const valStr = (value !== undefined && value !== null) ? String(value) : '';
      aliases.forEach(alias => { map[alias] = valStr; });
    };

    register(['studentName', 'student_name', 'name'], variables.studentName || variables.name);
    register(['studentId', 'student_id', 'id'], variables.studentId || variables.id);
    register(['planName', 'plan_name', 'plan'], variables.planName || variables.plan);
    register(['expiryDate', 'expiry_date', 'validUntil', 'valid_until', 'dueDate', 'due_date'], variables.expiryDate || variables.validUntil || variables.dueDate);
    register(['amount', 'amountPaid', 'amount_paid', 'renewalFee', 'fee'], variables.amount || variables.amountPaid);
    register(['balanceDue', 'balance_due', 'due_amount', 'pendingBalance', 'pendingFine', 'balance'], variables.balanceDue || variables.pendingBalance || variables.pendingFine);
    register(['seatNumber', 'seat_no', 'seat_number', 'seat'], variables.seatNumber || variables.seat);
    register(['shiftName', 'shift_name', 'shift'], variables.shiftName || variables.shift);
    register(['businessName', 'library_name', 'libraryName', 'bizName'], variables.businessName || variables.libraryName || 'Study Library');
    register(['upiLink', 'upi_link'], variables.upiLink);
    register(['upiId', 'upi_id'], variables.upiId);
    register(['portalLink', 'portal_link', 'link', 'portalUrl', 'portal_url', 'url'], variables.portalLink);
    register(['receiptNumber', 'receipt_no', 'receipt_number'], variables.receiptNumber);
    register(['paymentMethod', 'payment_mode', 'payment_method'], variables.paymentMethod);
    register(['paymentDate', 'payment_date'], variables.paymentDate);
    register(['upiRef', 'upi_ref', 'transactionId', 'utr'], variables.upiRef || variables.transactionId);
    register(['status', 'attendance_status', 'activity'], variables.status);
    register(['timestamp', 'time', 'punch_time', 'punchTime'], variables.timestamp || variables.time);
    register(['hoursStudied', 'hours_studied', 'duration'], variables.hoursStudied || variables.duration);

    // Register any other variables passed
    for (const [k, v] of Object.entries(variables)) {
      if (map[k] === undefined) {
        map[k] = (v !== undefined && v !== null) ? String(v) : '';
      }
    }

    // Replace all placeholders
    for (const [k, v] of Object.entries(map)) {
      const regDouble = new RegExp(`{{\\s*${k}\\s*}}`, 'gi');
      const regSingle = new RegExp(`{\\s*${k}\\s*}`, 'gi');
      rendered = rendered.replace(regDouble, v).replace(regSingle, v);
    }

    // Clean remaining unmapped {{...}} and {...} tokens
    rendered = rendered.replace(/{{\s*[\w_]+\s*}}/g, '').replace(/{\s*[\w_]+\s*}/g, '');

    return rendered;
  }

  /**
   * Fetch active template by trigger type or return default fallback text
   */
  static async getActiveTemplateText(triggerType) {
    try {
      const aliases = {
        'admission_welcome': ['welcome_admission', 'admission_welcome'],
        'welcome_admission': ['admission_welcome', 'welcome_admission'],
        'renewal_reminder': ['expiry_reminder_3d', 'expiry_reminder_1d', 'expiry_reminder_7d', 'renewal_reminder'],
        'expiry_reminder_3d': ['renewal_reminder', 'expiry_reminder_3d'],
        'balance_due': ['fee_due', 'balance_due'],
        'fee_due': ['balance_due', 'fee_due'],
        'payment_receipt': ['payment_receipt'],
        'attendance_punch': ['attendance_punch']
      };

      const matchTypes = aliases[triggerType] || [triggerType];
      const template = await MessageTemplate.findOne({
        triggerType: { $in: matchTypes },
        isActive: true
      });

      if (template && template.templateText) {
        return template.templateText;
      }
    } catch (e) {
      console.warn(`Could not load MessageTemplate for ${triggerType}:`, e.message);
    }

    // Fallbacks
    const defaults = {
      admission_welcome: `🎉 *Welcome to {{businessName}}!*

Dear *{{studentName}}*,
Your admission has been confirmed successfully!

🆔 *Student ID:* {{studentId}}
💺 *Seat No:* {{seatNumber}}
⏰ *Shift:* {{shiftName}}
📦 *Plan:* {{planName}}
📅 *Valid Until:* {{expiryDate}}

Access your Digital QR ID Card & Student Portal:
🔗 {{portalLink}}

_Please maintain strict library discipline and study hard!_ 📚✨`,

      payment_receipt: `🧾 *Payment Receipt Confirmation*
🏢 *{{businessName}}*

Dear *{{studentName}}*,
Thank you for your fee payment! Details:

📄 *Receipt No:* {{receiptNumber}}
💰 *Amount Paid:* ₹{{amount}}
⚠️ *Balance Due:* ₹{{balanceDue}}
💳 *Payment Mode:* {{paymentMethod}}
📅 *Date:* {{paymentDate}}
⏳ *Valid Until:* {{expiryDate}}
🔗 *UPI Ref / Txn ID:* {{upiRef}}

View & Download Receipt:
🔗 {{portalLink}}

_Thank you for choosing {{businessName}}!_`,

      renewal_reminder: `⏰ *Subscription Renewal Reminder*
🏢 *{{businessName}}*

Dear *{{studentName}}* (ID: {{studentId}}),
Your library plan (*{{planName}}* | Seat #{{seatNumber}} | {{shiftName}}) expires on *{{expiryDate}}*.

💰 *Renewal Fee:* ₹{{amount}}

To avoid seat reallocation and continue uninterrupted study hours, please renew your membership:

⚡ *1-Tap Instant UPI Payment:*
{{upiLink}}

🔗 *Online Student Portal:* {{portalLink}}

_Please share payment confirmation screenshot after completing payment._
Best regards,
*{{businessName}} Desk*`,

      balance_due: `⚠️ *Fee Balance Due Reminder*
🏢 *{{businessName}}*

Dear *{{studentName}}* (ID: {{studentId}}),
This is a gentle reminder regarding your outstanding membership balance of *₹{{balanceDue}}* for Seat #{{seatNumber}}.

Please clear your pending dues to maintain active library access:

⚡ *1-Tap Instant UPI Payment:*
{{upiLink}}

🔗 *Student Portal:* {{portalLink}}

_If already paid, please share your 12-digit UPI UTR number with the library desk._
Thank you,
*{{businessName}} Management*`,

      attendance_punch: `📚 *Daily Attendance Alert*
🏢 *{{businessName}}*

Dear *{{studentName}}* (ID: {{studentId}}),
Here is your attendance update:

⏱️ *Activity:* {{status}}
🕒 *Timestamp:* {{timestamp}}
💺 *Seat:* {{seatNumber}} | {{shiftName}}
⏳ *Hours Studied:* {{hoursStudied}}

Access your attendance logs & study hours on student portal:
🔗 {{portalLink}}

Have a productive study session! ✨`
    };

    return defaults[triggerType] || defaults['admission_welcome'];
  }

  /**
   * 1. Admission Welcome Template (Dynamic)
   */
  static async getAdmissionMessage(student, businessName = 'Study Library', baseUrl = null) {
    const base = baseUrl || this.getBaseUrl();
    const templateText = await this.getActiveTemplateText('admission_welcome');

    const expDate = student.expiryDate || student.planExpiresAt;
    const expDateStr = expDate ? new Date(expDate).toLocaleDateString('en-IN') : new Date(Date.now() + 30 * 86400000).toLocaleDateString('en-IN');

    return this.renderTemplate(templateText, {
      studentName: student.name || 'Student',
      studentId: student.studentId || '-',
      seatNumber: student.seat?.seatNumber || (typeof student.seat === 'string' ? student.seat : 'Allotted'),
      shiftName: student.shift?.name || student.shift || 'General',
      planName: student.plan?.name || (typeof student.plan === 'string' ? student.plan : 'Standard'),
      expiryDate: expDateStr,
      businessName: businessName || 'Study Library',
      portalLink: `${base}/#/portal`,
      amount: student.plan?.price || 0,
      balanceDue: student.balanceDue || student.pendingFine || 0
    });
  }

  /**
   * Send Welcome Message Helper
   */
  static async sendWelcomeMessage(student, password = '', req = null) {
    try {
      const profile = await BusinessProfile.getProfile();
      const base = this.getBaseUrl(req);
      const msg = await this.getAdmissionMessage(student, profile?.businessName || 'Study Library', base);
      const extra = password ? `\n\n🔑 *Portal Password / PIN:* ${password}` : '';
      return this.dispatchReminder({
        student,
        message: msg + extra,
        type: 'admission',
        link: '#/students'
      });
    } catch (e) {
      console.error('sendWelcomeMessage error:', e.message);
      return null;
    }
  }

  /**
   * 2. Payment Receipt Confirmation Template (Dynamic)
   */
  static async getPaymentReceiptMessage(payment, student, businessName = 'Study Library', baseUrl = null, upiId = '') {
    const base = baseUrl || this.getBaseUrl();
    const templateText = await this.getActiveTemplateText('payment_receipt');

    const amountVal = payment.amountPaid !== undefined ? payment.amountPaid : (payment.finalAmount !== undefined ? payment.finalAmount : (payment.amount || 0));
    const balanceVal = payment.balanceDue || 0;
    const directUpiLink = balanceVal > 0 && upiId ? this.generateUpiDeepLink({ upiId, businessName, amount: balanceVal, note: 'BalancePayment' }) : '';

    return this.renderTemplate(templateText, {
      studentName: student?.name || 'Student',
      studentId: student?.studentId || '-',
      receiptNumber: payment.receiptNumber || ('REC-' + Date.now()),
      amount: Number(amountVal).toLocaleString('en-IN'),
      balanceDue: Number(balanceVal).toLocaleString('en-IN'),
      paymentMethod: (payment.paymentMethod || payment.paymentMode || 'UPI').toUpperCase(),
      paymentDate: new Date(payment.paymentDate || Date.now()).toLocaleDateString('en-IN'),
      expiryDate: new Date(payment.periodEnd || payment.validUntil || payment.newExpiryDate || (Date.now() + 30 * 86400000)).toLocaleDateString('en-IN'),
      upiRef: payment.transactionId || payment.referenceNumber || payment.notes || 'UPI Reference',
      seatNumber: student?.seat?.seatNumber || 'Allocated Desk',
      shiftName: student?.shift?.name || student?.shift || 'General',
      planName: payment.plan?.name || student?.plan?.name || 'Study Membership',
      businessName: businessName || 'Study Library',
      portalLink: `${base}/#/portal`,
      upiLink: directUpiLink
    });
  }

  /**
   * 3. Membership Expiry / Subscription Renewal Reminder Template (Dynamic with 1-tap UPI Deep Link)
   */
  static async getExpiryReminderMessage(student, timeLeftStr = '24 hours', businessName = 'Study Library', upiId = '', amount = 0, upiLink = '', baseUrl = null) {
    const base = baseUrl || this.getBaseUrl();
    const templateText = await this.getActiveTemplateText('renewal_reminder');

    const directUpiLink = upiLink || (upiId ? this.generateUpiDeepLink({ upiId, businessName, amount, note: 'SubscriptionRenewal' }) : '');
    const expDate = student.expiryDate || student.planExpiresAt;
    const expDateStr = expDate ? new Date(expDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : 'Soon';
    const planName = student.plan?.name || (typeof student.plan === 'string' ? student.plan : 'Study Membership');
    const seatNum = student.seat?.seatNumber || (typeof student.seat === 'string' ? student.seat : '-');
    const shiftName = student.shift?.name || student.shift || 'General';
    const numAmount = Number(amount || student.plan?.price || 0);

    return this.renderTemplate(templateText, {
      studentName: student.name || 'Student',
      studentId: student.studentId || '-',
      planName,
      seatNumber: seatNum,
      shiftName,
      expiryDate: expDateStr,
      amount: numAmount.toLocaleString('en-IN'),
      balanceDue: Number(student.balanceDue || student.pendingFine || 0).toLocaleString('en-IN'),
      upiLink: directUpiLink,
      portalLink: `${base}/#/portal`,
      businessName: businessName || 'Study Library'
    });
  }

  /**
   * 4. Overdue Balance Due / Partial Payment Reminder Template (Dynamic with 1-tap UPI Deep Link)
   */
  static async getPartialBalanceReminderMessage(student, payment, businessName = 'Study Library', upiId = '', upiLink = '', baseUrl = null) {
    return this.getBalanceDueMessage(student, payment, businessName, upiId, upiLink, baseUrl);
  }

  static async getBalanceDueMessage(student, payment, businessName = 'Study Library', upiId = '', upiLink = '', baseUrl = null) {
    const base = baseUrl || this.getBaseUrl();
    const templateText = await this.getActiveTemplateText('balance_due');

    const balance = payment?.balanceDue !== undefined ? payment.balanceDue : (student.balanceDue || student.pendingFine || 0);
    const directUpiLink = upiLink || (upiId ? this.generateUpiDeepLink({ upiId, businessName, amount: balance, note: 'PartialPaymentBalance' }) : '');
    const dueDateStr = payment?.dueDate ? new Date(payment.dueDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : 'Immediate';
    const seatNum = student.seat?.seatNumber || (typeof student.seat === 'string' ? student.seat : '-');
    const shiftName = student.shift?.name || student.shift || '-';

    return this.renderTemplate(templateText, {
      studentName: student.name || 'Student',
      studentId: student.studentId || '-',
      seatNumber: seatNum,
      shiftName,
      balanceDue: Number(balance).toLocaleString('en-IN'),
      amount: Number(payment?.amount || payment?.finalAmount || balance).toLocaleString('en-IN'),
      expiryDate: dueDateStr,
      dueDate: dueDateStr,
      receiptNumber: payment?.receiptNumber || 'Pending Balance',
      businessName: businessName || 'Study Library',
      upiLink: directUpiLink,
      portalLink: `${base}/#/portal`
    });
  }

  /**
   * 5. Daily Attendance Alert / Punch Alert Template (Dynamic)
   */
  static async getAttendanceAlertMessage(student, businessName = 'Study Library', attendanceInfo = {}, baseUrl = null) {
    const base = baseUrl || this.getBaseUrl();
    const templateText = await this.getActiveTemplateText('attendance_punch');

    const status = attendanceInfo.status || 'Check-in Recorded';
    const time = attendanceInfo.time || attendanceInfo.timestamp || new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
    const seatNum = student.seat?.seatNumber || (typeof student.seat === 'string' ? student.seat : '-');
    const shiftName = student.shift?.name || student.shift || attendanceInfo.shift || 'General';
    const hoursStudied = attendanceInfo.hoursStudied || (attendanceInfo.duration ? `${(attendanceInfo.duration / 60).toFixed(1)} hrs` : 'In Progress');

    return this.renderTemplate(templateText, {
      studentName: student.name || 'Student',
      studentId: student.studentId || '-',
      status,
      timestamp: time,
      time,
      seatNumber: seatNum,
      shiftName,
      hoursStudied,
      businessName: businessName || 'Study Library',
      portalLink: `${base}/#/portal`
    });
  }

  /**
   * 6. Owner End-of-Day (EOD) Summary Template
   */
  static getEODSummaryMessage(summaryData, businessName = 'Study Library', baseUrl = null) {
    const base = baseUrl || this.getBaseUrl();
    return `📊 *Daily End-of-Day (EOD) Report*
🏢 *${businessName}*
📅 *Date:* ${new Date().toLocaleDateString('en-IN', { weekday: 'long', year: 'numeric', month: 'short', day: 'numeric' })}

💰 *Financial Summary:*
• Today's Collections: *₹${(summaryData.todayRevenue || 0).toLocaleString('en-IN')}*
  - UPI / Online: ₹${(summaryData.upiRevenue || 0).toLocaleString('en-IN')}
  - Cash: ₹${(summaryData.cashRevenue || 0).toLocaleString('en-IN')}
• Today's Expenses: *₹${(summaryData.todayExpenses || 0).toLocaleString('en-IN')}*
• Net Today's Cash Flow: *₹${((summaryData.todayRevenue || 0) - (summaryData.todayExpenses || 0)).toLocaleString('en-IN')}*

👥 *Student & Hall Operations:*
• New Admissions Today: *${summaryData.newAdmissionsCount || 0}*
• Total Active Students: *${summaryData.activeStudentsCount || 0}*
• Total Hall Check-ins Today: *${summaryData.todayAttendanceCount || 0}*
• Expiring in Next 3 Days: *${summaryData.expiringSoonCount || 0}*
• Overdue / Unpaid Members: *${summaryData.overdueCount || 0}*

🌐 Open Admin Dashboard: ${base}/#/dashboard
_Automated Daily Audit by StudyLib OS_`;
  }

  /**
   * Dispatch / Log notification & generate WhatsApp URL
   */
  static async dispatchReminder({ student, message, type = 'expiry', link = '' }) {
    try {
      const formattedPhone = this.formatPhone(student.phone);
      const clickToChatUrl = this.getClickToChatUrl(student.phone, message);

      const notifType = (type === 'partial_balance' || type === 'balance_due' || type === 'payment_receipt') 
        ? 'payment' 
        : (type === 'attendance' || type === 'attendance_punch') 
          ? 'system' 
          : (type === 'admission' || type === 'admission_welcome') 
            ? 'admission' 
            : 'expiry';

      const notif = await Notification.create({
        title: `📲 WhatsApp Reminder: ${student.name}`,
        message: message.length > 250 ? message.substring(0, 247) + '...' : message,
        type: notifType,
        link: link || '#/students'
      });

      return {
        success: true,
        studentId: student._id,
        studentName: student.name,
        phone: student.phone,
        formattedPhone,
        whatsappUrl: clickToChatUrl,
        message,
        notificationId: notif._id
      };
    } catch (err) {
      console.error('dispatchReminder error:', err.message);
      return {
        success: false,
        error: err.message
      };
    }
  }
}

module.exports = WhatsAppService;
