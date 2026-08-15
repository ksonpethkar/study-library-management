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
    showTimestamp: { type: Boolean, default: true }
  },
  
  // Branding
  branding: {
    showLogo: { type: Boolean, default: true },
    showBanner: { type: Boolean, default: false },
    bannerImage: { type: String, default: '' },
    headerText: { type: String, default: 'Student Registration Form' },
    footerText: { type: String, default: '' },
    termsText: { type: String, default: 'I agree to the library rules and terms of membership.' },
    termsUrl: { type: String, default: '' }
  }
}, { timestamps: true });

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
        theme: { style: 'clean' }
      });
    }
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
