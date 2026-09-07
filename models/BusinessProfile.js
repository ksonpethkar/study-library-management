const mongoose = require('mongoose');

const businessProfileSchema = new mongoose.Schema({
  businessName: {
    type: String,
    default: 'The Cozy Corner Centre Study Library & Reading Hall'
  },
  tagline: String,
  logo: String,
  favicon: String,
  address: String,
  city: String,
  state: String,
  pincode: String,
  phone: String,
  email: String,
  website: String,
  gstNumber: String,
  registrationNumber: String,
  upiQrCode: String,
  upiId: {
    type: String,
    default: ''
  },
  bankDetails: {
    accountName: { type: String, default: '' },
    accountNumber: { type: String, default: '' },
    ifscCode: { type: String, default: '' },
    bankName: { type: String, default: '' },
    branchName: { type: String, default: '' }
  },
  targetExams: {
    type: [String],
    default: ['UPSC Civil Services', 'State PSC / MPSC', 'SSC / CGL', 'Banking & RBI', 'IIT-JEE', 'NEET Medical', 'Chartered Accountancy (CA)', 'GATE / Engineering', 'Judiciary / CLAT', 'Defense / CDS']
  },
  rules: {
    type: [String],
    default: [
      'Maintain absolute silence in reading zones at all times.',
      'Mobile phones must remain on silent mode. Calls must be attended outside.',
      'Do not reserve empty desks with personal belongings when away.',
      'Smoking, tobacco, and outside cooked food are strictly prohibited.',
      'Ensure cleanliness and take care of study desks, charging points, and library facilities.'
    ]
  },
  paymentInstructions: {
    type: String,
    default: 'Please enter your 12-digit UTR / Reference number after completing payment.'
  },
  enableUpiDeepLinks: {
    type: Boolean,
    default: true
  },
  // Payment Gateway Settings (Option B - Razorpay / Cashfree / PhonePe Webhooks)
  gatewayProvider: { type: String, enum: ['manual_upi', 'razorpay', 'cashfree', 'phonepe'], default: 'manual_upi' },
  razorpayKeyId: { type: String, default: '' },
  razorpaySecret: { type: String, default: '' },
  razorpayWebhookSecret: { type: String, default: '' },
  cashfreeAppId: { type: String, default: '' },
  cashfreeSecret: { type: String, default: '' },
  phonepeMerchantId: { type: String, default: '' },
  phonepeSaltKey: { type: String, default: '' },
  enableAutoWebhookVerification: { type: Boolean, default: true },
  paymentMethods: [
    {
      key: { type: String, default: 'upi' },
      name: { type: String, default: 'Dynamic UPI QR' },
      subtitle: { type: String, default: 'GPay / PhonePe / Paytm / BHIM' },
      icon: { type: String, default: '⚡' },
      enabled: { type: Boolean, default: true },
      order: { type: Number, default: 1 },
      instructions: { type: String, default: 'Scan QR code and enter 12-digit UTR number' },
      requiresRef: { type: Boolean, default: true },
      refLabel: { type: String, default: 'UPI UTR / Reference Number *' }
    },
    {
      key: { type: String, default: 'card' },
      name: { type: String, default: 'Debit / Credit Card' },
      subtitle: { type: String, default: 'Visa, Mastercard, RuPay' },
      icon: { type: String, default: '💳' },
      enabled: { type: Boolean, default: true },
      order: { type: Number, default: 2 },
      instructions: { type: String, default: 'Enter cardholder name and card transaction reference' },
      requiresRef: { type: Boolean, default: true },
      refLabel: { type: String, default: 'Card Reference / Transaction ID *' }
    },
    {
      key: { type: String, default: 'netbanking' },
      name: { type: String, default: 'NetBanking' },
      subtitle: { type: String, default: 'All major Indian banks' },
      icon: { type: String, default: '🏦' },
      enabled: { type: Boolean, default: true },
      order: { type: Number, default: 3 },
      instructions: { type: String, default: 'Transfer fee to official bank account and enter bank UTR' },
      requiresRef: { type: Boolean, default: true },
      refLabel: { type: String, default: 'Bank Transaction Reference / UTR *' }
    },
    {
      key: { type: String, default: 'desk' },
      name: { type: String, default: 'Pay Later at Desk' },
      subtitle: { type: String, default: 'Pay cash on arrival' },
      icon: { type: String, default: '💵' },
      enabled: { type: Boolean, default: true },
      order: { type: Number, default: 4 },
      instructions: { type: String, default: 'Admission will be pre-reserved. Pay cash at front reception desk.' },
      requiresRef: { type: Boolean, default: false },
      refLabel: { type: String, default: '' }
    }
  ],
  stampImage: String,
  bannerImage: String,
  coverImage: String,
  socialLinks: {
    facebook: String,
    instagram: String,
    whatsapp: String
  },
  isSetupComplete: {
    type: Boolean,
    default: false
  }
}, { timestamps: true });

let _cachedProfile = null;
let _cachedProfileTime = 0;

// Static method to get the singleton profile with caching and fallback
businessProfileSchema.statics.getProfile = async function(forceRefresh = false) {
  if (!forceRefresh && _cachedProfile && (Date.now() - _cachedProfileTime < 60000)) {
    return _cachedProfile;
  }
  try {
    const fetchPromise = this.findOne().lean();
    const timeoutPromise = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('BusinessProfile query timed out')), 2500)
    );
    let profile = await Promise.race([fetchPromise, timeoutPromise]);
    if (!profile) {
      const doc = await this.create({});
      profile = doc.toObject ? doc.toObject() : doc;
    }
    _cachedProfile = profile;
    _cachedProfileTime = Date.now();
    return profile;
  } catch (err) {
    if (_cachedProfile) return _cachedProfile;
    return {
      businessName: 'The Cozy Corner Centre Study Library & Reading Hall',
      rules: [
        'Maintain absolute silence in reading zones at all times.',
        'Mobile phones must remain on silent mode. Calls must be attended outside.',
        'Do not reserve empty desks with personal belongings when away.'
      ],
      targetExams: ['UPSC Civil Services', 'State PSC / MPSC', 'SSC / CGL', 'Banking & RBI', 'IIT-JEE', 'NEET Medical']
    };
  }
};

businessProfileSchema.statics.invalidateCache = function() {
  _cachedProfile = null;
  _cachedProfileTime = 0;
};

module.exports = mongoose.model('BusinessProfile', businessProfileSchema);
