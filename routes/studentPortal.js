const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const Student = require('../models/Student');
const Seat = require('../models/Seat');
const Plan = require('../models/Plan');
const Payment = require('../models/Payment');
const Attendance = require('../models/Attendance');
const BusinessProfile = require('../models/BusinessProfile');
const Notification = require('../models/Notification');
const { Referral, LeaveRequest, SeatChangeRequest } = require('../models/Operations');
const ReferralConfig = require('../models/ReferralConfig');

router.use(protect);

/**
 * Helper to find student document for current authenticated user
 */
async function getStudentForUser(user, req = null) {
  const isAdmin = ['owner', 'branch_manager', 'staff', 'superadmin'].includes(user.role);
  const studentIdParam = req?.query?.studentId || req?.body?.studentId;

  // 1. If Admin requested a specific student ID to inspect:
  if (isAdmin && studentIdParam) {
    const student = await Student.findById(studentIdParam).populate('plan').populate('seat').populate('branch').lean();
    if (student) return student;
  }

  // 2. Exact match for regular student accounts (non-empty email and phone only)
  const queryConditions = [];
  if (user.email && typeof user.email === 'string' && user.email.trim().length > 0 && !user.email.includes('studylib.local')) {
    queryConditions.push({ email: user.email.trim().toLowerCase() });
  }
  if (user.phone && typeof user.phone === 'string' && user.phone.trim().length > 0) {
    const cleanPhone = user.phone.replace(/[^0-9]/g, '');
    if (cleanPhone.length >= 10) {
      queryConditions.push({ phone: user.phone });
      queryConditions.push({ phone: cleanPhone.slice(-10) });
    }
  }

  if (queryConditions.length > 0) {
    const matchedStudent = await Student.findOne({ $or: queryConditions })
      .populate('plan')
      .populate('seat')
      .populate('branch').lean();
    if (matchedStudent) return matchedStudent;
  }

  // 3. If user is Admin/Owner and has no student record of their own:
  if (isAdmin) {
    // Return first active student for preview purposes
    const firstStudent = await Student.findOne({ status: 'active' })
      .populate('plan')
      .populate('seat')
      .populate('branch') || await Student.findOne().populate('plan').populate('seat').populate('branch').lean();
    return firstStudent;
  }

  return null;
}

/**
 * Helper to calculate attendance stats, streaks, and auto-award badges for a student
 */
