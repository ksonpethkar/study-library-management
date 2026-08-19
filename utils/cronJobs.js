const cron = require('node-cron');
const fs = require('fs');
const path = require('path');
const nodemailer = require('nodemailer');
const mongoose = require('mongoose');
const Student = require('../models/Student');
const Seat = require('../models/Seat');
const Payment = require('../models/Payment');
const Expense = require('../models/Expense');
const Attendance = require('../models/Attendance');
const Notification = require('../models/Notification');
const SystemSetting = require('../models/SystemSetting');
const BusinessProfile = require('../models/BusinessProfile');
const WhatsAppService = require('./whatsappService');

/**
 * Check student expiries, calculate late fees, and handle grace periods & seat releases
 * Dispatches automated 24h & 48h expiry reminders & overdue partial payment alerts with 1-tap UPI deep links
 */
async function checkStudentExpiries() {
  try {
    const now = new Date();
    const todayStart = new Date(new Date().setHours(0, 0, 0, 0));

    // Fetch Business Profile for UPI deep links & library branding
    const profile = await BusinessProfile.getProfile();
    const upiId = profile?.upiId || '';
    const bizName = profile?.businessName || 'Study Library';

    // Get system policy settings
    const graceDays = Number(await SystemSetting.getSetting('payment.gracePeriod') || 3);
    const lateFeeType = await SystemSetting.getSetting('payment.lateFeeType') || 'flat';
    const lateFeeAmount = Number(await SystemSetting.getSetting('payment.lateFeeAmount') || 50);
    const autoSuspendDays = Number(await SystemSetting.getSetting('payment.autoSuspendDays') || 7);

    // Find all active or grace_period students with an expiry date
    const students = await Student.find({
      status: { $in: ['active', 'grace_period'] },
      $or: [
        { expiryDate: { $exists: true, $ne: null } },
        { planExpiresAt: { $exists: true, $ne: null } }
      ]
    }).populate('plan').populate('seat').populate('shift');

    for (const student of students) {
      const expDate = student.expiryDate || student.planExpiresAt;
      const exp = new Date(expDate);
      const diffTime = exp.getTime() - now.getTime();
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      const diffHours = Math.round(diffTime / (1000 * 60 * 60));

      // Case A: Expired beyond Grace Period -> Release Seat & Apply Late Fine
      if (diffDays <= -graceDays) {
        student.status = 'expired';
        
        // Calculate late fee
        const overdueDays = Math.abs(diffDays);
        let fine = 0;
        if (lateFeeType === 'per_day') {
          fine = overdueDays * lateFeeAmount;
        } else {
          fine = lateFeeAmount;
        }
        student.pendingFine = fine;
        await student.save({ validateBeforeSave: false });

        // Release seat if occupied
        if (student.seat) {
          await Seat.findByIdAndUpdate(student.seat._id || student.seat, {
            status: 'available',
            currentStudent: null
          });
        }

        // Avoid duplicate notification today
        const existingNotif = await Notification.findOne({
          type: 'expiry',
          title: `Seat Released: ${student.name}`,
          createdAt: { $gte: todayStart }
        });

        if (!existingNotif) {
          await Notification.create({
            title: `Seat Released: ${student.name}`,
            message: `${student.name}'s grace period exceeded by ${overdueDays} days. Seat ${student.seat?.seatNumber || ''} has been released. Late fine applied: ₹${fine}.`,
            type: 'expiry',
            link: `#/students`
          });
        }
      } 
      // Case B: Expired but within Grace Period
      else if (diffDays <= 0 && diffDays > -graceDays) {
        student.status = 'grace_period';
        await student.save({ validateBeforeSave: false });

        const existingGrace = await Notification.findOne({
          title: `Grace Period: ${student.name}`,
          createdAt: { $gte: todayStart }
        });

        if (!existingGrace) {
          await Notification.create({
            title: `Grace Period: ${student.name}`,
            message: `${student.name}'s plan expired on ${exp.toLocaleDateString('en-IN')}. Currently in ${graceDays}-day grace period before seat release.`,
            type: 'expiry',
            link: `#/payments`
          });
        }
      }
      // Case C: Expiring soon (24 hours / 48 hours / 1, 2, 3, 7 days prior)
      else if ([1, 2, 3, 7].includes(diffDays) || (diffHours > 0 && diffHours <= 48)) {
        const timeLabel = diffDays === 1 || diffHours <= 24 ? '24 hours' : (diffDays === 2 || diffHours <= 48 ? '48 hours' : `${diffDays} days`);
        const title = `Membership Expiry Alert: ${student.name} (${timeLabel} left)`;
        
        const existingAlert = await Notification.findOne({
          title,
          createdAt: { $gte: todayStart }
        });

        if (!existingAlert) {
          const renewalAmount = student.plan?.price || 0;
          const upiLink = upiId ? WhatsAppService.generateUpiDeepLink({
            upiId,
            businessName: bizName,
            amount: renewalAmount,
            note: 'SubscriptionRenewal'
          }) : '';

          const waMessage = await WhatsAppService.getExpiryReminderMessage(
            student,
            timeLabel,
            bizName,
            upiId,
            renewalAmount,
            upiLink
          );

          // Dispatch reminder via WhatsApp Service and Notification model
          await WhatsAppService.dispatchReminder({
            student,
            message: waMessage,
            type: 'expiry',
            link: '#/students'
          });

          await Notification.create({
            title,
            message: `${student.name}'s ${student.plan?.name || 'study'} plan will expire in ${timeLabel} on ${exp.toLocaleDateString('en-IN')}. Automated reminder dispatched.`,
            type: 'expiry',
            link: `#/payments`
          });
        }
      }
    }

    // Check overdue partial payment balances (balanceDue > 0 and past dueDate)
    const overduePayments = await Payment.find({
      balanceDue: { $gt: 0 },
      dueDate: { $lte: now },
      status: { $in: ['partial', 'pending'] }
    }).populate('student').populate('plan');

    for (const p of overduePayments) {
      if (!p.student) continue;
      const student = p.student;
      const balanceAmt = p.balanceDue;
      const overdueTitle = `⚠️ Overdue Balance Alert: ${student.name} (₹${balanceAmt})`;

      const existingDueNotif = await Notification.findOne({
        title: overdueTitle,
        createdAt: { $gte: todayStart }
      });

      if (!existingDueNotif) {
        const upiLink = upiId ? WhatsAppService.generateUpiDeepLink({
          upiId,
          businessName: bizName,
          amount: balanceAmt,
          note: 'PartialPaymentBalance'
        }) : '';

        const waMsg = await WhatsAppService.getPartialBalanceReminderMessage(
          student,
          p,
          bizName,
          upiId,
          upiLink
        );

        await WhatsAppService.dispatchReminder({
          student,
          message: waMsg,
          type: 'partial_balance',
          link: '#/payments'
        });

        await Notification.create({
          title: overdueTitle,
          message: `${student.name} has an overdue balance of ₹${balanceAmt} (Due: ${new Date(p.dueDate).toLocaleDateString('en-IN')}). WhatsApp reminder link prepared.`,
          type: 'payment',
          link: '#/payments'
        });
      }
    }
  } catch (error) {
    console.error('Error during student expiry cron job:', error.message);
  }
}

