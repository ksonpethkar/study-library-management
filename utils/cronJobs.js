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
 * Dispatches automated WhatsApp expiry reminders & overdue balance due alerts with 1-tap UPI deep links
 * Supports user-configured dispatch schedule times & reminder day intervals
 */
async function checkStudentExpiries(options = {}) {
  const isManual = Boolean(options.isManual);
  const executionLogs = [];
  let expiryRemindersSent = 0;
  let balanceDueRemindersSent = 0;
  let seatsReleased = 0;
  let gracePeriodCount = 0;

  try {
    const now = new Date();
    const todayStart = new Date(new Date().setHours(0, 0, 0, 0));
    const todayMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // Fetch Business Profile for UPI deep links & library branding
    const profile = await BusinessProfile.getProfile();
    const upiId = profile?.upiId || '';
    const bizName = profile?.businessName || 'Study Library';

    // Get system policy & notification schedule settings
    const graceDays = Number(await SystemSetting.getSetting('payment.gracePeriod') ?? 3);
    const lateFeeType = (await SystemSetting.getSetting('payment.lateFeeType')) || 'flat';
    const lateFeeAmount = Number(await SystemSetting.getSetting('payment.lateFeeAmount') ?? 50);

    // Dynamic WhatsApp Automated Schedule Settings
    const scheduleTime = (await SystemSetting.getSetting('notification.whatsappScheduleTime')) || '09:30';
    const enableAutoExpiryBot = (await SystemSetting.getSetting('notification.enableAutoExpiryBot')) !== false;
    const enableAutoDuesBot = (await SystemSetting.getSetting('notification.enableAutoDuesBot')) !== false;

    let rawExpiryDays = await SystemSetting.getSetting('notification.expiryReminderDays');
    let rawBalanceDays = await SystemSetting.getSetting('notification.balanceReminderDays');

    // Default intervals if not configured
    let expiryReminderDays = [7, 3, 1, 0];
    if (Array.isArray(rawExpiryDays) && rawExpiryDays.length > 0) {
      expiryReminderDays = rawExpiryDays.map(Number).filter(n => !isNaN(n));
    } else if (typeof rawExpiryDays === 'string') {
      try {
        expiryReminderDays = JSON.parse(rawExpiryDays).map(Number).filter(n => !isNaN(n));
      } catch {
        expiryReminderDays = rawExpiryDays.split(',').map(s => Number(s.trim())).filter(n => !isNaN(n));
      }
    }

    let balanceReminderDays = [7, 3, 1];
    if (Array.isArray(rawBalanceDays) && rawBalanceDays.length > 0) {
      balanceReminderDays = rawBalanceDays.map(Number).filter(n => !isNaN(n));
    } else if (typeof rawBalanceDays === 'string') {
      try {
        balanceReminderDays = JSON.parse(rawBalanceDays).map(Number).filter(n => !isNaN(n));
      } catch {
        balanceReminderDays = rawBalanceDays.split(',').map(s => Number(s.trim())).filter(n => !isNaN(n));
      }
    }

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

      // Exact Calendar-Day Difference (Midnight to Midnight)
      const expMidnight = new Date(exp.getFullYear(), exp.getMonth(), exp.getDate());
      const diffDays = Math.round((expMidnight.getTime() - todayMidnight.getTime()) / (1000 * 60 * 60 * 24));
      const diffHours = Math.round((exp.getTime() - now.getTime()) / (1000 * 60 * 60));

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
        seatsReleased++;

        // Avoid duplicate notification today
        const existingNotif = await Notification.findOne({
          type: 'expiry',
          title: `Seat Released: ${student.name}`,
          createdAt: { $gte: todayStart }
        });

        if (!existingNotif || isManual) {
          await Notification.create({
            title: `Seat Released: ${student.name}`,
            message: `${student.name}'s grace period exceeded by ${overdueDays} days. Seat ${student.seat?.seatNumber || ''} has been released. Late fine applied: ₹${fine}.`,
            type: 'expiry',
            targetRole: 'admin',
            student: student._id,
            link: `#/students`
          });
        }

        executionLogs.push({
          type: 'seat_release',
          studentName: student.name,
          phone: student.phone,
          seatNumber: student.seat?.seatNumber || 'N/A',
          detail: `Grace period exceeded by ${overdueDays}d. Seat released, fine ₹${fine}`,
          status: 'released'
        });
      } 
      // Case B: Expired but within Grace Period
      else if (diffDays <= 0 && diffDays > -graceDays) {
        student.status = 'grace_period';
        await student.save({ validateBeforeSave: false });
        gracePeriodCount++;

        const existingGrace = await Notification.findOne({
          title: `Grace Period: ${student.name}`,
          createdAt: { $gte: todayStart }
        });

        if (!existingGrace || isManual) {
          await Notification.create({
            title: `Grace Period: ${student.name}`,
            message: `${student.name}'s plan expired on ${exp.toLocaleDateString('en-IN')}. Currently in ${graceDays}-day grace period before seat release.`,
            type: 'expiry',
            targetRole: 'admin',
            student: student._id,
            link: `#/payments`
          });
        }

        executionLogs.push({
          type: 'grace_period',
          studentName: student.name,
          phone: student.phone,
          seatNumber: student.seat?.seatNumber || 'N/A',
          detail: `Expired on ${exp.toLocaleDateString('en-IN')}. In ${graceDays}-day grace period.`,
          status: 'grace_active'
        });
      }

      // Case C: Expiry Reminder WhatsApp Dispatch
      if (enableAutoExpiryBot) {
        const isMatchedDay = expiryReminderDays.includes(diffDays) || (diffDays === 0 && expiryReminderDays.includes(0));
        const isWithin24Hours = (diffHours > 0 && diffHours <= 24 && (expiryReminderDays.includes(1) || expiryReminderDays.includes(0)));

        if (isMatchedDay || isWithin24Hours || (isManual && diffDays <= 7 && diffDays >= 0)) {
          let timeLabel = '';
          if (diffDays <= 0) timeLabel = 'TODAY (Expires / Expired Today)';
          else if (diffDays === 1 || diffHours <= 24) timeLabel = '24 hours (Tomorrow)';
          else if (diffDays === 2 || diffHours <= 48) timeLabel = '48 hours (2 Days)';
          else timeLabel = `${diffDays} days`;

          const title = `Membership Expiry Alert: ${student.name} (${timeLabel})`;
          
          const existingAlert = await Notification.findOne({
            $or: [
              { title },
              { title: `📲 WhatsApp Reminder: ${student.name}`, createdAt: { $gte: todayStart } }
            ],
            createdAt: { $gte: todayStart }
          });

          if (!existingAlert || isManual) {
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
            const dispatchRes = await WhatsAppService.dispatchReminder({
              student,
              message: waMessage,
              type: 'expiry',
              link: '#/students'
            });

            await Notification.create({
              title,
              message: `${student.name}'s ${student.plan?.name || 'study'} plan expires in ${timeLabel} on ${exp.toLocaleDateString('en-IN')}. Automated WhatsApp reminder link prepared.`,
              type: 'expiry',
              targetRole: 'admin',
              student: student._id,
              link: `#/payments`
            });

            expiryRemindersSent++;
            executionLogs.push({
              type: 'expiry_reminder',
              studentName: student.name,
              phone: student.phone,
              seatNumber: student.seat?.seatNumber || 'N/A',
              planName: student.plan?.name || 'Standard',
              daysLeft: diffDays,
              timeLabel,
              amount: renewalAmount,
              whatsappUrl: dispatchRes.whatsappUrl,
              status: 'dispatched'
            });
          }
        }
      }
    }

    // Check overdue partial payment balances (balanceDue > 0)
    if (enableAutoDuesBot) {
      const overduePayments = await Payment.find({
        balanceDue: { $gt: 0 },
        status: { $in: ['partial', 'pending'] }
      }).populate('student').populate('plan');

      for (const p of overduePayments) {
        if (!p.student) continue;
        const student = p.student;
        const balanceAmt = p.balanceDue;
        const dueDate = p.dueDate ? new Date(p.dueDate) : new Date(p.createdAt || Date.now());
        const dueMidnight = new Date(dueDate.getFullYear(), dueDate.getMonth(), dueDate.getDate());
        const overdueDays = Math.round((todayMidnight.getTime() - dueMidnight.getTime()) / (1000 * 60 * 60 * 24));

        const isMatchedDueDay = isManual || balanceReminderDays.includes(overdueDays) || (overdueDays === 0 && balanceReminderDays.includes(0)) || (overdueDays > 0 && balanceReminderDays.length === 0);

        if (isMatchedDueDay) {
          const overdueTitle = `⚠️ Overdue Balance Alert: ${student.name} (₹${balanceAmt})`;

          const existingDueNotif = await Notification.findOne({
            $or: [
              { title: overdueTitle },
              { title: `📲 WhatsApp Reminder: ${student.name}`, createdAt: { $gte: todayStart } }
            ],
            createdAt: { $gte: todayStart }
          });

          if (!existingDueNotif || isManual) {
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

            const dispatchRes = await WhatsAppService.dispatchReminder({
              student,
              message: waMsg,
              type: 'partial_balance',
              link: '#/payments'
            });

            await Notification.create({
              title: overdueTitle,
              message: `${student.name} has an overdue balance of ₹${balanceAmt} (${overdueDays > 0 ? `${overdueDays} days overdue` : 'Due today'}). Automated WhatsApp alert link prepared.`,
              type: 'payment',
              targetRole: 'admin',
              student: student._id,
              link: '#/payments'
            });

            balanceDueRemindersSent++;
            executionLogs.push({
              type: 'balance_due_reminder',
              studentName: student.name,
              phone: student.phone,
              balanceDue: balanceAmt,
              overdueDays,
              whatsappUrl: dispatchRes.whatsappUrl,
              status: 'dispatched'
            });
          }
        }
      }
    }

    const summary = {
      success: true,
      timestamp: new Date().toISOString(),
      scheduleTime,
      enableAutoExpiryBot,
      enableAutoDuesBot,
      expiryReminderDays,
      balanceReminderDays,
      totalStudentsScanned: students.length,
      expiryRemindersSent,
      balanceDueRemindersSent,
      seatsReleased,
      gracePeriodCount,
      logs: executionLogs
    };

    console.log(`✅ [Automated WhatsApp Cron Engine] Completed. Scanned: ${students.length}, Expiry Reminders: ${expiryRemindersSent}, Dues Reminders: ${balanceDueRemindersSent}, Seats Released: ${seatsReleased}`);
    return summary;
  } catch (error) {
    console.error('Error during student expiry cron job:', error.message);
    return {
      success: false,
      error: error.message,
      totalStudentsScanned: 0,
      expiryRemindersSent,
      balanceDueRemindersSent,
      logs: executionLogs
    };
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
      targetRole: 'admin',
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
        targetRole: 'admin',
        link: '#/attendance'
      });
    }

    return reconciledCount;
  } catch (error) {
    console.error('Error during auto attendance reconciliation:', error.message);
    return 0;
  }
}

