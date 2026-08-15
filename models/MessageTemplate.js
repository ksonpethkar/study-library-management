const mongoose = require('mongoose');

const messageTemplateSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  triggerType: {
    type: String,
    enum: ['welcome_admission', 'payment_receipt', 'expiry_reminder_7d', 'expiry_reminder_3d', 'expiry_reminder_1d', 'fee_due', 'general_broadcast', 'custom'],
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

// Seed standard templates
messageTemplateSchema.statics.seedDefaults = async function() {
  const count = await this.countDocuments();
  if (count === 0) {
    const defaults = [
      {
        title: 'Welcome & Admission Confirmation',
        triggerType: 'welcome_admission',
        channel: 'whatsapp',
        templateText: 'Dear {student_name},\n\nWelcome to {library_name}! 🎉\nYour admission is confirmed:\n• Student ID: {student_id}\n• Seat No: {seat_no}\n• Plan: {plan_name}\n• Valid Until: {expiry_date}\n\nStudy hard and all the best for your exams!\n\nRegards,\n{library_name}',
        availableVariables: ['student_name', 'library_name', 'student_id', 'seat_no', 'plan_name', 'expiry_date']
      },
      {
        title: 'Fee Payment Receipt',
        triggerType: 'payment_receipt',
        channel: 'whatsapp',
        templateText: 'Hello {student_name},\n\nThank you for your payment! 🧾\n• Receipt No: {receipt_no}\n• Amount Paid: ₹{amount}\n• Date: {payment_date}\n• Valid Until: {expiry_date}\n\nHave a productive study session!\n\n{library_name}',
        availableVariables: ['student_name', 'library_name', 'receipt_no', 'amount', 'payment_date', 'expiry_date']
      },
      {
        title: 'Membership Expiry Reminder (3 Days)',
        triggerType: 'expiry_reminder_3d',
        channel: 'whatsapp',
        templateText: 'Hi {student_name},\n\nFriendly reminder from {library_name} ⏰\nYour study seat ({seat_no}) membership will expire in 3 days on {expiry_date}.\n\nRenew today to retain your preferred seat! Contact desk or pay online via UPI: {upi_id}\n\nThank you!',
        availableVariables: ['student_name', 'library_name', 'seat_no', 'expiry_date', 'upi_id']
      },
      {
        title: 'Pending Fee Due Alert',
        triggerType: 'fee_due',
        channel: 'whatsapp',
        templateText: 'Dear {student_name},\n\nThis is regarding pending fees of ₹{due_amount} for your library membership ({seat_no}).\nKindly clear the dues by {due_date} to avoid suspension.\n\nThank you,\n{library_name}',
        availableVariables: ['student_name', 'library_name', 'due_amount', 'seat_no', 'due_date']
      }
    ];
    await this.insertMany(defaults);
  }
};

module.exports = mongoose.model('MessageTemplate', messageTemplateSchema);
