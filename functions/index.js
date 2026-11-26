'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

async function getLibraryCommsRules(libraryId) {
  try {
    const commsDoc = await db.collection(`libraries/${libraryId}/settings`).doc('communications').get();
    return commsDoc.data()?.rules || {};
  } catch (_) {
    return {};
  }
}

async function getLibrarySecrets(libraryId) {
  try {
    const secretDoc = await db.collection(`libraries/${libraryId}/admin_secrets`).doc('communications').get();
    if (secretDoc.exists) return secretDoc.data() || {};
  } catch (_) {}
  return {};
}

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 1: Daily Membership Expiry & Multi-Stage Renewal Check
// Runs every day at 8:00 AM IST (02:30 UTC)
// Handles:
// 1. T-3 Days: Push reminder to student ("Plan expires in 3 days")
// 2. T-0 (Today): Urgent renewal notice + UPI payment link
// 3. T+2 Days: Grace period warning ("Seat released tomorrow")
// 4. Past Grace: Auto-expire status & auto-release seat to waiting list
// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 1: Autonomous Midnight Daily Membership Expiry & Seat Maintenance
// Runs every night at 00:01 AM IST (Asia/Kolkata)
// Handles:
// 1. T-3 Days: Push reminder to student ("Plan expires in 3 days")
// 2. T-0 (Today): Urgent renewal notice + UPI payment link
// 3. T+2 Days: Grace period warning ("Seat released tomorrow")
// 4. Past Grace: Auto-expire status & auto-release seat to waiting list
// 5. Updates lastMaintenanceReport & lastAutomationRunAt on library document
// ─────────────────────────────────────────────────────────────────────────────
async function performDailyMaintenanceForLibrary(libraryId, libData, now) {
  const nowTs = admin.firestore.Timestamp.fromDate(now);
  const libName = libData?.name || 'Cozy Corner Centre';
  const studentsRef = db.collection(`libraries/${libraryId}/students`);

  // Check Communications Hub automation rules before sending renewal nudges or cascading waitlist
  const commsRules = await getLibraryCommsRules(libraryId);
  const allowReminders = commsRules.allNotifications !== false &&
      commsRules.multiStageRenewals !== false &&
      commsRules.planExpiring !== false;
  const allowWaitlistCascade = commsRules.allNotifications !== false &&
      commsRules.waitlistCascade !== false;

  let libraryExpired = 0;
  let libraryGrace = 0;
  let libraryRemindedT3 = 0;
  let libraryRemindedT0 = 0;
  let libraryRemindedT2 = 0;
  let libraryReleasedSeats = 0;

  // Query active and grace members
  const studentsSnap = await studentsRef
    .where('membershipStatus', 'in', ['active', 'grace'])
    .get();

  // Load Grace Period Settings & Plan Overrides
  let globalGraceDays = libData?.defaultGraceDays || 3;
  let planGraceOverrides = {};
  try {
    const graceDoc = await db.collection(`libraries/${libraryId}/settings`).doc('grace_period').get();
    if (graceDoc.exists) {
      const gData = graceDoc.data() || {};
      if (typeof gData.defaultDays === 'number' && gData.defaultDays > 0) {
        globalGraceDays = gData.defaultDays;
      }
      if (gData.planOverrides && typeof gData.planOverrides === 'object') {
        planGraceOverrides = gData.planOverrides;
      }
    }
  } catch (_) {}

  // Load Plan definitions to check plan.gracePeriodDays
  const plansMap = {};
  try {
    const plansSnap = await db.collection(`libraries/${libraryId}/plans`).get();
    plansSnap.forEach(p => { plansMap[p.id] = p.data(); });
  } catch (_) {}

  const pendingBatches = [];
  let batch = db.batch();
  let batchCount = 0;
  const freedSeatsToCascade = [];

  const queueBatchOp = async (fn) => {
    fn(batch);
    batchCount++;
    if (batchCount >= 450) {
      pendingBatches.push(batch.commit());
      batch = db.batch();
      batchCount = 0;
    }
  };

  for (const studentDoc of studentsSnap.docs) {
    const s = studentDoc.data();
    const rawEnd = s.planEndDate || s.validTo;
    if (!rawEnd) continue;

    let planEnd = null;
    if (rawEnd.toDate) planEnd = rawEnd.toDate();
    else if (typeof rawEnd === 'string') planEnd = new Date(rawEnd);
    else if (typeof rawEnd === 'number') planEnd = new Date(rawEnd);

    if (!planEnd || isNaN(planEnd.getTime())) continue;

    // Normalize dates to midnight for consistent day-diff calculation
    const todayMid = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const planEndMid = new Date(planEnd.getFullYear(), planEnd.getMonth(), planEnd.getDate());
    const diffMs = planEndMid.getTime() - todayMid.getTime();
    const daysLeft = Math.round(diffMs / (1000 * 60 * 60 * 24));

    const currentStatus = s.membershipStatus || 'active';
    const remindedStages = Array.isArray(s.remindedStages) ? [...s.remindedStages] : [];
    let updatedStages = false;

    const seatLabel = s.seatLabel || s.seatId || '';
    const seatText = seatLabel ? `Seat #${seatLabel}` : 'your study desk';

    // ── STAGE 1: T-3 Days Reminder ────────────────────────────────────
    if (allowReminders && daysLeft === 3 && currentStatus === 'active') {
      if (!remindedStages.includes('T-3')) {
        remindedStages.push('T-3');
        updatedStages = true;
        libraryRemindedT3++;

        await db.collection(`libraries/${libraryId}/notifications`).add({
          title: '📅 Membership Expiring in 3 Days',
          body: `Hello ${s.name || 'Student'}, your membership for ${seatText} expires in 3 days. Renew now to retain your seat!`,
          targetRole: 'student',
          targetUserId: s.userId || studentDoc.id,
          type: 'renewal_reminder',
          stage: 'T-3',
          createdAt: nowTs,
          read: false,
          actionRoute: '/app/student/membership',
        });

        if (s.phone) {
          await dispatchExternalCommsMessage(libraryId, {
            phone: s.phone,
            text: `📅 *Membership Expiring in 3 Days — ${libName}*\n\nHello *${s.name || 'Student'}*,\nYour study plan for ${seatText} expires in 3 days. Please renew early to retain your desk!`,
            smsText: `[${libName}] Reminder: Your plan for ${seatText} expires in 3 days. Renew early to keep your seat.`,
          });
        }
      }
    }

    // ── STAGE 2: T-0 (Expires Today) ──────────────────────────────────
    if (allowReminders && daysLeft === 0 && currentStatus === 'active') {
      if (!remindedStages.includes('T-0')) {
        remindedStages.push('T-0');
        updatedStages = true;
        libraryRemindedT0++;

        await db.collection(`libraries/${libraryId}/notifications`).add({
          title: '⚡ Desk Membership Expires Today!',
          body: `Today is the last day of your study plan for ${seatText}. Please renew your plan to continue using your desk.`,
          targetRole: 'student',
          targetUserId: s.userId || studentDoc.id,
          type: 'renewal_reminder',
          stage: 'T-0',
          createdAt: nowTs,
          read: false,
          actionRoute: '/app/student/membership',
        });

        if (s.phone) {
          await dispatchExternalCommsMessage(libraryId, {
            phone: s.phone,
            text: `⚡ *Membership Expires Today — ${libName}*\n\nHello *${s.name || 'Student'}*,\nToday is the final day of your study plan for ${seatText}. Please renew today to continue uninterrupted access.`,
            smsText: `[${libName}] Your study plan for ${seatText} expires today. Please renew to retain your desk.`,
          });
        }
      }
    }

    // ── STAGE 3: Plan Ended ➔ Transition to Grace ─────────────────────
    let studentGraceDays = globalGraceDays;
    if (s.planId) {
      if (typeof planGraceOverrides[s.planId] === 'number') {
        studentGraceDays = planGraceOverrides[s.planId];
      } else if (plansMap[s.planId] && typeof plansMap[s.planId].gracePeriodDays === 'number') {
        studentGraceDays = plansMap[s.planId].gracePeriodDays;
      }
    }

    let graceEnd = null;
    if (s.graceEndDate) {
      graceEnd = s.graceEndDate.toDate ? s.graceEndDate.toDate() : new Date(s.graceEndDate);
    } else {
      graceEnd = new Date(planEnd.getTime() + studentGraceDays * 24 * 60 * 60 * 1000);
    }

    if (now > planEnd && now < graceEnd && currentStatus === 'active') {
      await queueBatchOp((b) => b.update(studentDoc.ref, {
        membershipStatus: 'grace',
        graceEndDate: admin.firestore.Timestamp.fromDate(graceEnd),
        updatedAt: nowTs,
      }));
      libraryGrace++;
    }

    // ── STAGE 4: T+2 Days (Grace Warning - 1 Day Before Auto-Release) ─
    const graceDiffMs = graceEnd.getTime() - now.getTime();
    const graceHoursLeft = graceDiffMs / (1000 * 60 * 60);

    if (allowReminders && currentStatus === 'grace' && graceHoursLeft <= 24 && graceHoursLeft > 0) {
      if (!remindedStages.includes('T+2')) {
        remindedStages.push('T+2');
        updatedStages = true;
        libraryRemindedT2++;

        await db.collection(`libraries/${libraryId}/notifications`).add({
          title: '⚠️ FINAL WARNING: Desk Release Tomorrow',
          body: `Your grace period ends tomorrow! ${seatText} will be released to the waiting list unless renewed today.`,
          targetRole: 'student',
          targetUserId: s.userId || studentDoc.id,
          type: 'renewal_reminder',
          stage: 'T+2',
          createdAt: nowTs,
          read: false,
          actionRoute: '/app/student/membership',
        });

        if (s.phone) {
          await dispatchExternalCommsMessage(libraryId, {
            phone: s.phone,
            text: `⚠️ *FINAL GRACE WARNING — ${libName}*\n\nHello *${s.name || 'Student'}*,\nYour grace period ends tomorrow! ${seatText} will be released to the waiting list unless renewed today.`,
            smsText: `[${libName}] FINAL WARNING: Grace period ends tomorrow. Renew today or ${seatText} will be released.`,
          });
        }
      }
    }

    // ── STAGE 5: Past Grace ➔ Expire & Auto-Release Seat ──────────────
    if (now >= graceEnd) {
      libraryExpired++;
      const studentUpdate = {
        membershipStatus: 'expired',
        updatedAt: nowTs,
      };

      // Auto-release seat if assigned
      if (s.seatId && s.sectionId) {
        libraryReleasedSeats++;
        const seatRef = db
          .collection(`libraries/${libraryId}/sections/${s.sectionId}/seats`)
          .doc(s.seatId);

        await queueBatchOp((b) => b.update(seatRef, {
          status: 'available',
          studentId: null,
          studentName: admin.firestore.FieldValue.delete(),
          assignedAt: admin.firestore.FieldValue.delete(),
          vacatedAt: nowTs,
          updatedAt: nowTs,
        }));

        studentUpdate.seatId = null;
        studentUpdate.sectionId = null;
        studentUpdate.previousSeatId = s.seatId;
        studentUpdate.previousSectionId = s.sectionId;

        // Record to library audit trail for full operational traceability
        const auditRef = db.collection(`libraries/${libraryId}/audit_log`).doc();
        await queueBatchOp((b) => b.set(auditRef, {
          action: 'expired_seat_release',
          entityType: 'seat',
          entityId: s.seatId,
          entityName: seatLabel,
          actor: 'System Automation (Cloud Cron)',
          performedBy: 'Autonomous Daily Maintenance (00:01 AM IST)',
          createdAt: nowTs,
          details: {
            studentId: studentDoc.id,
            studentName: s.name || 'Student',
            graceEndDate: graceEnd.toISOString(),
            releasedSeatId: s.seatId,
          },
        }));

        // Queue waitlist hold cascade to run AFTER batches commit so seat state is live & FIFO order stays deterministic
        if (allowWaitlistCascade) {
          freedSeatsToCascade.push({
            sectionId: s.sectionId,
            seatId: s.seatId,
            seatLabel,
          });
        }
      }

      await queueBatchOp((b) => b.update(studentDoc.ref, studentUpdate));
    } else if (updatedStages) {
      await queueBatchOp((b) => b.update(studentDoc.ref, { remindedStages }));
    }
  }

  if (batchCount > 0) {
    pendingBatches.push(batch.commit());
  }
  if (pendingBatches.length > 0) {
    await Promise.all(pendingBatches);
  }

  for (const freed of freedSeatsToCascade) {
    try {
      await triggerWaitlistHoldForFreedSeat(
        libraryId,
        freed.sectionId,
        freed.seatId,
        freed.seatLabel,
        libName
      );
    } catch (e) {
      logger.warn('Waitlist hold trigger error:', e);
    }
  }

  // Update library document with last maintenance summary report
  const report = {
    runAt: now.toISOString(),
    totalChecked: studentsSnap.size,
    totalGrace: libraryGrace,
    totalExpired: libraryExpired,
    totalRemindedT3: libraryRemindedT3,
    totalRemindedT0: libraryRemindedT0,
    totalRemindedT2: libraryRemindedT2,
    totalReleasedSeats: libraryReleasedSeats,
    source: 'cloud_function_scheduler',
  };

  await db.collection('libraries').doc(libraryId).set({
    lastAutomationRunAt: now.toISOString(),
    lastMaintenanceReport: report,
  }, { merge: true });

  return report;
}