// ── Phase 6: Weekly Behavior Score Batch Computation ────────────────────────
async function computeWeeklyBehaviorScores() {
  try {
    const Student = require('../models/Student');
    const Attendance = require('../models/Attendance');

    const students = await Student.find({ status: 'active' })
      .select('_id studyStreakDays').lean();

    let updated = 0;
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    for (const stu of students) {
      try {
        // Streak from last consecutive present days
        const recentAtt = await Attendance.find({ student: stu._id })
          .sort({ date: -1 }).limit(60).select('date status').lean();
        let streak = 0;
        const todayStr = new Date().toISOString().slice(0, 10);
        for (const rec of recentAtt) {
          const dateStr = new Date(rec.date).toISOString().slice(0, 10);
          if (dateStr > todayStr) continue;
          if (['present', 'late', 'half_day'].includes(rec.status)) streak++;
          else break;
        }

        // Update studyStreakDays on student document
        await Student.findByIdAndUpdate(stu._id, { $set: { studyStreakDays: streak } });
        updated++;
      } catch (stuErr) {
        // Skip individual student errors — don't break the batch
      }
    }

    console.log(`🧠 [BehaviorScore] Updated streaks for ${updated}/${students.length} active students`);
    return updated;
  } catch (error) {
    console.error('Error in computeWeeklyBehaviorScores:', error.message);
    return 0;
  }
}

