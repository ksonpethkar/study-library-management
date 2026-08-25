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
    
    // RBAC: If student role, isolate to own attendance only
    if (req.user.role === 'student') {
      const Student = require('../models/Student');
      const sDoc = await Student.findOne({
        $or: [{ email: req.user.email }, { phone: req.user.phone }, { _id: req.user.studentId || req.user.id || req.user._id }]
      }).select('_id').lean();
      if (!sDoc) return res.status(403).json({ success: false, message: 'Access denied' });
      filter.student = sDoc._id;
    } else {
      if (student) filter.student = student;
    }

    if (date) {
      const startOfDay = new Date(date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(date);
      endOfDay.setHours(23, 59, 59, 999);
      filter.date = { $gte: startOfDay, $lte: endOfDay };
    }
    if (status) filter.status = status;

    const total = await Attendance.countDocuments(filter);
    const records = await Attendance.find(filter)
      .populate('student', 'name studentId phone')
      .populate('seat', 'seatNumber')
      .sort({ date: -1, createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .lean();

    res.json({
      success: true,
      data: { records, total, page: parseInt(page), limit: parseInt(limit) },
      message: 'Attendance records fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /today - Today's attendance (Staff & Admin only)
router.get('/today', protect, roleCheck('owner', 'superadmin', 'admin', 'branch_manager', 'staff'), async (req, res) => {
  try {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    const records = await Attendance.find({ date: { $gte: startOfDay, $lte: endOfDay } })
      .populate('student', 'name studentId phone')
      .populate('seat', 'seatNumber')
      .sort({ createdAt: -1 })
      .lean();
      
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
    const Student = require('../models/Student');
    const { studentId } = req.params;

    // RBAC: If student role, ensure they only query their own record
    if (req.user.role === 'student') {
      const sDoc = await Student.findOne({
        $or: [{ email: req.user.email }, { phone: req.user.phone }, { _id: req.user.studentId || req.user.id || req.user._id }]
      }).select('_id').lean();
      if (!sDoc || String(sDoc._id) !== String(studentId)) {
        return res.status(403).json({ success: false, message: 'Access denied to other student attendance records' });
      }
    }

    const records = await Attendance.find({ student: studentId })
      .populate('seat', 'seatNumber')
      .sort({ date: -1 })
      .lean();

    res.json({
      success: true,
      data: records,
      message: 'Student attendance history fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ── GET /year-heatmap/:studentId/:year ─────────────────────────────────────
// Returns 365 days of attendance data for a given year (GitHub-style heatmap)
// Used by: attendanceHeatmap.js, portal.js, kiosk success card
router.get('/year-heatmap/:studentId/:year', protect, async (req, res) => {
  try {
    const Student = require('../models/Student');
    const mongoose = require('mongoose');
    const { studentId, year } = req.params;
    const yr = parseInt(year, 10);
    if (isNaN(yr) || yr < 2000 || yr > 2099) {
      return res.status(400).json({ success: false, message: 'Invalid year' });
    }

    // Resolve 'me' alias for student portal
    let resolvedId = studentId;
    if (studentId === 'me') {
      const stu = await Student.findOne({
        $or: [{ email: req.user.email }, { phone: req.user.phone }]
      }).select('_id').lean();
      if (!stu) return res.status(404).json({ success: false, message: 'Student not found' });
      resolvedId = stu._id.toString();
    }

    const startDate = new Date(`${yr}-01-01T00:00:00.000Z`);
    const endDate   = new Date(`${yr}-12-31T23:59:59.999Z`);

    const records = await Attendance.find({
      student: new mongoose.Types.ObjectId(resolvedId),
      date: { $gte: startDate, $lte: endDate }
    }).select('date status duration checkIn checkOut').lean();

    // Build a map by date string YYYY-MM-DD
    const byDate = {};
    records.forEach(r => {
      const key = new Date(r.date).toISOString().slice(0, 10);
      byDate[key] = {
        status: r.status || 'present',
        duration: r.duration || 0,
        checkIn:  r.checkIn ? new Date(r.checkIn).toTimeString().slice(0,5) : null,
        checkOut: r.checkOut ? new Date(r.checkOut).toTimeString().slice(0,5) : null
      };
    });

    // Build full-year array (365/366 days)
    const days = [];
    const cur = new Date(startDate);
    while (cur <= endDate) {
      const key = cur.toISOString().slice(0, 10);
      days.push({
        date: key,
        ...(byDate[key] || { status: 'absent', duration: 0, checkIn: null, checkOut: null })
      });
      cur.setUTCDate(cur.getUTCDate() + 1);
    }

    // Summary stats
    const presentDays  = days.filter(d => ['present','late','half_day'].includes(d.status)).length;
    const absentDays   = days.filter(d => d.status === 'absent').length;
    const lateDays     = days.filter(d => d.status === 'late').length;
    const totalMinutes = days.reduce((acc, d) => acc + (d.duration || 0), 0);

    // Current streak (counting backwards from today or Dec 31)
    const today = new Date().toISOString().slice(0, 10);
    let streak = 0;
    for (let i = days.length - 1; i >= 0; i--) {
      if (days[i].date > today) continue;
      if (['present','late','half_day'].includes(days[i].status)) streak++;
      else break;
    }

    res.json({
      success: true,
      data: {
        year: yr,
        days,
        summary: { presentDays, absentDays, lateDays, totalMinutes, currentStreak: streak }
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ── GET /behavior-score/:studentId ──────────────────────────────────────────
// Computes a 0–100 composite Behavior Score from attendance%, payment% & streak
// Returns score, label (Excellent/Good/Fair/At Risk), breakdown, and badge color
router.get('/behavior-score/:studentId', protect, async (req, res) => {
  try {
    const Student = require('../models/Student');
    const Payment = require('../models/Payment');
    const mongoose = require('mongoose');
    const { studentId } = req.params;

    let resolvedId = studentId;
    if (studentId === 'me') {
      const stu = await Student.findOne({
        $or: [{ email: req.user.email }, { phone: req.user.phone }]
      }).select('_id membershipExpiry').lean();
      if (!stu) return res.status(404).json({ success: false, message: 'Student not found' });
      resolvedId = stu._id.toString();
    }

    const student = await Student.findById(resolvedId)
      .select('studyStreakDays membershipExpiry status')
      .lean();
    if (!student) return res.status(404).json({ success: false, message: 'Student not found' });

    // Last 30 days attendance
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const attRecords = await Attendance.find({
      student: new mongoose.Types.ObjectId(resolvedId),
      date: { $gte: thirtyDaysAgo }
    }).select('status').lean();

    const presentCount = attRecords.filter(r => ['present','late','half_day'].includes(r.status)).length;
    const attPct = Math.min(100, Math.round((presentCount / 30) * 100));

    // Payment on-time score (last 3 payments)
    const lastPayments = await Payment.find({ student: resolvedId })
      .sort({ paymentDate: -1 }).limit(3).select('status dueDate paymentDate').lean();
    let payScore = 100;
    if (lastPayments.length > 0) {
      const onTime = lastPayments.filter(p => p.status === 'paid').length;
      payScore = Math.round((onTime / lastPayments.length) * 100);
    }

    // Streak bonus (max 15 pts for 30+ day streak)
    const streak = student.studyStreakDays || 0;
    const streakBonus = Math.min(15, Math.round((streak / 30) * 15));

    // Composite score: 55% attendance + 30% payment + 15% streak
    const rawScore = Math.round((attPct * 0.55) + (payScore * 0.30) + streakBonus);
    const score = Math.max(0, Math.min(100, rawScore));

    // Label & color
    let label, color, emoji;
    if (score >= 85)      { label = 'Excellent'; color = '#00b894'; emoji = '⭐'; }
    else if (score >= 70) { label = 'Good';      color = '#0984e3'; emoji = '👍'; }
    else if (score >= 50) { label = 'Fair';      color = '#fdcb6e'; emoji = '📊'; }
    else                  { label = 'At Risk';   color = '#e17055'; emoji = '⚠️'; }

    res.json({
      success: true,
      data: {
        score,
        label,
        color,
        emoji,
        breakdown: {
          attendancePct: attPct,
          paymentPct: payScore,
          streakDays: streak,
          streakBonus
        }
      }
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
      student = await Student.findById(paramId).lean();
      if (!student) {
        student = await Student.findOne({ studentId: paramId }).lean();
      }
    } else {
      student = await Student.findOne({ studentId: paramId }).lean();
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
    
    // Check if there is an active/open check-in within the last 18 hours (handles overnight shifts)
    const eighteenHoursAgo = new Date(Date.now() - 18 * 60 * 60 * 1000);
    let openRecord = await Attendance.findOne({
      student: studentId,
      checkIn: { $gte: eighteenHoursAgo },
      checkOut: null
    }).sort({ checkIn: -1 });

    if (openRecord) {
      return res.status(400).json({ success: false, message: 'Student is currently already checked in' });
    }

    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    let record = await Attendance.findOne({
      student: studentId,
      date: { $gte: startOfDay, $lte: endOfDay }
    });

    if (record && !record.checkOut) {
      return res.status(400).json({ success: false, message: 'Student already checked in today' });
    }

    if (record && record.checkOut) {
      // Re-entry check-in
      record.checkIn = now;
      record.checkOut = undefined;
      record.status = 'present';
      if (seatId) record.seat = seatId;
      if (!record.sessions) record.sessions = [];
      record.sessions.push({ checkIn: now, checkOut: null, durationMinutes: 0 });
    } else {
      record = new Attendance({
        student: studentId,
        date: now,
        checkIn: now,
        status: 'present',
        seat: seatId || undefined,
        sessions: [{ checkIn: now, checkOut: null, durationMinutes: 0 }],
        totalStudyMinutes: 0
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
    const now = new Date();
    
    // Look for active open check-in within the last 18 hours (handles shifts crossing midnight seamlessly)
    const eighteenHoursAgo = new Date(Date.now() - 18 * 60 * 60 * 1000);
    let record = await Attendance.findOne({
      student: studentId,
      checkIn: { $gte: eighteenHoursAgo },
      checkOut: null
    }).sort({ checkIn: -1 });

    // Fallback: Check today's record
    if (!record) {
      const startOfDay = new Date();
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date();
      endOfDay.setHours(23, 59, 59, 999);

      record = await Attendance.findOne({
        student: studentId,
        date: { $gte: startOfDay, $lte: endOfDay }
      });
    }

    if (!record) {
      return res.status(404).json({ success: false, message: 'No active check-in record found for student' });
    }
    if (!record.checkIn) {
      return res.status(400).json({ success: false, message: 'Student has not checked in' });
    }
    if (record.checkOut) {
      return res.status(400).json({ success: false, message: 'Student already checked out' });
    }

    record.checkOut = now;

    if (!record.sessions || record.sessions.length === 0) {
      const sessionMins = Math.max(0, Math.round((now.getTime() - new Date(record.checkIn).getTime()) / (1000 * 60)));
      record.sessions = [{ checkIn: record.checkIn, checkOut: now, durationMinutes: sessionMins }];
      record.totalStudyMinutes = sessionMins;
      record.duration = sessionMins;
    } else {
      let activeSession = record.sessions.slice().reverse().find(s => !s.checkOut);
      if (activeSession) {
        activeSession.checkOut = now;
        activeSession.durationMinutes = Math.max(0, Math.round((now.getTime() - new Date(activeSession.checkIn || record.checkIn).getTime()) / (1000 * 60)));
      } else {
        const sessionMins = Math.max(0, Math.round((now.getTime() - new Date(record.checkIn).getTime()) / (1000 * 60)));
        record.sessions.push({ checkIn: record.checkIn, checkOut: now, durationMinutes: sessionMins });
      }
      const totalMins = record.sessions.reduce((acc, s) => acc + (s.durationMinutes || 0), 0);
      record.totalStudyMinutes = totalMins;
      record.duration = totalMins;
    }

    await record.save();

    res.json({ success: true, data: record, message: `Check-out successful (${Math.floor((record.duration || record.totalStudyMinutes || 0) / 60)}h ${(record.duration || record.totalStudyMinutes || 0) % 60}m study duration)` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /check-out-all - Bulk check-out all active in hall
router.post('/check-out-all', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const eighteenHoursAgo = new Date(Date.now() - 18 * 60 * 60 * 1000);
    const now = new Date();
    
    // Find all un-closed checkins in last 18 hours
    const activeRecords = await Attendance.find({
      checkIn: { $gte: eighteenHoursAgo },
      checkOut: null
    });

    for (const rec of activeRecords) {
      rec.checkOut = now;
      if (!rec.sessions || rec.sessions.length === 0) {
        const sessionMins = Math.max(0, Math.round((now.getTime() - new Date(rec.checkIn).getTime()) / (1000 * 60)));
        rec.sessions = [{ checkIn: rec.checkIn, checkOut: now, durationMinutes: sessionMins }];
        rec.totalStudyMinutes = sessionMins;
        rec.duration = sessionMins;
      } else {
        let activeSession = rec.sessions.slice().reverse().find(s => !s.checkOut);
        if (activeSession) {
          activeSession.checkOut = now;
          activeSession.durationMinutes = Math.max(0, Math.round((now.getTime() - new Date(activeSession.checkIn || rec.checkIn).getTime()) / (1000 * 60)));
        } else {
          const sessionMins = Math.max(0, Math.round((now.getTime() - new Date(rec.checkIn).getTime()) / (1000 * 60)));
          rec.sessions.push({ checkIn: rec.checkIn, checkOut: now, durationMinutes: sessionMins });
        }
        const totalMins = rec.sessions.reduce((acc, s) => acc + (s.durationMinutes || 0), 0);
        rec.totalStudyMinutes = totalMins;
        rec.duration = totalMins;
      }
      await rec.save();
    }

    res.json({
      success: true,
      message: `Successfully checked out ${activeRecords.length} active members from reading hall.`
    });
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

    const records = await Attendance.find(filter).lean();
    
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

    // Check for open check-in in last 18 hours (handles overnight/midnight shifts cleanly)
    const eighteenHoursAgo = new Date(Date.now() - 18 * 60 * 60 * 1000);
    let openAtt = await Attendance.findOne({
      student: student._id,
      checkIn: { $gte: eighteenHoursAgo },
      checkOut: null
    }).sort({ checkIn: -1 });

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    let att = openAtt || await Attendance.findOne({
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
        markedBy: 'self',
        sessions: [{ checkIn: now, checkOut: null, durationMinutes: 0 }],
        totalStudyMinutes: 0
      });
      await att.save();
      action = 'check-in';
    } else if (att.checkIn && !att.checkOut) {
      // Currently checked in = Check-Out
      att.checkOut = now;
      if (!att.sessions || att.sessions.length === 0) {
        const sessionMins = Math.max(0, Math.round((now.getTime() - new Date(att.checkIn).getTime()) / (1000 * 60)));
        att.sessions = [{ checkIn: att.checkIn, checkOut: now, durationMinutes: sessionMins }];
        att.totalStudyMinutes = sessionMins;
        att.duration = sessionMins;
        durationMinutes = sessionMins;
      } else {
        let activeSession = att.sessions.slice().reverse().find(s => !s.checkOut);
        if (activeSession) {
          activeSession.checkOut = now;
          const sessionMins = Math.max(0, Math.round((now.getTime() - new Date(activeSession.checkIn || att.checkIn).getTime()) / (1000 * 60)));
          activeSession.durationMinutes = sessionMins;
          durationMinutes = sessionMins;
        } else {
          const sessionMins = Math.max(0, Math.round((now.getTime() - new Date(att.checkIn).getTime()) / (1000 * 60)));
          att.sessions.push({ checkIn: att.checkIn, checkOut: now, durationMinutes: sessionMins });
          durationMinutes = sessionMins;
        }
        const totalMins = att.sessions.reduce((acc, s) => acc + (s.durationMinutes || 0), 0);
        att.totalStudyMinutes = totalMins;
        att.duration = totalMins;
      }
      await att.save();
      action = 'check-out';
    } else {
      // Already checked out earlier = Re-entry Check-In
      att.checkIn = now;
      att.checkOut = null;
      att.status = 'present';
      if (!att.sessions) att.sessions = [];
      att.sessions.push({ checkIn: now, checkOut: null, durationMinutes: 0 });
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
      durationMinutes: durationMinutes || att.duration || 0,
      punchStats,
      message: action === 'check-in'
        ? `Welcome ${student.name}! Checked in successfully.`
        : `Goodbye ${student.name}! Checked out (${Math.floor((att.duration || att.totalStudyMinutes || 0) / 60)}h ${(att.duration || att.totalStudyMinutes || 0) % 60}m logged).`
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

    const student = await Student.findOne(query).populate('seat').lean();
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
        markedBy: 'biometric',
        sessions: [{ checkIn: now, checkOut: null, durationMinutes: 0 }],
        totalStudyMinutes: 0
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
      if (!att.sessions || att.sessions.length === 0) {
        const sessionMins = Math.max(0, Math.round((now.getTime() - new Date(att.checkIn).getTime()) / (1000 * 60)));
        att.sessions = [{ checkIn: att.checkIn, checkOut: now, durationMinutes: sessionMins }];
        att.totalStudyMinutes = sessionMins;
        att.duration = sessionMins;
      } else {
        let activeSession = att.sessions.slice().reverse().find(s => !s.checkOut);
        if (activeSession) {
          activeSession.checkOut = now;
          activeSession.durationMinutes = Math.max(0, Math.round((now.getTime() - new Date(activeSession.checkIn || att.checkIn).getTime()) / (1000 * 60)));
        } else {
          const sessionMins = Math.max(0, Math.round((now.getTime() - new Date(att.checkIn).getTime()) / (1000 * 60)));
          att.sessions.push({ checkIn: att.checkIn, checkOut: now, durationMinutes: sessionMins });
        }
        const totalMins = att.sessions.reduce((acc, s) => acc + (s.durationMinutes || 0), 0);
        att.totalStudyMinutes = totalMins;
        att.duration = totalMins;
      }
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
      // Multiple punches in same day - Re-punch / Re-entry
      att.checkOut = null;
      att.checkIn = now;
      if (!att.sessions) att.sessions = [];
      att.sessions.push({ checkIn: now, checkOut: null, durationMinutes: 0 });
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
          notes: `Hardware Sync (${log.deviceId || 'Biometric'})`,
          sessions: [{ checkIn: punchTime, checkOut: null, durationMinutes: 0 }],
          totalStudyMinutes: 0
        });
      } else if (!att.checkOut) {
        // Second punch = Check-Out
        att.checkOut = punchTime;
        if (!att.sessions || att.sessions.length === 0) {
          const sessionMins = Math.max(0, Math.round((punchTime.getTime() - new Date(att.checkIn).getTime()) / (1000 * 60)));
          att.sessions = [{ checkIn: att.checkIn, checkOut: punchTime, durationMinutes: sessionMins }];
          att.totalStudyMinutes = sessionMins;
          att.duration = sessionMins;
        } else {
          let activeSession = att.sessions.slice().reverse().find(s => !s.checkOut);
          if (activeSession) {
            activeSession.checkOut = punchTime;
            activeSession.durationMinutes = Math.max(0, Math.round((punchTime.getTime() - new Date(activeSession.checkIn || att.checkIn).getTime()) / (1000 * 60)));
          } else {
            const sessionMins = Math.max(0, Math.round((punchTime.getTime() - new Date(att.checkIn).getTime()) / (1000 * 60)));
            att.sessions.push({ checkIn: att.checkIn, checkOut: punchTime, durationMinutes: sessionMins });
          }
          const totalMins = att.sessions.reduce((acc, s) => acc + (s.durationMinutes || 0), 0);
          att.totalStudyMinutes = totalMins;
          att.duration = totalMins;
        }
        att.notes = (att.notes ? att.notes + ' • ' : '') + `Auto Out (${log.deviceId || 'Biometric'})`;
      } else {
        // Subsequent punch = Re-entry check-in
        att.checkOut = null;
        att.checkIn = punchTime;
        if (!att.sessions) att.sessions = [];
        att.sessions.push({ checkIn: punchTime, checkOut: null, durationMinutes: 0 });
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
