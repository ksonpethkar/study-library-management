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

const DEFAULT_DASHBOARD_WIDGETS = [
  { id: 'kpi_active_students', label: 'Active Students', isEnabled: true, order: 1, category: 'kpi' },
  { id: 'kpi_available_seats', label: 'Available Seats & Live Occupancy', isEnabled: true, order: 2, category: 'kpi' },
  { id: 'kpi_today_revenue', label: "Today's Fee Collection", isEnabled: true, order: 3, category: 'kpi' },
  { id: 'kpi_expiring_soon', label: 'Expiring in 48 Hours', isEnabled: true, order: 4, category: 'kpi' },
  { id: 'kpi_defaulter_dues', label: 'Overdue Fee Balances', isEnabled: true, order: 5, category: 'kpi' },
  { id: 'kpi_total_seats', label: 'Total Seat Capacity', isEnabled: true, order: 6, category: 'kpi' },
  { id: 'chart_revenue_trend', label: 'Monthly Revenue Trend Chart', isEnabled: true, order: 7, category: 'chart' },
  { id: 'chart_shift_occupancy', label: 'Shift Occupancy Distribution Chart', isEnabled: true, order: 8, category: 'chart' },
  { id: 'chart_exam_stats', label: 'Student Exam Preparation Breakdown', isEnabled: true, order: 9, category: 'chart' },
  { id: 'quick_actions', label: 'Quick 1-Tap Action Toolbar', isEnabled: true, order: 10, category: 'action' }
];

