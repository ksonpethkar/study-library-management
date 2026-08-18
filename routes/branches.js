const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const Branch = require('../models/Branch');
const Seat = require('../models/Seat');
const Student = require('../models/Student');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

const roleCheck = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Not authorized for this role' });
    }
    next();
  };
};

// GET /public-list — Public endpoint for student registration branch selection
router.get('/public-list', async (req, res) => {
  try {
    const branches = await Branch.find({ isActive: true }).lean();
    if (!branches || branches.length === 0) {
      return res.json({
        success: true,
        data: [{
          _id: 'default_main',
          name: 'Main Campus Centre',
          code: 'MAIN',
          city: 'Central City',
          address: 'Main Reading Hall Complex',
          phone: '+91 9876543210',
          totalSeats: 100,
          occupiedSeats: 42,
          availableSeats: 58
        }]
      });
    }

    const data = await Promise.all(branches.map(async (b) => {
      const occupiedSeats = await Seat.countDocuments({ branch: b._id, status: 'occupied', isActive: true });
      const totalSeats = b.totalSeats || 50;
      const availableSeats = Math.max(0, totalSeats - occupiedSeats);
      return {
        ...b,
        occupiedSeats,
        availableSeats
      };
    }));

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
      Branch.countDocuments(),
      Branch.countDocuments({ isActive: true }),
      Student.countDocuments({ status: 'active' }),
      Branch.find({ isActive: true })
    ]);

    const totalCapacity = branches.reduce((sum, b) => sum + (b.totalSeats || 0), 0);
    const assignedManagerIds = branches.filter(b => b.manager).map(b => b.manager.toString());
    const uniqueManagersCount = new Set(assignedManagerIds).size;
    const totalOccupiedSeats = await Seat.countDocuments({ status: 'occupied', isActive: true });

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

// GET /managers — Return list of active managers/users for branch assignment
router.get('/managers', async (req, res) => {
  try {
    const managers = await User.find({ isActive: true })
      .select('name email phone role avatar')
      .sort('name');
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
  try {
    const filter = {};
    if (req.query.isActive !== undefined && req.query.isActive !== 'all') {
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
      const branchObj = b.toObject();
      const [configuredSeats, occupiedSeats, activeStudents] = await Promise.all([
        Seat.countDocuments({ branch: b._id, isActive: true }),
        Seat.countDocuments({ branch: b._id, status: 'occupied', isActive: true }),
        Student.countDocuments({ branch: b._id, status: 'active' })
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

    const branchObj = branch.toObject();
    const [configuredSeats, occupiedSeats, activeStudents] = await Promise.all([
      Seat.countDocuments({ branch: branch._id, isActive: true }),
      Seat.countDocuments({ branch: branch._id, status: 'occupied', isActive: true }),
      Student.countDocuments({ branch: branch._id, status: 'active' })
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
    const existing = await Branch.findOne({ code: formattedCode });
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
      const existing = await Branch.findOne({ code: formattedCode, _id: { $ne: branch._id } });
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

// DELETE /:id — Deactivate branch
router.delete('/:id', roleCheck('owner'), async (req, res) => {
  try {
    const branch = await Branch.findById(req.params.id);
    if (!branch) {
      return res.status(404).json({ success: false, message: 'Branch not found' });
    }

    if (branch.isMainBranch) {
      return res.status(400).json({ success: false, message: 'Cannot deactivate the primary main branch' });
    }

    branch.isActive = false;
    await branch.save();

    res.json({
      success: true,
      data: branch,
      message: 'Branch deactivated successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
