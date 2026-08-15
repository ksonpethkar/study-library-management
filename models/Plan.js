const mongoose = require('mongoose');

const planSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Plan name is required'],
    trim: true
  },
  duration: {
    type: Number,
    required: [true, 'Duration is required'],
    min: [1, 'Duration must be at least 1']
  },
  durationType: {
    type: String,
    enum: ['days', 'months', 'years'],
    default: 'days'
  },
  price: {
    type: Number,
    required: [true, 'Price is required'],
    min: [0, 'Price cannot be negative']
  },
  description: {
    type: String,
    trim: true
  },
  features: [{
    type: String,
    trim: true
  }],
  seatType: {
    type: String,
    enum: ['any', 'regular', 'premium', 'cabin'],
    default: 'any'
  },
  shift: {
    type: String,
    enum: ['any', 'morning', 'evening', 'fullday', 'night'],
    default: 'any'
  },
  isActive: {
    type: Boolean,
    default: true
  },
  discount: {
    type: Number,
    default: 0,
    min: [0, 'Discount cannot be negative'],
    max: [100, 'Discount cannot exceed 100']
  },
  maxStudents: {
    type: Number,
    default: 0
  },
  branch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Branch'
  },
  displayOrder: {
    type: Number,
    default: 0
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

planSchema.virtual('effectivePrice').get(function() {
  if (this.price === undefined || this.price === null) return 0;
  return this.price * (1 - (this.discount || 0) / 100);
});

planSchema.virtual('enrolledCount', {
  ref: 'Student',
  localField: '_id',
  foreignField: 'plan',
  count: true
});

planSchema.statics.seedDefaults = async function() {
  const count = await this.countDocuments();
  if (count === 0) {
    await this.insertMany([
      {
        name: 'Monthly Full Day (16 Hrs)',
        duration: 30,
        durationType: 'days',
        price: 1200,
        description: 'Complete 06:00 AM – 10:00 PM access with reserved seat and all amenities.',
        features: ['Full Day 16-Hour Access', 'AC & Ergonomic Chair', '300 Mbps Wi-Fi', '100% Power Backup', 'RO Water Dispenser'],
        seatType: 'regular',
        shift: 'fullday',
        isActive: true,
        displayOrder: 1
      },
      {
        name: 'Monthly Morning Shift (8 Hrs)',
        duration: 30,
        durationType: 'days',
        price: 800,
        description: '06:00 AM – 02:00 PM morning shift, perfect for early risers.',
        features: ['Morning 8-Hour Access', 'AC Reading Hall', 'High-Speed Wi-Fi', 'RO Mineral Water', 'Charging Socket'],
        seatType: 'regular',
        shift: 'morning',
        isActive: true,
        displayOrder: 2
      },
      {
        name: 'Monthly Evening Shift (8 Hrs)',
        duration: 30,
        durationType: 'days',
        price: 800,
        description: '02:00 PM – 10:00 PM evening shift, ideal for college students & job goers.',
        features: ['Evening 8-Hour Access', 'Air-Conditioned Comfort', 'High-Speed Wi-Fi', 'RO Water Dispenser', 'Desk Lamp'],
        seatType: 'regular',
        shift: 'evening',
        isActive: true,
        displayOrder: 3
      },
      {
        name: 'Quarterly Full Day (3 Months)',
        duration: 90,
        durationType: 'days',
        price: 3300,
        discount: 10,
        description: 'Quarterly membership with 10% discount and complimentary personal locker.',
        features: ['Full Day 16-Hour Access (90 Days)', 'Free Personal Locker', 'Reserved Dedicated Seat', 'Dual AC & 300 Mbps Wi-Fi', '100% Online UPS Backup'],
        seatType: 'cabin',
        shift: 'fullday',
        isActive: true,
        displayOrder: 4
      },
      {
        name: 'Night Owl Shift (8 Hrs)',
        duration: 30,
        durationType: 'days',
        price: 900,
        description: '10:00 PM – 06:00 AM overnight shift with pin-drop silence and high focus.',
        features: ['Overnight 8-Hour Access', 'Ultra Quiet Ambience', 'High-Speed Wi-Fi', 'Tea & Coffee Facility', 'CCTV Security'],
        seatType: 'regular',
        shift: 'night',
        isActive: true,
        displayOrder: 5
      }
    ]);
  }
};

module.exports = mongoose.model('Plan', planSchema);
