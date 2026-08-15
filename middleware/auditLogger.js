const AuditLog = require('../models/AuditLog');

/**
 * Logs an audit event asynchronously.
 * Does not block the main request flow.
 *
 * @param {Object} req - The Express request object.
 * @param {String} action - The action performed (e.g., 'create', 'update').
 * @param {String} module - The module affected (e.g., 'students', 'settings').
 * @param {String} details - Optional details about the action.
 */
const logAction = (req, action, module, details = '') => {
  // Fire and forget, catch errors internally so it doesn't break the app
  try {
    if (!req || !req.user) return;

    const ipAddress = req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '';
    const userAgent = req.headers['user-agent'] || '';

    const logEntry = new AuditLog({
      user: req.user._id || req.user.id,
      userName: req.user.name || 'Unknown',
      userRole: req.user.role || 'unknown',
      action,
      module,
      details: typeof details === 'object' ? JSON.stringify(details) : details,
      ipAddress,
      userAgent
    });

    logEntry.save().catch(err => console.error('Failed to save audit log:', err.message));
  } catch (error) {
    console.error('Error in logAction:', error.message);
  }
};

module.exports = {
  logAction
};
