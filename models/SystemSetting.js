const mongoose = require('mongoose');

const systemSettingSchema = new mongoose.Schema({
  category: {
    type: String,
    required: true,
  },
  key: {
    type: String,
    required: true,
    unique: true,
  },
  value: {
    type: mongoose.Schema.Types.Mixed,
  },
  label: String,
  description: String,
  type: {
    type: String,
    enum: ['string', 'number', 'boolean', 'json', 'array'],
  },
  isEditable: {
    type: Boolean,
    default: true,
  }
}, { timestamps: true });

systemSettingSchema.statics.getSetting = async function(key) {
  const setting = await this.findOne({ key });
  return setting ? setting.value : null;
};

systemSettingSchema.statics.setSetting = async function(key, value) {
  return await this.findOneAndUpdate({ key }, { value }, { new: true });
};

systemSettingSchema.statics.getByCategory = async function(category) {
  return await this.find({ category });
};

systemSettingSchema.statics.initDefaults = async function() {
  const defaults = [
    { category: 'payment', key: 'payment.gracePeriod', value: 5, type: 'number', label: 'Grace Period (Days)' },
    { category: 'payment', key: 'payment.lateFeeType', value: 'flat', type: 'string', label: 'Late Fee Type' },
    { category: 'payment', key: 'payment.lateFeeAmount', value: 50, type: 'number', label: 'Late Fee Amount' },
    { category: 'payment', key: 'payment.autoSuspendDays', value: 15, type: 'number', label: 'Auto Suspend Days' },
    { category: 'admission', key: 'admission.autoApprove', value: false, type: 'boolean', label: 'Auto Approve Admissions' },
    { category: 'admission', key: 'admission.idPrefix', value: 'STU', type: 'string', label: 'Student ID Prefix' },
    { category: 'admission', key: 'admission.idFormat', value: 'prefix-year-serial', type: 'string', label: 'Student ID Format' },
    { category: 'notification', key: 'notification.paymentReminder', value: [7, 3, 1], type: 'array', label: 'Payment Reminders (Days before due)' },
    { category: 'notification', key: 'notification.expiryReminder', value: 7, type: 'number', label: 'Expiry Reminder (Days before)' },
    { category: 'notification', key: 'notification.enableWhatsapp', value: false, type: 'boolean', label: 'Enable WhatsApp Notifications' },
    { category: 'notification', key: 'notification.enableEmail', value: true, type: 'boolean', label: 'Enable Email Notifications' },
    { category: 'notification', key: 'notification.enableInApp', value: true, type: 'boolean', label: 'Enable In-App Notifications' },
    { category: 'general', key: 'general.currency', value: 'INR', type: 'string', label: 'Currency' },
    { category: 'general', key: 'general.currencySymbol', value: '₹', type: 'string', label: 'Currency Symbol' },
    { category: 'general', key: 'general.dateFormat', value: 'DD/MM/YYYY', type: 'string', label: 'Date Format' },
    { category: 'general', key: 'general.timezone', value: 'Asia/Kolkata', type: 'string', label: 'Timezone' },
    { category: 'general', key: 'general.autoBackup', value: true, type: 'boolean', label: 'Auto Backup' },
    { category: 'general', key: 'general.inactivityTimeout', value: 30, type: 'number', label: 'Inactivity Timeout (Minutes)' }
  ];

  for (const setting of defaults) {
    const exists = await this.findOne({ key: setting.key });
    if (!exists) {
      await this.create(setting);
    }
  }
};

module.exports = mongoose.model('SystemSetting', systemSettingSchema);
