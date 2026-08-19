const express = require('express');
const router = express.Router();
const { body, query, validationResult } = require('express-validator');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');
const Attendance = require('../models/Attendance');

// express-validator wrapper for Express 5
function validate(validations) {
  return async (req, res, next) => {
    for (const validation of validations) {
      await validation.run(req);
    }
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array(),
        message: errors.array()[0]?.msg || 'Validation failed'
      });
    }
    next();
  };
}

// GET / - List attendance records
router.get('/', protect, async (req, res) => {
  try {
    const { date, student, status, page = 1, limit = 50 } = req.query;
    const filter = {};
    if (date) {
      const startOfDay = new Date(date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(date);
      endOfDay.setHours(23, 59, 59, 999);
      filter.date = { $gte: startOfDay, $lte: endOfDay };
    }
    if (student) filter.student = student;
    if (status) filter.status = status;

    const total = await Attendance.countDocuments(filter);
    const records = await Attendance.find(filter)
      .populate('student', 'name studentId phone')
      .populate('seat', 'seatNumber')
      .sort({ date: -1, createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    res.json({
      success: true,
      data: { records, total, page: parseInt(page), limit: parseInt(limit) },
      message: 'Attendance records fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /today - Today's attendance
router.get('/today', protect, async (req, res) => {
  try {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const records = await Attendance.find({ date: { $gte: startOfDay, $lte: endOfDay } })
      .populate('student', 'name studentId phone')
      .populate('seat', 'seatNumber')
      .sort({ createdAt: -1 });
      
    const stats = await Attendance.getTodayStats();

    res.json({
      success: true,
      data: { records, stats },
      message: "Today's attendance fetched successfully"
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /student/:studentId - Attendance history for a student
router.get('/student/:studentId', protect, async (req, res) => {
  try {
    const records = await Attendance.find({ student: req.params.studentId })
      .populate('seat', 'seatNumber')
      .sort({ date: -1 });

    res.json({
      success: true,
      data: records,
      message: 'Student attendance history fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /analytics/:studentId - AI Study Habit & Attendance Analytics (90-day window)
router.get('/analytics/:studentId', protect, async (req, res) => {
  try {
    const Student = require('../models/Student');
    const mongoose = require('mongoose');
    const paramId = req.params.studentId;
    let student = null;

    if (paramId === 'me') {
      student = await Student.findOne({
        $or: [
          { email: req.user.email },
          { phone: req.user.phone }
        ]
      });
    } else if (mongoose.Types.ObjectId.isValid(paramId)) {
      student = await Student.findById(paramId);
      if (!student) {
        student = await Student.findOne({ studentId: paramId });
      }
    } else {
      student = await Student.findOne({ studentId: paramId });
    }

    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    // Past 90 Days Range
    const now = new Date();
    const endOfToday = new Date(now);
    endOfToday.setHours(23, 59, 59, 999);

    const startOf90Days = new Date(now);
    startOf90Days.setDate(startOf90Days.getDate() - 89);
    startOf90Days.setHours(0, 0, 0, 0);

    const records = await Attendance.find({
      student: student._id,
      date: { $gte: startOf90Days, $lte: endOfToday }
    }).sort({ date: 1 });

    // Map records by YYYY-MM-DD
    const recordsByDate = {};
    const hourDistribution = {};
    for (let h = 0; h < 24; h++) hourDistribution[h] = 0;

    let weekendPresent = 0;
    let weekendTotal = 0;
    let weekdayPresent = 0;
    let weekdayTotal = 0;

    records.forEach(r => {
      const d = new Date(r.date);
      const dateStr = d.toISOString().split('T')[0];
      recordsByDate[dateStr] = r;

      if (['present', 'late', 'half_day'].includes(r.status)) {
        if (r.checkIn) {
          const checkInHour = new Date(r.checkIn).getHours();
          hourDistribution[checkInHour] = (hourDistribution[checkInHour] || 0) + 1;
        }
      }
    });

    // 90-day sequence for streak & consistency calculation
    const allDays90 = [];
    for (let i = 89; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      const dayOfWeek = d.getDay(); // 0 = Sun, 6 = Sat
      const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
      const rec = recordsByDate[dateStr];
      const isAttended = rec && ['present', 'late', 'half_day'].includes(rec.status);

      if (isWeekend) {
        weekendTotal++;
        if (isAttended) weekendPresent++;
      } else {
        weekdayTotal++;
        if (isAttended) weekdayPresent++;
      }

      allDays90.push({
        date: dateStr,
        dayOfWeek,
        isAttended,
        status: rec ? rec.status : 'absent'
      });
    }

    // Calculate Streaks
    let currentStreak = 0;
    let longestStreak = 0;
    let tempStreak = 0;

    for (let i = 0; i < allDays90.length; i++) {
      if (allDays90[i].isAttended) {
        tempStreak++;
        if (tempStreak > longestStreak) longestStreak = tempStreak;
      } else {
        tempStreak = 0;
      }
    }

    // Current streak (backwards from today or yesterday)
    const todayIndex = allDays90.length - 1;
    let streakPointer = todayIndex;
    if (!allDays90[todayIndex].isAttended && streakPointer > 0) {
      streakPointer--;
    }
    while (streakPointer >= 0 && allDays90[streakPointer].isAttended) {
      currentStreak++;
      streakPointer--;
    }

    // 30-Day Heatmap Data (Array of { date, minutes, status })
    const heatmap30 = [];
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      const rec = recordsByDate[dateStr];
      let mins = 0;
      let status = 'absent';

      if (rec) {
        status = rec.status;
        mins = rec.duration || 0;
        if (!mins && rec.checkIn && rec.checkOut) {
          mins = Math.max(0, Math.round((new Date(rec.checkOut) - new Date(rec.checkIn)) / 60000));
        } else if (!mins && ['present', 'late', 'half_day'].includes(rec.status)) {
          mins = rec.status === 'half_day' ? 180 : 300;
        }
      }

      heatmap30.push({
        date: dateStr,
        minutes: mins,
        status: status,
        checkIn: rec?.checkIn ? new Date(rec.checkIn).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : null,
        checkOut: rec?.checkOut ? new Date(rec.checkOut).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : null
      });
    }

    // Peak Study Hours Distribution
    let peakHour = 8;
    let maxHourCount = -1;
    for (let h = 0; h < 24; h++) {
      if (hourDistribution[h] > maxHourCount) {
        maxHourCount = hourDistribution[h];
        peakHour = h;
      }
    }

    let peakSlotName = 'Morning';
    let peakBadge = '🌅 Peak Time: 08:00 AM – 02:00 PM';
    if (peakHour >= 5 && peakHour < 12) {
      peakSlotName = 'Morning (07:00 AM – 12:00 PM)';
      peakBadge = '🌅 Peak Time: 08:00 AM – 02:00 PM';
    } else if (peakHour >= 12 && peakHour < 16) {
      peakSlotName = 'Afternoon (12:00 PM – 04:00 PM)';
      peakBadge = '☀️ Peak Time: 12:00 PM – 05:00 PM';
    } else if (peakHour >= 16 && peakHour < 21) {
      peakSlotName = 'Evening (04:00 PM – 08:00 PM)';
      peakBadge = '🌆 Peak Time: 04:00 PM – 09:00 PM';
    } else {
      peakSlotName = 'Night / Late Shift (09:00 PM – 03:00 AM)';
      peakBadge = '🌙 Peak Time: 09:00 PM – 03:00 AM';
    }

    // Average Daily Study Duration
    const totalPresentDays30 = heatmap30.filter(d => ['present', 'late', 'half_day'].includes(d.status)).length;
    const totalMinutes30 = heatmap30.reduce((acc, cur) => acc + cur.minutes, 0);
    const avgMinutes = totalPresentDays30 > 0 ? Math.round(totalMinutes30 / totalPresentDays30) : 0;
    const avgHoursNum = (avgMinutes / 60).toFixed(1);
    const avgHours = Math.floor(avgMinutes / 60);
    const avgRemMins = avgMinutes % 60;
    const avgFormatted = avgHours > 0 ? `${avgHours}h ${avgRemMins}m` : `${avgRemMins}m`;

    // Consistency Score (0–100%)
    const daysAttended30 = totalPresentDays30;
    const attendanceRatio = Math.min(1, daysAttended30 / 30);
    const streakBonus = Math.min(1, currentStreak / 14);
    const lateDays = heatmap30.filter(d => d.status === 'late').length;
    const punctualityRatio = daysAttended30 > 0 ? (daysAttended30 - (lateDays * 0.5)) / daysAttended30 : 0;

    let consistencyScore = Math.round((attendanceRatio * 70) + (streakBonus * 15) + (punctualityRatio * 15));
    if (daysAttended30 === 0 && currentStreak === 0) consistencyScore = 0;
    consistencyScore = Math.max(0, Math.min(100, consistencyScore));

    // Dynamic AI Study Recommendation Note & Tip
    let aiRecommendation = '';
    let aiStudyTip = '';

    const weekendRate = weekendTotal > 0 ? (weekendPresent / weekendTotal) : 1;
    const weekdayRate = weekdayTotal > 0 ? (weekdayPresent / weekdayTotal) : 1;

    if (consistencyScore >= 85) {
      aiRecommendation = `🔥 Outstanding consistency! You've maintained ${consistencyScore}% attendance with a ${currentStreak}-day active streak. Keep up this unstoppable momentum!`;
      aiStudyTip = `🔥 Outstanding consistency! You've maintained 85%+ attendance for 3 weeks.`;
    } else if (weekendRate < 0.4 && weekdayRate >= 0.7) {
      aiRecommendation = `⚠️ Attendance drop detected on weekends (${Math.round(weekendRate * 100)}% vs ${Math.round(weekdayRate * 100)}% on weekdays). Keep up regular study hours to maintain exam readiness!`;
      aiStudyTip = `⚠️ Attendance drop detected on weekends. Keep up regular study hours!`;
    } else if (consistencyScore >= 70) {
      aiRecommendation = `⭐ Great focus! You are averaging ${avgFormatted}/day of focused study. Maintaining consistent check-in times will boost long-term retention.`;
      aiStudyTip = `⭐ Great focus! Consistent study routine detected. Aim for morning sessions to boost retention.`;
    } else if (currentStreak >= 5) {
      aiRecommendation = `🚀 Great momentum! You are currently on a ${currentStreak}-day study streak. Aim to cross 10 days to solidify your study habit!`;
      aiStudyTip = `🚀 ${currentStreak}-day study streak active! Keep going.`;
    } else if (consistencyScore < 50) {
      aiRecommendation = `💡 Consistency is the key to cracking competitive exams. Try starting with regular 3-4 hour study blocks every morning to build discipline!`;
      aiStudyTip = `💡 Build momentum with regular study blocks. Consistency beats cramming!`;
    } else {
      aiRecommendation = `📈 Solid progress! Try tracking your daily study sessions regularly to improve your consistency score past 80%.`;
      aiStudyTip = `📈 Set a fixed daily study slot to boost consistency.`;
    }

    res.json({
      success: true,
      data: {
        student: {
          _id: student._id,
          name: student.name,
          studentId: student.studentId
        },
        consistencyScore,
        currentStreak,
        longestStreak,
        totalDaysPresent: daysAttended30,
        totalDaysAbsent: 30 - daysAttended30,
        averageDailyDuration: {
          minutes: avgMinutes,
          hours: parseFloat(avgHoursNum),
          formatted: avgFormatted
        },
        peakStudyHours: {
          slot: peakSlotName,
          badge: peakBadge,
          peakHour,
          distribution: hourDistribution
        },
        heatmap: heatmap30,
        aiRecommendation,
        aiStudyTip
      },
      message: 'Student study analytics fetched successfully'
    });
  } catch (error) {
    console.error('Attendance analytics error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /check-in
router.post('/check-in', protect, validate([
  body('studentId').notEmpty().withMessage('Student ID is required')
]), async (req, res) => {
  try {
    const { studentId, seatId } = req.body;
    const now = new Date();
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    let record = await Attendance.findOne({
      student: studentId,
      date: { $gte: startOfDay, $lte: endOfDay }
    });

    if (record) {
      if (record.checkIn && !record.checkOut) {
        return res.status(400).json({ success: false, message: 'Student already checked in today' });
      }
      // If they were checked out, maybe we allow re-check-in, or just update?
      // Assuming simple flow: Update checkIn and clear checkOut for re-entry.
      record.checkIn = now;
      record.checkOut = undefined;
      record.status = 'present';
      if (seatId) record.seat = seatId;
    } else {
      record = new Attendance({
        student: studentId,
        date: now,
        checkIn: now,
        status: 'present',
        seat: seatId || undefined
      });
    }

    await record.save();
    res.json({ success: true, data: record, message: 'Check-in successful' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /check-out
router.post('/check-out', protect, validate([
  body('studentId').notEmpty().withMessage('Student ID is required')
]), async (req, res) => {
  try {
    const { studentId } = req.body;
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const record = await Attendance.findOne({
      student: studentId,
      date: { $gte: startOfDay, $lte: endOfDay }
    });

    if (!record) {
      return res.status(404).json({ success: false, message: 'No attendance record found for today' });
    }
    if (!record.checkIn) {
      return res.status(400).json({ success: false, message: 'Student has not checked in today' });
    }
    if (record.checkOut) {
      return res.status(400).json({ success: false, message: 'Student already checked out today' });
    }

    record.checkOut = new Date();
    await record.save();

    res.json({ success: true, data: record, message: 'Check-out successful' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /mark - Manual mark
router.post('/mark', protect, roleCheck('owner', 'branch_manager'), validate([
  body('studentId').notEmpty().withMessage('Student ID is required'),
  body('date').isISO8601().withMessage('Valid date is required'),
  body('status').isIn(['present', 'absent', 'late', 'half_day']).withMessage('Invalid status')
]), async (req, res) => {
  try {
    const { studentId, date, status } = req.body;
    const targetDate = new Date(date);
    targetDate.setHours(12, 0, 0, 0); // avoid timezone issues
    
    const startOfDay = new Date(targetDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(targetDate);
    endOfDay.setHours(23, 59, 59, 999);

    let record = await Attendance.findOne({
      student: studentId,
      date: { $gte: startOfDay, $lte: endOfDay }
    });

    if (record) {
      record.status = status;
      record.markedBy = 'manual';
    } else {
      record = new Attendance({
        student: studentId,
        date: targetDate,
        status,
        markedBy: 'manual'
      });
    }

    await record.save();
    res.json({ success: true, data: record, message: 'Attendance marked manually' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /report
router.get('/report', protect, async (req, res) => {
  try {
    const { startDate, endDate, studentId } = req.query;
    
    if (!startDate || !endDate) {
      return res.status(400).json({ success: false, message: 'startDate and endDate are required' });
    }

    const start = new Date(startDate);
    start.setHours(0, 0, 0, 0);
    const end = new Date(endDate);
    end.setHours(23, 59, 59, 999);

    const filter = { date: { $gte: start, $lte: end } };
    if (studentId) filter.student = studentId;

    const records = await Attendance.find(filter);
    
    const summary = {
      present: 0,
      absent: 0,
      late: 0,
      half_day: 0,
      total: records.length
    };

    records.forEach(r => {
      if (summary[r.status] !== undefined) {
        summary[r.status]++;
      }
    });

    res.json({
      success: true,
      data: { records, summary },
      message: 'Attendance report fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   POST /api/attendance/rfid-punch, /api/attendance/kiosk-punch
 * @desc    Self-service Kiosk Punch (Barcode, RFID, Keypad Student ID, Biometric)
 * @access  Public (Kiosk terminal)
 */
router.post(['/rfid-punch', '/kiosk-punch'], async (req, res) => {
  try {
    const Student = require('../models/Student');
    const rawIdentifier = req.body.rfidCardNumber || req.body.identifier || req.body.studentId || req.body.phone;

    if (!rawIdentifier) {
      return res.status(400).json({
        success: false,
        message: 'Please scan barcode, tap card, or enter Student ID / Phone number'
      });
    }

    const identifier = String(rawIdentifier).trim();

    // Look up student by studentId, phone, rfidCardNumber, or biometricId
    const student = await Student.findOne({
      $or: [
        { studentId: { $regex: new RegExp(`^${identifier}$`, 'i') } },
        { phone: identifier },
        { rfidCardNumber: identifier },
        { biometricId: identifier }
      ]
    }).populate('seat').populate('shift').populate('plan');

    if (!student) {
      return res.status(404).json({
        success: false,
        message: `Student "${identifier}" not found in database. Please register at reception.`
      });
    }

    if (student.status !== 'active') {
      return res.status(403).json({
        success: false,
        message: `Student membership is currently ${student.status.toUpperCase()}. Please contact front desk.`
      });
    }

    // Check today's attendance record
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    let att = await Attendance.findOne({
      student: student._id,
      date: { $gte: today, $lt: tomorrow }
    });

    const now = new Date();
    let action = 'check-in';
    let durationMinutes = 0;

    if (!att) {
      // First punch of today = Check-In
      att = new Attendance({
        student: student._id,
        seat: student.seat?._id || student.seat || null,
        branch: student.branch || null,
        date: now,
        checkIn: now,
        status: 'present',
        markedBy: 'self'
      });
      await att.save();
      action = 'check-in';
    } else if (att.checkIn && !att.checkOut) {
      // Currently checked in = Check-Out
      att.checkOut = now;
      durationMinutes = Math.max(0, Math.round((now.getTime() - new Date(att.checkIn).getTime()) / (1000 * 60)));
      att.duration = durationMinutes;
      await att.save();
      action = 'check-out';
    } else {
      // Already checked out earlier = Re-entry Check-In
      att.checkIn = now;
      att.checkOut = null;
      att.status = 'present';
      await att.save();
      action = 'check-in';
    }

    // Fetch updated today stats
    const todayStats = await Attendance.getTodayStats().catch(() => ({ totalPresent: 0, currentlyCheckedIn: 0, totalAbsent: 0 }));
    const totalCheckouts = await Attendance.countDocuments({
      date: { $gte: today, $lt: tomorrow },
      checkIn: { $ne: null },
      checkOut: { $ne: null }
    }).catch(() => 0);

    const punchStats = {
      currentlyCheckedIn: todayStats.currentlyCheckedIn || 0,
      totalPresent: todayStats.totalPresent || 0,
      totalCheckouts: totalCheckouts || 0
    };

    res.json({
      success: true,
      action,
      student: {
        _id: student._id,
        name: student.name,
        studentId: student.studentId,
        phone: student.phone,
        seat: student.seat ? {
          _id: student.seat._id,
          seatNumber: student.seat.seatNumber,
          zone: student.seat.zone
        } : null,
        shift: student.shift ? {
          name: student.shift.name,
          code: student.shift.code,
          formattedTiming: student.shift.formattedTiming
        } : null
      },
      time: now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
      durationMinutes,
      punchStats,
      message: action === 'check-in'
        ? `Welcome ${student.name}! Checked in successfully.`
        : `Goodbye ${student.name}! Checked out (${Math.floor(durationMinutes / 60)}h ${durationMinutes % 60}m logged).`
    });
  } catch (error) {
    console.error('Error during kiosk punch:', error);
    res.status(500).json({ success: false, message: error.message || 'Kiosk punch processing error' });
  }
});

// POST /biometric - Hardware Turnstile / RFID / Fingerprint machine webhook
router.post('/biometric', async (req, res) => {
  try {
    const Student = require('../models/Student');
    const { rfidCardNumber, biometricId, studentId, deviceId } = req.body;

    if (!rfidCardNumber && !biometricId && !studentId) {
      return res.status(400).json({
        success: false,
        accessGranted: false,
        message: 'Missing identifier (rfidCardNumber, biometricId, or studentId required)'
      });
    }

    // Lookup Student
    const query = { status: 'active' };
    if (rfidCardNumber) query.rfidCardNumber = rfidCardNumber;
    else if (biometricId) query.biometricId = biometricId;
    else if (studentId) query.studentId = studentId;

    const student = await Student.findOne(query).populate('seat');
    if (!student) {
      return res.status(404).json({
        success: false,
        accessGranted: false,
        message: 'Invalid / Unregistered Smart Card or Inactive Membership'
      });
    }

    // Check today's record
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    let att = await Attendance.findOne({
      student: student._id,
      date: { $gte: today, $lt: tomorrow }
    });

    const now = new Date();
    const nowTimeStr = now.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit' });

    if (!att) {
      // Check-In
      att = await Attendance.create({
        student: student._id,
        seat: student.seat?._id || null,
        date: now,
        checkIn: now,
        status: 'present',
        markedBy: 'biometric'
      });

      return res.json({
        success: true,
        accessGranted: true,
        action: 'check_in',
        studentName: student.name,
        studentId: student.studentId,
        seatNumber: student.seat?.seatNumber || 'General',
        time: nowTimeStr,
        deviceId: deviceId || 'GATE-01',
        message: `Welcome ${student.name}! Checked in at ${nowTimeStr}`
      });
    } else if (att.checkIn && !att.checkOut) {
      // Check-Out
      att.checkOut = now;
      await att.save();

      return res.json({
        success: true,
        accessGranted: true,
        action: 'check_out',
        studentName: student.name,
        studentId: student.studentId,
        seatNumber: student.seat?.seatNumber || 'General',
        time: nowTimeStr,
        durationMinutes: att.duration || 0,
        deviceId: deviceId || 'GATE-01',
        message: `Goodbye ${student.name}! Checked out at ${nowTimeStr} (${att.duration || 0} mins)`
      });
    } else {
      // Multiple punches in same day - Re-punch
      att.checkOut = null;
      att.checkIn = now;
      await att.save();

      return res.json({
        success: true,
        accessGranted: true,
        action: 'check_in',
        studentName: student.name,
        studentId: student.studentId,
        seatNumber: student.seat?.seatNumber || 'General',
        time: nowTimeStr,
        deviceId: deviceId || 'GATE-01',
        message: `Re-entry allowed: Checked in at ${nowTimeStr}`
      });
    }
  } catch (error) {
    res.status(500).json({ success: false, accessGranted: false, message: error.message });
  }
});

/**
 * @route   POST /api/attendance/hardware-sync
 * @desc    Universal webhook for eSSL, Realtime, ZKTeco, Matrix biometric & RFID machines
 * @access  Public / Device Key
 */
router.post('/hardware-sync', async (req, res) => {
  try {
    const Student = require('../models/Student');
    const logs = Array.isArray(req.body) ? req.body : (Array.isArray(req.body.logs) ? req.body.logs : [req.body]);
    
    let processed = 0;
    let errors = [];

    for (const log of logs) {
      const rawId = log.userId || log.EnrollNumber || log.studentId || log.cardNumber || log.CardNo || log.id;
      if (!rawId) continue;

      const identifier = String(rawId).trim();
      const student = await Student.findOne({
        $or: [
          { studentId: { $regex: new RegExp(`^${identifier}$`, 'i') } },
          { rfidCardNumber: identifier },
          { biometricId: identifier },
          { phone: identifier }
        ]
      }).populate('seat');

      if (!student) {
        errors.push({ identifier, error: 'Student not registered' });
        continue;
      }

      const punchTime = log.timestamp || log.time || log.LogTime ? new Date(log.timestamp || log.time || log.LogTime) : new Date();
      const startOfDay = new Date(punchTime);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(punchTime);
      endOfDay.setHours(23, 59, 59, 999);

      let att = await Attendance.findOne({
        student: student._id,
        date: { $gte: startOfDay, $lte: endOfDay }
      });

      if (!att) {
        // First punch of the day = Check-In
        att = new Attendance({
          student: student._id,
          date: punchTime,
          checkIn: punchTime,
          status: 'present',
          markedBy: 'biometric',
          seat: student.seat?._id || student.seat || null,
          branch: student.branch || null,
          notes: `Hardware Sync (${log.deviceId || 'Biometric'})`
        });
      } else if (!att.checkOut) {
        // Second punch = Check-Out
        att.checkOut = punchTime;
        att.duration = Math.round((punchTime.getTime() - new Date(att.checkIn).getTime()) / (1000 * 60));
        att.notes = (att.notes ? att.notes + ' • ' : '') + `Auto Out (${log.deviceId || 'Biometric'})`;
      } else {
        // Subsequent punch = Update Check-Out
        att.checkOut = punchTime;
        att.duration = Math.round((punchTime.getTime() - new Date(att.checkIn).getTime()) / (1000 * 60));
      }

      await att.save();
      processed++;
    }

    res.json({
      success: true,
      processedCount: processed,
      errorsCount: errors.length,
      errors: errors.length > 0 ? errors : undefined,
      message: `Hardware sync completed: ${processed} punch(es) recorded`
    });
  } catch (err) {
    console.error('Error during hardware attendance sync:', err);
    res.status(500).json({ success: false, message: err.message || 'Hardware sync error' });
  }
});

module.exports = router;