// ── Phase 6: Monthly At-Risk Student Digest ──────────────────────────────────
async function generateAtRiskDigest() {
  try {
    const Student = require('../models/Student');
    const Attendance = require('../models/Attendance');

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const activeStudents = await Student.find({ status: 'active' })
      .select('_id name phone studyStreakDays shift')
      .lean();

    const atRisk = [];

    for (const stu of activeStudents) {
      const attRecords = await Attendance.find({
        student: stu._id,
        date: { $gte: thirtyDaysAgo }
      }).select('status').lean();

      const presentCount = attRecords.filter(r =>
        ['present', 'late', 'half_day'].includes(r.status)
      ).length;
      const attPct = Math.round((presentCount / 30) * 100);

      // Flag as at-risk if attendance < 40% in last 30 days
      if (attPct < 40) {
        atRisk.push({
          name: stu.name,
          phone: stu.phone,
          attPct,
          streak: stu.studyStreakDays || 0,
          shift: stu.shift || 'N/A'
        });
      }
    }

    console.log(`⚠️ [AtRiskDigest] Found ${atRisk.length} at-risk students (attendance < 40% in last 30 days):`);
    atRisk.slice(0, 20).forEach(s => {
      console.log(`   • ${s.name} | ${s.attPct}% attendance | Streak: ${s.streak} days | Shift: ${s.shift}`);
    });

    return atRisk;
  } catch (error) {
    console.error('Error in generateAtRiskDigest:', error.message);
    return [];
  }
}

