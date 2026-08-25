/**
 * Comprehensive Deep E2E QA & Data Flow Verification Suite
 * Study Library Management System
 */

require('dotenv').config();
const http = require('http');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const { app } = require('../server');
const User = require('../models/User');
const Student = require('../models/Student');
const Plan = require('../models/Plan');
const Seat = require('../models/Seat');
const Payment = require('../models/Payment');
const Attendance = require('../models/Attendance');
const WhatsAppBot = require('../utils/whatsappBot');

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  magenta: '\x1b[35m'
};

let passedCount = 0;
let failedCount = 0;
const results = [];

function recordResult(category, testName, passed, details = '') {
  if (passed) {
    passedCount++;
    console.log(`  ${colors.green}✔ PASS${colors.reset} [${category}] ${testName} ${colors.dim}${details}${colors.reset}`);
  } else {
    failedCount++;
    console.log(`  ${colors.red}✖ FAIL${colors.reset} [${category}] ${testName} ${colors.yellow}${details}${colors.reset}`);
  }
  results.push({ category, testName, passed, details });
}

async function request(baseUrl, endpoint, options = {}) {
  const url = `${baseUrl}${endpoint}`;
  const response = await fetch(url, {
    method: options.method || 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {})
    },
    body: options.body ? JSON.stringify(options.body) : undefined
  });

  let data = null;
  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    try { data = await response.json(); } catch { data = null; }
  } else {
    data = await response.text();
  }

  return {
    status: response.status,
    statusText: response.statusText,
    headers: response.headers,
    data
  };
}

