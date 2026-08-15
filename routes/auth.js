const express = require('express');
const router = express.Router();
const User = require('../models/User');
const BusinessProfile = require('../models/BusinessProfile');
const SystemSetting = require('../models/SystemSetting');
const { protect } = require('../middleware/auth');
const { validateSetup, validateRegistration, validateLogin, validatePasswordChange } = require('../middleware/validate');
const { authLimiter } = require('../middleware/rateLimiter');
const CustomField = require('../models/CustomField');
const { Referral } = require('../models/Operations');
const emailService = require('../utils/emailService');
const whatsappService = require('../utils/whatsappService');

// @route   POST /api/auth/setup
// @desc    First-time setup (create owner account + business profile)
router.post('/setup', authLimiter, validateSetup, async (req, res) => {
  try {
    const userCount = await User.countDocuments();
    if (userCount > 0) {
      return res.status(400).json({ success: false, message: 'Setup has already been completed' });
    }

    const { name, email, password, businessName, phone } = req.body;

    const owner = await User.create({
      name,
      email,
      password,
      phone,
      role: 'owner',
    });

    const profile = await BusinessProfile.getProfile();
    profile.businessName = businessName;
    profile.email = email;
    profile.phone = phone;
    profile.isSetupComplete = true;
    await profile.save();

    await SystemSetting.initDefaults();

    const token = owner.generateAuthToken();

    res.status(201).json({
      success: true,
      data: {
        user: { id: owner._id, name: owner.name, email: owner.email, role: owner.role },
        token
      },
      message: 'Setup completed successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/auth/register
// @desc    Register new user
router.post('/register', authLimiter, validateRegistration, async (req, res) => {
  try {
    const { name, email, password, phone, role } = req.body;

    let userRole = 'student';
    let isActive = false; // by default false for student, needs approval

    // Check if autoApprove is enabled
    const autoApprove = await SystemSetting.getSetting('admission.autoApprove');
    if (autoApprove) {
      isActive = true;
    }

    if (role === 'branch_manager' || role === 'owner') {
      // Must be logged in as owner to create these
      // We will check header directly here for simplicity or use a separate protected route,
      // but as per requirement: "Only owner can create branch_manager accounts"
      let token;
      if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
        token = req.headers.authorization.split(' ')[1];
      }
      if (!token) {
        return res.status(401).json({ success: false, message: 'Not authorized to create manager accounts' });
      }
      const jwt = require('jsonwebtoken');
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const requester = await User.findById(decoded.id);
      if (!requester || requester.role !== 'owner') {
        return res.status(403).json({ success: false, message: 'Only owners can create branch manager accounts' });
      }
      userRole = role;
      isActive = true; // admins are active by default
    }

    const userExists = await User.findOne({ email });
    if (userExists) {
      return res.status(400).json({ success: false, message: 'User already exists' });
    }

    const user = await User.create({
      name, email, password, phone, role: userRole, isActive
    });

    res.status(201).json({
      success: true,
      data: { id: user._id, name: user.name, email: user.email, role: user.role, isActive: user.isActive },
      message: 'User registered successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/auth/login
// @desc    Login
router.post('/login', authLimiter, validateLogin, async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findByCredentials(email, password);
    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    if (!user.isActive) {
      return res.status(403).json({ success: false, message: 'Account is inactive or pending approval' });
    }

    user.lastLogin = Date.now();
    await user.save({ validateBeforeSave: false });

    const token = user.generateAuthToken();
    const businessProfile = await BusinessProfile.getProfile();

    res.json({
      success: true,
      data: {
        user: { id: user._id, name: user.name, email: user.email, role: user.role, avatar: user.avatar },
        token,
        businessProfile
      },
      message: 'Logged in successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   GET /api/auth/me
// @desc    Get current user
router.get('/me', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    res.json({ success: true, data: user, message: 'User data retrieved' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   GET /api/auth/check-setup
// @desc    Check if first-time setup is needed
router.get('/check-setup', async (req, res) => {
  try {
    const userCount = await User.countDocuments();
    res.json({ success: true, data: { isSetupComplete: userCount > 0 }, message: 'Setup status checked' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/auth/change-password
// @desc    Change password
router.post('/change-password', protect, validatePasswordChange, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = await User.findById(req.user.id).select('+password');

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Incorrect current password' });
    }

    user.password = newPassword;
    await user.save();

    res.json({ success: true, data: {}, message: 'Password updated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

const Student = require('../models/Student');
const Notification = require('../models/Notification');
const { generateStudentId } = require('../utils/idGenerator');

// @route   POST /api/auth/public-register
// @desc    Public online admission registration for prospective students
router.post('/public-register', authLimiter, async (req, res) => {
  try {
    const {
      name,
      email,
      phone,
      password,
      gender,
      dob,
      targetExams,
      plan,
      notes,
      signature,
      photo,
      customFields,
      referralCode,
      requestLocker
    } = req.body;

    if (!name || !phone) {
      return res.status(400).json({ success: false, message: 'Name and Phone number are required' });
    }

    // Check if phone or email already exists
    const existingStudent = await Student.findOne({
      $or: [
        { phone },
        ...(email ? [{ email }] : [])
      ]
    });

    if (existingStudent) {
      return res.status(400).json({
        success: false,
        message: 'A student with this phone number or email is already registered. Please login or contact the front desk.'
      });
    }

    // Generate Student ID
    const studentCount = await Student.countDocuments();
    const prefix = await SystemSetting.getSetting('admission.idPrefix') || 'STU';
    const year = new Date().getFullYear();
    const studentId = generateStudentId(prefix, year, studentCount + 1);

    // Validate custom fields
    const activeFields = await CustomField.getActiveFields();
    const missingFields = [];
    for (const field of activeFields) {
      if (field.required && !field.isSystemField) {
        if (!customFields || customFields[field.fieldName] === undefined || customFields[field.fieldName] === null || customFields[field.fieldName] === '') {
          missingFields.push(field.label);
        }
      }
    }
    if (missingFields.length > 0) {
      return res.status(400).json({ success: false, message: `Missing required custom fields: ${missingFields.join(', ')}` });
    }

    // Support referral code validation
    let referringStudent = null;
    let referralDiscount = 0;
    if (referralCode) {
      referringStudent = await Student.findOne({ 
        $or: [{ studentId: referralCode }, { phone: referralCode }] 
      });
      if (referringStudent) {
        referralDiscount = 500; // default discount
      }
    }

    // Flag locker interest
    let finalNotes = notes || '';
    if (requestLocker) {
      finalNotes += (finalNotes ? '\n' : '') + '[Locker Requested]';
    }

    // Create Student Document
    const newStudent = new Student({
      studentId,
      name,
      phone,
      email: email || '',
      gender: (gender || 'other').toLowerCase(),
      dateOfBirth: dob ? new Date(dob) : null,
      targetExams: Array.isArray(targetExams) ? targetExams : (targetExams ? [targetExams] : []),
      plan: plan || null,
      notes: finalNotes,
      photo: photo || '',
      signature: signature || '',
      customFields: customFields || {},
      status: 'active'
    });

    if (referringStudent) {
      newStudent.customFields = newStudent.customFields || {};
      if (newStudent.customFields instanceof Map) {
         newStudent.customFields.set('referredBy', referringStudent.studentId);
         newStudent.customFields.set('referralDiscount', referralDiscount);
      } else {
         newStudent.customFields.referredBy = referringStudent.studentId;
         newStudent.customFields.referralDiscount = referralDiscount;
      }
    }

    await newStudent.save();

    // Create user login account if password provided
    if (email && password) {
      const existingUser = await User.findOne({ email });
      if (!existingUser) {
        await User.create({
          name,
          email,
          phone,
          password,
          role: 'student',
          isActive: true
        });
      }
    }

    // Notify Library Admins
    await Notification.create({
      title: `🎓 Online Admission: ${name}`,
      message: `New student registration online! ID: ${studentId} • Phone: ${phone}`,
      type: 'student',
      link: '#/students'
    });

    if (referringStudent) {
      await Referral.create({
        referrerStudent: referringStudent._id,
        referrerName: referringStudent.name,
        referrerPhone: referringStudent.phone,
        refereeName: name,
        refereePhone: phone,
        refereeEmail: email || '',
        status: 'converted',
        convertedStudent: newStudent._id
      });
    }

    const business = await BusinessProfile.getProfile();

    // Trigger automated Welcome WhatsApp & Email notifications
    try {
      const welcomeBaseMsg = whatsappService.getAdmissionMessage ? whatsappService.getAdmissionMessage(newStudent, business.businessName) : 'Welcome to the library!';
      const passwordMsg = password ? `\n\nLogin Password: ${password}` : '';
      const fullMessage = welcomeBaseMsg + passwordMsg;

      if (email && emailService.sendMail) {
        await emailService.sendMail({
          to: email,
          subject: `Welcome to ${business.businessName}`,
          html: `<p>${fullMessage.replace(/\n/g, '<br>')}</p>`
        });
      }
      
      if (whatsappService.sendWelcomeMessage) {
         await whatsappService.sendWelcomeMessage(newStudent, password);
      }
    } catch (notifyErr) {
      console.error('Notification Error:', notifyErr);
    }

    res.status(201).json({
      success: true,
      message: 'Admission submitted successfully',
      data: {
        student: newStudent,
        admissionSlip: true,
        studentId: newStudent.studentId,
        name: newStudent.name,
        email: newStudent.email,
        phone: newStudent.phone
      }
    });

  } catch (error) {
    console.error('Error during public registration:', error);
    res.status(500).json({ success: false, message: error.message || 'Registration failed' });
  }
});

// @route   POST /api/auth/student-login
// @desc    Dedicated student login via Student ID or Phone or Email
router.post('/student-login', authLimiter, async (req, res) => {
  try {
    const { identifier, password } = req.body;

    if (!identifier) {
      return res.status(400).json({ success: false, message: 'Student ID, Phone number, or Email is required' });
    }

    const trimmedId = identifier.trim();

    // Find student in Student model
    const student = await Student.findOne({
      $or: [
        { studentId: { $regex: new RegExp(`^${trimmedId}$`, 'i') } },
        { phone: trimmedId },
        { email: trimmedId.toLowerCase() }
      ]
    }).populate('seat').populate('plan');

    if (!student) {
      return res.status(404).json({ success: false, message: 'Student record not found. Please verify your Student ID or Phone number.' });
    }

    // Check corresponding User record if password was provided
    let user = null;
    if (student.email) {
      user = await User.findOne({ email: student.email.toLowerCase() });
    }
    if (!user && student.phone) {
      user = await User.findOne({ phone: student.phone });
    }

    // If student user exists and password is provided, verify password
    if (user) {
      if (!password) {
        return res.status(400).json({ success: false, message: 'Password is required' });
      }
      const isMatch = await user.comparePassword(password);
      if (!isMatch) {
        return res.status(401).json({ success: false, message: 'Invalid password. If you forgot, please contact library front desk.' });
      }
    }

    // If user record does not exist yet, create a student user
    if (!user) {
      const randomPwd = password || `Lib@${student.phone.slice(-4)}`;
      user = await User.create({
        name: student.name,
        email: student.email || `${student.studentId.toLowerCase()}@studylib.local`,
        phone: student.phone,
        password: randomPwd,
        role: 'student',
        isActive: true
      });
    }

    user.lastLogin = Date.now();
    await user.save({ validateBeforeSave: false });

    const token = user.generateAuthToken();
    const businessProfile = await BusinessProfile.getProfile();

    res.json({
      success: true,
      data: {
        token,
        student,
        user: { id: user._id, name: user.name, role: user.role, email: user.email },
        businessProfile
      },
      message: `Welcome back, ${student.name}!`
    });
  } catch (error) {
    console.error('Error during student login:', error);
    res.status(500).json({ success: false, message: error.message || 'Login failed' });
  }
});

module.exports = router;
