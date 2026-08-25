/**
 * E2E Smoke & QA Verification Test Suite
 * Study Library Management System
 * 
 * Verifies:
 * 1. Public Routes Availability (200 OK)
 * 2. Unauthenticated Protected Route Rejections (401 Unauthorized)
 * 3. RBAC Boundary Enforcement (Student Token -> 403 Forbidden on Admin Routes)
 * 4. Webhook Security Verification (401 on unauthenticated/unauthorized payloads)
 * 5. Static Asset & HTML Viewport Health Check
 */

require('dotenv').config();
const path = require('path');
const fs = require('fs');
const http = require('http');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const { app } = require('../server');
const User = require('../models/User');

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m',
  dim: '\x1b[2m'
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
    try {
      data = await response.json();
    } catch {
      data = null;
    }
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

async function runTests() {
  console.log(`\n${colors.bold}${colors.cyan}====================================================${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}  🧪 Starting E2E Smoke & QA Verification Suite    ${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}====================================================${colors.reset}\n`);

  // 1. Connect DB
  try {
    await connectDB();
    console.log(`${colors.green}✓ Database connected successfully${colors.reset}\n`);
  } catch (dbErr) {
    console.error(`${colors.red}✗ Database connection error:${colors.reset}`, dbErr.message);
  }

  // 2. Start HTTP Server on dynamic port
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}`;
  console.log(`${colors.dim}  Test server listening on ${baseUrl}${colors.reset}\n`);

  const jwtSecret = process.env.JWT_SECRET || 'library_mgmt_dev_secret_2026';

  // ── TEST 1: Public Routes ──────────────────────────────────────────────────
  console.log(`${colors.bold}--- Test Suite 1: Public Routes Availability ---${colors.reset}`);
  const publicRoutes = [
    '/api/health',
    '/api/plans',
    '/api/branches/public-list',
    '/api/custom-fields',
    '/api/landing'
  ];

  for (const route of publicRoutes) {
    try {
      const res = await request(baseUrl, route);
      const isSuccess = res.status === 200;
      recordResult('Public Routes', `GET ${route}`, isSuccess, `(Status: ${res.status})`);
    } catch (err) {
      recordResult('Public Routes', `GET ${route}`, false, `Error: ${err.message}`);
    }
  }

  // ── TEST 2: Unauthenticated Protected Routes (Expect 401) ───────────────────
  console.log(`\n${colors.bold}--- Test Suite 2: Unauthenticated Protected Routes (Expect 401) ---${colors.reset}`);
  const protectedRoutes = [
    '/api/students',
    '/api/payments',
    '/api/settings',
    '/api/reports'
  ];

  for (const route of protectedRoutes) {
    try {
      const res = await request(baseUrl, route);
      const is401 = res.status === 401;
      recordResult('Protected Routes (No Auth)', `GET ${route} -> 401`, is401, `(Got Status: ${res.status})`);
    } catch (err) {
      recordResult('Protected Routes (No Auth)', `GET ${route} -> 401`, false, `Error: ${err.message}`);
    }
  }

  // ── TEST 3: RBAC Boundary Test (Student Token vs Admin Token) ───────────────
  console.log(`\n${colors.bold}--- Test Suite 3: RBAC Boundary & Role Enforcement ---${colors.reset}`);
  
  const realAdmin = await User.findOne({ role: 'owner' }) || await User.findOne({});
  const adminToken = jwt.sign(
    { id: realAdmin?._id, role: realAdmin?.role || 'owner', email: realAdmin?.email },
    jwtSecret,
    { expiresIn: '1h' }
  );

  // Temporary student user for RBAC test (deleted immediately after)
  let testStudentUser = await User.create({
    name: 'Temporary Smoke Test Student',
    email: `tmp_rbac_${Date.now()}@test.local`,
    password: 'TestPassword123!',
    role: 'student',
    isActive: true
  });

  const studentToken = jwt.sign(
    { id: testStudentUser._id, role: 'student', email: testStudentUser.email },
    jwtSecret,
    { expiresIn: '1h' }
  );

  const rbacEndpoints = [
    '/api/students',
    '/api/payments',
    '/api/settings'
  ];

  // Verify student gets 403 Forbidden
  for (const ep of rbacEndpoints) {
    try {
      const res = await request(baseUrl, ep, {
        headers: { Authorization: `Bearer ${studentToken}` }
      });
      const is403 = res.status === 403;
      recordResult('RBAC Student Role', `GET ${ep} with Student Token -> 403 Forbidden`, is403, `(Got Status: ${res.status})`);
    } catch (err) {
      recordResult('RBAC Student Role', `GET ${ep} with Student Token -> 403 Forbidden`, false, `Error: ${err.message}`);
    }
  }

  // Delete test student user immediately
  await User.deleteOne({ _id: testStudentUser._id });

  // Verify admin gets 200 OK
  for (const ep of rbacEndpoints) {
    try {
      const res = await request(baseUrl, ep, {
        headers: { Authorization: `Bearer ${adminToken}` }
      });
      const is200 = res.status === 200;
      recordResult('RBAC Admin Role', `GET ${ep} with Admin Token -> 200 OK`, is200, `(Got Status: ${res.status})`);
    } catch (err) {
      recordResult('RBAC Admin Role', `GET ${ep} with Admin Token -> 200 OK`, false, `Error: ${err.message}`);
    }
  }

  // ── TEST 4: Webhook Security Verification ──────────────────────────────────
  console.log(`\n${colors.bold}--- Test Suite 4: Webhook Security Verification ---${colors.reset}`);
  const webhookEndpoint = '/api/student-portal/webhook/payment-captured';

  // 4a. Unauthenticated and unsigned webhook request -> expect 401
  try {
    const res = await request(baseUrl, webhookEndpoint, {
      method: 'POST',
      body: { event: 'payment.captured', amountPaid: 1000 }
    });
    const is401 = res.status === 401;
    recordResult('Webhook Security', `POST ${webhookEndpoint} (No Secret/Token) -> 401`, is401, `(Got Status: ${res.status})`);
  } catch (err) {
    recordResult('Webhook Security', `POST ${webhookEndpoint} (No Secret/Token) -> 401`, false, `Error: ${err.message}`);
  }

  // 4b. Webhook request with invalid secret -> expect 401
  try {
    const res = await request(baseUrl, webhookEndpoint, {
      method: 'POST',
      headers: { 'x-webhook-secret': 'invalid_secret_token_12345' },
      body: { event: 'payment.captured', amountPaid: 1000 }
    });
    const is401 = res.status === 401;
    recordResult('Webhook Security', `POST ${webhookEndpoint} (Invalid Secret) -> 401`, is401, `(Got Status: ${res.status})`);
  } catch (err) {
    recordResult('Webhook Security', `POST ${webhookEndpoint} (Invalid Secret) -> 401`, false, `Error: ${err.message}`);
  }

  // ── TEST 5: Static Asset Health Check ──────────────────────────────────────
  console.log(`\n${colors.bold}--- Test Suite 5: Static Asset & Viewport Health Check ---${colors.reset}`);
  const publicDir = path.join(__dirname, '..', 'public');
  const requiredHtmlFiles = [
    'index.html',
    'landing.html',
    'register.html',
    'kiosk.html',
    'student-login.html',
    'offline.html'
  ];

  for (const file of requiredHtmlFiles) {
    const filePath = path.join(publicDir, file);
    const exists = fs.existsSync(filePath);
    if (!exists) {
      recordResult('Static Asset Health', `File ${file} exists`, false, 'File not found');
      continue;
    }

    const content = fs.readFileSync(filePath, 'utf8');
    const hasViewport = /<meta\s+name=["']viewport["']\s+content=["'][^"']*width=device-width[^"']*["']/i.test(content);
    recordResult('Static Asset Health', `File ${file} has valid viewport meta tag`, hasViewport, hasViewport ? '' : 'Missing or malformed viewport tag');
  }

  // ── Cleanup and Teardown ───────────────────────────────────────────────────
  try {
    await User.deleteMany({ email: { $in: ['qa_smoke_student@test.local', 'qa_smoke_admin@test.local'] } });
  } catch {}

  server.close();
  await mongoose.connection.close();

  // ── Summary Table ─────────────────────────────────────────────────────────
  console.log(`\n${colors.bold}${colors.cyan}====================================================${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}                  TEST SUMMARY                      ${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}====================================================${colors.reset}`);
  console.log(`  Total Tests Run : ${passedCount + failedCount}`);
  console.log(`  ${colors.green}Passed          : ${passedCount}${colors.reset}`);
  console.log(`  ${failedCount > 0 ? colors.red : colors.green}Failed          : ${failedCount}${colors.reset}`);
  console.log(`${colors.bold}${colors.cyan}====================================================${colors.reset}\n`);

  if (failedCount > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runTests().catch((err) => {
  console.error(`${colors.red}Fatal test runner error:${colors.reset}`, err);
  process.exit(1);
});
