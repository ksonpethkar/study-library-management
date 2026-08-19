const mongoose = require('mongoose');

const businessProfileSchema = new mongoose.Schema({
  businessName: {
    type: String,
    default: 'Study Library'
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
    default: 'thecozycorner@okaxis'
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
