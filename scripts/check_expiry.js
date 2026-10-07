/**
 * Daily Membership Expiry Check Script
 * Runs via GitHub Actions — FREE (no Blaze plan needed)
 * 
 * What it does:
 *   - Finds students whose validTo < now → marks membershipStatus = 'expired'
 *   - Finds students whose validTo < now+7days → marks membershipStatus = 'grace'
 *   - Writes admin notification to Firestore
 * 
 * Setup:
 *   1. Go to Firebase Console → Project Settings → Service Accounts
 *   2. Click "Generate new private key" → Download JSON
 *   3. Go to GitHub repo → Settings → Secrets → Actions → New secret
 *   4. Name: FIREBASE_SERVICE_ACCOUNT  Value: paste the entire JSON content
 */

'use strict';

const admin = require('firebase-admin');

// Parse service account from GitHub Secret (stored as JSON string)
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function runExpiryCheck() {
  console.log('Starting daily membership expiry check...');
  console.log('Time (UTC):', new Date().toISOString());
  console.log('Time (IST):', new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }));

  const now = admin.firestore.Timestamp.now();
  const sevenDaysFromNow = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
  );

  try {
    const librariesSnap = await db.collection('libraries').get();
    let grandTotalExpired = 0;
    let grandTotalGrace = 0;

    for (const libraryDoc of librariesSnap.docs) {
      const libraryId = libraryDoc.id;
      const libraryName = libraryDoc.data().name ?? libraryId;
      const studentsRef = db.collection(`libraries/${libraryId}/students`);

      // ── Fetch students and check expiry in memory (avoids requiring composite indexes)
      const studentsSnap = await studentsRef.get();
      const expiredDocs = [];
      const graceDocs = [];

      for (const sDoc of studentsSnap.docs) {
        const data = sDoc.data();
        if (!data.validTo) continue;

        const validTo = data.validTo.toDate ? data.validTo.toDate() : new Date(data.validTo);
        const nowDate = now.toDate();
        const graceDate = sevenDaysFromNow.toDate();
        const currentStatus = (data.membershipStatus || 'active').toLowerCase();

        if (validTo < nowDate && currentStatus !== 'expired') {
          expiredDocs.push(sDoc);
        } else if (validTo >= nowDate && validTo <= graceDate && currentStatus === 'active') {
          graceDocs.push(sDoc);
        }
      }

      if (expiredDocs.length === 0 && graceDocs.length === 0) {
        console.log(`[${libraryName}] No changes needed.`);
        continue;
      }

      // ── Batch update (Firestore allows 500 writes per batch)
      const batches = [];
      let batch = db.batch();
      let opCount = 0;

      const flushBatch = async () => {
        if (opCount > 0) {
          batches.push(batch.commit());
          batch = db.batch();
          opCount = 0;
        }
      };

      for (const doc of expiredDocs) {
        batch.update(doc.ref, {
          membershipStatus: 'expired',
          updatedAt: now,
        });
        opCount++;
        if (opCount >= 490) await flushBatch();
      }

      for (const doc of graceDocs) {
        batch.update(doc.ref, {
          membershipStatus: 'grace',
          updatedAt: now,
        });
        opCount++;
        if (opCount >= 490) await flushBatch();
      }

      await flushBatch();
      await Promise.all(batches);

      // ── Write admin notification
      await db.collection(`libraries/${libraryId}/notifications`).add({
        type: 'expiry_check',
        message: `${expiredDocs.length} student(s) expired, ${graceDocs.length} entering grace period.`,
        expired: expiredDocs.length,
        grace: graceDocs.length,
        createdAt: now,
        read: false,
      });

      grandTotalExpired += expiredDocs.length;
      grandTotalGrace += graceDocs.length;
      console.log(`[${libraryName}] Marked ${expiredDocs.length} expired, ${graceDocs.length} grace.`);
    }

    console.log(`\nDone! Total: ${grandTotalExpired} expired, ${grandTotalGrace} grace across ${librariesSnap.size} library/libraries.`);
    process.exit(0);

  } catch (err) {
    console.error('Expiry check FAILED:', err);
    process.exit(1);
  }
}

runExpiryCheck();
