const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const Student = require('../models/Student');
const Seat = require('../models/Seat');
const Locker = require('../models/Locker');
const User = require('../models/User');
const { generateStudentId } = require('../utils/idGenerator');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');
const { validate } = require('../middleware/validate');
const { moveToTrash } = require('./trash');

router.use(protect);
router.use(roleCheck('owner', 'branch_manager'));

// GET /stats
router.get('/stats', async (req, res) => {
  try {
    const stats = await Student.getStats({ isDeleted: { $ne: true } });
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

    const query = { isDeleted: { $ne: true } };
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

    const [students, total] = await Promise.all([
      Student.find(query)
        .populate('plan', 'name price duration durationType shift')
        .populate('seat', 'seatNumber zone status branch')
        .populate('locker', 'lockerNumber monthlyFee status')
        .populate('shift', 'name startTime endTime code')
        .populate('branch', 'name code city address')
        .sort(req.query.sort || '-createdAt')
        .skip(skip)
        .limit(limit)
        .lean(),
      Student.countDocuments(query)
    ]);

    const enrichedStudents = students.map(s => {
      let score = 0;
      if (s.name) score += 15;
      if (s.phone) score += 15;
      if (s.plan) score += 15;
      if (s.seat) score += 15;
      if (s.photo) score += 25;
      if (s.idProof && (s.idProof.number || s.idProof.image)) score += 15;
      const isComplete = score >= 100;
      return {
        ...s,
        profileCompletion: Math.min(100, score),
        isProfileComplete: isComplete
      };
    });

    res.json({
      success: true,
      data: {
        students: enrichedStudents,
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
      .populate('plan', 'name price duration durationType shift')
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
    if (req.body.phone) {
      let cleanPhone = String(req.body.phone).trim().replace(/[^0-9+]/g, '');
      if (cleanPhone.startsWith('0') && cleanPhone.length === 11) {
        cleanPhone = cleanPhone.slice(1);
      }
      req.body.phone = cleanPhone;

      // Duplicate Check: Check by last 10 digits or exact phone
      const digitsOnly = cleanPhone.replace(/[^0-9]/g, '');
      const last10 = digitsOnly.length >= 10 ? digitsOnly.slice(-10) : digitsOnly;
      if (last10) {
        const existingStudent = await Student.findOne({
          phone: { $regex: last10 + '$' }
        }).lean();

        if (existingStudent) {
          return res.status(400).json({
            success: false,
            message: `A student with mobile number "${req.body.phone}" is already registered (${existingStudent.name}, Student ID: ${existingStudent.studentId || 'N/A'}). Duplicate admissions with same phone number are not allowed.`
          });
        }
      }
    }

    if (req.body.email && req.body.email.trim()) {
      const cleanEmail = req.body.email.toLowerCase().trim();
      const existingEmail = await Student.findOne({ email: cleanEmail }).lean();
      if (existingEmail) {
        return res.status(400).json({
          success: false,
          message: `A student with email "${req.body.email}" is already registered (${existingEmail.name}, Student ID: ${existingEmail.studentId || 'N/A'}).`
        });
      }
    }

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
            { code: new RegExp(`^${shiftCodeToCheck}$`, 'i') },
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
    
    // Extract customFields before creating student
    const customFieldsData = req.body.customFields || {};
    delete req.body.customFields;

    const rawGender = req.body.gender !== undefined ? req.body.gender : (customFieldsData && (customFieldsData.gender || customFieldsData.Gender));
    if (rawGender) {
      const g = String(rawGender).toLowerCase().trim();
      req.body.gender = ['male', 'female', 'other'].includes(g) ? g : undefined;
    }
    if (req.body.status) {
      req.body.status = String(req.body.status).toLowerCase().trim();
    }

    const rawBloodGroup = req.body.bloodGroup !== undefined ? req.body.bloodGroup : (customFieldsData && (customFieldsData.bloodGroup || customFieldsData.blood_group || customFieldsData.BloodGroup || customFieldsData.bloodgroup));
    if (rawBloodGroup !== undefined && rawBloodGroup !== '') {
      req.body.bloodGroup = String(rawBloodGroup).trim();
    }

    const rawOccupation = req.body.occupation !== undefined ? req.body.occupation : (customFieldsData && (customFieldsData.occupation || customFieldsData.collegeOrCompany || customFieldsData.college_or_company));
    if (rawOccupation !== undefined && rawOccupation !== '') {
      req.body.occupation = String(rawOccupation).trim();
    }

    if (req.body.idProof || req.body.idProofType || req.body.idProofNumber || req.body.idProofImage || req.body['idProof.type'] || req.body['idProof.number'] || (customFieldsData && (customFieldsData.idProof || customFieldsData.id_proof || customFieldsData.idProofType || customFieldsData.id_proof_type || customFieldsData.idProofNumber || customFieldsData.id_proof_number || customFieldsData.idProofImage || customFieldsData.id_proof_image || customFieldsData.idprooftype || customFieldsData.idproofnumber || customFieldsData.idproofimage || customFieldsData.aadhaar || customFieldsData.pan))) {
      const idp = req.body.idProof || {};
      const idType = idp.type || req.body.idProofType || req.body['idProof.type'] || (customFieldsData && (customFieldsData.idProofType || customFieldsData.id_proof_type || customFieldsData['idProof.type'] || customFieldsData.idprooftype)) || 'Aadhaar Card';
      const idNum = idp.number || req.body.idProofNumber || req.body['idProof.number'] || (customFieldsData && (customFieldsData.idProofNumber || customFieldsData.id_proof_number || customFieldsData['idProof.number'] || customFieldsData.idproofnumber || customFieldsData.aadhaar || customFieldsData.pan)) || '';
      const idImg = idp.image || req.body.idProofImage || req.body['idProof.image'] || (customFieldsData && (customFieldsData.idProofImage || customFieldsData.id_proof_image || customFieldsData['idProof.image'] || customFieldsData.idproofimage)) || '';
      req.body.idProof = { type: String(idType).trim(), number: String(idNum).trim(), image: String(idImg).trim() };
      delete req.body['idProof.type'];
      delete req.body['idProof.number'];
      delete req.body['idProof.image'];
      delete req.body.idProofType;
      delete req.body.idProofNumber;
      delete req.body.idProofImage;
    }

    if (req.body.emergencyContact || req.body.emergencyContactName || req.body.emergencyContactPhone || req.body.emergencyContactRelation || req.body['emergencyContact.phone'] || (customFieldsData && (customFieldsData.emergencyContact || customFieldsData.emergency_contact || customFieldsData.emergencyContactPhone || customFieldsData.parentPhone || customFieldsData.emergency_contact_phone || customFieldsData.emergencycontact || customFieldsData.emergencycontactphone || customFieldsData.parentphone))) {
      const em = req.body.emergencyContact || {};
      const emName = em.name || req.body.emergencyContactName || req.body['emergencyContact.name'] || (customFieldsData && (customFieldsData.emergencyContactName || customFieldsData.parentName || customFieldsData.emergency_contact_name || customFieldsData.emergencycontactname || customFieldsData.parentname)) || '';
      const emPhone = em.phone || req.body.emergencyContactPhone || req.body.emergencyContact || req.body['emergencyContact.phone'] || (customFieldsData && (customFieldsData.emergencyContactPhone || customFieldsData.parentPhone || customFieldsData.emergency_contact_phone || customFieldsData.emergencyContact || customFieldsData.emergencycontact || customFieldsData.emergencycontactphone || customFieldsData.parentphone)) || '';
      const emRel = em.relation || req.body.emergencyContactRelation || req.body['emergencyContact.relation'] || (customFieldsData && (customFieldsData.emergencyContactRelation || customFieldsData.parentRelation || customFieldsData.emergency_contact_relation || customFieldsData.emergencycontactrelation || customFieldsData.parentrelation)) || 'Parent';
      req.body.emergencyContact = { name: String(emName).trim(), phone: String(emPhone).trim().replace(/[^0-9+]/g, ''), relation: String(emRel).trim() };
      delete req.body['emergencyContact.name'];
      delete req.body['emergencyContact.phone'];
      delete req.body['emergencyContact.relation'];
      delete req.body.emergencyContactName;
      delete req.body.emergencyContactPhone;
      delete req.body.emergencyContactRelation;
    }

    const rawExams = req.body.targetExams !== undefined ? req.body.targetExams : (customFieldsData && (customFieldsData.targetExams || customFieldsData.target_exams || customFieldsData.competitive_exams));
    if (rawExams !== undefined) {
      req.body.targetExams = Array.isArray(rawExams) ? rawExams : String(rawExams).split(',').map(s => s.trim()).filter(Boolean);
    }

    if (!req.body.studentId) {
      req.body.studentId = await generateStudentId({ branch: req.body.branch });
    }
    
    const student = new Student(req.body);
    
    // Properly set customFields Map including explicit false values
    if (customFieldsData && typeof customFieldsData === 'object') {
      for (const [key, value] of Object.entries(customFieldsData)) {
        if (value !== undefined) {
          student.customFields.set(key, value);
        }
      }
    }

    // Auto-calculate expiryDate from plan duration if not explicitly provided
    if (req.body.plan && !student.expiryDate) {
      const Plan = require('../models/Plan');
      const planDoc = await Plan.findById(req.body.plan).lean();
      if (planDoc) {
        const d = new Date();
        const durationType = planDoc.durationType || 'months';
        const duration = Number(planDoc.duration) || 1;
        if (durationType === 'days') {
          d.setDate(d.getDate() + duration);
        } else if (durationType === 'years') {
          d.setFullYear(d.getFullYear() + duration);
        } else {
          d.setMonth(d.getMonth() + duration);
        }
        student.expiryDate = d;
      }
    }

    await student.save();

    // Mark seat occupied with atomic concurrency guard
    if (student.seat) {
      const Seat = require('../models/Seat');
      const allocatedSeat = await Seat.findOneAndUpdate(
        {
          _id: student.seat,
          $or: [{ status: 'available' }, { currentStudent: null }, { currentStudent: student._id }]
        },
        { status: 'occupied', currentStudent: student._id, assignedAt: new Date() },
        { new: true }
      ).catch(() => null);

      if (!allocatedSeat) {
        student.seat = null;
        const noteMsg = 'Seat was concurrently booked by another user; floating admission granted.';
        student.notes = student.notes ? `${student.notes} • ${noteMsg}` : noteMsg;
        await student.save();
      }
    }

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

    if (req.body.phone) {
      let cleanPhone = String(req.body.phone).trim().replace(/[^0-9+]/g, '');
      if (cleanPhone.startsWith('0') && cleanPhone.length === 11) {
        cleanPhone = cleanPhone.slice(1);
      }
      req.body.phone = cleanPhone;

      const digitsOnly = cleanPhone.replace(/[^0-9]/g, '');
      const last10 = digitsOnly.length >= 10 ? digitsOnly.slice(-10) : digitsOnly;
      if (last10) {
        const existingPhone = await Student.findOne({
          _id: { $ne: req.params.id },
          phone: { $regex: last10 + '$' }
        }).lean();
        if (existingPhone) {
          return res.status(400).json({
            success: false,
            message: `Mobile number "${req.body.phone}" is already used by another student (${existingPhone.name}, Student ID: ${existingPhone.studentId || 'N/A'}).`
          });
        }
      }
    }

    if (req.body.email && req.body.email.trim()) {
      const cleanEmail = req.body.email.toLowerCase().trim();
      const existingEmail = await Student.findOne({
        _id: { $ne: req.params.id },
        email: cleanEmail
      }).lean();
      if (existingEmail) {
        return res.status(400).json({
          success: false,
          message: `Email "${req.body.email}" is already used by another student (${existingEmail.name}, Student ID: ${existingEmail.studentId || 'N/A'}).`
        });
      }
    }

    const oldSeat = student.seat ? String(student.seat) : null;
    const oldLocker = student.locker ? String(student.locker) : null;

    const customFieldsData = req.body.customFields;
    delete req.body.customFields;

    const rawGender = req.body.gender !== undefined ? req.body.gender : (customFieldsData && (customFieldsData.gender || customFieldsData.Gender));
    if (rawGender) {
      const g = String(rawGender).toLowerCase().trim();
      req.body.gender = ['male', 'female', 'other'].includes(g) ? g : undefined;
    }
    if (req.body.status) {
      req.body.status = String(req.body.status).toLowerCase().trim();
    }

    const rawBloodGroup = req.body.bloodGroup !== undefined ? req.body.bloodGroup : (customFieldsData && (customFieldsData.bloodGroup || customFieldsData.blood_group || customFieldsData.BloodGroup || customFieldsData.bloodgroup));
    if (rawBloodGroup !== undefined) {
      student.bloodGroup = String(rawBloodGroup).trim();
      student.markModified('bloodGroup');
      delete req.body.bloodGroup;
    }

    const rawOccupation = req.body.occupation !== undefined ? req.body.occupation : (customFieldsData && (customFieldsData.occupation || customFieldsData.collegeOrCompany || customFieldsData.college_or_company));
    if (rawOccupation !== undefined) {
      student.occupation = String(rawOccupation).trim();
      student.markModified('occupation');
      delete req.body.occupation;
    }

    if (req.body.idProof || req.body.idProofType || req.body.idProofNumber || req.body.idProofImage || req.body['idProof.type'] || req.body['idProof.number'] || (customFieldsData && (customFieldsData.idProof || customFieldsData.id_proof || customFieldsData.idProofType || customFieldsData.id_proof_type || customFieldsData.idProofNumber || customFieldsData.id_proof_number || customFieldsData.idProofImage || customFieldsData.id_proof_image || customFieldsData.idprooftype || customFieldsData.idproofnumber || customFieldsData.idproofimage || customFieldsData.aadhaar || customFieldsData.pan))) {
      const idp = req.body.idProof || {};
      const idType = idp.type || req.body.idProofType || req.body['idProof.type'] || (customFieldsData && (customFieldsData.idProofType || customFieldsData.id_proof_type || customFieldsData['idProof.type'] || customFieldsData.idprooftype)) || student.idProof?.type || 'Aadhaar Card';
      const idNum = idp.number || req.body.idProofNumber || req.body['idProof.number'] || (customFieldsData && (customFieldsData.idProofNumber || customFieldsData.id_proof_number || customFieldsData['idProof.number'] || customFieldsData.idproofnumber || customFieldsData.aadhaar || customFieldsData.pan)) || student.idProof?.number || '';
      const idImg = idp.image || req.body.idProofImage || req.body['idProof.image'] || (customFieldsData && (customFieldsData.idProofImage || customFieldsData.id_proof_image || customFieldsData['idProof.image'] || customFieldsData.idproofimage)) || student.idProof?.image || '';
      student.idProof = { type: String(idType).trim(), number: String(idNum).trim(), image: String(idImg).trim() };
      student.markModified('idProof');
      delete req.body.idProof;
      delete req.body['idProof.type'];
      delete req.body['idProof.number'];
      delete req.body['idProof.image'];
      delete req.body.idProofType;
      delete req.body.idProofNumber;
      delete req.body.idProofImage;
    }

    if (req.body.emergencyContact || req.body.emergencyContactName || req.body.emergencyContactPhone || req.body.emergencyContactRelation || req.body['emergencyContact.phone'] || (customFieldsData && (customFieldsData.emergencyContact || customFieldsData.emergency_contact || customFieldsData.emergencyContactPhone || customFieldsData.parentPhone || customFieldsData.emergency_contact_phone || customFieldsData.emergencycontact || customFieldsData.emergencycontactphone || customFieldsData.parentphone))) {
      const em = req.body.emergencyContact || {};
      const emName = em.name || req.body.emergencyContactName || req.body['emergencyContact.name'] || (customFieldsData && (customFieldsData.emergencyContactName || customFieldsData.parentName || customFieldsData.emergency_contact_name || customFieldsData.emergencycontactname || customFieldsData.parentname)) || student.emergencyContact?.name || '';
      const emPhone = em.phone || req.body.emergencyContactPhone || req.body.emergencyContact || req.body['emergencyContact.phone'] || (customFieldsData && (customFieldsData.emergencyContactPhone || customFieldsData.parentPhone || customFieldsData.emergency_contact_phone || customFieldsData.emergencyContact || customFieldsData.emergencycontact || customFieldsData.emergencycontactphone || customFieldsData.parentphone)) || student.emergencyContact?.phone || '';
      const emRel = em.relation || req.body.emergencyContactRelation || req.body['emergencyContact.relation'] || (customFieldsData && (customFieldsData.emergencyContactRelation || customFieldsData.parentRelation || customFieldsData.emergency_contact_relation || customFieldsData.emergencycontactrelation || customFieldsData.parentrelation)) || student.emergencyContact?.relation || 'Parent';
      student.emergencyContact = { name: String(emName).trim(), phone: String(emPhone).trim().replace(/[^0-9+]/g, ''), relation: String(emRel).trim() };
      student.markModified('emergencyContact');
      delete req.body.emergencyContact;
      delete req.body['emergencyContact.name'];
      delete req.body['emergencyContact.phone'];
      delete req.body['emergencyContact.relation'];
      delete req.body.emergencyContactName;
      delete req.body.emergencyContactPhone;
      delete req.body.emergencyContactRelation;
    }

    const rawExams = req.body.targetExams !== undefined ? req.body.targetExams : (customFieldsData && (customFieldsData.targetExams || customFieldsData.target_exams || customFieldsData.competitive_exams));
    if (rawExams !== undefined) {
      student.targetExams = Array.isArray(rawExams) ? rawExams : String(rawExams).split(',').map(s => s.trim()).filter(Boolean);
      student.markModified('targetExams');
      delete req.body.targetExams;
    }

    Object.assign(student, req.body);

    if (customFieldsData && typeof customFieldsData === 'object') {
      if (!student.customFields) student.customFields = new Map();
      for (const [key, value] of Object.entries(customFieldsData)) {
        if (value !== undefined) {
          student.customFields.set(key, value);
        }
      }
      student.markModified('customFields');
    }

    await student.save();

    // Atomic Seat Synchronization
    const newSeat = student.seat ? String(student.seat) : null;
    if (oldSeat && oldSeat !== newSeat) {
      await Seat.findByIdAndUpdate(oldSeat, { status: 'available', currentStudent: null }).catch(() => {});
    }
    if (newSeat && student.status === 'active') {
      const allocatedSeat = await Seat.findOneAndUpdate(
        {
          _id: newSeat,
          $or: [{ status: 'available' }, { currentStudent: null }, { currentStudent: student._id }]
        },
        { status: 'occupied', currentStudent: student._id, assignedAt: new Date() },
        { new: true }
      ).catch(() => null);

      if (!allocatedSeat && oldSeat !== newSeat) {
        student.seat = oldSeat ? new mongoose.Types.ObjectId(oldSeat) : null;
        await student.save();
        return res.status(409).json({ success: false, message: 'Requested seat is already occupied by another student' });
      }
    } else if (newSeat && ['inactive', 'expired', 'suspended'].includes(student.status)) {
      await Seat.findByIdAndUpdate(newSeat, { status: 'available', currentStudent: null }).catch(() => {});
    }

    // Atomic Locker Synchronization
    const newLocker = student.locker ? String(student.locker) : null;
    if (oldLocker && oldLocker !== newLocker) {
      await Locker.findByIdAndUpdate(oldLocker, { status: 'available', currentStudent: null }).catch(() => {});
    }
    if (newLocker && student.status === 'active') {
      await Locker.findByIdAndUpdate(newLocker, { status: 'occupied', currentStudent: student._id }).catch(() => {});
    }

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

    // Move to Trash
    await moveToTrash({
      itemType: 'student',
      itemId: student._id,
      itemTitle: `${student.name} (${student.studentId || 'ID'})`,
      itemSubtitle: `📱 ${student.phone || 'No Phone'} • 🏢 ${student.branch?.name || 'Main Campus'} • Status: ${(student.status || 'Active').toUpperCase()}`,
      originalCollection: 'students',
      itemData: student.toObject ? student.toObject() : student,
      user: req.user,
      reason: req.body?.reason || ''
    });

    res.json({
      success: true,
      message: `Student "${student.name}" moved to Recycle Bin (Trash). You can restore or permanently delete it anytime.`
    });
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
        ...(student.email ? [{ email: student.email.toLowerCase() }] : []),
        ...(student.phone ? [{ phone: student.phone }] : [])
      ]
    }).select('+password');

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