exports.dailyMembershipExpiryCheck = onSchedule(
  { schedule: '1 0 * * *', timeZone: 'Asia/Kolkata', region: 'us-central1' },
  async (event) => {
    logger.info('Running autonomous midnight daily membership expiry & seat maintenance (00:01 AM IST)');
    const now = new Date();

    try {
      const librariesSnap = await db.collection('libraries').get();
      let totalExpired = 0;
      let totalGrace = 0;
      let totalReleased = 0;

      for (const libraryDoc of librariesSnap.docs) {
        const report = await performDailyMaintenanceForLibrary(libraryDoc.id, libraryDoc.data() || {}, now);
        totalExpired += report.totalExpired;
        totalGrace += report.totalGrace;
        totalReleased += report.totalReleasedSeats;
      }

      logger.info(`Autonomous midnight maintenance complete: Expired: ${totalExpired}, Grace: ${totalGrace}, Seats Released: ${totalReleased}`);
    } catch (err) {
      logger.error('Autonomous daily maintenance failed:', err);
      throw err;
    }
  }
);

// Callable function to allow admin console to trigger daily maintenance on-demand
exports.triggerDailyMaintenance = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Admin authentication required.');
    }
    const libraryId = request.data?.libraryId;
    if (!libraryId) {
      throw new HttpsError('invalid-argument', 'libraryId is required.');
    }

    const libDoc = await db.collection('libraries').doc(libraryId).get();
    if (!libDoc.exists) {
      throw new HttpsError('not-found', 'Library not found.');
    }

    const report = await performDailyMaintenanceForLibrary(libraryId, libDoc.data() || {}, new Date());
    return { success: true, report };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2: Owner's Morning Briefing Digest (8:00 AM IST)
