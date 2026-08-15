const mongoose = require('mongoose');

const shiftSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Shift name is required'],
    trim: true
  },
  code: {
    type: String,
    required: [true, 'Shift code is required'],
    unique: true,
    uppercase: true,
    trim: true
  },
  startTime: {
    type: String,
    required: [true, 'Start time is required'],
    trim: true
  },
  endTime: {
    type: String,
    required: [true, 'End time is required'],
    trim: true
  },
  maxCapacity: {
    type: Number,
    default: 0,
    min: [0, 'Max capacity cannot be negative']
  },
  priceMultiplier: {
    type: Number,
    default: 1.0,
    min: [0.1, 'Price multiplier must be at least 0.1']
  },
  daysActive: {
    type: [String],
    default: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
  },
  description: {
    type: String,
    trim: true
  },
  isActive: {
    type: Boolean,
    default: true
  },
  branch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Branch'
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Format time in 12h format helper virtual
shiftSchema.virtual('formattedTiming').get(function() {
  if (!this.startTime || !this.endTime) return '';
  const formatTime12 = (t) => {
    if (!t) return '';
    const parts = t.split(':');
    const h = parseInt(parts[0], 10);
    const m = parseInt(parts[1] || 0, 10);
    const period = h >= 12 ? 'PM' : 'AM';
    const hour12 = h % 12 || 12;
    return `${hour12.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')} ${period}`;
  };
  return `${formatTime12(this.startTime)} - ${formatTime12(this.endTime)}`;
});

// Duration in hours virtual
shiftSchema.virtual('durationHours').get(function() {
  if (!this.startTime || !this.endTime) return 0;
  const [h1, m1] = this.startTime.split(':').map(Number);
  const [h2, m2] = this.endTime.split(':').map(Number);
  let startMinutes = h1 * 60 + m1;
  let endMinutes = h2 * 60 + m2;
  if (endMinutes <= startMinutes) {
    endMinutes += 24 * 60; // Overnight
  }
  return Math.round(((endMinutes - startMinutes) / 60) * 10) / 10;
});

// Async pre-save hook without next param (Critical Rule 2)
shiftSchema.pre('save', async function() {
  if (this.code) {
    this.code = this.code.trim().toUpperCase();
  }
});

shiftSchema.statics.getActiveShifts = async function(branch = null) {
  const query = { isActive: true };
  if (branch) query.branch = branch;
  return this.find(query).sort({ startTime: 1, name: 1 });
};

shiftSchema.statics.seedDefaults = async function(branch = null) {
  const query = branch ? { branch } : {};
  const count = await this.countDocuments(query);
  if (count === 0) {
    const defaults = [
      {
        name: 'Morning Shift',
        code: 'MORN',
        startTime: '06:00',
        endTime: '14:00',
        maxCapacity: 0,
        priceMultiplier: 1.0,
        daysActive: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        description: 'Early morning to afternoon study session (06:00 AM - 02:00 PM)',
        isActive: true,
        ...(branch && { branch })
      },
      {
        name: 'Evening Shift',
        code: 'EVE',
        startTime: '14:00',
        endTime: '22:00',
        maxCapacity: 0,
        priceMultiplier: 1.0,
        daysActive: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        description: 'Afternoon to night study session (02:00 PM - 10:00 PM)',
        isActive: true,
        ...(branch && { branch })
      },
      {
        name: 'Full Day',
        code: 'FULL',
        startTime: '06:00',
        endTime: '22:00',
        maxCapacity: 0,
        priceMultiplier: 1.5,
        daysActive: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        description: 'Complete day access for dedicated students (06:00 AM - 10:00 PM)',
        isActive: true,
        ...(branch && { branch })
      },
      {
        name: 'Night Shift',
        code: 'NIGHT',
        startTime: '22:00',
        endTime: '06:00',
        maxCapacity: 0,
        priceMultiplier: 1.2,
        daysActive: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        description: 'Overnight silent study session (10:00 PM - 06:00 AM)',
        isActive: true,
        ...(branch && { branch })
      }
    ];
    return await this.insertMany(defaults);
  }
  return [];
};

module.exports = mongoose.model('Shift', shiftSchema);
