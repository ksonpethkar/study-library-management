const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { protect, optionalAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const BusinessProfile = require('../models/BusinessProfile');
const SystemSetting = require('../models/SystemSetting');
const User = require('../models/User');
const ReceiptConfig = require('../models/ReceiptConfig');
const SidebarConfig = require('../models/SidebarConfig');

const roleCheck = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Not authorized for this role' });
    }
    next();
  };
};

// GET /api/settings/sidebar - Get sidebar config filtered by role and enabled status
router.get('/sidebar', optionalAuth, async (req, res) => {
  try {
    const config = await SidebarConfig.getConfig();
    const userRole = req.user?.role;

    const visibleItems = config.items
      .filter(item => {
        if (item.isEnabled === false) return false;
        if (!userRole) return true;
        if (!item.allowedRoles || item.allowedRoles.length === 0) return true;
        return item.allowedRoles.includes(userRole);
      })
      .sort((a, b) => (a.order || 0) - (b.order || 0));

    res.json({ success: true, data: visibleItems });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Protect all following routes
router.use(protect);

/**
 * @route   GET /api/settings
 * @desc    Get business profile and all system settings categorized
 * @access  Private (Admin / Owner / Manager)
 */
router.get('/', roleCheck('owner', 'branch_manager', 'staff'), async (req, res) => {
  try {
    const businessProfile = await BusinessProfile.getProfile();
    
    // Ensure default settings exist
    let allSettings = await SystemSetting.find().lean();
    if (!allSettings || allSettings.length === 0) {
      await SystemSetting.initDefaults();
      allSettings = await SystemSetting.find().lean();
    }

    const categorized = {
      general: {},
      payment: {},
      admission: {},
      notification: {}
    };

    allSettings.forEach(s => {
      const cat = s.category || 'general';
      if (!categorized[cat]) {
        categorized[cat] = {};
      }
      const shortKey = s.key.includes('.') ? s.key.split('.').slice(1).join('.') : s.key;
      categorized[cat][shortKey] = s.value;
      categorized[cat][s.key] = s.value;
    });

    res.json({
      success: true,
      data: {
        businessProfile,
        systemSettings: categorized,
        rawSettings: allSettings
      },
      message: 'Settings retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   PUT /api/settings/business-profile
 * @desc    Update library business profile
 * @access  Private
 */
const validateBusinessProfile = validate([
  body('businessName').optional().trim().notEmpty().withMessage('Business name cannot be empty'),
  body('email').optional({ checkFalsy: true }).isEmail().withMessage('Please provide a valid email address'),
  body('phone').optional().trim(),
  body('website').optional().trim(),
  body('address').optional().trim(),
  body('city').optional().trim(),
  body('state').optional().trim(),
  body('pincode').optional().trim(),
  body('tagline').optional().trim(),
  body('gstNumber').optional().trim(),
  body('registrationNumber').optional().trim(),
  body('upiQrCode').optional().trim(),
  body('stampImage').optional().trim(),
  body('logo').optional().trim(),
  body('favicon').optional().trim()
]);

router.put('/business-profile', roleCheck('owner'), validateBusinessProfile, async (req, res) => {
  try {
    const profile = await BusinessProfile.getProfile();
    const fields = [
      'businessName', 'tagline', 'logo', 'favicon', 'address', 'city', 'state', 'pincode',
      'phone', 'email', 'website', 'gstNumber', 'registrationNumber', 'upiQrCode', 'upiId',
      'paymentInstructions', 'enableUpiDeepLinks', 'stampImage',
      'gatewayProvider', 'razorpayKeyId', 'razorpaySecret', 'razorpayWebhookSecret',
      'cashfreeAppId', 'cashfreeSecret', 'phonepeMerchantId', 'phonepeSaltKey',
      'enableAutoWebhookVerification'
    ];

    fields.forEach(field => {
      if (req.body[field] !== undefined) {
        profile[field] = req.body[field];
      }
    });

    if (req.body.bankDetails && typeof req.body.bankDetails === 'object') {
      profile.bankDetails = {
        accountName: req.body.bankDetails.accountName !== undefined ? req.body.bankDetails.accountName : profile.bankDetails?.accountName,
        accountNumber: req.body.bankDetails.accountNumber !== undefined ? req.body.bankDetails.accountNumber : profile.bankDetails?.accountNumber,
        ifscCode: req.body.bankDetails.ifscCode !== undefined ? req.body.bankDetails.ifscCode : profile.bankDetails?.ifscCode,
        bankName: req.body.bankDetails.bankName !== undefined ? req.body.bankDetails.bankName : profile.bankDetails?.bankName,
        branchName: req.body.bankDetails.branchName !== undefined ? req.body.bankDetails.branchName : profile.bankDetails?.branchName
      };
    }

    if (Array.isArray(req.body.paymentMethods)) {
      profile.paymentMethods = req.body.paymentMethods.map((m, idx) => ({
        key: m.key || `custom_${idx}`,
        name: m.name || 'Payment Method',
        subtitle: m.subtitle || '',
        icon: m.icon || '💳',
        enabled: m.enabled !== undefined ? Boolean(m.enabled) : true,
        order: m.order !== undefined ? Number(m.order) : idx + 1,
        instructions: m.instructions || '',
        requiresRef: m.requiresRef !== undefined ? Boolean(m.requiresRef) : true,
        refLabel: m.refLabel || 'Transaction Reference / UTR *'
      }));
    }

    if (req.body.socialLinks && typeof req.body.socialLinks === 'object') {
      profile.socialLinks = {
        facebook: req.body.socialLinks.facebook !== undefined ? req.body.socialLinks.facebook : profile.socialLinks?.facebook,
        instagram: req.body.socialLinks.instagram !== undefined ? req.body.socialLinks.instagram : profile.socialLinks?.instagram,
        whatsapp: req.body.socialLinks.whatsapp !== undefined ? req.body.socialLinks.whatsapp : profile.socialLinks?.whatsapp
      };
    }

    profile.isSetupComplete = true;
    await profile.save();

    res.json({
      success: true,
      data: profile,
      message: 'Business profile updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   PUT /api/settings / PUT /api/settings/system-settings
 * @desc    Update operational and notification settings
 * @access  Private (Owner)
 */
const updateSystemSettingsHandler = async (req, res) => {
  try {
    const updates = req.body;
    if (!updates || typeof updates !== 'object') {
      return res.status(400).json({ success: false, message: 'Invalid settings payload' });
    }

    const keyDefinitions = {
      // Payment Settings
      'gracePeriod': { key: 'payment.gracePeriod', category: 'payment', type: 'number', label: 'Grace Period (Days)' },
      'payment.gracePeriod': { key: 'payment.gracePeriod', category: 'payment', type: 'number', label: 'Grace Period (Days)' },
      'lateFeeType': { key: 'payment.lateFeeType', category: 'payment', type: 'string', label: 'Late Fee Type' },
      'payment.lateFeeType': { key: 'payment.lateFeeType', category: 'payment', type: 'string', label: 'Late Fee Type' },
      'lateFeeAmount': { key: 'payment.lateFeeAmount', category: 'payment', type: 'number', label: 'Late Fee Amount' },
      'payment.lateFeeAmount': { key: 'payment.lateFeeAmount', category: 'payment', type: 'number', label: 'Late Fee Amount' },
      'autoSuspendDays': { key: 'payment.autoSuspendDays', category: 'payment', type: 'number', label: 'Auto Suspend Days' },
      'payment.autoSuspendDays': { key: 'payment.autoSuspendDays', category: 'payment', type: 'number', label: 'Auto Suspend Days' },

      // Admission Settings
      'autoApprove': { key: 'admission.autoApprove', category: 'admission', type: 'boolean', label: 'Auto Approve Admissions' },
      'admission.autoApprove': { key: 'admission.autoApprove', category: 'admission', type: 'boolean', label: 'Auto Approve Admissions' },
      'idPrefix': { key: 'admission.idPrefix', category: 'admission', type: 'string', label: 'Student ID Prefix' },
      'admission.idPrefix': { key: 'admission.idPrefix', category: 'admission', type: 'string', label: 'Student ID Prefix' },
      'idFormat': { key: 'admission.idFormat', category: 'admission', type: 'string', label: 'Student ID Format' },
      'admission.idFormat': { key: 'admission.idFormat', category: 'admission', type: 'string', label: 'Student ID Format' },
      'serialDigits': { key: 'admission.serialDigits', category: 'admission', type: 'number', label: 'Student ID Serial Digits' },
      'admission.serialDigits': { key: 'admission.serialDigits', category: 'admission', type: 'number', label: 'Student ID Serial Digits' },
      'startingSerial': { key: 'admission.startingSerial', category: 'admission', type: 'number', label: 'Student ID Starting Serial' },
      'admission.startingSerial': { key: 'admission.startingSerial', category: 'admission', type: 'number', label: 'Student ID Starting Serial' },
      'currentSerial': { key: 'admission.currentSerial', category: 'admission', type: 'number', label: 'Student ID Current Serial' },
      'admission.currentSerial': { key: 'admission.currentSerial', category: 'admission', type: 'number', label: 'Student ID Current Serial' },

      // Notification Settings
      'paymentReminder': { key: 'notification.paymentReminder', category: 'notification', type: 'array', label: 'Payment Reminders' },
      'paymentReminderDays': { key: 'notification.paymentReminder', category: 'notification', type: 'array', label: 'Payment Reminders' },
      'notification.paymentReminder': { key: 'notification.paymentReminder', category: 'notification', type: 'array', label: 'Payment Reminders' },
      'expiryReminder': { key: 'notification.expiryReminder', category: 'notification', type: 'number', label: 'Expiry Reminder (Days)' },
      'notification.expiryReminder': { key: 'notification.expiryReminder', category: 'notification', type: 'number', label: 'Expiry Reminder (Days)' },
      'enableWhatsapp': { key: 'notification.enableWhatsapp', category: 'notification', type: 'boolean', label: 'Enable WhatsApp' },
      'notification.enableWhatsapp': { key: 'notification.enableWhatsapp', category: 'notification', type: 'boolean', label: 'Enable WhatsApp' },
      'enableEmail': { key: 'notification.enableEmail', category: 'notification', type: 'boolean', label: 'Enable Email' },
      'notification.enableEmail': { key: 'notification.enableEmail', category: 'notification', type: 'boolean', label: 'Enable Email' },
      'enableInApp': { key: 'notification.enableInApp', category: 'notification', type: 'boolean', label: 'Enable In-App Notifications' },
      'notification.enableInApp': { key: 'notification.enableInApp', category: 'notification', type: 'boolean', label: 'Enable In-App Notifications' },
      'whatsappScheduleTime': { key: 'notification.whatsappScheduleTime', category: 'notification', type: 'string', label: 'WhatsApp Schedule Time' },
      'notification.whatsappScheduleTime': { key: 'notification.whatsappScheduleTime', category: 'notification', type: 'string', label: 'WhatsApp Schedule Time' },
      'expiryReminderDays': { key: 'notification.expiryReminderDays', category: 'notification', type: 'array', label: 'Expiry Reminder Days Intervals' },
      'notification.expiryReminderDays': { key: 'notification.expiryReminderDays', category: 'notification', type: 'array', label: 'Expiry Reminder Days Intervals' },
      'balanceReminderDays': { key: 'notification.balanceReminderDays', category: 'notification', type: 'array', label: 'Overdue Balance Reminder Days Intervals' },
      'notification.balanceReminderDays': { key: 'notification.balanceReminderDays', category: 'notification', type: 'array', label: 'Overdue Balance Reminder Days Intervals' },
      'enableAutoExpiryBot': { key: 'notification.enableAutoExpiryBot', category: 'notification', type: 'boolean', label: 'Enable Automated Expiry WhatsApp Bot' },
      'notification.enableAutoExpiryBot': { key: 'notification.enableAutoExpiryBot', category: 'notification', type: 'boolean', label: 'Enable Automated Expiry WhatsApp Bot' },
      'enableAutoDuesBot': { key: 'notification.enableAutoDuesBot', category: 'notification', type: 'boolean', label: 'Enable Automated Balance Due WhatsApp Bot' },
      'notification.enableAutoDuesBot': { key: 'notification.enableAutoDuesBot', category: 'notification', type: 'boolean', label: 'Enable Automated Balance Due WhatsApp Bot' },
      'enableConversationalBot': { key: 'notification.enableConversationalBot', category: 'notification', type: 'boolean', label: 'Enable Interactive WhatsApp Conversational Bot' },
      'notification.enableConversationalBot': { key: 'notification.enableConversationalBot', category: 'notification', type: 'boolean', label: 'Enable Interactive WhatsApp Conversational Bot' },


      // General Settings
      'currency': { key: 'general.currency', category: 'general', type: 'string', label: 'Currency' },
      'general.currency': { key: 'general.currency', category: 'general', type: 'string', label: 'Currency' },
      'currencySymbol': { key: 'general.currencySymbol', category: 'general', type: 'string', label: 'Currency Symbol' },
      'general.currencySymbol': { key: 'general.currencySymbol', category: 'general', type: 'string', label: 'Currency Symbol' },
      'dateFormat': { key: 'general.dateFormat', category: 'general', type: 'string', label: 'Date Format' },
      'general.dateFormat': { key: 'general.dateFormat', category: 'general', type: 'string', label: 'Date Format' },
      'timezone': { key: 'general.timezone', category: 'general', type: 'string', label: 'Timezone' },
      'general.timezone': { key: 'general.timezone', category: 'general', type: 'string', label: 'Timezone' },
      'autoBackup': { key: 'general.autoBackup', category: 'general', type: 'boolean', label: 'Auto Backup' },
      'general.autoBackup': { key: 'general.autoBackup', category: 'general', type: 'boolean', label: 'Auto Backup' },
      'inactivityTimeout': { key: 'general.inactivityTimeout', category: 'general', type: 'number', label: 'Inactivity Timeout' },
      'general.inactivityTimeout': { key: 'general.inactivityTimeout', category: 'general', type: 'number', label: 'Inactivity Timeout' }
    };

    // Flatten categorized nested objects
    const flatUpdates = {};
    for (const [k, v] of Object.entries(updates)) {
      if (typeof v === 'object' && v !== null && !Array.isArray(v) && ['general', 'payment', 'admission', 'notification'].includes(k)) {
        for (const [subK, subV] of Object.entries(v)) {
          flatUpdates[`${k}.${subK}`] = subV;
        }
      } else {
        flatUpdates[k] = v;
      }
    }

    for (const [key, value] of Object.entries(flatUpdates)) {
      const def = keyDefinitions[key];
      const targetKey = def ? def.key : key;
      const category = def ? def.category : (targetKey.includes('.') ? targetKey.split('.')[0] : 'general');
      const label = def ? def.label : targetKey;
      let targetType = def ? def.type : (Array.isArray(value) ? 'array' : typeof value);

      let parsedValue = value;
      if (targetType === 'number') {
        parsedValue = Number(value);
      } else if (targetType === 'boolean') {
        parsedValue = value === true || value === 'true' || value === 1 || value === '1';
      } else if (targetType === 'array') {
        if (Array.isArray(value)) {
          parsedValue = value.map(n => Number(n)).filter(n => !isNaN(n));
        } else if (typeof value === 'string') {
          try {
            parsedValue = JSON.parse(value);
            if (Array.isArray(parsedValue)) {
              parsedValue = parsedValue.map(n => Number(n)).filter(n => !isNaN(n));
            }
          } catch {
            parsedValue = value.split(',').map(s => Number(s.trim())).filter(n => !isNaN(n));
          }
        }
      }

      await SystemSetting.findOneAndUpdate(
        { key: targetKey },
        {
          category,
          key: targetKey,
          value: parsedValue,
          label,
          type: targetType,
          isEditable: true
        },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
    }

    // Return updated categorized settings
    const allSettings = await SystemSetting.find().lean();
    const categorized = {
      general: {},
      payment: {},
      admission: {},
      notification: {}
    };

    allSettings.forEach(s => {
      const cat = s.category || 'general';
      if (!categorized[cat]) {
        categorized[cat] = {};
      }
      const shortKey = s.key.includes('.') ? s.key.split('.').slice(1).join('.') : s.key;
      categorized[cat][shortKey] = s.value;
      categorized[cat][s.key] = s.value;
    });

    res.json({
      success: true,
      data: categorized,
      message: 'System settings updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

router.put('/system-settings', roleCheck('owner'), updateSystemSettingsHandler);
router.put('/', roleCheck('owner'), updateSystemSettingsHandler);

/**
 * @route   PUT /api/settings/admin-profile
 * @desc    Update current admin user name, email, phone, avatar
 * @access  Private
 */
const validateAdminProfile = validate([
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty'),
  body('email').optional().isEmail().withMessage('Valid email is required').normalizeEmail(),
  body('phone').optional().trim(),
  body('avatar').optional().trim()
]);

router.put('/admin-profile', validateAdminProfile, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const { name, email, phone, avatar } = req.body;

    if (email && email !== user.email) {
      const existingUser = await User.findOne({ email, _id: { $ne: req.user.id } }).lean();
      if (existingUser) {
        return res.status(400).json({ success: false, message: 'Email is already in use by another account' });
      }
      user.email = email;
    }

    if (name !== undefined) user.name = name;
    if (phone !== undefined) user.phone = phone;
    if (avatar !== undefined) {
      user.avatar = avatar;
      try {
        const Student = require('../models/Student');
        await Student.updateMany(
          { $or: [{ user: user._id }, { email: user.email }, { phone: user.phone }] },
          { $set: { photo: avatar } }
        );
      } catch (e) {
        console.warn('Could not sync student photo:', e);
      }
    }

    await user.save({ validateBeforeSave: false });

    res.json({
      success: true,
      data: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        avatar: user.avatar,
        lastLogin: user.lastLogin,
        updatedAt: user.updatedAt
      },
      message: 'Admin profile updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   POST /api/settings/change-password
 * @desc    Update admin user password (currentPassword, newPassword)
 * @access  Private
 */
const validatePasswordUpdate = validate([
  body('currentPassword').notEmpty().withMessage('Current password is required'),
  body('newPassword').isLength({ min: 6 }).withMessage('New password must be at least 6 characters')
]);

router.post('/change-password', validatePasswordUpdate, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = await User.findById(req.user.id).select('+password');
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(400).json({ success: false, message: 'Incorrect current password' });
    }

    user.password = newPassword;
    await user.save();

    res.json({
      success: true,
      data: {},
      message: 'Password changed successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   GET /api/settings/backup
 * @desc    Generate and download full JSON database backup
 * @access  Private (Owner / Super Admin)
 */
router.get('/backup', roleCheck('owner'), async (req, res) => {
  try {
    const Student = require('../models/Student');
    const Seat = require('../models/Seat');
    const Plan = require('../models/Plan');
    const Payment = require('../models/Payment');
    const Attendance = require('../models/Attendance');
    const Shift = require('../models/Shift');
    const Branch = require('../models/Branch');

    const [students, seats, plans, payments, attendance, shifts, branches, businessProfile, settings] = await Promise.all([
      Student.find().lean(),
      Seat.find().lean(),
      Plan.find().lean(),
      Payment.find().lean(),
      Attendance.find().lean(),
      Shift.find().lean(),
      Branch.find().lean(),
      BusinessProfile.findOne().lean(),
      SystemSetting.find().lean()
    ]);

    const backupData = {
      version: '1.0.0',
      exportedAt: new Date().toISOString(),
      system: 'Study Library Management System',
      data: {
        students,
        seats,
        plans,
        payments,
        attendance,
        shifts,
        branches,
        businessProfile,
        settings
      }
    };

    const filename = `studylib_backup_${new Date().toISOString().split('T')[0]}.json`;
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(JSON.stringify(backupData, null, 2));
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   POST /api/settings/restore
 * @desc    Restore database from JSON backup payload
 * @access  Private (Owner / Super Admin)
 */
router.post('/restore', roleCheck('owner'), async (req, res) => {
  try {
    const { data } = req.body;
    if (!data) {
      return res.status(400).json({ success: false, message: 'Invalid backup file format' });
    }

    const Student = require('../models/Student');
    const Seat = require('../models/Seat');
    const Plan = require('../models/Plan');
    const Payment = require('../models/Payment');
    const Shift = require('../models/Shift');
    const Branch = require('../models/Branch');

    let restoredCounts = { students: 0, seats: 0, plans: 0, payments: 0, shifts: 0, branches: 0 };

    if (Array.isArray(data.plans) && data.plans.length > 0) {
      for (const p of data.plans) {
        await Plan.findByIdAndUpdate(p._id, p, { upsert: true });
        restoredCounts.plans++;
      }
    }

    if (Array.isArray(data.seats) && data.seats.length > 0) {
      for (const s of data.seats) {
        await Seat.findByIdAndUpdate(s._id, s, { upsert: true });
        restoredCounts.seats++;
      }
    }

    if (Array.isArray(data.shifts) && data.shifts.length > 0) {
      for (const sh of data.shifts) {
        await Shift.findByIdAndUpdate(sh._id, sh, { upsert: true });
        restoredCounts.shifts++;
      }
    }

    if (Array.isArray(data.branches) && data.branches.length > 0) {
      for (const b of data.branches) {
        await Branch.findByIdAndUpdate(b._id, b, { upsert: true });
        restoredCounts.branches++;
      }
    }

    if (Array.isArray(data.students) && data.students.length > 0) {
      for (const st of data.students) {
        await Student.findByIdAndUpdate(st._id, st, { upsert: true });
        restoredCounts.students++;
      }
    }

    if (Array.isArray(data.payments) && data.payments.length > 0) {
      for (const py of data.payments) {
        await Payment.findByIdAndUpdate(py._id, py, { upsert: true });
        restoredCounts.payments++;
      }
    }

    if (data.businessProfile) {
      await BusinessProfile.findOneAndUpdate({}, data.businessProfile, { upsert: true });
    }

    res.json({
      success: true,
      data: restoredCounts,
      message: 'Database restored successfully from backup'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/settings/receipt-config
router.get('/receipt-config', protect, async (req, res) => {
  try {
    const config = await ReceiptConfig.getConfig();
    res.json({ success: true, data: config });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/settings/receipt-config
router.put('/receipt-config', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    let config = await ReceiptConfig.getConfig();
    Object.assign(config, req.body);
    await config.save();
    res.json({ success: true, data: config, message: 'Receipt configuration saved' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/settings/sidebar/all - Get all items including disabled (admin only)
router.get('/sidebar/all', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const config = await SidebarConfig.getConfig();
    res.json({ success: true, data: config.items.sort((a, b) => (a.order || 0) - (b.order || 0)) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/settings/sidebar - Update all sidebar items (reorder, enable/disable, rename, role permissions, icons)
router.put('/sidebar', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { items } = req.body;
    if (!Array.isArray(items)) return res.status(400).json({ success: false, message: 'Items array required' });
    
    const config = await SidebarConfig.getConfig();
    const defaults = SidebarConfig.getDefaults();
    const existingMap = new Map();
    (config.items || []).forEach(i => existingMap.set(i.key, i.toObject ? i.toObject() : i));
    defaults.forEach(d => { if (!existingMap.has(d.key)) existingMap.set(d.key, d); });

    const mergedItems = items.map((item, index) => {
      const existing = existingMap.get(item.key) || {};
      return {
        key: item.key,
        label: item.label !== undefined ? String(item.label).trim() : (existing.label || item.key),
        href: item.href || existing.href || `#/${item.key}`,
        icon: item.icon !== undefined ? String(item.icon).trim() : (existing.icon || ''),
        isEnabled: item.isEnabled !== undefined ? Boolean(item.isEnabled) : (existing.isEnabled !== false),
        order: item.order !== undefined ? Number(item.order) : index + 1,
        allowedRoles: Array.isArray(item.allowedRoles) ? item.allowedRoles : (existing.allowedRoles || ['owner', 'branch_manager', 'staff']),
        isSystem: existing.isSystem !== undefined ? existing.isSystem : false,
        i18nKey: existing.i18nKey || `nav.${item.key}`
      };
    });

    config.items = mergedItems;
    await config.save();
    res.json({ success: true, data: config.items, message: 'Sidebar configuration saved successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/settings/sidebar/reset - Reset to defaults
router.put('/sidebar/reset', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const config = await SidebarConfig.getConfig();
    config.items = SidebarConfig.getDefaults();
    await config.save();
    res.json({ success: true, data: config.items, message: 'Sidebar reset to defaults' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/settings/dashboard-widgets - Get dashboard widget configuration
router.get('/dashboard-widgets', async (req, res) => {
  try {
    const setting = await SystemSetting.findOne({ key: 'dashboard.widgetConfig' }).lean();
    const defaultWidgets = SystemSetting.getDefaultDashboardWidgets();

    if (!setting || !Array.isArray(setting.value) || setting.value.length === 0) {
      return res.json({
        success: true,
        data: defaultWidgets,
        message: 'Default dashboard widgets retrieved'
      });
    }

    // Merge saved widgets with any defaults that might be missing
    const existingMap = new Map();
    setting.value.forEach(w => existingMap.set(w.id, w));

    const merged = defaultWidgets.map(d => {
      const exist = existingMap.get(d.id);
      if (exist) {
        return {
          id: d.id,
          label: exist.label || d.label,
          isEnabled: exist.isEnabled !== undefined ? Boolean(exist.isEnabled) : d.isEnabled,
          order: exist.order !== undefined ? Number(exist.order) : d.order,
          category: exist.category || d.category
        };
      }
      return d;
    });

    // Also preserve any custom widget entries not in defaults
    setting.value.forEach(w => {
      if (!defaultWidgets.some(d => d.id === w.id)) {
        merged.push(w);
      }
    });

    merged.sort((a, b) => (a.order || 0) - (b.order || 0));

    res.json({
      success: true,
      data: merged,
      message: 'Dashboard widget configuration retrieved successfully'
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/settings/dashboard-widgets - Update dashboard widget configuration
router.put('/dashboard-widgets', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const widgets = Array.isArray(req.body) ? req.body : (Array.isArray(req.body.widgets) ? req.body.widgets : null);
    if (!widgets) {
      return res.status(400).json({ success: false, message: 'Widgets array is required in request body' });
    }

    const sanitized = widgets.map((w, idx) => ({
      id: String(w.id),
      label: String(w.label || w.id),
      isEnabled: Boolean(w.isEnabled !== false),
      order: w.order !== undefined ? Number(w.order) : idx + 1,
      category: ['kpi', 'chart', 'action'].includes(w.category) ? w.category : 'kpi'
    })).sort((a, b) => a.order - b.order);

    const setting = await SystemSetting.findOneAndUpdate(
      { key: 'dashboard.widgetConfig' },
      {
        category: 'dashboard',
        key: 'dashboard.widgetConfig',
        value: sanitized,
        label: 'Dashboard Widget Configuration',
        type: 'array',
        isEditable: true
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    res.json({
      success: true,
      data: setting.value,
      message: 'Dashboard widget configuration saved successfully'
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/settings/dashboard-widgets/reset - Reset dashboard widgets to default
router.put('/dashboard-widgets/reset', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const defaultWidgets = SystemSetting.getDefaultDashboardWidgets();
    const setting = await SystemSetting.findOneAndUpdate(
      { key: 'dashboard.widgetConfig' },
      {
        category: 'dashboard',
        key: 'dashboard.widgetConfig',
        value: defaultWidgets,
        label: 'Dashboard Widget Configuration',
        type: 'array',
        isEditable: true
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    res.json({
      success: true,
      data: setting.value,
      message: 'Dashboard widgets reset to default successfully'
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/settings/pdf-config - Get PDF Admission Form Configuration
router.get('/pdf-config', roleCheck('owner', 'branch_manager', 'staff'), async (req, res) => {
  try {
    const setting = await SystemSetting.findOne({ key: 'pdf.admissionConfig' });
    const defaultConfig = {
      pdfTemplate: 'modern_glass',
      watermarkStamp: 'PAID • ACTIVE STUDENT',
      showSelfiePhoto: true,
      showDigitalSignature: true,
      showGateQrCode: true,
      showFormBuilderAnswers: true,
      showUploadedDocuments: true,
      showPaymentBreakdown: true,
      showDisciplineRules: true,
      showStatusWatermark: true
    };
    res.json({
      success: true,
      data: setting ? { ...defaultConfig, ...setting.value } : defaultConfig
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/settings/pdf-config - Update PDF Admission Form Configuration
router.put('/pdf-config', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const payload = req.body || {};
    const sanitized = {
      pdfTemplate: payload.pdfTemplate || 'modern_glass',
      watermarkStamp: String(payload.watermarkStamp || 'PAID • ACTIVE STUDENT').trim(),
      showSelfiePhoto: Boolean(payload.showSelfiePhoto !== false),
      showDigitalSignature: Boolean(payload.showDigitalSignature !== false),
      showGateQrCode: Boolean(payload.showGateQrCode !== false),
      showFormBuilderAnswers: Boolean(payload.showFormBuilderAnswers !== false),
      showUploadedDocuments: Boolean(payload.showUploadedDocuments !== false),
      showPaymentBreakdown: Boolean(payload.showPaymentBreakdown !== false),
      showDisciplineRules: Boolean(payload.showDisciplineRules !== false),
      showStatusWatermark: Boolean(payload.showStatusWatermark !== false)
    };

    const setting = await SystemSetting.findOneAndUpdate(
      { key: 'pdf.admissionConfig' },
      {
        category: 'pdf',
        key: 'pdf.admissionConfig',
        value: sanitized,
        label: 'PDF Admission Form Configuration',
        type: 'object',
        isEditable: true
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    res.json({
      success: true,
      data: setting.value,
      message: 'PDF Admission Form configuration saved successfully'
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
