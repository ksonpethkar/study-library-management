const express = require('express');
const router = express.Router();
const MessageTemplate = require('../models/MessageTemplate');
const Student = require('../models/Student');
const BusinessProfile = require('../models/BusinessProfile');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');

// GET /api/messages/templates - List templates
router.get('/templates', protect, async (req, res) => {
  try {
    await MessageTemplate.seedDefaults();
    const templates = await MessageTemplate.find().sort({ createdAt: -1 });
    res.json({ success: true, templates });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/messages/templates - Create template
router.post('/templates', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { title, triggerType, channel, templateText, availableVariables } = req.body;
    const t = new MessageTemplate({
      title,
      triggerType: triggerType || 'custom',
      channel: channel || 'whatsapp',
      templateText,
      availableVariables: availableVariables || []
    });
    await t.save();
    res.status(201).json({ success: true, message: 'Template created', template: t });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/messages/templates/:id - Update template
router.put('/templates/:id', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const t = await MessageTemplate.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!t) return res.status(404).json({ success: false, message: 'Template not found' });
    res.json({ success: true, message: 'Template updated', template: t });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/messages/prepare-broadcast - Generate customized messages and WhatsApp URLs for recipients
router.post('/prepare-broadcast', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { templateId, customMessage, targetFilter, studentIds } = req.body;
    const business = await BusinessProfile.getProfile();
    const libraryName = business?.businessName || 'Study Library';

    let messageTemplate = customMessage || '';
    if (templateId) {
      const t = await MessageTemplate.findById(templateId);
      if (t) messageTemplate = t.templateText;
    }

    let students = [];
    if (studentIds && studentIds.length > 0) {
      students = await Student.find({ _id: { $in: studentIds } }).populate('seat', 'seatNumber').populate('plan', 'name');
    } else if (targetFilter === 'expiring_3d') {
      const now = new Date();
      const threeDaysLater = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
      students = await Student.find({
        status: 'active',
        expiryDate: { $gte: now, $lte: threeDaysLater }
      }).populate('seat', 'seatNumber').populate('plan', 'name');
    } else if (targetFilter === 'expired') {
      students = await Student.find({
        status: { $in: ['expired', 'suspended'] }
      }).populate('seat', 'seatNumber').populate('plan', 'name');
    } else {
      students = await Student.find({ status: 'active' }).populate('seat', 'seatNumber').populate('plan', 'name');
    }

    const preparedMessages = students.map(s => {
      let text = messageTemplate;
      text = text.replace(/{student_name}/g, s.name || 'Student');
      text = text.replace(/{library_name}/g, libraryName);
      text = text.replace(/{student_id}/g, s.studentId || '');
      text = text.replace(/{seat_no}/g, s.seat?.seatNumber || 'N/A');
      text = text.replace(/{plan_name}/g, s.plan?.name || 'General');
      text = text.replace(/{expiry_date}/g, s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : 'N/A');
      text = text.replace(/{upi_id}/g, business?.upiQrCode ? 'Available on request' : '');

      let phone = (s.phone || '').replace(/[^0-9]/g, '');
      if (phone.length === 10) phone = '91' + phone;

      const whatsappUrl = phone ? `https://api.whatsapp.com/send?phone=${phone}&text=${encodeURIComponent(text)}` : null;

      return {
        studentId: s._id,
        studentName: s.name,
        phone: s.phone,
        text,
        whatsappUrl
      };
    });

    res.json({
      success: true,
      count: preparedMessages.length,
      messages: preparedMessages
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
