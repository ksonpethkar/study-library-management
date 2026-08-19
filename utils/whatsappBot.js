const Student = require('../models/Student');
const BusinessProfile = require('../models/BusinessProfile');
const WhatsAppService = require('./whatsappService');

class WhatsAppBot {
  /**
   * Process incoming command from WhatsApp webhook
   * @param {Object} params
   * @param {string} params.phone - Sender phone number
   * @param {string} params.messageText - Incoming message text / command
   * @returns {Promise<Object>} Response object containing reply text, command, student, and success status
   */
  static async processIncomingCommand({ phone, messageText }) {
    if (!phone || !messageText) {
      return {
        success: false,
        reply: '❌ *Error:* Phone number and message text are required.',
        message: 'Missing required parameters'
      };
    }

    const cleanPhone = String(phone).replace(/[^0-9]/g, '');
    const last10 = cleanPhone.slice(-10);

    // Lookup registered student by last 10 digits of phone number
    const student = await Student.findOne({
      phone: { $regex: last10 + '$' }
    })
      .populate('seat')
      .populate('shift')
      .populate('plan')
      .populate('branch');

    if (!student) {
      return {
        success: false,
        reply: `❌ *Student Record Not Found*\nNo student account registered with phone number ${phone}.\nPlease contact the library administration for assistance.`,
        message: 'Student not found'
      };
    }

    const rawCmd = String(messageText).trim();
    const cmd = rawCmd.toLowerCase();

    const business = await BusinessProfile.getProfile();
    const libraryName = business?.businessName || 'Study Library';

    let reply = '';

    if (cmd === '!seat') {
      const seatNo = student.seat?.seatNumber || (typeof student.seat === 'string' ? student.seat : 'Not Allotted');
      const shiftName = student.shift?.name || student.shift || 'General';
      const shiftTimes = (student.shift?.startTime && student.shift?.endTime)
        ? `${student.shift.startTime} - ${student.shift.endTime}`
        : '';
      const shiftDisplay = shiftTimes ? `${shiftName} (${shiftTimes})` : shiftName;
      const branchName = student.branch?.name || business?.city || 'Main Branch';

      reply = `💺 *Active Desk & Seat Details*
🏢 *${libraryName}*

Dear *${student.name}* (ID: ${student.studentId || '-'}),
Here are your active library seating details:

📍 *Branch:* ${branchName}
💺 *Desk / Seat No:* ${seatNo}
⏰ *Shift Timing:* ${shiftDisplay}

_Thank you for choosing ${libraryName}! Happy studying!_ 📚✨`;

    } else if (cmd === '!status' || cmd === '!expiry') {
      const planName = student.plan?.name || (typeof student.plan === 'string' ? student.plan : 'Standard Membership');
      const expDate = student.expiryDate || student.planExpiresAt;
      const expDateStr = expDate
        ? new Date(expDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
        : 'N/A';
      const balanceDue = Number(student.balanceDue || student.pendingFine || 0);
      const statusStr = (student.status || 'active').toUpperCase();

      reply = `📋 *Membership & Subscription Status*
🏢 *${libraryName}*

Dear *${student.name}* (ID: ${student.studentId || '-'}),
Here is your current subscription summary:

📦 *Plan Name:* ${planName}
📅 *Validity End Date:* ${expDateStr}
💰 *Balance Due:* ₹${balanceDue.toLocaleString('en-IN')}
⚡ *Account Status:* ${statusStr}

_Need to renew or pay dues? Reply *!renew* to get payment link & QR code._`;

    } else if (cmd === '!renew') {
      const upiId = business?.upiId || 'thecozycorner@okaxis';
      const planName = student.plan?.name || 'Study Membership';
      const renewalFee = Number(student.plan?.price || 0);
      const balanceDue = Number(student.balanceDue || student.pendingFine || 0);
      const payableAmount = balanceDue > 0 ? balanceDue : renewalFee;

      const upiDeepLink = WhatsAppService.generateUpiDeepLink({
        upiId,
        businessName: libraryName,
        amount: payableAmount,
        note: 'SubscriptionRenewal'
      });

      const qrCodeUrl = upiDeepLink
        ? `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(upiDeepLink)}`
        : 'N/A';

      reply = `⚡ *Instant Membership Renewal & UPI Payment*
🏢 *${libraryName}*

Dear *${student.name}* (ID: ${student.studentId || '-'}),
Renew your membership instantly to maintain active seat reservation!

📦 *Plan:* ${planName}
💰 *Payable Amount:* ₹${payableAmount.toLocaleString('en-IN')}
⚡ *UPI ID:* ${upiId}

👇 *1-Tap Instant UPI Deep Link:*
${upiDeepLink}

🖼️ *Scan & Pay via UPI QR Code:*
${qrCodeUrl}

_Please share payment confirmation screenshot after completing payment._`;

    } else if (cmd === '!help') {
      reply = this.getHelpMenu(student.name, libraryName);
    } else {
      reply = `🤖 *WhatsApp Interactive Bot*
🏢 *${libraryName}*

Hello *${student.name}*! Unrecognized command "${rawCmd}".

` + this.getHelpMenu(student.name, libraryName);
    }

    return {
      success: true,
      command: cmd,
      phone: student.phone,
      studentName: student.name,
      reply,
      student
    };
  }

  /**
   * Helper to format command guide menu
   */
  static getHelpMenu(studentName = 'Student', libraryName = 'Study Library') {
    return `🤖 *WhatsApp Bot Command Guide*
🏢 *${libraryName}*

Send any of the following commands to get instant automated details:

💺 *!seat* - View your active desk number, shift timing & branch
📋 *!status* or *!expiry* - View plan name, validity end date & balance due
⚡ *!renew* - Get 1-tap UPI payment deep link & QR code for renewal
❓ *!help* - Display this command guide menu

_Type and send any command (e.g., !seat) to start!_`;
  }
}

module.exports = WhatsAppBot;
