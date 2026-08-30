require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const fs = require('fs');
const connectDB = require('./config/db');
const { generalLimiter } = require('./middleware/rateLimiter');
const { errorHandler, initProcessErrorHandlers } = require('./middleware/errorMiddleware');

// Initialize process crash catchers for uncaught exceptions and unhandled rejections
initProcessErrorHandlers();

const app = express();
app.set('trust proxy', 1);

// Security Middleware — configured to allow CDNs (Chart.js, Sortable.js), Google Fonts, worker blobs, and maps
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: [
        "'self'",
        "'unsafe-inline'",
        "'unsafe-eval'",
        "https://cdn.jsdelivr.net",
        "https://cdnjs.cloudflare.com"
      ],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc: [
        "'self'",
        "'unsafe-inline'",
        "https://fonts.googleapis.com",
        "https://cdn.jsdelivr.net",
        "https://cdnjs.cloudflare.com"
      ],
      fontSrc: [
        "'self'",
        "https://fonts.gstatic.com",
        "https://cdnjs.cloudflare.com",
        "data:"
      ],
      imgSrc: [
        "'self'",
        "data:",
        "blob:",
        "https:",
        "http:"
      ],
      connectSrc: [
        "'self'",
        "https:",
        "wss:",
        "blob:",
        "data:",
        "https://api.postalpincode.in",
        "https://api.qrserver.com",
        "https://api.zippopotam.us",
        "https://ui-avatars.com"
      ],
      frameSrc: [
        "'self'",
        "https://www.google.com",
        "https://maps.google.com",
        "https://*.google.com"
      ],
      workerSrc: [
        "'self'",
        "blob:"
      ],
      childSrc: [
        "'self'",
        "blob:"
      ],
      objectSrc: ["'none'"]
    }
  },
  crossOriginEmbedderPolicy: false,
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));

const allowedOrigins = process.env.CORS_ORIGIN 
  ? process.env.CORS_ORIGIN.split(',').map(s => s.trim()) 
  : (process.env.NODE_ENV === 'production' 
      ? ['https://study-library-management.onrender.com'] 
      : '*');

app.use(cors({
  origin: allowedOrigins,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-webhook-secret']
}));

// Body parser (protected 10MB limit for high-res photo/signature uploads)
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Apply rate limiting
app.use(generalLimiter);

