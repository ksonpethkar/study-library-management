const express = require('express');
const router = express.Router();
const Plan = require('../models/Plan');
const { protect } = require('../middleware/auth');
const { body, validationResult } = require('express-validator');

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
      return res.status(400).json({ 
        success: false, 
        errors: errors.array(), 
        message: errors.array()[0]?.msg || 'Validation failed' 
      });
    }
    next();
  };
}

// GET / — List active plans (Public for registration & landing page)
router.get('/', async (req, res) => {
  try {
    const plans = await Plan.find({ isActive: true })
      .sort('displayOrder')
      .populate('enrolledCount')
      .lean();
    res.json({ success: true, data: plans, message: 'Active plans retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Protect write and admin operations
router.use(protect);

router.get('/all', async (req, res) => {
  try {
    const plans = await Plan.find()
      .sort('displayOrder')
      .populate('enrolledCount');
    res.json({ success: true, data: plans, message: 'All plans retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const plan = await Plan.findById(req.params.id).populate('enrolledCount');
    if (!plan) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }
    res.json({ success: true, data: plan, message: 'Plan retrieved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

const createValidations = [
  body('name').notEmpty().withMessage('Name is required').trim(),
  body('duration').isNumeric().withMessage('Duration is required and must be a number'),
  body('price').isNumeric().withMessage('Price is required and must be a number')
];

router.post('/', roleCheck('owner', 'branch_manager'), validate(createValidations), async (req, res) => {
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

router.put('/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
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
    const plan = await Plan.findByIdAndUpdate(
      req.params.id,
      { isActive: false },
      { new: true }
    );
    if (!plan) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }
    res.json({ success: true, data: plan, message: 'Plan deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
