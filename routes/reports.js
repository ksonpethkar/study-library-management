const express = require('express');
const router = express.Router();
const { query } = require('express-validator');
const { protect } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const Payment = require('../models/Payment');
const Student = require('../models/Student');
const Attendance = require('../models/Attendance');
const Plan = require('../models/Plan');
const Seat = require('../models/Seat');
const Expense = require('../models/Expense');

// Protect all report endpoints
router.use(protect);

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

router.use(roleCheck('owner', 'branch_manager'));

/**
 * Helper to escape and format CSV field
 */
function escapeCSV(val) {
  if (val === null || val === undefined) return '""';
  const str = String(val).replace(/"/g, '""');
  return `"${str}"`;
}

/**
 * Helper to generate CSV string from rows
 */
function generateCSV(headers, rows) {
  const headerLine = headers.map(h => escapeCSV(h.label || h.key || h)).join(',');
  const rowLines = rows.map(row => {
    return headers.map(h => {
      const val = typeof h.formatter === 'function' ? h.formatter(row[h.key], row) : row[h.key];
      return escapeCSV(val);
    }).join(',');
  });
  return [headerLine, ...rowLines].join('\r\n');
}

/**
 * Helper to parse date range or provide default past 30 days
 */
function parseDateRange(start, end, defaultDays = 30) {
  let startDate, endDate;
  const now = new Date();

  if (end) {
    endDate = new Date(end);
    endDate.setHours(23, 59, 59, 999);
  } else {
    endDate = new Date(now);
    endDate.setHours(23, 59, 59, 999);
  }

  if (start) {
    startDate = new Date(start);
    startDate.setHours(0, 0, 0, 0);
  } else {
    startDate = new Date(endDate);
    startDate.setDate(startDate.getDate() - defaultDays + 1);
    startDate.setHours(0, 0, 0, 0);
  }

  return { startDate, endDate };
}

/**
 * GET /api/reports/overview
 * High-level summary totals: total revenue, active students, attendance logs, upcoming expiries
 */
router.get('/overview', async (req, res) => {
  try {
    const { startDate: qStart, endDate: qEnd } = req.query;
    const { startDate, endDate } = parseDateRange(qStart, qEnd, 30);

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date();
    todayEnd.setHours(23, 59, 59, 999);

    const monthStart = new Date(todayStart.getFullYear(), todayStart.getMonth(), 1);
    const in30Days = new Date(todayStart);
    in30Days.setDate(in30Days.getDate() + 30);

    const [
      allTimeRevenueAgg,
      periodRevenueAgg,
      monthRevenueAgg,
      totalStudents,
      activeStudents,
      inactiveStudents,
      expiredStudents,
      totalAttendanceLogs,
      todayAttendanceRecords,
      upcomingExpiriesCount,
      pendingDuesStudents,
      pendingPaymentsAgg
    ] = await Promise.all([
      // All time revenue
      Payment.aggregate([
        { $match: { status: 'paid', isDeleted: { $ne: true } } },
        { $group: { _id: null, total: { $sum: '$finalAmount' }, count: { $sum: 1 } } }
      ]),
      // Period revenue
      Payment.aggregate([
        { $match: { paymentDate: { $gte: startDate, $lte: endDate }, status: 'paid', isDeleted: { $ne: true } } },
        { $group: { _id: null, total: { $sum: '$finalAmount' }, count: { $sum: 1 } } }
      ]),
      // Current month revenue
      Payment.aggregate([
        { $match: { paymentDate: { $gte: monthStart, $lte: todayEnd }, status: 'paid', isDeleted: { $ne: true } } },
        { $group: { _id: null, total: { $sum: '$finalAmount' } } }
      ]),
      // Total students
      Student.countDocuments({ isDeleted: { $ne: true } }),
      // Active students
      Student.countDocuments({ status: 'active', isDeleted: { $ne: true } }),
      // Inactive students
      Student.countDocuments({ status: 'inactive', isDeleted: { $ne: true } }),
      // Expired students
      Student.countDocuments({ status: 'expired', isDeleted: { $ne: true } }),
      // Total attendance logs
      Attendance.countDocuments(),
      // Today's attendance
      Attendance.find({ date: { $gte: todayStart, $lte: todayEnd } }).lean(),
      // Expiring in next 30 days
      Student.countDocuments({
        expiryDate: { $gte: todayStart, $lte: in30Days },
        status: { $in: ['active', 'expired'] },
        isDeleted: { $ne: true }
      }),
      // Students with expired date (dues)
      Student.countDocuments({
        expiryDate: { $lt: todayStart },
        isDeleted: { $ne: true }
      }),
      // Pending/partial payment dues amount
      Payment.aggregate([
        { $match: { status: { $in: ['pending', 'partial'] }, isDeleted: { $ne: true } } },
        { $group: { _id: null, total: { $sum: '$finalAmount' }, count: { $sum: 1 } } }
      ])
    ]);

    const totalRevenue = allTimeRevenueAgg[0]?.total || 0;
    const periodRevenue = periodRevenueAgg[0]?.total || 0;
    const periodTransactions = periodRevenueAgg[0]?.count || 0;
    const monthRevenue = monthRevenueAgg[0]?.total || 0;

    const todayPresent = todayAttendanceRecords.filter(r => ['present', 'late', 'half_day'].includes(r.status)).length;
    const todayCheckedInNow = todayAttendanceRecords.filter(r => r.checkIn && !r.checkOut).length;

    // Calculate renewal rate: active students / total students * 100
    const renewalRate = totalStudents > 0 ? Math.round((activeStudents / totalStudents) * 100) : 100;

    res.json({
      success: true,
      data: {
        totalRevenue,
        periodRevenue,
        periodTransactions,
        monthRevenue,
        totalStudents,
        totalActiveStudents: activeStudents,
        totalInactiveStudents: inactiveStudents,
        totalExpiredStudents: expiredStudents,
        totalAttendanceLogs,
        todayAttendanceCount: todayPresent,
        todayCurrentlyInside: todayCheckedInNow,
        upcomingExpiries: upcomingExpiriesCount,
        pendingDuesCount: pendingDuesStudents,
        pendingPaymentsAmount: pendingPaymentsAgg[0]?.total || 0,
        renewalRate,
        period: {
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString()
        }
      },
      message: 'Overview analytics fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/reports/revenue
 * Revenue analytics: group payments by date/month, breakdown by payment method & plan breakdown
 */
router.get('/revenue', async (req, res) => {
  try {
    const { startDate: qStart, endDate: qEnd, groupBy = 'day' } = req.query;
    const { startDate, endDate } = parseDateRange(qStart, qEnd, 30);

    // 1. Trend analysis (daily or monthly)
    const paymentsInPeriod = await Payment.find({
      paymentDate: { $gte: startDate, $lte: endDate },
      status: 'paid',
      isDeleted: { $ne: true }
    })
      .populate('student', 'name studentId phone email')
      .populate('plan', 'name price duration durationType')
      .populate('collectedBy', 'name')
      .sort({ paymentDate: 1 })
      .lean();

    // Grouping by date
    const dateMap = {};
    const curr = new Date(startDate);
    while (curr <= endDate) {
      const key = curr.toISOString().split('T')[0];
      dateMap[key] = { date: key, amount: 0, count: 0 };
      curr.setDate(curr.getDate() + 1);
    }

    let totalRevenue = 0;
    const methodCounts = {
      cash: { amount: 0, count: 0 },
      upi: { amount: 0, count: 0 },
      bank_transfer: { amount: 0, count: 0 },
      card: { amount: 0, count: 0 },
      other: { amount: 0, count: 0 }
    };

    const planMap = {};

    paymentsInPeriod.forEach(p => {
      const amt = Number(p.finalAmount || p.amount || 0);
      totalRevenue += amt;

      // Date trend
      const dateKey = new Date(p.paymentDate).toISOString().split('T')[0];
      if (dateMap[dateKey]) {
        dateMap[dateKey].amount += amt;
        dateMap[dateKey].count += 1;
      } else {
        dateMap[dateKey] = { date: dateKey, amount: amt, count: 1 };
      }

      // Method breakdown
      const m = p.paymentMethod || 'cash';
      if (!methodCounts[m]) {
        methodCounts[m] = { amount: 0, count: 0 };
      }
      methodCounts[m].amount += amt;
      methodCounts[m].count += 1;

      // Plan breakdown
      const planId = p.plan?._id ? p.plan._id.toString() : 'unassigned';
      const planName = p.plan?.name || 'Custom / Direct';
      if (!planMap[planId]) {
        planMap[planId] = { planId, name: planName, amount: 0, count: 0 };
      }
      planMap[planId].amount += amt;
      planMap[planId].count += 1;
    });

    const trend = Object.values(dateMap).sort((a, b) => a.date.localeCompare(b.date));

    // Format method stats
    const methodStats = Object.entries(methodCounts).map(([method, data]) => ({
      method,
      amount: data.amount,
      count: data.count,
      percentage: totalRevenue > 0 ? Math.round((data.amount / totalRevenue) * 100) : 0
    }));

    // Format plan stats
    const planStats = Object.values(planMap).map(p => ({
      ...p,
      percentage: totalRevenue > 0 ? Math.round((p.amount / totalRevenue) * 100) : 0
    })).sort((a, b) => b.amount - a.amount);

    // Dues stats
    const duesStudents = await Student.find({
      expiryDate: { $lt: new Date() },
      isDeleted: { $ne: true }
    }).populate('plan', 'name price').lean();

    let estimatedPendingDues = 0;
    duesStudents.forEach(s => {
      estimatedPendingDues += s.plan?.price || 0;
    });

    res.json({
      success: true,
      data: {
        summary: {
          totalRevenue,
          totalTransactions: paymentsInPeriod.length,
          averageTransaction: paymentsInPeriod.length > 0 ? Math.round(totalRevenue / paymentsInPeriod.length) : 0,
          pendingDues: estimatedPendingDues,
          pendingStudentsCount: duesStudents.length
        },
        trend,
        byMethod: {
          cash: methodCounts.cash.amount,
          upi: methodCounts.upi.amount,
          bank_transfer: methodCounts.bank_transfer.amount,
          card: methodCounts.card.amount,
          other: methodCounts.other.amount
        },
        methodStats,
        byPlan: planStats,
        collections: paymentsInPeriod.slice().reverse().slice(0, 100)
      },
      message: 'Revenue analytics fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/reports/attendance
 * Attendance statistics: daily student logs for past 30 days, peak study hours distribution, avg study hours
 */
router.get('/attendance', async (req, res) => {
  try {
    const { startDate: qStart, endDate: qEnd, studentId } = req.query;
    const { startDate, endDate } = parseDateRange(qStart, qEnd, 30);

    const filter = {
      date: { $gte: startDate, $lte: endDate }
    };
    if (studentId) filter.student = studentId;

    const records = await Attendance.find(filter)
      .populate('student', 'name studentId phone')
      .populate('seat', 'seatNumber zone')
      .sort({ date: 1, checkIn: 1 })
      .lean();

    // Daily logs map
    const dailyMap = {};
    const curr = new Date(startDate);
    while (curr <= endDate) {
      const key = curr.toISOString().split('T')[0];
      dailyMap[key] = { date: key, present: 0, late: 0, half_day: 0, absent: 0, total: 0 };
      curr.setDate(curr.getDate() + 1);
    }

    // Hourly distribution (0 - 23)
    const hourlyCounts = Array.from({ length: 24 }, (_, i) => ({
      hour: i,
      label: `${i.toString().padStart(2, '0')}:00`,
      displayLabel: i === 0 ? '12 AM' : i < 12 ? `${i} AM` : i === 12 ? '12 PM' : `${i - 12} PM`,
      count: 0
    }));

    let totalDurationMinutes = 0;
    let recordsWithDuration = 0;
    const studentAgg = {};

    records.forEach(r => {
      const dateKey = new Date(r.date).toISOString().split('T')[0];
      if (!dailyMap[dateKey]) {
        dailyMap[dateKey] = { date: dateKey, present: 0, late: 0, half_day: 0, absent: 0, total: 0 };
      }

      const st = r.status || 'present';
      if (dailyMap[dateKey][st] !== undefined) {
        dailyMap[dateKey][st] += 1;
      }
      dailyMap[dateKey].total += 1;

      // Hourly check-in distribution
      if (r.checkIn) {
        const checkInHour = new Date(r.checkIn).getHours();
        if (checkInHour >= 0 && checkInHour < 24) {
          hourlyCounts[checkInHour].count += 1;
        }
      }

      // Duration calculation
      let dur = r.duration || 0;
      if (!dur && r.checkIn && r.checkOut) {
        dur = Math.max(0, Math.round((new Date(r.checkOut) - new Date(r.checkIn)) / (1000 * 60)));
      }
      if (dur > 0) {
        totalDurationMinutes += dur;
        recordsWithDuration += 1;
      }

      // Student aggregation
      if (r.student) {
        const sid = r.student._id.toString();
        if (!studentAgg[sid]) {
          studentAgg[sid] = {
            student: r.student,
            daysPresent: 0,
            totalMinutes: 0,
            logsCount: 0
          };
        }
        if (['present', 'late', 'half_day'].includes(r.status)) {
          studentAgg[sid].daysPresent += 1;
        }
        studentAgg[sid].totalMinutes += dur;
        studentAgg[sid].logsCount += 1;
      }
    });

    const dailyLogs = Object.values(dailyMap).sort((a, b) => a.date.localeCompare(b.date));

    // Calculate peak hour
    let peakHourObj = hourlyCounts.reduce((max, h) => h.count > max.count ? h : max, hourlyCounts[0]);
    const peakHourText = peakHourObj.count > 0 ? `${peakHourObj.displayLabel} (${peakHourObj.count} check-ins)` : 'N/A';

    // Average study hours
    const avgDurationHours = recordsWithDuration > 0
      ? Number((totalDurationMinutes / recordsWithDuration / 60).toFixed(1))
      : 0;

    const totalStudyHours = Number((totalDurationMinutes / 60).toFixed(1));

    // Daily averages
    const totalDaysInRange = Object.keys(dailyMap).length || 1;
    const totalCheckIns = records.filter(r => ['present', 'late', 'half_day'].includes(r.status)).length;
    const avgDailyCheckIns = Number((totalCheckIns / totalDaysInRange).toFixed(1));

    // Format student analytics
    const studentAnalytics = Object.values(studentAgg).map(s => {
      const avgHours = s.daysPresent > 0
        ? Number((s.totalMinutes / s.daysPresent / 60).toFixed(1))
        : 0;
      const totalHours = Number((s.totalMinutes / 60).toFixed(1));
      const attendanceRate = Math.min(100, Math.round((s.daysPresent / totalDaysInRange) * 100));

      return {
        student: s.student,
        daysPresent: s.daysPresent,
        totalHours,
        avgHours,
        logsCount: s.logsCount,
        attendanceRate
      };
    }).sort((a, b) => b.daysPresent - a.daysPresent);

    res.json({
      success: true,
      data: {
        dailyLogs,
        hourlyDistribution: hourlyCounts,
        stats: {
          avgStudyHours: avgDurationHours,
          totalStudyHours,
          totalCheckIns,
          avgDailyCheckIns,
          peakHour: peakHourText,
          peakHourData: peakHourObj,
          totalLogs: records.length
        },
        studentAnalytics
      },
      message: 'Attendance analytics fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/reports/expiries
 * List of students expiring in next 7, 15, 30 days with plan & contact details
 */
router.get('/expiries', async (req, res) => {
  try {
    const { days = '30' } = req.query;
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const maxDays = days === 'all' ? 365 : parseInt(days, 10) || 30;
    const futureDate = new Date(todayStart);
    futureDate.setDate(futureDate.getDate() + maxDays);
    futureDate.setHours(23, 59, 59, 999);

    // Also include recently expired (past 30 days) to allow collecting overdue fees
    const past30Days = new Date(todayStart);
    past30Days.setDate(past30Days.getDate() - 30);

    const students = await Student.find({
      expiryDate: { $gte: past30Days, $lte: futureDate },
      isDeleted: { $ne: true }
    })
      .populate('plan', 'name price duration durationType')
      .populate('seat', 'seatNumber zone')
      .sort({ expiryDate: 1 })
      .lean();

    const next7Days = [];
    const next15Days = [];
    const next30Days = [];
    const expired = [];

    const formattedStudents = students.map(student => {
      const expiry = new Date(student.expiryDate);
      const diffMs = expiry.getTime() - todayStart.getTime();
      const daysRemaining = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

      let expiryCategory = 'next30Days';
      let statusBadge = 'warning';

      if (daysRemaining < 0) {
        expiryCategory = 'expired';
        statusBadge = 'danger';
        expired.push(student);
      } else if (daysRemaining <= 7) {
        expiryCategory = 'next7Days';
        statusBadge = 'danger';
        next7Days.push(student);
      } else if (daysRemaining <= 15) {
        expiryCategory = 'next15Days';
        statusBadge = 'warning';
        next15Days.push(student);
      } else {
        expiryCategory = 'next30Days';
        statusBadge = 'info';
        next30Days.push(student);
      }

      return {
        _id: student._id,
        name: student.name,
        studentId: student.studentId,
        phone: student.phone,
        email: student.email,
        plan: student.plan,
        seat: student.seat,
        admissionDate: student.admissionDate,
        expiryDate: student.expiryDate,
        status: student.status,
        daysRemaining,
        expiryCategory,
        statusBadge
      };
    });

    res.json({
      success: true,
      data: {
        students: formattedStudents,
        counts: {
          count7: next7Days.length,
          count15: next15Days.length,
          count30: next30Days.length,
          countExpired: expired.length,
          total: formattedStudents.length
        },
        categories: {
          next7Days,
          next15Days,
          next30Days,
          expired
        }
      },
      message: 'Expiries fetched successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/reports/export/students
 * Download/export students list as CSV data or formatted JSON
 */
router.get('/export/students', async (req, res) => {
  try {
    const { format = 'csv', status, plan } = req.query;
    const filter = { isDeleted: { $ne: true } };
    if (status) filter.status = status;
    if (plan) filter.plan = plan;

    const students = await Student.find(filter)
      .populate('plan', 'name price duration durationType')
      .populate('seat', 'seatNumber zone')
      .sort({ studentId: 1 })
      .lean();

    if (format === 'json') {
      return res.json({
        success: true,
        data: students,
        message: 'Students exported successfully'
      });
    }

    const headers = [
      { label: 'Student ID', key: 'studentId' },
      { label: 'Full Name', key: 'name' },
      { label: 'Phone', key: 'phone' },
      { label: 'Email', key: 'email', formatter: v => v || '' },
      { label: 'Gender', key: 'gender', formatter: v => v || '' },
      { label: 'Plan', key: 'plan', formatter: (v, r) => r.plan?.name || 'N/A' },
      { label: 'Plan Price', key: 'planPrice', formatter: (v, r) => r.plan?.price ? `₹${r.plan.price}` : '' },
      { label: 'Seat Number', key: 'seat', formatter: (v, r) => r.seat?.seatNumber || 'Unassigned' },
      { label: 'Seat Zone', key: 'seatZone', formatter: (v, r) => r.seat?.zone || '' },
      { label: 'Admission Date', key: 'admissionDate', formatter: v => v ? new Date(v).toLocaleDateString('en-IN') : '' },
      { label: 'Expiry Date', key: 'expiryDate', formatter: v => v ? new Date(v).toLocaleDateString('en-IN') : '' },
      { label: 'Status', key: 'status', formatter: v => (v || '').toUpperCase() },
      { label: 'Address', key: 'address', formatter: v => v || '' },
      { label: 'City', key: 'city', formatter: v => v || '' },
      { label: 'Pincode', key: 'pincode', formatter: v => v || '' }
    ];

    const csvData = generateCSV(headers, students);
    const filename = `students-report-${new Date().toISOString().split('T')[0]}.csv`;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csvData);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/reports/export/payments
 * Download/export payment records as CSV data or formatted JSON
 */
router.get('/export/payments', async (req, res) => {
  try {
    const { format = 'csv', startDate: qStart, endDate: qEnd, method, status } = req.query;
    const filter = { isDeleted: { $ne: true } };

    if (qStart || qEnd) {
      const { startDate, endDate } = parseDateRange(qStart, qEnd, 90);
      filter.paymentDate = { $gte: startDate, $lte: endDate };
    }
    if (method) filter.paymentMethod = method;
    if (status) filter.status = status;

    const payments = await Payment.find(filter)
      .populate('student', 'name studentId phone email')
      .populate('plan', 'name price duration')
      .populate('collectedBy', 'name')
      .sort({ paymentDate: -1 })
      .lean();

    if (format === 'json') {
      return res.json({
        success: true,
        data: payments,
        message: 'Payments exported successfully'
      });
    }

    const headers = [
      { label: 'Receipt #', key: 'receiptNumber' },
      { label: 'Payment Date', key: 'paymentDate', formatter: v => v ? new Date(v).toLocaleDateString('en-IN') : '' },
      { label: 'Student ID', key: 'studentId', formatter: (v, r) => r.student?.studentId || '' },
      { label: 'Student Name', key: 'studentName', formatter: (v, r) => r.student?.name || 'Unknown' },
      { label: 'Student Phone', key: 'studentPhone', formatter: (v, r) => r.student?.phone || '' },
      { label: 'Plan Name', key: 'planName', formatter: (v, r) => r.plan?.name || 'Custom / Direct' },
      { label: 'Base Amount (₹)', key: 'amount', formatter: v => v || 0 },
      { label: 'Discount (₹)', key: 'discount', formatter: v => v || 0 },
      { label: 'Late Fee (₹)', key: 'lateFee', formatter: v => v || 0 },
      { label: 'Final Amount (₹)', key: 'finalAmount', formatter: (v, r) => r.finalAmount || r.amount || 0 },
      { label: 'Payment Method', key: 'paymentMethod', formatter: v => (v || '').toUpperCase() },
      { label: 'Status', key: 'status', formatter: v => (v || '').toUpperCase() },
      { label: 'Transaction ID', key: 'transactionId', formatter: v => v || '' },
      { label: 'Collected By', key: 'collectedBy', formatter: (v, r) => r.collectedBy?.name || 'System' },
      { label: 'Notes', key: 'notes', formatter: v => v || '' }
    ];

    const csvData = generateCSV(headers, payments);
    const filename = `payments-report-${new Date().toISOString().split('T')[0]}.csv`;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csvData);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/reports/export/attendance
 * Download/export attendance records as CSV data or formatted JSON
 */
router.get('/export/attendance', async (req, res) => {
  try {
    const { format = 'csv', startDate: qStart, endDate: qEnd, studentId, status } = req.query;
    const filter = {};

    if (qStart || qEnd) {
      const { startDate, endDate } = parseDateRange(qStart, qEnd, 30);
      filter.date = { $gte: startDate, $lte: endDate };
    }
    if (studentId) filter.student = studentId;
    if (status) filter.status = status;

    const records = await Attendance.find(filter)
      .populate('student', 'name studentId phone')
      .populate('seat', 'seatNumber zone')
      .sort({ date: -1, checkIn: -1 })
      .lean();

    if (format === 'json') {
      return res.json({
        success: true,
        data: records,
        message: 'Attendance exported successfully'
      });
    }

    const headers = [
      { label: 'Date', key: 'date', formatter: v => v ? new Date(v).toLocaleDateString('en-IN') : '' },
      { label: 'Student ID', key: 'studentId', formatter: (v, r) => r.student?.studentId || '' },
      { label: 'Student Name', key: 'studentName', formatter: (v, r) => r.student?.name || 'Unknown' },
      { label: 'Student Phone', key: 'studentPhone', formatter: (v, r) => r.student?.phone || '' },
      { label: 'Seat Number', key: 'seatNumber', formatter: (v, r) => r.seat?.seatNumber || 'Unassigned' },
      { label: 'Check-In Time', key: 'checkIn', formatter: v => v ? new Date(v).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : '-' },
      { label: 'Check-Out Time', key: 'checkOut', formatter: v => v ? new Date(v).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : '-' },
      { label: 'Duration (Minutes)', key: 'duration', formatter: v => v || 0 },
      { label: 'Duration (Hours)', key: 'durationHours', formatter: (v, r) => r.duration ? (r.duration / 60).toFixed(1) : '0' },
      { label: 'Status', key: 'status', formatter: v => (v || '').toUpperCase() },
      { label: 'Marked By', key: 'markedBy', formatter: v => (v || '').toUpperCase() },
      { label: 'Shift', key: 'shift', formatter: v => v || '-' },
      { label: 'Notes', key: 'notes', formatter: v => v || '' }
    ];

    const csvData = generateCSV(headers, records);
    const filename = `attendance-report-${new Date().toISOString().split('T')[0]}.csv`;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csvData);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   GET /api/reports/eod-summary
 * @desc    Get complete daily End-of-Day summary for owner
 * @access  Private (Owner / Manager)
 */
router.get('/eod-summary', async (req, res) => {
  try {
    const { generateEODSummary } = require('../utils/cronJobs');
    const BusinessProfile = require('../models/BusinessProfile');
    const WhatsAppService = require('../utils/whatsappService');

    const [summary, profile] = await Promise.all([
      generateEODSummary(),
      BusinessProfile.getProfile()
    ]);

    const waText = WhatsAppService.getEODSummaryMessage(summary, profile.businessName);
    const ownerPhone = profile.phone || req.user.phone || '';
    const waUrl = WhatsAppService.getClickToChatUrl(ownerPhone, waText);

    res.json({
      success: true,
      data: {
        summary,
        formattedMessage: waText,
        ownerPhone,
        whatsappUrl: waUrl
      },
      message: 'End-of-Day summary computed successfully'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/reports/tally-xml
 * Generates Tally Prime XML Sales & Receipt Voucher XML import file for fee collections and operational expenses
 */
router.get('/tally-xml', async (req, res) => {
  try {
    const { startDate: qStart, endDate: qEnd } = req.query;
    const { startDate, endDate } = parseDateRange(qStart, qEnd, 30);

    const [payments, expenses] = await Promise.all([
      Payment.find({
        paymentDate: { $gte: startDate, $lte: endDate },
        status: 'paid',
        isDeleted: { $ne: true }
      })
        .populate('student', 'name studentId phone')
        .populate('plan', 'name')
        .sort({ paymentDate: 1 })
        .lean(),
      Expense.find({
        date: { $gte: startDate, $lte: endDate },
        isDeleted: { $ne: true }
      })
        .sort({ date: 1 })
        .lean()
    ]);

    function formatTallyDate(date) {
      if (!date) return '';
      const d = new Date(date);
      const year = d.getFullYear();
      const month = String(d.getMonth() + 1).padStart(2, '0');
      const day = String(d.getDate()).padStart(2, '0');
      return `${year}${month}${day}`;
    }

    function escapeXML(str) {
      if (str === null || str === undefined) return '';
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;');
    }

    let voucherXmls = '';

    // Receipt Vouchers for Fee Collections
    payments.forEach(p => {
      const vDate = formatTallyDate(p.paymentDate);
      const vNo = escapeXML(p.receiptNumber || `REC-${p._id}`);
      const studentName = escapeXML(p.student?.name || 'Student Fee');
      const planName = escapeXML(p.plan?.name || 'Library Membership');
      const amount = Number(p.finalAmount || p.amount || 0);
      const method = p.paymentMethod || 'cash';
      const ledgerName = method === 'cash' ? 'Cash' : 'Bank Accounts';
      const narration = escapeXML(`Fee Collection - ${studentName} (${planName}) - ${p.receiptNumber || ''}`);

      voucherXmls += `
        <TALLYMESSAGE xmlns:UDF="TallyUDF">
          <VOUCHER VCHTYPE="Receipt" ACTION="Create">
            <DATE>${vDate}</DATE>
            <VOUCHERTYPENAME>Receipt</VOUCHERTYPENAME>
            <VOUCHERNUMBER>${vNo}</VOUCHERNUMBER>
            <NARRATION>${narration}</NARRATION>
            <ALLLEDGERENTRIES.LIST>
              <LEDGERNAME>${ledgerName}</LEDGERNAME>
              <ISDEEMEDPOSITIVE>YES</ISDEEMEDPOSITIVE>
              <AMOUNT>-${amount.toFixed(2)}</AMOUNT>
            </ALLLEDGERENTRIES.LIST>
            <ALLLEDGERENTRIES.LIST>
              <LEDGERNAME>Fee Income</LEDGERNAME>
              <ISDEEMEDPOSITIVE>NO</ISDEEMEDPOSITIVE>
              <AMOUNT>${amount.toFixed(2)}</AMOUNT>
            </ALLLEDGERENTRIES.LIST>
          </VOUCHER>
        </TALLYMESSAGE>`;
    });

    // Payment Vouchers for Operational Expenses
    expenses.forEach(e => {
      const vDate = formatTallyDate(e.date);
      const vNo = escapeXML(`EXP-${e._id.toString().substring(18)}`);
      const category = escapeXML(e.category || 'Indirect Expenses');
      const title = escapeXML(e.title || 'Operational Expense');
      const amount = Number(e.amount || 0);
      const method = e.paymentMethod || 'cash';
      const bankOrCash = method === 'cash' ? 'Cash' : 'Bank Accounts';
      const narration = escapeXML(`Expense - ${category}: ${title} ${e.vendor ? '(' + e.vendor + ')' : ''}`);

      voucherXmls += `
        <TALLYMESSAGE xmlns:UDF="TallyUDF">
          <VOUCHER VCHTYPE="Payment" ACTION="Create">
            <DATE>${vDate}</DATE>
            <VOUCHERTYPENAME>Payment</VOUCHERTYPENAME>
            <VOUCHERNUMBER>${vNo}</VOUCHERNUMBER>
            <NARRATION>${narration}</NARRATION>
            <ALLLEDGERENTRIES.LIST>
              <LEDGERNAME>${category}</LEDGERNAME>
              <ISDEEMEDPOSITIVE>YES</ISDEEMEDPOSITIVE>
              <AMOUNT>-${amount.toFixed(2)}</AMOUNT>
            </ALLLEDGERENTRIES.LIST>
            <ALLLEDGERENTRIES.LIST>
              <LEDGERNAME>${bankOrCash}</LEDGERNAME>
              <ISDEEMEDPOSITIVE>NO</ISDEEMEDPOSITIVE>
              <AMOUNT>${amount.toFixed(2)}</AMOUNT>
            </ALLLEDGERENTRIES.LIST>
          </VOUCHER>
        </TALLYMESSAGE>`;
    });

    const tallyXml = `<?xml version="1.0" encoding="UTF-8"?>
<ENVELOPE>
  <HEADER>
    <TALLYREQUEST>Import Data</TALLYREQUEST>
  </HEADER>
  <BODY>
    <IMPORTDATA>
      <REQUESTDESC>
        <REPORTNAME>Vouchers</REPORTNAME>
        <STATICVARIABLES>
          <SVCURRENTCOMPANY>Library Management System</SVCURRENTCOMPANY>
        </STATICVARIABLES>
      </REQUESTDESC>
      <REQUESTDATA>${voucherXmls}
      </REQUESTDATA>
    </IMPORTDATA>
  </BODY>
</ENVELOPE>`;

    const startDateStr = startDate.toISOString().split('T')[0];
    const endDateStr = endDate.toISOString().split('T')[0];
    const filename = `tally-import-${startDateStr}-to-${endDateStr}.xml`;

    res.setHeader('Content-Type', 'application/xml; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(tallyXml);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/reports/gst-report
 * Generates GSTR-1 & GSTR-3B B2C sales summary (Taxable Value, CGST 9%, SGST 9%, Total GST 18%, Grand Total)
 */
router.get('/gst-report', async (req, res) => {
  try {
    const { startDate: qStart, endDate: qEnd, format = 'csv' } = req.query;
    const { startDate, endDate } = parseDateRange(qStart, qEnd, 30);

    const payments = await Payment.find({
      paymentDate: { $gte: startDate, $lte: endDate },
      status: 'paid',
      isDeleted: { $ne: true }
    })
      .populate('student', 'name studentId phone state gstin')
      .populate('plan', 'name price')
      .sort({ paymentDate: 1 })
      .lean();

    let grandTotal = 0;
    let totalTaxableValue = 0;
    let totalCgst = 0;
    let totalSgst = 0;
    let totalGst = 0;

    const rows = payments.map(p => {
      const totalAmt = Number(p.finalAmount || p.amount || 0);
      const taxable = Math.round((totalAmt / 1.18) * 100) / 100;
      const gstAmt = Math.round((totalAmt - taxable) * 100) / 100;
      const cgst = Math.round((gstAmt / 2) * 100) / 100;
      const sgst = Math.round((gstAmt - cgst) * 100) / 100;

      grandTotal += totalAmt;
      totalTaxableValue += taxable;
      totalCgst += cgst;
      totalSgst += sgst;
      totalGst += gstAmt;

      return {
        receiptNumber: p.receiptNumber || '',
        paymentDate: p.paymentDate ? new Date(p.paymentDate).toLocaleDateString('en-IN') : '',
        studentName: p.student?.name || 'B2C Customer',
        studentId: p.student?.studentId || '',
        planName: p.plan?.name || 'Subscription',
        paymentMethod: (p.paymentMethod || 'cash').toUpperCase(),
        taxableValue: taxable.toFixed(2),
        cgst: cgst.toFixed(2),
        sgst: sgst.toFixed(2),
        totalGst: gstAmt.toFixed(2),
        grandTotal: totalAmt.toFixed(2)
      };
    });

    const summary = {
      totalTransactions: payments.length,
      taxableValue: Number(totalTaxableValue.toFixed(2)),
      cgst9: Number(totalCgst.toFixed(2)),
      sgst9: Number(totalSgst.toFixed(2)),
      totalGst18: Number(totalGst.toFixed(2)),
      grandTotal: Number(grandTotal.toFixed(2))
    };

    if (format === 'json') {
      return res.json({
        success: true,
        data: {
          summary,
          items: rows,
          period: {
            startDate: startDate.toISOString(),
            endDate: endDate.toISOString()
          }
        },
        message: 'GST Sales Summary report generated successfully'
      });
    }

    const headers = [
      { label: 'Receipt #', key: 'receiptNumber' },
      { label: 'Payment Date', key: 'paymentDate' },
      { label: 'Student Name', key: 'studentName' },
      { label: 'Student ID', key: 'studentId' },
      { label: 'Plan Name', key: 'planName' },
      { label: 'Payment Method', key: 'paymentMethod' },
      { label: 'Taxable Value (₹)', key: 'taxableValue' },
      { label: 'CGST 9% (₹)', key: 'cgst' },
      { label: 'SGST 9% (₹)', key: 'sgst' },
      { label: 'Total GST 18% (₹)', key: 'totalGst' },
      { label: 'Grand Total (₹)', key: 'grandTotal' }
    ];

    const csvRows = [...rows, {
      receiptNumber: 'TOTAL SUMMARY',
      paymentDate: '',
      studentName: '',
      studentId: '',
      planName: '',
      paymentMethod: '',
      taxableValue: totalTaxableValue.toFixed(2),
      cgst: totalCgst.toFixed(2),
      sgst: totalSgst.toFixed(2),
      totalGst: totalGst.toFixed(2),
      grandTotal: grandTotal.toFixed(2)
    }];

    const csvData = generateCSV(headers, csvRows);
    const startDateStr = startDate.toISOString().split('T')[0];
    const endDateStr = endDate.toISOString().split('T')[0];
    const filename = `gst-b2c-sales-summary-${startDateStr}-to-${endDateStr}.csv`;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csvData);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;

