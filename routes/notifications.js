const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const Notification = require('../models/Notification');

router.use(protect);

// @route   GET /api/notifications
// @desc    Get user notifications + unread count (Student receives ONLY their own notifications; Admin receives library operational alerts)
router.get('/', async (req, res) => {
  try {
    const isStudent = req.user.role === 'student';
    let filter = {};

    if (isStudent) {
      // Find current student ID
      let studentId = req.user.student;
      if (!studentId) {
        const Student = require('../models/Student');
        const s = await Student.findOne({ 
          $or: [
            { user: req.user._id },
            ...(req.user.email ? [{ email: req.user.email.toLowerCase() }] : []),
            ...(req.user.phone ? [{ phone: req.user.phone }] : [])
          ]
        }).select('_id').lean();
        if (s) studentId = s._id;
      }

      // Students ONLY receive:
      // 1. Direct user-targeted notifications (recipient == req.user._id)
      // 2. Direct student-targeted notifications (student == studentId)
      // 3. General student announcements (targetRole: 'student' or type: 'announcement')
      // STRICTLY EXCLUDE: targetRole: 'admin', or notifications with student != studentId
      filter = {
        targetRole: { $ne: 'admin' },
        $or: [
          { recipient: req.user._id },
          ...(studentId ? [{ student: studentId }] : []),
          { targetRole: 'student', student: null },
          { type: { $in: ['notice', 'general', 'announcement'] }, student: null }
        ]
      };
    } else {
      // Admin / Staff receives all administrative and library activity notifications
      filter = {
        $or: [
          { recipient: req.user._id },
          { recipient: null },
          { targetRole: { $in: ['admin', 'all', null] } }
        ]
      };
    }

    const notifications = await Notification.find(filter)
      .sort({ createdAt: -1 })
      .limit(30)
      .lean();

    const unreadCount = await Notification.countDocuments({
      ...filter,
      isRead: false
    });

    res.json({
      success: true,
      data: {
        notifications,
        unreadCount
      },
      message: 'Notifications retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   PUT /api/notifications/:id/read
// @desc    Mark single notification as read
router.put('/:id/read', async (req, res) => {
  try {
    const notification = await Notification.findByIdAndUpdate(
      req.params.id,
      { isRead: true },
      { new: true, returnDocument: 'after' }
    );

    if (!notification) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    res.json({
      success: true,
      data: notification,
      message: 'Notification marked as read'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   PUT /api/notifications/read-all
// @desc    Mark all notifications as read
router.put('/read-all', async (req, res) => {
  try {
    const isStudent = req.user.role === 'student';
    let filter = {};

    if (isStudent) {
      let studentId = req.user.student;
      if (!studentId) {
        const Student = require('../models/Student');
        const s = await Student.findOne({ 
          $or: [
            { user: req.user._id },
            ...(req.user.email ? [{ email: req.user.email.toLowerCase() }] : []),
            ...(req.user.phone ? [{ phone: req.user.phone }] : [])
          ]
        }).select('_id').lean();
        if (s) studentId = s._id;
      }
      filter = {
        targetRole: { $ne: 'admin' },
        $or: [
          { recipient: req.user._id },
          ...(studentId ? [{ student: studentId }] : []),
          { targetRole: 'student', student: null },
          { type: { $in: ['notice', 'general', 'announcement'] }, student: null }
        ],
        isRead: false
      };
    } else {
      filter = {
        $or: [
          { recipient: req.user._id },
          { recipient: null },
          { targetRole: { $in: ['admin', 'all', null] } }
        ],
        isRead: false
      };
    }

    await Notification.updateMany(filter, { isRead: true });

    res.json({
      success: true,
      message: 'All notifications marked as read'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   DELETE /api/notifications/clear-read
// @desc    Delete all read notifications for user
router.delete('/clear-read', async (req, res) => {
  try {
    const isStudent = req.user.role === 'student';
    let filter = {};

    if (isStudent) {
      let studentId = req.user.student;
      if (!studentId) {
        const Student = require('../models/Student');
        const s = await Student.findOne({ 
          $or: [
            { user: req.user._id },
            ...(req.user.email ? [{ email: req.user.email.toLowerCase() }] : []),
            ...(req.user.phone ? [{ phone: req.user.phone }] : [])
          ]
        }).select('_id').lean();
        if (s) studentId = s._id;
      }
      filter = {
        targetRole: { $ne: 'admin' },
        $or: [
          { recipient: req.user._id },
          ...(studentId ? [{ student: studentId }] : [])
        ],
        isRead: true
      };
    } else {
      filter = {
        $or: [
          { recipient: req.user._id },
          { recipient: null },
          { targetRole: { $in: ['admin', 'all', null] } }
        ],
        isRead: true
      };
    }

    await Notification.deleteMany(filter);

    res.json({
      success: true,
      message: 'All read notifications cleared'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/notifications/receipt-whatsapp-link
// @desc    Generate pre-filled WhatsApp web link for a payment receipt
router.post('/receipt-whatsapp-link', async (req, res) => {
  try {
    const { paymentId } = req.body;
    const Payment = require('../models/Payment');
    const BusinessProfile = require('../models/BusinessProfile');
    const { getWhatsAppShareUrl, formatPaymentReceiptMessage } = require('../services/notificationService');

    const payment = await Payment.findById(paymentId).populate('student').populate('plan');
    if (!payment || !payment.student) {
      return res.status(404).json({ success: false, message: 'Payment or student not found' });
    }

    const student = payment.student;
    const business = await BusinessProfile.getProfile();
    const msg = formatPaymentReceiptMessage(payment, student, business);
    const url = getWhatsAppShareUrl(student.phone, msg);

    res.json({
      success: true,
      data: {
        url,
        message: msg,
        phone: student.phone
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// @route   POST /api/notifications/test-gateway
// @desc    Test WhatsApp or SMS gateway dispatch
router.post('/test-gateway', async (req, res) => {
  try {
    const { phone, type, message } = req.body;
    const { sendGatewayMessage } = require('../services/notificationService');
    const result = await sendGatewayMessage({
      phone: phone || req.user?.phone || '9999999999',
      type: type || 'whatsapp',
      message: message || 'Hello from Study Library Management System!'
    });

    res.json({
      success: true,
      data: result,
      message: `Test ${type === 'sms' ? 'SMS' : 'WhatsApp'} message dispatched successfully!`
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
