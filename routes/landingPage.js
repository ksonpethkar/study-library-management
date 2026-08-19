const express = require('express');
const router = express.Router();
const LandingPage = require('../models/LandingPage');
const Plan = require('../models/Plan');
const Shift = require('../models/Shift');
const BusinessProfile = require('../models/BusinessProfile');
const { Visitor } = require('../models/Operations');
const Notification = require('../models/Notification');
const { protect } = require('../middleware/auth');

const roleCheck = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Not authorized for this role' });
    }
    next();
  };
};

/**
 * @route   GET /api/landing
 * @desc    Get complete public landing page data (Hero, facilities, plans, gallery, rules, contact)
 * @access  Public
 */
router.get('/', async (req, res) => {
  try {
    let landingConfig = null;
    let businessProfile = {};
    let plans = [];
    let shifts = [];

    try {
      [landingConfig, businessProfile, plans, shifts] = await Promise.all([
        LandingPage.getPageConfig().catch(() => LandingPage.getDefaults()),
        BusinessProfile.getProfile().catch(() => ({})),
        Plan.find({ isActive: true }).sort({ displayOrder: 1, price: 1 }).catch(() => []),
        Shift.find({ isActive: true }).catch(() => [])
      ]);
    } catch (dbErr) {
      console.warn('Falling back to default landing configuration:', dbErr.message);
      landingConfig = LandingPage.getDefaults();
    }

    if (!landingConfig) landingConfig = LandingPage.getDefaults();

    res.json({
      success: true,
      data: {
        landing: landingConfig,
        businessProfile: {
          businessName: businessProfile?.businessName || 'Study Library',
          tagline: businessProfile?.tagline || 'Premier Air-Conditioned Reading Hall',
          logo: businessProfile?.logo || '',
          phone: businessProfile?.phone || '',
          email: businessProfile?.email || '',
          address: businessProfile?.address || '',
          city: businessProfile?.city || '',
          state: businessProfile?.state || '',
          pincode: businessProfile?.pincode || '',
          upiQrCode: businessProfile?.upiQrCode || '',
          socialLinks: businessProfile?.socialLinks || {}
        },
        plans: (plans || []).map(p => ({
          id: p._id,
          name: p.name,
          duration: p.duration,
          durationType: p.durationType,
          price: p.price,
          discount: p.discount,
          effectivePrice: p.price * (1 - (p.discount || 0) / 100),
          features: p.features || [],
          seatType: p.seatType,
          shift: p.shift,
          description: p.description
        })),
        shifts: (shifts || []).map(s => ({
          id: s._id,
          name: s.name,
          code: s.code,
          startTime: s.startTime,
          endTime: s.endTime,
          priceMultiplier: s.priceMultiplier
        }))
      }
    });
  } catch (err) {
    console.error('Error fetching landing page data:', err);
    res.json({
      success: true,
      data: {
        landing: LandingPage.getDefaults(),
        businessProfile: { businessName: 'Study Library', tagline: 'Premier Air-Conditioned Reading Hall' },
        plans: [],
        shifts: []
      }
    });
  }
});

/**
 * @route   POST /api/landing/enquiry
 * @desc    Submit student enquiry from landing page (creates Visitor/Lead record & admin alert)
 * @access  Public
 */
router.post('/enquiry', async (req, res) => {
  try {
    const { name, phone, email, exam, shift, message, preferredBranch } = req.body;

    if (!name || !phone) {
      return res.status(400).json({ success: false, message: 'Name and phone number are required' });
    }

    // Save as Visitor/Lead record
    const visitor = new Visitor({
      name: name.trim(),
      phone: phone.trim(),
      email: email ? email.trim() : '',
      targetExam: exam ? exam.trim() : 'Competitive Exam Aspirant',
      preferredSlot: shift || 'Any Available Shift',
      notes: `Website Enquiry: ${message || 'No additional message.'}`,
      status: 'inquiry',
      followUpDate: new Date(Date.now() + 24 * 60 * 60 * 1000) // Next day follow up
    });

    await visitor.save();

    // Create in-app admin notification
    try {
      await Notification.create({
        title: '📩 New Admission Enquiry',
        message: `${name} (${phone}) sent an enquiry for ${exam || 'Library Admission'}.`,
        type: 'admission',
        link: '#/operations'
      });
    } catch (notifErr) {
      console.warn('Could not create enquiry notification:', notifErr);
    }

    const config = await LandingPage.getPageConfig();

    res.status(201).json({
      success: true,
      message: config.enquiry?.successMessage || 'Enquiry submitted successfully! Our team will contact you shortly.',
      data: { id: visitor._id }
    });
  } catch (err) {
    console.error('Error submitting enquiry:', err);
    res.status(500).json({ success: false, message: err.message || 'Failed to submit enquiry' });
  }
});

/**
 * @route   PUT /api/landing
 * @desc    Update landing page configuration (Admin only)
 * @access  Private (Owner / Manager)
 */
router.put('/', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    let config = await LandingPage.getPageConfig();
    
    // Deep update fields
    const { hero, about, facilities, shifts, rules, gallery, faqs, testimonials, contact, enquiry, theme, footer, navbar, floatingActions, seo } = req.body;

    if (hero) config.hero = { ...config.hero.toObject(), ...hero };
    if (about) config.about = { ...config.about.toObject(), ...about };
    if (facilities) config.facilities = { ...config.facilities.toObject(), ...facilities };
    if (shifts) config.shifts = { ...config.shifts.toObject(), ...shifts };
    if (rules) config.rules = { ...config.rules.toObject(), ...rules };
    if (gallery) config.gallery = { ...config.gallery.toObject(), ...gallery };
    if (faqs) config.faqs = { ...config.faqs.toObject(), ...faqs };
    if (testimonials) config.testimonials = { ...config.testimonials.toObject(), ...testimonials };
    if (contact) config.contact = { ...config.contact.toObject(), ...contact };
    if (enquiry) config.enquiry = { ...config.enquiry.toObject(), ...enquiry };
    if (theme) config.theme = { ...config.theme.toObject(), ...theme };
    if (footer) config.footer = { ...config.footer.toObject(), ...footer };
    if (navbar) config.navbar = { ...config.navbar.toObject(), ...navbar };
    if (floatingActions) config.floatingActions = { ...config.floatingActions.toObject(), ...floatingActions };
    if (seo) config.seo = { ...config.seo.toObject(), ...seo };

    await config.save();

    res.json({
      success: true,
      data: config,
      message: 'Landing page updated successfully'
    });
  } catch (err) {
    console.error('Error updating landing page:', err);
    res.status(500).json({ success: false, message: err.message || 'Failed to update landing page' });
  }
});

/**
 * @route   POST /api/landing/reset
 * @desc    Reset landing page to default template
 * @access  Private (Owner only)
 */
router.post('/reset', protect, roleCheck('owner'), async (req, res) => {
  try {
    await LandingPage.deleteMany({});
    const newConfig = await LandingPage.create(LandingPage.getDefaults());
    res.json({
      success: true,
      data: newConfig,
      message: 'Landing page reset to default configuration'
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
