const express = require('express');
const router = express.Router();
const { body, query, validationResult } = require('express-validator');
const { protect } = require('../middleware/auth');
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
router.post('/mark', protect, validate([
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
