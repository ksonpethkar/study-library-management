const express = require('express');
const router = express.Router();
const BusinessProfile = require('../models/BusinessProfile');
const Shift = require('../models/Shift');
const Plan = require('../models/Plan');
const Student = require('../models/Student');
const Attendance = require('../models/Attendance');
const SystemSetting = require('../models/SystemSetting');
const ReceiptConfig = require('../models/ReceiptConfig');
const FormTemplate = require('../models/FormTemplate');
const CustomField = require('../models/CustomField');
const Branch = require('../models/Branch');
const memoryCache = require('../utils/memoryCache');

/**
 * @route   GET /api/system/public-config
 * @desc    Get public library configuration for gate kiosk, registration, receipts & waiting list
 * @access  Public
 */
router.get('/public-config', async (req, res) => {
  try {
    const [businessProfile, allShifts, allPlans, todayStats, receiptConfig, rawSettings, activeTemplate, allFields, allBranches] = await Promise.all([
      BusinessProfile.getProfile(),
      Shift.find({ isActive: true }).sort({ startTime: 1, name: 1 }),
      Plan.find({ isActive: true }).sort('displayOrder').lean(),
      Attendance.getTodayStats().catch(() => ({ totalPresent: 0, totalAbsent: 0, currentlyCheckedIn: 0 })),
      ReceiptConfig.getConfig(),
      SystemSetting.find().lean().catch(() => []),
      FormTemplate.getActiveTemplate().catch(() => null),
      CustomField.find({ isActive: true }).sort({ order: 1 }).lean().catch(() => []),
      Branch.find({ isActive: true }).lean().catch(() => [])
    ]);

    // Calculate active student enrollment & full status for each shift
    const activeStudents = await Student.find({ status: 'active' }).select('shift plan').populate('plan', 'shift name').lean();
    
    // Count active students per shift
    const shiftStudentCount = {};
    allShifts.forEach(s => {
      shiftStudentCount[s._id.toString()] = 0;
      shiftStudentCount[s.code] = 0;
    });

    activeStudents.forEach(st => {
      if (st.shift && shiftStudentCount[st.shift.toString()] !== undefined) {
        shiftStudentCount[st.shift.toString()]++;
      } else if (st.plan?.shift) {
        const pShift = st.plan.shift.toLowerCase();
        const matched = allShifts.find(s =>
          s.code.toLowerCase() === pShift ||
          s.name.toLowerCase().replace(/\s+/g, '').includes(pShift) ||
          (pShift === 'fullday' && (s.code === 'FULL' || s.name.toLowerCase().includes('full'))) ||
          (pShift === 'morning' && (s.code === 'MORN' || s.name.toLowerCase().includes('morn'))) ||
          (pShift === 'evening' && (s.code === 'EVE' || s.name.toLowerCase().includes('eve'))) ||
          (pShift === 'night' && (s.code === 'NIGHT' || s.name.toLowerCase().includes('night')))
        );
        if (matched) {
          shiftStudentCount[matched._id.toString()]++;
          shiftStudentCount[matched.code]++;
        }
      }
    });

    // Count active students per plan
    const planStudentCount = {};
    activeStudents.forEach(st => {
      const pId = st.plan?._id ? st.plan._id.toString() : (st.plan ? st.plan.toString() : null);
      if (pId) {
        planStudentCount[pId] = (planStudentCount[pId] || 0) + 1;
      }
    });

    const enrichedPlans = (allPlans || []).map(p => {
      const origPrice = Number(p.price) || 0;
      const discount = Number(p.discount) || 0;
      const effectivePrice = Math.round(origPrice * (1 - discount / 100));
      return {
        ...p,
        discount,
        effectivePrice,
        activeMembersCount: planStudentCount[p._id.toString()] || 0
      };
    });

    const shiftsWithCapacity = allShifts.map(shift => {
      const sObj = shift.toObject({ virtuals: true });
      const currentEnrolled = shiftStudentCount[shift._id.toString()] || shiftStudentCount[shift.code] || 0;
      const maxCap = shift.maxCapacity || 0;
      const isFull = maxCap > 0 && currentEnrolled >= maxCap;

      return {
        ...sObj,
        currentEnrolled,
        availableSlots: maxCap > 0 ? Math.max(0, maxCap - currentEnrolled) : 999,
        isFull
      };
    });

    // Extract settings
    const settingsMap = {};
    (rawSettings || []).forEach(s => {
      settingsMap[s.key] = s.value;
    });

    // Kiosk voice audio preferences
    const kioskVoice = {
      voiceEnabled: settingsMap['kiosk.voiceEnabled'] !== undefined ? settingsMap['kiosk.voiceEnabled'] : true,
      language: settingsMap['kiosk.voiceLang'] || 'en-IN',
      voiceGender: settingsMap['kiosk.voiceGender'] || 'female',
      pitch: Number(settingsMap['kiosk.voicePitch']) || 1.0,
      rate: Number(settingsMap['kiosk.voiceRate']) || 1.0,
      volume: Number(settingsMap['kiosk.voiceVolume']) || 1.0,
      checkInVoiceTemplate: settingsMap['kiosk.checkInVoiceTemplate'] || 'Welcome to {businessName}, {studentName}! Seat {seatNumber}.',
      checkOutVoiceTemplate: settingsMap['kiosk.checkOutVoiceTemplate'] || 'Goodbye {studentName}! Total study duration {duration}.'
    };

    // Calculate today's checkouts
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

    // Canonical Payment Methods for Self-Registration Portal
    const CANONICAL_PAYMENT_METHODS = [
      {
        key: 'upi',
        name: 'Dynamic UPI QR & 1-Tap Apps',
        subtitle: 'GPay / PhonePe / Paytm / BHIM (Instant)',
        icon: '⚡',
        enabled: true,
        order: 1,
        instructions: 'Scan QR code or use 1-tap UPI app buttons and enter 12-digit UTR number',
        requiresRef: true,
        refLabel: '12-Digit Bank UTR / Reference Number *'
      },
      {
        key: 'card',
        name: 'Debit / Credit Card',
        subtitle: 'Visa, Mastercard, RuPay & POS Swipe',
        icon: '💳',
        enabled: true,
        order: 2,
        instructions: 'Swipe / pay via card machine or online POS and enter card txn reference',
        requiresRef: true,
        refLabel: 'Card Transaction Reference / Approval Code *'
      },
      {
        key: 'netbanking',
        name: 'NetBanking / Direct Bank Transfer',
        subtitle: 'NEFT / IMPS / RTGS (All Indian Banks)',
        icon: '🏦',
        enabled: true,
        order: 3,
        instructions: 'Transfer fee to official library bank account and enter transaction UTR or upload slip',
        requiresRef: true,
        refLabel: 'Bank Transaction Reference / UTR *'
      },
      {
        key: 'desk',
        name: 'Pay Later at Front Desk',
        subtitle: 'Cash / Spot Pay on Arrival',
        icon: '💵',
        enabled: true,
        order: 4,
        instructions: 'Your chosen seat is reserved for 24 hours. Pay cash or UPI at the front desk upon arrival.',
        requiresRef: false,
        refLabel: ''
      }
    ];

    const storedMethods = Array.isArray(businessProfile?.paymentMethods) ? businessProfile.paymentMethods : [];
    const storedMap = new Map(storedMethods.map(m => [m.key, m]));
    const tplS = activeTemplate?.settings || {};

    const mergedPaymentMethods = CANONICAL_PAYMENT_METHODS.map(def => {
      const stored = storedMap.get(def.key);
      let isEnabled = stored ? Boolean(stored.enabled) : def.enabled;

      if (def.key === 'upi' && tplS.showUpiPayment !== undefined) isEnabled = Boolean(tplS.showUpiPayment);
      else if (def.key === 'desk' && tplS.showDeskPayment !== undefined) isEnabled = Boolean(tplS.showDeskPayment);
      else if (def.key === 'netbanking' && tplS.showNetBankingPayment !== undefined) isEnabled = Boolean(tplS.showNetBankingPayment);
      else if (def.key === 'card' && tplS.showCardPayment !== undefined) isEnabled = Boolean(tplS.showCardPayment);

      return {
        ...def,
        ...(stored ? (typeof stored.toObject === 'function' ? stored.toObject() : stored) : {}),
        enabled: isEnabled,
        name: (def.key === 'upi' && tplS.upiPaymentLabel) ? tplS.upiPaymentLabel :
              (def.key === 'card' && tplS.cardPaymentLabel) ? tplS.cardPaymentLabel :
              (def.key === 'desk' && tplS.deskPaymentLabel) ? tplS.deskPaymentLabel :
              (def.key === 'netbanking' && tplS.netBankingPaymentLabel) ? tplS.netBankingPaymentLabel :
              (stored?.name || def.name),
        subtitle: (def.key === 'upi' && tplS.upiPaymentSubtext) ? tplS.upiPaymentSubtext :
                  (def.key === 'card' && tplS.cardPaymentSubtext) ? tplS.cardPaymentSubtext :
                  (def.key === 'desk' && tplS.deskPaymentSubtext) ? tplS.deskPaymentSubtext :
                  (def.key === 'netbanking' && tplS.netBankingPaymentSubtext) ? tplS.netBankingPaymentSubtext :
                  (stored?.subtitle || def.subtitle)
      };
    });

    storedMethods.forEach(sm => {
      if (!CANONICAL_PAYMENT_METHODS.some(def => def.key === sm.key)) {
        mergedPaymentMethods.push(typeof sm.toObject === 'function' ? sm.toObject() : sm);
      }
    });

    const enrichedBusinessProfile = {
      ...(typeof businessProfile?.toObject === 'function' ? businessProfile.toObject() : (businessProfile || {})),
      paymentMethods: mergedPaymentMethods
    };

    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.json({
      success: true,
      data: {
        businessName: businessProfile.businessName || 'Study Library',
        libraryName: businessProfile.businessName || 'Study Library',
        name: businessProfile.businessName || 'Study Library',
        tagline: businessProfile.tagline || 'Premier Air-Conditioned Reading Hall',
        logo: businessProfile.logo || '',
        favicon: businessProfile.favicon || '',
        stampImage: businessProfile.stampImage || '',
        bannerImage: businessProfile.bannerImage || '',
        phone: businessProfile.phone || '',
        email: businessProfile.email || '',
        address: businessProfile.address || '',
        city: businessProfile.city || '',
        state: businessProfile.state || '',
        pincode: businessProfile.pincode || '',
        gstNumber: businessProfile.gstNumber || '',
        registrationNumber: businessProfile.registrationNumber || '',
        upiId: businessProfile.upiId || 'thecozycorner@okaxis',
        upiQrCode: businessProfile.upiQrCode || '',
        bankDetails: businessProfile.bankDetails || {},
        businessProfile: enrichedBusinessProfile,
        paymentMethods: mergedPaymentMethods,
        branches: allBranches,
        shifts: shiftsWithCapacity,
        plans: enrichedPlans,
        template: activeTemplate,
        customFields: allFields,
        targetExams: businessProfile.targetExams || [],
        rules: businessProfile.rules || [],
        kioskVoice,
        livePunchStats,
        receiptConfig,
        currencySymbol: settingsMap['general.currencySymbol'] || '₹',
        dateFormat: settingsMap['general.dateFormat'] || 'DD/MM/YYYY'
      },
      message: 'Public configuration retrieved successfully'
    });
  } catch (error) {
    console.error('Error fetching public config:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
