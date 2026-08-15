const cron = require('node-cron');
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
 */
async function checkStudentExpiries() {
  try {
    const now = new Date();
    const todayStart = new Date(new Date().setHours(0, 0, 0, 0));

    // Get system policy settings
    const graceDays = Number(await SystemSetting.getSetting('payment.gracePeriod') || 3);
    const lateFeeType = await SystemSetting.getSetting('payment.lateFeeType') || 'flat';
    const lateFeeAmount = Number(await SystemSetting.getSetting('payment.lateFeeAmount') || 50);
    const autoSuspendDays = Number(await SystemSetting.getSetting('payment.autoSuspendDays') || 7);

    // Find all active or grace_period students with an expiry date
    const students = await Student.find({
      status: { $in: ['active', 'grace_period'] },
      expiryDate: { $exists: true, $ne: null }
    }).populate('plan').populate('seat');

    for (const student of students) {
      const exp = new Date(student.expiryDate);
      const diffTime = exp.getTime() - now.getTime();
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

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
      // Case C: Expiring soon (1, 3, or 7 days prior)
      else if ([1, 3, 7].includes(diffDays)) {
        const title = `Membership Expiry Alert: ${student.name} (${diffDays}d left)`;
        const existingAlert = await Notification.findOne({
          title,
          createdAt: { $gte: todayStart }
        });

        if (!existingAlert) {
          await Notification.create({
            title,
            message: `${student.name}'s ${student.plan?.name || 'study'} plan will expire in ${diffDays} day(s) on ${exp.toLocaleDateString('en-IN')}.`,
            type: 'expiry',
            link: `#/payments`
          });
        }
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
      todayRevenue += (p.amountPaid || 0);
      if (p.paymentMode === 'upi') upiRevenue += (p.amountPaid || 0);
      else if (p.paymentMode === 'cash') cashRevenue += (p.amountPaid || 0);
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

  // Initial check on boot
  setTimeout(async () => {
    await checkStudentExpiries();
  }, 10000);

  console.log('  🕒 Automated Notification, Expiry & EOD Cron jobs scheduled');
}

module.exports = { initCronJobs, checkStudentExpiries, generateEODSummary };