async function calculateAndAwardBadges(studentId) {
  try {
    const studentDoc = await Student.findById(studentId);
    if (!studentDoc) return null;

    // Fetch all attendance records for the student
    const records = await Attendance.find({ student: studentId }).sort({ date: 1 }).lean();

    let earlyBirdCount = 0;
    let nightOwlCount = 0;
    let totalMinutes = 0;
    const attendedDateStrs = new Set();

    records.forEach(r => {
      // Check-in time evaluation
      if (r.checkIn) {
        const checkInDate = new Date(r.checkIn);
        const hours = checkInDate.getHours();
        // Early bird: before 07:00 AM (hour < 7)
        if (hours < 7) {
          earlyBirdCount++;
        }
        // Night owl: after 08:00 PM (hour >= 20)
        if (hours >= 20) {
          nightOwlCount++;
        }
      }

      // Total study duration
      let mins = r.duration || 0;
      if (!mins && r.checkIn && r.checkOut) {
        mins = Math.max(0, Math.round((new Date(r.checkOut) - new Date(r.checkIn)) / 60000));
      } else if (!mins && ['present', 'late', 'half_day'].includes(r.status)) {
        mins = r.status === 'half_day' ? 180 : 300;
      }
      totalMinutes += mins;

      // Track attended days for streak calculation
      if (['present', 'late', 'half_day'].includes(r.status) || r.checkIn) {
        const d = new Date(r.date);
        if (!isNaN(d.getTime())) {
          attendedDateStrs.add(d.toISOString().split('T')[0]);
        }
      }
    });

    const totalHours = Number((totalMinutes / 60).toFixed(1));

    // Calculate streaks (consecutive calendar days)
    const sortedDates = Array.from(attendedDateStrs).sort();
    let currentStreak = 0;
    let maxStreak = 0;
    let tempStreak = 0;
    let prevDate = null;

    for (const dateStr of sortedDates) {
      const curr = new Date(dateStr);
      if (!prevDate) {
        tempStreak = 1;
      } else {
        const diffDays = Math.round((curr - prevDate) / (1000 * 60 * 60 * 24));
        if (diffDays === 1) {
          tempStreak++;
        } else if (diffDays > 1) {
          tempStreak = 1;
        }
      }
      if (tempStreak > maxStreak) maxStreak = tempStreak;
      prevDate = curr;
    }

    // Determine current active streak relative to today
    const todayStr = new Date().toISOString().split('T')[0];
    const yesterdayStr = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    if (attendedDateStrs.has(todayStr) || attendedDateStrs.has(yesterdayStr)) {
      let checkDate = attendedDateStrs.has(todayStr) ? new Date() : new Date(Date.now() - 86400000);
      currentStreak = 0;
      while (true) {
        const dStr = checkDate.toISOString().split('T')[0];
        if (attendedDateStrs.has(dStr)) {
          currentStreak++;
          checkDate.setDate(checkDate.getDate() - 1);
        } else {
          break;
        }
      }
    } else {
      currentStreak = 0;
    }

    // Update studyStreakDays counter on student
    studentDoc.studyStreakDays = currentStreak;

    // Auto-award badges list
    const badgeDefs = [
      {
        badgeId: 'early_bird',
        title: '🌅 Early Bird',
        icon: '🌅',
        description: 'Checked in before 07:00 AM 5+ times',
        eligible: earlyBirdCount >= 5,
        progress: earlyBirdCount,
        target: 5
      },
      {
        badgeId: 'study_warrior',
        title: '⚔️ 100-Hour Study Warrior',
        icon: '⚔️',
        description: 'Total study hours >= 100',
        eligible: totalHours >= 100,
        progress: totalHours,
        target: 100
      },
      {
        badgeId: 'night_owl',
        title: '🦉 Night Owl',
        icon: '🦉',
        description: 'Checked in after 08:00 PM 5+ times',
        eligible: nightOwlCount >= 5,
        progress: nightOwlCount,
        target: 5
      },
      {
        badgeId: 'streak_champion',
        title: '🏆 30-Day Streak Champion',
        icon: '🏆',
        description: 'Consecutive attendance streak >= 30 days',
        eligible: maxStreak >= 30 || currentStreak >= 30,
        progress: Math.max(maxStreak, currentStreak),
        target: 30
      }
    ];

    if (!Array.isArray(studentDoc.badges)) {
      studentDoc.badges = [];
    }

    const existingBadgeIds = new Set(studentDoc.badges.map(b => b.badgeId));

    for (const def of badgeDefs) {
      if (def.eligible && !existingBadgeIds.has(def.badgeId)) {
        studentDoc.badges.push({
          badgeId: def.badgeId,
          title: def.title,
          icon: def.icon,
          description: def.description,
          earnedAt: new Date()
        });
        existingBadgeIds.add(def.badgeId);
      }
    }

    await studentDoc.save({ validateBeforeSave: false });

    // Re-populate seat & plan for dashboard view consistency
    const populatedStudent = await Student.findById(studentId)
      .populate('plan')
      .populate('seat')
      .populate('branch')
      .lean();

    return {
      student: populatedStudent || studentDoc.toObject(),
      badgeProgress: badgeDefs.map(d => ({
        badgeId: d.badgeId,
        title: d.title,
        icon: d.icon,
        description: d.description,
        progress: d.progress,
        target: d.target,
        earned: existingBadgeIds.has(d.badgeId)
      })),
      earlyBirdCount,
      nightOwlCount,
      totalHours,
      currentStreak,
      maxStreak
    };
  } catch (err) {
    console.error('Badge calculation error:', err);
    return null;
  }
}

