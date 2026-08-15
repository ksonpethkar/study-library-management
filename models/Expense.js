const mongoose = require('mongoose');

const expenseSchema = new mongoose.Schema({
  category: {
    type: String,
    required: [true, 'Expense category is required'],
    enum: [
      'Rent',
      'Electricity',
      'Salaries & Staff',
      'High-Speed Wi-Fi & Tech',
      'RO Water & Dispenser',
      'Cleaning & Housekeeping',
      'Maintenance & Repairs',
      'Stationery & Printing',
      'Security & CCTV',
      'Taxes & Legal',
      'Marketing & Ads',
      'Other'
    ],
    default: 'Other'
  },
  title: {
    type: String,
    required: [true, 'Expense title is required'],
    trim: true
  },
  description: {
    type: String,
    trim: true,
    default: ''
  },
  amount: {
    type: Number,
    required: [true, 'Amount is required'],
    min: [0, 'Amount cannot be negative']
  },
  date: {
    type: Date,
    default: Date.now
  },
  paymentMethod: {
    type: String,
    enum: ['cash', 'upi', 'bank_transfer', 'card', 'cheque', 'other'],
    default: 'upi'
  },
  vendor: {
    type: String,
    trim: true,
    default: ''
  },
  receiptUrl: {
    type: String,
    default: ''
  },
  receiptImage: {
    type: String,
    default: ''
  },
  isRecurring: {
    type: Boolean,
    default: false
  },
  recurringFrequency: {
    type: String,
    enum: ['monthly', 'quarterly', 'yearly', 'none'],
    default: 'none'
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

// Statics for financial P&L aggregation
expenseSchema.statics.getMonthlyTotal = async function(year, month) {
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 0, 23, 59, 59);

  const result = await this.aggregate([
    { $match: { date: { $gte: start, $lte: end } } },
    { $group: { _id: null, total: { $sum: '$amount' } } }
  ]);

  return result.length > 0 ? result[0].total : 0;
};

expenseSchema.statics.getCategoryBreakdown = async function(year, month) {
  const matchStage = {};
  if (year && month) {
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0, 23, 59, 59);
    matchStage.date = { $gte: start, $lte: end };
  }

  return await this.aggregate([
    { $match: matchStage },
    {
      $group: {
        _id: '$category',
        total: { $sum: '$amount' },
        count: { $sum: 1 }
      }
    },
    { $sort: { total: -1 } }
  ]);
};

module.exports = mongoose.model('Expense', expenseSchema);
