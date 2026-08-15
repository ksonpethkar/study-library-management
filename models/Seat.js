const mongoose = require('mongoose');

const seatSchema = new mongoose.Schema({
  seatNumber: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  zone: {
    type: String,
    required: true,
    trim: true
  },
  floor: {
    type: String,
    trim: true
  },
  type: {
    type: String,
    enum: ['regular', 'premium', 'cabin'],
    default: 'regular'
  },
  status: {
    type: String,
    enum: ['available', 'occupied', 'reserved', 'maintenance'],
    default: 'available'
  },
  currentStudent: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Student'
  },
  amenities: [{
    type: String
  }],
  monthlyRate: {
    type: Number
  },
  branch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Branch'
  },
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// Performance Database Indexes
seatSchema.index({ branch: 1, zone: 1, status: 1 });
seatSchema.index({ currentStudent: 1 });
seatSchema.index({ status: 1 });

seatSchema.statics.getStats = async function() {
  const stats = await this.aggregate([
    {
      $group: {
        _id: null,
        total: { $sum: 1 },
        available: {
          $sum: { $cond: [{ $eq: ['$status', 'available'] }, 1, 0] }
        },
        occupied: {
          $sum: { $cond: [{ $eq: ['$status', 'occupied'] }, 1, 0] }
        },
        reserved: {
          $sum: { $cond: [{ $eq: ['$status', 'reserved'] }, 1, 0] }
        },
        maintenance: {
          $sum: { $cond: [{ $eq: ['$status', 'maintenance'] }, 1, 0] }
        }
      }
    }
  ]);
  
  if (stats.length === 0) {
    return { total: 0, available: 0, occupied: 0, reserved: 0, maintenance: 0 };
  }
  
  const { _id, ...result } = stats[0];
  return result;
};

seatSchema.statics.getZones = async function() {
  return this.distinct('zone');
};

seatSchema.pre('save', async function() {
  // Add any pre-save logic here if needed
  if (this.currentStudent && this.status === 'available') {
    this.status = 'occupied';
  } else if (!this.currentStudent && this.status === 'occupied') {
    this.status = 'available';
  }
});

module.exports = mongoose.model('Seat', seatSchema);
