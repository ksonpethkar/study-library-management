const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Student = require('../models/Student');
const Seat = require('../models/Seat');
const Plan = require('../models/Plan');
const Payment = require('../models/Payment');
const Attendance = require('../models/Attendance');
const Expense = require('../models/Expense');
const Locker = require('../models/Locker');
const Shift = require('../models/Shift');
const Branch = require('../models/Branch');
const BusinessProfile = require('../models/BusinessProfile');
const SystemSetting = require('../models/SystemSetting');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');

// GET /api/backup/export - Full JSON database dump
router.get('/export', protect, roleCheck('owner', 'superadmin', 'admin'), async (req, res) => {
  try {
    const backupData = {
      exportedAt: new Date().toISOString(),
      version: '2.0.0',
      businessProfile: await BusinessProfile.find(),
      systemSettings: await SystemSetting.find(),
      branches: await Branch.find(),
      shifts: await Shift.find(),
      plans: await Plan.find(),
      seats: await Seat.find(),
      students: await Student.find(),
      payments: await Payment.find(),
      attendances: await Attendance.find().sort({ date: -1 }).limit(5000),
      expenses: await Expense.find(),
      lockers: await Locker.find()
    };

    const filename = `study_library_backup_${new Date().toISOString().split('T')[0]}.json`;
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(JSON.stringify(backupData, null, 2));
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/backup/restore - Restore from uploaded JSON
router.post('/restore', protect, roleCheck('owner', 'superadmin', 'admin'), async (req, res) => {
  try {
    const data = req.body;
    if (!data || !data.version) {
      return res.status(400).json({ success: false, message: 'Invalid backup file format' });
    }

    let stats = { restored: {} };

    if (data.plans && data.plans.length > 0) {
      for (const item of data.plans) {
        await Plan.findByIdAndUpdate(item._id, item, { upsert: true });
      }
      stats.restored.plans = data.plans.length;
    }

    if (data.seats && data.seats.length > 0) {
      for (const item of data.seats) {
        await Seat.findByIdAndUpdate(item._id, item, { upsert: true });
      }
      stats.restored.seats = data.seats.length;
    }

    if (data.students && data.students.length > 0) {
      for (const item of data.students) {
        await Student.findByIdAndUpdate(item._id, item, { upsert: true });
      }
      stats.restored.students = data.students.length;
    }

    if (data.payments && data.payments.length > 0) {
      for (const item of data.payments) {
        await Payment.findByIdAndUpdate(item._id, item, { upsert: true });
      }
      stats.restored.payments = data.payments.length;
    }

    if (data.lockers && data.lockers.length > 0) {
      for (const item of data.lockers) {
        await Locker.findByIdAndUpdate(item._id, item, { upsert: true });
      }
      stats.restored.lockers = data.lockers.length;
    }

    if (data.expenses && data.expenses.length > 0) {
      for (const item of data.expenses) {
        await Expense.findByIdAndUpdate(item._id, item, { upsert: true });
      }
      stats.restored.expenses = data.expenses.length;
    }

    res.json({
      success: true,
      message: 'Database backup restored successfully',
      stats
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
