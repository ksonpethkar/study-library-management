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

// POST /api/messages/send-reminder - 1-Click WhatsApp Reminder Dispatcher
router.post('/send-reminder', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { studentId, reminderType = 'expiry', customAmount } = req.body;
    if (!studentId) {
      return res.status(400).json({ success: false, message: 'Student ID is required' });
    }

    const student = await Student.findById(studentId).populate('seat').populate('plan');
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    const Payment = require('../models/Payment');
    const Attendance = require('../models/Attendance');
    const WhatsAppService = require('../utils/whatsappService');

    const profile = await BusinessProfile.getProfile();
    const upiId = profile?.upiId || '';
    const bizName = profile?.businessName || 'Study Library';

    let messageText = '';
    let upiLink = '';

    if (reminderType === 'expiry') {
      const expDate = student.expiryDate || student.planExpiresAt;
      let timeLeftStr = 'Soon';
      if (expDate) {
        const diffHours = Math.round((new Date(expDate).getTime() - Date.now()) / (1000 * 60 * 60));
        const diffDays = Math.ceil((new Date(expDate).getTime() - Date.now()) / (1000 * 60 * 60 * 24));
        if (diffDays <= 0) timeLeftStr = 'TODAY (Expired)';
        else if (diffDays === 1 || diffHours <= 24) timeLeftStr = '24 hours';
        else if (diffDays === 2 || diffHours <= 48) timeLeftStr = '48 hours';
        else timeLeftStr = `${diffDays} days`;
      }
      const amount = customAmount !== undefined ? Number(customAmount) : (student.plan?.price || 0);
      upiLink = upiId ? WhatsAppService.generateUpiDeepLink({
        upiId,
        businessName: bizName,
        amount,
        note: 'SubscriptionRenewal'
      }) : '';

      messageText = WhatsAppService.getExpiryReminderMessage(
        student,
        timeLeftStr,
        bizName,
        upiId,
        amount,
        upiLink
      );
    } else if (reminderType === 'partial_balance') {
      const payment = await Payment.findOne({
        student: student._id,
        balanceDue: { $gt: 0 }
      }).sort({ createdAt: -1 }) || await Payment.findOne({ student: student._id }).sort({ createdAt: -1 });

      const balanceAmt = customAmount !== undefined ? Number(customAmount) : (payment?.balanceDue || student.pendingFine || 500);
      upiLink = upiId ? WhatsAppService.generateUpiDeepLink({
        upiId,
        businessName: bizName,
        amount: balanceAmt,
        note: 'PartialPaymentBalance'
      }) : '';

      messageText = WhatsAppService.getPartialBalanceReminderMessage(
        student,
        payment || { balanceDue: balanceAmt, dueDate: new Date() },
        bizName,
        upiId,
        upiLink
      );
    } else if (reminderType === 'attendance') {
      const attendance = await Attendance.findOne({ student: student._id }).sort({ date: -1, createdAt: -1 });
      const attendanceInfo = {
        status: attendance?.status === 'present' ? 'Present / Active' : (attendance?.status || 'Active in Study Hall'),
        time: attendance?.inTime ? new Date(attendance.inTime).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
      };
      messageText = WhatsAppService.getAttendanceAlertMessage(student, bizName, attendanceInfo);
    } else {
      return res.status(400).json({ success: false, message: `Unsupported reminder type: ${reminderType}` });
    }

    // Dispatch in-app notification & prepare click-to-chat URL
    const result = await WhatsAppService.dispatchReminder({
      student,
      message: messageText,
      type: reminderType,
      link: reminderType === 'partial_balance' ? '#/payments' : '#/students'
    });

    const whatsappUrl = WhatsAppService.getClickToChatUrl(student.phone, messageText);

    res.json({
      success: true,
      message: `${reminderType.replace('_', ' ').toUpperCase()} reminder generated successfully`,
      data: {
        studentId: student._id,
        studentName: student.name,
        phone: student.phone,
        formattedPhone: WhatsAppService.formatPhone(student.phone),
        reminderType,
        messageText,
        upiLink,
        whatsappUrl
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
