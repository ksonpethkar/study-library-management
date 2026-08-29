const express = require('express');
const router = express.Router();
const { protect, optionalAuth } = require('../middleware/auth');
const Student = require('../models/Student');
const Seat = require('../models/Seat');
const Plan = require('../models/Plan');
const Payment = require('../models/Payment');
const Attendance = require('../models/Attendance');
const BusinessProfile = require('../models/BusinessProfile');
const ReceiptConfig = require('../models/ReceiptConfig');
const Notification = require('../models/Notification');
const { Referral, LeaveRequest, SeatChangeRequest, Announcement, Holiday, LostFound, Feedback } = require('../models/Operations');
const ReferralConfig = require('../models/ReferralConfig');

// @route   POST /api/student-portal/webhook/payment-captured
// @desc    Option B Webhook: Bank Gateway Payment Auto-Verification (Secured with Secret/Admin Auth)
router.post('/webhook/payment-captured', optionalAuth, async (req, res) => {
  try {
    const webhookSecret = req.headers['x-webhook-secret'];
    const expectedSecret = process.env.WEBHOOK_SECRET || process.env.JWT_SECRET;
    const isAuthorizedSecret = expectedSecret && webhookSecret === expectedSecret;
    const isAuthorizedAdmin = req.user && ['owner', 'branch_manager'].includes(req.user.role);

    if (!isAuthorizedSecret && !isAuthorizedAdmin) {
      return res.status(401).json({ success: false, message: 'Unauthorized webhook access: missing or invalid signature/secret' });
    }

    const { event, studentId, planId, utrNumber, amountPaid } = req.body;

    const student = await Student.findOne({ $or: [{ _id: studentId }, { studentId }] });
    if (!student) {
      return res.status(400).json({ success: false, message: 'Student not found for webhook payload' });
    }

    let durationDays = 30;
    const targetPlanId = planId || student.plan;
    if (targetPlanId) {
      const planDoc = await Plan.findById(targetPlanId).lean();
      if (planDoc) {
        const rawDur = planDoc.duration || 30;
        const dt = planDoc.durationType || 'days';
        durationDays = dt === 'months' ? rawDur * 30 : dt === 'years' ? rawDur * 365 : rawDur;
      }
    }
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

// @route   GET /api/student-portal/config
// @desc    Get dynamic feature flags and portal configurations
// @access  Public / Optional Auth
router.get('/config', async (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  try {
    const SystemSetting = require('../models/SystemSetting');
    const settings = await SystemSetting.find({ category: 'portal' }).lean();
    const portalConfig = {};
    settings.forEach(s => {
      const shortKey = s.key.replace(/^portal\./, '');
      portalConfig[shortKey] = s.value;
    });

    const businessProfile = await BusinessProfile.getProfile().catch(() => ({}));
    const receiptConfig = await ReceiptConfig.getConfig().catch(() => ({}));

    res.json({
      success: true,
      data: {
        features: portalConfig,
        businessProfile: {
          businessName: businessProfile.businessName,
          logo: businessProfile.logo,
          favicon: businessProfile.favicon,
          phone: businessProfile.phone,
          upiId: businessProfile.upiId,
          upiQrCode: businessProfile.upiQrCode
        },
        receiptConfig
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.use(protect);

/**
 * Helper to find student document for current authenticated user
 */
async function getStudentForUser(user, req = null) {
  if (!user) return null;
  const isAdmin = ['owner', 'branch_manager'].includes(user.role);
  const studentIdParam = req?.query?.studentId || req?.params?.studentId;

  // 0. If token explicitly contains studentId (e.g. from student login):
  if (user.studentId) {
    const student = await Student.findById(user.studentId).populate('plan').populate('seat').populate('branch').lean();
    if (student) return student;
  }

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
    let firstStudent = await Student.findOne({ status: 'active' })
      .populate('plan')
      .populate('seat')
      .populate('branch').lean();
    if (!firstStudent) {
      firstStudent = await Student.findOne()
        .populate('plan')
        .populate('seat')
        .populate('branch').lean();
    }
    return firstStudent;
  }

  return null;
}

// In-memory badge calculation cache (10 min TTL)
const _badgeCache = new Map();
const BADGE_CACHE_TTL = 10 * 60 * 1000;

/**
 * Helper to calculate attendance stats, streaks, and auto-award badges for a student
 */
async function calculateAndAwardBadges(studentId, forceRefresh = false) {
  try {
    const sid = String(studentId);
    if (!forceRefresh && _badgeCache.has(sid)) {
      const cached = _badgeCache.get(sid);
      if (Date.now() - cached.ts < BADGE_CACHE_TTL) {
        return cached.data;
      }
      _badgeCache.delete(sid);
    }

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

    const result = {
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

    _badgeCache.set(sid, { data: result, ts: Date.now() });
    return result;
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

    const isAdmin = ['owner', 'branch_manager'].includes(req.user.role);
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

    let completionScore = 0;
    if (student.name) completionScore += 15;
    if (student.phone) completionScore += 15;
    if (student.plan) completionScore += 15;
    if (student.seat) completionScore += 15;
    if (student.photo) completionScore += 25;
    if (student.idProof && (student.idProof.number || student.idProof.image)) completionScore += 15;
    student.profileCompletion = Math.min(100, completionScore);
    student.isProfileComplete = completionScore >= 100;

    const receiptConfig = await ReceiptConfig.getConfig().catch(() => ({}));

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
        badgeProgress: badgeResult ? badgeResult.badgeProgress : [],
        receiptConfig
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
// @desc    Student requests plan renewal with automated UPI intent or desk payment
router.post('/renew', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student record not found' });
    }

    const { planId, shiftId, months = 1, paymentMethod = 'upi', utrNumber, transactionId, amount, notes } = req.body;
    const finalTxnId = (transactionId || utrNumber || '').trim();

    let plan = null;
    if (planId) {
      plan = await Plan.findById(planId).lean();
    } else if (student.plan) {
      plan = await Plan.findById(student.plan).lean();
    }

    const payableAmount = Number(amount) || (plan ? (plan.price || plan.amount || 1000) * Number(months) : 1000);
    const durationDays = Number(months) * 30;

    // Calculate new validity range
    const currentValid = student.validUntil || student.expiryDate;
    const validFrom = (currentValid && new Date(currentValid) > new Date()) ? new Date(currentValid) : new Date();
    const validUntil = new Date(validFrom.getTime() + durationDays * 24 * 60 * 60 * 1000);

    const isPaidOnline = paymentMethod === 'upi' || paymentMethod === 'upi_gateway' || paymentMethod === 'bank_transfer' || paymentMethod === 'card';

    const payment = new Payment({
      student: student._id,
      plan: plan ? plan._id : (student.plan || null),
      amount: payableAmount,
      finalAmount: payableAmount,
      paymentMethod: paymentMethod === 'desk' ? 'cash' : (paymentMethod || 'upi'),
      transactionId: finalTxnId || `UPI_${Date.now()}`,
      referenceNumber: finalTxnId || `REF_${Date.now()}`,
      status: isPaidOnline ? 'paid' : 'pending',
      balanceDue: isPaidOnline ? 0 : payableAmount,
      periodStart: validFrom,
      periodEnd: validUntil,
      branch: student.branch?._id || student.branch || null,
      notes: notes || `Student Portal Renewal (${months} Month${months > 1 ? 's' : ''})`
    });

    await payment.save();

    if (isPaidOnline) {
      student.validUntil = validUntil;
      student.expiryDate = validUntil;
      student.status = 'active';
      if (planId) student.plan = planId;
      if (shiftId) student.shift = shiftId;
      await student.save();
    }

    await Notification.create({
      title: isPaidOnline ? `🎉 Renewal Confirmed: ${student.name}` : `Plan Renewal Request: ${student.name}`,
      message: isPaidOnline 
        ? `Student ${student.name} (${student.studentId || ''}) renewed plan for ${months} month(s) via UPI (₹${payableAmount}, Ref: ${payment.transactionId}).`
        : `Student ${student.name} (${student.studentId || ''}) requested membership renewal via Desk payment. Contact: ${student.phone}`,
      type: 'payment',
      link: '#/payments'
    });

    res.json({
      success: true,
      message: isPaidOnline 
        ? `🎉 Membership renewed successfully! 30 Days added to your plan.`
        : `Renewal request submitted to the administration. Please complete payment at the front desk!`,
      data: {
        payment,
        validUntil: student.validUntil || validUntil,
        status: isPaidOnline ? 'active' : 'pending_desk'
      }
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

// @route   GET /api/student-portal/branches
// @desc    Get active branches / study centres for student portal
router.get('/branches', async (req, res) => {
  try {
    const Branch = require('../models/Branch');
    const branches = await Branch.find({ isActive: true, isDeleted: { $ne: true } })
      .select('name code city address phone totalSeats')
      .sort('name')
      .lean();
    res.json({ success: true, data: branches || [] });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   GET /api/student-portal/available-seats
// @desc    Get all available/vacant desks for student portal seat transfer selection
router.get('/available-seats', async (req, res) => {
  try {
    const { branch } = req.query;
    let filter = {
      isActive: true,
      isDeleted: { $ne: true },
      status: { $in: ['available', 'vacant'] }
    };
    if (branch && branch !== 'all' && branch !== 'default_main') {
      filter.branch = branch;
    }
    const seats = await Seat.find(filter)
      .select('seatNumber zone floor status type priceMultiplier branch seatType')
      .populate('branch', 'name code city')
      .sort('seatNumber')
      .lean();
    res.json({ success: true, data: seats || [] });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/student-portal/seat-change
// @desc    Submit a seat change / transfer request
router.post('/seat-change', async (req, res) => {
  try {
    const student = await getStudentForUser(req.user, req);
    if (!student) return res.status(404).json({ success: false, message: 'Student record not found' });

    const SystemSetting = require('../models/SystemSetting');
    const flag = await SystemSetting.findOne({ key: 'portal.enableSeatTransfer' }).lean();
    if (flag && (flag.value === false || flag.value === 'false')) {
      return res.status(403).json({ success: false, message: 'Seat transfer requests are currently disabled by administrator.' });
    }

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
    const isWalletRequested = applyWallet === 'true' || applyWallet === true;
    
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

    const allPaymentMethods = Array.isArray(business.paymentMethods) ? business.paymentMethods : [
      { key: 'upi', enabled: true }, { key: 'card', enabled: true }, { key: 'netbanking', enabled: true }, { key: 'desk', enabled: true }
    ];
    const activePaymentMethods = allPaymentMethods.filter(m => m.enabled === true || m.enabled === 'true' || m.enabled === 1 || m.enabled === '1');
    const isOnlinePaymentEnabled = activePaymentMethods.length > 0;

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
        durationDays: (() => {
          const dur = selectedPlan?.duration || 30;
          const dt = selectedPlan?.durationType || 'days';
          if (dt === 'months') return dur * 30;
          if (dt === 'years') return dur * 365;
          return dur;
        })(),
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
        paymentMethods: activePaymentMethods,
        isOnlinePaymentEnabled,
        allMethodsDisabled: !isOnlinePaymentEnabled,
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

    const SystemSetting = require('../models/SystemSetting');
    const renewalFlag = await SystemSetting.findOne({ key: 'portal.enableOnlineRenewal' }).lean();
    if (renewalFlag && (renewalFlag.value === false || renewalFlag.value === 'false')) {
      return res.status(403).json({ success: false, message: 'Online fee renewal is currently disabled by administrator.' });
    }

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

    const rawDur = targetPlan?.duration || 30;
    const durType = targetPlan?.durationType || 'days';
    const durationDays = durType === 'months' ? rawDur * 30 : durType === 'years' ? rawDur * 365 : rawDur;
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
    const isGatewayVerified = Boolean(req.body.isGatewayVerified) || Boolean(req.body.razorpay_payment_id);
    const payment = new Payment({
      student: student._id,
      plan: targetPlan?._id || student.plan?._id || student.plan || null,
      amount: payAmount,
      finalAmount: payAmount,
      paymentMethod: paymentMode || 'upi',
      transactionId: cleanUtr,
      status: isGatewayVerified ? 'paid' : 'pending_verification',
      paymentDate: new Date(),
      periodStart: validFrom,
      periodEnd: validUntil,
      notes: isGatewayVerified
        ? `Online Self-Renewal Auto-Verified via Gateway (ID: ${req.body.razorpay_payment_id || cleanUtr})`
        : `Online Student Self-Renewal (UTR: ${cleanUtr}${walletDeduction > 0 ? ` • Wallet Discount: ₹${walletDeduction}` : ''}) • Pending Front Desk Verification`
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

    const { 
      photo, email, phone, gender, dob, dateOfBirth, bloodGroup, targetExams,
      collegeOrCompany, occupation, address, city, state, pincode,
      emergencyContact, emergencyContactName, emergencyContactPhone, emergencyContactRelation,
      idProof, idProofType, idProofNumber, idProofImage, customFields
    } = req.body;

    const updateData = {};
    if (photo !== undefined) updateData.photo = photo;
    if (email) updateData.email = email.trim();
    if (gender) updateData.gender = gender;
    const customF = customFields || {};
    const rawDob = dob || dateOfBirth || req.body.dateofbirth || req.body.date_of_birth || req.body.birthDate || customF.dateOfBirth || customF.dob || customF.dateofbirth || customF.date_of_birth;
    if (rawDob !== undefined) {
      const parsedDate = rawDob ? new Date(rawDob) : null;
      updateData.dateOfBirth = parsedDate && !isNaN(parsedDate.getTime()) ? parsedDate : null;
    }
    const rawBlood = bloodGroup || req.body.blood_group || req.body.bloodgroup || customF.bloodGroup || customF.blood_group || customF.bloodgroup;
    if (rawBlood !== undefined) updateData.bloodGroup = String(rawBlood).trim();
    if (targetExams) updateData.targetExams = Array.isArray(targetExams) ? targetExams : String(targetExams).split(',').map(e => e.trim()).filter(Boolean);
    if (collegeOrCompany || occupation) updateData.collegeOrCompany = (collegeOrCompany || occupation).trim();
    if (address) updateData.address = address.trim();
    if (city) updateData.city = city.trim();
    if (state) updateData.state = state.trim();
    if (pincode) updateData.pincode = pincode.trim();

    if (emergencyContact || emergencyContactName || emergencyContactPhone || req.body.emergency_contact || req.body.parentPhone || customF.emergencyContact || customF.emergencyContactPhone || customF.parentPhone) {
      updateData.emergencyContact = {
        name: (emergencyContact?.name || emergencyContactName || req.body.emergencyContactName || req.body.parentName || customF.emergencyContactName || customF.parentName || student.emergencyContact?.name || '').trim(),
        phone: (emergencyContact?.phone || emergencyContactPhone || req.body.emergencyContactPhone || req.body.emergencyContact || req.body.parentPhone || customF.emergencyContactPhone || customF.emergencyContact || customF.parentPhone || student.emergencyContact?.phone || '').trim(),
        relation: (emergencyContact?.relation || emergencyContactRelation || req.body.emergencyContactRelation || req.body.parentRelation || customF.emergencyContactRelation || customF.parentRelation || student.emergencyContact?.relation || 'Parent/Guardian').trim()
      };
    }

    if (idProof || idProofType || idProofNumber || idProofImage || req.body.id_proof_type || req.body.id_proof_number || req.body.idprooftype || req.body.idproofnumber || customF.idProofType || customF.idProofNumber || customF.idprooftype || customF.idproofnumber) {
      updateData.idProof = {
        type: (idProof?.type || idProofType || req.body.id_proof_type || req.body.idprooftype || customF.idProofType || customF.idprooftype || student.idProof?.type || 'Aadhaar Card').trim(),
        number: (idProof?.number || idProofNumber || req.body.id_proof_number || req.body.idproofnumber || customF.idProofNumber || customF.idproofnumber || student.idProof?.number || '').trim(),
        image: (idProof?.image || idProofImage || req.body.id_proof_image || req.body.idproofimage || customF.idProofImage || customF.idproofimage || student.idProof?.image || '').trim()
      };
    }

    if (customFields && typeof customFields === 'object') {
      updateData.customFields = customFields;
    }

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
      message: 'Student profile details updated successfully!',
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

// @route   POST /api/student-portal/change-password
// @desc    Change student login password/PIN
// @access  Private (Student)
router.post('/change-password', async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!newPassword || newPassword.trim().length < 4) {
      return res.status(400).json({ success: false, message: 'New password must be at least 4 characters long' });
    }

    const User = require('../models/User');
    const user = await User.findById(req.user._id).select('+password');
    if (!user) {
      return res.status(404).json({ success: false, message: 'User record not found' });
    }

    if (currentPassword && user.password) {
      const isMatch = await user.comparePassword(currentPassword);
      if (!isMatch) {
        return res.status(400).json({ success: false, message: 'Current password is incorrect' });
      }
    }

    user.password = newPassword.trim();
    await user.save();

    res.json({
      success: true,
      message: 'Password changed successfully!'
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ----------------------------------------------------
// 📢 Student Notice Board & Announcements
// ----------------------------------------------------
router.get('/announcements', protect, async (req, res) => {
  try {
    const student = await Student.findOne({ user: req.user._id }).lean();
    const query = {
      $or: [
        { branch: { $exists: false } },
        { branch: null }
      ]
    };
    if (student && student.branch) {
      query.$or.push({ branch: student.branch });
    }
    const announcements = await Announcement.find(query).sort({ isPinned: -1, createdAt: -1 }).lean();
    res.json({ success: true, data: announcements });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ----------------------------------------------------
// 📅 Student Holiday Calendar
// ----------------------------------------------------
router.get('/holidays', protect, async (req, res) => {
  try {
    const holidays = await Holiday.find().sort({ date: 1, startDate: 1 }).lean();
    res.json({ success: true, data: holidays });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ----------------------------------------------------
// 🔍 Student Lost & Found Hub
// ----------------------------------------------------
router.get('/lost-found', protect, async (req, res) => {
  try {
    const items = await LostFound.find().sort({ createdAt: -1 }).limit(50).lean();
    res.json({ success: true, data: items });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/lost-found', protect, async (req, res) => {
  try {
    const student = await Student.findOne({ user: req.user._id }).lean();
    const { itemName, description, category, foundLocation, status } = req.body;
    if (!itemName) {
      return res.status(400).json({ success: false, message: 'Item name is required' });
    }
    const item = await LostFound.create({
      itemName,
      description: `${description || ''} (Reported by: ${student?.name || req.user.name})`.trim(),
      category: category || 'other',
      foundLocation: foundLocation || 'Library Campus',
      status: status || 'found',
      claimedBy: ''
    });
    res.json({ success: true, data: item, message: 'Lost & Found report submitted successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ----------------------------------------------------
// 💬 Student Feedback & Helpdesk
// ----------------------------------------------------
router.get('/feedback', protect, async (req, res) => {
  try {
    const student = await Student.findOne({ user: req.user._id }).lean();
    const studentName = student?.name || req.user.name;
    const feedbacks = await Feedback.find({ studentName }).sort({ createdAt: -1 }).lean();
    res.json({ success: true, data: feedbacks });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/feedback', protect, async (req, res) => {
  try {
    const student = await Student.findOne({ user: req.user._id }).lean();
    const { category, rating, message } = req.body;
    if (!message) {
      return res.status(400).json({ success: false, message: 'Feedback message cannot be empty' });
    }
    const fb = await Feedback.create({
      studentName: student?.name || req.user.name,
      category: category || 'other',
      rating: Number(rating) || 5,
      message: message.trim(),
      status: 'pending'
    });
    res.json({ success: true, data: fb, message: 'Thank you! Your feedback has been submitted to management.' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
