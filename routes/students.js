const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const Student = require('../models/Student');
const Seat = require('../models/Seat');
const Locker = require('../models/Locker');
const User = require('../models/User');
const { generateStudentId } = require('../utils/idGenerator');
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
      .populate('plan'.lean(), 'name price duration durationType shift')
      .populate('seat', 'seatNumber zone status branch')
      .populate('locker', 'lockerNumber monthlyFee status')
      .populate('shift', 'name startTime endTime code')
      .populate('branch', 'name code city address')
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
      .populate('plan'.lean(), 'name price duration durationType shift')
      .populate('seat', 'seatNumber zone status branch')
      .populate('locker', 'lockerNumber monthlyFee status')
      .populate('shift', 'name startTime endTime code')
      .populate('branch', 'name code city address')
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
    // Validate Shift Capacity
    if (req.body.shift || req.body.plan) {
      const Shift = require('../models/Shift');
      const Plan = require('../models/Plan');
      
      let shiftIdToCheck = req.body.shift;
      let shiftCodeToCheck = null;

      if (!shiftIdToCheck && req.body.plan) {
        const planDoc = await Plan.findById(req.body.plan).lean();
        if (planDoc?.shift && planDoc.shift !== 'any') {
          shiftCodeToCheck = planDoc.shift.toLowerCase();
        }
      }

      let shiftDoc = null;
      if (shiftIdToCheck) {
        shiftDoc = await Shift.findById(shiftIdToCheck).lean();
      } else if (shiftCodeToCheck) {
        shiftDoc = await Shift.findOne({
          $or: [
            { code: new RegExp(`^${shiftCodeToCheck}$`, 'i') }.lean(),
            { name: new RegExp(shiftCodeToCheck, 'i') }
          ],
          isActive: true
        });
      }

      if (shiftDoc && shiftDoc.maxCapacity > 0 && !req.body.allowOvercapacity) {
        const currentActiveCount = await Student.countDocuments({
          $or: [
            { shift: shiftDoc._id },
            { 'plan.shift': shiftDoc.code }
          ],
          status: 'active'
        });

        if (currentActiveCount >= shiftDoc.maxCapacity) {
          return res.status(400).json({
            success: false,
            isFull: true,
            message: `Shift "${shiftDoc.name}" is currently FULL (${currentActiveCount}/${shiftDoc.maxCapacity} active). Please add candidate to Waiting List or choose another shift.`
          });
        }
      }
    }

    req.body.createdBy = req.user._id;
    
    if (!req.body.studentId) {
      req.body.studentId = await generateStudentId({ branch: req.body.branch });
    }
    
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

