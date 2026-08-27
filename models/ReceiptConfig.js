const mongoose = require('mongoose');

const receiptConfigSchema = new mongoose.Schema({
  activeTemplate: {
    type: String,
    enum: ['standard_a4', 'standardA4', 'thermal_80', 'thermal80', 'thermal_58', 'thermal58', 'modern_minimal', 'gst_invoice'],
    default: 'thermal80'
  },
  
  // Header customization
  header: {
    showLogo: { type: Boolean, default: true },
    logoUrl: { type: String, default: '' },
    logoPosition: { type: String, enum: ['left', 'center', 'right'], default: 'center' },
    showBusinessName: { type: Boolean, default: true },
    subtitle: { type: String, default: 'Official Fee Receipt' },
    showAddress: { type: Boolean, default: true },
    showPhone: { type: Boolean, default: true },
    showEmail: { type: Boolean, default: true },
    showGst: { type: Boolean, default: true },
    taxNumber: { type: String, default: '' },
    gstNumber: { type: String, default: '' },
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
  
  // Stamp & Watermark customization
  stamp: {
    showStamp: { type: Boolean, default: true },
    stampText: { type: String, default: 'PAID • OFFICIAL RECEIPT' },
    stampColor: { type: String, default: '#059669' },
    stampImage: { type: String, default: '' },
    showWatermark: { type: Boolean, default: true },
    watermarkText: { type: String, default: 'PAID • OFFICIAL FEE RECEIPT' },
    watermarkOpacity: { type: Number, default: 0.12 }
  },

  // Date & Time formatting
  dateTime: {
    format: { type: String, enum: ['date_only', 'date_time_12h', 'date_time_24h'], default: 'date_time_12h' },
    showTimestamp: { type: Boolean, default: true }
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
    stampImage: { type: String, default: '' },
    showSignature: { type: Boolean, default: true },
    signatureImage: { type: String, default: '' },
    signatureLabel: { type: String, default: 'Authorized Signatory' },
    showUpiQr: { type: Boolean, default: true },
    termsText: { type: String, default: '1. Fees paid are non-refundable. 2. Seat assignment is strictly non-transferable.' },
    customNote: { type: String, default: 'Thank you for choosing our study library!' },
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
