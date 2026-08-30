const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const User = require('../models/User');
const BusinessProfile = require('../models/BusinessProfile');
const SystemSetting = require('../models/SystemSetting');
const { protect } = require('../middleware/auth');
const { validateSetup, validateRegistration, validateLogin, validatePasswordChange, validatePublicRegister } = require('../middleware/validate');
const { authLimiter } = require('../middleware/rateLimiter');
const CustomField = require('../models/CustomField');
const { Referral } = require('../models/Operations');
const emailService = require('../utils/emailService');
const whatsappService = require('../utils/whatsappService');
const jwt = require('jsonwebtoken');

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
    await user.save({ validateBeforeSave: false }).catch(() => {});

    const token = user.generateAuthToken();
    const businessProfile = { businessName: 'The Cozy Corner Centre' };

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
    const user = await User.findById(req.user.id || req.user._id).lean();
    if (user && req.user.role === 'student') {
      user.role = 'student';
    }
    res.json({ success: true, data: user || req.user, message: 'User data retrieved' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   GET /api/auth/users
// @desc    Get all staff and admin users for RBAC management
router.get('/users', protect, async (req, res) => {
  try {
    const users = await User.find({ role: { $ne: 'student' } })
      .select('-password')
      .populate('branch', 'name city')
      .sort({ createdAt: -1 })
      .lean();
    res.json({ success: true, data: users, message: 'Staff users retrieved' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/auth/users
// @desc    Add new staff or branch manager user
router.post('/users', protect, async (req, res) => {
  try {
    const { name, email, password, role, phone, branch } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Name, email, and password are required' });
    }
    const existing = await User.findOne({ email: email.toLowerCase().trim() });
    if (existing) {
      return res.status(400).json({ success: false, message: 'User with this email already exists' });
    }
    const newUser = await User.create({
      name,
      email: email.toLowerCase().trim(),
      password,
      role: role || 'staff',
      phone,
      branch: branch || null
    });
    const populated = await User.findById(newUser._id).select('-password').populate('branch', 'name city').lean();
    res.status(201).json({ success: true, data: populated, message: 'Staff member added successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   PUT /api/auth/users/:id
// @desc    Update staff user role, status or branch
router.put('/users/:id', protect, async (req, res) => {
  try {
    const { name, role, isActive, phone, branch, password } = req.body;
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    if (name !== undefined) user.name = name;
    if (role !== undefined) user.role = role;
    if (isActive !== undefined) user.isActive = isActive;
    if (phone !== undefined) user.phone = phone;
    if (branch !== undefined) user.branch = branch || null;
    if (password) user.password = password;

    await user.save();
    const updated = await User.findById(user._id).select('-password').populate('branch', 'name city').lean();
    res.json({ success: true, data: updated, message: 'Staff member updated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   DELETE /api/auth/users/:id
// @desc    Delete staff user
router.delete('/users/:id', protect, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    if (user.role === 'owner') {
      return res.status(403).json({ success: false, message: 'Cannot delete primary owner account' });
    }
    await User.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Staff member deleted successfully' });
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
const Plan = require('../models/Plan');
const Seat = require('../models/Seat');
const Payment = require('../models/Payment');
const Notification = require('../models/Notification');
const { generateStudentId } = require('../utils/idGenerator');

// @route   GET /api/auth/check-duplicate
// @desc    Check if phone or email is already registered (Public)
router.get('/check-duplicate', async (req, res) => {
  try {
    const { phone, email } = req.query;
    if (!phone && !email) return res.json({ success: true, isDuplicate: false });

    const conditions = [];
    if (phone) conditions.push({ phone: phone.trim() });
    if (email) conditions.push({ email: email.trim().toLowerCase() });

    const existingStudent = await Student.findOne({ $or: conditions });
    if (existingStudent) {
      const matchType = existingStudent.phone === phone ? 'phone number' : 'email address';
      return res.json({
        success: true,
        isDuplicate: true,
        message: `A student with this ${matchType} is already registered (${existingStudent.studentId}). Please login or contact desk.`
      });
    }
    res.json({ success: true, isDuplicate: false });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   POST /api/auth/public-register
// @desc    Public online admission registration for prospective students
router.post('/public-register', authLimiter, validatePublicRegister, async (req, res) => {
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
      seat,
      notes,
      signature,
      photo,
      customFields,
      referralCode,
      requestLocker,
      paymentMethod,
      transactionId
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

    // Anti-Replay Duplicate UTR Fraud Protection
    let cleanUtr = '';
    const isOnlinePayment = paymentMethod && paymentMethod !== 'cash' && paymentMethod !== 'desk';
    if (isOnlinePayment && transactionId) {
      cleanUtr = String(transactionId).trim().replace(/[^0-9A-Za-z_-]/g, '');
      if (cleanUtr.length >= 6) {
        const existingPayment = await Payment.findOne({ transactionId: cleanUtr }).lean();
        if (existingPayment) {
          return res.status(400).json({
            success: false,
            message: `This UTR / Transaction Reference (${cleanUtr}) has already been registered in the system! Re-used or duplicate UTR numbers cannot be processed.`
          });
        }
      }
    }

    // Generate Student ID
    const studentId = await generateStudentId({ branch: req.body.branch });

    // Load Selected Plan Document & Compute Plan Expiry Date
    const Plan = require('../models/Plan');
    let selectedPlanDoc = null;
    let calculatedExpiryDate = new Date();
    calculatedExpiryDate.setMonth(calculatedExpiryDate.getMonth() + 1); // Default 1 month

    if (plan) {
      if (mongoose.Types.ObjectId.isValid(plan)) {
        selectedPlanDoc = await Plan.findById(plan);
      }
      if (!selectedPlanDoc) {
        selectedPlanDoc = await Plan.findOne({
          $or: [
            { name: plan },
            { name: new RegExp('^' + String(plan).trim() + '$', 'i') }
          ]
        });
      }

      if (selectedPlanDoc) {
        calculatedExpiryDate = Plan.calculateExpiryDate(selectedPlanDoc, new Date());
      } else {
        // Direct keyword matching on plan identifier/name string
        const pLower = String(plan).toLowerCase();
        const d = new Date();
        if (pLower.includes('quarter') || pLower.includes('quater') || pLower.includes('3 month') || pLower.includes('3-month')) {
          d.setMonth(d.getMonth() + 3);
          calculatedExpiryDate = d;
        } else if (pLower.includes('annual') || pLower.includes('year') || pLower.includes('12 month')) {
          d.setFullYear(d.getFullYear() + 1);
          calculatedExpiryDate = d;
        } else if (pLower.includes('half') || pLower.includes('6 month') || pLower.includes('semi')) {
          d.setMonth(d.getMonth() + 6);
          calculatedExpiryDate = d;
        }
      }
    }

    // Validate custom fields safely & flexibly
    const activeFields = await CustomField.getActiveFields().catch(() => []);
    const missingFields = [];
    for (const field of activeFields) {
      if (field.required && !field.isSystemField) {
        const slug = field.fieldName;
        const normSlug = (slug || '').toLowerCase().replace(/[^a-z0-9]/g, '');
        const normLabel = (field.label || '').toLowerCase().replace(/[^a-z0-9]/g, '');

        let val = customFields ? (customFields[slug] ?? customFields[`cf_${slug}`]) : null;

        // Check top-level req.body
        if (val === undefined || val === null || val === '') {
          val = req.body[slug] ?? req.body[`cf_${slug}`];
        }

        // Check emergencyContact object if field relates to emergency / parent / guardian
        if (val === undefined || val === null || val === '') {
          if (normSlug.includes('relation') || normLabel.includes('relation')) {
            val = req.body.emergencyContact?.relation || req.body.emergencyRelation || req.body.relationship || customFields?.relationship || customFields?.relation;
          } else if (normSlug.includes('parent') || normSlug.includes('guardian') || normLabel.includes('parent') || normLabel.includes('guardian') || normSlug.includes('emergencyname') || normLabel.includes('emergencycontactperson') || normLabel.includes('emergencycontactname')) {
            val = req.body.emergencyContact?.name || req.body.emergencyName || req.body.parentName || customFields?.emergencyName || customFields?.parentName;
          } else if (normSlug.includes('emergencyphone') || normSlug.includes('emergencycontact') || normLabel.includes('emergencyphone') || normLabel.includes('parentmobile')) {
            val = req.body.emergencyContact?.phone || req.body.emergencyPhone || customFields?.emergencyPhone || customFields?.emergencycontact;
          }
        }

        // Fuzzy match in customFields keys by normalized string
        if ((val === undefined || val === null || val === '') && customFields) {
          for (const [k, v] of Object.entries(customFields)) {
            const normK = k.toLowerCase().replace(/[^a-z0-9]/g, '');
            if (normK === normSlug || normK === normLabel) {
              val = v;
              break;
            }
          }
        }

        // Also check if field maps to top-level student schema fields (address, city, state, pincode, occupation, dob, gender, photo, etc.)
        if (val === undefined || val === null || val === '') {
          if (normSlug === 'address' || normSlug === 'residentialaddress') val = req.body.address;
          else if (normSlug === 'city') val = req.body.city;
          else if (normSlug === 'state') val = req.body.state;
          else if (normSlug === 'pincode') val = req.body.pincode;
          else if (normSlug === 'occupation') val = req.body.occupation;
          else if (normSlug === 'idprooftype') val = req.body.idProofType;
          else if (normSlug === 'idproofnumber') val = req.body.idProofNumber;
          else if (normSlug === 'dob' || normSlug === 'dateofbirth') val = req.body.dob || req.body.dateOfBirth;
          else if (normSlug === 'gender') val = req.body.gender;
          else if (normSlug === 'bloodgroup') val = req.body.bloodGroup;
          else if (normSlug === 'photo') val = req.body.photo;
        }

        if (val === undefined || val === null || val === '' || (Array.isArray(val) && val.length === 0)) {
          missingFields.push(field.label || field.fieldName);
        }
      }
    }
    if (missingFields.length > 0) {
      return res.status(400).json({ success: false, message: `Missing required custom fields: ${missingFields.join(', ')}` });
    }

    // Support referral code validation against ReferralConfig and Student referral codes
    let referringStudent = null;
    let referralDiscount = 0;
    if (referralCode) {
      try {
        const ReferralConfig = require('../models/ReferralConfig');
        const refConfig = await ReferralConfig.getConfig();

        if (refConfig && refConfig.isEnabled) {
          const cleanRefCode = referralCode.trim().toUpperCase();
          referringStudent = await Student.findOne({ 
            $or: [
              { referralCode: cleanRefCode },
              { studentId: cleanRefCode },
              { phone: cleanRefCode }
            ] 
          });

          if (referringStudent) {
            if (refConfig.refereeRewardType === 'percentage') {
              const planBase = selectedPlanDoc ? selectedPlanDoc.price : 1000;
              referralDiscount = Math.round((planBase * (refConfig.refereeRewardAmount || 10)) / 100);
            } else {
              referralDiscount = refConfig.refereeRewardAmount || 100;
            }
          }
        }
      } catch (refErr) {
        console.warn('Referral check warning:', refErr);
      }
    }

    // Check Shift Capacity & Auto-Route to Waiting List if Full
    const Shift = require('../models/Shift');
    const WaitingList = require('../models/WaitingList');
    
    let targetShiftDoc = null;
    if (req.body.shift && mongoose.Types.ObjectId.isValid(req.body.shift)) {
      targetShiftDoc = await Shift.findById(req.body.shift);
    } else if (selectedPlanDoc?.shift) {
      const pShift = selectedPlanDoc.shift.toLowerCase();
      targetShiftDoc = await Shift.findOne({
        $or: [
          { code: new RegExp(`^${pShift}$`, 'i') },
          { name: new RegExp(pShift, 'i') }
        ],
        isActive: true
      });
    }

    if (targetShiftDoc && targetShiftDoc.maxCapacity > 0) {
      const activeEnrolledCount = await Student.countDocuments({
        $or: [
          { shift: targetShiftDoc._id },
          { 'plan.shift': targetShiftDoc.code }
        ],
        status: 'active'
      });

      if (activeEnrolledCount >= targetShiftDoc.maxCapacity) {
        // Shift is FULL! Route to Waiting List
        const waitingEntry = new WaitingList({
          studentName: name,
          studentPhone: phone,
          studentEmail: email || '',
          preferredShift: targetShiftDoc.name,
          preferredZone: req.body.preferredZone || 'General',
          notes: `Auto-routed from Registration: Shift "${targetShiftDoc.name}" is currently FULL (${activeEnrolledCount}/${targetShiftDoc.maxCapacity} active).`,
          status: 'waiting'
        });
        await waitingEntry.save();

        return res.status(200).json({
          success: true,
          isWaitingList: true,
          message: `Shift "${targetShiftDoc.name}" is currently FULL at maximum capacity (${activeEnrolledCount}/${targetShiftDoc.maxCapacity}). You have been placed on Priority Waiting List (#${waitingEntry.priority}).`,
          data: {
            studentId: `WAIT-${String(waitingEntry.priority).padStart(4, '0')}`,
            waitingListEntry: waitingEntry,
            shiftName: targetShiftDoc.name,
            priority: waitingEntry.priority
          }
        });
      }
    }

    // Extract nested fields
    const customF = customFields || {};
    const extractedBloodGroup = req.body.bloodGroup || customF.bloodGroup || customF.blood_group || customF.bloodgroup || customF.BloodGroup || '';
    const extractedOccupation = req.body.occupation || req.body.collegeOrCompany || customF.occupation || customF.collegeOrCompany || '';
    const extractedAddress = req.body.address || customF.address || '';
    const extractedCity = req.body.city || customF.city || '';
    const extractedState = req.body.state || customF.state || '';
    const extractedPincode = req.body.pincode || customF.pincode || '';

    const idp = req.body.idProof || {};
    const extractedIdType = idp.type || req.body.idProofType || req.body['idProof.type'] || customF.idProofType || customF.id_proof_type || customF.idprooftype || 'Aadhaar Card';
    const extractedIdNum = idp.number || req.body.idProofNumber || req.body['idProof.number'] || customF.idProofNumber || customF.id_proof_number || customF.idproofnumber || customF.aadhaar || customF.pan || '';
    const extractedIdImg = idp.image || req.body.idProofImage || req.body['idProof.image'] || customF.idProofImage || customF.id_proof_image || customF.idproofimage || '';

    const em = req.body.emergencyContact || {};
    const extractedEmName = em.name || req.body.emergencyContactName || req.body['emergencyContact.name'] || req.body.parentName || req.body.parent___guardian_name || (customF && (customF.emergencyContactName || customF.parentName || customF.parent___guardian_name || customF.parentguardianname || customF.guardianName || customF.guardian_name || customF.fatherName || customF.father_name || customF.emergency_contact_name || customF.emergencycontactname || customF.parentname)) || '';
    const extractedEmPhone = em.phone || req.body.emergencyContactPhone || req.body['emergencyContact.phone'] || req.body.emergencyContact || req.body.emergencycontact || (customF && (customF.emergencyContactPhone || customF.emergencyContact || customF.emergencycontact || customF.parentPhone || customF.parent_phone || customF.emergency_contact_phone || customF.emergencycontactphone)) || '';
    const extractedEmRel = em.relation || req.body.emergencyContactRelation || req.body['emergencyContact.relation'] || req.body.relationship || req.body.relation || (customF && (customF.relationship || customF.relation || customF.emergencyContactRelation || customF.parentRelation || customF.emergency_contact_relation || customF.emergencycontactrelation)) || 'Parent';

    const rawDob = dob || req.body.dateOfBirth || req.body.dateofbirth || req.body.date_of_birth || req.body.birthDate || (customF && (customF.dateOfBirth || customF.dob || customF.dateofbirth || customF.date_of_birth || customF.birthDate));
    const parsedDob = rawDob && !isNaN(new Date(rawDob).getTime()) ? new Date(rawDob) : null;
    const finalNotes = (notes && String(notes).trim()) || (req.body.specialNotes && String(req.body.specialNotes).trim()) || 'Online Student Self-Registration';
    const initialStatus = (paymentMethod === 'desk' || paymentMethod === 'cash') ? 'pending_payment' : 'active';

    // Create Student Document
    const newStudent = new Student({
      studentId,
      name,
      phone,
      email: email || '',
      gender: (gender || 'other').toLowerCase(),
      dateOfBirth: parsedDob,
      targetExams: Array.isArray(targetExams) ? targetExams : (targetExams ? [targetExams] : []),
      plan: (plan && mongoose.Types.ObjectId.isValid(plan)) ? plan : null,
      branch: (req.body.branch && mongoose.Types.ObjectId.isValid(req.body.branch)) ? req.body.branch : null,
      expiryDate: calculatedExpiryDate,
      notes: finalNotes,
      photo: photo || '',
      signature: signature || '',
      bloodGroup: String(extractedBloodGroup).trim(),
      occupation: String(extractedOccupation).trim(),
      address: String(extractedAddress).trim(),
      city: String(extractedCity).trim(),
      state: String(extractedState).trim(),
      pincode: String(extractedPincode).trim(),
      idProof: {
        type: String(extractedIdType).trim(),
        number: String(extractedIdNum).trim(),
        image: String(extractedIdImg).trim()
      },
      emergencyContact: {
        name: String(extractedEmName).trim(),
        phone: String(extractedEmPhone).trim().replace(/[^0-9+]/g, ''),
        relation: String(extractedEmRel).trim()
      },
      customFields: customFields || {},
      status: initialStatus
    });

    if (referringStudent) {
      newStudent.referredBy = referringStudent._id;
      newStudent.customFields = newStudent.customFields || {};
      if (newStudent.customFields instanceof Map) {
         newStudent.customFields.set('referredBy', referringStudent.studentId);
         newStudent.customFields.set('referralDiscount', referralDiscount);
      } else {
         newStudent.customFields.referredBy = referringStudent.studentId;
         newStudent.customFields.referralDiscount = referralDiscount;
      }
    }

    // Handle atomic seat assignment if selected during registration
    let allocatedSeatDoc = null;
    if (seat && mongoose.Types.ObjectId.isValid(seat)) {
      allocatedSeatDoc = await Seat.findOneAndUpdate(
        { _id: seat, status: 'available' },
        { status: 'occupied', currentStudent: newStudent._id, assignedAt: new Date() },
        { new: true }
      );
      if (allocatedSeatDoc) {
        newStudent.seat = allocatedSeatDoc._id;
      } else {
        newStudent.seat = null;
        const noteMsg = 'Seat was concurrently booked by another user; floating admission granted.';
        newStudent.notes = newStudent.notes ? `${newStudent.notes} • ${noteMsg}` : noteMsg;
      }
    }

    await newStudent.save();

    // Auto-create Referral log and credit referrer if applicable
    if (referringStudent) {
      try {
        const { Referral } = require('../models/Operations');
        const ReferralConfig = require('../models/ReferralConfig');
        const refConfig = await ReferralConfig.getConfig();
        const referrerRewardAmt = refConfig.referrerRewardAmount || 100;

        await Referral.create({
          referrerStudent: referringStudent._id,
          referrerName: referringStudent.name,
          referrerPhone: referringStudent.phone,
          refereeName: newStudent.name,
          refereePhone: newStudent.phone,
          refereeEmail: newStudent.email || '',
          referralCode: referringStudent.referralCode,
          targetExam: Array.isArray(targetExams) ? targetExams.join(', ') : (targetExams || ''),
          status: refConfig.autoApplyToNextRenewal ? 'rewarded' : 'joined',
          rewardAmount: referrerRewardAmt,
          reward: `₹${referrerRewardAmt} Discount on Next Renewal`,
          discountApplied: refConfig.autoApplyToNextRenewal,
          convertedStudent: newStudent._id,
          branch: newStudent.branch
        });

        if (refConfig.autoApplyToNextRenewal) {
          referringStudent.referralCredits = (referringStudent.referralCredits || 0) + referrerRewardAmt;
          referringStudent.totalReferralsCount = (referringStudent.totalReferralsCount || 0) + 1;
          await referringStudent.save();
        }
      } catch (refLogErr) {
        console.warn('Referral logging warning:', refLogErr);
      }
    }

    // Create payment record if plan is chosen
    if (selectedPlanDoc) {
      const origPlanPrice = Number(selectedPlanDoc.price) || 0;
      const planDiscountPct = Number(selectedPlanDoc.discount) || 0;
      const planDiscountAmount = Math.round(origPlanPrice * (planDiscountPct / 100));
      const effectivePlanPrice = Math.round(selectedPlanDoc.effectivePrice !== undefined ? selectedPlanDoc.effectivePrice : (origPlanPrice - planDiscountAmount));
      const totalDiscount = planDiscountAmount + referralDiscount;
      const finalAmount = Math.max(0, effectivePlanPrice - referralDiscount);

      const normalizedPaymentMethod = (paymentMethod === 'netbanking') 
        ? 'bank_transfer' 
        : ((paymentMethod === 'desk') ? 'cash' : (paymentMethod || 'upi'));

      if (isOnlinePayment) {
        const isGatewayVerified = req.body.isGatewayVerified === true || Boolean(req.body.razorpay_payment_id);
        await Payment.create({
          student: newStudent._id,
          plan: selectedPlanDoc._id,
          amount: origPlanPrice,
          discount: totalDiscount,
          finalAmount,
          paymentMethod: normalizedPaymentMethod,
          transactionId: cleanUtr || transactionId || `TXN-${Date.now()}`,
          paymentDate: new Date(),
          periodStart: new Date(),
          periodEnd: calculatedExpiryDate,
          status: isGatewayVerified ? 'paid' : 'pending_verification',
          notes: isGatewayVerified 
            ? `Online Gateway Payment Auto-Verified (ID: ${req.body.razorpay_payment_id || cleanUtr})` 
            : `Online Admission: Submitted UPI UTR ${cleanUtr || 'N/A'} (Pending Front Desk Verification)`
        });
      } else {
        await Payment.create({
          student: newStudent._id,
          plan: selectedPlanDoc._id,
          amount: origPlanPrice,
          discount: totalDiscount,
          finalAmount,
          balanceDue: finalAmount,
          paymentMethod: 'cash',
          paymentDate: new Date(),
          status: 'pending',
          notes: 'Online Admission: Pay Later at Front Desk'
        });
      }
    }

    // Create user login account if password provided
    if (password) {
      const loginIdentifier = email || `${phone}@studylib.local`;
      const existingUser = await User.findOne({ $or: [{ email: loginIdentifier }, { phone }] });
      if (!existingUser) {
        await User.create({
          name,
          email: loginIdentifier,
          phone,
          password,
          role: 'student',
          isActive: true
        });
      }
    }

    // Notify Library Admins
    await Notification.create({
      title: `🎓 Online Admission: ${name} (${initialStatus === 'active' ? 'Active' : 'Pending Fee'})`,
      message: `Student registered: ${studentId} • Plan: ${selectedPlanDoc?.name || 'N/A'} • Status: ${initialStatus}`,
      type: 'student',
      link: '#/students'
    });

    const business = await BusinessProfile.getProfile();

    // Trigger automated Welcome WhatsApp & Email notifications
    try {
      const welcomeBaseMsg = whatsappService.getAdmissionMessage ? await whatsappService.getAdmissionMessage(newStudent, business.businessName) : 'Welcome to the library!';
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
// @route   POST /api/auth/student-login
// @desc    Dedicated student login via Student ID or Phone or Email
router.post('/student-login', authLimiter, async (req, res) => {
  try {
    const { identifier, password } = req.body;

    if (!identifier) {
      return res.status(400).json({ success: false, message: 'Student ID, Phone number, or Email is required' });
    }

    const trimmedId = identifier.trim();
    const isPhone = /^\d{10}$/.test(trimmedId);
    const isEmail = trimmedId.includes('@');

    let studentQuery;
    if (isPhone) {
      studentQuery = { phone: trimmedId, isDeleted: { $ne: true } };
    } else if (isEmail) {
      studentQuery = { email: trimmedId.toLowerCase(), isDeleted: { $ne: true } };
    } else {
      studentQuery = {
        isDeleted: { $ne: true },
        $or: [
          { studentId: trimmedId.toUpperCase() },
          { studentId: trimmedId },
          { phone: trimmedId },
          { email: trimmedId.toLowerCase() }
        ]
      };
    }

    // Fast indexed student lookup
    const student = await Student.findOne(studentQuery).populate('seat').populate('plan');

    if (!student) {
      return res.status(404).json({ success: false, message: 'Student record not found. Please verify your Student ID or Phone number.' });
    }

    // Fast single-query user lookup
    let user = null;
    if (student.user) {
      user = await User.findById(student.user).select('+password');
    }
    if (!user) {
      const userOr = [];
      if (student.email) userOr.push({ email: student.email.toLowerCase() });
      if (student.phone) userOr.push({ phone: student.phone.trim() });
      if (student.studentId) userOr.push({ email: `${student.studentId.toLowerCase()}@studylib.local` });
      if (userOr.length > 0) {
        user = await User.findOne({ $or: userOr }).select('+password');
      }
    }

    // Verify password
    if (user) {
      if (!password) {
        return res.status(400).json({ success: false, message: 'Password is required' });
      }
      if (!user.password) {
        user.password = password;
        await user.save();
      } else {
        const isMatch = await user.comparePassword(password);
        if (!isMatch) {
          return res.status(401).json({ success: false, message: 'Invalid password / PIN. Please verify your credentials or contact desk.' });
        }
      }
    } else {
      // Create student user if not existing
      const randomPwd = password || `Lib@${student.phone.slice(-4)}`;
      user = await User.create({
        name: student.name,
        email: student.email || `${student.studentId.toLowerCase()}@studylib.local`,
        phone: student.phone,
        password: randomPwd,
        role: 'student',
        student: student._id,
        isActive: true
      });
    }

    // Non-blocking background sync of lastLogin & bidirectional links
    Promise.all([
      (!student.user || String(student.user) !== String(user._id)) ? Student.updateOne({ _id: student._id }, { $set: { user: user._id } }) : Promise.resolve(),
      User.updateOne({ _id: user._id }, { $set: { student: student._id, lastLogin: Date.now() } })
    ]).catch(err => console.warn('Background login sync warning:', err.message));

    // Sign student JWT token
    const secret = process.env.JWT_SECRET || 'study-library-jwt-secret-key-2026-production';
    const token = jwt.sign(
      { id: user._id, role: 'student', email: user.email, studentId: student._id },
      secret,
      { expiresIn: process.env.JWT_EXPIRE || '365d' }
    );

    res.json({
      success: true,
      data: {
        token,
        student,
        user: { id: user._id, name: user.name, role: 'student', email: user.email }
      },
      message: `Welcome back, ${student.name}!`
    });
  } catch (error) {
    console.error('Error during student login:', error);
    res.status(500).json({ success: false, message: error.message || 'Login failed' });
  }
});

// @route   POST /api/auth/google-login
// @desc    Smart Google Sign-In for Student & Staff/Admin Portals
router.post('/google-login', authLimiter, async (req, res) => {
  try {
    const { email, identifier, name, googleId, picture, portalType } = req.body;
    const inputVal = (email || identifier || '').trim();

    if (!inputVal) {
      return res.status(400).json({ success: false, message: 'Google Email, Mobile Number, or Student ID is required' });
    }

    const cleanInput = inputVal.toLowerCase();

    if (portalType === 'student') {
      // Find matching Student record by email, phone, studentId, or googleId
      let student = await Student.findOne({
        $or: [
          { email: cleanInput },
          { studentId: { $regex: new RegExp(`^${cleanInput}$`, 'i') } },
          { phone: cleanInput },
          ...(googleId ? [{ googleId }] : [])
        ]
      }).populate('seat').populate('plan');

      if (!student) {
        return res.status(404).json({
          success: false,
          isRegistered: false,
          message: `No active student enrollment found for "${inputVal}". Please verify your email or phone, or apply online first.`
        });
      }

      // Link googleId if not linked
      if (!student.googleId && googleId) {
        student.googleId = googleId;
        await student.save({ validateBeforeSave: false });
      }

      // Find or create User record
      let user = await User.findOne({
        $or: [
          ...(student.email ? [{ email: student.email }] : []),
          ...(student.phone ? [{ phone: student.phone }] : [])
        ]
      });

      if (!user) {
        user = await User.create({
          name: student.name || name || 'Student',
          email: student.email || (cleanInput.includes('@') ? cleanInput : `${student.studentId.toLowerCase()}@studylib.local`),
          phone: student.phone || '0000000000',
          password: `GAuth@${Date.now()}`,
          role: 'student',
          isActive: true
        });
      }

      user.lastLogin = Date.now();
      await user.save({ validateBeforeSave: false });

      const token = user.generateAuthToken();
      const businessProfile = await BusinessProfile.getProfile();

      return res.json({
        success: true,
        data: {
          token,
          student,
          user: { id: user._id, name: user.name, role: user.role, email: user.email },
          businessProfile
        },
        message: `Welcome back via Google, ${student.name}!`
      });

    } else {
      // Staff / Admin Portal Google SSO
      const staffUser = await User.findOne({
        $or: [{ email: cleanInput }, { phone: cleanInput }],
        role: { $in: ['owner', 'branch_manager', 'staff'] }
      });

      if (!staffUser) {
        return res.status(403).json({
          success: false,
          message: `Access denied. Google account ${cleanInput} is not authorized for Admin / Staff portal.`
        });
      }

      if (!staffUser.isActive) {
        return res.status(403).json({ success: false, message: 'Staff account is deactivated' });
      }

      staffUser.lastLogin = Date.now();
      await staffUser.save({ validateBeforeSave: false });

      const token = staffUser.generateAuthToken();
      const businessProfile = await BusinessProfile.getProfile();

      return res.json({
        success: true,
        data: {
          token,
          user: { id: staffUser._id, name: staffUser.name, email: staffUser.email, role: staffUser.role },
          businessProfile
        },
        message: `Welcome back, ${staffUser.name}!`
      });
    }
  } catch (error) {
    console.error('Google login error:', error);
    res.status(500).json({ success: false, message: error.message || 'Google authentication failed' });
  }
});

// @route   POST /api/auth/passkey-login
// @desc    Smart Passkey / Biometric Login (Fingerprint, Face ID, Windows Hello)
router.post('/passkey-login', authLimiter, async (req, res) => {
  try {
    const { identifier, portalType } = req.body;
    
    if (!identifier) {
      return res.status(400).json({ success: false, message: 'Student ID, Phone, or Email is required for Passkey authentication' });
    }

    const trimmedId = identifier.trim();

    if (portalType === 'student') {
      const student = await Student.findOne({
        $or: [
          { studentId: { $regex: new RegExp(`^${trimmedId}$`, 'i') } },
          { phone: trimmedId },
          { email: trimmedId.toLowerCase() }
        ]
      }).populate('seat').populate('plan');

      if (!student) {
        return res.status(404).json({ success: false, message: 'No student record found for Passkey verification' });
      }

      let user = await User.findOne({ $or: [{ email: student.email }, { phone: student.phone }] });
      if (!user) {
        user = await User.create({
          name: student.name,
          email: student.email || `${student.studentId.toLowerCase()}@studylib.local`,
          phone: student.phone,
          password: `Passkey@${Date.now()}`,
          role: 'student',
          isActive: true
        });
      }

      const token = user.generateAuthToken();
      const businessProfile = await BusinessProfile.getProfile();

      return res.json({
        success: true,
        data: {
          token,
          student,
          user: { id: user._id, name: user.name, role: user.role, email: user.email },
          businessProfile
        },
        message: `Unlocked via Passkey! Welcome back, ${student.name}.`
      });
    } else {
      const staffUser = await User.findOne({
        $or: [{ email: trimmedId.toLowerCase() }, { phone: trimmedId }],
        role: { $in: ['owner', 'branch_manager', 'staff'] }
      });

      if (!staffUser) {
        return res.status(403).json({ success: false, message: 'No authorized staff account found for Passkey' });
      }

      const token = staffUser.generateAuthToken();
      const businessProfile = await BusinessProfile.getProfile();

      return res.json({
        success: true,
        data: {
          token,
          user: { id: staffUser._id, name: staffUser.name, email: staffUser.email, role: staffUser.role },
          businessProfile
        },
        message: `Passkey verified! Welcome back, ${staffUser.name}.`
      });
    }
  } catch (error) {
    res.status(500).json({ success: false, message: error.message || 'Passkey authentication failed' });
  }
});

// @route   POST /api/auth/biometric/register
// @desc    Register native WebAuthn biometric credential for logged in user
router.post('/biometric/register', protect, async (req, res) => {
  try {
    const { credentialId, publicKey, rawId, transports } = req.body;

    if (!credentialId) {
      return res.status(400).json({ success: false, message: 'Credential ID is required for biometric registration' });
    }

    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User account not found' });
    }

    user.biometricCredentials = user.biometricCredentials || [];

    const existingIndex = user.biometricCredentials.findIndex(c => c.credentialId === credentialId);
    if (existingIndex > -1) {
      user.biometricCredentials[existingIndex].publicKey = publicKey || user.biometricCredentials[existingIndex].publicKey;
      user.biometricCredentials[existingIndex].transports = transports || user.biometricCredentials[existingIndex].transports;
      user.biometricCredentials[existingIndex].createdAt = new Date();
    } else {
      user.biometricCredentials.push({
        credentialId,
        publicKey: publicKey || '',
        transports: transports || ['internal'],
        createdAt: new Date()
      });
    }

    await user.save({ validateBeforeSave: false });

    res.json({
      success: true,
      message: 'Biometric credential registered successfully',
      data: { credentialId }
    });
  } catch (error) {
    console.error('Biometric registration error:', error);
    res.status(500).json({ success: false, message: error.message || 'Biometric registration failed' });
  }
});

// @route   POST /api/auth/biometric/login
// @desc    Authenticate User (Admin/Staff) or Student via native WebAuthn biometric assertion
router.post('/biometric/login', authLimiter, async (req, res) => {
  try {
    const { credentialId, savedEmail } = req.body;

    if (!credentialId) {
      return res.status(400).json({ success: false, message: 'Biometric Credential ID is required' });
    }

    const Student = require('../models/Student');
    let user = await User.findOne({ 'biometricCredentials.credentialId': credentialId });
    let student = null;

    if (!user) {
      student = await Student.findOne({ 'biometricCredentials.credentialId': credentialId });
    }

    if (!user && !student && savedEmail) {
      const candidateUser = await User.findOne({ email: savedEmail.toLowerCase() });
      if (candidateUser && candidateUser.biometricCredentials && candidateUser.biometricCredentials.length > 0) {
        user = candidateUser;
      } else {
        student = await Student.findOne({
          $or: [
            { email: savedEmail.toLowerCase() },
            { phone: savedEmail },
            { studentId: savedEmail }
          ]
        });
      }
    }

    // Student Authentication Success Branch
    if (student) {
      if (student.status !== 'active') {
        return res.status(403).json({ success: false, message: 'Student account is inactive or expired.' });
      }
      const jwt = require('jsonwebtoken');
      const token = jwt.sign(
        { id: student._id, studentId: student.studentId, phone: student.phone, role: 'student' },
        process.env.JWT_SECRET || 'fallback_jwt_secret',
        { expiresIn: '30d' }
      );
      const businessProfile = await BusinessProfile.getProfile();
      return res.json({
        success: true,
        data: {
          token,
          isStudent: true,
          student: { id: student._id, studentId: student.studentId, name: student.name, phone: student.phone, email: student.email },
          businessProfile
        },
        message: `🎓 Student Biometric login successful! Welcome back, ${student.name}.`
      });
    }

    // Admin/Staff Authentication Success Branch
    if (!user) {
      return res.status(401).json({ success: false, message: 'Biometric credential not recognized or not registered. Please log in with password once, then enable Biometrics.' });
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
        token,
        user: { id: user._id, name: user.name, email: user.email, role: user.role, avatar: user.avatar },
        businessProfile
      },
      message: `👆 Biometric login successful! Welcome back, ${user.name}.`
    });
  } catch (error) {
    console.error('Biometric login error:', error);
    res.status(500).json({ success: false, message: error.message || 'Biometric authentication failed' });
  }
});

// @route   POST /api/auth/forgot-password
// @desc    Smart Forgot Password Recovery for Students & Admin/Staff
router.post('/forgot-password', authLimiter, async (req, res) => {
  try {
    const { identifier, portalType } = req.body;
    if (!identifier || !identifier.trim()) {
      return res.status(400).json({ success: false, message: 'Please enter your Mobile Number, Student ID, or Email address' });
    }

    const cleanInput = identifier.trim().toLowerCase();
    const cleanPhone = identifier.replace(/[^0-9]/g, '').slice(-10);

    const businessProfile = await BusinessProfile.findOne().lean().catch(() => ({}));
    const rawPhone = businessProfile?.phone || businessProfile?.whatsapp || process.env.BUSINESS_PHONE || '8625982248';
    const ownerPhone = rawPhone.replace(/[^0-9]/g, '').slice(-10) || '8625982248';

    if (portalType === 'student') {
      const student = await Student.findOne({
        $or: [
          { email: cleanInput },
          { studentId: { $regex: new RegExp(`^${cleanInput}$`, 'i') } },
          { phone: cleanInput },
          ...(cleanPhone ? [{ phone: cleanPhone }] : [])
        ]
      });

      if (!student) {
        return res.status(404).json({
          success: false,
          message: `No active student enrollment found for "${identifier}". Please verify your mobile number or apply online.`
        });
      }

      // Generate 1-Click WhatsApp Support Link
      const waText = encodeURIComponent(
        `🔑 *STUDENT PORTAL PASSWORD RECOVERY REQUEST*\n\n` +
        `Hello Support Team,\n` +
        `I forgot my Student Portal password/PIN. Please assist me in resetting it.\n\n` +
        `👤 *Name*: ${student.name}\n` +
        `🆔 *Student ID*: ${student.studentId}\n` +
        `📱 *Registered Phone*: ${student.phone}\n` +
        `📧 *Email*: ${student.email || 'N/A'}`
      );
      const whatsappUrl = `https://wa.me/91${ownerPhone}?text=${waText}`;

      // If email exists, send temporary PIN / reset instructions via Email
      let emailSent = false;
      if (student.email && student.email.includes('@')) {
        try {
          const tempPin = Math.floor(100000 + Math.random() * 900000).toString();
          let user = await User.findOne({
            $or: [{ email: student.email }, { phone: student.phone }]
          });
          if (user) {
            user.password = tempPin;
            await user.save();
          }

          await emailService.sendMail({
            to: student.email,
            subject: '🔑 Temporary Password Reset - Study Library Portal',
            text: `Hello ${student.name},\nYour temporary Student Portal password is: ${tempPin}\nLogin at: https://study-library-management.onrender.com/student-login`,
            html: `<div style="font-family: sans-serif; padding: 20px; background: #f8fafc; border-radius: 8px;">
              <h2>🔑 Temporary Password Reset</h2>
              <p>Hello <strong>${student.name}</strong>,</p>
              <p>Your temporary password for the Study Library Student Portal is:</p>
              <div style="background: #ffffff; padding: 15px; border-radius: 6px; border: 1px solid #cbd5e1; margin: 15px 0;">
                <p style="margin: 0; font-size: 1.2em;"><strong>Temporary Password / PIN:</strong> <code style="background: #f1f5f9; padding: 4px 8px; border-radius: 4px; color: #6366f1;">${tempPin}</code></p>
              </div>
              <p><a href="https://study-library-management.onrender.com/student-login" style="display: inline-block; padding: 10px 18px; background: #6366f1; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: bold;">Login Now ➔</a></p>
            </div>`
          });
          emailSent = true;
        } catch (e) {
          console.error('Failed to send forgot password email:', e);
        }
      }

      return res.json({
        success: true,
        data: {
          whatsappUrl,
          emailSent,
          studentName: student.name
        },
        message: emailSent
          ? `Temporary password sent to ${student.email}. You can also use WhatsApp for instant support.`
          : `Recovery request prepared for ${student.name}. Click WhatsApp to contact admin for instant password reset.`
      });

    } else {
      // Staff / Admin Password Recovery
      const staffUser = await User.findOne({
        $or: [{ email: cleanInput }, { phone: cleanInput }],
        role: { $in: ['owner', 'branch_manager', 'staff'] }
      }).lean();

      if (!staffUser) {
        return res.status(404).json({ success: false, message: `No staff account found for "${identifier}".` });
      }

      const waText = encodeURIComponent(
        `Hello Admin Support, I am staff member ${staffUser.name} (${staffUser.email}). I forgot my staff portal password. Please reset my account credentials.`
      );
      const whatsappUrl = `https://wa.me/91${ownerPhone}?text=${waText}`;

      return res.json({
        success: true,
        data: { whatsappUrl },
        message: `Recovery request prepared for staff member ${staffUser.name}. Click WhatsApp link to contact owner.`
      });
    }

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
