const jwt = require('jsonwebtoken');
const User = require('../models/User');

// ── In-memory user cache (avoids DB lookup on every API call) ──────────────
// Keyed by userId, expires after 60 seconds
const _userCache = new Map();
const USER_CACHE_TTL = 60 * 1000; // 60 seconds

function getCachedUser(userId) {
  const entry = _userCache.get(userId);
  if (!entry) return null;
  if (Date.now() - entry.ts > USER_CACHE_TTL) { _userCache.delete(userId); return null; }
  return entry.user;
}

function setCachedUser(userId, user) {
  _userCache.set(userId, { user, ts: Date.now() });
  // Prevent unbounded growth — cap cache at 500 entries
  if (_userCache.size > 500) {
    const firstKey = _userCache.keys().next().value;
    _userCache.delete(firstKey);
  }
}

// Call this to invalidate a user's cache entry (e.g. on logout, deactivation)
function invalidateUserCache(userId) { _userCache.delete(String(userId)); }

// ── JWT Secret — MUST be set in environment ─────────────────────────────────
function getJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('FATAL: JWT_SECRET environment variable is not set in production.');
    }
    return 'library_mgmt_dev_secret_2026';
  }
  return secret;
}

const protect = async (req, res, next) => {
  try {
    let token;
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return res.status(401).json({ success: false, message: 'Not authorized to access this route' });
    }

    const secret = getJwtSecret();
    const decoded = jwt.verify(token, secret);
    const userId = String(decoded.id);

    // Try cache first — avoids DB hit on every request
    let user = getCachedUser(userId);
    if (!user) {
      user = await User.findById(userId).lean();
      if (user) setCachedUser(userId, user);
    }

    if (!user) {
      return res.status(401).json({ success: false, message: 'User not found' });
    }

    if (!user.isActive) {
      return res.status(403).json({ success: false, message: 'User account is inactive' });
    }

    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Not authorized, token failed' });
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    let token;

    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (token) {
      const secret = getJwtSecret();
      const decoded = jwt.verify(token, secret);
      const userId = String(decoded.id);
      let user = getCachedUser(userId);
      if (!user) {
        user = await User.findById(userId).lean();
        if (user) setCachedUser(userId, user);
      }
      if (user && user.isActive) {
        req.user = user;
      }
    }
  } catch (err) {
    // Ignore invalid/expired token for optional auth
  }
  next();
};

module.exports = { protect, optionalAuth };

