const SystemSetting = require('../models/SystemSetting');
const BusinessProfile = require('../models/BusinessProfile');

/**
 * Generate formatted WhatsApp share URL for direct mobile/web dispatch
 */
function getWhatsAppShareUrl(phone, message) {
  let cleanPhone = (phone || '').replace(/[^0-9]/g, '');
  if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;
  return `https://api.whatsapp.com/send?phone=${cleanPhone}&text=${encodeURIComponent(message)}`;
}

/**
 * Format Payment Receipt message for WhatsApp
 */
function formatPaymentReceiptMessage(payment, student, business) {
  const libName = business?.businessName || 'Study Library';
  const receiptNo = payment.receiptNumber || 'REC';
  const amount = payment.finalAmount || 0;
  const planName = payment.plan?.name || student?.plan?.name || 'Membership Plan';
  const dateStr = new Date(payment.paymentDate || Date.now()).toLocaleDateString('en-IN');
  const expiryStr = payment.newExpiryDate ? new Date(payment.newExpiryDate).toLocaleDateString('en-IN') : '-';

  return `🎉 *FEE PAYMENT RECEIPT — ${libName}*\n\n` +
    `Dear *${student.name}*,\n` +
    `Thank you for your payment! Here are your receipt details:\n\n` +
    `📄 *Receipt No:* ${receiptNo}\n` +
    `💰 *Amount Paid:* ₹${amount}\n` +
    `📋 *Plan:* ${planName}\n` +
    `💺 *Assigned Seat:* ${student.seat?.seatNumber || 'Allocated Desk'}\n` +
    `📅 *Payment Date:* ${dateStr}\n` +
    `⏳ *Valid Till:* ${expiryStr}\n\n` +
    `_Carry your digital ID Card daily. Happy Studying!_ 📚\n` +
    `📞 Helpdesk: ${business?.phone || ''}`;
}

/**
 * Format Expiry Reminder message
 */
function formatExpiryReminderMessage(student, daysRemaining, business) {
  const libName = business?.businessName || 'Study Library';
  const expiryStr = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : '-';

  return `⚠️ *MEMBERSHIP EXPIRY ALERT — ${libName}*\n\n` +
    `Dear *${student.name}*,\n` +
    `Your library membership plan will expire in *${daysRemaining} day(s)* on *${expiryStr}*.\n\n` +
    `💺 *Desk:* ${student.seat?.seatNumber || 'Reserved Seat'}\n` +
    `Please renew your fee to retain your assigned seat.\n\n` +
    `📞 Helpdesk: ${business?.phone || ''}`;
}

/**
 * Direct WhatsApp / SMS Gateway sender (API hook for Meta Cloud API or Fast2SMS)
 */
async function sendGatewayMessage({ phone, message, type = 'whatsapp' }) {
  // Check if WhatsApp integration is enabled in settings
  const isWhatsappEnabled = await SystemSetting.getSetting('notification.enableWhatsapp');
  
  console.log(`📡 [Notification Gateway] Sending ${type.toUpperCase()} to ${phone}:`);
  console.log(message);

  // Return simulated successful dispatch payload
  return {
    success: true,
    phone,
    type,
    dispatchedAt: new Date().toISOString(),
    status: isWhatsappEnabled ? 'sent_to_gateway' : 'simulated_success'
  };
}

module.exports = {
  getWhatsAppShareUrl,
  formatPaymentReceiptMessage,
  formatExpiryReminderMessage,
  sendGatewayMessage
};
