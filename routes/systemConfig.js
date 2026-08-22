const express = require('express');
const router = express.Router();
const BusinessProfile = require('../models/BusinessProfile');
const Plan = require('../models/Plan');
const Shift = require('../models/Shift');
const Branch = require('../models/Branch');
const Seat = require('../models/Seat');
const Student = require('../models/Student');
const Attendance = require('../models/Attendance');
const CustomField = require('../models/CustomField');
const ReceiptConfig = require('../models/ReceiptConfig');
const LandingPage = require('../models/LandingPage');
const SystemSetting = require('../models/SystemSetting');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');

// Helper to format shift time to 12-hour AM/PM string
const formatShiftTime = (t) => {
  if (!t) return '';
  if (t.includes('AM') || t.includes('PM')) return t;
  const parts = t.split(':');
  if (parts.length < 2) return t;
  let h = parseInt(parts[0], 10);
  const m = parts[1].padStart(2, '0');
  const ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  h = h ? h : 12;
  return `${h.toString().padStart(2, '0')}:${m} ${ampm}`;
};

// Helper to guess icon from shift name
const guessShiftIcon = (name) => {
  const n = (name || '').toLowerCase();
  if (n.includes('morning') || n.includes('sakal')) return '🌅';
  if (n.includes('evening') || n.includes('sandhya') || n.includes('afternoon')) return '🌇';
  if (n.includes('night') || n.includes('owl') || n.includes('ratra')) return '🌙';
  if (n.includes('full') || n.includes('24') || n.includes('prime')) return '☀️';
  return '⏰';
};

/**
 * @route   GET /api/system/public-config
 * @desc    Aggregate Single Source of Truth (SSOT) public configuration
 *          Returns businessProfile, plans, shifts, branches, customFields, receiptConfig, landing, theme
 * @access  Public
 */
