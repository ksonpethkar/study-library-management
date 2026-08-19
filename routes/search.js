const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const Student = require('../models/Student');
const Seat = require('../models/Seat');
const Plan = require('../models/Plan');
const Payment = require('../models/Payment');
const { lookupPincode } = require('../utils/pincodeLookup');

// @route   GET /api/search/pincode/:pin
// @desc    Fast Indian Pincode Lookup (Public - No auth required)
router.get('/pincode/:pin', async (req, res) => {
  try {
    const data = await lookupPincode(req.params.pin);
    if (data) {
      return res.json({ success: true, data, message: 'Pincode details fetched successfully' });
    }
    return res.status(404).json({ success: false, message: 'Pincode details not found' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

router.use(protect);

// @route   GET /api/search
// @desc    Global multi-source search across students, seats, plans, and payments
router.get('/', async (req, res) => {
  try {
    const q = (req.query.q || '').trim();
    if (!q || q.length < 1) {
      return res.json({
        success: true,
        data: {
          students: [],
          seats: [],
          plans: [],
          payments: [],
          actions: [
            { label: 'Add New Student', icon: '🧑‍🎓', link: '#/students', category: 'Action' },
            { label: 'Collect Fee Payment', icon: '💰', link: '#/payments', category: 'Action' },
            { label: 'Manage Seats & Desks', icon: '💺', link: '#/seats', category: 'Action' },
            { label: 'Daily Attendance Log', icon: '⏱️', link: '#/attendance', category: 'Action' },
            { label: 'Revenue & Attendance Reports', icon: '📈', link: '#/reports', category: 'Action' },
            { label: 'System & Business Settings', icon: '⚙️', link: '#/settings', category: 'Action' }
          ]
        }
      });
    }

    const regex = new RegExp(q, 'i');

    const [students, seats, plans, payments] = await Promise.all([
      Student.find({
        $or: [
          { name: regex },
          { phone: regex },
          { studentId: regex },
          { email: regex }
        ]
      }).select('name studentId phone status plan seat').populate('plan', 'name').limit(6),

      Seat.find({
        $or: [
          { seatNumber: regex },
          { zone: regex }
        ]
      }).select('seatNumber zone type status').limit(6),

      Plan.find({
        $or: [
          { name: regex },
          { seatType: regex },
          { shift: regex }
        ]
      }).select('name price duration durationType').limit(4),

      Payment.find({
        $or: [
          { receiptNumber: regex },
          { transactionId: regex }
        ]
      }).select('receiptNumber finalAmount paymentDate status').populate('student', 'name').limit(4)
    ]);

    res.json({
      success: true,
      data: {
        students,
        seats,
        plans,
        payments
      },
      message: 'Search completed'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
