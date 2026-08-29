const mongoose = require('mongoose');

const formTemplateSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  slug: { type: String, required: true, unique: true, lowercase: true },
  description: { type: String, default: '' },
  isActive: { type: Boolean, default: false },  // only one active at a time
  
  // Visual theme
  theme: {
    primaryColor: { type: String, default: '#4f46e5' },
    accentColor: { type: String, default: '#06b6d4' },
    backgroundColor: { type: String, default: '#ffffff' },
    cardBackground: { type: String, default: '#f8fafc' },
    textColor: { type: String, default: '#1e293b' },
    borderRadius: { type: Number, default: 12 },
    fontFamily: { type: String, default: 'Inter, system-ui, sans-serif' },
    style: { type: String, enum: ['clean', 'glassmorphism', 'flat', 'vibrant', 'dark'], default: 'clean' }
  },
  
  // Form settings
  settings: {
    showProgressBar: { type: Boolean, default: true },
    showSectionNumbers: { type: Boolean, default: true },
    showRequiredIndicator: { type: Boolean, default: true },
    submitButtonText: { type: String, default: 'Submit Registration' },
    successMessage: { type: String, default: 'Registration submitted successfully! You will receive a confirmation soon.' },
    enableAutoSave: { type: Boolean, default: false },
    showTimestamp: { type: Boolean, default: true },
    // Step 5: Membership Plan & Add-ons Visibility Controls
    showPlans: { type: Boolean, default: true },
    showLockerAddon: { type: Boolean, default: true },
    showReferralCoupon: { type: Boolean, default: true },
    showShiftSelection: { type: Boolean, default: true },
    showFeeBreakdown: { type: Boolean, default: true },

    // Step 6: Live Payment Methods & Sub-Option Gateway Breakdown Controls
    showUpiPayment: { type: Boolean, default: true },
    showCardPayment: { type: Boolean, default: true },
    showDeskPayment: { type: Boolean, default: true },
    showNetBankingPayment: { type: Boolean, default: true },
    showWhatsappReceipt: { type: Boolean, default: true },
    showEmailConfirmation: { type: Boolean, default: true },
    showTaxInvoice: { type: Boolean, default: true },
    upiPaymentLabel: { type: String, default: 'Dynamic UPI QR' },
    upiPaymentSubtext: { type: String, default: 'GPay / PhonePe / Paytm + 12-digit UTR Verification' },
    cardPaymentLabel: { type: String, default: 'Debit / Credit Card' },
    cardPaymentSubtext: { type: String, default: 'Visa, Mastercard, RuPay & POS' },
    deskPaymentLabel: { type: String, default: 'Pay Later at Desk' },
    deskPaymentSubtext: { type: String, default: 'Pre-reserves admission & seat; cash paid on arrival' },
    netBankingPaymentLabel: { type: String, default: 'NetBanking / Bank Transfer' },
    netBankingPaymentSubtext: { type: String, default: 'NEFT / IMPS / RTGS (All Indian banks)' },
    whatsappReceiptLabel: { type: String, default: 'Automated WhatsApp Receipt' },
    emailConfirmationLabel: { type: String, default: 'Email Payment Confirmation' },
    taxInvoiceLabel: { type: String, default: 'Tax Invoice Generation' },

    // Step 7: Seat Selection & Digital Signature Sub-Options Controls
    showSeatSelection: { type: Boolean, default: true },
    seatSelectionLabel: { type: String, default: 'Circular Seat Badges / Desk Map' },
    seatSelectionSubtext: { type: String, default: '22px round circular seat checkmarks with Indigo glow' },
    seatSelectionRequired: { type: Boolean, default: false },

    showDigitalSignature: { type: Boolean, default: true },
    digitalSignatureLabel: { type: String, default: 'Digital Signature Canvas' },
    digitalSignatureSubtext: { type: String, default: 'Touch & stylus interactive drawing pad' },
    digitalSignatureRequired: { type: Boolean, default: true },

    showPassportSelfie: { type: Boolean, default: true },
    passportSelfieLabel: { type: String, default: 'Passport Selfie Capture' },
    passportSelfieSubtext: { type: String, default: 'Webcam photo & document crop studio' },
    passportSelfieRequired: { type: Boolean, default: false },

    showQuietStudyAgreement: { type: Boolean, default: true },
    quietStudyAgreementTitle: { type: String, default: 'Quiet Study Code & Library Rules Agreement' },
    quietStudyAgreementRules: { type: String, default: '1. Pin-Drop Silence: Strict silence must be maintained inside reading halls at all times. Whispering or phone calls inside study zones is strictly forbidden.\n2. Mobile Phone Protocol: Phones must be switched to silent or flight mode. Attend urgent phone calls outside in corridors.\n3. Assigned Desk Protocol: Occupy only your allotted desk number and adhere strictly to your registered shift timing.\n4. Cleanliness & Socket Safety: Keep your study desk clean. Turn off lights, fans, and socket chargers when leaving your seat.\n5. ID Pass & Gate Access: Carry your Student ID / Registration Pass for kiosk check-in.\n6. Fee Policy & Non-Refundability: Membership fees once paid are non-refundable.' },
    quietStudyConsentText: { type: String, default: 'I have read, understood, and agree to strictly abide by the Library Rules, Code of Conduct, and Payment Policies.' },
    quietStudyRequired: { type: Boolean, default: true },

    showKioskBarcode: { type: Boolean, default: true },
    kioskBarcodeLabel: { type: String, default: 'Kiosk Entry Barcode' },
    kioskBarcodeSubtext: { type: String, default: 'Instant admission barcode for turnstile / attendance gate' }
  },
  
  // Branding
  branding: {
    showLogo: { type: Boolean, default: true },
    showBanner: { type: Boolean, default: false },
    bannerImage: { type: String, default: '' },
    headerText: { type: String, default: 'Student Registration Form' },
    tagline: { type: String, default: 'Silence, Focus & Success' },
    alignment: { type: String, default: 'center' },
    logoSize: { type: String, default: '64' },
    footerText: { type: String, default: '' },
    termsText: { type: String, default: 'I agree to the library rules and terms of membership.' },
    termsUrl: { type: String, default: '' }
  },

  // Dynamic Form Sections (Fully Customizable & Persisted)
  sections: [{
    name: { type: String, required: true },
    label: { type: String, required: true },
    icon: { type: String, default: 'personal' },
    order: { type: Number, default: 0 },
    isSystem: { type: Boolean, default: false },
    isHidden: { type: Boolean, default: false }
  }]
}, { timestamps: true });