router.get('/public-config', async (req, res) => {
  try {
    // Seed default custom fields if none exist
    try {
      await CustomField.seedDefaultFields();
    } catch (seedErr) {
      console.warn('CustomField seed check note:', seedErr.message);
    }

    const [
      businessProfileRes,
      plansRes,
      shiftsRes,
      branchesRes,
      customFieldsRes,
      receiptConfigRes,
      landingConfigRes,
      activeStudentsRes,
      settingsRes,
      attendanceStatsRes,
      occupiedCountsRes
    ] = await Promise.allSettled([
      BusinessProfile.getProfile(),
      Plan.find({ isActive: true }).sort({ displayOrder: 1, price: 1 }).lean(),
      Shift.find({ isActive: true }).sort({ startTime: 1, name: 1 }).lean(),
      Branch.find({ isActive: true }).lean(),
      CustomField.getActiveFields(),
      ReceiptConfig.getConfig(),
      LandingPage.getPageConfig(),
      Student.find({ status: 'active' }).populate('plan', 'shift name').lean(),
      SystemSetting.find().lean(),
      Attendance.getTodayStats(),
      Seat.aggregate([
        { $match: { status: 'occupied', isActive: true, branch: { $ne: null } } },
        { $group: { _id: '$branch', count: { $sum: 1 } } }
      ])
    ]);

    const businessProfile = businessProfileRes.status === 'fulfilled' && businessProfileRes.value ? businessProfileRes.value : {};
    const rawPlans = plansRes.status === 'fulfilled' && Array.isArray(plansRes.value) ? plansRes.value : [];
    const rawShifts = shiftsRes.status === 'fulfilled' && Array.isArray(shiftsRes.value) ? shiftsRes.value : [];
    const rawCustomFields = customFieldsRes.status === 'fulfilled' && Array.isArray(customFieldsRes.value) ? customFieldsRes.value : [];
    const receiptConfig = receiptConfigRes.status === 'fulfilled' && receiptConfigRes.value ? receiptConfigRes.value : {};
    let landingConfig = landingConfigRes.status === 'fulfilled' && landingConfigRes.value ? landingConfigRes.value : LandingPage.getDefaults();
    const activeStudents = activeStudentsRes.status === 'fulfilled' && Array.isArray(activeStudentsRes.value) ? activeStudentsRes.value : [];
    const rawSettings = settingsRes.status === 'fulfilled' && Array.isArray(settingsRes.value) ? settingsRes.value : [];
    const todayStats = attendanceStatsRes.status === 'fulfilled' && attendanceStatsRes.value ? attendanceStatsRes.value : { totalPresent: 0, totalAbsent: 0, currentlyCheckedIn: 0 };

    if (!landingConfig) {
      landingConfig = LandingPage.getDefaults();
    }

    // Settings map
    const settingsMap = {};
    rawSettings.forEach(s => {
      settingsMap[s.key] = s.value;
    });

    // Calculate active student counts per shift for capacity checking
    const shiftStudentCount = {};
    rawShifts.forEach(s => {
      shiftStudentCount[s._id.toString()] = 0;
      shiftStudentCount[s.code] = 0;
    });

    activeStudents.forEach(st => {
      if (st.shift && shiftStudentCount[st.shift.toString()] !== undefined) {
        shiftStudentCount[st.shift.toString()]++;
      } else if (st.plan?.shift) {
        const pShift = st.plan.shift.toLowerCase();
        const matched = rawShifts.find(s =>
          s.code.toLowerCase() === pShift ||
          s.name.toLowerCase().replace(/\s+/g, '').includes(pShift) ||
          (pShift === 'fullday' && (s.code === 'FULL' || s.name.toLowerCase().includes('full'))) ||
          (pShift === 'morning' && (s.code === 'MORN' || s.name.toLowerCase().includes('morn'))) ||
          (pShift === 'evening' && (s.code === 'EVE' || s.name.toLowerCase().includes('eve'))) ||
          (pShift === 'night' && (s.code === 'NIGHT' || s.name.toLowerCase().includes('night')))
        );
        if (matched) {
          shiftStudentCount[matched._id.toString()] = (shiftStudentCount[matched._id.toString()] || 0) + 1;
          shiftStudentCount[matched.code] = (shiftStudentCount[matched.code] || 0) + 1;
        }
      }
    });

    // 1. Business Profile Aggregation
    const formattedBusinessProfile = {
      businessName: businessProfile?.businessName || 'Study Library',
      tagline: businessProfile?.tagline || 'Premier Air-Conditioned Reading Hall',
      logo: businessProfile?.logo || '',
      favicon: businessProfile?.favicon || '',
      phone: businessProfile?.phone || '',
      email: businessProfile?.email || '',
      address: businessProfile?.address || '',
      city: businessProfile?.city || '',
      state: businessProfile?.state || '',
      pincode: businessProfile?.pincode || '',
      gstNumber: businessProfile?.gstNumber || '',
      upiQrCode: businessProfile?.upiQrCode || '',
      upiId: businessProfile?.upiId || 'thecozycorner@okaxis',
      bankDetails: businessProfile?.bankDetails || {},
      paymentMethods: businessProfile?.paymentMethods || [],
      socialLinks: businessProfile?.socialLinks || {},
      mapEmbedUrl: businessProfile?.mapEmbedUrl || landingConfig?.footer?.mapEmbedUrl || landingConfig?.contact?.googleMapEmbedUrl || ''
    };

    // 2. Plans Aggregation with effective price & features & shift capacity flag
    const formattedPlans = rawPlans.map(p => {
      const price = Number(p.price) || 0;
      const discount = Number(p.discount) || 0;
      const effectivePrice = Math.round(price * (1 - discount / 100));
      
      const pShift = (p.shift || 'any').toLowerCase();
      const matchedShift = rawShifts.find(s =>
        s.code.toLowerCase() === pShift ||
        s.name.toLowerCase().replace(/\s+/g, '').includes(pShift) ||
        (pShift === 'fullday' && (s.code === 'FULL' || s.name.toLowerCase().includes('full'))) ||
        (pShift === 'morning' && (s.code === 'MORN' || s.name.toLowerCase().includes('morn'))) ||
        (pShift === 'evening' && (s.code === 'EVE' || s.name.toLowerCase().includes('eve'))) ||
        (pShift === 'night' && (s.code === 'NIGHT' || s.name.toLowerCase().includes('night')))
      );

      const shiftMaxCap = matchedShift?.maxCapacity || 0;
      const shiftEnrolled = matchedShift ? (shiftStudentCount[matchedShift._id.toString()] || shiftStudentCount[matchedShift.code] || 0) : 0;
      const isShiftFull = shiftMaxCap > 0 && shiftEnrolled >= shiftMaxCap;

      return {
        id: p._id,
        _id: p._id,
        name: p.name,
        duration: p.duration,
        durationType: p.durationType || 'days',
        price,
        discount,
        effectivePrice,
        features: Array.isArray(p.features) ? p.features : [],
        seatType: p.seatType || 'any',
        shift: p.shift || 'any',
        matchedShiftId: matchedShift?._id || null,
        isFull: isShiftFull,
        description: p.description || '',
        displayOrder: p.displayOrder || 0,
        isActive: p.isActive !== false
      };
    });

    // 3. Shifts Aggregation with formatted timing, capacity & full status
    const formattedShifts = rawShifts.map(s => {
      const timingStr = (s.startTime && s.endTime)
        ? `${formatShiftTime(s.startTime)} – ${formatShiftTime(s.endTime)}`
        : '';
      const icon = guessShiftIcon(s.name);
      const currentEnrolled = shiftStudentCount[s._id.toString()] || shiftStudentCount[s.code] || 0;
      const maxCap = s.maxCapacity || 0;
      const isFull = maxCap > 0 && currentEnrolled >= maxCap;
      const availableSlots = maxCap > 0 ? Math.max(0, maxCap - currentEnrolled) : 999;

      return {
        id: s._id,
        _id: s._id,
        name: s.name,
        code: s.code,
        startTime: s.startTime,
        endTime: s.endTime,
        formattedTiming: s.formattedTiming || timingStr,
        maxCapacity: maxCap,
        currentEnrolled,
        availableSlots,
        isFull,
        guessShiftIcon: icon,
        icon,
        showOnLanding: true,
        description: s.description || '',
        priceMultiplier: s.priceMultiplier || 1.0,
        daysActive: s.daysActive || ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
      };
    });

    // Auto-sync system database shifts into landingConfig.shifts.items
    const existingCmsShifts = (landingConfig.shifts?.items || []).filter(item => item.name && item.name !== 'New Shift');
    let mergedShiftItems = [];

    if (rawShifts.length > 0) {
      rawShifts.forEach(s => {
        const found = existingCmsShifts.find(item =>
          (item.shiftId && item.shiftId.toString() === s._id.toString()) ||
          (item.name && item.name.toLowerCase() === s.name.toLowerCase())
        );

        const timingStr = (s.startTime && s.endTime)
          ? `${formatShiftTime(s.startTime)} – ${formatShiftTime(s.endTime)}`
          : '';

        if (found) {
          mergedShiftItems.push({
            shiftId: s._id.toString(),
            name: found.name || s.name,
            timing: found.timing || timingStr,
            description: found.description || s.description || 'Dedicated study slot with AC and high-speed Wi-Fi access.',
            icon: found.icon || guessShiftIcon(s.name),
            enabled: found.enabled !== false
          });
        } else {
          mergedShiftItems.push({
            shiftId: s._id.toString(),
            name: s.name,
            timing: timingStr,
            description: s.description || 'Dedicated study slot with AC and high-speed Wi-Fi access.',
            icon: guessShiftIcon(s.name),
            enabled: true
          });
        }
      });

      // Preserve custom CMS items
      existingCmsShifts.forEach(item => {
        if (!item.shiftId && !mergedShiftItems.some(m => m.name.toLowerCase() === item.name.toLowerCase())) {
          mergedShiftItems.push(item);
        }
      });
    } else if (existingCmsShifts.length > 0) {
      mergedShiftItems = existingCmsShifts;
    } else {
      mergedShiftItems = LandingPage.getDefaults().shifts.items;
    }

    if (!landingConfig.shifts) landingConfig.shifts = {};
    landingConfig.shifts.items = mergedShiftItems;

    // 4. Custom Fields Grouped by Sections
    const sectionsMap = new Map();
    const sectionDefaults = {
      personal: { label: 'Personal Information', icon: '👤', description: 'Basic identification details' },
      academic: { label: 'Academic & Preparation', icon: '📚', description: 'Educational background and exam goals' },
      contact: { label: 'Address & Emergency Contact', icon: '📍', description: 'Address and emergency contact information' },
      kyc: { label: 'KYC & Verification', icon: '🪪', description: 'Identity verification and digital signature' },
      other: { label: 'Additional Information', icon: '📝', description: 'Additional notes and preferences' }
    };

    rawCustomFields.forEach(field => {
      const secKey = field.section || 'personal';
      if (!sectionsMap.has(secKey)) {
        sectionsMap.set(secKey, {
          section: secKey,
          sectionLabel: field.sectionLabel || sectionDefaults[secKey]?.label || secKey.charAt(0).toUpperCase() + secKey.slice(1),
          sectionIcon: field.sectionIcon || sectionDefaults[secKey]?.icon || '📋',
          sectionDescription: field.sectionDescription || sectionDefaults[secKey]?.description || '',
          sectionInstructions: field.sectionInstructions || '',
          fields: []
        });
      }
      sectionsMap.get(secKey).fields.push(field);
    });

    const sectionsArray = Array.from(sectionsMap.values());
    const bySection = {};
    sectionsArray.forEach(s => {
      bySection[s.section] = s.fields;
    });

    const formattedCustomFields = {
      sections: sectionsArray,
      bySection,
      fields: rawCustomFields
    };

    // 5. Receipt Configuration
    const formattedReceiptConfig = {
      activeTemplate: receiptConfig?.activeTemplate || 'standard_a4',
      header: {
        showLogo: receiptConfig?.header?.showLogo !== false,
        logoUrl: receiptConfig?.header?.logoUrl || businessProfile?.logo || '',
        logoPosition: receiptConfig?.header?.logoPosition || 'center',
        showBusinessName: receiptConfig?.header?.showBusinessName !== false,
        subtitle: receiptConfig?.header?.subtitle || 'Official Fee Receipt',
        showAddress: receiptConfig?.header?.showAddress !== false,
        showPhone: receiptConfig?.header?.showPhone !== false,
        showEmail: receiptConfig?.header?.showEmail !== false,
        showGst: receiptConfig?.header?.showGst !== false,
        taxNumber: receiptConfig?.header?.taxNumber || businessProfile?.registrationNumber || '',
        gstNumber: receiptConfig?.header?.gstNumber || businessProfile?.gstNumber || '',
        headerColor: receiptConfig?.header?.headerColor || '#4f46e5'
      },
      body: receiptConfig?.body || {
        showStudentId: true,
        showStudentPhone: true,
        showStudentEmail: false,
        showPlanDetails: true,
        showPeriod: true,
        showDiscount: true,
        showLateFee: true,
        showPaymentMethod: true,
        showTransactionId: true,
        showSeatNumber: true,
        showShift: true
      },
      footer: {
        showStamp: receiptConfig?.footer?.showStamp !== false,
        stampImage: receiptConfig?.footer?.stampImage || businessProfile?.stampImage || '',
        showSignature: receiptConfig?.footer?.showSignature !== false,
        signatureImage: receiptConfig?.footer?.signatureImage || '',
        signatureLabel: receiptConfig?.footer?.signatureLabel || 'Authorized Signatory',
        showUpiQr: Boolean(receiptConfig?.footer?.showUpiQr),
        termsText: receiptConfig?.footer?.termsText || 'This is a computer-generated receipt and does not require a physical signature.',
        customNote: receiptConfig?.footer?.customNote || 'Thank you for choosing our library!',
        showTimestamp: receiptConfig?.footer?.showTimestamp !== false
      },
      gst: receiptConfig?.gst || {
        enabled: false,
        gstRate: 18,
        hsnCode: '9992',
        showCgstSgst: true,
        placeOfSupply: ''
      },
      logo: receiptConfig?.header?.logoUrl || businessProfile?.logo || '',
      terms: receiptConfig?.footer?.termsText || 'This is a computer-generated receipt and does not require a physical signature.',
      signature: {
        showSignature: receiptConfig?.footer?.showSignature !== false,
        signatureLabel: receiptConfig?.footer?.signatureLabel || 'Authorized Signatory',
        stampImage: receiptConfig?.footer?.stampImage || businessProfile?.stampImage || ''
      }
    };

    // 6. Theme Configuration
    const formattedTheme = landingConfig?.theme || {
      preset: 'default',
      primaryColor: '#6c5ce7',
      accentColor: '#00b894',
      fontFamily: 'Outfit, sans-serif'
    };

    // 7. Kiosk Voice & Audio Preferences
    const kioskVoice = {
      voiceEnabled: settingsMap['kiosk.enableVoice'] !== undefined ? Boolean(settingsMap['kiosk.enableVoice']) : (settingsMap['kiosk.voiceEnabled'] !== undefined ? Boolean(settingsMap['kiosk.voiceEnabled']) : true),
      soundEnabled: settingsMap['kiosk.soundEnabled'] !== undefined ? Boolean(settingsMap['kiosk.soundEnabled']) : true,
      language: settingsMap['kiosk.voiceLanguage'] || settingsMap['kiosk.voiceLang'] || 'en-IN',
      voiceGender: settingsMap['kiosk.voiceGender'] || 'female',
      pitch: Number(settingsMap['kiosk.voicePitch']) || 1.0,
      rate: Number(settingsMap['kiosk.voiceRate']) || 1.0,
      volume: Number(settingsMap['kiosk.voiceVolume']) || 1.0,
      welcomeMessage: settingsMap['kiosk.welcomeMessage'] || 'Welcome to {businessName}, {studentName}! Seat {seatNumber}.',
      farewellMessage: settingsMap['kiosk.farewellMessage'] || 'Goodbye {studentName}! Total study duration {duration}.',
      checkInVoiceTemplate: settingsMap['kiosk.welcomeMessage'] || 'Welcome to {businessName}, {studentName}! Seat {seatNumber}.',
      checkOutVoiceTemplate: settingsMap['kiosk.farewellMessage'] || 'Goodbye {studentName}! Total study duration {duration}.'
    };

    // 8. Live Punch Stats
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);
    const totalCheckouts = await Attendance.countDocuments({
      date: { $gte: startOfDay, $lte: endOfDay },
      checkIn: { $ne: null },
      checkOut: { $ne: null }
    }).catch(() => 0);

    const livePunchStats = {
      currentlyCheckedIn: todayStats.currentlyCheckedIn || 0,
      totalPresent: todayStats.totalPresent || 0,
      totalCheckouts: totalCheckouts || 0,
      totalAbsent: todayStats.totalAbsent || 0,
      timestamp: new Date().toISOString()
    };

    // 3.5 Branches Aggregation with available seat calculations
    const rawBranches = branchesRes.status === 'fulfilled' && Array.isArray(branchesRes.value) ? branchesRes.value : [];
    const occupiedCounts = occupiedCountsRes.status === 'fulfilled' && Array.isArray(occupiedCountsRes.value) ? occupiedCountsRes.value : [];
    const occupiedMap = new Map(occupiedCounts.map(c => [String(c._id), c.count]));

    let formattedBranches = [];
    if (rawBranches.length > 0) {
      formattedBranches = rawBranches.map(b => {
        const occupiedSeats = occupiedMap.get(String(b._id)) || 0;
        const totalSeats = b.totalSeats || 50;
        return {
          ...b,
          occupiedSeats,
          availableSeats: Math.max(0, totalSeats - occupiedSeats)
        };
      });
    } else {
      formattedBranches = [{
        _id: 'default_main',
        name: formattedBusinessProfile.businessName || 'Main Campus Central',
        code: 'MAIN',
        city: formattedBusinessProfile.city || 'Central City',
        address: formattedBusinessProfile.address || 'Main Reading Hall Complex',
        phone: formattedBusinessProfile.phone || '+91 9876543210',
        totalSeats: 50,
        occupiedSeats: 1,
        availableSeats: 49
      }];
    }

    // Return unified SSOT response
    res.json({
      success: true,
      data: {
        businessName: formattedBusinessProfile.businessName,
        tagline: formattedBusinessProfile.tagline,
        logo: formattedBusinessProfile.logo,
        businessProfile: formattedBusinessProfile,
        plans: formattedPlans,
        shifts: formattedShifts,
        branches: formattedBranches,
        customFields: formattedCustomFields,
        receiptConfig: formattedReceiptConfig,
        kioskVoice,
        livePunchStats,
        landing: landingConfig,
        theme: formattedTheme
      }
    });
  } catch (err) {
    console.error('Error fetching public config:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to aggregate public configuration',
      error: err.message
    });
  }
});

