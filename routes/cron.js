const express = require('express');
const router = express.Router();
const {
  checkStudentExpiries,
  reconcileDailyAttendance,
  generateEODSummary,
  computeWeeklyBehaviorScores
} = require('../utils/cronJobs');

/**
 * Middleware to verify cron authorization (optional security)
 * Accepts Bearer token in Authorization header or secret in query param (?secret=xxx)
 * If CRON_SECRET is not configured in env, requests are permitted (convenience).
 */
const verifyCronSecret = (req, res, next) => {
  const configuredSecret = process.env.CRON_SECRET;
  if (!configuredSecret) return next();

  const authHeader = req.headers.authorization;
  const bearerToken = authHeader && authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : null;
  const querySecret = req.query.secret;

  if (bearerToken === configuredSecret || querySecret === configuredSecret) {
    return next();
  }

  return res.status(401).json({
    success: false,
    message: 'Unauthorized: Invalid or missing cron secret'
  });
};

/**
 * GET/POST /api/cron/daily
 * Master daily automated trigger:
 * - Checks student expiries & prepares WhatsApp notifications
 * - Reconciles unclosed student attendance sessions
 * - Computes End-of-Day revenue summary
 */
router.all('/daily', verifyCronSecret, async (req, res) => {
  const startTime = Date.now();
  console.log('⏰ [Cron Webhook] Daily automated tasks triggered...');

  try {
    const [expiryResult, attendanceClosed, eodSummary] = await Promise.allSettled([
      checkStudentExpiries({ isManual: false }),
      reconcileDailyAttendance(),
      generateEODSummary()
    ]);

    const durationMs = Date.now() - startTime;
    return res.status(200).json({
      success: true,
      timestamp: new Date().toISOString(),
      durationMs,
      results: {
        expiryAndReminders: expiryResult.status === 'fulfilled' ? expiryResult.value : { error: expiryResult.reason?.message },
        attendanceReconciled: attendanceClosed.status === 'fulfilled' ? attendanceClosed.value : { error: attendanceClosed.reason?.message },
        eodSummary: eodSummary.status === 'fulfilled' ? eodSummary.value : { error: eodSummary.reason?.message }
      }
    });
  } catch (error) {
    console.error('❌ [Cron Webhook] Daily job failed:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET/POST /api/cron/expiries
 * Targeted trigger for expiry check & WhatsApp reminder dispatch
 */
router.all('/expiries', verifyCronSecret, async (req, res) => {
  try {
    const result = await checkStudentExpiries({ isManual: true });
    return res.status(200).json({ success: true, result });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET/POST /api/cron/weekly
 * Weekly streak & behavior score batch computation
 */
router.all('/weekly', verifyCronSecret, async (req, res) => {
  try {
    const updated = await computeWeeklyBehaviorScores();
    return res.status(200).json({ success: true, updatedStudents: updated });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;