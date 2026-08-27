const mongoose = require('mongoose');

const studentSchema = new mongoose.Schema({
  studentId: { type: String, unique: true },
  name: { type: String, required: true, trim: true },
  email: { type: String, lowercase: true, trim: true },
  phone: { type: String, required: true, trim: true },
  gender: {
    type: String,
    enum: ['male', 'female', 'other', 'Male', 'Female', 'Other', 'MALE', 'FEMALE', 'OTHER', ''],
    set: v => (v ? String(v).toLowerCase().trim() : undefined)
  },
  dateOfBirth: { type: Date },
  address: { type: String },
  city: { type: String },
  state: { type: String },
  pincode: { type: String },
  idProof: {
    type: { type: String },
    number: { type: String },
    image: { type: String }
  },
  photo: { type: String },
  plan: { type: mongoose.Schema.Types.ObjectId, ref: 'Plan' },
  seat: { type: mongoose.Schema.Types.ObjectId, ref: 'Seat' },
  locker: { type: mongoose.Schema.Types.ObjectId, ref: 'Locker' },
  shift: { type: mongoose.Schema.Types.ObjectId, ref: 'Shift' },
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  admissionDate: { type: Date, default: Date.now },
  expiryDate: { type: Date },
  status: {
    type: String,
    enum: ['active', 'inactive', 'suspended', 'expired', 'pending', 'pending_payment', 'grace_period', 'Active', 'Inactive', 'Suspended', 'Expired', 'Pending', 'Pending_Payment', 'Grace_Period', 'GRACE_PERIOD'],
    set: v => (v ? String(v).toLowerCase().trim() : 'active'),
    default: 'active'
  },
  targetExams: [{ type: String, trim: true }],
  signature: { type: String }, // Base64 data URL from signature canvas pad
  bloodGroup: { type: String, trim: true },
  occupation: { type: String, trim: true },
  collegeOrCompany: { type: String, trim: true },
  biometricCardNumber: { type: String, trim: true, index: true },
  biometricCredentials: [{
    credentialId: { type: String, required: true },
    publicKey: { type: String, required: true },
    counter: { type: Number, default: 0 },
    transports: [{ type: String }],
    createdAt: { type: Date, default: Date.now }
  }],
  emergencyContact: {
    name: { type: String },
    phone: { type: String },
    relation: { type: String }
  },
  // Referral Program & Wallet Balance Fields
  referralCode: { type: String, uppercase: true, trim: true, sparse: true, index: true },
  referredBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Student' },
  referralCredits: { type: Number, default: 0 },
  walletBalance: { type: Number, default: 0 },
  totalReferralsCount: { type: Number, default: 0 },
  // Gamified Leaderboard & Badges
  badges: [{
    badgeId: { type: String },
    title: { type: String },
    icon: { type: String },
    description: { type: String },
    earnedAt: { type: Date, default: Date.now }
  }],
  studyStreakDays: { type: Number, default: 0 },
  notes: { type: String },
  customFields: { type: Map, of: mongoose.Schema.Types.Mixed, default: {} },
  branch: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  // Soft Delete & Trash Support
  isDeleted: { type: Boolean, default: false, index: true },
  deletedAt: { type: Date },
  deletedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
}, {
  timestamps: true
});

// Performance & Soft-Delete Compound Database Indexes
studentSchema.index({ isDeleted: 1, branch: 1, status: 1 });
studentSchema.index({ isDeleted: 1, branch: 1, status: 1, expiryDate: 1 });
studentSchema.index({ isDeleted: 1, branch: 1, plan: 1 });
studentSchema.index({ isDeleted: 1, seat: 1, shift: 1, status: 1 });
studentSchema.index({ isDeleted: 1, locker: 1 });
studentSchema.index({ isDeleted: 1, expiryDate: 1 });
studentSchema.index({ isDeleted: 1, seat: 1 });
studentSchema.index({ isDeleted: 1, phone: 1 });
studentSchema.index({ isDeleted: 1, email: 1 });
studentSchema.index({ isDeleted: 1, status: 1 });
studentSchema.index({ isDeleted: 1, createdAt: -1 });
studentSchema.index({ name: 'text', phone: 'text', studentId: 'text' });

studentSchema.pre('save', async function() {
  if (this.isNew && !this.studentId) {
    const { generateStudentId } = require('../utils/idGenerator');
    this.studentId = await generateStudentId({ branch: this.branch });
  }

  // Auto-generate referral code if missing
  if (!this.referralCode) {
    const cleanName = (this.name || 'MEMBER').replace(/[^a-zA-Z]/g, '').toUpperCase().slice(0, 5) || 'STUDY';
    const randSuffix = Math.floor(100 + Math.random() * 900);
    this.referralCode = `${cleanName}${randSuffix}`;
  }
});

studentSchema.statics.getStats = async function(query = {}) {
  const [total, active, inactive, expired, newThisMonth] = await Promise.all([
    this.countDocuments(query),
    this.countDocuments({ ...query, status: 'active' }),
    this.countDocuments({ ...query, status: 'inactive' }),
    this.countDocuments({ ...query, status: 'expired' }),
    this.countDocuments({ 
      ...query, 
      createdAt: { 
        $gte: new Date(new Date().getFullYear(), new Date().getMonth(), 1) 
      } 
    })
  ]);
  
  return { total, active, inactive, expired, newThisMonth };
};

module.exports = mongoose.model('Student', studentSchema);