systemSettingSchema.statics.getDefaultDashboardWidgets = function() {
  return JSON.parse(JSON.stringify(DEFAULT_DASHBOARD_WIDGETS));
};

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
    // Payment & Penalties
    { category: 'payment', key: 'payment.gracePeriod', value: 5, type: 'number', label: 'Payment Grace Period (Days)' },
    { category: 'payment', key: 'payment.lateFeeType', value: 'flat', type: 'string', label: 'Late Fee Type' },
    { category: 'payment', key: 'payment.lateFeeAmount', value: 50, type: 'number', label: 'Late Fee Amount' },
    { category: 'payment', key: 'payment.latePenalty', value: 50, type: 'number', label: 'Late Penalty' },
    { category: 'payment', key: 'payment.autoSuspendDays', value: 15, type: 'number', label: 'Auto Suspend Days' },
    
    // Library Operations
    { category: 'operations', key: 'operations.gracePeriodMinutes', value: 15, type: 'number', label: 'Attendance Check-in Grace Period (Minutes)' },
    { category: 'operations', key: 'operations.autoCheckout', value: true, type: 'boolean', label: 'Enable Auto Checkout' },
    { category: 'operations', key: 'operations.autoCheckoutHours', value: 16, type: 'number', label: 'Auto Checkout Duration (Hours)' },
    { category: 'operations', key: 'operations.autoCheckoutTime', value: '23:00', type: 'string', label: 'Daily Auto Checkout Time' },
    { category: 'operations', key: 'operations.latePenaltyPerHour', value: 10, type: 'number', label: 'Overstay Penalty Per Hour (₹)' },
    { category: 'operations', key: 'operations.requireBiometricForEntry', value: false, type: 'boolean', label: 'Require Biometric Verification' },
    
    // Kiosk & Gate Scanner Settings
    { category: 'kiosk', key: 'kiosk.enableVoice', value: true, type: 'boolean', label: 'Enable Kiosk Voice Audio Announcements' },
    { category: 'kiosk', key: 'kiosk.voiceLanguage', value: 'en-IN', type: 'string', label: 'Voice Audio Language' },
    { category: 'kiosk', key: 'kiosk.soundEnabled', value: true, type: 'boolean', label: 'Enable Kiosk Sound Effects' },
    { category: 'kiosk', key: 'kiosk.autoCheckout', value: true, type: 'boolean', label: 'Kiosk Auto Checkout Enabled' },
    { category: 'kiosk', key: 'kiosk.autoCheckoutHours', value: 16, type: 'number', label: 'Kiosk Auto Checkout Hours' },
    { category: 'kiosk', key: 'kiosk.screenTimeoutSeconds', value: 10, type: 'number', label: 'Kiosk Screen Timeout (Seconds)' },
    { category: 'kiosk', key: 'kiosk.announcementVolume', value: 80, type: 'number', label: 'Voice Audio Volume (0-100)' },
    { category: 'kiosk', key: 'kiosk.welcomeMessage', value: 'Welcome to Study Library. Have a productive study session!', type: 'string', label: 'Kiosk Welcome Audio Message' },
    { category: 'kiosk', key: 'kiosk.farewellMessage', value: 'Thank you for visiting. See you again tomorrow!', type: 'string', label: 'Kiosk Checkout Audio Message' },
    
    // Admission Settings
    { category: 'admission', key: 'admission.autoApprove', value: false, type: 'boolean', label: 'Auto Approve Admissions' },
    { category: 'admission', key: 'admission.idPrefix', value: 'STU', type: 'string', label: 'Student ID Prefix' },
    { category: 'admission', key: 'admission.idFormat', value: 'prefix-year-serial', type: 'string', label: 'Student ID Format' },
    { category: 'admission', key: 'admission.serialDigits', value: 3, type: 'number', label: 'Student ID Serial Digits' },
    { category: 'admission', key: 'admission.startingSerial', value: 1, type: 'number', label: 'Student ID Starting Serial' },
    { category: 'admission', key: 'admission.currentSerial', value: 1, type: 'number', label: 'Student ID Current Serial' },
    
    // Notifications
    { category: 'notification', key: 'notification.paymentReminder', value: [7, 3, 1], type: 'array', label: 'Payment Reminders (Days before due)' },
    { category: 'notification', key: 'notification.expiryReminder', value: 7, type: 'number', label: 'Expiry Reminder (Days before)' },
    { category: 'notification', key: 'notification.enableWhatsapp', value: false, type: 'boolean', label: 'Enable WhatsApp Notifications' },
    { category: 'notification', key: 'notification.enableEmail', value: true, type: 'boolean', label: 'Enable Email Notifications' },
    { category: 'notification', key: 'notification.enableInApp', value: true, type: 'boolean', label: 'Enable In-App Notifications' },
    { category: 'notification', key: 'notification.whatsappScheduleTime', value: '09:30', type: 'string', label: 'Automated WhatsApp Dispatch Time' },
    { category: 'notification', key: 'notification.expiryReminderDays', value: [7, 3, 1, 0], type: 'array', label: 'Expiry Reminder Days Intervals' },
    { category: 'notification', key: 'notification.balanceReminderDays', value: [7, 3, 1], type: 'array', label: 'Overdue Balance Reminder Days Intervals' },
    { category: 'notification', key: 'notification.enableAutoExpiryBot', value: true, type: 'boolean', label: 'Enable Automated Expiry WhatsApp Bot' },
    { category: 'notification', key: 'notification.enableAutoDuesBot', value: true, type: 'boolean', label: 'Enable Automated Balance Due WhatsApp Bot' },
    { category: 'notification', key: 'notification.enableConversationalBot', value: true, type: 'boolean', label: 'Enable Interactive WhatsApp Conversational Bot' },

    
    // Portal Feature Matrix
    { category: 'portal', key: 'portal.enableOnlineRenewal', value: true, type: 'boolean', label: 'Enable Student Portal Online Fee Renewal' },
    { category: 'portal', key: 'portal.enableSeatTransfer', value: true, type: 'boolean', label: 'Enable Student Seat Transfer Requests' },
    { category: 'portal', key: 'portal.enableShiftSwitch', value: true, type: 'boolean', label: 'Enable Student Shift Switch Requests' },
    { category: 'portal', key: 'portal.enableIdPassDownload', value: true, type: 'boolean', label: 'Enable Digital Mobile ID Pass Download' },
    { category: 'portal', key: 'portal.enableReceiptDownload', value: true, type: 'boolean', label: 'Enable Fee Receipt PDF Download' },
    { category: 'portal', key: 'portal.enableProfileEdit', value: true, type: 'boolean', label: 'Enable Student Profile & KYC Self-Edit' },
    { category: 'portal', key: 'portal.enableWebAuthn', value: true, type: 'boolean', label: 'Enable One-Touch Biometric Login' },
    { category: 'portal', key: 'portal.enableGamifiedBadges', value: true, type: 'boolean', label: 'Enable Gamified Badges & Study Streak' },
    { category: 'portal', key: 'portal.enableReferralProgram', value: true, type: 'boolean', label: 'Enable Student Referral Program & Wallet' },
    { category: 'portal', key: 'portal.enableAttendanceLogs', value: true, type: 'boolean', label: 'Enable 30-Day AI Study Heatmap' },
    { category: 'portal', key: 'portal.enableAnnouncements', value: true, type: 'boolean', label: 'Enable Notice Board & Announcements' },
    { category: 'portal', key: 'portal.enableLockerRequests', value: true, type: 'boolean', label: 'Enable Locker Allotment Requests' },

    // Automations
    { category: 'automations', key: 'automations.autoSeatExpiry', value: true, type: 'boolean', label: 'Auto Release Expired Seats' },
    { category: 'automations', key: 'automations.autoDueReminders', value: true, type: 'boolean', label: 'Auto Dispatch Balance Due Reminders' },
    { category: 'automations', key: 'automations.autoReceiptGeneration', value: true, type: 'boolean', label: 'Auto Generate & Send PDF Receipts' },
    { category: 'automations', key: 'automations.autoDailyBackup', value: true, type: 'boolean', label: 'Daily Automated Cloud Database Snapshots' },

    // Billing & Invoicing
    { category: 'billing', key: 'billing.receiptPrefix', value: 'LIB-2026', type: 'string', label: 'Invoice / Receipt Prefix' },
    { category: 'billing', key: 'billing.nextReceiptNumber', value: 1001, type: 'number', label: 'Starting Invoice Number' },
    { category: 'billing', key: 'billing.enableGst', value: false, type: 'boolean', label: 'Enable GST Tax on Invoices' },
    { category: 'billing', key: 'billing.gstRate', value: 18, type: 'number', label: 'Standard GST Percentage (%)' },
    { category: 'billing', key: 'billing.hsnSacCode', value: '999293', type: 'string', label: 'HSN / SAC Code' },
    { category: 'billing', key: 'billing.allowPartialPayment', value: true, type: 'boolean', label: 'Allow Partial / Split Payments' },
    { category: 'billing', key: 'billing.minPartialPercent', value: 50, type: 'number', label: 'Minimum Partial Payment (%)' },
    { category: 'billing', key: 'billing.refundPolicyDays', value: 3, type: 'number', label: 'Refund Guarantee Window (Days)' },

    // Extended Library Operations
    { category: 'operations', key: 'operations.openingTime', value: '06:00', type: 'string', label: 'Daily Opening Time' },
    { category: 'operations', key: 'operations.closingTime', value: '23:00', type: 'string', label: 'Daily Closing Time' },
    { category: 'operations', key: 'operations.weeklyOff', value: 'none', type: 'string', label: 'Weekly Off Day' },
    { category: 'operations', key: 'operations.examExtendedHours', value: false, type: 'boolean', label: 'Enable 24x7 Exam Season Hours' },
    { category: 'operations', key: 'operations.emergencyNotice', value: '', type: 'string', label: 'Emergency Closure Broadcast Message' },
    { category: 'operations', key: 'operations.emergencyNoticeEnabled', value: false, type: 'boolean', label: 'Enable Emergency Banner Broadcast' },

    // General Settings
    { category: 'general', key: 'general.currency', value: 'INR', type: 'string', label: 'Currency' },
    { category: 'general', key: 'general.currencySymbol', value: '₹', type: 'string', label: 'Currency Symbol' },
    { category: 'general', key: 'general.dateFormat', value: 'DD/MM/YYYY', type: 'string', label: 'Date Format' },
    { category: 'general', key: 'general.timezone', value: 'Asia/Kolkata', type: 'string', label: 'Timezone' },
    { category: 'general', key: 'general.autoBackup', value: true, type: 'boolean', label: 'Auto Backup' },
    { category: 'general', key: 'general.inactivityTimeout', value: 30, type: 'number', label: 'Inactivity Timeout (Minutes)' },

    // Dashboard Widget Configurations
    { category: 'dashboard', key: 'dashboard.widgetConfig', value: DEFAULT_DASHBOARD_WIDGETS, type: 'array', label: 'Dashboard Widget Configuration' }
  ];

  for (const setting of defaults) {
    const exists = await this.findOne({ key: setting.key });
    if (!exists) {
      await this.create(setting);
    }
  }
};

module.exports = mongoose.model('SystemSetting', systemSettingSchema);
