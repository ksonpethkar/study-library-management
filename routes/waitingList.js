const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const WaitingList = require('../models/WaitingList');
const Student = require('../models/Student');
const Seat = require('../models/Seat');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');

router.use(protect);
router.use(roleCheck('owner', 'branch_manager'));

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

/**
 * @route   GET /api/waiting-list
 * @desc    Get all waiting list items sorted by priority
 */
router.get('/', async (req, res) => {
  try {
    const { status = 'all' } = req.query;
    const query = {};
    if (status !== 'all') {
      query.status = status;
    }

    const items = await WaitingList.find(query)
      .populate('student', 'name studentId phone email plan seat')
      .populate('offeredSeat', 'seatNumber zone type')
      .sort({ priority: 1, createdAt: 1 });

    const waitingCount = await WaitingList.countDocuments({ status: 'waiting' });
    const offeredCount = await WaitingList.countDocuments({ status: 'offered' });

    res.json({
      success: true,
      data: {
        items,
        counts: {
          waiting: waitingCount,
          offered: offeredCount,
          total: items.length
        }
      }
    });
  } catch (err) {
    console.error('Error fetching waiting list:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch waiting list' });
  }
});

/**
 * @route   POST /api/waiting-list
 * @desc    Add student or walk-in to waiting queue
 */
router.post(
  '/',
  validate([
    body('studentName').trim().notEmpty().withMessage('Student name is required'),
    body('studentPhone').trim().notEmpty().withMessage('Phone number is required')
  ]),
  async (req, res) => {
    try {
      const { student, studentName, studentPhone, studentEmail, preferredZone, preferredShift, notes } = req.body;

      const item = new WaitingList({
        student: student || null,
        studentName,
        studentPhone,
        studentEmail: studentEmail || '',
        preferredZone: preferredZone || 'Any',
        preferredShift: preferredShift || 'Any',
        notes: notes || '',
        createdBy: req.user._id
      });

      await item.save();

      res.status(201).json({
        success: true,
        message: `Added ${studentName} to the seat waiting list (#${item.priority})`,
        data: item
      });
    } catch (err) {
      console.error('Error adding to waiting list:', err);
      res.status(500).json({ success: false, message: 'Failed to add to waiting list' });
    }
  }
);

/**
 * @route   PUT /api/waiting-list/:id/offer
 * @desc    Offer a seat to a waiting student
 */
router.put('/:id/offer', async (req, res) => {
  try {
    const { seatId } = req.body;
    if (!seatId) {
      return res.status(400).json({ success: false, message: 'Please select a seat to offer' });
    }

    const seat = await Seat.findById(seatId);
    if (!seat) {
      return res.status(404).json({ success: false, message: 'Seat not found' });
    }

    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24hr hold

    const item = await WaitingList.findByIdAndUpdate(
      req.params.id,
      {
        status: 'offered',
        offeredSeat: seatId,
        offerExpiresAt: expiresAt
      },
      { new: true }
    ).populate('offeredSeat');

    if (!item) {
      return res.status(404).json({ success: false, message: 'Waiting list entry not found' });
    }

    res.json({
      success: true,
      message: `Seat ${seat.seatNumber} offered to ${item.studentName}. (Hold active for 24h)`,
      data: item
    });
  } catch (err) {
    console.error('Error offering seat:', err);
    res.status(500).json({ success: false, message: 'Failed to offer seat' });
  }
});

/**
 * @route   PUT /api/waiting-list/:id/assign
 * @desc    Confirm seat assignment and update Student + Seat records
 */
router.put('/:id/assign', async (req, res) => {
  try {
    const item = await WaitingList.findById(req.params.id);
    if (!item) {
      return res.status(404).json({ success: false, message: 'Waiting list entry not found' });
    }

    const seatId = req.body.seatId || item.offeredSeat;
    if (!seatId) {
      return res.status(400).json({ success: false, message: 'No seat assigned' });
    }

    // 1. Mark seat occupied
    let studentId = item.student;
    if (!studentId) {
      // Create student if this was a direct walk-in queue item
      const newStudent = new Student({
        name: item.studentName,
        phone: item.studentPhone,
        email: item.studentEmail,
        seat: seatId,
        status: 'active',
        createdBy: req.user._id
      });
      await newStudent.save();
      studentId = newStudent._id;
    } else {
      await Student.findByIdAndUpdate(studentId, { seat: seatId, status: 'active' });
    }

    await Seat.findByIdAndUpdate(seatId, {
      status: 'occupied',
      currentStudent: studentId,
      assignedAt: new Date()
    });

    item.status = 'assigned';
    item.offeredSeat = seatId;
    await item.save();

    res.json({
      success: true,
      message: `Successfully allocated seat to ${item.studentName}!`,
      data: item
    });
  } catch (err) {
    console.error('Error assigning from waiting list:', err);
    res.status(500).json({ success: false, message: 'Failed to allocate seat' });
  }
});

/**
 * @route   PUT /api/waiting-list/:id/cancel
 * @desc    Cancel waiting list item
 */
router.put('/:id/cancel', async (req, res) => {
  try {
    const item = await WaitingList.findByIdAndUpdate(
      req.params.id,
      { status: 'cancelled' },
      { new: true }
    );
    if (!item) {
      return res.status(404).json({ success: false, message: 'Entry not found' });
    }
    res.json({ success: true, message: 'Waiting list entry cancelled' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to cancel entry' });
  }
});

module.exports = router;
