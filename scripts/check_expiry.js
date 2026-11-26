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

      const studentsSnap = await db
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