/**
 * Generate and broadcast daily End-of-Day (EOD) financial and operational summary
 */
async function generateEODSummary() {
  try {
    const todayStart = new Date(new Date().setHours(0, 0, 0, 0));
    const todayEnd = new Date(new Date().setHours(23, 59, 59, 999));
    const threeDaysLater = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);

    const [paymentsToday, expensesToday, newAdmissions, attendanceToday, activeCount, expiringSoon, overdueCount, profile] = await Promise.all([
      Payment.find({ paymentDate: { $gte: todayStart, $lte: todayEnd } }),
      Expense.find({ date: { $gte: todayStart, $lte: todayEnd } }),
      Student.countDocuments({ createdAt: { $gte: todayStart, $lte: todayEnd } }),
      Attendance.countDocuments({ date: { $gte: todayStart, $lte: todayEnd } }),
      Student.countDocuments({ status: 'active' }),
      Student.countDocuments({ status: 'active', expiryDate: { $gte: todayStart, $lte: threeDaysLater } }),
      Student.countDocuments({ status: { $in: ['expired', 'grace_period'] } }),
      BusinessProfile.getProfile()
    ]);

    let todayRevenue = 0;
    let upiRevenue = 0;
    let cashRevenue = 0;
    paymentsToday.forEach(p => {
      const amt = (p.finalAmount !== undefined ? p.finalAmount : p.amount || 0);
      const mode = (p.paymentMethod || 'cash');
      todayRevenue += amt;
      if (mode === 'upi') upiRevenue += amt;
      else if (mode === 'cash') cashRevenue += amt;
    });

    let todayExpenses = 0;
    expensesToday.forEach(e => {
      todayExpenses += (e.amount || 0);
    });

    const summaryData = {
      todayRevenue,
      upiRevenue,
      cashRevenue,
      todayExpenses,
      netCashFlow: todayRevenue - todayExpenses,
      newAdmissionsCount: newAdmissions,
      activeStudentsCount: activeCount,
      todayAttendanceCount: attendanceToday,
      expiringSoonCount: expiringSoon,
      overdueCount
    };

    // Store in-app notification for owner
    await Notification.create({
      title: `📊 Daily Business Summary: ₹${todayRevenue.toLocaleString('en-IN')}`,
      message: `Total Collections: ₹${todayRevenue.toLocaleString('en-IN')} | Expenses: ₹${todayExpenses.toLocaleString('en-IN')} | Attendance: ${attendanceToday} students.`,
      type: 'system',
      link: '#/reports'
    });

    return summaryData;
  } catch (err) {
    console.error('Error generating EOD summary:', err.message);
    return null;
  }
}

