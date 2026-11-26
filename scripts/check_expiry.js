/**
 * Daily Membership Expiry Check Script
 * Runs via GitHub Actions — FREE (no Blaze plan needed).
 *
 * Uses the unified `planEndDate` (falling back to legacy `validTo`) and
 * 3-tier grace period rules (`grace_period` overrides -> plan -> library default),
 * and skips libraries already maintained within the last 12 hours by Cloud Scheduler
 * so Firebase Spark and Blaze setups never conflict.
 */

'use strict';

const admin = require('firebase-admin');

if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
  console.error('FIREBASE_SERVICE_ACCOUNT secret is not configured.');
  process.exit(1);
}

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

function parseDateValue(raw) {
  if (!raw) return null;
  if (typeof raw.toDate === 'function') return raw.toDate();
  if (typeof raw === 'string' || typeof raw === 'number') {
    const parsed = new Date(raw);
    return isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

async function sendFreeTelegramMessage(botToken, chatId, text) {
  if (!botToken || !chatId || !text) return;
  try {
    await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        parse_mode: 'HTML',
        disable_web_page_preview: true,
      }),
    });
  } catch (err) {
    console.warn('Telegram send failed (non-fatal):', err?.message || err);
  }
}

async function getCommsConfig(libraryId) {
  let rules = {};
  let channels = {};
  let secrets = {};
  try {
    const [commsDoc, secretDoc] = await Promise.all([
      db.collection(`libraries/${libraryId}/settings`).doc('communications').get(),
      db.collection(`libraries/${libraryId}/admin_secrets`).doc('communications').get(),
    ]);
    if (commsDoc.exists) {
      const cData = commsDoc.data() || {};
      rules = cData.rules || {};
      channels = cData.channels || {};
    }
    if (secretDoc.exists) {
      secrets = secretDoc.data() || {};
    }
  } catch (_) {}
  return { rules, channels, secrets };
}

