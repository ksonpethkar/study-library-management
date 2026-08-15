const mongoose = require('mongoose');

const receiptConfigSchema = new mongoose.Schema({
  activeTemplate: {
    type: String,
    enum: ['standard_a4', 'thermal_80', 'thermal_58', 'modern_minimal', 'gst_invoice'],
    default: 'standard_a4'
  },
  
  // Header customization
  header: {
    showLogo: { type: Boolean, default: true },
    logoPosition: { type: String, enum: ['left', 'center', 'right'], default: 'center' },
    showBusinessName: { type: Boolean, default: true },
    subtitle: { type: String, default: 'Official Fee Receipt' },
    showAddress: { type: Boolean, default: true },
    showPhone: { type: Boolean, default: true },
    showEmail: { type: Boolean, default: true },
    showGst: { type: Boolean, default: true },
    headerColor: { type: String, default: '#4f46e5' }
  },
  
  // Body customization
  body: {
    showStudentId: { type: Boolean, default: true },
    showStudentPhone: { type: Boolean, default: true },
    showStudentEmail: { type: Boolean, default: false },
    showPlanDetails: { type: Boolean, default: true },
    showPeriod: { type: Boolean, default: true },
    showDiscount: { type: Boolean, default: true },
    showLateFee: { type: Boolean, default: true },
    showPaymentMethod: { type: Boolean, default: true },
    showTransactionId: { type: Boolean, default: true },
    showSeatNumber: { type: Boolean, default: false },
    showShift: { type: Boolean, default: false }
  },
  
  // GST Invoice fields
  gst: {
    enabled: { type: Boolean, default: false },
    gstRate: { type: Number, default: 18 },
    hsnCode: { type: String, default: '9992' },
    showCgstSgst: { type: Boolean, default: true },
    placeOfSupply: { type: String, default: '' }
  },
  
  // Footer customization
  footer: {
    showStamp: { type: Boolean, default: true },
    showSignature: { type: Boolean, default: true },
    signatureLabel: { type: String, default: 'Authorized Signatory' },
    showUpiQr: { type: Boolean, default: false },
    termsText: { type: String, default: 'This is a computer-generated receipt and does not require a physical signature.' },
    customNote: { type: String, default: 'Thank you for choosing our library!' },
    showTimestamp: { type: Boolean, default: true }
  }
}, { timestamps: true });

// Singleton pattern
receiptConfigSchema.statics.getConfig = async function() {
  let config = await this.findOne();
  if (!config) config = await this.create({});
  return config;
};

module.exports = mongoose.model('ReceiptConfig', receiptConfigSchema);