function initCronJobs() {
  // Dynamic Automated WhatsApp Dispatch Engine (Checks configured notification.whatsappScheduleTime every minute)
  let lastDispatchedMinuteKey = '';
  cron.schedule('* * * * *', async () => {
    try {
      const scheduleTime = (await SystemSetting.getSetting('notification.whatsappScheduleTime')) || '09:30';
      const timezone = (await SystemSetting.getSetting('general.timezone')) || 'Asia/Kolkata';

      const now = new Date();
      // Format current time in 24-hour HH:mm
      const formatter = new Intl.DateTimeFormat('en-GB', {
        timeZone: timezone,
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      });
      const currentTimeStr = formatter.format(now).trim();
      const dateKey = now.toISOString().split('T')[0];
      const minuteKey = `${dateKey}_${currentTimeStr}`;

      if (currentTimeStr === scheduleTime && lastDispatchedMinuteKey !== minuteKey) {
        lastDispatchedMinuteKey = minuteKey;
        console.log(`⏰ [${currentTimeStr} ${timezone}] Triggering Daily Scheduled Automated WhatsApp Dispatch Engine...`);
        await checkStudentExpiries();
      }
    } catch (scheduleErr) {
      console.error('Error during WhatsApp minute schedule check:', scheduleErr.message);
    }
  });

  // Hourly Auto-Reminder Health & Catch-Up Check (Runs at minute 05 of every hour)
  cron.schedule('5 * * * *', async () => {
    try {
      await checkStudentExpiries();
    } catch (e) {
      console.error('Error during hourly reminder catch-up:', e.message);
    }
  });

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

  // ── Phase 6: Weekly Behavior Score Computation (Every Monday 06:00 AM) ────
  // Batch-computes behavior scores for all active students and updates their
  // studyStreakDays field. Cheap aggregation query — runs once a week.
  cron.schedule('0 6 * * 1', async () => {
    console.log('🧠 [BehaviorScore] Weekly batch computation starting...');
    await computeWeeklyBehaviorScores();
  });

  // ── Phase 6: Monthly At-Risk Digest (1st of Every Month 08:00 AM) ─────────
  // Identifies students with behavior score < 50 and logs/alerts for admin review.
  cron.schedule('0 8 1 * *', async () => {
    console.log('⚠️ [AtRiskDigest] Monthly at-risk student digest starting...');
    await generateAtRiskDigest();
  });

  // Initial check on boot
  setTimeout(async () => {
    await checkStudentExpiries();
  }, 10000);

  console.log('  🕒 Automated WhatsApp Dispatch Engine, Expiry, Keep-Alive, EOD, Reconciliation, BehaviorScore & AtRisk Cron jobs scheduled');
}

module.exports = { initCronJobs, checkStudentExpiries, generateEODSummary, reconcileDailyAttendance, performDatabaseBackup, computeWeeklyBehaviorScores, generateAtRiskDigest };

