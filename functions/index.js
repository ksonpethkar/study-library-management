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
// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2: Revenue Aggregate on Payment Created
// Triggers on every new payment doc → updates running revenue total in
// libraries/{libId}/settings/revenue_aggregate
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

    const status = (paymentData.status || 'paid').toLowerCase();
    const isVoid = status === 'voided' || status === 'cancelled';
    if (isVoid) return; // Voided payments have 0 revenue contribution

    const isRefund = status === 'refunded';
    const amount = (paymentData.amount ?? 0) * (isRefund ? -1 : 1);

    let dateObj = new Date();
    if (paymentData.date) {
      dateObj = paymentData.date.toDate ? paymentData.date.toDate() : new Date(paymentData.date);
    }
    const month = dateObj.toISOString().slice(0, 7); // e.g. '2026-10'

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

      logger.info(`Revenue aggregate updated for library ${libraryId} (Payment ${paymentId}): ${isRefund ? '-' : '+'}₹${Math.abs(amount)}`);
    } catch (err) {
      logger.error(`Failed to update revenue aggregate for ${libraryId}:`, err);
      throw err;
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2B: Revenue Aggregate on Payment Updated (Refunds, Voids, Edits)
// Handles status transitions: paid -> refunded/voided, amount adjustments
// ─────────────────────────────────────────────────────────────────────────────
exports.onPaymentUpdated = onDocumentUpdated(
  { document: 'libraries/{libraryId}/payments/{paymentId}', region: 'us-central1' },
  async (event) => {
    const { libraryId, paymentId } = event.params;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) return;

    // Helper to calculate net financial contribution
    const getNetContribution = (p) => {
      const st = (p.status || 'paid').toLowerCase();
      if (st === 'voided' || st === 'cancelled') return 0;
      if (st === 'refunded') return -Number(p.amount || 0);
      return Number(p.amount || 0);
    };

    const delta = getNetContribution(after) - getNetContribution(before);
    if (delta === 0) return; // No financial change

    let dateObj = new Date();
    if (after.date) {
      dateObj = after.date.toDate ? after.date.toDate() : new Date(after.date);
    }
    const month = dateObj.toISOString().slice(0, 7);

    const aggregateRef = db
      .collection(`libraries/${libraryId}/settings`)
      .doc('revenue_aggregate');

    try {
      await db.runTransaction(async (transaction) => {
        const aggregateDoc = await transaction.get(aggregateRef);
        if (!aggregateDoc.exists) return;

        const data = aggregateDoc.data();
        const currentMonthRevenue = data.monthlyRevenue?.[month] ?? 0;

        const isNewlyRefunded = (after.status || '').toLowerCase() === 'refunded' && (before.status || '').toLowerCase() !== 'refunded';
        const refundAmountIncrement = isNewlyRefunded ? Number(after.amount || 0) : 0;

        transaction.update(aggregateRef, {
          totalRevenue: admin.firestore.FieldValue.increment(delta),
          totalRefunds: admin.firestore.FieldValue.increment(refundAmountIncrement),
          [`monthlyRevenue.${month}`]: currentMonthRevenue + delta,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      logger.info(`Revenue aggregate adjusted for library ${libraryId} (Payment ${paymentId}): delta ₹${delta}`);
    } catch (err) {
      logger.error(`Failed to adjust revenue aggregate for ${libraryId}:`, err);
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

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 4: Dispatch Real FCM Push & Alerts on New Notification Created
// Triggers on: libraries/{libraryId}/notifications/{notificationId}
// Dispatches downstream FCM push to device tokens & topics, plus Telegram
// ─────────────────────────────────────────────────────────────────────────────
exports.onNotificationCreated = onDocumentCreated(
  { document: 'libraries/{libraryId}/notifications/{notificationId}', region: 'us-central1' },
  async (event) => {
    const { libraryId, notificationId } = event.params;
    const notif = event.data?.data();
    if (!notif) return;

    const title = notif.title || 'Library Notification';
    const body = notif.body || '';
    const targetRole = notif.targetRole || 'all'; // 'admin', 'student', 'all'
    const targetUserId = notif.targetUserId;
    const type = notif.type || 'general';

    try {
      // 1. Fetch library data for admin token and name
      const libDoc = await db.collection('libraries').doc(libraryId).get();
      const libData = libDoc.data() || {};
      const adminFcmToken = libData.adminFcmToken;

      // 2. Dispatch to Admin if targeted
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
            logger.info(`FCM push sent to admin of ${libraryId}`);
          } catch (e) {
            logger.warn(`Failed to send direct FCM to admin token: ${e.message}`);
          }
        }

        // Also broadcast to admin topic
        try {
          await admin.messaging().send({
            topic: `admin-${libraryId}`,
            ...payload,
          });
        } catch (_) {}

        // Check if Telegram alert is enabled
        try {
          const msgDoc = await db.collection(`libraries/${libraryId}/settings`).doc('messaging').get();
          const msgConfig = msgDoc.data() || {};
          if (msgConfig.telegramEnabled && msgConfig.telegramBotToken && msgConfig.telegramChatId) {
            const text = `🔔 <b>${title}</b>\n${body}\n\n<i>${libData.name || 'Cozy Corner Centre'}</i>`;
            await fetch(`https://api.telegram.org/bot${msgConfig.telegramBotToken}/sendMessage`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                chat_id: msgConfig.telegramChatId,
                text: text,
                parse_mode: 'HTML',
              }),
            });
            logger.info(`Telegram alert dispatched for ${type} in library ${libraryId}`);
          }
        } catch (tgErr) {
          logger.warn(`Telegram dispatch failed: ${tgErr.message}`);
        }
      }

      // 3. Dispatch to Student if targeted
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
              logger.info(`FCM push sent to student ${targetUserId}`);
            } catch (e) {
              logger.warn(`Failed to send FCM to student: ${e.message}`);
            }
          }
        } else if (type === 'announcement') {
          // Broadcast to all enrolled students
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
            logger.info(`Broadcast FCM sent to topic lib-${libraryId}`);
          } catch (e) {
            logger.warn(`Failed to broadcast announcement to topic: ${e.message}`);
          }
        }
      }
    } catch (err) {
      logger.error('Error dispatching notification alerts:', err);
    }
  }
);