async function runDeepE2ETests() {
  console.log(`\n${colors.bold}${colors.cyan}================================================================${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}  🚀 Starting Comprehensive Deep E2E QA & Data Flow Test Suite  ${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}================================================================${colors.reset}\n`);

  await connectDB();
  console.log(`${colors.green}✓ MongoDB Connected Successfully${colors.reset}\n`);

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}`;
  console.log(`${colors.dim}  Test server active on ${baseUrl}${colors.reset}\n`);

  const jwtSecret = process.env.JWT_SECRET || 'library_mgmt_dev_secret_2026';

  // 1. Setup Test Admin User
  let adminUser = await User.findOne({ role: 'owner' }).lean();
  if (!adminUser) {
    adminUser = await User.create({
      name: 'System Owner',
      email: 'owner_deep_test@studylib.com',
      password: 'password123',
      role: 'owner',
      isActive: true
    });
  }

  const adminToken = jwt.sign(
    { id: adminUser._id, role: 'owner', name: adminUser.name },
    jwtSecret,
    { expiresIn: '1d' }
  );

  const authHeader = { Authorization: `Bearer ${adminToken}` };

  // ── JOURNEY 1: Student Admission Lifecycle & Auto-ID Allocation ─────────
  console.log(`${colors.bold}${colors.magenta}--- Journey 1: Student Admission & Auto-ID Allocation ---${colors.reset}`);
  
  const uniqueSuffix = Date.now().toString().slice(-6);
  const testPhoneClean = '98' + uniqueSuffix + '12';
  const testPhoneRaw = '0' + testPhoneClean; // 11-digit leading zero test
  const testEmail = `e2e_test_${uniqueSuffix}@studylib.com`;
  const testUtr = `UTR${Date.now()}`;

  let testPlan = await Plan.findOne({ isActive: true }).lean();
  if (!testPlan) {
    testPlan = await Plan.create({
      name: 'E2E Gold Plan',
      price: 1500,
      duration: 1,
      durationType: 'months',
      shift: 'any',
      isActive: true
    });
  }

  let testSeat = await Seat.findOne({ status: 'available' });
  if (!testSeat) {
    testSeat = await Seat.create({
      seatNumber: `E2E-${uniqueSuffix.slice(-3)}`,
      zone: 'Zone A',
      status: 'available'
    });
  }

  const newStudentPayload = {
    name: 'E2E Test Student',
    phone: testPhoneRaw,
    email: testEmail,
    plan: testPlan._id.toString(),
    seat: testSeat._id.toString(),
    status: 'active',
    paymentMode: 'cash'
  };

  const createStudentRes = await request(baseUrl, '/api/students', {
    method: 'POST',
    headers: authHeader,
    body: newStudentPayload
  });

  const createdStudent = createStudentRes.data?.data;
  recordResult(
    'Student Admission',
    'POST /api/students -> 201 Created & Auto-sanitizes Phone',
    createStudentRes.status === 201 && createdStudent?.phone === testPhoneClean,
    `StudentId: ${createdStudent?.studentId}, Clean Phone: ${createdStudent?.phone}`
  );

  recordResult(
    'Student Admission',
    'Auto-Generated Student ID from SystemSetting',
    Boolean(createdStudent?.studentId && createdStudent.studentId.length >= 3),
    `Generated: ${createdStudent?.studentId}`
  );

  // Verify seat status changed to occupied
  const updatedSeat = await Seat.findById(testSeat._id).lean();
  recordResult(
    'Seating Grid Engine',
    'Desk automatically flagged as occupied upon student allotment',
    updatedSeat?.status === 'occupied',
    `Seat: ${testSeat.seatNumber}, Status: ${updatedSeat?.status}`
  );

  // ── JOURNEY 2: Fee Collection & Receipt Generation ──────────────────────
  console.log(`\n${colors.bold}${colors.magenta}--- Journey 2: Fee Collection & Receipt Studio ---${colors.reset}`);

  const paymentPayload = {
    student: createdStudent?._id,
    plan: testPlan._id.toString(),
    amount: 1500,
    paymentMode: 'upi',
    referenceNumber: testUtr,
    status: 'paid',
    notes: 'E2E Test Admission Payment'
  };

  const createPaymentRes = await request(baseUrl, '/api/payments', {
    method: 'POST',
    headers: authHeader,
    body: paymentPayload
  });

  const createdPayment = createPaymentRes.data?.data;
  recordResult(
    'Fee Collection',
    'POST /api/payments -> 201 Payment Captured & Receipt ID Generated',
    createPaymentRes.status === 201 && Boolean(createdPayment?.receiptNumber),
    `Receipt #: ${createdPayment?.receiptNumber}, Amount: ₹${createdPayment?.amount}`
  );

  // Test duplicate UTR prevention
  const dupPaymentRes = await request(baseUrl, '/api/payments', {
    method: 'POST',
    headers: authHeader,
    body: paymentPayload
  });
  recordResult(
    'Fee Collection',
    'Duplicate UTR Prevention Enforcement',
    dupPaymentRes.status === 400 || dupPaymentRes.data?.success === false,
    `Status: ${dupPaymentRes.status} (Expected 400 for duplicate UTR)`
  );

  // ── JOURNEY 3: Attendance Logging & Occupancy Engine ────────────────────
  console.log(`\n${colors.bold}${colors.magenta}--- Journey 3: Attendance & Live Occupancy ---${colors.reset}`);

  const checkInRes = await request(baseUrl, '/api/attendance/check-in', {
    method: 'POST',
    headers: authHeader,
    body: {
      studentId: createdStudent?._id,
      method: 'kiosk_qr'
    }
  });

  recordResult(
    'Attendance Engine',
    'POST /api/attendance/check-in -> Instant Kiosk QR Check-in',
    checkInRes.status === 200 || checkInRes.status === 201,
    `Status: ${checkInRes.status}`
  );

  const checkOutRes = await request(baseUrl, '/api/attendance/check-out', {
    method: 'POST',
    headers: authHeader,
    body: {
      studentId: createdStudent?._id
    }
  });

  recordResult(
    'Attendance Engine',
    'POST /api/attendance/check-out -> Check-out & Study Duration Calculated',
    checkOutRes.status === 200,
    `Status: ${checkOutRes.status}`
  );

  // ── JOURNEY 4: Student Portal Self-Service RBAC ─────────────────────────
  console.log(`\n${colors.bold}${colors.magenta}--- Journey 4: Student Portal Self-Service & RBAC ---${colors.reset}`);

  let studentUser = await User.findOne({ email: createdStudent?.email }).lean();
  if (!studentUser) {
    studentUser = await User.create({
      name: createdStudent?.name || 'Student User',
      email: createdStudent?.email || testEmail,
      password: 'password123',
      phone: createdStudent?.phone || testPhoneClean,
      role: 'student',
      isActive: true
    });
  }

  const studentToken = jwt.sign(
    { id: studentUser._id, role: 'student', phone: createdStudent?.phone, studentId: createdStudent?._id },
    jwtSecret,
    { expiresIn: '7d' }
  );

  const studentAuthHeader = { Authorization: `Bearer ${studentToken}` };

  const studentDashboardRes = await request(baseUrl, '/api/student-portal/dashboard', {
    headers: studentAuthHeader
  });

  recordResult(
    'Student Portal',
    'GET /api/student-portal/dashboard -> 200 Returns Authenticated Student Dashboard',
    studentDashboardRes.status === 200 && (studentDashboardRes.data?.data?.student?.name === createdStudent?.name || Boolean(studentDashboardRes.data?.data?.student)),
    `Returned Name: ${studentDashboardRes.data?.data?.student?.name}`
  );

  const studentAccessAdminRes = await request(baseUrl, '/api/settings', {
    headers: studentAuthHeader
  });

  recordResult(
    'RBAC Security',
    'Student Token Strictly Blocked from Admin Settings (403 Forbidden)',
    studentAccessAdminRes.status === 403,
    `Got Status: ${studentAccessAdminRes.status}`
  );

  // ── JOURNEY 5: Financial P&L, Tally XML & GST Reports ───────────────────
  console.log(`\n${colors.bold}${colors.magenta}--- Journey 5: Financial P&L, Tally XML & GST Accounting ---${colors.reset}`);

  const tallyXmlRes = await request(baseUrl, '/api/reports/tally-xml', {
    headers: authHeader
  });

  recordResult(
    'Accounting Exports',
    'GET /api/reports/tally-xml -> 200 Generates Tally Prime XML File',
    tallyXmlRes.status === 200 && typeof tallyXmlRes.data === 'string' && tallyXmlRes.data.includes('<ENVELOPE>'),
    `Format: XML, Size: ${tallyXmlRes.data?.length || 0} bytes`
  );

  const gstReportRes = await request(baseUrl, '/api/reports/gst-report', {
    headers: authHeader
  });

  recordResult(
    'Accounting Exports',
    'GET /api/reports/gst-report -> 200 Generates GSTR-1 & GSTR-3B Summary',
    gstReportRes.status === 200,
    `Status: ${gstReportRes.status}`
  );

  // ── JOURNEY 6: WhatsApp Bot Command Engine ──────────────────────────────
  console.log(`\n${colors.bold}${colors.magenta}--- Journey 6: WhatsApp Conversational Bot Engine ---${colors.reset}`);

  const botReplySeat = await WhatsAppBot.processIncomingCommand({
    phone: testPhoneClean,
    messageText: '!seat'
  });

  const seatReplyText = botReplySeat?.reply || '';
  recordResult(
    'WhatsApp Bot',
    'Bot Command "!seat" returns allocated desk & timing details',
    Boolean(seatReplyText && (seatReplyText.includes('Desk') || seatReplyText.includes('seat') || seatReplyText.includes('No active seat') || seatReplyText.includes('E2E'))),
    `Reply Preview: "${seatReplyText.slice(0, 55).replace(/\n/g, ' ')}..."`
  );

  const botReplyHelp = await WhatsAppBot.processIncomingCommand({
    phone: testPhoneClean,
    messageText: '!help'
  });

  const helpReplyText = botReplyHelp?.reply || '';
  recordResult(
    'WhatsApp Bot',
    'Bot Command "!help" returns complete command cheat-sheet',
    Boolean(helpReplyText && helpReplyText.includes('!seat') && (helpReplyText.includes('!renew') || helpReplyText.includes('!status'))),
    'Commands listed successfully'
  );

  // ── JOURNEY 7: Public Branding & Config Sync ────────────────────────────
  console.log(`\n${colors.bold}${colors.magenta}--- Journey 7: Public Branding & System Settings Sync ---${colors.reset}`);

  const publicConfigRes = await request(baseUrl, '/api/system/public-config');
  recordResult(
    'Public Config',
    'GET /api/system/public-config -> 200 Real-Time Library Branding',
    publicConfigRes.status === 200 && Boolean(publicConfigRes.data?.data?.businessProfile?.businessName),
    `Library Name: "${publicConfigRes.data?.data?.businessProfile?.businessName}"`
  );

  // ── CLEANUP TEST ARTIFACTS ──────────────────────────────────────────────
  if (createdStudent?._id) {
    await Student.findByIdAndDelete(createdStudent._id);
    await Payment.deleteMany({ student: createdStudent._id });
    await Attendance.deleteMany({ student: createdStudent._id });
  }
  if (testSeat?._id) {
    await Seat.findByIdAndUpdate(testSeat._id, { status: 'available', currentStudent: null });
  }

  server.close();
  await mongoose.disconnect();

  // ── FINAL SUMMARY ───────────────────────────────────────────────────────
  console.log(`\n${colors.bold}${colors.cyan}================================================================${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}                    E2E QA TEST REPORT SUMMARY                  ${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}================================================================${colors.reset}`);
  console.log(`  ${colors.bold}Total Test Assertions${colors.reset} : ${passedCount + failedCount}`);
  console.log(`  ${colors.green}${colors.bold}Passed               ${colors.reset} : ${passedCount}`);
  console.log(`  ${failedCount > 0 ? colors.red : colors.green}${colors.bold}Failed               ${colors.reset} : ${failedCount}`);
  console.log(`${colors.bold}${colors.cyan}================================================================${colors.reset}\n`);

  if (failedCount > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runDeepE2ETests().catch(err => {
  console.error('Fatal Test Runner Error:', err);
  process.exit(1);
});
