const mongoose = require('mongoose');

const branchSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Please provide a branch name'],
    trim: true
  },
  code: {
    type: String,
    required: [true, 'Please provide a unique branch code'],
    unique: true,
    uppercase: true,
    trim: true
  },
  address: {
    type: String,
    required: [true, 'Please provide an address'],
    trim: true
  },
  city: {
    type: String,
    required: [true, 'Please provide a city'],
    trim: true
  },
  state: {
    type: String,
    trim: true,
    default: ''
  },
  pincode: {
    type: String,
    trim: true,
    default: ''
  },
  phone: {
    type: String,
    required: [true, 'Please provide a contact phone number'],
    trim: true
  },
  email: {
    type: String,
    trim: true,
    lowercase: true,
    default: ''
  },
  manager: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  totalSeats: {
    type: Number,
    default: 50,
    min: [0, 'Total seats cannot be negative']
  },
  amenities: {
    type: [String],
    default: ['AC', 'WiFi', 'CCTV', 'Power Backup', 'RO Water', 'Locker']
  },
  isMainBranch: {
    type: Boolean,
    default: false
  },
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// Pre-save hook: uppercase code and ensure single main branch if this is set as main
branchSchema.pre('save', async function() {
  if (this.code) {
    this.code = this.code.toUpperCase().trim();
  }
  if (this.isMainBranch) {
    await this.constructor.updateMany(
      { _id: { $ne: this._id }, isMainBranch: true },
      { $set: { isMainBranch: false } }
    );
  }
});

// Static: Seed default main branch if none exist
branchSchema.statics.seedDefaults = async function() {
  const count = await this.countDocuments();
  if (count === 0) {
    return await this.create({
      name: 'Main Campus Central',
      code: 'BR-CENTRAL',
      address: '123 University Avenue, Knowledge Park',
      city: 'New Delhi',
      state: 'Delhi',
      pincode: '110001',
      phone: '+91 98765 43210',
      email: 'main@studylibrary.com',
      totalSeats: 50,
      amenities: ['AC', 'WiFi', 'CCTV', 'Power Backup', 'RO Water', 'Locker'],
      isMainBranch: true,
      isActive: true
    });
  }
};

module.exports = mongoose.model('Branch', branchSchema);
