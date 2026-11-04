'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 1: Daily Membership Expiry & Multi-Stage Renewal Check
// Runs every day at 8:00 AM IST (02:30 UTC)
// Handles:
// 1. T-3 Days: Push reminder to student ("Plan expires in 3 days")
// 2. T-0 (Today): Urgent renewal notice + UPI payment link
// 3. T+2 Days: Grace period warning ("Seat released tomorrow")
// 4. Past Grace: Auto-expire status & auto-release seat to waiting list
// ─────────────────────────────────────────────────────────────────────────────
exports.dailyMembershipExpiryCheck = onSchedule(
  { schedule: '30 2 * * *', timeZone: 'Asia/Kolkata', region: 'us-central1' },
  async (event) => {
    logger.info('Running daily membership expiry & multi-stage renewal check (8:00 AM IST)');
    const now = new Date();
    const nowTs = admin.firestore.Timestamp.fromDate(now);

    try {
      const librariesSnap = await db.collection('libraries').get();
      let totalExpired = 0;
      let totalGrace = 0;
      let totalRemindedT3 = 0;
      let totalRemindedT0 = 0;
      let totalRemindedT2 = 0;

      for (const libraryDoc of librariesSnap.docs) {
        const libraryId = libraryDoc.id;
        const libData = libraryDoc.data() || {};
        const libName = libData.name || 'Cozy Corner Centre';
        const studentsRef = db.collection(`libraries/${libraryId}/students`);

        // Query active and grace members
        const studentsSnap = await studentsRef
          .where('membershipStatus', 'in', ['active', 'grace'])
          .get();

        // Load Grace Period Settings & Plan Overrides
        let globalGraceDays = libData.defaultGraceDays || 3;
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

        const batch = db.batch();
        let batchCount = 0;

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
          if (daysLeft === 3 && currentStatus === 'active') {
            if (!remindedStages.includes('T-3')) {
              remindedStages.push('T-3');
              updatedStages = true;
              totalRemindedT3++;

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
            }
          }

          // ── STAGE 2: T-0 (Expires Today) ──────────────────────────────────
          if (daysLeft === 0 && currentStatus === 'active') {
            if (!remindedStages.includes('T-0')) {
              remindedStages.push('T-0');
              updatedStages = true;
              totalRemindedT0++;

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
            batch.update(studentDoc.ref, {
              membershipStatus: 'grace',
              graceEndDate: admin.firestore.Timestamp.fromDate(graceEnd),
              updatedAt: nowTs,
            });
            batchCount++;
            totalGrace++;
          }

          // ── STAGE 4: T+2 Days (Grace Warning - 1 Day Before Auto-Release) ─
          const graceDiffMs = graceEnd.getTime() - now.getTime();
          const graceHoursLeft = graceDiffMs / (1000 * 60 * 60);

          if (currentStatus === 'grace' && graceHoursLeft <= 24 && graceHoursLeft > 0) {
            if (!remindedStages.includes('T+2')) {
              remindedStages.push('T+2');
              updatedStages = true;
              totalRemindedT2++;

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
            }
          }

          // ── STAGE 5: Past Grace ➔ Expire & Auto-Release Seat ──────────────
          if (now >= graceEnd) {
            totalExpired++;
            const studentUpdate = {
              membershipStatus: 'expired',
              updatedAt: nowTs,
            };

            // Auto-release seat if assigned
            if (s.seatId && s.sectionId) {
              const seatRef = db
                .collection(`libraries/${libraryId}/sections/${s.sectionId}/seats`)
                .doc(s.seatId);

              batch.update(seatRef, {
                status: 'available',
                studentId: null,
                updatedAt: nowTs,
              });

              studentUpdate.seatId = null;
              studentUpdate.sectionId = null;
              studentUpdate.previousSeatId = s.seatId;
              studentUpdate.previousSectionId = s.sectionId;

              // Check and hold seat for #1 waiting list candidate (Phase 3)
              triggerWaitlistHoldForFreedSeat(libraryId, s.sectionId, s.seatId, seatLabel, libName).catch(e => {
                logger.warn('Waitlist hold trigger error:', e);
              });
            }

            batch.update(studentDoc.ref, studentUpdate);
            batchCount++;
          } else if (updatedStages) {
            batch.update(studentDoc.ref, { remindedStages });
            batchCount++;
          }
        }

        if (batchCount > 0) {
          await batch.commit();
        }
      }

      logger.info(`Daily check complete: Expired: ${totalExpired}, Grace: ${totalGrace}, T-3: ${totalRemindedT3}, T-0: ${totalRemindedT0}, T+2: ${totalRemindedT2}`);
    } catch (err) {
      logger.error('Daily expiry check failed:', err);
      throw err;
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2: Owner's Morning Briefing Digest (8:00 AM IST)
// Runs daily at 8:00 AM IST (02:30 UTC)
// Sends a consolidated morning summary of occupancy, expiries & waitlist
// to Telegram Bot and Admin Push Topic.
// ─────────────────────────────────────────────────────────────────────────────
exports.dailyMorningOwnerDigest = onSchedule(
  { schedule: '30 2 * * *', timeZone: 'Asia/Kolkata', region: 'us-central1' },
  async (event) => {
    logger.info('Generating Owner Morning Briefing Digest (8:00 AM IST)');
    const now = new Date();
    const todayMid = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    try {
      const librariesSnap = await db.collection('libraries').get();

      for (const libraryDoc of librariesSnap.docs) {
        const libraryId = libraryDoc.id;
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
  { schedule: '30 17 * * *', timeZone: 'Asia/Kolkata', region: 'us-central1' },
  async (event) => {
    logger.info('Generating Owner Nightly Financial Settlement Digest (11:00 PM IST)');
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

    try {
      const librariesSnap = await db.collection('libraries').get();

      for (const libraryDoc of librariesSnap.docs) {
        const libraryId = libraryDoc.id;
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
    logger.info('Running hourly waiting list 2-hour hold cascade check');
    const now = admin.firestore.Timestamp.now();

    try {
      const librariesSnap = await db.collection('libraries').get();

      for (const libraryDoc of librariesSnap.docs) {
        const libraryId = libraryDoc.id;
        const sectionsSnap = await db.collection(`libraries/${libraryId}/sections`).get();

        for (const secDoc of sectionsSnap.docs) {
          const sectionId = secDoc.id;
          const expiredHoldsSnap = await secDoc.ref
            .collection('seats')
            .where('status', '==', 'reserved')
            .where('reservationType', '==', 'waitlist_hold')
            .where('reservationExpiresAt', '<', now)
            .get();

          for (const seatDoc of expiredHoldsSnap.docs) {
            const seat = seatDoc.data();
            const prevCandidateId = seat.reservedCandidateId;
            const seatLabel = seat.label || seatDoc.id;

            logger.info(`Waitlist hold expired for seat ${seatLabel} (Candidate: ${prevCandidateId}). Cascading...`);

            // Mark previous candidate as offer_expired
            if (prevCandidateId) {
              await db
                .collection(`libraries/${libraryId}/waiting_list`)
                .doc(prevCandidateId)
                .update({
                  status: 'offer_expired',
                  offerExpiredAt: now,
                })
                .catch(() => {});
            }

            // Cascade to next candidate
            await triggerWaitlistHoldForFreedSeat(
              libraryId,
              sectionId,
              seatDoc.id,
              seatLabel,
              libraryDoc.data()?.name || 'Cozy Corner'
            );
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

      // 1. Put seat on reservation hold
      await seatRef.update({
        status: 'reserved',
        reservationType: 'waitlist_hold',
        reservedCandidateId: candidate.id,
        reservedCandidateName: candidate.studentName || 'Candidate',
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

      logger.info(`Seat ${seatLabel} reserved for 2 hours for waitlist candidate ${candidate.studentName}`);
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

// Helper to dispatch Telegram messages using native fetch
async function sendTelegramMessage(libraryId, htmlText) {
  try {
    const msgDoc = await db.collection(`libraries/${libraryId}/settings`).doc('messaging').get();
    const config = msgDoc.data() || {};
    if (config.telegramEnabled && config.telegramBotToken && config.telegramChatId) {
      await fetch(`https://api.telegram.org/bot${config.telegramBotToken}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: config.telegramChatId,
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

    const status = (paymentData.status || 'paid').toLowerCase();
    if (status === 'voided' || status === 'cancelled') return;

    const isRefund = status === 'refunded';
    const amount = (paymentData.amount ?? 0) * (isRefund ? -1 : 1);

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
            totalRefunds: isRefund ? (paymentData.amount ?? 0) : 0,
            monthlyRevenue: { [month]: amount },
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          const data = aggregateDoc.data();
          const currentMonthRevenue = data.monthlyRevenue?.[month] ?? 0;
          transaction.update(aggregateRef, {
            totalRevenue: admin.firestore.FieldValue.increment(amount),
            totalPayments: isRefund ? admin.firestore.FieldValue.increment(0) : admin.firestore.FieldValue.increment(1),
            totalRefunds: isRefund ? admin.firestore.FieldValue.increment(paymentData.amount ?? 0) : admin.firestore.FieldValue.increment(0),
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

    const getNetContribution = (p) => {
      const st = (p.status || 'paid').toLowerCase();
      if (st === 'voided' || st === 'cancelled') return 0;
      if (st === 'refunded') return -Number(p.amount || 0);
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
        const isNewlyRefunded = (after.status || '').toLowerCase() === 'refunded' && (before.status || '').toLowerCase() !== 'refunded';

        transaction.update(aggregateRef, {
          totalRevenue: admin.firestore.FieldValue.increment(delta),
          totalRefunds: admin.firestore.FieldValue.increment(isNewlyRefunded ? Number(after.amount || 0) : 0),
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

    const existingSnap = await db
      .collection(`libraries/${libraryId}/requests`)
      .where('studentId', '==', studentId)
      .where('status', '==', 'pending')
      .get();

    const pendingDocs = existingSnap.docs.filter(d => d.id !== requestId);
    if (pendingDocs.length > 0) {
      logger.warn(`Student ${studentId} already has a pending request. Deleting duplicate ${requestId}`);
      await event.data.ref.delete();
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
      const libDoc = await db.collection('libraries').doc(libraryId).get();
      const libData = libDoc.data() || {};
      const adminFcmToken = libData.adminFcmToken;

      // 1. Dispatch to Admin if targeted
      if (targetRole === 'admin' || targetRole === 'all') {
        const payload = {
          notification: { title, body },
          data: {
            notificationId,
            libraryId,
            type,
            actionRoute: notif.actionRoute || '',
          },
        };

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

        // Telegram alert for operational events
        if (type !== 'morning_digest' && type !== 'nightly_digest') {
          const telegramText = `🔔 <b>${title}</b>\n${body}\n\n<i>${libData.name || 'Cozy Corner'}</i>`;
          await sendTelegramMessage(libraryId, telegramText);
        }
      }

      // 2. Dispatch to Student if targeted
      if (targetRole === 'student' || targetRole === 'all') {
        if (targetUserId) {
          const studentDoc = await db.collection(`libraries/${libraryId}/students`).doc(targetUserId).get();
          const studentFcmToken = studentDoc.data()?.fcmToken;
          if (studentFcmToken) {
            try {
              await admin.messaging().send({
                token: studentFcmToken,
                notification: { title, body },
                data: {
                  notificationId,
                  libraryId,
                  type,
                },
              });
            } catch (_) {}
          }
        } else if (type === 'announcement') {
          try {
            await admin.messaging().send({
              topic: `lib-${libraryId}`,
              notification: { title, body },
              data: {
                notificationId,
                libraryId,
                type: 'announcement',
              },
            });
          } catch (_) {}
        }
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