// Compression Middleware for optimized asset delivery & performance
const compression = require('compression');
app.use(compression({
  level: 6,
  threshold: 1024, // Only compress responses > 1KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));

// Static folder with smart cache headers
app.use(express.static(path.join(__dirname, 'public'), {
  setHeaders: (res, filePath) => {
    // HTML & SW: never cache (always get latest)
    if (filePath.endsWith('sw.js') || filePath.endsWith('.html') || filePath.endsWith('manifest.json')) {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
      res.setHeader('Pragma', 'no-cache');
    // JS & CSS: cache 1 day (busted by ?v=X.Y.Z in index.html)
    } else if (filePath.endsWith('.js') || filePath.endsWith('.css')) {
      res.setHeader('Cache-Control', 'public, max-age=86400, stale-while-revalidate=43200');
    // Images & Fonts: cache 7 days
    } else if (/\.(png|jpg|jpeg|gif|svg|ico|woff2?|ttf|eot)$/i.test(filePath)) {
      res.setHeader('Cache-Control', 'public, max-age=604800, immutable');
    // Everything else: 1 day
    } else {
      res.setHeader('Cache-Control', 'public, max-age=86400');
    }
  },
  etag: true,
  lastModified: true
}));
const uploadsDir = path.join(__dirname, 'uploads');
try {
  if (!require('fs').existsSync(uploadsDir)) {
    require('fs').mkdirSync(uploadsDir, { recursive: true });
  }
} catch (fsErr) {
  // Read-only filesystem in serverless environments (e.g. Vercel)
}

// Persistent /uploads file server (Serves from local disk cache or auto-restores from MongoDB Atlas)
app.use('/uploads', async (req, res, next) => {
  const filename = path.basename(req.path);
  if (!filename) return next();
  const filePath = path.join(uploadsDir, filename);

  if (fs.existsSync(filePath)) {
    return res.sendFile(filePath);
  }

  try {
    const MediaFile = require('./models/MediaFile');
    const media = await MediaFile.findOne({ filename }).lean();
    if (media && media.data) {
      let imageBuffer = media.data;
      if (imageBuffer && imageBuffer.buffer && !Buffer.isBuffer(imageBuffer)) {
        imageBuffer = Buffer.from(imageBuffer.buffer);
      } else if (imageBuffer && !Buffer.isBuffer(imageBuffer)) {
        imageBuffer = Buffer.from(imageBuffer);
      }

      if (imageBuffer && Buffer.isBuffer(imageBuffer)) {
        try { await fs.promises.writeFile(filePath, imageBuffer); } catch (e) {}
        res.setHeader('Content-Type', media.mimeType || 'image/jpeg');
        res.setHeader('Content-Length', imageBuffer.length);
        res.setHeader('Cache-Control', 'public, max-age=604800, immutable');
        return res.end(imageBuffer);
      }
    }
  } catch (err) {
    console.warn('Media fetch from DB warning:', err.message);
  }

  next();
}, express.static(uploadsDir, { maxAge: '7d' }));

// Ensure MongoDB connection is active for serverless invocations (e.g. Vercel)
app.use(async (req, res, next) => {
  if (req.path.startsWith('/api') && req.path !== '/api/health') {
    try {
      await connectDB();
    } catch (dbErr) {
      console.error('Serverless DB connect error:', dbErr.message);
    }
  }
  next();
});

// API Routes
app.use('/api/cron', require('./routes/cron'));
app.use('/api/upload', require('./routes/upload'));
app.use('/api/auth', require('./routes/auth'));
app.use('/api/students', require('./routes/students'));
app.use('/api/seats', require('./routes/seats'));
app.use('/api/plans', require('./routes/plans'));
app.use('/api/payments', require('./routes/payments'));
app.use('/api/attendance', require('./routes/attendance'));
app.use('/api/branches', require('./routes/branches'));
app.use('/api/shifts', require('./routes/shifts'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/settings', require('./routes/settings'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/search', require('./routes/search'));
app.use('/api/student-portal', require('./routes/studentPortal'));
app.use('/api/operations', require('./routes/operations'));
app.use('/api/expenses', require('./routes/expenses'));
app.use('/api/custom-fields', require('./routes/customFields'));
app.use('/api/waiting-list', require('./routes/waitingList'));
app.use('/api/lockers', require('./routes/lockers'));
app.use('/api/messages', require('./routes/messages'));
app.use('/api/backup', require('./routes/backup'));
app.use('/api/landing', require('./routes/landingPage'));
app.use('/api/audit-logs', require('./routes/auditLogs'));
app.use('/api/coupons', require('./routes/coupons'));
app.use('/api/trash', require('./routes/trash'));
app.use('/api/system', require('./routes/systemConfig'));
app.use('/api/system', require('./routes/systemHealth'));
app.use('/api/ai', require('./routes/aiInsights'));

// Health check endpoint for uptime monitoring, diagnostics & Render.com
app.get('/api/health', async (req, res) => {
  const mongoose = require('mongoose');
  const dbConnected = mongoose.connection.readyState === 1;
  const dbStateMap = { 0: 'disconnected', 1: 'connected', 2: 'connecting', 3: 'disconnecting' };
  const dbStatus = dbStateMap[mongoose.connection.readyState] || 'unknown';

  let dbPingLatencyMs = -1;
  if (dbConnected && mongoose.connection.db) {
    const pingStart = Date.now();
    try {
      await mongoose.connection.db.command({ ping: 1 });
      dbPingLatencyMs = Date.now() - pingStart;
    } catch {
      dbPingLatencyMs = -1;
    }
  }

  const mem = process.memoryUsage();
  const bytesToMB = (b) => Number((b / (1024 * 1024)).toFixed(2));
  const uptimeSeconds = Math.round(process.uptime());
  const d = Math.floor(uptimeSeconds / (3600 * 24));
  const h = Math.floor((uptimeSeconds % (3600 * 24)) / 3600);
  const m = Math.floor((uptimeSeconds % 3600) / 60);
  const s = Math.floor(uptimeSeconds % 60);
  const formattedUptime = `${d > 0 ? d + 'd ' : ''}${h > 0 ? h + 'h ' : ''}${m}m ${s}s`;

  const isHealthy = dbConnected && (dbPingLatencyMs >= 0 || mongoose.connection.readyState === 1);
  const isDegraded = isHealthy && dbPingLatencyMs > 400;

  const responsePayload = {
    status: !isHealthy ? 'unhealthy' : (isDegraded ? 'degraded' : 'healthy'),
    badge: !isHealthy ? '🔴 Unhealthy' : (isDegraded ? '🟡 Degraded (High Latency)' : '🟢 Operational'),
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: uptimeSeconds,
    uptimeFormatted: formattedUptime,
    database: {
      status: dbStatus,
      connected: dbConnected,
      pingLatencyMs: dbPingLatencyMs,
      badge: dbPingLatencyMs >= 0 ? (dbPingLatencyMs < 50 ? '🟢 Ultra-Fast' : (dbPingLatencyMs < 200 ? '🟡 Good' : '🟠 Moderate')) : '🔴 Disconnected',
      host: mongoose.connection.host || 'MongoDB Atlas'
    },
    memory: {
      heapUsedMB: bytesToMB(mem.heapUsed),
      heapTotalMB: bytesToMB(mem.heapTotal),
      rssMB: bytesToMB(mem.rss),
      externalMB: bytesToMB(mem.external),
      containerLimitMB: 512,
      usagePercent: Number(((mem.rss / (512 * 1024 * 1024)) * 100).toFixed(1))
    },
    system: {
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      pid: process.pid,
      environment: process.env.NODE_ENV || 'production'
    }
  };

  res.status(isHealthy ? 200 : 503).json(responsePayload);
});

// Public Configuration Endpoint for Admission Wizard & System (High Performance)
app.get('/api/system/public-config', async (req, res) => {
  try {
    const BusinessProfile = require('./models/BusinessProfile');
    const CustomField = require('./models/CustomField');
    const FormTemplate = require('./models/FormTemplate');
    const Plan = require('./models/Plan');
    const Shift = require('./models/Shift');
    const Branch = require('./models/Branch');
    const SystemSetting = require('./models/SystemSetting');
    const Seat = require('./models/Seat');

    const Student = require('./models/Student');
    const [businessProfile, customFields, template, plans, shifts, rawBranches, seatStats, totalSystemSeats, availableSystemSeats, systemSettingsList, studentCounts] = await Promise.all([
      BusinessProfile.getProfile().catch(() => ({})),
      CustomField.find({ isDeleted: { $ne: true } }).sort({ order: 1, createdAt: 1 }).lean().catch(() => []),
      FormTemplate.getActiveTemplate().catch(() => null),
      Plan.find({ isActive: true, isDeleted: { $ne: true } }).sort('displayOrder').lean().catch(() => []),
      Shift.find({ isActive: true }).sort('startTime').lean().catch(() => []),
      Branch.find({ isActive: true, isDeleted: { $ne: true } }).lean().catch(() => []),
      Seat.aggregate([
        { $match: { isActive: true, isDeleted: { $ne: true } } },
        { $group: {
            _id: '$branch',
            total: { $sum: 1 },
            occupied: { $sum: { $cond: [{ $eq: ['$status', 'occupied'] }, 1, 0] } },
            available: { $sum: { $cond: [{ $in: ['$status', ['available', 'vacant']] }, 1, 0] } }
        }}
      ]).catch(() => []),
      Seat.countDocuments({ isActive: true, isDeleted: { $ne: true } }).catch(() => 0),
      Seat.countDocuments({ isActive: true, isDeleted: { $ne: true }, status: { $in: ['available', 'vacant'] } }).catch(() => 0),
      SystemSetting.find().lean().catch(() => []),
      Student.aggregate([
        { $match: { isDeleted: { $ne: true }, status: 'active', plan: { $exists: true, $ne: null } } },
        { $group: { _id: '$plan', count: { $sum: 1 } } }
      ]).catch(() => [])
    ]);

    const memberCountMap = {};
    (studentCounts || []).forEach(m => { memberCountMap[String(m._id)] = m.count; });

    const enrichedPlans = (plans || []).map(p => {
      const origPrice = Number(p.price) || 0;
      const discount = Number(p.discount) || 0;
      const effectivePrice = Math.round(origPrice * (1 - discount / 100));
      return {
        ...p,
        discount,
        effectivePrice,
        activeMembersCount: memberCountMap[String(p._id)] || 0
      };
    });

    const settingsMap = {};
    (systemSettingsList || []).forEach(s => { settingsMap[s.key] = s.value; });
    const lockerConfig = {
      enableAddon: settingsMap['locker.enableAddon'] !== false,
      monthlyFee: Number(settingsMap['locker.monthlyFee']) || 200,
      deposit: Number(settingsMap['locker.deposit']) || 0,
      title: settingsMap['locker.title'] || 'Add Personal Study Locker',
      description: settingsMap['locker.description'] || 'Secure private key-allotted locker to safely keep heavy study books, notes & laptop.'
    };

    let branches = [];
    if (rawBranches && rawBranches.length > 0) {
      const statsMap = new Map((seatStats || []).map(c => [String(c._id), c]));
      branches = rawBranches.map(b => {
        const stat = statsMap.get(String(b._id));
        const totalSeats = stat ? stat.total : (b.totalSeats || totalSystemSeats || 59);
        const occupiedSeats = stat ? stat.occupied : 0;
        const availableSeats = stat ? stat.available : Math.max(0, totalSeats - occupiedSeats);
        return {
          _id: b._id,
          name: b.name,
          code: b.code || 'MAIN',
          city: b.city || 'Central City',
          address: b.address || '',
          phone: b.phone || '',
          totalSeats,
          occupiedSeats,
          availableSeats
        };
      });
    } else {
      const liveTotal = totalSystemSeats || 59;
      const liveAvail = availableSystemSeats || 57;
      branches = [{
        _id: 'default_main',
        name: businessProfile?.businessName || 'Cozy Corner (Main Centre)',
        code: 'MAIN',
        city: businessProfile?.city || 'PARLI',
        address: businessProfile?.address || 'Main Study Hall',
        phone: businessProfile?.phone || '',
        totalSeats: liveTotal,
        occupiedSeats: Math.max(0, liveTotal - liveAvail),
        availableSeats: liveAvail
      }];
    }

    // Canonical Payment Methods for Self-Registration Portal
    const CANONICAL_PAYMENT_METHODS = [
      {
        key: 'upi',
        name: 'Dynamic UPI QR & 1-Tap Apps',
        subtitle: 'GPay / PhonePe / Paytm / BHIM (Instant)',
        icon: '⚡',
        enabled: true,
        order: 1,
        instructions: 'Scan QR code or use 1-tap UPI app buttons and enter 12-digit UTR number',
        requiresRef: true,
        refLabel: '12-Digit Bank UTR / Reference Number *'
      },
      {
        key: 'card',
        name: 'Debit / Credit Card',
        subtitle: 'Visa, Mastercard, RuPay & POS Swipe',
        icon: '💳',
        enabled: true,
        order: 2,
        instructions: 'Swipe / pay via card machine or online POS and enter card txn reference',
        requiresRef: true,
        refLabel: 'Card Transaction Reference / Approval Code *'
      },
      {
        key: 'netbanking',
        name: 'NetBanking / Direct Bank Transfer',
        subtitle: 'NEFT / IMPS / RTGS (All Indian Banks)',
        icon: '🏦',
        enabled: true,
        order: 3,
        instructions: 'Transfer fee to official library bank account and enter transaction UTR or upload slip',
        requiresRef: true,
        refLabel: 'Bank Transaction Reference / UTR *'
      },
      {
        key: 'desk',
        name: 'Pay Later at Front Desk',
        subtitle: 'Cash / Spot Pay on Arrival',
        icon: '💵',
        enabled: true,
        order: 4,
        instructions: 'Your chosen seat is reserved for 24 hours. Pay cash or UPI at the front desk upon arrival.',
        requiresRef: false,
        refLabel: ''
      }
    ];

    const storedMethods = Array.isArray(businessProfile?.paymentMethods) ? businessProfile.paymentMethods : [];
    const storedMap = new Map(storedMethods.map(m => [m.key, m]));
    const tplS = template?.settings || {};

    const mergedPaymentMethods = CANONICAL_PAYMENT_METHODS.map(def => {
      const stored = storedMap.get(def.key);
      let isEnabled = stored ? Boolean(stored.enabled) : def.enabled;

      if (def.key === 'upi' && tplS.showUpiPayment !== undefined) isEnabled = Boolean(tplS.showUpiPayment);
      else if (def.key === 'desk' && tplS.showDeskPayment !== undefined) isEnabled = Boolean(tplS.showDeskPayment);
      else if (def.key === 'netbanking' && tplS.showNetBankingPayment !== undefined) isEnabled = Boolean(tplS.showNetBankingPayment);
      else if (def.key === 'card' && tplS.showCardPayment !== undefined) isEnabled = Boolean(tplS.showCardPayment);

      return {
        ...def,
        ...(stored ? (typeof stored.toObject === 'function' ? stored.toObject() : stored) : {}),
        enabled: isEnabled,
        name: (def.key === 'upi' && tplS.upiPaymentLabel) ? tplS.upiPaymentLabel :
              (def.key === 'card' && tplS.cardPaymentLabel) ? tplS.cardPaymentLabel :
              (def.key === 'desk' && tplS.deskPaymentLabel) ? tplS.deskPaymentLabel :
              (def.key === 'netbanking' && tplS.netBankingPaymentLabel) ? tplS.netBankingPaymentLabel :
              (stored?.name || def.name),
        subtitle: (def.key === 'upi' && tplS.upiPaymentSubtext) ? tplS.upiPaymentSubtext :
                  (def.key === 'card' && tplS.cardPaymentSubtext) ? tplS.cardPaymentSubtext :
                  (def.key === 'desk' && tplS.deskPaymentSubtext) ? tplS.deskPaymentSubtext :
                  (def.key === 'netbanking' && tplS.netBankingPaymentSubtext) ? tplS.netBankingPaymentSubtext :
                  (stored?.subtitle || def.subtitle)
      };
    });

    storedMethods.forEach(sm => {
      if (!CANONICAL_PAYMENT_METHODS.some(def => def.key === sm.key)) {
        mergedPaymentMethods.push(typeof sm.toObject === 'function' ? sm.toObject() : sm);
      }
    });

    const enrichedBusinessProfile = {
      ...(typeof businessProfile?.toObject === 'function' ? businessProfile.toObject() : (businessProfile || {})),
      paymentMethods: mergedPaymentMethods
    };

    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.json({
      success: true,
      data: {
        businessProfile: enrichedBusinessProfile,
        customFields,
        template,
        plans: enrichedPlans,
        shifts: shifts || [],
        branches,
        locker: lockerConfig
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// High-Speed In-Memory Pre-hydration Cache (Sub-millisecond delivery for public landing & registration)
const _hydratedHtmlCache = new Map();
const HYDRATE_CACHE_TTL_MS = 60000; // 60s memory cache

function invalidateHydratedCache() {
  _hydratedHtmlCache.clear();
}
app.set('invalidateHydratedCache', invalidateHydratedCache);

async function generateHydratedHTML(htmlPath) {
  let fs = require('fs');
  let html = fs.readFileSync(htmlPath, 'utf8');
  const BusinessProfile = require('./models/BusinessProfile');
  const LandingPage = require('./models/LandingPage');
  const Plan = require('./models/Plan');
  const Shift = require('./models/Shift');

  const [profile, landing, plans, shifts] = await Promise.all([
    BusinessProfile.getProfile().catch(() => ({})),
    LandingPage.getPageConfig().catch(() => ({})),
    Plan.find({ isActive: true, isDeleted: { $ne: true } }).sort({ displayOrder: 1, price: 1 }).lean().catch(() => []),
    Shift.find({ isActive: true }).lean().catch(() => [])
  ]);

  const escapeHTML = str => String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');

  const bName = escapeHTML(landing?.navbar?.brandName || profile?.businessName || 'The Cozy Corner Centre');
  const bLogo = landing?.navbar?.brandLogo || profile?.logo || '';
  const tagline = escapeHTML(profile?.tagline || landing?.footer?.tagline || 'Silence, Focus and Success');

  // 1. Pre-hydrate Brand Name & Logos
  if (bName) {
    html = html.replace(/<span id="nav-brand-name">.*?<\/span>/g, `<span id="nav-brand-name">${bName}</span>`);
    html = html.replace(/<span id="drawer-brand-name">.*?<\/span>/g, `<span id="drawer-brand-name">${bName}</span>`);
    html = html.replace(/<h1 id="lib-title">.*?<\/h1>/g, `<h1 id="lib-title">${bName}</h1>`);
    html = html.replace(/<span id="sidebar-org-name">.*?<\/span>/g, `<span id="sidebar-org-name">${bName}</span>`);
    html = html.replace(/<h1 id="lib-name">.*?<\/h1>/g, `<h1 id="lib-name">${bName}</h1>`);
    html = html.replace(/<h3 class="footer-title" id="footer-org-name">.*?<\/h3>/g, `<h3 class="footer-title" id="footer-org-name">${bName}</h3>`);
    html = html.replace(/<span id="footer-copy-name">.*?<\/span>/g, `<span id="footer-copy-name">${bName}</span>`);
    html = html.replace(/<title>.*?<\/title>/g, `<title>${bName} — Premier Self-Study Space</title>`);
    if (tagline) {
      html = html.replace(/<p class="footer-text" id="footer-tagline">.*?<\/p>/g, `<p class="footer-text" id="footer-tagline">${tagline}</p>`);
      html = html.replace(/<div id="footer-bottom-tagline">.*?<\/div>/g, `<div id="footer-bottom-tagline">${tagline}</div>`);
    }
  }

  if (bLogo) {
    const logoImg = `<img src="${bLogo}" alt="Logo" width="36" height="36" style="width: 36px; height: 36px; max-width: 36px; max-height: 36px; object-fit: contain; border-radius: 6px; display: block;">`;
    html = html.replace(/<span class="nav-logo" id="nav-logo-icon">.*?<\/span>/g, `<span class="nav-logo" id="nav-logo-icon" style="width: 36px; height: 36px; display: inline-flex; align-items: center; justify-content: center; overflow: hidden;">${logoImg}</span>`);

    const footerLogoImg = `<img src="${bLogo}" alt="Logo" width="38" height="38" style="width: 38px; height: 38px; max-width: 38px; max-height: 38px; object-fit: contain; border-radius: 8px; display: block;">`;
    html = html.replace(/<div id="footer-logo".*?<\/div>/g, `<div id="footer-logo" style="width: 38px; height: 38px; max-width: 38px; max-height: 38px; margin-bottom: 0.75rem; display: inline-flex; align-items: center; justify-content: center; overflow: hidden; border-radius: 8px;">${footerLogoImg}</div>`);
  } else {
    html = html.replace(/<div id="footer-logo".*?<\/div>/g, `<div id="footer-logo" style="display:none;"></div>`);
  }

  // 2. Pre-hydrate Hero Customizations
  if (landing?.hero?.title) {
    let ht = landing.hero.title;
    if (ht.includes('{library_name}')) {
      ht = ht.replace(/{library_name}/gi, bName);
    }
    if (!ht.includes('<span>') && !ht.includes('</span>')) {
      const words = ht.split(' ');
      if (words.length > 2) {
        ht = `<span>${words.slice(0, 2).join(' ')}</span> ${words.slice(2).join(' ')}`;
      } else {
        ht = `<span>${ht}</span>`;
      }
    }
    html = html.replace(/<h1 class="hero-title" id="hero-title">[\s\S]*?<\/h1>/g, `<h1 class="hero-title" id="hero-title">${ht}</h1>`);
  }
  if (landing?.hero?.subtitle) {
    html = html.replace(/<p class="hero-subtitle" id="hero-subtitle">[\s\S]*?<\/p>/g, `<p class="hero-subtitle" id="hero-subtitle">${landing.hero.subtitle}</p>`);
  }
  if (landing?.hero?.tickerText) {
    html = html.replace(/<span id="ticker-text">[\s\S]*?<\/span>/g, `<span id="ticker-text">${landing.hero.tickerText}</span>`);
  }

  // 3. Pre-hydrate Plans Section (Zero Spinner / Instant Render)
  const activePlans = (Array.isArray(plans) && plans.length > 0) ? plans : [
    {
      name: 'Monthly',
      price: 1000,
      discount: 30,
      duration: 1,
      durationType: 'months',
      seatType: 'regular',
      shift: 'fullday',
      features: ['WiFi', 'AC', 'Personal Charging Point', 'RO Water']
    },
    {
      name: 'Quaterly',
      price: 4000,
      discount: 40,
      duration: 3,
      durationType: 'months',
      seatType: 'premium',
      shift: 'fullday',
      features: ['WiFi', 'AC', 'Personal Charging Point', 'RO Water']
    }
  ];

  const plansCardsHtml = activePlans.map(p => {
    const finalPrice = Math.round(p.effectivePrice || (p.price * (1 - (p.discount || 0) / 100)) || p.price || 0);
    let durationLabel = '';
    if (p.duration && p.duration > 1) {
      durationLabel = p.durationType === 'days' ? `${p.duration} Days` : `${p.duration} Months`;
    } else if (p.name && p.name.toLowerCase().includes('quater')) {
      durationLabel = '3 Months';
    } else if (p.name && (p.name.toLowerCase().includes('half') || p.name.toLowerCase().includes('6 month'))) {
      durationLabel = '6 Months';
    } else if (p.name && (p.name.toLowerCase().includes('annual') || p.name.toLowerCase().includes('year'))) {
      durationLabel = '1 Year';
    } else {
      durationLabel = '1 Month';
    }
    const discount = p.discount || 0;
    const planId = p._id || p.id || '';
    return `
      <div class="plan-card">
        ${discount > 0 ? `<div class="plan-badge">${discount}% OFF</div>` : ''}
        <h3 class="plan-name">${escapeHTML(p.name)}</h3>
        <div class="plan-price-row">
          <span class="plan-price">₹${finalPrice.toLocaleString('en-IN')}</span>
          <span class="plan-period">/ ${durationLabel}</span>
        </div>
        <ul class="plan-features">
          <li>Seat Type: <strong>${(p.seatType || 'Standard').toUpperCase()}</strong></li>
          <li>Shift: <strong>${(p.shift || 'Any').toUpperCase()}</strong></li>
          ${(p.features || []).map(f => `<li>${escapeHTML(f)}</li>`).join('')}
        </ul>
        <a href="/register?plan=${encodeURIComponent(planId || p.name)}" class="btn-hero-primary" style="justify-content: center; text-align: center; width: 100%; border: none; text-decoration: none;">
          Register Now
        </a>
      </div>
    `;
  }).join('');

  html = html.replace(/<div class="plans-grid" id="plans-container">[\s\S]*?<\/div>\s*<\/section>/g, `<div class="plans-grid" id="plans-container">${plansCardsHtml}</div>\n  </section>`);

  // 4. Pre-hydrate Shifts Section
  const activeShifts = (Array.isArray(shifts) && shifts.length > 0) ? shifts : [
    { icon: '🌅', name: 'Morning Shift', timing: '06:00 AM – 02:00 PM', description: 'Early morning slot for fresh mental energy and peak focus.' },
    { icon: '🌇', name: 'Evening Shift', timing: '02:00 PM – 10:00 PM', description: 'Afternoon & evening slot ideal for college students and professionals.' },
    { icon: '☀️', name: 'Full Day Prime', timing: '06:00 AM – 11:00 PM', description: 'Complete 17-hour all-day reserved seat with dedicated charging desk.' },
    { icon: '🌙', name: 'Night Owl Slot', timing: '10:00 PM – 06:00 AM', description: 'Distraction-free overnight study hours for night preparation.' }
  ];

  const formatShiftTime = (t) => {
    if (!t) return '';
    if (t.includes('AM') || t.includes('PM')) return t;
    const parts = t.split(':');
    if (parts.length < 2) return t;
    let h = parseInt(parts[0], 10);
    const m = parts[1].padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    h = h ? h : 12;
    return `${h.toString().padStart(2, '0')}:${m} ${ampm}`;
  };

  const shiftsCardsHtml = activeShifts.map(s => {
    const timingStr = s.timing || ((s.startTime && s.endTime) ? `${formatShiftTime(s.startTime)} – ${formatShiftTime(s.endTime)}` : '');
    const icon = s.icon || '⏰';
    return `
      <div class="shift-card">
        <div class="shift-icon">${icon}</div>
        <div class="shift-name">${escapeHTML(s.name)}</div>
        <div class="shift-time">${escapeHTML(timingStr)}</div>
        ${s.description ? `<div class="shift-desc" style="font-size: 0.88rem; color: var(--text-muted); margin-top: 6px; line-height: 1.4;">${escapeHTML(s.description)}</div>` : ''}
      </div>
    `;
  }).join('');

  html = html.replace(/<div class="shifts-grid" id="shifts-container">[\s\S]*?<\/div>\s*<\/section>/g, `<div class="shifts-grid" id="shifts-container">${shiftsCardsHtml}</div>\n  </section>`);

  // 5. Pre-hydrate Section Headers
  if (landing?.pricing?.title) {
    html = html.replace(/(<section id="plans"[\s\S]*?<h2 class="section-title">)[\s\S]*?(<\/h2>)/g, `$1${landing.pricing.title}$2`);
  }
  if (landing?.about?.title) {
    html = html.replace(/(<section id="about"[\s\S]*?<h2 class="section-title">)[\s\S]*?(<\/h2>)/g, `$1${landing.about.title}$2`);
  }
  if (landing?.gallery?.title) {
    html = html.replace(/(<section id="gallery"[\s\S]*?<h2 class="section-title">)[\s\S]*?(<\/h2>)/g, `$1${landing.gallery.title}$2`);
  }

  // 6. Pre-hydrate Gallery Items & Filters
  if (Array.isArray(landing?.gallery?.images) && landing.gallery.images.length > 0) {
    const categories = Array.from(new Set(landing.gallery.images.map(img => img.category || 'Hall'))).filter(Boolean);
    const filterBtns = `<button type="button" class="g-filter active" data-category="all">All</button>` + 
      categories.map(c => `<button type="button" class="g-filter" data-category="${c.toLowerCase()}">${c}</button>`).join('');
    html = html.replace(/<div class="gallery-filters" id="gallery-filters-bar">[\s\S]*?<\/div>/g, `<div class="gallery-filters" id="gallery-filters-bar">${filterBtns}</div>`);

    const galleryCards = landing.gallery.images.map(img => `
      <div class="gallery-item" data-category="${img.category || 'Hall'}" onclick="openLightbox('${img.url}', '${img.caption || ''}')">
        <img src="${img.url}" alt="${img.caption || 'Gallery Image'}" loading="lazy">
        <div class="gallery-caption">${img.caption || ''}</div>
      </div>
    `).join('');
    html = html.replace(/<div class="gallery-grid" id="gallery-container">[\s\S]*?<\/div>/g, `<div class="gallery-grid" id="gallery-container">${galleryCards}</div>`);
  }

  // 7. Pre-hydrate Footer Quick Links & Contact Info
  const linksHeading = escapeHTML(landing?.footer?.linksHeading || 'Quick Links');
  html = html.replace(/<h4.*?id="footer-links-heading">[\s\S]*?<\/h4>/g, `<h4 style="font-weight: 700; margin-bottom: 1.5rem; font-size:1.1rem;" id="footer-links-heading">${linksHeading}</h4>`);

  const qLinks = (Array.isArray(landing?.footer?.quickLinks) && landing.footer.quickLinks.length > 0)
    ? landing.footer.quickLinks.filter(l => l && l.label && l.url)
    : [
        { label: 'Online Admission', url: '/register', openInNewTab: false },
        { label: 'Student Portal', url: '/student-login', openInNewTab: false },
        { label: 'Gate Kiosk', url: '/kiosk', openInNewTab: false },
        { label: 'Staff & Owner Login', url: '/#/', openInNewTab: false }
      ];

  const linksHtml = qLinks.map(l => `<li><a href="${escapeHTML(l.url)}" ${l.openInNewTab ? 'target="_blank" rel="noopener"' : ''}>${escapeHTML(l.label)}</a></li>`).join('');
  html = html.replace(/<ul class="footer-links" id="footer-links-container">[\s\S]*?<\/ul>/g, `<ul class="footer-links" id="footer-links-container">${linksHtml}</ul>`);

  const addressText = escapeHTML(landing?.contact?.address || profile?.address || 'Nath road, parli vaijanath-431515');
  const phoneText = escapeHTML(landing?.contact?.phone || profile?.phone || '+919403243830');
  const hoursText = escapeHTML(landing?.contact?.openingHours || 'Open Daily: 06:00 AM – 11:00 PM (365 Days)');

  html = html.replace(/<span id="footer-address">[\s\S]*?<\/span>/g, `<span id="footer-address">${addressText}</span>`);
  html = html.replace(/<span id="footer-phone">[\s\S]*?<\/span>/g, `<span id="footer-phone">${phoneText}</span>`);
  html = html.replace(/<span id="footer-hours">[\s\S]*?<\/span>/g, `<span id="footer-hours">${hoursText}</span>`);
  html = html.replace(/<div[^>]*?id="map-card-address">[\s\S]*?<\/div>/g, `<div style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 0.85rem;" id="map-card-address">${addressText}</div>`);

  // 8. Pre-inject Instant Admission Configuration into /register
  if (htmlPath.includes('register.html')) {
    try {
      const CustomField = require('./models/CustomField');
      const FormTemplate = require('./models/FormTemplate');
      const Branch = require('./models/Branch');
      const SystemSetting = require('./models/SystemSetting');

      let [cFields, template, rPlans, rShifts, branches, settingsList] = await Promise.all([
        CustomField.find({ isDeleted: { $ne: true } }).sort({ order: 1, createdAt: 1 }).lean().catch(() => []),
        FormTemplate.getActiveTemplate().catch(() => null),
        Plan.find({ isActive: true, isDeleted: { $ne: true } }).sort('displayOrder').lean().catch(() => []),
        Shift.find({ isActive: true }).sort('startTime').lean().catch(() => []),
        Branch.find({ isActive: true, isDeleted: { $ne: true } }).lean().catch(() => []),
        SystemSetting.find().lean().catch(() => [])
      ]);

      if (!rPlans || rPlans.length === 0) {
        rPlans = await Plan.find({ isDeleted: { $ne: true } }).lean().catch(() => []);
      }

      const settingsMap = {};
      (settingsList || []).forEach(s => { settingsMap[s.key] = s.value; });

      const preloadedConfig = {
        businessProfile: profile,
        customFields: cFields,
        template,
        plans: rPlans,
        shifts: rShifts,
        branches: branches.length > 0 ? branches : [{
          _id: 'default_main',
          name: profile?.businessName || 'The Cozy Corner Centre',
          city: profile?.city || 'PARLI',
          totalSeats: 59,
          availableSeats: 57
        }],
        settings: settingsMap,
        locker: {
          enableAddon: settingsMap['locker.enableAddon'] !== false,
          monthlyFee: Number(settingsMap['locker.monthlyFee']) || 200,
          deposit: Number(settingsMap['locker.deposit']) || 0
        }
      };

      const configJson = JSON.stringify(preloadedConfig).replace(/</g, '\\u003c');
      const injectedScript = `<script id="initial-public-config" type="application/json">${configJson}</script>`;
      html = html.replace('</head>', `${injectedScript}\n</head>`);
    } catch (e) {}
  }

  return html;
}

// Ultra-fast Sub-millisecond HTML Dispatcher
async function sendHydratedHTML(res, htmlPath) {
  try {
    const cached = _hydratedHtmlCache.get(htmlPath);
    const now = Date.now();

    // 1. Fresh cache hit (< 60s): Instant 0.2ms delivery
    if (cached && (now - cached.timestamp < HYDRATE_CACHE_TTL_MS)) {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.setHeader('Cache-Control', 'public, max-age=0, stale-while-revalidate=120');
      res.setHeader('X-Fast-Cache', 'HIT');
      return res.send(cached.html);
    }

    // 2. Stale cache: Instant 0.2ms delivery + Async background refresh
    if (cached) {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.setHeader('Cache-Control', 'public, max-age=0, stale-while-revalidate=120');
      res.setHeader('X-Fast-Cache', 'STALE');
      res.send(cached.html);

      // Async background revalidation without blocking client
      generateHydratedHTML(htmlPath).then(newHtml => {
        _hydratedHtmlCache.set(htmlPath, { html: newHtml, timestamp: Date.now() });
      }).catch(() => {});
      return;
    }

    // 3. First-run generation
    const html = await generateHydratedHTML(htmlPath);
    _hydratedHtmlCache.set(htmlPath, { html, timestamp: Date.now() });

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 'public, max-age=0, stale-while-revalidate=120');
    res.setHeader('X-Fast-Cache', 'MISS');
    return res.send(html);
  } catch (err) {
    res.setHeader('Cache-Control', 'no-cache, must-revalidate');
    return res.sendFile(htmlPath);
  }
}

// Public Landing Page & Registration Routes
app.get('/landing', (req, res) => sendHydratedHTML(res, path.join(__dirname, 'public', 'landing.html')));
app.get(['/register', '/register.html'], (req, res) => sendHydratedHTML(res, path.join(__dirname, 'public', 'register.html')));
app.get(['/student-login', '/portal-login'], (req, res) => sendHydratedHTML(res, path.join(__dirname, 'public', 'student-login.html')));
app.get('/kiosk', (req, res) => sendHydratedHTML(res, path.join(__dirname, 'public', 'kiosk.html')));

// SPA fallback — only for non-API GET requests
app.use((req, res, next) => {
  if (req.method === 'GET' && !req.path.startsWith('/api')) {
    return sendHydratedHTML(res, path.join(__dirname, 'public', 'index.html'));
  }
  next();
});

// Global error handler middleware
app.use(errorHandler);

// Start server
const PORT = process.env.PORT || 5000;

let server;

const startServer = async () => {
  // Start Express first (so frontend is always accessible)
  server = app.listen(PORT, () => {
    console.log(`\n  ✅ Server running on http://localhost:${PORT}`);
    console.log(`  📂 Mode: ${process.env.NODE_ENV || 'development'}`);
    console.log(`  🌐 Open in browser: http://localhost:${PORT}\n`);
  });

  // Graceful HTTP shutdown handler
  const gracefulShutdown = (signal) => {
    console.log(`\n  🛑 Received ${signal}. Closing HTTP server gracefully...`);
    if (server) {
      server.close(() => {
        console.log('  👋 HTTP server closed.');
      });
    }
  };
  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));

  // Then connect to MongoDB (non-blocking)
  try {
    await connectDB();
    console.log('  🗄️  MongoDB connected');

    // Initialize system settings, default branch & shifts
    const SystemSetting = require('./models/SystemSetting');
    await SystemSetting.initDefaults();
    const Branch = require('./models/Branch');
    await Branch.seedDefaults();
    const Shift = require('./models/Shift');
    if (typeof Shift.seedDefaults === 'function') {
      await Shift.seedDefaults();
    }
    // Initialize default membership plans
    const Plan = require('./models/Plan');
    if (typeof Plan.seedDefaults === 'function') {
      await Plan.seedDefaults();
    }

    // Initialize default form templates
    const FormTemplate = require('./models/FormTemplate');
    if (typeof FormTemplate.seedDefaults === 'function') {
      await FormTemplate.seedDefaults();
    }
    
    // Initialize Automated Expiry & Notification Cron Jobs
    const { initCronJobs } = require('./utils/cronJobs');
    initCronJobs();

    // Self-Healing Plan Expiry Sync: Fix any students whose plan duration doesn't match expiryDate
    try {
      const Student = require('./models/Student');
      const Payment = require('./models/Payment');
      const studentsToFix = await Student.find({
        plan: { $ne: null },
        expiryDate: { $ne: null }
      }).populate('plan');

      let fixedCount = 0;
      for (const s of studentsToFix) {
        if (!s.plan) continue;
        const baseDate = new Date(s.createdAt || s.admissionDate || Date.now());
        const expectedExpiry = Plan.calculateExpiryDate(s.plan, baseDate);

        // If currently set expiryDate is significantly shorter (>= 15 days shorter) than expected expiry:
        const diffMs = expectedExpiry.getTime() - new Date(s.expiryDate).getTime();
        if (diffMs >= 15 * 86400000) {
          const oldExpStr = new Date(s.expiryDate).toISOString().split('T')[0];
          const newExpStr = expectedExpiry.toISOString().split('T')[0];
          s.expiryDate = expectedExpiry;
          await s.save();

          // Also synchronize initial admission receipt periodEnd if needed
          await Payment.updateMany(
            { student: s._id, periodEnd: { $lt: expectedExpiry } },
            { $set: { periodEnd: expectedExpiry } }
          ).catch(() => {});

          fixedCount++;
          console.log(`  🔧 Auto-healed expiry date for student ${s.studentId || s.name} (${s.plan.name}): corrected ${oldExpStr} -> ${newExpStr}`);
        }
      }
      if (fixedCount > 0) {
        console.log(`  ✅ Successfully auto-healed ${fixedCount} student expiry date(s) to match full plan duration.`);
      }
    } catch (healErr) {
      console.warn('  ⚠️ Plan expiry auto-heal check skipped:', healErr.message);
    }

    console.log('  ⚙️  System settings, Branch & Shifts initialized');
    console.log('  ✨ Ready!\n');
  } catch (error) {
    console.error('\n  ⚠️  MongoDB connection failed:', error.message);
    console.error('  💡 The frontend will still load, but API calls will fail.');
    console.error('  💡 Set MONGODB_URI in .env to a valid MongoDB connection string.');
    console.error('  💡 Get a free MongoDB Atlas cluster at: https://cloud.mongodb.com\n');
  }
};

if (require.main === module) {
  startServer();
}

module.exports = app;
module.exports.app = app;
module.exports.startServer = startServer;