// DELETE /:id - Delete student document, release seat & locker
router.delete('/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const student = await Student.findById(req.params.id).lean();
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student record not found' });
    }

    // Release seat if assigned
    if (student.seat) {
      await Seat.findByIdAndUpdate(student.seat, { status: 'available', currentStudent: null });
    }

    // Release locker if assigned
    if (student.locker) {
      await Locker.findByIdAndUpdate(student.locker, { status: 'available', currentStudent: null });
    }

    // Delete student user account if exists
    if (student.phone || student.email) {
      const orConditions = [];
      if (student.phone) orConditions.push({ phone: student.phone });
      if (student.email) orConditions.push({ email: student.email });
      if (orConditions.length > 0) {
        await User.findOneAndDelete({ $or: orConditions });
      }
    }

    await Student.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: `Student "${student.name}" deleted successfully` });
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

    const WhatsAppService = require('../utils/whatsappService');
    const BusinessProfile = require('../models/BusinessProfile');
    const profile = await BusinessProfile.getProfile();
    const upiId = profile?.upiId || '';
    const bizName = profile?.businessName || 'Study Library';
    const baseUrl = WhatsAppService.getBaseUrl(req);

    const students = await Student.find({ _id: { $in: studentIds } })
      .populate('seat')
      .populate('plan')
      .populate('shift').lean();

    const reminders = [];
    for (const s of students) {
      const renewalAmount = s.plan?.price || 0;
      const upiLink = upiId ? WhatsAppService.generateUpiDeepLink({
        upiId,
        businessName: bizName,
        amount: renewalAmount,
        note: 'SubscriptionRenewal'
      }) : '';

      const expDate = s.expiryDate || s.planExpiresAt;
      const timeLeftStr = expDate ? `${Math.max(0, Math.ceil((new Date(expDate).getTime() - Date.now()) / (1000 * 60 * 60 * 24)))} days` : 'Soon';

      const messageText = await WhatsAppService.getExpiryReminderMessage(
        s,
        timeLeftStr,
        bizName,
        upiId,
        renewalAmount,
        upiLink,
        baseUrl
      );

      const whatsappUrl = WhatsAppService.getClickToChatUrl(s.phone, messageText);
      reminders.push({
        studentId: s._id,
        name: s.name,
        phone: s.phone,
        message: messageText,
        whatsappUrl
      });
    }

    res.json({
      success: true,
      data: reminders,
      message: `Prepared WhatsApp reminders for ${reminders.length} student(s).`
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/students/:id/reset-password - Admin reset & set new password for student
router.post('/:id/reset-password', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { newPassword, sendEmail } = req.body;
    if (!newPassword || newPassword.trim().length < 4) {
      return res.status(400).json({ success: false, message: 'Password must be at least 4 characters long' });
    }

    const student = await Student.findById(req.params.id).lean();
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student record not found' });
    }

    const cleanPhone = (student.phone || '').replace(/[^0-9]/g, '').slice(-10);
    const cleanPassword = newPassword.trim();
    const User = require('../models/User');

    // Find or create matching User account
    let user = await User.findOne({
      $or: [
        ...(student.email ? [{ email: student.email }] : []),
        ...(student.phone ? [{ phone: student.phone }] : [])
      ]
    });

    if (!user) {
      user = new User({
        name: student.name,
        email: student.email || `${student.studentId.toLowerCase()}@studylib.local`,
        phone: student.phone || '0000000000',
        password: cleanPassword,
        role: 'student',
        isActive: true
      });
    } else {
      user.password = cleanPassword;
    }

    await user.save();

    // Generate WhatsApp text & link
    const waText = encodeURIComponent(
      `🔑 *STUDY LIBRARY — PORTAL PASSWORD RESET*\n\n` +
      `Hello *${student.name}*,\n` +
      `Your Student Portal password has been updated by Admin.\n\n` +
      `🆔 *Student ID / Phone*: ${student.studentId} / ${student.phone}\n` +
      `🔑 *New Password / PIN*: ${cleanPassword}\n\n` +
      `🌐 *Login Portal*: https://study-library-management.onrender.com/student-login\n\n` +
      `Please keep your credentials secure.`
    );
    const whatsappUrl = `https://wa.me/91${cleanPhone}?text=${waText}`;

    // Send Email if requested and student has valid email
    let emailSent = false;
    if (sendEmail && student.email && student.email.includes('@')) {
      try {
        const emailService = require('../utils/emailService');
        await emailService.sendMail({
          to: student.email,
          subject: '🔑 Your Student Portal Password Has Been Reset',
          text: `Hello ${student.name},\nYour Student Portal password has been reset by Admin.\nNew Password: ${cleanPassword}\nLogin Portal: https://study-library-management.onrender.com/student-login`,
          html: `<div style="font-family: sans-serif; padding: 20px; background: #f8fafc; border-radius: 8px;">
            <h2>🔑 Student Portal Password Reset</h2>
            <p>Hello <strong>${student.name}</strong>,</p>
            <p>Your password for the Study Library Student Portal has been updated by Admin.</p>
            <div style="background: #ffffff; padding: 15px; border-radius: 6px; border: 1px solid #cbd5e1; margin: 15px 0;">
              <p style="margin: 4px 0;"><strong>Student ID:</strong> ${student.studentId}</p>
              <p style="margin: 4px 0;"><strong>New Password / PIN:</strong> <code style="font-size: 1.1em; background: #f1f5f9; padding: 2px 6px; border-radius: 4px;">${cleanPassword}</code></p>
            </div>
            <p><a href="https://study-library-management.onrender.com/student-login" style="display: inline-block; padding: 10px 18px; background: #6366f1; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: bold;">Enter Student Portal ➔</a></p>
          </div>`
        });
        emailSent = true;
      } catch (e) {
        console.error('Failed to send password reset email:', e);
      }
    }

    try {
      const { logAction } = require('../middleware/auditLogger');
      if (logAction) logAction(req, 'update', 'students', `Reset password for student ${student.name} (${student.studentId})`);
    } catch (e) {}

    res.json({
      success: true,
      message: `Password reset successfully for ${student.name}!`,
      data: {
        newPassword: cleanPassword,
        whatsappUrl,
        emailSent
      }
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;

