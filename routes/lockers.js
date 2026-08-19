const express = require('express');
const router = express.Router();
const Locker = require('../models/Locker');
const Student = require('../models/Student');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');

// GET /api/lockers/blocks - Get aggregated statistics per block
router.get('/blocks', protect, async (req, res) => {
  try {
    const lockers = await Locker.find().lean();
    const blocksMap = {};

    lockers.forEach(l => {
      const b = l.block || 'Block A';
      if (!blocksMap[b]) {
        blocksMap[b] = { block: b, total: 0, assigned: 0, available: 0, totalRevenue: 0 };
      }
      blocksMap[b].total += 1;
      if (l.status === 'occupied') {
        blocksMap[b].assigned += 1;
        blocksMap[b].totalRevenue += (l.monthlyFee || 0);
      } else if (l.status === 'available') {
        blocksMap[b].available += 1;
      }
    });

    res.json({ success: true, blocks: Object.values(blocksMap) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/lockers/blocks/pricing - Update pricing for a block
router.put('/blocks/pricing', protect, roleCheck('owner'), async (req, res) => {
  try {
    const { block, monthlyFee, depositFee, size } = req.body;
    if (!block) return res.status(400).json({ success: false, message: 'Block is required' });

    const updateFields = {};
    if (monthlyFee !== undefined) updateFields.monthlyFee = Number(monthlyFee);
    if (depositFee !== undefined) updateFields.depositFee = Number(depositFee);
    if (size) updateFields.size = size;

    await Locker.updateMany({ block }, { $set: updateFields });
    res.json({ success: true, message: `Updated pricing for ${block}` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/lockers - List all lockers with branch and status filters
router.get('/', protect, async (req, res) => {
  try {
    const { branch, status, size, search } = req.query;
    const query = {};

    if (branch) query.branch = branch;
    if (status && status !== 'all') query.status = status;
    if (size && size !== 'all') query.size = size;
    if (search) {
      query.lockerNumber = new RegExp(search.trim(), 'i');
    }

    const lockers = await Locker.find(query)
      .populate('assignedStudent', 'name phone studentId dateOfBirth photo')
      .populate('branch', 'name')
      .sort({ lockerNumber: 1 })
      .lean();

    const total = lockers.length;
    const available = lockers.filter(l => l.status === 'available').length;
    const occupied = lockers.filter(l => l.status === 'occupied').length;
    const maintenance = lockers.filter(l => l.status === 'maintenance').length;
    const totalDeposit = lockers.reduce((acc, l) => acc + (l.isDepositPaid && !l.isDepositRefunded ? (l.depositAmount || 0) : 0), 0);

    res.json({
      success: true,
      stats: { total, available, occupied, maintenance, totalDeposit },
      lockers
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/lockers - Create single or bulk lockers
router.post('/', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { isBulk, prefix = 'L-', startNumber, count, size = 'medium', depositAmount = 0, branch, lockerNumber } = req.body;

    if (isBulk) {
      const start = parseInt(startNumber, 10) || 1;
      const total = parseInt(count, 10) || 10;
      const created = [];

      for (let i = 0; i < total; i++) {
        const numStr = String(start + i).padStart(2, '0');
        const num = `${prefix}${numStr}`;
        
        // Skip if exists
        const exists = await Locker.findOne({ lockerNumber: num, branch: branch || null }).lean();
        if (!exists) {
          const l = new Locker({
            lockerNumber: num,
            size,
            depositAmount: parseFloat(depositAmount) || 0,
            branch: branch || null,
            status: 'available'
          });
          await l.save();
          created.push(l);
        }
      }

      return res.status(201).json({
        success: true,
        message: `Successfully generated ${created.length} lockers`,
        count: created.length
      });
    }

    // Single creation
    if (!lockerNumber) {
      return res.status(400).json({ success: false, message: 'Locker number is required' });
    }

    const existing = await Locker.findOne({ lockerNumber: lockerNumber.trim(), branch: branch || null }).lean();
    if (existing) {
      return res.status(400).json({ success: false, message: `Locker ${lockerNumber} already exists in this branch` });
    }

    const locker = new Locker({
      lockerNumber: lockerNumber.trim(),
      size: size || 'medium',
      depositAmount: parseFloat(depositAmount) || 0,
      branch: branch || null,
      notes: req.body.notes || ''
    });

    await locker.save();
    res.status(201).json({ success: true, message: 'Locker created', locker });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/lockers/:id/assign - Assign student to locker
router.put('/:id/assign', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { studentId, expiryDate, depositAmount, isDepositPaid, keyNumber, notes } = req.body;
    const locker = await Locker.findById(req.params.id);

    if (!locker) {
      return res.status(404).json({ success: false, message: 'Locker not found' });
    }

    const student = await Student.findById(studentId);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    // Concurrency check: prevent double allocation of occupied locker
    if (locker.status === 'occupied' && locker.assignedStudent && locker.assignedStudent.toString() !== student._id.toString()) {
      return res.status(409).json({ success: false, message: 'Locker is already assigned to another student' });
    }

    // If student was already assigned to another locker, release old locker
    if (student.locker && student.locker.toString() !== locker._id.toString()) {
      await Locker.findByIdAndUpdate(student.locker, {
        status: 'available',
        assignedStudent: null,
        assignedDate: null,
        expiryDate: null
      });
    }

    locker.status = 'occupied';
    locker.assignedStudent = student._id;
    locker.assignedDate = new Date();
    if (expiryDate) locker.expiryDate = new Date(expiryDate);
    if (depositAmount !== undefined) locker.depositAmount = parseFloat(depositAmount) || 0;
    if (isDepositPaid !== undefined) locker.isDepositPaid = Boolean(isDepositPaid);
    locker.isDepositRefunded = false;
    if (keyNumber) locker.keyNumber = keyNumber;
    if (notes) locker.notes = notes;

    await locker.save();

    // Synchronize Student model
    student.locker = locker._id;
    await student.save();

    const updated = await Locker.findById(locker._id).populate('assignedStudent', 'name phone studentId').lean();

    res.json({ success: true, message: 'Locker assigned successfully', locker: updated });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/lockers/:id/release - Release locker and handle deposit refund
router.put('/:id/release', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { refundDeposit } = req.body;
    const locker = await Locker.findById(req.params.id);

    if (!locker) {
      return res.status(404).json({ success: false, message: 'Locker not found' });
    }

    // Synchronize Student model
    await Student.updateMany({ locker: locker._id }, { $set: { locker: null } });

    locker.status = 'available';
    locker.assignedStudent = null;
    locker.assignedDate = null;
    locker.expiryDate = null;
    if (refundDeposit) {
      locker.isDepositRefunded = true;
    }
    locker.notes = '';

    await locker.save();
    res.json({ success: true, message: 'Locker released and marked available', locker });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/lockers/:id - Edit locker
router.put('/:id', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const locker = await Locker.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!locker) {
      return res.status(404).json({ success: false, message: 'Locker not found' });
    }
    res.json({ success: true, message: 'Locker updated', locker });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/lockers/:id - Delete locker
router.delete('/:id', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const locker = await Locker.findById(req.params.id).lean();
    if (!locker) {
      return res.status(404).json({ success: false, message: 'Locker not found' });
    }
    if (locker.status === 'occupied') {
      return res.status(400).json({ success: false, message: 'Cannot delete an occupied locker. Release it first.' });
    }

    await Locker.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Locker deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
