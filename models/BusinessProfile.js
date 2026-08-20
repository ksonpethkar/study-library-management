const mongoose = require('mongoose');

const businessProfileSchema = new mongoose.Schema({
  businessName: {
    type: String,
    default: 'The Cozy Corner Centre'
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
  paymentInstructions: {
    type: String,
    default: 'Please enter your 12-digit UTR / Reference number after completing payment.'
  },
  enableUpiDeepLinks: {
    type: Boolean,
    default: true
  },
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

// Static method to get the singleton profile
businessProfileSchema.statics.getProfile = async function() {
  let profile = await this.findOne();
  if (!profile) {
    profile = await this.create({});
  }
  return profile;
};

module.exports = mongoose.model('BusinessProfile', businessProfileSchema);
