/**
 * Zero-Cost WhatsApp Service
 * Provides automated formatting, deep-linking, and free message dispatching
 */

const BusinessProfile = require('../models/BusinessProfile');

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
   * Build instant WhatsApp web click-to-chat URL
   */
  static getClickToChatUrl(phone, message) {
    const formattedPhone = this.formatPhone(phone);
    const encoded = encodeURIComponent(message);
    return `https://wa.me/${formattedPhone}?text=${encoded}`;
  }

  /**
   * 1. Admission Confirmation Template
   */
  static getAdmissionMessage(student, businessName = 'Study Library') {
    return `🎉 *Welcome to ${businessName}!*

Dear *${student.name}*,
Your admission has been confirmed successfully!

🆔 *Student ID:* ${student.studentId}
📞 *Registered Phone:* ${student.phone}
💺 *Seat / Shift:* ${student.seat?.seatNumber || 'Allotted'} (${student.plan?.name || 'Standard'})
📅 *Admission Date:* ${new Date().toLocaleDateString('en-IN')}

Access your Digital QR ID Card & Student Portal:
🔗 http://localhost:5000/#/portal

_Please maintain strict silence and follow library discipline._
Best wishes for your exam preparation! 📚✨`;
  }

  /**
   * 2. Payment Receipt Confirmation Template
   */
  static getPaymentReceiptMessage(payment, student, businessName = 'Study Library') {
    return `🧾 *Payment Receipt Confirmation*
🏢 *${businessName}*

Dear *${student.name}*,
Thank you for your fee payment. Details:

📄 *Receipt No:* ${payment.receiptNumber || 'REC-' + Date.now()}
💰 *Amount Paid:* ₹${payment.amountPaid.toLocaleString('en-IN')}
💳 *Payment Mode:* ${(payment.paymentMode || 'UPI').toUpperCase()}
📅 *Payment Date:* ${new Date(payment.paymentDate || Date.now()).toLocaleDateString('en-IN')}
⏳ *Valid Until:* ${new Date(payment.validUntil || Date.now() + 30*86400000).toLocaleDateString('en-IN')}

View & Download Full PDF Receipt:
🔗 http://localhost:5000/#/payments

_Thank you for choosing ${businessName}!_`;
  }

  /**
   * 3. Membership Expiry Reminder Template
   */
  static getExpiryReminderMessage(student, daysLeft, businessName = 'Study Library', upiId = '') {
    const urgency = daysLeft === 0 ? '⚠️ *EXPIRES TODAY*' : `⏰ *Expires in ${daysLeft} days*`;
    return `${urgency} — Fee Renewal Notice
🏢 *${businessName}*

Dear *${student.name}* (ID: ${student.studentId}),
Your study room membership is scheduled to expire on *${new Date(student.expiryDate).toLocaleDateString('en-IN')}*.

To avoid seat reallocation and late fees, please renew your membership:
${upiId ? `💳 *UPI ID for Direct Payment:* ${upiId}` : ''}
🔗 *Online Self-Renewal Link:* http://localhost:5000/#/portal

_For any queries or seat adjustments, please visit the library desk._`;
  }

  /**
   * 4. Owner End-of-Day (EOD) Summary Template
   */
  static getEODSummaryMessage(summaryData, businessName = 'Study Library') {
    return `📊 *Daily End-of-Day (EOD) Report*
🏢 *${businessName}*
📅 *Date:* ${new Date().toLocaleDateString('en-IN', { weekday: 'long', year: 'numeric', month: 'short', day: 'numeric' })}

💰 *Financial Summary:*
• Today's Collections: *₹${summaryData.todayRevenue.toLocaleString('en-IN')}*
  - UPI / Online: ₹${summaryData.upiRevenue.toLocaleString('en-IN')}
  - Cash: ₹${summaryData.cashRevenue.toLocaleString('en-IN')}
• Today's Expenses: *₹${summaryData.todayExpenses.toLocaleString('en-IN')}*
• Net Today's Cash Flow: *₹${(summaryData.todayRevenue - summaryData.todayExpenses).toLocaleString('en-IN')}*

👥 *Student & Hall Operations:*
• New Admissions Today: *${summaryData.newAdmissionsCount}*
• Total Active Students: *${summaryData.activeStudentsCount}*
• Total Hall Check-ins Today: *${summaryData.todayAttendanceCount}*
• Expiring in Next 3 Days: *${summaryData.expiringSoonCount}*
• Overdue / Unpaid Members: *${summaryData.overdueCount}*

🌐 Open Admin Dashboard: http://localhost:5000/#/dashboard
_Automated Daily Audit by StudyLib OS_`;
  }
}

module.exports = WhatsAppService;
