const mongoose = require('mongoose');

const lockerSchema = new mongoose.Schema({
  lockerNumber: {
    type: String,
    required: true,
    trim: true
  },
  size: {
    type: String,
    enum: ['small', 'medium', 'large'],
    default: 'medium'
  },
  block: {
    type: String,
    default: 'Block A'
  },
  floor: {
    type: String,
    default: 'Ground Floor'
  },
  monthlyFee: {
    type: Number,
    default: 0
  },
  depositFee: {
    type: Number,
    default: 0
  },
  status: {
    type: String,
    enum: ['available', 'occupied', 'maintenance'],
    default: 'available'
  },
  assignedStudent: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Student',
    default: null
  },
  assignedDate: {
    type: Date,
    default: null
  },
  expiryDate: {
    type: Date,
    default: null
  },
  depositAmount: {
    type: Number,
    default: 0
  },
  isDepositPaid: {
    type: Boolean,
    default: false
  },
  isDepositRefunded: {
    type: Boolean,
    default: false
  },
  keyNumber: {
    type: String,
    trim: true,
    default: ''
  },
  branch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Branch',
    default: null
  },
  notes: {
    type: String,
    trim: true,
    default: ''
  }
}, {
  timestamps: true
});

lockerSchema.index({ lockerNumber: 1, branch: 1 }, { unique: true });

module.exports = mongoose.model('Locker', lockerSchema);
