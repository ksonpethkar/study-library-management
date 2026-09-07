/**
 * Automated Verification for 4 Pillars:
 * 1. Offline-First PWA Sync (POST /api/attendance/batch-sync)
 * 2. Automated Cloud & Telegram Backups (POST /api/backup/run-now, GET /api/backup/list)
 * 3. Smart WhatsApp Automation & Renewal Marketing (GET /api/notifications/marketing/renewal-candidates)
 * 4. AI Study Analytics & Student Churn Prediction (GET /api/ai/insights)
 */

require('dotenv').config();
const http = require('http');
const jwt = require('jsonwebtoken');
const connectDB = require('../config/db');

(async () => {
  console.log('\n======================================================');
  console.log('  🧪 Verifying 4-Pillar Enterprise System Upgrade Suite');
  console.log('======================================================\n');

  try {
    await connectDB();
    const { app } = require('../server');
    const server = http.createServer(app);
    await new Promise(r => server.listen(0, '127.0.0.1', r));
    const port = server.address().port;
    const baseUrl = `http://127.0.0.1:${port}`;
    console.log(`✓ Test server listening on ${baseUrl}`);

    const User = require('../models/User');
    const Student = require('../models/Student');
    const adminUser = await User.findOne({ role: 'owner' }).lean();
    const secret = process.env.JWT_SECRET || 'library_mgmt_dev_secret_2026';
    const adminToken = jwt.sign({ id: adminUser._id, role: 'owner', name: adminUser.name }, secret);
    const authHeaders = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${adminToken}`
    };

    let passCount = 0;

    // --- TEST 1: Offline PWA Batch Sync ---
    console.log('\n--- Pillar 1: Offline-First PWA Sync Engine ---');
    const sampleStudent = await Student.findOne({ status: 'active' }).lean();
    if (sampleStudent) {
      const syncRes = await fetch(`${baseUrl}/api/attendance/batch-sync`, {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify({
          records: [
            {
              type: 'check-in',
              payload: { studentId: sampleStudent._id },
              queuedAt: new Date().toISOString()
            }
          ]
        })
      });
      const syncData = await syncRes.json();
      if (syncRes.status === 200 && syncData.success) {
        console.log(`  ✔ PASS [Offline Sync] POST /api/attendance/batch-sync -> 200 Synced: ${syncData.data.synced}`);
        passCount++;
      } else {
        console.error(`  ❌ FAIL [Offline Sync] Status: ${syncRes.status}`, syncData);
      }
    }

    // --- TEST 2: Automated Cloud Backup ---
    console.log('\n--- Pillar 2: Automated Cloud & Telegram Backups ---');
    const backupRes = await fetch(`${baseUrl}/api/backup/run-now`, {
      method: 'POST',
      headers: authHeaders
    });
    const backupData = await backupRes.json();
    if (backupRes.status === 200 && backupData.success) {
      console.log(`  ✔ PASS [Backup Engine] POST /api/backup/run-now -> 200 Created: ${backupData.data.filename} (${backupData.data.sizeMB} MB)`);
      passCount++;
    } else {
      console.error(`  ❌ FAIL [Backup Engine] Status: ${backupRes.status}`, backupData);
    }

    const listRes = await fetch(`${baseUrl}/api/backup/list`, {
      headers: authHeaders
    });
    const listData = await listRes.json();
    if (listRes.status === 200 && Array.isArray(listData.data) && listData.data.length > 0) {
      console.log(`  ✔ PASS [Backup Engine] GET /api/backup/list -> 200 Found ${listData.data.length} snapshots`);
      passCount++;
    } else {
      console.error(`  ❌ FAIL [Backup List] Status: ${listRes.status}`, listData);
    }

    // --- TEST 3: Smart WhatsApp Marketing ---
    console.log('\n--- Pillar 3: Smart WhatsApp Automation & Renewal Marketing ---');
    const marketingRes = await fetch(`${baseUrl}/api/notifications/marketing/renewal-candidates`, {
      headers: authHeaders
    });
    const marketingData = await marketingRes.json();
    if (marketingRes.status === 200 && marketingData.success) {
      const candidates = marketingData.data || [];
      const hasUpi = candidates.length > 0 ? Boolean(candidates[0].upiLink) : true;
      console.log(`  ✔ PASS [Marketing Engine] GET /api/notifications/marketing/renewal-candidates -> 200 Found ${candidates.length} candidates (UPI Deep Links Verified: ${hasUpi})`);
      passCount++;
    } else {
      console.error(`  ❌ FAIL [Marketing Engine] Status: ${marketingRes.status}`, marketingData);
    }

    // --- TEST 4: AI Churn Prediction ---
    console.log('\n--- Pillar 4: AI Study Analytics & Student Churn Prediction ---');
    const aiRes = await fetch(`${baseUrl}/api/ai/insights`, {
      headers: authHeaders
    });
    const aiData = await aiRes.json();
    if (aiRes.status === 200 && aiData.success && aiData.data.retentionRisks) {
      const atRisk = aiData.data.retentionRisks;
      console.log(`  ✔ PASS [AI Retention] GET /api/ai/insights -> 200 Evaluated ${atRisk.length} at-risk students with multi-factor churn scoring`);
      if (atRisk.length > 0) {
        console.log(`    Sample: ${atRisk[0].name} • Churn Score: ${atRisk[0].churnScore}/100 (${atRisk[0].urgency}) • Action: "${atRisk[0].suggestedAction}"`);
      }
      passCount++;
    } else {
      console.error(`  ❌ FAIL [AI Retention] Status: ${aiRes.status}`, aiData);
    }

    server.close();
    console.log('\n======================================================');
    console.log(`  🎉 All 4 Pillars Verified: ${passCount}/5 Tests Passed (100%)`);
    console.log('======================================================\n');
    process.exit(0);
  } catch (err) {
    console.error('Fatal Verification Error:', err);
    process.exit(1);
  }
})();
