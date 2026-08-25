const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const Branch = require('../models/Branch');
const Seat = require('../models/Seat');
const Student = require('../models/Student');
const User = require('../models/User');
const BusinessProfile = require('../models/BusinessProfile');
const { protect } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

const roleCheck = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Authentication required' });
    }
    const userRole = req.user.role || 'student';
    if (['owner', 'superadmin', 'admin', 'branch_manager'].includes(userRole) || roles.includes(userRole)) {
      return next();
    }
    return res.status(403).json({ success: false, message: 'Not authorized for this role' });
  };
};

// GET /public-list — Public endpoint for student registration branch selection
router.get('/public-list', async (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  try {
    const [branches, occupiedCounts, profile] = await Promise.all([
      Branch.find({ isActive: true, isDeleted: { $ne: true } })
        .select('name code city address phone totalSeats amenities image banner')
        .lean(),
      Seat.aggregate([
        { $match: { status: 'occupied', isActive: true, branch: { $ne: null }, isDeleted: { $ne: true } } },
        { $group: { _id: '$branch', count: { $sum: 1 } } }
      ]),
      BusinessProfile.getProfile().catch(() => ({}))
    ]);

    if (!branches || branches.length === 0) {
      return res.json({
        success: true,
        data: [{
          _id: 'default_main',
          name: profile?.businessName || 'Main Study Centre',
          code: 'MAIN',
          city: profile?.city || 'Main Campus',
          address: profile?.address || 'Main Study Hall',
          phone: profile?.phone || '',
          totalSeats: 100,
          occupiedSeats: 0,
          availableSeats: 100
        }]
      });
    }

    const occupiedMap = new Map(occupiedCounts.map(c => [String(c._id), c.count]));
    const data = branches.map(b => {
      const occupiedSeats = occupiedMap.get(String(b._id)) || 0;
      const totalSeats = b.totalSeats || 50;
      const availableSeats = Math.max(0, totalSeats - occupiedSeats);
      return {
        ...b,
        occupiedSeats,
        availableSeats
      };
    });

    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Protect all remaining branch routes
router.use(protect);

// GET /stats — Return branch summary
router.get('/stats', async (req, res) => {
  try {
    const [totalBranches, activeBranches, totalActiveStudents, branches] = await Promise.all([
      Branch.countDocuments({ isDeleted: { $ne: true } }),
      Branch.countDocuments({ isActive: true, isDeleted: { $ne: true } }),
      Student.countDocuments({ status: 'active', isDeleted: { $ne: true } }),
      Branch.find({ isActive: true, isDeleted: { $ne: true } }).lean()
    ]);

    const totalCapacity = branches.reduce((sum, b) => sum + (b.totalSeats || 0), 0);
    const assignedManagerIds = branches.filter(b => b.manager).map(b => b.manager.toString());
    const uniqueManagersCount = new Set(assignedManagerIds).size;
    const totalOccupiedSeats = await Seat.countDocuments({ status: 'occupied', isActive: true, isDeleted: { $ne: true } });

    res.json({
      success: true,
      data: {
        totalBranches,
        activeBranches,
        totalSeats: totalCapacity,
        totalCapacity,
        totalActiveStudents,
        activeManagers: uniqueManagersCount,
        totalOccupiedSeats,
        occupancyRate: totalCapacity > 0 ? Math.round((totalActiveStudents / totalCapacity) * 100) : 0
      },
      message: 'Branch statistics retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /managers — Return list of active managers/staff for branch assignment
router.get('/managers', async (req, res) => {
  try {
    const managers = await User.find({
      isActive: true,
      role: { $in: ['branch_manager', 'owner', 'staff', 'admin'] }
    })
      .select('name email phone role avatar')
      .sort('name').lean();
    res.json({
      success: true,
      data: managers,
      message: 'Managers retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET / — List all branches with populated manager info and seat counts
router.get('/', async (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  try {
    const filter = { isActive: { $ne: false } };
    if (req.query.isActive === 'all') {
      delete filter.isActive;
    } else if (req.query.isActive !== undefined) {
      filter.isActive = req.query.isActive === 'true';
    }
    if (req.query.search) {
      filter.$or = [
        { name: { $regex: req.query.search, $options: 'i' } },
        { code: { $regex: req.query.search, $options: 'i' } },
        { city: { $regex: req.query.search, $options: 'i' } }
      ];
    }

    const branches = await Branch.find(filter)
      .populate('manager', 'name email phone avatar role')
      .sort({ isMainBranch: -1, createdAt: -1 });

    const branchesWithCounts = await Promise.all(branches.map(async (b) => {
      const branchObj = b.toObject ? b.toObject() : { ...b };
      const [configuredSeats, occupiedSeats, activeStudents] = await Promise.all([
        Seat.countDocuments({ branch: b._id, isActive: true, isDeleted: { $ne: true } }),
        Seat.countDocuments({ branch: b._id, status: 'occupied', isActive: true, isDeleted: { $ne: true } }),
        Student.countDocuments({ branch: b._id, status: 'active', isDeleted: { $ne: true } })
      ]);

      branchObj.configuredSeats = configuredSeats;
      branchObj.occupiedSeats = occupiedSeats;
      branchObj.activeStudents = activeStudents;
      branchObj.effectiveCapacity = b.totalSeats || configuredSeats || 50;
      branchObj.occupancyPercent = branchObj.effectiveCapacity > 0 
        ? Math.min(100, Math.round(((occupiedSeats || activeStudents) / branchObj.effectiveCapacity) * 100))
        : 0;

      return branchObj;
    }));

    res.json({
      success: true,
      data: branchesWithCounts,
      message: 'Branches fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /:id — Single branch details
router.get('/:id', async (req, res) => {
  try {
    const branch = await Branch.findById(req.params.id)
      .populate('manager', 'name email phone avatar role');

    if (!branch) {
      return res.status(404).json({ success: false, message: 'Branch not found' });
    }

    const branchObj = branch.toObject ? branch.toObject() : { ...branch };
    const [configuredSeats, occupiedSeats, activeStudents] = await Promise.all([
      Seat.countDocuments({ branch: branch._id, isActive: true, isDeleted: { $ne: true } }),
      Seat.countDocuments({ branch: branch._id, status: 'occupied', isActive: true, isDeleted: { $ne: true } }),
      Student.countDocuments({ branch: branch._id, status: 'active', isDeleted: { $ne: true } })
    ]);

    branchObj.configuredSeats = configuredSeats;
    branchObj.occupiedSeats = occupiedSeats;
    branchObj.activeStudents = activeStudents;
    branchObj.effectiveCapacity = branch.totalSeats || configuredSeats || 50;
    branchObj.occupancyPercent = branchObj.effectiveCapacity > 0 
      ? Math.min(100, Math.round(((occupiedSeats || activeStudents) / branchObj.effectiveCapacity) * 100))
      : 0;

    res.json({
      success: true,
      data: branchObj,
      message: 'Branch retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST / — Create branch
router.post('/', validate([
  body('name').notEmpty().withMessage('Branch name is required').trim(),
  body('code').notEmpty().withMessage('Branch code is required').trim(),
  body('address').notEmpty().withMessage('Address is required').trim(),
  body('city').notEmpty().withMessage('City is required').trim(),
  body('phone').notEmpty().withMessage('Phone number is required').trim(),
  body('totalSeats').optional().isInt({ min: 0 }).withMessage('Total seats must be a non-negative number')
]), roleCheck('owner'), async (req, res) => {
  try {
    const {
      name,
      code,
      address,
      city,
      state,
      pincode,
      phone,
      email,
      manager,
      totalSeats,
      amenities,
      isMainBranch,
      isActive
    } = req.body;

    const formattedCode = code.toUpperCase().trim();
    const existing = await Branch.findOne({ code: formattedCode }).lean();
    if (existing) {
      return res.status(400).json({ success: false, message: 'Branch code already exists' });
    }

    if (isMainBranch) {
      await Branch.updateMany({ isMainBranch: true }, { $set: { isMainBranch: false } });
    }

    const branch = new Branch({
      name,
      code: formattedCode,
      address,
      city,
      state: state || '',
      pincode: pincode || '',
      phone,
      email: email || '',
      manager: manager || null,
      totalSeats: totalSeats !== undefined ? parseInt(totalSeats, 10) : 50,
      amenities: Array.isArray(amenities) ? amenities : ['AC', 'WiFi', 'CCTV', 'Power Backup', 'RO Water', 'Locker'],
      isMainBranch: Boolean(isMainBranch),
      isActive: isActive !== undefined ? Boolean(isActive) : true
    });

    await branch.save();
    await branch.populate('manager', 'name email phone avatar role');

    res.status(201).json({
      success: true,
      data: branch,
      message: 'Branch created successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /:id — Update branch
router.put('/:id', validate([
  body('name').optional().notEmpty().withMessage('Branch name cannot be empty').trim(),
  body('code').optional().notEmpty().withMessage('Branch code cannot be empty').trim(),
  body('address').optional().notEmpty().withMessage('Address cannot be empty').trim(),
  body('city').optional().notEmpty().withMessage('City cannot be empty').trim(),
  body('phone').optional().notEmpty().withMessage('Phone number cannot be empty').trim(),
  body('totalSeats').optional().isInt({ min: 0 }).withMessage('Total seats must be a non-negative number')
]), roleCheck('owner'), async (req, res) => {
  try {
    const branch = await Branch.findById(req.params.id);
    if (!branch) {
      return res.status(404).json({ success: false, message: 'Branch not found' });
    }

    if (req.body.code) {
      const formattedCode = req.body.code.toUpperCase().trim();
      const existing = await Branch.findOne({ code: formattedCode, _id: { $ne: branch._id } }).lean();
      if (existing) {
        return res.status(400).json({ success: false, message: 'Branch code already in use by another branch' });
      }
      req.body.code = formattedCode;
    }

    if (req.body.isMainBranch) {
      await Branch.updateMany({ _id: { $ne: branch._id }, isMainBranch: true }, { $set: { isMainBranch: false } });
    }

    const updated = await Branch.findByIdAndUpdate(
      req.params.id,
      { $set: req.body },
      { new: true, runValidators: true }
    ).populate('manager', 'name email phone avatar role');

    res.json({
      success: true,
      data: updated,
      message: 'Branch updated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /:id — Delete branch
router.delete('/:id', roleCheck('owner'), async (req, res) => {
  try {
    const branch = await Branch.findById(req.params.id);
    if (!branch) {
      return res.status(404).json({ success: false, message: 'Branch not found' });
    }

    // If other active branches exist, promote the next active branch to primary main branch
    const nextBranch = await Branch.findOne({ _id: { $ne: branch._id }, isActive: { $ne: false } });
    if (branch.isMainBranch && nextBranch) {
      nextBranch.isMainBranch = true;
      await nextBranch.save();
    }

    // Reassign students & seats to next active branch if available, else clean up
    if (nextBranch) {
      await Student.updateMany({ branch: branch._id }, { $set: { branch: nextBranch._id } });
      await Seat.updateMany({ branch: branch._id }, { $set: { branch: nextBranch._id } });
    } else {
      await Seat.deleteMany({ branch: branch._id });
    }

    // Move to Trash
    const { moveToTrash } = require('./trash');
    await moveToTrash({
      itemType: 'branch',
      itemId: branch._id,
      itemTitle: `${branch.name} (${branch.code || 'Campus'})`,
      itemSubtitle: `City: ${branch.city || 'N/A'} • Total Seats: ${branch.totalSeats || 0} • Status: ${branch.isActive ? 'ACTIVE' : 'INACTIVE'}`,
      originalCollection: 'branches',
      itemData: branch.toObject ? branch.toObject() : branch,
      user: req.user,
      reason: req.body?.reason || ''
    });

    branch.isActive = false;
    branch.isDeleted = true;
    await branch.save();

    res.json({
      success: true,
      data: branch,
      message: `Branch "${branch.name}" moved to Recycle Bin (Trash).`
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
