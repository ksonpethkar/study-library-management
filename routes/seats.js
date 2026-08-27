const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { body, validationResult } = require('express-validator');
const Seat = require('../models/Seat');
const Student = require('../models/Student');
const Shift = require('../models/Shift');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');
const { validate, validateSeatCreate, validateSeatUpdate } = require('../middleware/validate');
const { moveToTrash } = require('./trash');

// GET /public-available - Public endpoint for student registration seat selection
router.get('/public-available', async (req, res) => {
  try {
    const seats = await Seat.find({ isActive: true, isDeleted: { $ne: true } })
      .select('seatNumber zone floor status type priceMultiplier branch')
      .populate('branch', 'name code')
      .sort('seatNumber')
      .lean();
    res.json({ success: true, data: seats });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// All remaining routes are protected
router.use(protect);
router.use(roleCheck('owner', 'superadmin', 'admin', 'branch_manager', 'staff'));

// GET / - List seats with branch, zone, status, floor, type filters
router.get('/', async (req, res) => {
  try {
    const { zone, status, floor, type, branch, search } = req.query;
    let filter = { isDeleted: { $ne: true } };
    if (zone) filter.zone = zone;
    if (status) filter.status = status;
    if (floor) filter.floor = floor;
    if (type) filter.type = type;
    if (branch && branch !== 'all') {
      if (branch === 'unassigned') {
        filter.branch = null;
      } else {
        filter.branch = branch;
      }
    }
    if (search) {
      filter.seatNumber = { $regex: search, $options: 'i' };
    }

    const seats = await Seat.find(filter)
      .populate('currentStudent', 'name studentId phone email photo')
      .populate('branch', 'name code city')
      .sort('seatNumber')
      .lean();
    
    res.json({ success: true, data: seats, message: 'Seats retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /zones - Get unique zones with seat counts (optional branch filter)
router.get('/zones', async (req, res) => {
  try {
    const { branch } = req.query;
    let match = { isDeleted: { $ne: true } };
    if (branch && branch !== 'all') {
      if (branch === 'unassigned') match.branch = null;
      else if (mongoose.Types.ObjectId.isValid(branch)) match.branch = new mongoose.Types.ObjectId(branch);
    }

    const zoneCounts = await Seat.aggregate([
      { $match: match },
      { $group: { _id: '$zone', count: { $sum: 1 }, available: { $sum: { $cond: [{ $eq: ['$status', 'available'] }, 1, 0] } } } },
      { $sort: { _id: 1 } }
    ]);

    res.json({ success: true, data: zoneCounts, message: 'Zones retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /stats - Seat statistics with optional branch filter
router.get('/stats', async (req, res) => {
  try {
    const { branch } = req.query;
    let match = { isDeleted: { $ne: true } };
    if (branch && branch !== 'all') {
      if (branch === 'unassigned') match.branch = null;
      else if (mongoose.Types.ObjectId.isValid(branch)) match.branch = new mongoose.Types.ObjectId(branch);
    }

    const stats = await Seat.aggregate([
      { $match: match },
      {
        $group: {
          _id: null,
          total: { $sum: 1 },
          available: { $sum: { $cond: [{ $eq: ['$status', 'available'] }, 1, 0] } },
          occupied: { $sum: { $cond: [{ $eq: ['$status', 'occupied'] }, 1, 0] } },
          reserved: { $sum: { $cond: [{ $eq: ['$status', 'reserved'] }, 1, 0] } },
          maintenance: { $sum: { $cond: [{ $eq: ['$status', 'maintenance'] }, 1, 0] } }
        }
      }
    ]);
    
    if (stats.length === 0) {
      return res.json({ success: true, data: { total: 0, available: 0, occupied: 0, reserved: 0, maintenance: 0 } });
    }
    
    const { _id, ...result } = stats[0];
    res.json({ success: true, data: result, message: 'Seat statistics retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /:id - Single seat
router.get('/:id', async (req, res) => {
  try {
    const seat = await Seat.findById(req.params.id)
      .populate('currentStudent', 'name studentId email phone photo')
      .populate('branch', 'name code')
      .lean();
    if (!seat) {
      return res.status(404).json({ success: false, message: 'Seat not found' });
    }
    res.json({ success: true, data: seat, message: 'Seat retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST / - Create single custom seat
router.post('/', roleCheck('owner', 'branch_manager'), validateSeatCreate, async (req, res) => {
  try {
    const { seatNumber, zone, floor, type, status, monthlyRate, amenities, branch } = req.body;
    
    const branchId = branch && branch !== 'none' && branch !== 'all' ? branch : null;
    const existing = await Seat.findOne({ seatNumber: seatNumber.trim(), branch: branchId });
    if (existing) {
      if (!existing.isDeleted) {
        return res.status(400).json({ success: false, message: `Seat number '${seatNumber}' already exists for this branch` });
      }
      // Un-delete and update existing soft-deleted seat
      existing.isDeleted = false;
      existing.isActive = true;
      existing.zone = zone.trim();
      existing.floor = floor ? floor.trim() : '';
      existing.type = type || 'regular';
      existing.status = status || 'available';
      existing.monthlyRate = monthlyRate ? parseFloat(monthlyRate) : 0;
      existing.amenities = Array.isArray(amenities) ? amenities : (amenities ? amenities.split(',').map(a => a.trim()).filter(Boolean) : []);
      await existing.save();
      return res.status(200).json({ success: true, data: existing, message: `Seat ${existing.seatNumber} restored and created successfully` });
    }

    const seat = await Seat.create({
      seatNumber: seatNumber.trim(),
      zone: zone.trim(),
      floor: floor ? floor.trim() : '',
      type: type || 'regular',
      status: status || 'available',
      monthlyRate: monthlyRate ? parseFloat(monthlyRate) : 0,
      amenities: Array.isArray(amenities) ? amenities : (amenities ? amenities.split(',').map(a => a.trim()).filter(Boolean) : []),
      branch: branchId
    });
    
    res.status(201).json({ success: true, data: seat, message: `Seat ${seat.seatNumber} created successfully` });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
});

// POST /bulk - Bulk create seats with Branch support
router.post('/bulk', roleCheck('owner', 'branch_manager'), validate([
  body('zone').notEmpty().withMessage('Zone is required'),
  body('count').isInt({ min: 1, max: 500 }).withMessage('Count must be between 1 and 500'),
  body('startNumber').isInt({ min: 1 }).withMessage('Start number must be at least 1')
]), async (req, res) => {
  try {
    const { zone, floor, type, count, startNumber, prefix = '', branch, monthlyRate, amenities } = req.body;
    const seatsToCreate = [];
    const parsedMonthlyRate = monthlyRate ? parseFloat(monthlyRate) : 0;
    const parsedAmenities = Array.isArray(amenities) ? amenities : (amenities ? amenities.split(',').map(a => a.trim()).filter(Boolean) : []);
    
    for (let i = 0; i < parseInt(count, 10); i++) {
      const num = parseInt(startNumber, 10) + i;
      const formattedNum = num < 10 ? `0${num}` : `${num}`;
      const seatNumber = `${prefix}${formattedNum}`;
      
      seatsToCreate.push({
        seatNumber,
        zone: zone.trim(),
        zoneColor: req.body.zoneColor || '#6c5ce7',
        floor: floor ? floor.trim() : '',
        type: type || 'regular',
        seatType: req.body.seatType || 'standard',
        branch: branch || null,
        monthlyRate: parsedMonthlyRate,
        amenities: parsedAmenities,
        status: 'available'
      });
    }

    // Attempt insertMany with ordered: false to skip existing seatNumbers
    try {
      const created = await Seat.insertMany(seatsToCreate, { ordered: false });
      res.status(201).json({ success: true, data: created, message: `${created.length} seats created successfully` });
    } catch (insertError) {
      if (insertError.code === 11000) {
        const insertedCount = insertError.insertedDocs ? insertError.insertedDocs.length : 0;
        res.status(207).json({ 
          success: true, 
          data: insertError.insertedDocs, 
          message: `Created ${insertedCount} seats (skipped existing duplicates)`
        });
      } else {
        throw insertError;
      }
    }
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
});

// POST /bulk-delete - Soft-delete multiple seats to Trash
router.post('/bulk-delete', roleCheck('owner'), async (req, res) => {
  try {
    const { seatIds, reason } = req.body;
    if (!Array.isArray(seatIds) || seatIds.length === 0) {
      return res.status(400).json({ success: false, message: 'No seat IDs provided' });
    }

    // Do not delete occupied seats
    const occupied = await Seat.find({
      _id: { $in: seatIds },
      $or: [{ status: 'occupied' }, { currentStudent: { $ne: null } }],
      isDeleted: { $ne: true }
    }).lean();

    if (occupied.length > 0) {
      return res.status(400).json({ 
        success: false, 
        message: `Cannot delete ${occupied.length} occupied seat(s). Please release students first.` 
      });
    }

    const seatsToDelete = await Seat.find({
      _id: { $in: seatIds },
      isDeleted: { $ne: true }
    }).populate('branch', 'name');

    for (const seat of seatsToDelete) {
      await moveToTrash({
        itemType: 'seat',
        itemId: seat._id,
        itemTitle: `Desk ${seat.seatNumber} (${seat.zone || 'Zone A'})`,
        itemSubtitle: `Floor: ${seat.floor || 'G'} • Type: ${(seat.type || 'regular').toUpperCase()} • Branch: ${seat.branch?.name || 'Main'}`,
        originalCollection: 'seats',
        itemData: seat.toObject ? seat.toObject() : seat,
        user: req.user,
        reason: reason || req.body?.reason || ''
      });

      await Seat.findByIdAndUpdate(seat._id, {
        isDeleted: true,
        isActive: false,
        deletedAt: new Date(),
        deletedBy: req.user?._id
      });
    }

    res.json({
      success: true,
      message: `Successfully moved ${seatsToDelete.length} seat(s) to Recycle Bin (Trash)`
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /bulk-update - Bulk update zone, floor, type, branch, or status
router.post('/bulk-update', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { seatIds, updates } = req.body;
    if (!Array.isArray(seatIds) || seatIds.length === 0) {
      return res.status(400).json({ success: false, message: 'No seat IDs provided' });
    }

    const updateObj = {};
    if (updates.zone) updateObj.zone = updates.zone.trim();
    if (updates.floor !== undefined) updateObj.floor = updates.floor.trim();
    if (updates.type) updateObj.type = updates.type;
    if (updates.branch !== undefined) updateObj.branch = updates.branch || null;
    if (updates.status) updateObj.status = updates.status;
    if (updates.monthlyRate !== undefined) updateObj.monthlyRate = parseFloat(updates.monthlyRate) || 0;

    const result = await Seat.updateMany({ _id: { $in: seatIds } }, { $set: updateObj });
    res.json({ success: true, message: `Updated ${result.modifiedCount} seats successfully` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /:id - Full update of single seat
router.put('/:id', roleCheck('owner', 'branch_manager'), validateSeatUpdate, async (req, res) => {
  try {
    const updateData = { ...req.body };
    if (updateData.monthlyRate !== undefined) {
      updateData.monthlyRate = parseFloat(updateData.monthlyRate) || 0;
    }
    if (updateData.amenities && typeof updateData.amenities === 'string') {
      updateData.amenities = updateData.amenities.split(',').map(a => a.trim()).filter(Boolean);
    }
    if (updateData.branch === '' || updateData.branch === 'none') {
      updateData.branch = null;
    }

    const seat = await Seat.findByIdAndUpdate(req.params.id, updateData, {
      new: true,
      runValidators: true
    }).populate('currentStudent', 'name studentId').populate('branch', 'name code');

    if (!seat) {
      return res.status(404).json({ success: false, message: 'Seat not found' });
    }
    res.json({ success: true, data: seat, message: 'Seat details modified successfully' });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ success: false, message: 'Seat number already exists in system' });
    }
    res.status(400).json({ success: false, message: error.message });
  }
});

// DELETE /:id - Delete seat
router.delete('/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const seat = await Seat.findById(req.params.id).populate('branch', 'name');
    if (!seat) {
      return res.status(404).json({ success: false, message: 'Seat not found' });
    }
    
    if (seat.status === 'occupied' || seat.currentStudent) {
      return res.status(400).json({ success: false, message: 'Cannot delete an occupied seat. Please release the student first.' });
    }
    
    await moveToTrash({
      itemType: 'seat',
      itemId: seat._id,
      itemTitle: `Desk ${seat.seatNumber} (${seat.zone || 'Zone A'})`,
      itemSubtitle: `Floor: ${seat.floor || 'G'} • Type: ${(seat.type || 'regular').toUpperCase()} • Branch: ${seat.branch?.name || 'Main'}`,
      originalCollection: 'seats',
      itemData: seat.toObject ? seat.toObject() : seat,
      user: req.user,
      reason: req.body?.reason || ''
    });

    await Seat.findByIdAndUpdate(seat._id, {
      isDeleted: true,
      isActive: false,
      deletedAt: new Date(),
      deletedBy: req.user?._id
    });

    res.json({ success: true, data: {}, message: `Seat "${seat.seatNumber}" moved to Recycle Bin (Trash).` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /zones/update - Update zoneColor and seatType for all seats matching a zone name
router.put('/zones/update', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { zone, zoneColor, seatType, floor, branch } = req.body;
    if (!zone) return res.status(400).json({ success: false, message: 'Zone name is required' });
    
    const filter = { zone: zone.trim(), isDeleted: { $ne: true } };
    if (branch && branch !== 'all') filter.branch = branch;

    const updateObj = {};
    if (zoneColor) updateObj.zoneColor = zoneColor;
    if (seatType) updateObj.seatType = seatType;
    if (floor !== undefined) updateObj.floor = floor;
    
    const result = await Seat.updateMany(filter, { $set: updateObj });
    res.json({ success: true, message: `Updated ${result.modifiedCount} seats in zone "${zone}" successfully` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /zones/rename - Rename a zone and optionally update its metadata across all matching desks
router.put('/zones/rename', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { oldZone, newZone, zoneColor, seatType, floor, branch } = req.body;
    if (!oldZone || !newZone) {
      return res.status(400).json({ success: false, message: 'Both oldZone and newZone names are required' });
    }

    const filter = { zone: oldZone.trim(), isDeleted: { $ne: true } };
    if (branch && branch !== 'all') filter.branch = branch;

    const updateObj = { zone: newZone.trim() };
    if (zoneColor) updateObj.zoneColor = zoneColor;
    if (seatType) updateObj.seatType = seatType;
    if (floor !== undefined) updateObj.floor = floor;

    const result = await Seat.updateMany(filter, { $set: updateObj });
    res.json({
      success: true,
      message: `Zone "${oldZone}" renamed to "${newZone}". Updated ${result.modifiedCount} seats successfully.`,
      data: { modifiedCount: result.modifiedCount }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /zones/delete - Delete a zone by reassigning desks to another zone or moving them to Trash
router.post('/zones/delete', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { zone, action = 'reassign', targetZone = 'General', branch } = req.body;
    if (!zone) {
      return res.status(400).json({ success: false, message: 'Zone name is required' });
    }

    const filter = { zone: zone.trim(), isDeleted: { $ne: true } };
    if (branch && branch !== 'all') filter.branch = branch;

    if (action === 'trash') {
      const seats = await Seat.find(filter);
      for (const seat of seats) {
        await moveToTrash({
          itemType: 'Seat',
          itemId: seat._id,
          itemTitle: `Desk ${seat.seatNumber} (${seat.zone})`,
          itemData: seat.toObject(),
          deletedBy: req.user?._id
        });
        seat.isDeleted = true;
        seat.isActive = false;
        await seat.save();
      }
      return res.json({
        success: true,
        message: `Zone "${zone}" removed and ${seats.length} seats moved to Recycle Bin.`
      });
    } else {
      const destZone = (targetZone || 'General').trim();
      const result = await Seat.updateMany(filter, { $set: { zone: destZone } });
      return res.json({
        success: true,
        message: `Zone "${zone}" deleted. ${result.modifiedCount} seats reassigned to "${destZone}".`,
        data: { modifiedCount: result.modifiedCount }
      });
    }
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /reorder - Bulk update row/column coordinates for drag-and-drop seat grid reordering
router.put('/reorder', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { seats } = req.body; // Array of { id, row, column }
    if (!Array.isArray(seats) || seats.length === 0) {
      return res.status(400).json({ success: false, message: 'No seats provided' });
    }

    const bulkOps = seats.map(s => ({
      updateOne: {
        filter: { _id: s.id },
        update: { $set: { row: s.row, column: s.column } }
      }
    }));

    const result = await Seat.bulkWrite(bulkOps);
    res.json({ success: true, message: `Reordered ${result.modifiedCount} seats successfully` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /:id/assign - Assign student to seat with shift overlap prevention & bidirectional synchronization
router.post('/:id/assign', roleCheck('owner', 'branch_manager'), validate([
  body('studentId').notEmpty().withMessage('Student ID is required')
]), async (req, res) => {
  try {
    const { studentId } = req.body;
    const seat = await Seat.findById(req.params.id).lean();
    
    if (!seat) {
      return res.status(404).json({ success: false, message: 'Seat not found' });
    }

    if (seat.status === 'maintenance') {
      return res.status(400).json({ success: false, message: 'Cannot assign student to a seat under maintenance' });
    }

    const student = await Student.findById(studentId).populate('shift').populate('plan').lean();
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    // Shift Overlap Prevention: Find other active students assigned to this seat
    const occupiedStudents = await Student.find({
      seat: seat._id,
      status: 'active',
      _id: { $ne: student._id }
    }).populate('shift').populate('plan');

    for (const other of occupiedStudents) {
      const otherShift = other.shift;
      const curShift = student.shift;

      if (Shift.doShiftsOverlap(curShift, otherShift)) {
        return res.status(409).json({
          success: false,
          message: `Shift conflict: Seat ${seat.seatNumber} is already assigned to ${other.name} during overlapping timing (${otherShift?.name || 'Full Day Access'})`
        });
      }
    }

    // If student was already assigned to another seat, unassign that seat
    if (student.seat && student.seat.toString() !== seat._id.toString()) {
      await Seat.findByIdAndUpdate(student.seat, { currentStudent: null, status: 'available' });
    }

    // Atomic seat assignment guard
    const updatedSeat = await Seat.findOneAndUpdate(
      {
        _id: seat._id,
        status: { $ne: 'maintenance' },
        $or: [
          { status: 'available' },
          { currentStudent: null },
          { currentStudent: student._id }
        ]
      },
      {
        $set: {
          currentStudent: student._id,
          status: 'occupied',
          assignedAt: new Date()
        }
      },
      { new: true }
    );

    if (!updatedSeat) {
      return res.status(409).json({
        success: false,
        message: `Seat ${seat.seatNumber} is currently occupied or unavailable`
      });
    }

    // Update student
    await Student.findByIdAndUpdate(student._id, { seat: updatedSeat._id });
    
    const populated = await Seat.findById(seat._id).populate('currentStudent', 'name studentId phone').lean();
    res.json({ success: true, data: populated, message: `Student ${student.name} assigned to Seat ${seat.seatNumber} successfully` });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
});

// POST /:id/release - Release seat and unassign student
router.post('/:id/release', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const seat = await Seat.findById(req.params.id);
    
    if (!seat) {
      return res.status(404).json({ success: false, message: 'Seat not found' });
    }
    
    await Student.updateMany({ seat: seat._id }, { $set: { seat: null } });

    seat.currentStudent = null;
    seat.status = 'available';
    await seat.save();
    
    res.json({ success: true, data: seat, message: `Seat ${seat.seatNumber} released and marked available` });
  } catch (error) {
    res.status(400).json({ success: false, message: error.message });
  }
});

module.exports = router;
