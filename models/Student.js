const mongoose = require('mongoose');

const studentSchema = new mongoose.Schema({
  studentId: { type: String, unique: true },
  name: { type: String, required: true, trim: true },
  email: { type: String, lowercase: true, trim: true },
  phone: { type: String, required: true, trim: true },
  gender: { type: String, enum: ['male', 'female', 'other'] },
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
  admissionDate: { type: Date, default: Date.now },
  expiryDate: { type: Date },
  status: { type: String, enum: ['active', 'inactive', 'suspended', 'expired', 'pending', 'pending_payment'], default: 'active' },
  targetExams: [{ type: String, trim: true }],
  signature: { type: String }, // Base64 data URL from signature canvas pad
  bloodGroup: { type: String, trim: true },
  occupation: { type: String, trim: true },
  collegeOrCompany: { type: String, trim: true },
  rfidCardNumber: { type: String, trim: true, index: true },
  biometricId: { type: String, trim: true, index: true },
  emergencyContact: {
    name: { type: String },
    phone: { type: String },
    relation: { type: String }
  },
  notes: { type: String },
  customFields: { type: Map, of: mongoose.Schema.Types.Mixed, default: {} },
  branch: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
}, {
  timestamps: true
});

// Performance Database Indexes
studentSchema.index({ branch: 1, status: 1 });
studentSchema.index({ expiryDate: 1 });
studentSchema.index({ seat: 1 });
studentSchema.index({ name: 'text', phone: 'text', studentId: 'text' });
studentSchema.index({ phone: 1 });

studentSchema.pre('save', async function() {
  if (this.isNew && !this.studentId) {
    const year = new Date().getFullYear();
    const lastStudent = await this.constructor.findOne({
      studentId: new RegExp(`^STU-${year}-`)
    }).sort({ studentId: -1 });
    
    let serial = 1;
    if (lastStudent && lastStudent.studentId) {
      const parts = lastStudent.studentId.split('-');
      serial = parseInt(parts[2], 10) + 1;
    }
    
    this.studentId = `STU-${year}-${serial.toString().padStart(3, '0')}`;
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
