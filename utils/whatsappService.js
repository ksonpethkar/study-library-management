/**
 * Zero-Cost WhatsApp Service
 * Provides automated formatting, UPI deep-linking, reminder templates, and message dispatching
 */

const BusinessProfile = require('../models/BusinessProfile');
const Notification = require('../models/Notification');

class WhatsAppService {
  /**
   * Format phone number to international 91XXXXXXXXXX format
   */
  static formatPhone(phone) {
    if (!phone) return '';
    let cleaned = phone.replace(/[^0-9]/g, '');
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
   * Format: upi://pay?pa=${upiId}&pn=${bizName}&am=${amount}&tn=SubscriptionRenewal
   */
  static generateUpiDeepLink({ upiId, businessName = 'Study Library', amount = 0, note = 'SubscriptionRenewal' }) {
    if (!upiId) return '';
    const encodedBiz = encodeURIComponent(businessName);
    const encodedNote = encodeURIComponent(note);
    let link = `upi://pay?pa=${upiId}&pn=${encodedBiz}`;
    const numAmount = Number(amount);
    if (!isNaN(numAmount) && numAmount > 0) {
      link += `&am=${numAmount}`;
    }
    link += `&tn=${encodedNote}`;
    return link;
  }

  /**
   * 1. Admission Confirmation Template
   */
  static getAdmissionMessage(student, businessName = 'Study Library') {
    return `🎉 *Welcome to ${businessName}!*

Dear *${student.name}*,
Your admission has been confirmed successfully!

🆔 *Student ID:* ${student.studentId || '-'}
📞 *Registered Phone:* ${student.phone}
💺 *Seat / Shift:* ${student.seat?.seatNumber || 'Allotted'} (${student.plan?.name || 'Standard'})
📅 *Admission Date:* ${new Date().toLocaleDateString('en-IN')}

Access your Digital QR ID Card & Student Portal:
🔗 http://localhost:5000/#/portal

_Please maintain strict silence and follow library discipline._
Best wishes for your exam preparation! 📚✨`;
  }

  /**
   * Send Welcome Message Helper
   */
  static async sendWelcomeMessage(student, password = '') {
    try {
      const profile = await BusinessProfile.getProfile();
      const msg = this.getAdmissionMessage(student, profile?.businessName || 'Study Library');
      const extra = password ? `\n🔑 *Portal Password / PIN:* ${password}` : '';
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
   * 2. Payment Receipt Confirmation Template
   */
  static getPaymentReceiptMessage(payment, student, businessName = 'Study Library') {
    const amountVal = payment.amountPaid !== undefined ? payment.amountPaid : (payment.finalAmount || payment.amount || 0);
    return `🧾 *Payment Receipt Confirmation*
🏢 *${businessName}*

Dear *${student.name}*,
Thank you for your fee payment. Details:

📄 *Receipt No:* ${payment.receiptNumber || 'REC-' + Date.now()}
💰 *Amount Paid:* ₹${Number(amountVal).toLocaleString('en-IN')}
💳 *Payment Mode:* ${(payment.paymentMethod || payment.paymentMode || 'UPI').toUpperCase()}
📅 *Payment Date:* ${new Date(payment.paymentDate || Date.now()).toLocaleDateString('en-IN')}
⏳ *Valid Until:* ${new Date(payment.periodEnd || payment.validUntil || Date.now() + 30 * 86400000).toLocaleDateString('en-IN')}

View & Download Full Receipt:
🔗 http://localhost:5000/#/payments

_Thank you for choosing ${businessName}!_`;
  }

  /**
   * 3. Membership Expiry Reminder Template with 1-tap UPI Deep Link
   */
  static getExpiryReminderMessage(student, timeLeftStr = '24 hours', businessName = 'Study Library', upiId = '', amount = 0, upiLink = '') {
    const directUpiLink = upiLink || (upiId ? this.generateUpiDeepLink({ upiId, businessName, amount, note: 'SubscriptionRenewal' }) : '');
    const expDate = student.expiryDate || student.planExpiresAt;
    const expDateStr = expDate ? new Date(expDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : 'Soon';
    const planName = student.plan?.name || 'Study Membership';
    const seatNum = student.seat?.seatNumber ? ` | Seat #${student.seat.seatNumber}` : '';
    const numAmount = Number(amount);

    return `⏰ *Subscription Renewal Reminder*
🏢 *${businessName}*

Dear *${student.name}* (ID: ${student.studentId || '-'}),
Your library plan (*${planName}*${seatNum}) expires in *${timeLeftStr}* on *${expDateStr}*.

${numAmount > 0 ? `💰 *Renewal Fee:* ₹${numAmount.toLocaleString('en-IN')}\n` : ''}To avoid seat reallocation and continue uninterrupted study hours, please renew your membership:

${directUpiLink ? `⚡ *1-Tap Instant UPI Payment:*
${directUpiLink}
` : (upiId ? `💳 *UPI ID:* ${upiId}\n` : '')}🔗 *Online Self-Renewal Link:* http://localhost:5000/#/portal

_Please share payment confirmation screenshot after completing payment._
Best regards,
*${businessName} Desk*`;
  }

  /**
   * 4. Partial Payment / Outstanding Balance Reminder Template with 1-tap UPI Deep Link
   */
  static getPartialBalanceReminderMessage(student, payment, businessName = 'Study Library', upiId = '', upiLink = '') {
    const balance = payment?.balanceDue || 0;
    const dueDateStr = payment?.dueDate ? new Date(payment.dueDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : 'Immediate';
    const directUpiLink = upiLink || (upiId ? this.generateUpiDeepLink({ upiId, businessName, amount: balance, note: 'PartialPaymentBalance' }) : '');

    return `⚠️ *Fee Balance Due Reminder*
🏢 *${businessName}*

Dear *${student.name}* (ID: ${student.studentId || '-'}),
This is a gentle reminder regarding your outstanding membership balance with ${businessName}.

💰 *Pending Balance:* ₹${Number(balance).toLocaleString('en-IN')}
📅 *Due Date:* ${dueDateStr}
📄 *Receipt / Invoice:* ${payment?.receiptNumber || 'Pending Balance'}

Please clear your pending dues to maintain active library access.

${directUpiLink ? `⚡ *1-Tap Instant UPI Payment:*
${directUpiLink}
` : (upiId ? `💳 *UPI ID:* ${upiId}\n` : '')}🔗 *Student Portal:* http://localhost:5000/#/portal

_If already paid, please share your 12-digit UPI UTR number with the library desk._
Thank you,
*${businessName} Management*`;
  }

  /**
   * 5. Daily Attendance Alert Template
   */
  static getAttendanceAlertMessage(student, businessName = 'Study Library', attendanceInfo = {}) {
    const todayStr = new Date().toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
    const status = attendanceInfo.status || 'Check-in Recorded';
    const time = attendanceInfo.time || new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
    const seat = student.seat?.seatNumber ? ` | Seat #${student.seat.seatNumber}` : '';

    return `📚 *Daily Attendance Alert*
🏢 *${businessName}*

Dear *${student.name}* (ID: ${student.studentId || '-'}),
Here is your attendance update for *${todayStr}*:

⏱️ *Status:* ${status} at *${time}*${seat}
🎯 Keep up your consistent study discipline! 

_Access your attendance logs & study hours on student portal:_
🔗 http://localhost:5000/#/portal

Have a productive study session! ✨`;
  }

  /**
   * 6. Owner End-of-Day (EOD) Summary Template
   */
  static getEODSummaryMessage(summaryData, businessName = 'Study Library') {
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

🌐 Open Admin Dashboard: http://localhost:5000/#/dashboard
_Automated Daily Audit by StudyLib OS_`;
  }

  /**
   * Dispatch / Log notification & generate WhatsApp URL
   */
  static async dispatchReminder({ student, message, type = 'expiry', link = '' }) {
    try {
      const formattedPhone = this.formatPhone(student.phone);
      const clickToChatUrl = this.getClickToChatUrl(student.phone, message);

      const notifType = type === 'partial_balance' ? 'payment' : (type === 'attendance' ? 'system' : (type === 'admission' ? 'admission' : 'expiry'));

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