/**
 * @route   GET /api/system/system-settings
 * @desc    Get library operation settings (grace periods, auto checkout, kiosk settings)
 * @access  Private (Authenticated users)
 */
router.get('/system-settings', protect, async (req, res) => {
  try {
    let allSettings = await SystemSetting.find();
    if (!allSettings || allSettings.length === 0) {
      await SystemSetting.initDefaults();
      allSettings = await SystemSetting.find();
    }

    const categorized = {
      general: {},
      payment: {},
      operations: {},
      kiosk: {},
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
        systemSettings: categorized,
        operations: categorized.operations || {},
        kiosk: categorized.kiosk || {},
        payment: categorized.payment || {},
        admission: categorized.admission || {},
        notification: categorized.notification || {},
        general: categorized.general || {},
        rawSettings: allSettings
      },
      message: 'System settings retrieved successfully'
    });
  } catch (error) {
    console.error('Error fetching system settings:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   PUT /api/system/system-settings
 * @desc    Update library operation settings
 * @access  Private (Owner only)
 */
router.put('/system-settings', protect, roleCheck('owner'), async (req, res) => {
  try {
    const updates = req.body;
    if (!updates || typeof updates !== 'object') {
      return res.status(400).json({ success: false, message: 'Invalid settings payload' });
    }

    // Key definitions with type hints
    const keyDefinitions = {
      // Payment Settings
      'gracePeriod': { key: 'payment.gracePeriod', category: 'payment', type: 'number', label: 'Grace Period (Days)' },
      'payment.gracePeriod': { key: 'payment.gracePeriod', category: 'payment', type: 'number', label: 'Grace Period (Days)' },
      'lateFeeType': { key: 'payment.lateFeeType', category: 'payment', type: 'string', label: 'Late Fee Type' },
      'payment.lateFeeType': { key: 'payment.lateFeeType', category: 'payment', type: 'string', label: 'Late Fee Type' },
      'lateFeeAmount': { key: 'payment.lateFeeAmount', category: 'payment', type: 'number', label: 'Late Fee Amount' },
      'payment.lateFeeAmount': { key: 'payment.lateFeeAmount', category: 'payment', type: 'number', label: 'Late Fee Amount' },
      'latePenalty': { key: 'payment.latePenalty', category: 'payment', type: 'number', label: 'Late Penalty' },
      'payment.latePenalty': { key: 'payment.latePenalty', category: 'payment', type: 'number', label: 'Late Penalty' },
      'autoSuspendDays': { key: 'payment.autoSuspendDays', category: 'payment', type: 'number', label: 'Auto Suspend Days' },
      'payment.autoSuspendDays': { key: 'payment.autoSuspendDays', category: 'payment', type: 'number', label: 'Auto Suspend Days' },

      // Library Operations Settings
      'gracePeriodMinutes': { key: 'operations.gracePeriodMinutes', category: 'operations', type: 'number', label: 'Attendance Grace Period (Minutes)' },
      'operations.gracePeriodMinutes': { key: 'operations.gracePeriodMinutes', category: 'operations', type: 'number', label: 'Attendance Grace Period (Minutes)' },
      'autoCheckout': { key: 'operations.autoCheckout', category: 'operations', type: 'boolean', label: 'Auto Checkout' },
      'operations.autoCheckout': { key: 'operations.autoCheckout', category: 'operations', type: 'boolean', label: 'Auto Checkout' },
      'autoCheckoutHours': { key: 'operations.autoCheckoutHours', category: 'operations', type: 'number', label: 'Auto Checkout Duration (Hours)' },
      'operations.autoCheckoutHours': { key: 'operations.autoCheckoutHours', category: 'operations', type: 'number', label: 'Auto Checkout Duration (Hours)' },
      'autoCheckoutTime': { key: 'operations.autoCheckoutTime', category: 'operations', type: 'string', label: 'Daily Auto Checkout Time' },
      'operations.autoCheckoutTime': { key: 'operations.autoCheckoutTime', category: 'operations', type: 'string', label: 'Daily Auto Checkout Time' },
      'latePenaltyPerHour': { key: 'operations.latePenaltyPerHour', category: 'operations', type: 'number', label: 'Overstay Penalty Per Hour' },
      'operations.latePenaltyPerHour': { key: 'operations.latePenaltyPerHour', category: 'operations', type: 'number', label: 'Overstay Penalty Per Hour' },
      'requireBiometricForEntry': { key: 'operations.requireBiometricForEntry', category: 'operations', type: 'boolean', label: 'Require Biometric Entry' },
      'operations.requireBiometricForEntry': { key: 'operations.requireBiometricForEntry', category: 'operations', type: 'boolean', label: 'Require Biometric Entry' },

      // Kiosk Settings
      'enableVoice': { key: 'kiosk.enableVoice', category: 'kiosk', type: 'boolean', label: 'Enable Kiosk Voice Audio' },
      'kiosk.enableVoice': { key: 'kiosk.enableVoice', category: 'kiosk', type: 'boolean', label: 'Enable Kiosk Voice Audio' },
      'voiceLanguage': { key: 'kiosk.voiceLanguage', category: 'kiosk', type: 'string', label: 'Voice Audio Language' },
      'kiosk.voiceLanguage': { key: 'kiosk.voiceLanguage', category: 'kiosk', type: 'string', label: 'Voice Audio Language' },
      'soundEnabled': { key: 'kiosk.soundEnabled', category: 'kiosk', type: 'boolean', label: 'Enable Sound Effects' },
      'kiosk.soundEnabled': { key: 'kiosk.soundEnabled', category: 'kiosk', type: 'boolean', label: 'Enable Sound Effects' },
      'screenTimeoutSeconds': { key: 'kiosk.screenTimeoutSeconds', category: 'kiosk', type: 'number', label: 'Screen Timeout (Seconds)' },
      'kiosk.screenTimeoutSeconds': { key: 'kiosk.screenTimeoutSeconds', category: 'kiosk', type: 'number', label: 'Screen Timeout (Seconds)' },
      'welcomeMessage': { key: 'kiosk.welcomeMessage', category: 'kiosk', type: 'string', label: 'Kiosk Welcome Audio Message' },
      'kiosk.welcomeMessage': { key: 'kiosk.welcomeMessage', category: 'kiosk', type: 'string', label: 'Kiosk Welcome Audio Message' },
      'farewellMessage': { key: 'kiosk.farewellMessage', category: 'kiosk', type: 'string', label: 'Kiosk Checkout Audio Message' },
      'kiosk.farewellMessage': { key: 'kiosk.farewellMessage', category: 'kiosk', type: 'string', label: 'Kiosk Checkout Audio Message' },

      // Admission Settings
      'autoApprove': { key: 'admission.autoApprove', category: 'admission', type: 'boolean', label: 'Auto Approve Admissions' },
      'admission.autoApprove': { key: 'admission.autoApprove', category: 'admission', type: 'boolean', label: 'Auto Approve Admissions' },
      'idPrefix': { key: 'admission.idPrefix', category: 'admission', type: 'string', label: 'Student ID Prefix' },
      'admission.idPrefix': { key: 'admission.idPrefix', category: 'admission', type: 'string', label: 'Student ID Prefix' },
      'idFormat': { key: 'admission.idFormat', category: 'admission', type: 'string', label: 'Student ID Format' },
      'admission.idFormat': { key: 'admission.idFormat', category: 'admission', type: 'string', label: 'Student ID Format' },

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
      if (typeof v === 'object' && v !== null && !Array.isArray(v) && ['general', 'payment', 'operations', 'kiosk', 'admission', 'notification'].includes(k)) {
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
        if (typeof value === 'string') {
          try {
            parsedValue = JSON.parse(value);
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
    const allSettings = await SystemSetting.find();
    const categorized = {
      general: {},
      payment: {},
      operations: {},
      kiosk: {},
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
        systemSettings: categorized,
        operations: categorized.operations || {},
        kiosk: categorized.kiosk || {},
        payment: categorized.payment || {}
      },
      message: 'System settings updated successfully'
    });
  } catch (error) {
    console.error('Error updating system settings:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