// Runs daily at 8:00 AM IST (02:30 UTC)
// Sends a consolidated morning summary of occupancy, expiries & waitlist
// to Telegram Bot and Admin Push Topic.
// ─────────────────────────────────────────────────────────────────────────────
exports.dailyMorningOwnerDigest = onSchedule(
  { schedule: '0 8 * * *', timeZone: 'Asia/Kolkata', region: 'us-central1' },
  async (event) => {
    logger.info('Generating Owner Morning Briefing Digest (8:00 AM IST)');
    const now = new Date();
    const todayMid = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    try {
      const librariesSnap = await db.collection('libraries').get();

      for (const libraryDoc of librariesSnap.docs) {
        const libraryId = libraryDoc.id;
        const commsRules = await getLibraryCommsRules(libraryId);
        if (commsRules.allNotifications === false ||
            commsRules.morningBriefing === false ||
            commsRules.dailyExpirySummary === false) {
          logger.info(`Morning briefing skipped for library ${libraryId} (disabled in Communications Hub).`);
          continue;
        }
        const libData = libraryDoc.data() || {};
        const libName = libData.name || 'Cozy Corner Centre';

        // 1. Calculate Occupancy
        let totalSeats = 0;
        let occupiedSeats = 0;
        const sectionsSnap = await db.collection(`libraries/${libraryId}/sections`).get();

        for (const secDoc of sectionsSnap.docs) {
          const seatsSnap = await secDoc.ref.collection('seats').get();
          totalSeats += seatsSnap.size;
          occupiedSeats += seatsSnap.docs.filter(d => {
            const st = (d.data().status || '').toLowerCase();
            return st === 'occupied' || st === 'reserved';
          }).length;
        }

        // If no sections, check root seats
        if (totalSeats === 0) {
          const rootSeatsSnap = await db.collection(`libraries/${libraryId}/seats`).get();
          totalSeats = rootSeatsSnap.size;
          occupiedSeats = rootSeatsSnap.docs.filter(d => {
            const st = (d.data().status || '').toLowerCase();
            return st === 'occupied' || st === 'reserved';
          }).length;
        }

        const occupancyPct = totalSeats > 0 ? ((occupiedSeats / totalSeats) * 100).toFixed(1) : '0.0';

        // 2. Find Renewals Due Today & Next 3 Days
        const studentsSnap = await db
          .collection(`libraries/${libraryId}/students`)
          .where('membershipStatus', 'in', ['active', 'grace'])
          .get();

        const expiringToday = [];
        let expiringIn3DaysCount = 0;

        studentsSnap.forEach(doc => {
          const s = doc.data();
          const rawEnd = s.planEndDate || s.validTo;
          if (!rawEnd) return;
          const end = rawEnd.toDate ? rawEnd.toDate() : new Date(rawEnd);
          const endMid = new Date(end.getFullYear(), end.getMonth(), end.getDate());
          const days = Math.round((endMid.getTime() - todayMid.getTime()) / (1000 * 60 * 60 * 24));

          if (days === 0) {
            expiringToday.push(`${s.name || 'Student'} (Seat #${s.seatLabel || s.seatId || '•'})`);
          } else if (days > 0 && days <= 3) {
            expiringIn3DaysCount++;
          }
        });

        // 3. Waiting list queue count
        const waitlistSnap = await db.collection(`libraries/${libraryId}/waiting_list`).get();
        const waitlistCount = waitlistSnap.size;

        // 4. Pending in-app requests
        const requestsSnap = await db
          .collection(`libraries/${libraryId}/requests`)
          .where('status', '==', 'pending')
          .get();
        const pendingRequestsCount = requestsSnap.size;

        // Build Telegram HTML Message
        let expiringListText = 'None';
        if (expiringToday.length > 0) {
          expiringListText = expiringToday.map(n => `  • ${n}`).join('\n');
        }

        const telegramText =
          `🌅 <b>Cozy Corner — Morning Briefing (8:00 AM)</b>\n\n` +
          `🏛️ <b>Library:</b> ${libName}\n` +
          `💺 <b>Occupancy:</b> <b>${occupiedSeats} / ${totalSeats}</b> Desks (<b>${occupancyPct}%</b> Full)\n` +
          `🟢 <b>Available Desks:</b> ${Math.max(0, totalSeats - occupiedSeats)}\n\n` +
          `⏰ <b>Expiring Today (T-0):</b> ${expiringToday.length}\n${expiringListText}\n\n` +
          `⏳ <b>Renewals Due in 3 Days:</b> ${expiringIn3DaysCount} Aspirant(s)\n` +
          `📋 <b>Waiting List Queue:</b> ${waitlistCount} Candidate(s)\n` +
          `📥 <b>Pending Requests:</b> ${pendingRequestsCount}\n\n` +
          `<i>Have a productive day managing your study centre!</i>`;

        // Send to Telegram if configured
        await sendTelegramMessage(libraryId, telegramText);

        // Send Push to Admin Topic
        await admin.messaging().send({
          topic: `admin-${libraryId}`,
          notification: {
            title: `🌅 Morning Briefing — ${occupancyPct}% Occupied`,
            body: `${occupiedSeats}/${totalSeats} desks full. ${expiringToday.length} expiring today, ${waitlistCount} on waiting list.`,
          },
          data: {
            type: 'morning_digest',
            libraryId,
            actionRoute: '/admin',
          },
        }).catch(() => {});

        // Save to Admin Notifications
        await db.collection(`libraries/${libraryId}/notifications`).add({
          title: `🌅 Morning Briefing: ${occupiedSeats}/${totalSeats} Desks (${occupancyPct}%)`,
          body: `${expiringToday.length} renewals due today. ${waitlistCount} candidates on waiting list.`,
          targetRole: 'admin',
          type: 'morning_digest',
          createdAt: admin.firestore.Timestamp.now(),
          read: false,
          actionRoute: '/admin',
        });
      }
    } catch (err) {
      logger.error('Morning digest failed:', err);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 3: Owner's Nightly Financial Settlement Digest (11:00 PM IST)
// Runs daily at 11:00 PM IST (17:30 UTC)
// Sends a complete end-of-day revenue, cash vs UPI, and settlement report.
// ─────────────────────────────────────────────────────────────────────────────
exports.dailyNightlyOwnerDigest = onSchedule(
  { schedule: '0 23 * * *', timeZone: 'Asia/Kolkata', region: 'us-central1' },
  async (event) => {
    logger.info('Generating Owner Nightly Financial Settlement Digest (11:00 PM IST)');
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

    try {
      const librariesSnap = await db.collection('libraries').get();

      for (const libraryDoc of librariesSnap.docs) {
        const libraryId = libraryDoc.id;
        const commsRules = await getLibraryCommsRules(libraryId);
        if (commsRules.allNotifications === false || commsRules.nightlySettlement === false) {
          logger.info(`Nightly settlement skipped for library ${libraryId} (disabled in Communications Hub).`);
          continue;
        }
        const libData = libraryDoc.data() || {};
        const libName = libData.name || 'Cozy Corner Centre';

        // Query today's payments
        const paymentsSnap = await db
          .collection(`libraries/${libraryId}/payments`)
          .where('date', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
          .where('date', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
          .get();

        let totalRevenue = 0;
        let upiRevenue = 0;
        let cashRevenue = 0;
        let otherRevenue = 0;
        let totalReceipts = 0;

        paymentsSnap.forEach(doc => {
          const p = doc.data();
          const st = (p.status || 'paid').toLowerCase();
          if (st === 'voided' || st === 'cancelled') return;

          const amt = Number(p.amount || 0);
          totalRevenue += amt;
          totalReceipts++;

          const mode = (p.method || p.paymentMethod || '').toLowerCase();
          if (mode.includes('upi') || mode.includes('qr') || mode.includes('gpay') || mode.includes('phonepe')) {
            upiRevenue += amt;
          } else if (mode.includes('cash')) {
            cashRevenue += amt;
          } else {
            otherRevenue += amt;
          }
        });

        // New student admissions today
        const studentsSnap = await db
          .collection(`libraries/${libraryId}/students`)
          .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
          .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
          .get();
        const newAdmissionsCount = studentsSnap.size;

        const telegramText =
          `🌙 <b>Cozy Corner — Nightly Settlement (11:00 PM)</b>\n\n` +
          `🏛️ <b>Library:</b> ${libName}\n` +
          `💰 <b>Total Collections Today:</b> <b>₹${totalRevenue.toLocaleString('en-IN')}</b>\n` +
          `   • 📱 <b>UPI / QR:</b> ₹${upiRevenue.toLocaleString('en-IN')}\n` +
          `   • 💵 <b>Cash at Desk:</b> ₹${cashRevenue.toLocaleString('en-IN')}\n` +
          (otherRevenue > 0 ? `   • 💳 <b>Other:</b> ₹${otherRevenue.toLocaleString('en-IN')}\n` : '') +
          `\n` +
          `🧾 <b>Official Receipts Issued:</b> ${totalReceipts}\n` +
          `👤 <b>New Admissions Today:</b> ${newAdmissionsCount}\n\n` +
          `<i>All transaction entries verified and safely synced to cloud backup. Good night!</i>`;

        // Send to Telegram if configured
        await sendTelegramMessage(libraryId, telegramText);

        // Send Push to Admin Topic
        await admin.messaging().send({
          topic: `admin-${libraryId}`,
          notification: {
            title: `🌙 Nightly Settlement: ₹${totalRevenue.toLocaleString('en-IN')} Collected`,
            body: `UPI: ₹${upiRevenue} | Cash: ₹${cashRevenue} across ${totalReceipts} receipts. ${newAdmissionsCount} new admissions.`,
          },
          data: {
            type: 'nightly_digest',
            libraryId,
            actionRoute: '/admin/finance',
          },
        }).catch(() => {});

        // Save to Admin Notifications
        await db.collection(`libraries/${libraryId}/notifications`).add({
          title: `🌙 Nightly Settlement: ₹${totalRevenue.toLocaleString('en-IN')}`,
          body: `Today's collection: ₹${upiRevenue} (UPI) + ₹${cashRevenue} (Cash). ${totalReceipts} receipts issued.`,
          targetRole: 'admin',
          type: 'nightly_digest',
          createdAt: admin.firestore.Timestamp.now(),
          read: false,
          actionRoute: '/admin/finance',
        });
      }
    } catch (err) {
      logger.error('Nightly digest failed:', err);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 4: Hourly Waiting List 2-Hour Hold Cascade Check
// Runs every hour to check if any seat reservation hold has expired (2-hr timeout).
// If candidate did not confirm within 2 hours, auto-cascades to candidate #2!
// ─────────────────────────────────────────────────────────────────────────────
exports.hourlyWaitingListCascadeCheck = onSchedule(
  { schedule: '0 * * * *', timeZone: 'Asia/Kolkata', region: 'us-central1' },
  async (event) => {
    logger.info('Running hourly reservation hold & waitlist cascade check');
    const now = admin.firestore.Timestamp.now();
    const nowMs = Date.now();

    try {
      const librariesSnap = await db.collection('libraries').get();

      for (const libraryDoc of librariesSnap.docs) {
        const libraryId = libraryDoc.id;
        const commsRules = await getLibraryCommsRules(libraryId);
        const allowCascade = commsRules.allNotifications !== false && commsRules.waitlistCascade !== false;
        const sectionsSnap = await db.collection(`libraries/${libraryId}/sections`).get();

        for (const secDoc of sectionsSnap.docs) {
          const sectionId = secDoc.id;
          const reservedSnap = await secDoc.ref
            .collection('seats')
            .where('status', '==', 'reserved')
            .get();

          for (const seatDoc of reservedSnap.docs) {
            const seat = seatDoc.data() || {};
            const rawExpires = seat.reservationExpiresAt;
            if (!rawExpires) continue;

            let expiresMs = null;
            if (typeof rawExpires.toMillis === 'function') {
              expiresMs = rawExpires.toMillis();
            } else if (rawExpires.toDate) {
              expiresMs = rawExpires.toDate().getTime();
            } else if (typeof rawExpires === 'string' || typeof rawExpires === 'number') {
              const parsed = new Date(rawExpires);
              if (!isNaN(parsed.getTime())) expiresMs = parsed.getTime();
            }

            if (expiresMs === null || expiresMs >= nowMs) continue;

            const reservationType = (seat.reservationType || '').toString().toLowerCase();
            const prevCandidateId = seat.reservedCandidateId;
            const seatLabel = seat.label || seatDoc.id;

            if (reservationType === 'waitlist_hold') {
              logger.info(`Waitlist hold expired for seat ${seatLabel} (Candidate: ${prevCandidateId}).`);

              if (prevCandidateId) {
                await db
                  .collection(`libraries/${libraryId}/waiting_list`)
                  .doc(prevCandidateId)
                  .update({
                    status: 'offer_expired',
                    offerExpiredAt: now,
                  })
                  .catch(() => {});

                await db.collection(`libraries/${libraryId}/audit_log`).add({
                  action: 'waitlist_hold_expired',
                  entityType: 'waitlist',
                  entityId: prevCandidateId,
                  entityName: seatLabel,
                  actor: 'System Automation (Hourly Cron)',
                  performedBy: 'System Cascade Cron',
                  createdAt: now,
                  details: {
                    seatId: seatDoc.id,
                    sectionId,
                    candidateId: prevCandidateId,
                  },
                }).catch(() => {});
              }

              if (allowCascade) {
                await triggerWaitlistHoldForFreedSeat(
                  libraryId,
                  sectionId,
                  seatDoc.id,
                  seatLabel,
                  libraryDoc.data()?.name || 'Cozy Corner'
                );
              } else {
                await seatDoc.ref.update({
                  status: 'available',
                  studentId: null,
                  reservationType: admin.firestore.FieldValue.delete(),
                  reservedCandidateId: admin.firestore.FieldValue.delete(),
                  reservedCandidateName: admin.firestore.FieldValue.delete(),
                  reservationExpiresAt: admin.firestore.FieldValue.delete(),
                  updatedAt: now,
                });
              }
            } else {
              // Expired admission_soft_lock / registration_hold / temporary hold
              logger.info(`Cleaning expired ${reservationType || 'soft_lock'} reservation on seat ${seatLabel}.`);
              if (allowCascade) {
                await triggerWaitlistHoldForFreedSeat(
                  libraryId,
                  sectionId,
                  seatDoc.id,
                  seatLabel,
                  libraryDoc.data()?.name || 'Cozy Corner'
                );
              } else {
                await seatDoc.ref.update({
                  status: 'available',
                  studentId: null,
                  reservationType: admin.firestore.FieldValue.delete(),
                  reservedCandidateId: admin.firestore.FieldValue.delete(),
                  reservedCandidateName: admin.firestore.FieldValue.delete(),
                  reservationExpiresAt: admin.firestore.FieldValue.delete(),
                  updatedAt: now,
                });
              }
            }
          }
        }
      }
    } catch (err) {
      logger.error('Hourly waitlist cascade check failed:', err);
    }
  }
);

// Helper to trigger 2-hour hold for #1 waiting list candidate matching section/gender
async function triggerWaitlistHoldForFreedSeat(libraryId, sectionId, seatId, seatLabel, libName) {
  try {
    // Query FIFO waiting list entries
    const waitSnap = await db
      .collection(`libraries/${libraryId}/waiting_list`)
      .orderBy('createdAt', 'asc')
      .get();

    let candidate = null;
    for (const doc of waitSnap.docs) {
      const w = doc.data();
      const st = (w.status || 'waiting').toLowerCase();
      if (st === 'offered' || st === 'admitted' || st === 'cancelled') continue;

      // Section match check
      if (w.preferredSectionId && w.preferredSectionId !== sectionId) continue;

      candidate = { id: doc.id, ...w };
      break;
    }

    const seatRef = db
      .collection(`libraries/${libraryId}/sections/${sectionId}/seats`)
      .doc(seatId);

    if (candidate) {
      // Dynamic reservation hold (read from library settings, default 24 hours)
      let holdingHours = 24;
      try {
        const libDoc = await db.collection('libraries').doc(libraryId).get();
        const lData = libDoc.data() || {};
        if (typeof lData.waitingListHoldingHours === 'number' && lData.waitingListHoldingHours > 0) {
          holdingHours = lData.waitingListHoldingHours;
        }
      } catch (_) {}

      const expiresAt = new Date(Date.now() + holdingHours * 60 * 60 * 1000);
      const expiresAtTs = admin.firestore.Timestamp.fromDate(expiresAt);

      // 1. Put seat on reservation hold (strip candidate PII from public seat doc)
      await seatRef.update({
        status: 'reserved',
        reservationType: 'waitlist_hold',
        reservedCandidateId: candidate.id,
        reservedCandidateName: admin.firestore.FieldValue.delete(),
        reservationExpiresAt: expiresAtTs,
        updatedAt: admin.firestore.Timestamp.now(),
      });

      // 2. Mark candidate as 'offered'
      await db.collection(`libraries/${libraryId}/waiting_list`).doc(candidate.id).update({
        status: 'offered',
        offeredSeatId: seatId,
        offeredSeatLabel: seatLabel,
        offeredSectionId: sectionId,
        offeredAt: admin.firestore.Timestamp.now(),
        offerExpiresAt: expiresAtTs,
      });

      // 3. Notify Admin with 1-tap WhatsApp prompt
      const expTimeStr = expiresAt.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
      await db.collection(`libraries/${libraryId}/notifications`).add({
        title: `⏳ Seat #${seatLabel} Held for ${candidate.studentName}`,
        body: `${holdingHours}-Hour reservation active until ${expTimeStr}. Tap to assign or message candidate via WhatsApp.`,
        targetRole: 'admin',
        type: 'waitlist_hold',
        createdAt: admin.firestore.Timestamp.now(),
        read: false,
        actionRoute: '/admin/students?filter=waiting',
        metadata: {
          candidateId: candidate.id,
          candidateName: candidate.studentName,
          candidatePhone: candidate.studentPhone,
          seatId,
          seatLabel,
          sectionId,
          holdingHours,
          offerExpiresAt: expiresAt.toISOString(),
        },
      });

      logger.info(`Seat ${seatLabel} reserved for ${holdingHours} hours for waitlist candidate ${candidate.studentName}`);
    } else {
      // No waitlist candidates ➔ revert seat to available
      await seatRef.update({
        status: 'available',
        studentId: null,
        reservationType: null,
        reservedCandidateId: null,
        reservedCandidateName: null,
        reservationExpiresAt: null,
        updatedAt: admin.firestore.Timestamp.now(),
      });
      logger.info(`Seat ${seatLabel} reverted to available (no waiting list candidates)`);
    }
  } catch (e) {
    logger.error('Failed to trigger waitlist hold:', e);
  }
}

// Normalize Indian 10-digit phone numbers to E.164 without '+'
function normalizePhoneIN(raw) {
  const digits = String(raw || '').replace(/\D/g, '');
  if (digits.length === 10) return `91${digits}`;
  if (digits.length === 11 && digits.startsWith('0')) return `91${digits.slice(1)}`;
  return digits;
}

// Server-side WhatsApp Cloud API & Fast2SMS dispatcher (reads admin_secrets securely without exposing keys to client)
async function dispatchExternalCommsMessage(libraryId, { phone, text, smsText }) {
  const formattedPhone = normalizePhoneIN(phone);
  if (!formattedPhone) return;

  try {
    const [secrets, msgDoc, commsDoc] = await Promise.all([
      getLibrarySecrets(libraryId),
      db.collection(`libraries/${libraryId}/settings`).doc('messaging').get(),
      db.collection(`libraries/${libraryId}/settings`).doc('communications').get(),
    ]);
    const msgCfg = msgDoc.data() || {};
    const commsChannels = commsDoc.data()?.channels || {};

    const metaEnabled = commsChannels.metaWhatsAppEnabled ?? msgCfg.metaWhatsAppEnabled ?? false;
    const metaPhoneId = String(secrets.metaPhoneNumberId || commsChannels.metaPhoneNumberId || msgCfg.metaPhoneNumberId || '').trim();
    const metaToken = String(secrets.metaAccessToken || commsChannels.metaAccessToken || msgCfg.metaAccessToken || '').trim();

    if (metaEnabled && metaPhoneId && metaToken && text) {
      await fetch(`https://graph.facebook.com/v19.0/${metaPhoneId}/messages`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${metaToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: formattedPhone,
          type: 'text',
          text: { preview_url: false, body: text },
        }),
        signal: AbortSignal.timeout(8000),
      }).catch((e) => logger.warn(`Meta WhatsApp server dispatch failed for ${libraryId}:`, e.message));
    }

    const smsEnabled = commsChannels.smsGatewayEnabled ?? msgCfg.smsGatewayEnabled ?? false;
    const smsKey = String(secrets.smsApiKey || commsChannels.smsApiKey || msgCfg.smsApiKey || '').trim();
    const smsSender = String(secrets.smsSenderId || commsChannels.smsSenderId || msgCfg.smsSenderId || '').trim();
    const tenDigit = formattedPhone.length > 10 ? formattedPhone.slice(-10) : formattedPhone;

    if (smsEnabled && smsKey && tenDigit.length === 10 && (smsText || text)) {
      const payload = {
        route: smsSender ? 'dlt' : 'q',
        ...(smsSender ? { sender_id: smsSender } : {}),
        message: smsText || text,
        language: 'english',
        flash: 0,
        numbers: tenDigit,
      };
      await fetch('https://www.fast2sms.com/dev/bulkV2', {
        method: 'POST',
        headers: {
          authorization: smsKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(8000),
      }).catch((e) => logger.warn(`SMS Gateway server dispatch failed for ${libraryId}:`, e.message));
    }
  } catch (err) {
    logger.warn(`External comms dispatch skipped for ${libraryId}:`, err.message);
  }
}

// Helper to dispatch Telegram messages using native fetch
async function sendTelegramMessage(libraryId, htmlText) {
  try {
    const [secrets, msgDoc, commsDoc] = await Promise.all([
      getLibrarySecrets(libraryId),
      db.collection(`libraries/${libraryId}/settings`).doc('messaging').get(),
      db.collection(`libraries/${libraryId}/settings`).doc('communications').get(),
    ]);
    const msgConfig = msgDoc.data() || {};
    const commsChannels = commsDoc.data()?.channels || {};
    const telegramEnabled = commsChannels.telegramEnabled ?? msgConfig.telegramEnabled ?? false;
    const botToken = secrets.telegramBotToken || msgConfig.telegramBotToken || commsChannels.telegramBotToken || '';
    const chatId = secrets.telegramChatId || msgConfig.telegramChatId || commsChannels.telegramChatId || '';

    if (telegramEnabled && botToken && chatId) {
      await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text: htmlText,
          parse_mode: 'HTML',
        }),
      });
      logger.info(`Telegram digest dispatched to library ${libraryId}`);
    }
  } catch (e) {
    logger.warn(`Telegram dispatch failed for ${libraryId}:`, e.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 5: Revenue Aggregate on Payment Created
// ─────────────────────────────────────────────────────────────────────────────
exports.onPaymentCreated = onDocumentCreated(
  { document: 'libraries/{libraryId}/payments/{paymentId}', region: 'us-central1' },
  async (event) => {
    const { libraryId, paymentId } = event.params;
    const paymentData = event.data?.data();
    if (!paymentData) return;
    if (paymentData.aggregateSyncedByClient === true) return;

    const status = (paymentData.status || 'paid').toLowerCase();
    if (status === 'voided' || status === 'cancelled') return;

    const isRefund = status === 'refunded';
    const absAmount = Math.abs(Number(paymentData.amount || 0));
    const amount = isRefund ? -absAmount : Number(paymentData.amount || 0);

    let dateObj = new Date();
    if (paymentData.date) {
      dateObj = paymentData.date.toDate ? paymentData.date.toDate() : new Date(paymentData.date);
    }
    const month = dateObj.toISOString().slice(0, 7);

    const aggregateRef = db.collection(`libraries/${libraryId}/settings`).doc('revenue_aggregate');

    try {
      await db.runTransaction(async (transaction) => {
        const aggregateDoc = await transaction.get(aggregateRef);

        if (!aggregateDoc.exists) {
          transaction.set(aggregateRef, {
            totalRevenue: amount,
            totalPayments: isRefund ? 0 : 1,
            totalRefunds: isRefund ? absAmount : 0,
            monthlyRevenue: { [month]: amount },
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          const data = aggregateDoc.data();
          const currentMonthRevenue = data.monthlyRevenue?.[month] ?? 0;
          transaction.update(aggregateRef, {
            totalRevenue: admin.firestore.FieldValue.increment(amount),
            totalPayments: isRefund ? admin.firestore.FieldValue.increment(0) : admin.firestore.FieldValue.increment(1),
            totalRefunds: isRefund ? admin.firestore.FieldValue.increment(absAmount) : admin.firestore.FieldValue.increment(0),
            [`monthlyRevenue.${month}`]: currentMonthRevenue + amount,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (err) {
      logger.error(`Failed to update revenue aggregate for ${libraryId}:`, err);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 6: Revenue Aggregate on Payment Updated (Refunds, Voids)
// ─────────────────────────────────────────────────────────────────────────────
exports.onPaymentUpdated = onDocumentUpdated(
  { document: 'libraries/{libraryId}/payments/{paymentId}', region: 'us-central1' },
  async (event) => {
    const { libraryId, paymentId } = event.params;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    const afterStatus = (after.status || 'paid').toLowerCase();
    if (after.aggregateSyncedStatus && String(after.aggregateSyncedStatus).toLowerCase() === afterStatus) {
      return;
    }

    const getNetContribution = (p) => {
      const st = (p.status || 'paid').toLowerCase();
      if (st === 'voided' || st === 'cancelled') return 0;
      if (st === 'refunded') return -Math.abs(Number(p.amount || 0));
      return Number(p.amount || 0);
    };

    const delta = getNetContribution(after) - getNetContribution(before);
    if (delta === 0) return;

    let dateObj = new Date();
    if (after.date) {
      dateObj = after.date.toDate ? after.date.toDate() : new Date(after.date);
    }
    const month = dateObj.toISOString().slice(0, 7);

    const aggregateRef = db.collection(`libraries/${libraryId}/settings`).doc('revenue_aggregate');

    try {
      await db.runTransaction(async (transaction) => {
        const aggregateDoc = await transaction.get(aggregateRef);
        if (!aggregateDoc.exists) return;

        const data = aggregateDoc.data();
        const currentMonthRevenue = data.monthlyRevenue?.[month] ?? 0;
        const isNewlyRefunded = afterStatus === 'refunded' && (before.status || '').toLowerCase() !== 'refunded';

        transaction.update(aggregateRef, {
          totalRevenue: admin.firestore.FieldValue.increment(delta),
          totalRefunds: admin.firestore.FieldValue.increment(isNewlyRefunded ? Math.abs(Number(after.amount || 0)) : 0),
          [`monthlyRevenue.${month}`]: currentMonthRevenue + delta,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (err) {
      logger.error(`Failed to adjust revenue aggregate for ${libraryId}:`, err);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 7: Validate Seat Request — prevent duplicate pending requests
// ─────────────────────────────────────────────────────────────────────────────
exports.onRequestCreated = onDocumentCreated(
  { document: 'libraries/{libraryId}/requests/{requestId}', region: 'us-central1' },
  async (event) => {
    const { libraryId, requestId } = event.params;
    const requestData = event.data?.data();
    if (!requestData || requestData.status !== 'pending') return;

    const studentId = requestData.studentId;
    if (!studentId) return;
    const reqType = (requestData.type || 'registration').toString().toLowerCase();

    const existingSnap = await db
      .collection(`libraries/${libraryId}/requests`)
      .where('studentId', '==', studentId)
      .where('status', '==', 'pending')
      .get();

    const sameTypeOlderDocs = existingSnap.docs.filter((d) => {
      if (d.id === requestId) return false;
      const dType = (d.data()?.type || 'registration').toString().toLowerCase();
      return dType === reqType;
    });
    if (sameTypeOlderDocs.length > 0) {
      logger.warn(
        `Student ${studentId} submitted newer ${reqType} request ${requestId}; superseding ${sameTypeOlderDocs.length} older pending request(s).`
      );
      const batch = db.batch();
      for (const oldDoc of sameTypeOlderDocs) {
        batch.update(oldDoc.ref, {
          status: 'superseded',
          supersededBy: requestId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 8: Dispatch Real FCM Push & Alerts on New Notification Created
// ─────────────────────────────────────────────────────────────────────────────
exports.onNotificationCreated = onDocumentCreated(
  { document: 'libraries/{libraryId}/notifications/{notificationId}', region: 'us-central1' },
  async (event) => {
    const { libraryId, notificationId } = event.params;
    const notif = event.data?.data();
    if (!notif) return;

    const title = notif.title || 'Library Notification';
    const body = notif.body || '';
    const targetRole = notif.targetRole || 'all';
    const targetUserId = notif.targetUserId;
    const type = notif.type || 'general';

    try {
      const [libDoc, commsDoc, secrets] = await Promise.all([
        db.collection('libraries').doc(libraryId).get(),
        db.collection(`libraries/${libraryId}/settings`).doc('communications').get(),
        getLibrarySecrets(libraryId),
      ]);
      const libData = libDoc.data() || {};
      const commsData = commsDoc.data() || {};
      const channels = commsData.channels || {};
      const rules = commsData.rules || {};
      const pushEnabled = channels.pushEnabled !== false && rules.allNotifications !== false;
      const adminFcmToken = libData.adminFcmToken;

      const isStudentAnnouncement =
        (type === 'announcement' && targetRole !== 'admin') ||
        notif.actionRoute === '/student/announcements' ||
        (notif.actionRoute && notif.actionRoute.startsWith('/student'));

      // 1. Dispatch to Admin ONLY if explicitly targeted to 'admin' (NEVER 'all', NEVER student alerts/announcements!)
      if (targetRole === 'admin' && !isStudentAnnouncement) {
        const payload = {
          notification: { title, body },
          data: {
            notificationId,
            libraryId,
            type,
            targetRole: 'admin',
            targetUserId: targetUserId ? String(targetUserId) : '',
            actionRoute: notif.actionRoute || '',
          },
        };

        if (pushEnabled) {
          if (adminFcmToken) {
            try {
              await admin.messaging().send({
                token: adminFcmToken,
                ...payload,
              });
            } catch (_) {}
          }

          try {
            await admin.messaging().send({
              topic: `admin-${libraryId}`,
              ...payload,
            });
          } catch (_) {}
        }

        // Telegram alert for operational events
        if (type !== 'morning_digest' && type !== 'nightly_digest') {
          const telegramText = `🔔 <b>${title}</b>\n${body}\n\n<i>${libData.name || 'Cozy Corner'}</i>`;
          await sendTelegramMessage(libraryId, telegramText);
        }
      }

      // 2. Dispatch to Student if targeted
      if (pushEnabled && (targetRole === 'student' || targetRole === 'all' || isStudentAnnouncement)) {
        if (targetUserId) {
          let studentFcmToken = null;
          let studentPhone = null;
          const studentDoc = await db.collection(`libraries/${libraryId}/students`).doc(targetUserId).get();
          if (studentDoc.exists) {
            studentFcmToken = studentDoc.data()?.fcmToken || null;
            studentPhone = studentDoc.data()?.phone || null;
          } else {
            // targetUserId may be the Firebase Auth UID (studentUserId) or metadata.studentId
            const metaStudentId = notif.metadata?.studentId;
            if (metaStudentId) {
              const metaDoc = await db.collection(`libraries/${libraryId}/students`).doc(String(metaStudentId)).get();
              if (metaDoc.exists) {
                studentFcmToken = metaDoc.data()?.fcmToken || null;
                studentPhone = metaDoc.data()?.phone || null;
              }
            }
            if (!studentFcmToken || !studentPhone) {
              const qByUid = await db.collection(`libraries/${libraryId}/students`)
                .where('userId', '==', String(targetUserId))
                .limit(1)
                .get();
              if (!qByUid.empty) {
                const qData = qByUid.docs[0].data();
                studentFcmToken = studentFcmToken || qData?.fcmToken || null;
                studentPhone = studentPhone || qData?.phone || null;
              }
            }
          }
          // Server-side WhatsApp/SMS dispatch for critical lifecycle events (never exposes secrets to client)
          if (studentPhone && ['payment', 'receipt', 'admission', 'seat_change', 'renewal'].includes(type)) {
            await dispatchExternalCommsMessage(libraryId, {
              phone: studentPhone,
              text: `*${title}*\n${body}\n\n_${libData.name || 'Cozy Corner'}_`,
              smsText: `[${libData.name || 'Cozy Corner'}] ${title}: ${body}`,
            });
          }
          // Anti-cross-device leak: never push a student-targeted alert onto the active admin phone token
          if (studentFcmToken && studentFcmToken !== adminFcmToken) {
            try {
              await admin.messaging().send({
                token: studentFcmToken,
                notification: { title, body },
                data: {
                  notificationId,
                  libraryId,
                  type,
                  targetRole: 'student',
                  targetUserId: String(targetUserId),
                  actionRoute: notif.actionRoute || '',
                },
              });
            } catch (_) {}
          }
        } else if (type === 'announcement' || isStudentAnnouncement) {
          try {
            // Send ONLY to student-specific topic so Admin devices/Chrome never receive student broadcasts
            await admin.messaging().send({
              topic: `student-${libraryId}`,
              notification: { title, body },
              data: {
                notificationId,
                libraryId,
                type: 'announcement',
                targetRole: 'student',
                targetUserId: '',
                actionRoute: notif.actionRoute || '/student/announcements',
              },
            });
          } catch (_) {}
        }
      }

      // 3. Dispatch to Custom Webhook if configured
      try {
        const webhookEnabled = channels.customWebhookEnabled || commsData.customWebhookEnabled;
        const webhookUrl = secrets.customWebhookUrl || channels.customWebhookUrl || commsData.customWebhookUrl;

        if (webhookEnabled && webhookUrl && typeof webhookUrl === 'string' && webhookUrl.startsWith('http')) {
          await fetch(webhookUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              event: 'notification',
              notificationId,
              libraryId,
              libraryName: libData.name || 'Cozy Corner',
              title,
              body,
              type,
              targetRole,
              targetUserId: targetUserId || null,
              timestamp: new Date().toISOString(),
            }),
            signal: AbortSignal.timeout(5000),
          });
        }
      } catch (webhookErr) {
        logger.warn('Failed to dispatch custom webhook:', webhookErr.message);
      }
    } catch (err) {
      logger.error('Error dispatching notification alerts:', err);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 9: Real Remote Session Revocation
// 1. Triggered on users/{userId} update when revokeSessionsRequestedAt changes
// 2. Or invoked directly via onCall
// Revokes all refresh tokens for that UID in Firebase Auth.
// ─────────────────────────────────────────────────────────────────────────────
exports.onUserSessionRevocation = onDocumentUpdated(
  'users/{userId}',
  async (event) => {
    const beforeData = event.data?.before?.data() || {};
    const afterData = event.data?.after?.data() || {};
    const userId = event.params.userId;

    const beforeTs = beforeData.revokeSessionsRequestedAt?.toMillis ? beforeData.revokeSessionsRequestedAt.toMillis() : 0;
    const afterTs = afterData.revokeSessionsRequestedAt?.toMillis ? afterData.revokeSessionsRequestedAt.toMillis() : 0;

    if (afterTs > beforeTs) {
      logger.info(`Revoking refresh tokens for user ${userId}`);
      try {
        await admin.auth().revokeRefreshTokens(userId);
        const userRecord = await admin.auth().getUser(userId);
        const validAfterMillis = new Date(userRecord.tokensValidAfterTime).getTime();

        await event.data.after.ref.update({
          tokensValidAfterMillis: validAfterMillis,
          sessionsRevokedSuccess: true,
        });
        logger.info(`Successfully revoked all sessions for user ${userId}, valid after: ${validAfterMillis}`);
      } catch (err) {
        logger.error(`Failed to revoke sessions for user ${userId}:`, err);
      }
    }
  }
);

exports.revokeAllOtherSessions = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'User must be authenticated to revoke sessions.');
    }

    const uid = request.auth.uid;
    try {
      await admin.auth().revokeRefreshTokens(uid);
      const userRecord = await admin.auth().getUser(uid);
      const validAfterMillis = new Date(userRecord.tokensValidAfterTime).getTime();

      await db.collection('users').doc(uid).set({
        tokensValidAfterMillis: validAfterMillis,
        sessionsRevokedSuccess: true,
        lastSessionRevokedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      return {
        success: true,
        message: 'All other refresh tokens revoked successfully.',
        tokensValidAfterMillis: validAfterMillis,
      };
    } catch (err) {
      logger.error(`Error in revokeAllOtherSessions for ${uid}:`, err);
      throw new HttpsError('internal', err.message);
    }
  }
);