async function performDatabaseBackup() {
  try {
    const backupDir = path.join(__dirname, '../backups');
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir, { recursive: true });
    }

    const files = fs.readdirSync(backupDir);
    const now = Date.now();
    files.forEach(file => {
      const filePath = path.join(backupDir, file);
      const stats = fs.statSync(filePath);
      if (now - stats.mtime.getTime() > 7 * 24 * 60 * 60 * 1000) {
        fs.unlinkSync(filePath);
      }
    });

    const dbName = mongoose.connection.name || 'library';
    const dateStr = new Date().toISOString().replace(/[:.]/g, '-');
    const backupFile = path.join(backupDir, `backup-${dbName}-${dateStr}.json`);

    const collections = mongoose.connection.collections;
    const backupData = {};
    for (const [name, collection] of Object.entries(collections)) {
      backupData[name] = await collection.find({}).toArray();
    }
    
    fs.writeFileSync(backupFile, JSON.stringify(backupData, null, 2));
    console.log(`✅ Backup created successfully: ${backupFile}`);

    if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASS
        }
      });
      
      const profile = await BusinessProfile.findOne({});
      const toEmail = profile?.email || process.env.EMAIL_USER;

      await transporter.sendMail({
        from: process.env.EMAIL_USER,
        to: toEmail,
        subject: `Daily Database Backup - ${dbName}`,
        text: 'Please find the daily automated database backup attached.',
        attachments: [{ filename: path.basename(backupFile), path: backupFile }]
      });
      console.log(`📧 Backup emailed to ${toEmail}`);
    }
  } catch (error) {
    console.error('❌ Database Backup Failed:', error.message);
  }
}

/**
 * Daily Auto Attendance Reconciliation
 * Finds all open attendance records (checked in today but missing checkout)
 * Closes them with duration calculated, ensuring accurate attendance logs.
 */
async function reconcileDailyAttendance() {
  try {
    const todayStart = new Date(new Date().setHours(0, 0, 0, 0));
    const todayEnd = new Date(new Date().setHours(23, 59, 59, 999));

    // Find all attendance records today where checkIn is present but checkOut is null
    const openRecords = await Attendance.find({
      date: { $gte: todayStart, $lte: todayEnd },
      checkIn: { $exists: true, $ne: null },
      checkOut: { $in: [null, undefined] }
    }).populate('student');

    let reconciledCount = 0;
    const autoCloseTime = new Date();

    for (const record of openRecords) {
      record.checkOut = autoCloseTime;
      const diffMs = autoCloseTime.getTime() - new Date(record.checkIn).getTime();
      record.duration = Math.max(0, Math.round(diffMs / (1000 * 60)));
      record.notes = (record.notes ? `${record.notes} | ` : '') + 'Auto-closed by end-of-day reconciliation';
      await record.save();
      reconciledCount++;
    }

    if (reconciledCount > 0) {
      console.log(`✅ Auto Attendance Reconciliation: Closed ${reconciledCount} open check-ins.`);
      await Notification.create({
        title: '⏱️ Daily Attendance Reconciled',
        message: `Automated EOD reconciliation closed ${reconciledCount} open student attendance sessions.`,
        type: 'attendance',
        link: '#/attendance'
      });
    }

    return reconciledCount;
  } catch (error) {
    console.error('Error during auto attendance reconciliation:', error.message);
    return 0;
  }
}

function initCronJobs() {
  // Midnight Cron (00:00) — Expiry, Grace Period & Late Fine Check
  cron.schedule('0 0 * * *', async () => {
    console.log('⏰ Running midnight membership expiry & notification check...');
    await checkStudentExpiries();
  });

  // End-of-Day Cron (22:00 / 10:00 PM) — Daily Business & Revenue Summary
  cron.schedule('0 22 * * *', async () => {
    console.log('📊 Running 10:00 PM End-of-Day Summary computation...');
    await generateEODSummary();
  });

  // Auto Attendance Reconciliation (23:55 daily)
  cron.schedule('55 23 * * *', async () => {
    console.log('⏱️ Running 23:55 Auto Attendance Reconciliation...');
    await reconcileDailyAttendance();
  });

  // Database Backup Cron (03:00 AM)
  cron.schedule('0 3 * * *', async () => {
    console.log('💾 Running 03:00 AM Database Backup...');
    await performDatabaseBackup();
  });

  // Keep-Alive Self-Ping Cron (Every 10 Minutes) — Prevents Render.com Cold Starts
  cron.schedule('*/10 * * * *', async () => {
    try {
      const liveUrl = process.env.LIVE_URL || 'https://study-library-management.onrender.com';
      const protocol = liveUrl.startsWith('https') ? require('https') : require('http');
      protocol.get(`${liveUrl}/api/health`, (res) => {
        console.log(`💓 Render Keep-Alive Ping Status: ${res.statusCode}`);
      }).on('error', () => {});
    } catch (e) {}
  });

  // Initial check on boot
  setTimeout(async () => {
    await checkStudentExpiries();
  }, 10000);

  console.log('  🕒 Automated Notification, Expiry, Keep-Alive, EOD & Reconciliation Cron jobs scheduled');
}

module.exports = { initCronJobs, checkStudentExpiries, generateEODSummary, reconcileDailyAttendance, performDatabaseBackup };
