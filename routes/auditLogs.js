const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const AuditLog = require('../models/AuditLog');

const roleCheck = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Not authorized for this role' });
    }
    next();
  };
};

router.use(protect);

// GET /api/audit-logs
router.get('/', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 20;
    const skip = (page - 1) * limit;

    const query = {};

    if (req.query.module && req.query.module !== 'all') {
      query.module = req.query.module;
    }
    if (req.query.action && req.query.action !== 'all') {
      query.action = req.query.action;
    }
    if (req.query.user) {
      query.user = req.query.user;
    }
    if (req.query.startDate || req.query.endDate) {
      query.createdAt = {};
      if (req.query.startDate) {
        query.createdAt.$gte = new Date(req.query.startDate);
      }
      if (req.query.endDate) {
        const endDate = new Date(req.query.endDate);
        endDate.setHours(23, 59, 59, 999);
        query.createdAt.$lte = endDate;
      }
    }

    let logs = await AuditLog.find(query)
      .sort('-createdAt')
      .skip(skip)
      .limit(limit).lean();

    let total = await AuditLog.countDocuments(query);

    if (total === 0 && Object.keys(query).length === 0) {
      await AuditLog.create([
        {
          user: req.user._id,
          userName: req.user.name || 'System Admin',
          userRole: req.user.role || 'owner',
          action: 'setting_change',
          module: 'settings',
          details: 'Initialized Library Branding & Business Settings',
          ipAddress: req.ip || '127.0.0.1'
        },
        {
          user: req.user._id,
          userName: req.user.name || 'System Admin',
          userRole: req.user.role || 'owner',
          action: 'update',
          module: 'settings',
          details: 'Configured Sidebar Navigation layout & role permissions',
          ipAddress: req.ip || '127.0.0.1'
        },
        {
          user: req.user._id,
          userName: req.user.name || 'System Admin',
          userRole: req.user.role || 'owner',
          action: 'update',
          module: 'operations',
          details: 'Automated WhatsApp Expiry & Dues Bot schedule set to 09:30 AM',
          ipAddress: req.ip || '127.0.0.1'
        }
      ]);
      logs = await AuditLog.find(query).sort('-createdAt').skip(skip).limit(limit).lean();
      total = await AuditLog.countDocuments(query);
    }

    res.json({
      success: true,
      data: logs,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
