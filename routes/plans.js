const express = require('express');
const router = express.Router();
const Plan = require('../models/Plan');
const { protect } = require('../middleware/auth');
const { validate, validatePlanCreate, validatePlanUpdate } = require('../middleware/validate');
const memoryCache = require('../utils/memoryCache');

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

// GET / — List active plans (Public for registration & landing page)
router.get('/', async (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  try {
    const Student = require('../models/Student');
    const [plans, counts] = await Promise.all([
      Plan.find({ isActive: true, isDeleted: { $ne: true } }).sort('displayOrder').lean(),
      Student.aggregate([
        { $match: { status: 'active', plan: { $ne: null } } },
        { $group: { _id: '$plan', count: { $sum: 1 } } }
      ])
    ]);
    
    const countsMap = new Map(counts.map(c => [String(c._id), c.count]));
    const enriched = plans.map(p => ({
      ...p,
      activeMembersCount: countsMap.get(String(p._id)) || 0
    }));

    res.json({ success: true, data: enriched, message: 'Active plans retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Protect write and admin operations
router.use(protect);
router.use((req, res, next) => {
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(req.method)) {
    memoryCache.clear();
  }
  next();
});

router.get('/all', async (req, res) => {
  try {
    const Student = require('../models/Student');
    const [plans, counts] = await Promise.all([
      Plan.find({ isDeleted: { $ne: true } }).sort('displayOrder').lean(),
      Student.aggregate([
        { $match: { status: 'active', plan: { $ne: null } } },
        { $group: { _id: '$plan', count: { $sum: 1 } } }
      ])
    ]);

    const countsMap = new Map(counts.map(c => [String(c._id), c.count]));
    const enriched = plans.map(p => ({
      ...p,
      activeMembersCount: countsMap.get(String(p._id)) || 0
    }));

    res.json({ success: true, data: enriched, message: 'All plans retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const plan = await Plan.findById(req.params.id).populate('enrolledCount').lean();
    if (!plan) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }
    res.json({ success: true, data: plan, message: 'Plan retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', roleCheck('owner', 'branch_manager'), validatePlanCreate, async (req, res) => {
  try {
    if (typeof req.body.features === 'string') {
      req.body.features = req.body.features.split(',').map(f => f.trim()).filter(f => f);
    }
    const plan = await Plan.create(req.body);
    res.status(201).json({ success: true, data: plan, message: 'Plan created successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/reorder', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { orders } = req.body;
    if (!Array.isArray(orders)) {
      return res.status(400).json({ success: false, message: 'Invalid orders format' });
    }
    
    const operations = orders.map(order => ({
      updateOne: {
        filter: { _id: order.id },
        update: { displayOrder: order.displayOrder }
      }
    }));
    
    if (operations.length > 0) {
      await Plan.bulkWrite(operations);
    }
    
    res.json({ success: true, data: null, message: 'Display order updated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id', roleCheck('owner', 'branch_manager'), validatePlanUpdate, async (req, res) => {
  try {
    if (typeof req.body.features === 'string') {
      req.body.features = req.body.features.split(',').map(f => f.trim()).filter(f => f);
    }
    const plan = await Plan.findByIdAndUpdate(
      req.params.id, 
      req.body, 
      { new: true, runValidators: true }
    );
    if (!plan) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }
    res.json({ success: true, data: plan, message: 'Plan updated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { moveToTrash } = require('./trash');
    const plan = await Plan.findById(req.params.id);
    if (!plan) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }
    
    plan.isActive = false;
    plan.isDeleted = true;
    await plan.save();

    await moveToTrash({
      itemType: 'plan',
      itemId: plan._id,
      itemTitle: `${plan.name} (₹${plan.price})`,
      itemSubtitle: `Duration: ${plan.duration} ${plan.durationType || 'days'} • Shift: ${plan.shift || 'Any'}`,
      originalCollection: 'plans',
      itemData: plan.toObject ? plan.toObject() : plan,
      user: req.user,
      reason: req.body?.reason || ''
    });

    res.json({ success: true, data: plan, message: `Plan "${plan.name}" moved to Recycle Bin (Trash).` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
