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
app.use(compression());

// Static folder with smart cache headers
app.use(express.static(path.join(__dirname, 'public'), {
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('sw.js') || filePath.endsWith('.html') || filePath.endsWith('.json')) {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    } else if (filePath.endsWith('.js') || filePath.endsWith('.css')) {
      res.setHeader('Cache-Control', 'public, max-age=0, must-revalidate');
    } else {
      res.setHeader('Cache-Control', 'public, max-age=86400');
    }
  },
  etag: true,
  lastModified: true
}));
const uploadsDir = path.join(__dirname, 'uploads');
if (!require('fs').existsSync(uploadsDir)) {
  require('fs').mkdirSync(uploadsDir, { recursive: true });
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

// API Routes
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

    const [businessProfile, customFields, template, plans, shifts, rawBranches, seatStats, totalSystemSeats, availableSystemSeats, systemSettingsList] = await Promise.all([
      BusinessProfile.getProfile().catch(() => ({})),
      CustomField.getActiveFields().catch(() => []),
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
      SystemSetting.find().lean().catch(() => [])
    ]);

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

    res.setHeader('Cache-Control', 'public, max-age=10, stale-while-revalidate=60');
    res.json({
      success: true,
      data: {
        businessProfile,
        customFields,
        template,
        plans: plans || [],
        shifts: shifts || [],
        branches,
        locker: lockerConfig
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Server-Side HTML Pre-hydration Engine (Admin Changes Are Final & Served Directly From MongoDB)
async function sendHydratedHTML(res, htmlPath) {
  try {
    let fs = require('fs');
    let html = fs.readFileSync(htmlPath, 'utf8');
    const BusinessProfile = require('./models/BusinessProfile');
    const LandingPage = require('./models/LandingPage');

    const [profile, landing] = await Promise.all([
      BusinessProfile.getProfile().catch(() => ({})),
      LandingPage.getPageConfig().catch(() => ({}))
    ]);

    const escapeHTML = str => String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');

    const bName = escapeHTML(landing?.navbar?.brandName || profile?.businessName || 'The Cozy Corner Centre');
    const bLogo = landing?.navbar?.brandLogo || profile?.logo || '';
    const tagline = escapeHTML(landing?.footer?.tagline || profile?.tagline || '');

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
    }

    if (bLogo) {
      const logoImg = `<img src="${bLogo}" alt="Logo" style="height: 36px; width: auto; object-fit: contain; border-radius: 6px;">`;
      html = html.replace(/<span class="nav-logo" id="nav-logo-icon">.*?<\/span>/g, `<span class="nav-logo" id="nav-logo-icon">${logoImg}</span>`);
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

    // 3. Pre-hydrate Section Headers
    if (landing?.pricing?.title) {
      html = html.replace(/(<section id="plans"[\s\S]*?<h2 class="section-title">)[\s\S]*?(<\/h2>)/g, `$1${landing.pricing.title}$2`);
    }
    if (landing?.about?.title) {
      html = html.replace(/(<section id="about"[\s\S]*?<h2 class="section-title">)[\s\S]*?(<\/h2>)/g, `$1${landing.about.title}$2`);
    }
    if (landing?.gallery?.title) {
      html = html.replace(/(<section id="gallery"[\s\S]*?<h2 class="section-title">)[\s\S]*?(<\/h2>)/g, `$1${landing.gallery.title}$2`);
    }

    // 4. Pre-hydrate Gallery Items & Filters
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

    // 5. Pre-hydrate Footer Quick Links & Contact Info
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

    const addressText = escapeHTML(landing?.contact?.address || profile?.address || 'Near Metro Station, Pune');
    const phoneText = escapeHTML(landing?.contact?.phone || profile?.phone || '+91 9876543210');
    const hoursText = escapeHTML(landing?.contact?.openingHours || '06:00 AM – 11:00 PM (Daily)');

    html = html.replace(/<span id="footer-address">[\s\S]*?<\/span>/g, `<span id="footer-address">${addressText}</span>`);
    html = html.replace(/<span id="footer-phone">[\s\S]*?<\/span>/g, `<span id="footer-phone">${phoneText}</span>`);
    html = html.replace(/<span id="footer-hours">[\s\S]*?<\/span>/g, `<span id="footer-hours">${hoursText}</span>`);
    html = html.replace(/<div[^>]*?id="map-card-address">[\s\S]*?<\/div>/g, `<div style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 0.85rem;" id="map-card-address">${addressText}</div>`);

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send(html);
  } catch (err) {
    return res.sendFile(htmlPath);
  }
}

// Public Landing Page & Registration Routes
app.get('/landing', (req, res) => sendHydratedHTML(res, path.join(__dirname, 'public', 'landing.html')));
app.get('/register', (req, res) => sendHydratedHTML(res, path.join(__dirname, 'public', 'register.html')));
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

module.exports = { app, startServer };