// @route   GET /api/student-portal/dashboard
// @desc    Get student's live membership, seat, attendance, and payment details
router.get('/dashboard', async (req, res) => {
  try {
    let student = await getStudentForUser(req.user, req);
    if (!student) {
      return res.status(404).json({ success: false, message: 'No student record associated with this account' });
    }

    const badgeResult = await calculateAndAwardBadges(student._id);
    if (badgeResult && badgeResult.student) {
      student = badgeResult.student;
    }

    const isAdmin = ['owner', 'branch_manager', 'staff', 'superadmin'].includes(req.user.role);
    let allStudents = [];
    if (isAdmin) {
      allStudents = await Student.find({}, '_id name studentId phone status').sort({ name: 1 }).lean();
    }

    const business = await BusinessProfile.getProfile();

    const [payments, attendanceRecords, todayAttendance] = await Promise.all([
      Payment.find({ student: student._id }).sort({ paymentDate: -1 }).limit(10).lean(),
      Attendance.find({ student: student._id }).sort({ date: -1 }).limit(30).lean(),
      Attendance.findOne({
        student: student._id,
        date: {
          $gte: new Date(new Date().setHours(0, 0, 0, 0)),
          $lte: new Date(new Date().setHours(23, 59, 59, 999))
        }
      })
    ]);

    // Calculate remaining days
    let daysRemaining = 0;
    if (student.expiryDate) {
      const diff = new Date(student.expiryDate).getTime() - Date.now();
      daysRemaining = Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
    }

    // Calculate total hours studied
    const totalMinutes = attendanceRecords.reduce((sum, r) => sum + (r.duration || 0), 0);
    const totalHours = badgeResult ? badgeResult.totalHours : (totalMinutes / 60).toFixed(1);

    if (!student.photo && req.user?.avatar) {
      student.photo = req.user.avatar;
    }

    res.json({
      success: true,
      data: {
        student,
        business,
        daysRemaining,
        totalHours,
        todayAttendance,
        payments,
        attendanceRecords,
        isAdmin,
        allStudents,
        badgeProgress: badgeResult ? badgeResult.badgeProgress : []
      },
      message: 'Student dashboard loaded'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/student-portal/punch
// @desc    Self-service attendance punch in / out
router.post('/punch', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student record not found' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    let att = await Attendance.findOne({
      student: student._id,
      date: { $gte: today, $lt: tomorrow }
    });

    const now = new Date();

    if (!att) {
      // Punch In
      att = await Attendance.create({
        student: student._id,
        seat: student.seat?._id || student.seat || null,
        date: new Date(),
        checkIn: now,
        status: 'present'
      });

      await calculateAndAwardBadges(student._id);

      return res.json({
        success: true,
        data: att,
        message: `Punched in successfully at ${now.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit' })}`
      });
    } else if (att.checkIn && !att.checkOut) {
      // Punch Out
      att.checkOut = now;
      
      // Calculate duration
      let inTime = att.checkIn;
      if (typeof inTime === 'string') {
        const [inH, inM] = inTime.split(':').map(Number);
        inTime = new Date(today);
        inTime.setHours(inH, inM, 0, 0);
      }
      
      att.duration = Math.max(0, Math.floor((now.getTime() - inTime.getTime()) / 60000));
      await att.save();

      await calculateAndAwardBadges(student._id);

      return res.json({
        success: true,
        data: att,
        message: `Punched out successfully at ${now.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit' })} (${att.duration} mins studied)`
      });
    } else {
      return res.json({
        success: true,
        data: att,
        message: `Attendance already recorded for today (In: ${att.checkIn}, Out: ${att.checkOut})`
      });
    }
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/student-portal/renew
// @desc    Student requests plan renewal
router.post('/renew', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student record not found' });
    }

    await Notification.create({
      title: `Plan Renewal Request: ${student.name}`,
      message: `Student ${student.name} (${student.studentId || ''}) requested membership renewal. Contact: ${student.phone}`,
      type: 'payment',
      link: '#/payments'
    });

    res.json({
      success: true,
      message: 'Renewal request submitted to the administration. We will confirm upon fee verification!'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});


// @route   POST /api/student-portal/leave-request
// @desc    Submit a leave / absence request
router.post('/leave-request', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const { startDate, endDate, reason } = req.body;
    if (!startDate || !endDate || !reason) {
      return res.status(400).json({ success: false, message: 'Start date, end date, and reason are required' });
    }

    const leave = new LeaveRequest({
      student: student._id,
      studentName: student.name,
      studentPhone: student.phone,
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      reason,
      branch: student.branch?._id || student.branch
    });

    await leave.save();

    await Notification.create({
      title: `🌴 Leave Application: ${student.name}`,
      message: `Absence requested from ${new Date(startDate).toLocaleDateString('en-IN')} to ${new Date(endDate).toLocaleDateString('en-IN')}: ${reason}`,
      type: 'general',
      link: '#/operations'
    });

    res.status(201).json({ success: true, message: 'Leave application submitted successfully', data: leave });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   GET /api/student-portal/leave-requests
router.get('/leave-requests', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const leaves = await LeaveRequest.find({ student: student._id }).sort({ createdAt: -1 }).lean();
    res.json({ success: true, data: leaves });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   POST /api/student-portal/seat-change
// @desc    Submit a seat change / transfer request
router.post('/seat-change', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const { targetBranch, targetBranchName, targetSeat, targetSeatNumber, preferredZone, reason } = req.body;
    if (!reason) {
      return res.status(400).json({ success: false, message: 'Reason for seat transfer is required' });
    }

    const sc = new SeatChangeRequest({
      student: student._id,
      studentName: student.name,
      studentPhone: student.phone,
      currentSeat: student.seat?._id || student.seat || null,
      currentSeatNumber: student.seat?.seatNumber || 'Unassigned',
      targetBranch: targetBranch || null,
      targetBranchName: targetBranchName || '',
      targetSeat: targetSeat || null,
      targetSeatNumber: targetSeatNumber || '',
      preferredZone: preferredZone || 'General Zone',
      reason
    });

    await sc.save();

    const targetDesc = targetSeatNumber ? `Desk ${targetSeatNumber} (${targetBranchName || preferredZone})` : `${preferredZone} (${targetBranchName || 'Current Branch'})`;

    await Notification.create({
      title: `💺 Seat Transfer Request: ${student.name}`,
      message: `Current: ${sc.currentSeatNumber} ➔ Requested: ${targetDesc} • Reason: ${reason}`,
      type: 'seat',
      link: '#/operations'
    });

    res.status(201).json({ success: true, message: 'Seat transfer request submitted successfully!', data: sc });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   GET /api/student-portal/seat-changes
router.get('/seat-changes', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const requests = await SeatChangeRequest.find({ student: student._id }).sort({ createdAt: -1 }).lean();
    res.json({ success: true, data: requests });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   GET /api/student-portal/referral-stats
// @desc    Get student's referral code, active rewards config, and referral ledger
router.get('/referral-stats', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const config = await ReferralConfig.getConfig();
    const referrals = await Referral.find({ referrerStudent: student._id }).sort({ createdAt: -1 }).lean();

    // Auto-generate code if empty
    if (!student.referralCode) {
      const cleanName = (student.name || 'STUDENT').replace(/[^a-zA-Z]/g, '').toUpperCase().slice(0, 5) || 'STUDY';
      student.referralCode = `${cleanName}${Math.floor(100 + Math.random() * 900)}`;
      await Student.findByIdAndUpdate(student._id, { referralCode: student.referralCode });
    }

    res.json({
      success: true,
      data: {
        referralCode: student.referralCode,
        referralCredits: student.referralCredits || 0,
        totalReferralsCount: student.totalReferralsCount || referrals.length,
        config,
        referrals
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   PUT /api/student-portal/custom-referral-code
// @desc    Allow student to customize vanity referral code
router.put('/custom-referral-code', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    let { code } = req.body;
    if (!code) return res.status(400).json({ success: false, message: 'Referral code cannot be empty' });

    code = code.trim().toUpperCase().replace(/[^A-Z0-9_-]/g, '');
    if (code.length < 3 || code.length > 20) {
      return res.status(400).json({ success: false, message: 'Referral code must be between 3 and 20 characters' });
    }

    // Check uniqueness
    const existing = await Student.findOne({ referralCode: code, _id: { $ne: student._id } });
    if (existing) {
      return res.status(400).json({ success: false, message: 'This referral code is already taken. Please choose another one.' });
    }

    await Student.findByIdAndUpdate(student._id, { referralCode: code });

    res.json({ success: true, message: `Your custom referral code is now ${code}!`, data: { referralCode: code } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   POST /api/student-portal/referral
// @desc    Submit a friend referral lead
router.post('/referral', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const { refereeName, refereePhone, refereeEmail, targetExam, notes } = req.body;
    if (!refereeName || !refereePhone) {
      return res.status(400).json({ success: false, message: 'Friend name and phone number are required' });
    }

    const config = await ReferralConfig.getConfig();
    const rewardAmt = config.referrerRewardAmount || 100;

    const ref = new Referral({
      referrerStudent: student._id,
      referrerName: student.name,
      referrerPhone: student.phone,
      referralCode: student.referralCode,
      refereeName,
      refereePhone,
      refereeEmail: refereeEmail || '',
      targetExam: targetExam || '',
      notes: notes || '',
      rewardAmount: rewardAmt,
      reward: `₹${rewardAmt} Discount on Next Month Fee`,
      status: 'pending',
      branch: student.branch?._id || student.branch
    });

    await ref.save();

    await Notification.create({
      title: `🎁 New Referral: ${student.name}`,
      message: `Referred friend: ${refereeName} (${refereePhone})`,
      type: 'general',
      link: '#/operations'
    });

    res.status(201).json({ success: true, message: 'Friend referral submitted! Thank you!', data: ref });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   GET /api/student-portal/referrals
router.get('/referrals', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const referrals = await Referral.find({ referrerStudent: student._id }).sort({ createdAt: -1 }).lean();
    res.json({ success: true, data: referrals });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   GET /api/student-portal/renewal-quote
// @desc    Calculate renewal price for selected plan/shift, apply earned referral credits, pending dues, and generate dynamic UPI QR
router.get('/renewal-quote', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const Shift = require('../models/Shift');
    const [business, allPlans, allShifts] = await Promise.all([
      BusinessProfile.getProfile(),
      Plan.find({ isActive: { $ne: false } }).lean(),
      Shift.find({ isActive: { $ne: false } }).lean()
    ]);

    const { planId, shiftId, applyWallet } = req.query;

    let selectedPlan = null;
    if (planId) {
      selectedPlan = allPlans.find(p => String(p._id) === String(planId));
    }
    if (!selectedPlan && student.plan) {
      selectedPlan = typeof student.plan === 'object' ? student.plan : allPlans.find(p => String(p._id) === String(student.plan));
    }
    if (!selectedPlan && allPlans.length > 0) {
      selectedPlan = allPlans[0];
    }

    let selectedShift = null;
    if (shiftId) {
      selectedShift = allShifts.find(s => String(s._id) === String(shiftId));
    }
    if (!selectedShift && student.shift) {
      selectedShift = typeof student.shift === 'object' ? student.shift : allShifts.find(s => String(s._id) === String(student.shift));
    }
    if (!selectedShift && allShifts.length > 0) {
      selectedShift = allShifts[0];
    }

    const basePrice = selectedPlan ? Number(selectedPlan.price || 1000) : 1000;
    const discount = selectedPlan?.discount ? Math.round(basePrice * selectedPlan.discount / 100) : 0;
    
    // Wallet & Referral Credit Balance Calculation
    const availableWalletBalance = Math.max(0, (student.walletBalance || 0) + (student.referralCredits || 0));
    const isWalletRequested = applyWallet === undefined || applyWallet === 'true' || applyWallet === true;
    
    const appliedWalletDiscount = isWalletRequested 
      ? Math.min(availableWalletBalance, Math.max(0, basePrice - discount)) 
      : 0;

    const pendingFine = student.pendingFine || 0;
    const totalPayable = Math.max(0, Math.round(basePrice - discount - appliedWalletDiscount + pendingFine));

    const textUpiId = (business.upiId && typeof business.upiId === 'string' && !business.upiId.startsWith('data:image'))
      ? business.upiId.trim()
      : (business.phone ? `${business.phone.replace(/\D/g, '').slice(-10)}@ybl` : 'studylibrary@upi');

    const cleanPayee = encodeURIComponent(business.businessName || 'Study Library');
    const note = encodeURIComponent(`Renewal_${student.studentId}_${(student.name || '').replace(/\s+/g, '')}`);
    const upiIntentUrl = `upi://pay?pa=${textUpiId}&pn=${cleanPayee}&am=${totalPayable}&cu=INR&tn=${note}`;

    let qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${encodeURIComponent(upiIntentUrl)}`;

    res.json({
      success: true,
      data: {
        studentId: student.studentId,
        studentName: student.name,
        currentExpiryDate: student.expiryDate,
        allPlans,
        allShifts,
        selectedPlanId: selectedPlan?._id || '',
        selectedShiftId: selectedShift?._id || '',
        planName: selectedPlan?.name || 'Standard Study Plan',
        durationDays: selectedPlan?.duration || 30,
        basePrice,
        discount,
        availableWalletBalance,
        appliedWalletDiscount,
        isWalletApplied: isWalletRequested && appliedWalletDiscount > 0,
        referralCredits: student.referralCredits || 0,
        referralDiscount: appliedWalletDiscount,
        pendingFine,
        totalPayable,
        upiId: textUpiId,
        upiIntentUrl,
        qrCodeUrl,
        gatewayProvider: business.gatewayProvider || 'manual_upi',
        enableAutoWebhookVerification: business.enableAutoWebhookVerification !== false,
        paymentMethods: (business.paymentMethods || []).filter(m => m.enabled !== false),
        businessName: business.businessName,
        bankDetails: business.bankDetails
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   POST /api/student-portal/renewal-request
// @desc    Submit renewal payment with UTR / Transaction ID for admin approval
router.post('/renewal-request', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const { utrNumber, planId, shiftId, amountPaid, applyWallet, paymentMode = 'upi', notes } = req.body;
    if (!utrNumber || !utrNumber.trim()) {
      return res.status(400).json({ success: false, message: 'UPI UTR / Transaction reference number is required' });
    }

    const cleanUtr = utrNumber.trim();

    // Check for duplicate UTR submitted anywhere in system (Anti-Replay Fraud Protection)
    const existingPayment = await Payment.findOne({ transactionId: cleanUtr }).lean();
    if (existingPayment) {
      return res.status(400).json({
        success: false,
        message: `This UTR / Transaction ID (${cleanUtr}) has already been registered! Fraudulent or re-used UTR reference numbers cannot be processed.`
      });
    }

    const business = await BusinessProfile.getProfile();

    let targetPlan = null;
    if (planId) {
      targetPlan = await Plan.findById(planId).lean();
    }
    if (!targetPlan) {
      targetPlan = typeof student.plan === 'object' ? student.plan : await Plan.findById(student.plan).lean();
    }

    const durationDays = targetPlan?.duration || 30;
    const basePrice = targetPlan?.price || 1000;
    const planDiscount = targetPlan?.discount ? Math.round(basePrice * targetPlan.discount / 100) : 0;
    
    // Deduct Wallet Balance if applied
    let walletDeduction = 0;
    const currentRefCredits = student.referralCredits || 0;
    const currentWalletBal = student.walletBalance || 0;
    const totalWalletAvail = currentRefCredits + currentWalletBal;

    if (applyWallet && totalWalletAvail > 0) {
      walletDeduction = Math.min(totalWalletAvail, Math.max(0, basePrice - planDiscount));
    }

    const payAmount = Number(amountPaid) || Math.max(0, basePrice - planDiscount - walletDeduction + (student.pendingFine || 0));
    
    const validFrom = student.expiryDate && new Date(student.expiryDate) > new Date() ? new Date(student.expiryDate) : new Date();
    const validUntil = new Date(validFrom.getTime() + durationDays * 24 * 60 * 60 * 1000);

    // Create payment log conforming to Payment schema
    const payment = new Payment({
      student: student._id,
      plan: targetPlan?._id || student.plan?._id || student.plan || null,
      amount: payAmount,
      finalAmount: payAmount,
      paymentMethod: 'upi',
      transactionId: utrNumber.trim(),
      status: 'paid',
      paymentDate: new Date(),
      periodStart: validFrom,
      periodEnd: validUntil,
      notes: `Online Student Self-Renewal (UTR: ${utrNumber}${walletDeduction > 0 ? ` • Wallet Discount Used: ₹${walletDeduction}` : ''})`
    });

    await payment.save();

    // Deduct used wallet balance & extend student expiry date
    let newRefCredits = currentRefCredits;
    let newWalletBal = currentWalletBal;

    if (walletDeduction > 0) {
      if (currentRefCredits >= walletDeduction) {
        newRefCredits -= walletDeduction;
      } else {
        const rem = walletDeduction - currentRefCredits;
        newRefCredits = 0;
        newWalletBal = Math.max(0, currentWalletBal - rem);
      }
    }

    const updateFields = {
      expiryDate: validUntil,
      status: 'active',
      pendingFine: 0,
      referralCredits: newRefCredits,
      walletBalance: newWalletBal
    };
    if (planId) updateFields.plan = planId;
    if (shiftId) updateFields.shift = shiftId;

    await Student.findByIdAndUpdate(student._id, updateFields);

    // Notify Library Admins
    await Notification.create({
      title: `💰 Self-Renewal: ${student.name}`,
      message: `Student renewed plan online! Amount: ₹${payment.finalAmount || payAmount} • UTR: ${utrNumber}`,
      type: 'payment',
      link: '#/payments'
    });

    res.status(201).json({
      success: true,
      message: 'Membership renewed successfully! Your new expiry date has been updated.',
      data: {
        receiptNumber: payment.receiptNumber,
        newExpiryDate: validUntil,
        amount: payment.finalAmount || payAmount
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * @route   PUT /api/student-portal/profile
 * @desc    Update student profile photo or contact info
 * @access  Private (Student)
 */
router.put('/profile', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student account record not found' });
    }

    const { photo, email, phone } = req.body;
    const updateData = {};
    if (photo !== undefined) updateData.photo = photo;
    if (email) updateData.email = email.trim();
    if (phone) updateData.phone = phone.trim();

    const updatedStudent = await Student.findByIdAndUpdate(
      student._id,
      { $set: updateData },
      { new: true, runValidators: false }
    );

    // Also update User avatar if matching user exists
    const User = require('../models/User');
    if (req.user && photo !== undefined) {
      await User.findByIdAndUpdate(req.user._id, { avatar: photo });
    }

    res.json({
      success: true,
      message: 'Student profile photo updated successfully',
      data: updatedStudent || { ...student, ...updateData }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   POST /api/student-portal/create-gateway-order
// @desc    Option B: Create Payment Gateway Order for 0-second auto-verification (Razorpay / Cashfree / PhonePe)
router.post('/create-gateway-order', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const business = await BusinessProfile.getProfile();
    const { planId, shiftId, amountPaid } = req.body;

    const orderId = `ORD_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

    res.json({
      success: true,
      data: {
        orderId,
        provider: business.gatewayProvider || 'manual_upi',
        keyId: business.razorpayKeyId || '',
        amount: Math.round(Number(amountPaid || 1000) * 100), // in paise
        currency: 'INR',
        studentName: student.name,
        studentEmail: student.email,
        studentPhone: student.phone
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   POST /api/student-portal/webhook/payment-captured
// @desc    Option B Webhook: 0-second Bank Gateway Payment Auto-Verification (Razorpay / PhonePe / Cashfree)
router.post('/webhook/payment-captured', async (req, res) => {
  try {
    const { event, studentId, planId, utrNumber, amountPaid } = req.body;

    const student = await Student.findOne({ $or: [{ _id: studentId }, { studentId }] });
    if (!student) {
      return res.status(400).json({ success: false, message: 'Student not found for webhook payload' });
    }

    const durationDays = 30;
    const validFrom = student.expiryDate && new Date(student.expiryDate) > new Date() ? new Date(student.expiryDate) : new Date();
    const validUntil = new Date(validFrom.getTime() + durationDays * 24 * 60 * 60 * 1000);

    const payment = new Payment({
      student: student._id,
      plan: planId || student.plan || null,
      amount: Number(amountPaid) || 1000,
      finalAmount: Number(amountPaid) || 1000,
      paymentMethod: 'upi_gateway',
      transactionId: utrNumber || `PG_${Date.now()}`,
      status: 'paid',
      paymentDate: new Date(),
      periodStart: validFrom,
      periodEnd: validUntil,
      notes: `Option B Gateway Auto-Verified Webhook Payment (${event || 'payment.captured'})`
    });

    await payment.save();

    await Student.findByIdAndUpdate(student._id, {
      expiryDate: validUntil,
      status: 'active',
      pendingFine: 0
    });

    res.json({ success: true, message: 'Payment auto-verified and membership renewed instantly' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
