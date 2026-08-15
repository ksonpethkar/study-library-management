const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const Student = require('../models/Student');
const { protect } = require('../middleware/auth');

const roleCheck = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Not authorized for this role' });
    }
    next();
  };
};

function validate(validations) {
  return async (req, res, next) => {
    for (const validation of validations) {
      await validation.run(req);
    }
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array(), message: errors.array()[0]?.msg || 'Validation failed' });
    }
    next();
  };
}

router.use(protect);

// GET /stats
router.get('/stats', async (req, res) => {
  try {
    const stats = await Student.getStats();
    res.json({ success: true, data: stats, message: 'Stats fetched successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /
router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 10;
    const skip = (page - 1) * limit;

    const query = {};
    if (req.query.search) {
      query.$or = [
        { name: { $regex: req.query.search, $options: 'i' } },
        { phone: { $regex: req.query.search, $options: 'i' } },
        { studentId: { $regex: req.query.search, $options: 'i' } }
      ];
    }
    if (req.query.status && req.query.status !== 'all') {
      query.status = req.query.status;
    }
    if (req.query.plan) {
      query.plan = req.query.plan;
    }

    const students = await Student.find(query)
      .populate('plan', 'name price')
      .populate('seat', 'seatNumber zone')
      .sort(req.query.sort || '-createdAt')
      .skip(skip)
      .limit(limit)
      .lean();

    const total = await Student.countDocuments(query);

    res.json({
      success: true,
      data: {
        students,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      },
      message: 'Students fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /:id
router.get('/:id', async (req, res) => {
  try {
    const student = await Student.findById(req.params.id)
      .populate('plan', 'name price')
      .populate('seat', 'seatNumber zone')
      .lean();
      
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }
    res.json({ success: true, data: student, message: 'Student fetched successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /
router.post('/', validate([
  body('name').notEmpty().withMessage('Name is required').trim(),
  body('phone').notEmpty().withMessage('Phone is required').trim()
]), roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    req.body.createdBy = req.user._id;
    
    // Extract customFields before creating student
    const customFieldsData = req.body.customFields;
    delete req.body.customFields;
    
    const student = new Student(req.body);
    
    // Properly set customFields Map including explicit false values
    if (customFieldsData && typeof customFieldsData === 'object') {
      for (const [key, value] of Object.entries(customFieldsData)) {
        if (value !== undefined) {
          student.customFields.set(key, value);
        }
      }
    }
    
    await student.save();
    res.status(201).json({ success: true, data: student, message: 'Student created successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /:id
router.put('/:id', validate([
  body('name').optional().notEmpty().withMessage('Name cannot be empty').trim(),
  body('phone').optional().notEmpty().withMessage('Phone cannot be empty').trim()
]), roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const student = await Student.findById(req.params.id);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    const customFieldsData = req.body.customFields;
    delete req.body.customFields;

    Object.assign(student, req.body);

    if (customFieldsData && typeof customFieldsData === 'object') {
      for (const [key, value] of Object.entries(customFieldsData)) {
        if (value !== undefined) {
          student.customFields.set(key, value);
        }
      }
    }

    await student.save();
    res.json({ success: true, data: student, message: 'Student updated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /:id
router.delete('/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const student = await Student.findByIdAndUpdate(req.params.id, { status: 'inactive' }, { new: true });
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }
    res.json({ success: true, data: student, message: 'Student soft deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /:id/renew
router.post('/:id/renew', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { expiryDate } = req.body;
    const student = await Student.findByIdAndUpdate(req.params.id, { 
      status: 'active',
      ...(expiryDate && { expiryDate })
    }, { new: true });
    
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }
    res.json({ success: true, data: student, message: 'Student renewed successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /bulk-renew
router.post('/bulk-renew', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { studentIds, days = 30 } = req.body;
    if (!Array.isArray(studentIds) || studentIds.length === 0) {
      return res.status(400).json({ success: false, message: 'No students selected' });
    }

    const students = await Student.find({ _id: { $in: studentIds } });
    let updatedCount = 0;

    for (const s of students) {
      const currentExpiry = s.expiryDate && new Date(s.expiryDate) > new Date() ? new Date(s.expiryDate) : new Date();
      const newExpiry = new Date(currentExpiry.getTime() + days * 24 * 60 * 60 * 1000);
      s.expiryDate = newExpiry;
      s.status = 'active';
      await s.save();
      updatedCount++;
    }

    res.json({
      success: true,
      message: `Successfully renewed memberships for ${updatedCount} student(s) by ${days} days.`
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /bulk-deactivate
router.post('/bulk-deactivate', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { studentIds } = req.body;
    if (!Array.isArray(studentIds) || studentIds.length === 0) {
      return res.status(400).json({ success: false, message: 'No students selected' });
    }

    const result = await Student.updateMany(
      { _id: { $in: studentIds } },
      { status: 'inactive' }
    );

    res.json({
      success: true,
      message: `Successfully deactivated ${result.modifiedCount} student(s).`
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /bulk-remind
router.post('/bulk-remind', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { studentIds } = req.body;
    if (!Array.isArray(studentIds) || studentIds.length === 0) {
      return res.status(400).json({ success: false, message: 'No students selected' });
    }

    const students = await Student.find({ _id: { $in: studentIds } });
    const reminders = students.map(s => {
      const expiryStr = s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : 'Soon';
      const cleanPhone = s.phone.replace(/[^0-9]/g, '').slice(-10);
      const text = encodeURIComponent(`Hello ${s.name}, your Study Library subscription validity is active until ${expiryStr}. Please renew on time to retain your seat. Thank you!`);
      return {
        studentId: s._id,
        name: s.name,
        phone: s.phone,
        whatsappUrl: `https://wa.me/91${cleanPhone}?text=${text}`
      };
    });

    res.json({
      success: true,
      data: reminders,
      message: `Prepared WhatsApp reminders for ${reminders.length} student(s).`
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;

