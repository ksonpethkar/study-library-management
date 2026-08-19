const mongoose = require('mongoose');

const messageTemplateSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  triggerType: {
    type: String,
    enum: [
      'admission_welcome',
      'payment_receipt',
      'renewal_reminder',
      'balance_due',
      'attendance_punch',
      'welcome_admission', // backward compatibility alias
      'fee_due',           // backward compatibility alias
      'expiry_reminder_7d',
      'expiry_reminder_3d',
      'expiry_reminder_1d',
      'general_broadcast',
      'custom'
    ],
    default: 'custom'
  },
  channel: {
    type: String,
    enum: ['whatsapp', 'sms', 'email'],
    default: 'whatsapp'
  },
  templateText: {
    type: String,
    required: true
  },
  availableVariables: [{
    type: String
  }],
  isActive: {
    type: Boolean,
    default: true
  },
  branch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Branch',
    default: null
  }
}, {
  timestamps: true
});

const DEFAULT_TEMPLATES = [
  {
    title: 'Admission Welcome & Confirmation',
    triggerType: 'admission_welcome',
    channel: 'whatsapp',
    templateText: `🎉 *Welcome to {{businessName}}!*

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
    availableVariables: ['studentName', 'studentId', 'seatNumber', 'shiftName', 'planName', 'expiryDate', 'businessName', 'portalLink']
  },
  {
    title: 'Fee Payment Receipt Confirmation',
    triggerType: 'payment_receipt',
    channel: 'whatsapp',
    templateText: `🧾 *Payment Receipt Confirmation*
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
    availableVariables: ['studentName', 'studentId', 'receiptNumber', 'amount', 'balanceDue', 'paymentMethod', 'paymentDate', 'expiryDate', 'upiRef', 'businessName', 'portalLink']
  },
  {
    title: 'Subscription Renewal Reminder',
    triggerType: 'renewal_reminder',
    channel: 'whatsapp',
    templateText: `⏰ *Subscription Renewal Reminder*
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
    availableVariables: ['studentName', 'studentId', 'planName', 'seatNumber', 'shiftName', 'expiryDate', 'amount', 'upiLink', 'portalLink', 'businessName']
  },
  {
    title: 'Pending Fee Balance Due Notice',
    triggerType: 'balance_due',
    channel: 'whatsapp',
    templateText: `⚠️ *Fee Balance Due Reminder*
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
    availableVariables: ['studentName', 'studentId', 'seatNumber', 'shiftName', 'balanceDue', 'amount', 'upiLink', 'portalLink', 'businessName']
  },
  {
    title: 'Daily Attendance Alert',
    triggerType: 'attendance_punch',
    channel: 'whatsapp',
    templateText: `📚 *Daily Attendance Alert*
🏢 *{{businessName}}*

Dear *{{studentName}}* (ID: {{studentId}}),
Here is your attendance update:

⏱️ *Activity:* {{status}}
🕒 *Timestamp:* {{timestamp}}
💺 *Seat:* {{seatNumber}} | {{shiftName}}
⏳ *Hours Studied:* {{hoursStudied}}

Access your attendance logs & study hours on student portal:
🔗 {{portalLink}}

Have a productive study session! ✨`,
    availableVariables: ['studentName', 'studentId', 'status', 'timestamp', 'seatNumber', 'shiftName', 'hoursStudied', 'businessName', 'portalLink']
  }
];

// Seed standard templates
messageTemplateSchema.statics.seedDefaults = async function() {
  for (const t of DEFAULT_TEMPLATES) {
    const query = {
      $or: [
        { triggerType: t.triggerType },
        ...(t.triggerType === 'admission_welcome' ? [{ triggerType: 'welcome_admission' }] : []),
        ...(t.triggerType === 'balance_due' ? [{ triggerType: 'fee_due' }] : []),
        ...(t.triggerType === 'renewal_reminder' ? [{ triggerType: 'expiry_reminder_3d' }] : [])
      ]
    };
    const existing = await this.findOne(query);
    if (!existing) {
      await this.create(t);
    }
  }
};

messageTemplateSchema.statics.getDefaultTemplates = function() {
  return DEFAULT_TEMPLATES;
};

module.exports = mongoose.model('MessageTemplate', messageTemplateSchema);
