const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const Shift = require('../models/Shift');
const Student = require('../models/Student');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');
const { validate } = require('../middleware/validate');

// GET / — List shifts (supports ?active=true, ?active=false, ?all=true)
router.get('/', async (req, res) => {
  try {
    await Shift.seedDefaults();

    let query = {};
    if (req.query.active === 'true' || req.query.active === '1') {
      query.isActive = true;
    } else if (req.query.active === 'false' || req.query.active === '0') {
      query.isActive = false;
    }
    // If active query parameter is not provided or is 'all', return all shifts
    if (req.query.search) {
      const searchRegex = new RegExp(req.query.search, 'i');
      query.$or = [
        { name: searchRegex },
        { code: searchRegex },
        { description: searchRegex }
      ];
    }

    const shifts = await Shift.find(query).sort({ startTime: 1, name: 1 }).lean();
    res.json({
      success: true,
      data: shifts,
      message: 'Shifts retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Protect write and admin operations
router.use(protect);

// Validations
const createShiftValidations = validate([
  body('name').trim().notEmpty().withMessage('Shift name is required'),
  body('code').trim().notEmpty().withMessage('Shift code is required'),
  body('startTime').trim().notEmpty().withMessage('Start time is required')
    .matches(/^([01]\d|2[0-3]):?([0-5]\d)$/).withMessage('Start time must be in HH:mm format'),
  body('endTime').trim().notEmpty().withMessage('End time is required')
    .matches(/^([01]\d|2[0-3]):?([0-5]\d)$/).withMessage('End time must be in HH:mm format'),
  body('maxCapacity').optional().isInt({ min: 0 }).withMessage('Capacity must be a non-negative number'),
  body('priceMultiplier').optional().isFloat({ min: 0.1 }).withMessage('Price multiplier must be at least 0.1')
]);

const updateShiftValidations = validate([
  body('name').optional().trim().notEmpty().withMessage('Shift name cannot be empty'),
  body('code').optional().trim().notEmpty().withMessage('Shift code cannot be empty'),
  body('startTime').optional().trim().matches(/^([01]\d|2[0-3]):?([0-5]\d)$/).withMessage('Start time must be in HH:mm format'),
  body('endTime').optional().trim().matches(/^([01]\d|2[0-3]):?([0-5]\d)$/).withMessage('End time must be in HH:mm format'),
  body('maxCapacity').optional().isInt({ min: 0 }).withMessage('Capacity must be a non-negative number'),
  body('priceMultiplier').optional().isFloat({ min: 0.1 }).withMessage('Price multiplier must be at least 0.1')
]);

// GET /stats — Return shift stats (total, active, fullDay, student enrollment counts per shift)
router.get('/stats', async (req, res) => {
  try {
    await Shift.seedDefaults();

    const [total, active, shifts] = await Promise.all([
      Shift.countDocuments(),
      Shift.countDocuments({ isActive: true }),
      Shift.find().sort({ startTime: 1, name: 1 }).lean()
    ]);

    const fullDay = shifts.filter(s =>
      s.code === 'FULL' ||
      s.name.toLowerCase().includes('full day') ||
      s.name.toLowerCase().includes('fullday')
    ).length;

    // Aggregate student counts across shifts
    const activeStudents = await Student.find({ status: 'active' }).populate('plan', 'shift name').lean();
    const studentEnrollment = {};
    shifts.forEach(shift => {
      studentEnrollment[shift.code] = 0;
    });

    activeStudents.forEach(student => {
      const planShift = student.plan?.shift?.toLowerCase();
      if (planShift) {
        const matched = shifts.find(s =>
          s.code.toLowerCase() === planShift ||
          s.name.toLowerCase().replace(/\s+/g, '').includes(planShift) ||
          (planShift === 'fullday' && (s.code === 'FULL' || s.name.toLowerCase().includes('full'))) ||
          (planShift === 'morning' && (s.code === 'MORN' || s.name.toLowerCase().includes('morn'))) ||
          (planShift === 'evening' && (s.code === 'EVE' || s.name.toLowerCase().includes('eve'))) ||
          (planShift === 'night' && (s.code === 'NIGHT' || s.name.toLowerCase().includes('night')))
        );
        if (matched) {
          studentEnrollment[matched.code] = (studentEnrollment[matched.code] || 0) + 1;
        }
      }
    });

    const shiftStats = shifts.map(s => {
      const enrolled = studentEnrollment[s.code] || 0;
      const capacity = s.maxCapacity || 0;
      const occupancyRate = capacity > 0 ? Math.min(100, Math.round((enrolled / capacity) * 100)) : null;
      return {
        ...s,
        enrolledStudents: enrolled,
        occupancyRate
      };
    });

    res.json({
      success: true,
      data: {
        total,
        active,
        inactive: total - active,
        fullDay,
        totalEnrolled: activeStudents.length,
        studentEnrollment,
        shiftStats
      },
      message: 'Shift statistics retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET / — List all shifts (supports ?active=true/false)
router.get('/', async (req, res) => {
  try {
    await Shift.seedDefaults();

    let query = {};
    if (req.query.active !== undefined && req.query.active !== '') {
      query.isActive = req.query.active === 'true' || req.query.active === '1';
    }
    if (req.query.search) {
      const searchRegex = new RegExp(req.query.search, 'i');
      query.$or = [
        { name: searchRegex },
        { code: searchRegex },
        { description: searchRegex }
      ];
    }

    const shifts = await Shift.find(query).sort({ startTime: 1, name: 1 }).lean();
    res.json({
      success: true,
      data: shifts,
      message: 'Shifts retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /:id — Get single shift
router.get('/:id', async (req, res) => {
  try {
    const shift = await Shift.findById(req.params.id).lean();
    if (!shift) {
      return res.status(404).json({ success: false, message: 'Shift not found' });
    }
    res.json({
      success: true,
      data: shift,
      message: 'Shift retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST / — Create shift (name, code, startTime, endTime, maxCapacity, priceMultiplier, description)
router.post('/', roleCheck('owner', 'branch_manager'), createShiftValidations, async (req, res) => {
  try {
    const { name, code, startTime, endTime, maxCapacity, priceMultiplier, daysActive, description, isActive, branch } = req.body;

    const formattedCode = code.trim().toUpperCase();
    const branchId = branch && branch !== 'all' && branch !== 'none' ? branch : null;
    const existing = await Shift.findOne({ code: formattedCode, branch: branchId }).lean();
    if (existing) {
      return res.status(400).json({
        success: false,
        message: `Shift with code "${formattedCode}" already exists for this branch`
      });
    }

    const shift = await Shift.create({
      name: name.trim(),
      code: formattedCode,
      startTime: startTime.trim(),
      endTime: endTime.trim(),
      maxCapacity: maxCapacity !== undefined ? Number(maxCapacity) : 0,
      priceMultiplier: priceMultiplier !== undefined ? Number(priceMultiplier) : 1.0,
      daysActive: Array.isArray(daysActive) && daysActive.length > 0 ? daysActive : ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
      description: description ? description.trim() : '',
      isActive: isActive !== undefined ? Boolean(isActive) : true,
      branch: branchId
    });

    res.status(201).json({
      success: true,
      data: shift,
      message: 'Shift created successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /:id — Update shift
router.put('/:id', roleCheck('owner', 'branch_manager'), updateShiftValidations, async (req, res) => {
  try {
    const shift = await Shift.findById(req.params.id);
    if (!shift) {
      return res.status(404).json({ success: false, message: 'Shift not found' });
    }

    if (req.body.code && req.body.code.trim().toUpperCase() !== shift.code) {
      const codeUpper = req.body.code.trim().toUpperCase();
      const existing = await Shift.findOne({ code: codeUpper, branch: shift.branch, _id: { $ne: shift._id } }).lean();
      if (existing) {
        return res.status(400).json({
          success: false,
          message: `Shift with code "${codeUpper}" already exists for this branch`
        });
      }
      shift.code = codeUpper;
    }

    if (req.body.name !== undefined) shift.name = req.body.name.trim();
    if (req.body.startTime !== undefined) shift.startTime = req.body.startTime.trim();
    if (req.body.endTime !== undefined) shift.endTime = req.body.endTime.trim();
    if (req.body.maxCapacity !== undefined) shift.maxCapacity = Number(req.body.maxCapacity);
    if (req.body.priceMultiplier !== undefined) shift.priceMultiplier = Number(req.body.priceMultiplier);
    if (req.body.daysActive !== undefined) shift.daysActive = req.body.daysActive;
    if (req.body.description !== undefined) shift.description = req.body.description.trim();
    if (req.body.isActive !== undefined) shift.isActive = Boolean(req.body.isActive);

    await shift.save();

    res.json({
      success: true,
      data: shift,
      message: 'Shift updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /:id — Soft delete shift to Recycle Bin
router.delete('/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { moveToTrash } = require('./trash');
    const shift = await Shift.findById(req.params.id);
    if (!shift) {
      return res.status(404).json({ success: false, message: 'Shift not found' });
    }

    shift.isActive = false;
    shift.isDeleted = true;
    await shift.save();

    await moveToTrash({
      itemType: 'shift',
      itemId: shift._id,
      itemTitle: `${shift.name} (${shift.startTime || ''} - ${shift.endTime || ''})`,
      itemSubtitle: `Capacity: ${shift.maxCapacity || 'Unlimited'} • Multiplier: ${shift.priceMultiplier || 1.0}x`,
      originalCollection: 'shifts',
      itemData: shift.toObject ? shift.toObject() : shift,
      user: req.user,
      reason: req.body?.reason || ''
    });

    res.json({
      success: true,
      data: shift,
      message: `Shift "${shift.name}" moved to Recycle Bin (Trash).`
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
