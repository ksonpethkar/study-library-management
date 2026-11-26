/**
 * Cozy Corner — Automated Real-Time System Health & Invariant Audit
 * 
 * Audits all 7 operational scenarios across the live Firestore database:
 * 1. Profile photo integrity & shared/swapped avatar collisions
 * 2. Desk ↔ Student double-binding & ghost occupancy
 * 3. 5-minute zombie cart holds & expired reservation soft-locks
 * 4. Identity uniqueness (duplicate Aadhaar / phone numbers)
 * 5. Raw coordinate ID leaks (`_r_c`) and recursive prefix anomalies (`Seat Seat #`)
 * 6. Financial invariants (negative dues & overdue active memberships)
 * 7. Untouched pending admission/renewal requests (>48h)
 * 
 * Usage:
 *   node scripts/daily_system_health_audit.cjs
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

// Read Firebase CLI token with auto-refresh capability
const configFile = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');

function getToken() {
  if (fs.existsSync(configFile)) {
    try {
      const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
      return config.tokens?.access_token || null;
    } catch (_) {}
  }
  return null;
}

let token = getToken();

function refreshToken() {
  try {
    console.log('🔄 Access token expired. Refreshing token via Firebase CLI...');
    execSync('npx firebase projects:list', { stdio: 'ignore' });
    token = getToken();
    console.log('✓ Token successfully refreshed.');
  } catch (e) {
    console.warn('⚠️ Could not auto-refresh token:', e.message);
  }
}

const PROJECT_ID = 'study-lib-mgmt-2026';
const LIBRARY_ID = 'aPSMq8xSAjuZQh2fTtuY'; // Active library: The Cozy Corner Study Centre
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function fetchCollection(collectionPath) {
  if (!token) return [];
  let allDocs = [];
  let pageToken = '';
  try {
    do {
      const url = `${BASE_URL}/${collectionPath}?pageSize=100${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
      let res = await fetch(url, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (res.status === 401) {
        refreshToken();
        res = await fetch(url, {
          headers: { Authorization: `Bearer ${token}` }
        });
      }
      if (!res.ok) break;
      const data = await res.json();
      const docs = (data.documents || []).map(doc => {
        const id = doc.name.split('/').pop();
        const fields = {};
        for (const [k, v] of Object.entries(doc.fields || {})) {
          if ('stringValue' in v) fields[k] = v.stringValue;
          else if ('integerValue' in v) fields[k] = parseInt(v.integerValue, 10);
          else if ('doubleValue' in v) fields[k] = parseFloat(v.doubleValue);
          else if ('booleanValue' in v) fields[k] = v.booleanValue;
          else if ('timestampValue' in v) fields[k] = v.timestampValue;
          else if ('mapValue' in v) fields[k] = v.mapValue.fields;
          else fields[k] = v;
        }
        return { id, ...fields };
      });
      allDocs.push(...docs);
      pageToken = data.nextPageToken || '';
    } while (pageToken);
    return allDocs;
  } catch (e) {
    console.error(`Failed to fetch ${collectionPath}:`, e.message);
    return allDocs;
  }
}

async function runAudit() {
  console.log('===============================================================');
  console.log('🛡️  COZY CORNER — AUTONOMOUS REAL-TIME SYSTEM HEALTH AUDIT');
  console.log('📅  Time:', new Date().toLocaleString());
  console.log('🏢  Library ID:', LIBRARY_ID);
  console.log('===============================================================\n');

  if (!token) {
    console.error('❌ Error: Firebase CLI authentication token not found. Run `firebase login` first.');
    process.exit(1);
  }

  // 1. Fetch live collections in parallel
  console.log('📡 Fetching live database collections from Firestore...');
  const [students, sections, requests, feedback] = await Promise.all([
    fetchCollection(`libraries/${LIBRARY_ID}/students`),
    fetchCollection(`libraries/${LIBRARY_ID}/sections`),
    fetchCollection(`libraries/${LIBRARY_ID}/requests`),
    fetchCollection(`libraries/${LIBRARY_ID}/feedback`)
  ]);

  // Fetch seats across all sections
  let allSeats = [];
  for (const sec of sections) {
    const seats = await fetchCollection(`libraries/${LIBRARY_ID}/sections/${sec.id}/seats`);
    allSeats.push(...seats.map(s => ({ ...s, sectionId: sec.id })));
  }

  console.log(`✓ Loaded: ${students.length} students, ${allSeats.length} seats across ${sections.length} sections, ${requests.length} requests, ${feedback.length} feedback items.\n`);

  const anomalies = [];
  const now = new Date();

  // -------------------------------------------------------------
  // INVARIANT 1: Profile Photo Integrity & Cross-Student Collisions
  // -------------------------------------------------------------
  const photoToStudents = {};
  for (const s of students) {
    const status = (s.membershipStatus || 'active').toLowerCase();
    if (status === 'active') {
      const photo = (s.photoUrl || s.photo || '').trim();
      if (!photo) {
        anomalies.push({
          level: 'ADVISORY',
          title: `Missing Photo: ${s.name || s.id}`,
          detail: `Active scholar #${s.membershipNumber || s.id} has no profile photo attached.`,
          fix: 'Upload passport photo in Student Detail screen.'
        });
      } else {
        const key = photo.length > 120 ? `${photo.substring(0, 80)}_${photo.length}` : photo;
        if (!photoToStudents[key]) photoToStudents[key] = [];
        photoToStudents[key].push(s);
      }
    }
  }

  for (const list of Object.values(photoToStudents)) {
    if (list.length > 1) {
      const names = list.map(s => `${s.name} (#${s.membershipNumber || s.id})`).join(' & ');
      anomalies.push({
        level: 'CRITICAL',
        title: 'Shared / Swapped Profile Photo Collision',
        detail: `${list.length} distinct scholars (${names}) share the exact same profile photo data!`,
        fix: 'Re-upload distinct verified photos for each affected scholar.'
      });
    }
  }

  // -------------------------------------------------------------
  // INVARIANT 2: Desk ↔ Student Double-Binding & Ghost Occupancy
  // -------------------------------------------------------------
  const studentMap = new Map(students.map(s => [s.id, s]));
  const seatMap = new Map(allSeats.map(s => [s.id, s]));

  for (const seat of allSeats) {
    if ((seat.status || '').toLowerCase() === 'occupied') {
      if (!seat.studentId) {
        anomalies.push({
          level: 'WARNING',
          title: `Ghost Occupancy on Desk ${seat.label || seat.id}`,
          detail: 'Desk is marked occupied but studentId is null/empty.',
          fix: 'Reset desk to available or assign student.'
        });
      } else {
        const student = studentMap.get(seat.studentId);
        if (!student) {
          anomalies.push({
            level: 'CRITICAL',
            title: `Orphaned Desk on ${seat.label || seat.id}`,
            detail: `Desk points to non-existent student ID: ${seat.studentId}.`,
            fix: 'Release desk to available pool.'
          });
        } else if (student.seatId !== seat.id) {
          anomalies.push({
            level: 'WARNING',
            title: `Desk ↔ Student Desync: Desk ${seat.label || seat.id}`,
            detail: `Desk points to ${student.name}, but student profile points to ${student.seatId || 'none'}.`,
            fix: 'Re-save desk assignment to re-align pointers.'
          });
        }
      }
    }
  }

  // -------------------------------------------------------------
  // INVARIANT 3: Expired 5-Minute Cart Soft-Locks (Zombie Holds)
  // -------------------------------------------------------------
  for (const seat of allSeats) {
    if ((seat.status || '').toLowerCase() === 'reserved') {
      if (seat.reservationExpiresAt) {
        const exp = new Date(seat.reservationExpiresAt);
        if (exp < now) {
          const minsAgo = Math.round((now - exp) / 60000);
          anomalies.push({
            level: 'WARNING',
            title: `Zombie Hold on Desk ${seat.label || seat.id}`,
            detail: `Cart reservation expired ${minsAgo} minutes ago (Type: ${seat.reservationType || 'hold'}).`,
            fix: 'Release hold back to available pool.'
          });
        }
      }
    }
  }

  // -------------------------------------------------------------
  // INVARIANT 4: Identity Uniqueness (Aadhaar & Contact Number)
  // -------------------------------------------------------------
  const phoneToStudents = {};
  const govIdToStudents = {};

  for (const s of students) {
    if ((s.membershipStatus || 'active').toLowerCase() === 'active') {
      const cleanPhone = (s.phone || '').replace(/\D/g, '');
      if (cleanPhone.length >= 10) {
        const stdPhone = cleanPhone.slice(-10);
        if (!phoneToStudents[stdPhone]) phoneToStudents[stdPhone] = [];
        phoneToStudents[stdPhone].push(s);
      }

      const cleanGovId = (s.govIdNumber || '').replace(/[\s-]/g, '').toUpperCase();
      if (cleanGovId.length >= 6) {
        if (!govIdToStudents[cleanGovId]) govIdToStudents[cleanGovId] = [];
        govIdToStudents[cleanGovId].push(s);
      }
    }
  }

  for (const [phone, list] of Object.entries(phoneToStudents)) {
    if (list.length > 1) {
      const names = list.map(s => `${s.name} (#${s.membershipNumber || s.id})`).join(' & ');
      anomalies.push({
        level: 'WARNING',
        title: `Shared Contact Number: ${phone}`,
        detail: `${list.length} scholars (${names}) share the same mobile phone.`,
        fix: 'Verify family relationship or merge duplicate accounts.'
      });
    }
  }

  for (const [govId, list] of Object.entries(govIdToStudents)) {
    if (list.length > 1) {
      const names = list.map(s => `${s.name} (#${s.membershipNumber || s.id})`).join(' & ');
      anomalies.push({
        level: 'CRITICAL',
        title: `Duplicate Aadhaar / Gov ID Collision: ${govId}`,
        detail: `${list.length} scholars (${names}) share the same identity document number.`,
        fix: 'Inspect physical documents and correct identity number.'
      });
    }
  }

  // -------------------------------------------------------------
  // INVARIANT 5: Raw Coordinate ID Leaks & Double Prefixes
  // -------------------------------------------------------------
  for (const seat of allSeats) {
    const label = seat.label || '';
    if (label.includes('_r') && label.includes('_c')) {
      anomalies.push({
        level: 'WARNING',
        title: `Raw Coordinate in Seat Label: ${label}`,
        detail: `Desk ${seat.id} has unformatted coordinate string instead of human desk number.`,
        fix: 'Rename desk label in Layout Studio.'
      });
    } else if (label.toLowerCase().includes('seat seat') || label.toLowerCase().includes('desk #seat')) {
      anomalies.push({
        level: 'WARNING',
        title: `Double Prefix in Seat Label: ${label}`,
        detail: `Desk label contains recursive double prefix.`,
        fix: 'Normalize seat label.'
      });
    }
  }

  for (const fb of feedback) {
    const seatNum = fb.seatNumber || '';
    if (seatNum.includes('_r') && seatNum.includes('_c')) {
      anomalies.push({
        level: 'WARNING',
        title: `Raw Coordinate in Feedback #${fb.id}`,
        detail: `Feedback record holds raw coordinate "${seatNum}".`,
        fix: 'Normalize via SeatHelper.formatDeskLabel.'
      });
    }
  }

  // -------------------------------------------------------------
  // INVARIANT 6: Financial Invariants & Overdue Subscriptions
  // -------------------------------------------------------------
  for (const s of students) {
    const due = parseFloat(s.pendingDueBalance || 0);
    if (due < -0.01) {
      anomalies.push({
        level: 'WARNING',
        title: `Negative Due Balance: ${s.name}`,
        detail: `Student shows negative due balance of ₹${Math.abs(due).toFixed(2)}.`,
        fix: 'Reset balance to ₹0 or record advance credit.'
      });
    }

    if ((s.membershipStatus || 'active').toLowerCase() === 'active' && s.planEndDate) {
      const expDate = new Date(s.planEndDate);
      const daysOverdue = Math.floor((now - expDate) / (1000 * 60 * 60 * 24));
      if (daysOverdue > 3) {
        anomalies.push({
          level: 'ADVISORY',
          title: `Overdue Membership: ${s.name}`,
          detail: `Plan expired ${daysOverdue} days ago (${s.planEndDate.substring(0, 10)}) without renewal.`,
          fix: 'Send WhatsApp renewal reminder or mark membership expired.'
        });
      }
    }
  }

  // -------------------------------------------------------------
  // INVARIANT 7: Untouched Pending Requests (>48 hours)
  // -------------------------------------------------------------
  for (const req of requests) {
    if ((req.status || 'pending').toLowerCase() === 'pending' && req.createdAt) {
      const created = new Date(req.createdAt);
      const hoursWaiting = Math.round((now - created) / (1000 * 60 * 60));
      if (hoursWaiting > 48) {
        anomalies.push({
          level: 'WARNING',
          title: `Untouched Pending Request (${req.type || 'admission'}): ${req.studentName || req.id}`,
          detail: `Submitted ${hoursWaiting} hours ago (${created.toLocaleDateString()}) and still awaiting counter review.`,
          fix: 'Open Requests Queue and approve or reject.'
        });
      }
    }
  }

  // -------------------------------------------------------------
  // SUMMARY SCORE CALCULATION
  // -------------------------------------------------------------
  const criticalCount = anomalies.filter(a => a.level === 'CRITICAL').length;
  const warningCount = anomalies.filter(a => a.level === 'WARNING').length;
  const advisoryCount = anomalies.filter(a => a.level === 'ADVISORY').length;

  const deduction = (criticalCount * 18.0) + (warningCount * 4.0) + (advisoryCount * 1.0);
  const healthScore = Math.max(10, Math.min(100, Math.round(100.0 - deduction)));

  console.log('---------------------------------------------------------------');
  console.log(`🏥  SYSTEM HEALTH SCORE: ${healthScore}%`);
  console.log(`🚨  Critical Issues: ${criticalCount}`);
  console.log(`⚠️   Warnings:        ${warningCount}`);
  console.log(`ℹ️   Advisories:      ${advisoryCount}`);
  console.log('---------------------------------------------------------------\n');

  if (anomalies.length === 0) {
    console.log('✅ CONGRATULATIONS: All 7 operational invariants are 100% HEALTHY!');
    console.log('   Zero anomalies or data discrepancies detected across all records.\n');
  } else {
    console.log(`DETAILED ANOMALIES (${anomalies.length}):\n`);
    anomalies.forEach((a, i) => {
      const badge = a.level === 'CRITICAL' ? '🚨 [CRITICAL]' : (a.level === 'WARNING' ? '⚠️  [WARNING] ' : 'ℹ️  [ADVISORY]');
      console.log(`${i + 1}. ${badge} ${a.title}`);
      console.log(`   Detail: ${a.detail}`);
      console.log(`   Fix:    ${a.fix}\n`);
    });
  }

  // -------------------------------------------------------------
  // GENERATE 1-TAP WHATSAPP ALERT LINK
  // -------------------------------------------------------------
  const statusEmoji = healthScore >= 90 ? '🟢' : (healthScore >= 70 ? '🟡' : '🔴');
  const dateStr = now.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  
  let waText = `🛡️ *Cozy Corner System Health Report*\n📅 ${dateStr}\n${statusEmoji} *Health Score:* ${healthScore}%\n🚨 Critical: ${criticalCount} | ⚠️ Warnings: ${warningCount} | ℹ️ Advisories: ${advisoryCount}\n\n`;
  
  if (anomalies.length === 0) {
    waText += `✅ *All 7 operational invariants are 100% healthy!* Zero anomalies detected.\n\n`;
  } else {
    waText += `*Active Anomalies (${anomalies.length}):*\n`;
    anomalies.slice(0, 6).forEach(a => {
      waText += `• [${a.level}] *${a.title}*\n  _${a.detail}_\n  👉 ${a.fix}\n\n`;
    });
    if (anomalies.length > 6) {
      waText += `...and ${anomalies.length - 6} more.\n\n`;
    }
  }
  waText += `🔗 *Sentinel Dashboard:* https://study-lib-mgmt-2026.web.app/app/admin/sentinel`;

  const waLink = `https://wa.me/?text=${encodeURIComponent(waText)}`;
  console.log('---------------------------------------------------------------');
  console.log('📲  1-TAP WHATSAPP ALERT LINK (Open in browser or click):');
  console.log(waLink);
  console.log('---------------------------------------------------------------\n');

  return { healthScore, criticalCount, warningCount, advisoryCount, anomalies };
}

runAudit();
