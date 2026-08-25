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
router.get('/public-config', memoryCache.middleware(30), async (req, res) => {
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
        businessProfile: businessProfile,
        branches: allBranches,
        shifts: shiftsWithCapacity,
        plans: allPlans,
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