const DEFAULT_SECTIONS = [
  { name: 'personal', label: 'Step 1: Study Centre & Personal Info', icon: 'personal', order: 1, isSystem: true },
  { name: 'address', label: 'Step 2: Address & Emergency Contact', icon: 'contact', order: 2, isSystem: false },
  { name: 'kyc', label: 'Step 3: KYC & Verification', icon: 'kyc', order: 3, isSystem: false },
  { name: 'academic', label: 'Step 4: Academic Goals & KYC Proof', icon: 'academic', order: 4, isSystem: false },
  { name: 'plan', label: 'Step 5: Membership Plan & Fee Calculator', icon: 'plan', order: 5, isSystem: true },
  { name: 'payment', label: 'Step 6: Dynamic Payment Selection', icon: 'payment', order: 6, isSystem: true },
  { name: 'seat', label: 'Step 7: Seat Selection & Digital Signature', icon: 'seat', order: 7, isSystem: true },
  { name: 'other', label: 'Step 8: Additional Information', icon: 'other', order: 8, isSystem: false }
];

// Ensure only one template is active
formTemplateSchema.pre('save', async function() {
  if (this.isActive && this.isModified('isActive')) {
    await this.constructor.updateMany(
      { _id: { $ne: this._id } },
      { isActive: false }
    );
  }
});

// Get active template or default
formTemplateSchema.statics.getActiveTemplate = async function() {
  let template = await this.findOne({ isActive: true });
  if (!template) {
    template = await this.findOne();
    if (!template) {
      template = await this.create({
        name: 'Clean Professional',
        slug: 'clean-professional',
        isActive: true,
        theme: { style: 'clean' },
        sections: DEFAULT_SECTIONS
      });
    }
  }

  // Populate sections if empty
  if (!template.sections || template.sections.length === 0) {
    template.sections = DEFAULT_SECTIONS;
    await template.save();
  }

  return template;
};

// Seed 5 default presets
formTemplateSchema.statics.seedDefaults = async function() {
  const count = await this.countDocuments();
  if (count > 0) return;
  
  await this.insertMany([
    {
      name: 'Clean Professional',
      slug: 'clean-professional',
      isActive: true,
      theme: { style: 'clean', primaryColor: '#4f46e5', backgroundColor: '#ffffff', cardBackground: '#f8fafc', textColor: '#1e293b', borderRadius: 12 },
      branding: { headerText: 'Student Registration Form' }
    },
    {
      name: 'Modern Glass',
      slug: 'modern-glass',
      theme: { style: 'glassmorphism', primaryColor: '#8b5cf6', accentColor: '#06b6d4', backgroundColor: '#0f172a', cardBackground: 'rgba(255,255,255,0.08)', textColor: '#f1f5f9', borderRadius: 16 },
      branding: { headerText: 'Join Our Study Community' }
    },
    {
      name: 'Minimal Flat',
      slug: 'minimal-flat',
      theme: { style: 'flat', primaryColor: '#0f172a', backgroundColor: '#ffffff', cardBackground: '#ffffff', textColor: '#334155', borderRadius: 4, fontFamily: 'DM Sans, system-ui, sans-serif' },
      branding: { headerText: 'Registration' }
    },
    {
      name: 'Vibrant Colorful',
      slug: 'vibrant-colorful',
      theme: { style: 'vibrant', primaryColor: '#f59e0b', accentColor: '#ec4899', backgroundColor: '#fffbeb', cardBackground: '#ffffff', textColor: '#1e293b', borderRadius: 16 },
      branding: { headerText: '🎓 Start Your Journey!' }
    },
    {
      name: 'Dark Premium',
      slug: 'dark-premium',
      theme: { style: 'dark', primaryColor: '#22d3ee', accentColor: '#a78bfa', backgroundColor: '#0f172a', cardBackground: '#1e293b', textColor: '#e2e8f0', borderRadius: 12 },
      branding: { headerText: 'Member Registration' }
    }
  ]);
};

module.exports = mongoose.model('FormTemplate', formTemplateSchema);
