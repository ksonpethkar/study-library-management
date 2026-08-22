// Force Google DNS — fixes networks that block SRV record lookups for MongoDB Atlas
const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const connectDB = require('./config/db');
const { generalLimiter } = require('./middleware/rateLimiter');
const { errorHandler, initProcessErrorHandlers } = require('./middleware/errorMiddleware');

// Initialize process crash catchers for uncaught exceptions and unhandled rejections
initProcessErrorHandlers();

const app = express();

// Security Middleware — configured to allow inline scripts, Google Fonts, and our own assets
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      imgSrc: ["'self'", "data:", "blob:", "https:"],
      connectSrc: ["'self'", "https://api.postalpincode.in", "https://api.qrserver.com", "https://api.zippopotam.us"],
    }
  },
  crossOriginEmbedderPolicy: false,
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

// Body parser
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Apply rate limiting
app.use(generalLimiter);

// Compression Middleware for optimized asset delivery & performance
const compression = require('compression');
app.use(compression());

// Static folder with caching
app.use(express.static(path.join(__dirname, 'public'), {
  maxAge: process.env.NODE_ENV === 'production' ? '1d' : 0,
  etag: true,
  lastModified: true
}));
const uploadsDir = path.join(__dirname, 'uploads');
if (!require('fs').existsSync(uploadsDir)) {
  require('fs').mkdirSync(uploadsDir, { recursive: true });
}
app.use('/uploads', express.static(uploadsDir, { maxAge: '7d' }));

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
app.use('/api/system', require('./routes/systemConfig'));
app.use('/api/system', require('./routes/systemHealth'));

// Health check endpoint for uptime monitoring & Render.com
app.get('/api/health', (req, res) => {
  const mongoose = require('mongoose');
  const dbStatus = mongoose.connection.readyState === 1 ? 'connected' : 'disconnected';
  res.json({
    status: 'healthy',
    uptime: Math.round(process.uptime()),
    timestamp: new Date().toISOString(),
    database: dbStatus,
    version: '1.0.0'
  });
});

// Public Configuration Endpoint for Admission Wizard & System
app.get('/api/system/public-config', async (req, res) => {
  try {
    const BusinessProfile = require('./models/BusinessProfile');
    const CustomField = require('./models/CustomField');
    const FormTemplate = require('./models/FormTemplate');
    const Plan = require('./models/Plan');
    const Shift = require('./models/Shift');
    const Branch = require('./models/Branch');

    await CustomField.seedDefaultFields().catch(() => {});
    const Seat = require('./models/Seat');
    const [businessProfile, customFields, template, plans, shifts, rawBranches, occupiedCounts] = await Promise.all([
      BusinessProfile.getProfile().catch(() => ({})),
      CustomField.getActiveFields().catch(() => []),
      FormTemplate.getActiveTemplate().catch(() => null),
      Plan.find({ isActive: true }).sort('displayOrder').lean().catch(() => []),
      Shift.find({ isActive: true }).sort('startTime').lean().catch(() => []),
      Branch.find({ isActive: true }).lean().catch(() => []),
      Seat.aggregate([
        { $match: { status: 'occupied', isActive: true, branch: { $ne: null } } },
        { $group: { _id: '$branch', count: { $sum: 1 } } }
      ]).catch(() => [])
    ]);

    let branches = [];
    if (rawBranches && rawBranches.length > 0) {
      const occupiedMap = new Map((occupiedCounts || []).map(c => [String(c._id), c.count]));
      branches = rawBranches.map(b => {
        const occupiedSeats = occupiedMap.get(String(b._id)) || 0;
        const totalSeats = b.totalSeats || 50;
        return {
          ...b,
          occupiedSeats,
          availableSeats: Math.max(0, totalSeats - occupiedSeats)
        };
      });
    } else {
      branches = [{
        _id: 'default_main',
        name: 'Main Campus Central',
        code: 'MAIN',
        city: 'Central City',
        address: 'Main Reading Hall Complex',
        phone: '+91 9876543210',
        totalSeats: 50,
        occupiedSeats: 1,
        availableSeats: 49
      }];
    }

    res.json({
      success: true,
      data: {
        businessProfile,
        customFields,
        template,
        plans,
        shifts,
        branches
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Server-Side HTML Pre-hydration Engine (Admin Changes Are Final & Served Directly From MongoDB)
async function sendHydratedHTML(res, htmlPath) {
  try {
    let html = fs.readFileSync(htmlPath, 'utf8');
    const BusinessProfile = require('./models/BusinessProfile');
    const LandingPage = require('./models/LandingPage');

    const [profile, landing] = await Promise.all([
      BusinessProfile.getProfile().catch(() => ({})),
      LandingPage.getPageConfig().catch(() => ({}))
    ]);

    const bName = landing?.navbar?.brandName || profile?.businessName || 'The Cozy Corner Centre';
    const bLogo = landing?.navbar?.brandLogo || profile?.logo || '';
    const tagline = landing?.footer?.tagline || profile?.tagline || '';

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
      let ht = landing.hero.title.replace(/Study Library|StudyLib/gi, bName);
      if (ht.includes(bName) && !ht.includes(`<span>${bName}</span>`)) {
        ht = ht.replace(bName, `<span>${bName}</span>`);
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

const startServer = async () => {
  // Start Express first (so frontend is always accessible)
  app.listen(PORT, () => {
    console.log(`\n  ✅ Server running on http://localhost:${PORT}`);
    console.log(`  📂 Mode: ${process.env.NODE_ENV || 'development'}`);
    console.log(`  🌐 Open in browser: http://localhost:${PORT}\n`);
  });

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
