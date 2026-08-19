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
    const BusinessProfile = require('../models/BusinessProfile');
    const WhatsAppService = require('../utils/whatsappService');
    const business = await BusinessProfile.getProfile();
    const libraryName = business?.businessName || 'Study Library';
    const baseUrl = WhatsAppService.getBaseUrl(req);
    const upiId = business?.upiId || '';

    let messageTemplate = customMessage || '';
    if (templateId) {
      const t = await MessageTemplate.findById(templateId);
      if (t) messageTemplate = t.templateText;
    }

    let students = [];
    if (studentIds && studentIds.length > 0) {
      students = await Student.find({ _id: { $in: studentIds } })
        .populate('seat', 'seatNumber')
        .populate('plan', 'name price')
        .populate('shift', 'name');
    } else if (targetFilter === 'expiring_3d') {
      const now = new Date();
      const threeDaysLater = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
      students = await Student.find({
        status: 'active',
        expiryDate: { $gte: now, $lte: threeDaysLater }
      })
        .populate('seat', 'seatNumber')
        .populate('plan', 'name price')
        .populate('shift', 'name');
    } else if (targetFilter === 'expired') {
      students = await Student.find({
        status: { $in: ['expired', 'suspended', 'grace_period'] }
      })
        .populate('seat', 'seatNumber')
        .populate('plan', 'name price')
        .populate('shift', 'name');
    } else {
      students = await Student.find({ status: 'active' })
        .populate('seat', 'seatNumber')
        .populate('plan', 'name price')
        .populate('shift', 'name');
    }

    const preparedMessages = students.map(s => {
      const renewalAmount = s.plan?.price || 0;
      const upiLink = upiId ? WhatsAppService.generateUpiDeepLink({
        upiId,
        businessName: libraryName,
        amount: renewalAmount,
        note: 'SubscriptionRenewal'
      }) : '';

      const text = WhatsAppService.renderTemplate(messageTemplate, {
        studentName: s.name || 'Student',
        studentId: s.studentId || '',
        seatNumber: s.seat?.seatNumber || 'N/A',
        shiftName: s.shift?.name || s.shift || 'General',
        planName: s.plan?.name || 'General',
        expiryDate: s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : 'N/A',
        businessName: libraryName,
        upiId,
        upiLink,
        portalLink: `${baseUrl}/#/portal`,
        amount: renewalAmount,
        balanceDue: s.balanceDue || s.pendingFine || 0
      });

      const formattedPhone = WhatsAppService.formatPhone(s.phone);
      const whatsappUrl = formattedPhone ? WhatsAppService.getClickToChatUrl(formattedPhone, text) : null;

      return {
        studentId: s._id,
        studentName: s.name,
        phone: s.phone,
        formattedPhone,
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
    const { studentId, reminderType = 'renewal_reminder', customAmount, customMessage, paymentId } = req.body;
    if (!studentId) {
      return res.status(400).json({ success: false, message: 'Student ID is required' });
    }

    const student = await Student.findById(studentId).populate('seat').populate('plan').populate('shift');
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    const Payment = require('../models/Payment');
    const Attendance = require('../models/Attendance');
    const WhatsAppService = require('../utils/whatsappService');

    const profile = await BusinessProfile.getProfile();
    const upiId = profile?.upiId || '';
    const bizName = profile?.businessName || 'Study Library';
    const baseUrl = WhatsAppService.getBaseUrl(req);

    let messageText = '';
    let upiLink = '';

    const normType = (reminderType === 'expiry' || reminderType === 'renewal' || reminderType === 'renewal_reminder') ? 'renewal_reminder'
      : (reminderType === 'partial_balance' || reminderType === 'balance_due' || reminderType === 'fee_due' || reminderType === 'due') ? 'balance_due'
      : (reminderType === 'admission_welcome' || reminderType === 'admission' || reminderType === 'welcome') ? 'admission_welcome'
      : (reminderType === 'payment_receipt' || reminderType === 'receipt' || reminderType === 'payment') ? 'payment_receipt'
      : (reminderType === 'attendance_punch' || reminderType === 'attendance' || reminderType === 'punch') ? 'attendance_punch'
      : reminderType;

    if (customMessage) {
      messageText = customMessage;
    } else if (normType === 'renewal_reminder') {
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

      messageText = await WhatsAppService.getExpiryReminderMessage(
        student,
        timeLeftStr,
        bizName,
        upiId,
        amount,
        upiLink,
        baseUrl
      );
    } else if (normType === 'balance_due') {
      let payment = null;
      if (paymentId) {
        payment = await Payment.findById(paymentId);
      } else {
        payment = await Payment.findOne({
          student: student._id,
          balanceDue: { $gt: 0 }
        }).sort({ createdAt: -1 }) || await Payment.findOne({ student: student._id }).sort({ createdAt: -1 });
      }

      const balanceAmt = customAmount !== undefined ? Number(customAmount) : (payment?.balanceDue || student.balanceDue || student.pendingFine || 500);
      upiLink = upiId ? WhatsAppService.generateUpiDeepLink({
        upiId,
        businessName: bizName,
        amount: balanceAmt,
        note: 'PartialPaymentBalance'
      }) : '';

      messageText = await WhatsAppService.getBalanceDueMessage(
        student,
        payment || { balanceDue: balanceAmt, dueDate: new Date() },
        bizName,
        upiId,
        upiLink,
        baseUrl
      );
    } else if (normType === 'admission_welcome') {
      messageText = await WhatsAppService.getAdmissionMessage(student, bizName, baseUrl);
    } else if (normType === 'payment_receipt') {
      let payment = null;
      if (paymentId) {
        payment = await Payment.findById(paymentId).populate('plan');
      } else {
        payment = await Payment.findOne({ student: student._id }).sort({ createdAt: -1 }).populate('plan');
      }
      if (!payment) {
        payment = {
          receiptNumber: 'REC-' + Date.now(),
          finalAmount: student.plan?.price || 0,
          paymentMethod: 'UPI',
          paymentDate: new Date(),
          periodEnd: student.expiryDate || student.planExpiresAt,
          balanceDue: 0
        };
      }
      messageText = await WhatsAppService.getPaymentReceiptMessage(payment, student, bizName, baseUrl, upiId);
    } else if (normType === 'attendance_punch') {
      const attendance = await Attendance.findOne({ student: student._id }).sort({ date: -1, createdAt: -1 });
      const attendanceInfo = {
        status: attendance?.status === 'present' ? 'Check-in Recorded (Present)' : (attendance?.status || 'Check-in Recorded'),
        time: attendance?.checkIn ? new Date(attendance.checkIn).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }),
        hoursStudied: attendance?.duration ? `${(attendance.duration / 60).toFixed(1)} hrs` : 'In Progress'
      };
      messageText = await WhatsAppService.getAttendanceAlertMessage(student, bizName, attendanceInfo, baseUrl);
    } else {
      return res.status(400).json({ success: false, message: `Unsupported reminder type: ${reminderType}` });
    }

    // Dispatch in-app notification & prepare click-to-chat URL
    const result = await WhatsAppService.dispatchReminder({
      student,
      message: messageText,
      type: normType,
      link: normType === 'balance_due' || normType === 'payment_receipt' ? '#/payments' : '#/students'
    });

    const whatsappUrl = WhatsAppService.getClickToChatUrl(student.phone, messageText);

    res.json({
      success: true,
      message: `${normType.replace('_', ' ').toUpperCase()} reminder generated successfully`,
      data: {
        studentId: student._id,
        studentName: student.name,
        phone: student.phone,
        formattedPhone: WhatsAppService.formatPhone(student.phone),
        reminderType: normType,
        messageText,
        upiLink,
        whatsappUrl
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/messages/run-cron-now - Immediately executes the daily subscription expiry and balance due check and dispatches WhatsApp messages
router.post('/run-cron-now', protect, roleCheck('owner'), async (req, res) => {
  try {
    const { checkStudentExpiries } = require('../utils/cronJobs');
    const result = await checkStudentExpiries({ isManual: true });

    res.json({
      success: true,
      message: `Automated WhatsApp Expiry & Dues Bot executed successfully (${result.expiryRemindersSent || 0} expiry alerts, ${result.balanceDueRemindersSent || 0} dues alerts dispatched)`,
      data: result
    });
  } catch (error) {
    console.error('Error executing automated bot now:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/messages/webhook - Meta WhatsApp Webhook challenge verification
router.get('/webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode && token) {
    if (mode === 'subscribe') {
      console.log('WhatsApp Webhook verified successfully');
      return res.status(200).send(challenge);
    } else {
      return res.sendStatus(403);
    }
  }
  res.json({ success: true, message: 'WhatsApp Webhook Endpoint Ready' });
});

// POST /api/messages/webhook - Receive incoming WhatsApp Webhook payloads and auto-reply using WhatsAppBot.processIncomingCommand()
router.post('/webhook', async (req, res) => {
  try {
    const SystemSetting = require('../models/SystemSetting');
    const WhatsAppBot = require('../utils/whatsappBot');

    const isBotEnabled = await SystemSetting.getSetting('notification.enableConversationalBot');
    if (isBotEnabled === false) {
      return res.status(200).json({
        success: false,
        message: 'WhatsApp Interactive Conversational Bot is currently disabled in settings.'
      });
    }

    let phone = req.body.phone || req.body.from || req.body.From || req.body.sender;
    let messageText = req.body.messageText || req.body.message || req.body.text || req.body.body || req.body.Body;

    // Fallback: parse Meta WhatsApp Cloud API payload format
    if (!phone && req.body.entry?.[0]?.changes?.[0]?.value?.messages?.[0]) {
      const msgObj = req.body.entry[0].changes[0].value.messages[0];
      phone = msgObj.from;
      messageText = msgObj.text?.body || msgObj.caption || '';
    }

    if (!phone || !messageText) {
      return res.status(400).json({
        success: false,
        message: 'Missing phone number or messageText payload'
      });
    }

    const result = await WhatsAppBot.processIncomingCommand({ phone, messageText });

    res.json({
      success: result.success,
      reply: result.reply,
      data: result
    });
  } catch (error) {
    console.error('WhatsApp Webhook processing error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;

