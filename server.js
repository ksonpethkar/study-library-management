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

app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Body parser
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Apply rate limiting
app.use(generalLimiter);

// Compression Middleware for optimized asset delivery & performance
const compression = require('compression');
app.use(compression());

// Static folder
app.use(express.static(path.join(__dirname, 'public')));
const uploadsDir = path.join(__dirname, 'uploads');
if (!require('fs').existsSync(uploadsDir)) {
  require('fs').mkdirSync(uploadsDir, { recursive: true });
}
app.use('/uploads', express.static(uploadsDir));

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
    const [businessProfile, customFields, template, plans, shifts, branches] = await Promise.all([
      BusinessProfile.getProfile().catch(() => ({})),
      CustomField.getActiveFields().catch(() => []),
      FormTemplate.getActiveTemplate().catch(() => null),
      Plan.find({ isActive: true }).sort('displayOrder').lean().catch(() => []),
      Shift.find({ isActive: true }).sort('startTime').lean().catch(() => []),
      Branch.find({ isActive: true }).lean().catch(() => [])
    ]);

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

// Public Landing Page & Registration Routes
app.get('/landing', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'landing.html'));
});

app.get('/register', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'register.html'));
});

// Dedicated Student Portal Login Route
app.get(['/student-login', '/portal-login'], (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'student-login.html'));
});

// Self-Service Kiosk / Gate Scanner Route
app.get('/kiosk', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'kiosk.html'));
});

// SPA fallback — only for non-API GET requests
app.use((req, res, next) => {
  if (req.method === 'GET' && !req.path.startsWith('/api')) {
    return res.sendFile(path.join(__dirname, 'public', 'index.html'));
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

startServer();
