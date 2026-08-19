const mongoose = require('mongoose');

const waitingListSchema = new mongoose.Schema({
  student: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Student'
  },
  studentName: {
    type: String,
    required: [true, 'Student name is required'],
    trim: true
  },
  studentPhone: {
    type: String,
    required: [true, 'Phone number is required'],
    trim: true
  },
  studentEmail: {
    type: String,
    trim: true,
    default: ''
  },
  preferredZone: {
    type: String,
    enum: ['Any', 'AC Zone', 'Non-AC Zone', 'Private Cabins', 'Open Hall', 'Ladies Reserved', 'Laptop Desks'],
    default: 'Any'
  },
  preferredShift: {
    type: String,
    default: 'Any'
  },
  priority: {
    type: Number,
    default: 1
  },
  status: {
    type: String,
    enum: ['waiting', 'offered', 'assigned', 'cancelled'],
    default: 'waiting'
  },
  offeredSeat: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Seat'
  },
  offerExpiresAt: {
    type: Date
  },
  notes: {
    type: String,
    trim: true,
    default: ''
  },
  branch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Branch'
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true
});

// Database Indexes
waitingListSchema.index({ branch: 1, status: 1, priority: 1 });
waitingListSchema.index({ status: 1, priority: 1 });

waitingListSchema.pre('save', async function() {
  if (this.isNew && (!this.priority || this.priority === 1)) {
    const lastItem = await this.constructor.findOne().sort({ priority: -1 });
    this.priority = lastItem && lastItem.priority ? lastItem.priority + 1 : 1;
  }
});

module.exports = mongoose.model('WaitingList', waitingListSchema);