async function runExpiryCheck() {
  console.log('Starting daily membership expiry check...');
  console.log('Time (UTC):', new Date().toISOString());
  console.log('Time (IST):', new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }));

  const nowDate = new Date();
  const nowTs = admin.firestore.Timestamp.fromDate(nowDate);

  try {
    const librariesSnap = await db.collection('libraries').get();
    let grandTotalExpired = 0;
    let grandTotalGrace = 0;
    let grandReleasedSeats = 0;

    for (const libraryDoc of librariesSnap.docs) {
      const libraryId = libraryDoc.id;
      const libData = libraryDoc.data() || {};
      const libraryName = libData.name ?? libraryId;

      // Avoid clobbering active Cloud Functions maintenance if it already ran recently
      const lastReport = libData.lastMaintenanceReport || {};
      const lastRunDate = parseDateValue(libData.lastAutomationRunAt || lastReport.runAt);
      if (
        lastReport.source === 'cloud_function_scheduler' &&
        lastRunDate &&
        nowDate.getTime() - lastRunDate.getTime() < 12 * 60 * 60 * 1000
      ) {
        console.log(`[${libraryName}] Skipping: Cloud Scheduler already ran at ${lastRunDate.toISOString()}.`);
        continue;
      }

      const { rules: commsRules, channels: commsChannels, secrets: commsSecrets } =
        await getCommsConfig(libraryId);

      // 1) Release expired 5-minute registration soft-locks (free Spark seat cleanup)
      let expiredHoldsReleased = 0;
      if (commsRules.waitlistCascade !== false) {
        try {
          const sectionsSnap = await db.collection(`libraries/${libraryId}/sections`).get();
          for (const secDoc of sectionsSnap.docs) {
            const seatsSnap = await secDoc.ref
              .collection('seats')
              .where('status', '==', 'reserved')
              .get();
            for (const seatDoc of seatsSnap.docs) {
              const sData = seatDoc.data() || {};
              const exp = parseDateValue(sData.reservationExpiresAt);
              if (exp && exp <= nowDate) {
                expiredHoldsReleased++;
                await seatDoc.ref.update({
                  status: 'available',
                  reservationType: admin.firestore.FieldValue.delete(),
                  reservedCandidateId: admin.firestore.FieldValue.delete(),
                  reservedCandidateName: admin.firestore.FieldValue.delete(),
                  reservationExpiresAt: admin.firestore.FieldValue.delete(),
                  updatedAt: nowTs,
                });
              }
            }
          }
        } catch (_) {}
      }

      if (commsRules.autoExpiryGrace === false) {
        console.log(`[${libraryName}] Auto expiry/grace paused in Communications Hub (released ${expiredHoldsReleased} expired holds).`);
      }

      let globalGraceDays = typeof libData.defaultGraceDays === 'number' ? libData.defaultGraceDays : 3;
      let planGraceOverrides = {};
      try {
        const graceDoc = await db.collection(`libraries/${libraryId}/settings`).doc('grace_period').get();
        if (graceDoc.exists) {
          const gData = graceDoc.data() || {};
          if (typeof gData.defaultDays === 'number' && gData.defaultDays >= 0) {
            globalGraceDays = gData.defaultDays;
          }
          if (gData.planOverrides && typeof gData.planOverrides === 'object') {
            planGraceOverrides = gData.planOverrides;
          }
        }
      } catch (_) {}

      const plansMap = {};
      try {
        const plansSnap = await db.collection(`libraries/${libraryId}/plans`).get();
        plansSnap.forEach((p) => {
          plansMap[p.id] = p.data() || {};
        });
      } catch (_) {}

      const studentsSnap = commsRules.autoExpiryGrace === false
        ? { docs: [], size: 0 }
        : await db
            .collection(`libraries/${libraryId}/students`)
            .where('membershipStatus', 'in', ['active', 'grace'])
            .get();

      let libraryExpired = 0;
      let libraryGrace = 0;
      let libraryReleased = 0;

      const commits = [];
      let batch = db.batch();
      let opCount = 0;

      const queueOp = (fn) => {
        fn(batch);
        opCount++;
        if (opCount >= 450) {
          commits.push(batch.commit());
          batch = db.batch();
          opCount = 0;
        }
      };

      for (const sDoc of studentsSnap.docs) {
        const data = sDoc.data() || {};
        const planEnd = parseDateValue(data.planEndDate || data.validTo);
        if (!planEnd) continue;

        let studentGraceDays = globalGraceDays;
        if (data.planId) {
          if (typeof planGraceOverrides[data.planId] === 'number') {
            studentGraceDays = planGraceOverrides[data.planId];
          } else if (plansMap[data.planId] && typeof plansMap[data.planId].gracePeriodDays === 'number') {
            studentGraceDays = plansMap[data.planId].gracePeriodDays;
          }
        }

        const parsedGraceEnd = parseDateValue(data.graceEndDate);
        const graceEnd =
          parsedGraceEnd && parsedGraceEnd > planEnd
            ? parsedGraceEnd
            : new Date(planEnd.getTime() + studentGraceDays * 24 * 60 * 60 * 1000);

        const currentStatus = (data.membershipStatus || 'active').toLowerCase();

        if (nowDate >= graceEnd) {
          libraryExpired++;
          const studentUpdate = {
            membershipStatus: 'expired',
            updatedAt: nowTs,
          };

          if (data.seatId && data.sectionId) {
            libraryReleased++;
            const seatRef = db
              .collection(`libraries/${libraryId}/sections/${data.sectionId}/seats`)
              .doc(data.seatId);
            queueOp((b) =>
              b.update(seatRef, {
                status: 'available',
                studentId: null,
                studentName: admin.firestore.FieldValue.delete(),
                assignedAt: admin.firestore.FieldValue.delete(),
                vacatedAt: nowTs,
                updatedAt: nowTs,
              })
            );
            studentUpdate.seatId = null;
            studentUpdate.sectionId = null;
            studentUpdate.previousSeatId = data.seatId;
            studentUpdate.previousSectionId = data.sectionId;
          }

          queueOp((b) => b.update(sDoc.ref, studentUpdate));
        } else if (nowDate > planEnd && nowDate < graceEnd && currentStatus === 'active') {
          libraryGrace++;
          queueOp((b) =>
            b.update(sDoc.ref, {
              membershipStatus: 'grace',
              graceEndDate: admin.firestore.Timestamp.fromDate(graceEnd),
              updatedAt: nowTs,
            })
          );
        }
      }

      if (opCount > 0) {
        commits.push(batch.commit());
      }
      if (commits.length > 0) {
        await Promise.all(commits);
      }

      await db.collection('libraries').doc(libraryId).set(
        {
          lastAutomationRunAt: nowDate.toISOString(),
          lastMaintenanceReport: {
            runAt: nowDate.toISOString(),
            totalChecked: studentsSnap.size,
            totalGrace: libraryGrace,
            totalExpired: libraryExpired,
            totalReleasedSeats: libraryReleased,
            source: 'github_actions_cron',
          },
        },
        { merge: true }
      );

      if (libraryExpired > 0 || libraryGrace > 0) {
        await db.collection(`libraries/${libraryId}/notifications`).add({
          title: 'Daily Expiry & Grace Sync Complete',
          body: `${libraryExpired} expired (${libraryReleased} seat(s) released), ${libraryGrace} moved to grace period.`,
          targetRole: 'admin',
          type: 'expiry_check',
          actionRoute: '/admin',
          expired: libraryExpired,
          grace: libraryGrace,
          releasedSeats: libraryReleased,
          createdAt: nowTs,
          read: false,
        });
      }

      // 2) Free Morning Briefing (8 AM IST) / Nightly Settlement (11 PM IST) Digest
      try {
        const istHour = Number(
          new Intl.DateTimeFormat('en-US', {
            timeZone: 'Asia/Kolkata',
            hour: '2-digit',
            hour12: false,
          }).format(nowDate)
        );
        const istDateKey = new Intl.DateTimeFormat('en-CA', {
          timeZone: 'Asia/Kolkata',
        }).format(nowDate);
        const isMorning = istHour < 14;
        const digestKey = isMorning ? `morning_${istDateKey}` : `nightly_${istDateKey}`;
        const digestAllowed = isMorning
          ? commsRules.morningBriefing !== false
          : commsRules.nightlySettlement !== false;

        if (digestAllowed && libData.lastFreeDigestKey !== digestKey) {
          const allStudentsSnap = await db.collection(`libraries/${libraryId}/students`).get();
          let activeCount = 0;
          let graceCount = 0;
          let expiringSoonCount = 0;
          const threeDaysMs = 3 * 24 * 60 * 60 * 1000;

          for (const st of allStudentsSnap.docs) {
            const d = st.data() || {};
            const mStatus = (d.membershipStatus || '').toLowerCase();
            if (mStatus === 'active') activeCount++;
            if (mStatus === 'grace') graceCount++;
            const pEnd = parseDateValue(d.planEndDate || d.validTo);
            if (
              (mStatus === 'active' || mStatus === 'grace') &&
              pEnd &&
              pEnd >= nowDate &&
              pEnd.getTime() - nowDate.getTime() <= threeDaysMs
            ) {
              expiringSoonCount++;
            }
          }

          const title = isMorning ? '☀️ Morning Library Briefing' : '🌙 Nightly Library Summary';
          const summaryBody =
            `Active: ${activeCount} • Grace: ${graceCount} • Expiring ≤3d: ${expiringSoonCount}` +
            (libraryExpired > 0 || libraryReleased > 0
              ? ` • Today Expired: ${libraryExpired}, Seats Released: ${libraryReleased}`
              : '');

          await db.collection(`libraries/${libraryId}/notifications`).add({
            title,
            body: summaryBody,
            targetRole: 'admin',
            type: 'digest',
            actionRoute: '/admin',
            createdAt: nowTs,
            read: false,
          });

          if (commsChannels.telegramEnabled === true) {
            const botToken = (commsSecrets.telegramBotToken || '').trim();
            const chatId = (commsSecrets.telegramChatId || '').trim();
            if (botToken && chatId) {
              await sendFreeTelegramMessage(
                botToken,
                chatId,
                `<b>${title} — ${libraryName}</b>\n${summaryBody}`
              );
            }
          }

          await db.collection('libraries').doc(libraryId).set(
            { lastFreeDigestKey: digestKey },
            { merge: true }
          );
        }
      } catch (digestErr) {
        console.warn(`[${libraryName}] Digest skipped:`, digestErr?.message || digestErr);
      }

      grandTotalExpired += libraryExpired;
      grandTotalGrace += libraryGrace;
      grandReleasedSeats += libraryReleased;
      console.log(
        `[${libraryName}] Expired: ${libraryExpired}, Grace: ${libraryGrace}, Seats Released: ${libraryReleased}.`
      );
    }

    console.log(
      `\nDone! Total: ${grandTotalExpired} expired, ${grandTotalGrace} grace, ${grandReleasedSeats} seats released across ${librariesSnap.size} library/libraries.`
    );
    process.exit(0);
  } catch (err) {
    console.error('Expiry check FAILED:', err);
    process.exit(1);
  }
}

runExpiryCheck();
