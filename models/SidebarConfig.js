const mongoose = require('mongoose');

const sidebarItemSchema = new mongoose.Schema({
  key: { type: String, required: true },           // e.g., 'dashboard', 'students'
  label: { type: String, required: true },          // Display name
  icon: { type: String, default: '' },              // SVG path or emoji
  href: { type: String, required: true },           // e.g., '#/dashboard'
  isEnabled: { type: Boolean, default: true },
  order: { type: Number, default: 0 },
  isSystem: { type: Boolean, default: false },      // Can't delete, but can disable
  i18nKey: { type: String, default: '' }            // For internationalization
}, { _id: false });

const sidebarConfigSchema = new mongoose.Schema({
  items: [sidebarItemSchema]
}, { timestamps: true });

// Singleton
sidebarConfigSchema.statics.getConfig = async function() {
  let config = await this.findOne();
  if (!config) {
    config = await this.create({ items: this.getDefaults() });
  }
  return config;
};

sidebarConfigSchema.statics.getDefaults = function() {
  return [
    { key: 'dashboard', label: 'Dashboard', href: '#/dashboard', order: 1, isEnabled: true, isSystem: true, i18nKey: 'nav.dashboard' },
    { key: 'students', label: 'Students', href: '#/students', order: 2, isEnabled: true, isSystem: true, i18nKey: 'nav.students' },
    { key: 'seats', label: 'Centers & Seats', href: '#/seats', order: 3, isEnabled: true, isSystem: true, i18nKey: 'nav.seats' },
    { key: 'lockers', label: 'Lockers', href: '#/lockers', order: 4, isEnabled: true, isSystem: false, i18nKey: 'nav.lockers' },
    { key: 'plans', label: 'Plans', href: '#/plans', order: 5, isEnabled: true, isSystem: true, i18nKey: 'nav.plans' },
    { key: 'payments', label: 'Payments', href: '#/payments', order: 6, isEnabled: true, isSystem: true, i18nKey: 'nav.payments' },
    { key: 'attendance', label: 'Attendance', href: '#/attendance', order: 7, isEnabled: true, isSystem: false, i18nKey: 'nav.attendance' },
    { key: 'shifts', label: 'Shifts', href: '#/shifts', order: 8, isEnabled: true, isSystem: false, i18nKey: 'nav.shifts' },
    { key: 'reports', label: 'Reports', href: '#/reports', order: 9, isEnabled: true, isSystem: false, i18nKey: 'nav.reports' },
    { key: 'expenses', label: 'Expenses (P&L)', href: '#/expenses', order: 10, isEnabled: true, isSystem: false, i18nKey: 'nav.expenses' },
    { key: 'operations', label: 'Operations', href: '#/operations', order: 11, isEnabled: true, isSystem: false, i18nKey: 'nav.operations' },
    { key: 'settings', label: 'Settings', href: '#/settings', order: 12, isEnabled: true, isSystem: true, i18nKey: 'nav.settings' },
    { key: 'profile', label: 'My Profile', href: '#/profile', order: 13, isEnabled: true, isSystem: true, i18nKey: 'nav.profile' }
  ];
};

module.exports = mongoose.model('SidebarConfig', sidebarConfigSchema);
