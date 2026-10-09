'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 1: Daily Membership Expiry Check
// Runs every day at 8:00 AM IST (2:30 AM UTC)
// Marks expired students, notifies admin via Firestore notification doc
// ─────────────────────────────────────────────────────────────────────────────
exports.dailyMembershipExpiryCheck = onSchedule(
  { schedule: '30 2 * * *', timeZone: 'Asia/Kolkata', region: 'us-central1' },
  async (event) => {
    logger.info('Running daily membership expiry check');
    const now = admin.firestore.Timestamp.now();
    const sevenDaysFromNow = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    );

    try {
      // Get all libraries
      const librariesSnap = await db.collection('libraries').get();
      let totalExpired = 0;
      let totalExpiringSoon = 0;

      for (const libraryDoc of librariesSnap.docs) {
        const libraryId = libraryDoc.id;
        const studentsRef = db.collection(`libraries/${libraryId}/students`);

        // Find EXPIRED students (validTo < now AND status != 'expired')
        const expiredSnap = await studentsRef
          .where('validTo', '<', now)
          .where('membershipStatus', '!=', 'expired')
          .get();

        const batch = db.batch();

        for (const studentDoc of expiredSnap.docs) {
          batch.update(studentDoc.ref, {
            membershipStatus: 'expired',
            updatedAt: now,
          });
          totalExpired++;
        }

        // Find students expiring in next 7 days (for grace/reminder)
        const expiringSoonSnap = await studentsRef
          .where('validTo', '>', now)
          .where('validTo', '<', sevenDaysFromNow)
          .where('membershipStatus', '==', 'active')
          .get();

        for (const studentDoc of expiringSoonSnap.docs) {
          batch.update(studentDoc.ref, {
            membershipStatus: 'grace',
            updatedAt: now,
          });
          totalExpiringSoon++;
        }

        if (expiredSnap.size > 0 || expiringSoonSnap.size > 0) {
          await batch.commit();

          // Write a notification for admin dashboard
          await db.collection(`libraries/${libraryId}/notifications`).add({
            type: 'expiry_check',
            message: `${expiredSnap.size} student(s) expired, ${expiringSoonSnap.size} expiring soon.`,
            expired: expiredSnap.size,
            expiringSoon: expiringSoonSnap.size,
            createdAt: now,
            read: false,
          });
        }
      }

      logger.info(`Expiry check complete: ${totalExpired} expired, ${totalExpiringSoon} expiring soon`);
    } catch (err) {
      logger.error('Expiry check failed:', err);
      throw err;
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2: Revenue Aggregate on Payment Created
// Triggers on every new payment doc → updates running revenue total in
// libraries/{libId}/settings/revenue_aggregate
// This means the dashboard never needs to fetch 200+ payment docs
// ─────────────────────────────────────────────────────────────────────────────
exports.onPaymentCreated = onDocumentCreated(
  { document: 'libraries/{libraryId}/payments/{paymentId}', region: 'us-central1' },
  async (event) => {
    const { libraryId, paymentId } = event.params;
    const paymentData = event.data?.data();

    if (!paymentData) {
      logger.warn(`Payment ${paymentId} has no data, skipping aggregate update`);
      return;
    }

    const amount = paymentData.amount ?? 0;
    const month = new Date().toISOString().slice(0, 7); // e.g. '2026-10'

    const aggregateRef = db
      .collection(`libraries/${libraryId}/settings`)
      .doc('revenue_aggregate');

    try {
      await db.runTransaction(async (transaction) => {
        const aggregateDoc = await transaction.get(aggregateRef);

        if (!aggregateDoc.exists) {
          // First payment ever — initialize aggregate
          transaction.set(aggregateRef, {
            totalRevenue: amount,
            totalPayments: 1,
            monthlyRevenue: { [month]: amount },
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          const data = aggregateDoc.data();
          const currentMonthRevenue = data.monthlyRevenue?.[month] ?? 0;
          transaction.update(aggregateRef, {
            totalRevenue: admin.firestore.FieldValue.increment(amount),
            totalPayments: admin.firestore.FieldValue.increment(1),
            [`monthlyRevenue.${month}`]: currentMonthRevenue + amount,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      logger.info(`Revenue aggregate updated for library ${libraryId}: +₹${amount}`);
    } catch (err) {
      logger.error(`Failed to update revenue aggregate for ${libraryId}:`, err);
      throw err;
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 3: Validate Seat Request — prevent duplicate pending requests
// Triggers on request creation → if student already has pending, deletes new one
// ─────────────────────────────────────────────────────────────────────────────
exports.onRequestCreated = onDocumentCreated(
  { document: 'libraries/{libraryId}/requests/{requestId}', region: 'us-central1' },
  async (event) => {
    const { libraryId, requestId } = event.params;
    const requestData = event.data?.data();

    if (!requestData || requestData.status !== 'pending') return;

    const studentId = requestData.studentId;
    if (!studentId) return;

    // Check if there's already another pending request from this student
    const existingSnap = await db
      .collection(`libraries/${libraryId}/requests`)
      .where('studentId', '==', studentId)
      .where('status', '==', 'pending')
      .get();

    // If more than 1 pending (including the one just created), delete the duplicate
    const pendingDocs = existingSnap.docs.filter(d => d.id !== requestId);
    if (pendingDocs.length > 0) {
      logger.warn(`Student ${studentId} already has a pending request. Deleting duplicate ${requestId}`);
      await event.data.ref.delete();
    }
  }
);
