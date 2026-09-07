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
 * Direct WhatsApp / SMS Gateway sender supporting:
 *   1. UltraMsg (https://ultramsg.com)
 *   2. Fast2SMS (https://fast2sms.com)
 *   3. Meta WhatsApp Cloud API (https://developers.facebook.com)
 *   4. Custom Webhook
 *   5. Native Fallback (wa.me click-to-chat)
 */
async function sendGatewayMessage({ phone, message, type = 'whatsapp' }) {
  let cleanPhone = (phone || '').replace(/[^0-9]/g, '');
  if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;

  // Retrieve provider config from SystemSettings or environment variables
  const provider = (await SystemSetting.getSetting('notification.whatsappProvider')) || process.env.WHATSAPP_GATEWAY_PROVIDER || 'none';
  const isEnabled = await SystemSetting.getSetting('notification.enableWhatsapp');

  console.log(`📡 [Notification Gateway] Outgoing ${type.toUpperCase()} to ${cleanPhone} via [${provider}]:`);

  if (!cleanPhone) {
    return { success: false, error: 'Recipient phone number is missing or invalid' };
  }

  // 1. UltraMsg Provider
  if (provider === 'ultramsg') {
    const instanceId = (await SystemSetting.getSetting('notification.ultramsgInstanceId')) || process.env.WHATSAPP_INSTANCE_ID || process.env.ULTRAMSG_INSTANCE_ID;
    const token = (await SystemSetting.getSetting('notification.ultramsgToken')) || process.env.WHATSAPP_TOKEN || process.env.ULTRAMSG_TOKEN;

    if (!instanceId || !token) {
      console.warn('⚠️ UltraMsg instanceId or token is missing. Falling back to click-to-chat.');
      return { success: false, error: 'UltraMsg credentials not configured', fallbackUrl: getWhatsAppShareUrl(cleanPhone, message) };
    }

    try {
      const endpoint = `https://api.ultramsg.com/${instanceId}/messages/chat`;
      const params = new URLSearchParams();
      params.append('token', token);
      params.append('to', cleanPhone);
      params.append('body', message);

      const resp = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params
      });

      const data = await resp.json();
      console.log('✅ UltraMsg response:', data);
      return {
        success: data.sent === 'true' || Boolean(data.id),
        provider: 'ultramsg',
        messageId: data.id,
        data
      };
    } catch (err) {
      console.error('❌ UltraMsg dispatch error:', err.message);
      return { success: false, provider: 'ultramsg', error: err.message, fallbackUrl: getWhatsAppShareUrl(cleanPhone, message) };
    }
  }

  // 2. Fast2SMS Provider
  if (provider === 'fast2sms') {
    const apiKey = (await SystemSetting.getSetting('notification.fast2smsApiKey')) || process.env.FAST2SMS_API_KEY;
    if (!apiKey) {
      return { success: false, error: 'Fast2SMS API key not configured', fallbackUrl: getWhatsAppShareUrl(cleanPhone, message) };
    }

    try {
      const raw10 = cleanPhone.slice(-10);
      const resp = await fetch('https://www.fast2sms.com/dev/bulkV2', {
        method: 'POST',
        headers: {
          'authorization': apiKey,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          route: 'q',
          message: message,
          language: 'english',
          flash: 0,
          numbers: raw10
        })
      });
      const data = await resp.json();
      console.log('✅ Fast2SMS response:', data);
      return { success: data.return === true, provider: 'fast2sms', data };
    } catch (err) {
      console.error('❌ Fast2SMS dispatch error:', err.message);
      return { success: false, provider: 'fast2sms', error: err.message };
    }
  }

  // 3. Meta WhatsApp Cloud API
  if (provider === 'meta') {
    const phoneId = (await SystemSetting.getSetting('notification.metaPhoneNumberId')) || process.env.META_WA_PHONE_NUMBER_ID;
    const token = (await SystemSetting.getSetting('notification.metaAccessToken')) || process.env.META_WA_ACCESS_TOKEN;

    if (!phoneId || !token) {
      return { success: false, error: 'Meta WhatsApp credentials missing', fallbackUrl: getWhatsAppShareUrl(cleanPhone, message) };
    }

    try {
      const endpoint = `https://graph.facebook.com/v18.0/${phoneId}/messages`;
      const resp = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: cleanPhone,
          type: 'text',
          text: { preview_url: true, body: message }
        })
      });
      const data = await resp.json();
      console.log('✅ Meta WhatsApp API response:', data);
      return { success: !data.error, provider: 'meta', data };
    } catch (err) {
      console.error('❌ Meta WhatsApp API error:', err.message);
      return { success: false, provider: 'meta', error: err.message, fallbackUrl: getWhatsAppShareUrl(cleanPhone, message) };
    }
  }

  // 4. Custom Webhook
  if (provider === 'webhook') {
    const webhookUrl = (await SystemSetting.getSetting('notification.webhookUrl')) || process.env.WHATSAPP_WEBHOOK_URL;
    if (webhookUrl) {
      try {
        const resp = await fetch(webhookUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            phone: cleanPhone,
            message,
            type,
            timestamp: new Date().toISOString()
          })
        });
        const data = await resp.text();
        return { success: resp.ok, provider: 'webhook', status: resp.status, data };
      } catch (err) {
        console.error('❌ Webhook dispatch error:', err.message);
        return { success: false, provider: 'webhook', error: err.message };
      }
    }
  }

  // 5. Default: Direct Click-to-Chat Share URL
  const clickToChat = getWhatsAppShareUrl(cleanPhone, message);
  return {
    success: true,
    phone: cleanPhone,
    type,
    provider: 'click_to_chat',
    dispatchedAt: new Date().toISOString(),
    status: isEnabled ? 'ready_to_send' : 'disabled',
    whatsappUrl: clickToChat
  };
}

module.exports = {
  getWhatsAppShareUrl,
  formatPaymentReceiptMessage,
  formatExpiryReminderMessage,
  sendGatewayMessage
};
