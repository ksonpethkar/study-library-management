const mongoose = require('mongoose');

const sidebarItemSchema = new mongoose.Schema({
  key: { type: String, required: true },           // e.g., 'dashboard', 'students'
  label: { type: String, required: true },          // Display name
  href: { type: String, required: true },           // e.g., '#/dashboard'
  icon: { type: String, default: '' },              // SVG path or emoji
  isEnabled: { type: Boolean, default: true },
  order: { type: Number, default: 0 },
  allowedRoles: { 
    type: [String], 
    default: ['owner', 'branch_manager', 'staff'] 
  },
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
  } else {
    // Ensure all items have allowedRoles and icon populated if missing
    let modified = false;
    const defaults = this.getDefaults();
    const defaultMap = new Map(defaults.map(d => [d.key, d]));

    config.items.forEach(item => {
      if (!item.allowedRoles || item.allowedRoles.length === 0) {
        const def = defaultMap.get(item.key);
        item.allowedRoles = def ? def.allowedRoles : ['owner', 'branch_manager', 'staff'];
        modified = true;
      }
      if (!item.icon && defaultMap.has(item.key)) {
        item.icon = defaultMap.get(item.key).icon || '';
        modified = true;
      }
    });

    if (modified) {
      await config.save();
    }
  }
  return config;
};

sidebarConfigSchema.statics.getDefaults = function() {
  return [
    { key: 'dashboard', label: 'Dashboard', href: '#/dashboard', icon: '📊', order: 1, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: true, i18nKey: 'nav.dashboard' },
    { key: 'students', label: 'Students', href: '#/students', icon: '👥', order: 2, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: true, i18nKey: 'nav.students' },
    { key: 'seats', label: 'Centers & Seats', href: '#/seats', icon: '🪑', order: 3, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: true, i18nKey: 'nav.seats' },
    { key: 'lockers', label: 'Lockers', href: '#/lockers', icon: '🔒', order: 4, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: false, i18nKey: 'nav.lockers' },
    { key: 'plans', label: 'Plans', href: '#/plans', icon: '🏷️', order: 5, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: true, i18nKey: 'nav.plans' },
    { key: 'payments', label: 'Payments', href: '#/payments', icon: '💳', order: 6, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: true, i18nKey: 'nav.payments' },
    { key: 'attendance', label: 'Attendance', href: '#/attendance', icon: '📋', order: 7, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: false, i18nKey: 'nav.attendance' },
    { key: 'shifts', label: 'Shifts', href: '#/shifts', icon: '⏱️', order: 8, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: false, i18nKey: 'nav.shifts' },
    { key: 'reports', label: 'Reports', href: '#/reports', icon: '📈', order: 9, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: false, i18nKey: 'nav.reports' },
    { key: 'expenses', label: 'Expenses (P&L)', href: '#/expenses', icon: '💰', order: 10, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: false, i18nKey: 'nav.expenses' },
    { key: 'operations', label: 'Operations', href: '#/operations', icon: '⚙️', order: 11, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: false, i18nKey: 'nav.operations' },
    { key: 'settings', label: 'Settings', href: '#/settings', icon: '🛠️', order: 12, isEnabled: true, allowedRoles: ['owner', 'branch_manager'], isSystem: true, i18nKey: 'nav.settings' },
    { key: 'profile', label: 'My Profile', href: '#/profile', icon: '👤', order: 13, isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'], isSystem: true, i18nKey: 'nav.profile' }
  ];
};

module.exports = mongoose.model('SidebarConfig', sidebarConfigSchema);
