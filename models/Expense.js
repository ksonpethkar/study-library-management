const mongoose = require('mongoose');

const expenseSchema = new mongoose.Schema({
  category: {
    type: String,
    required: [true, 'Expense category is required']
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
  },
  // Soft Delete & Trash Support
  isDeleted: {
    type: Boolean,
    default: false,
    index: true
  },
  deletedAt: {
    type: Date
  },
  deletedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true
});

// Database Indexes
expenseSchema.index({ isDeleted: 1, branch: 1, date: -1 });
expenseSchema.index({ isDeleted: 1, branch: 1, category: 1 });
expenseSchema.index({ isDeleted: 1, date: -1 });
expenseSchema.index({ branch: 1, date: -1 });
expenseSchema.index({ branch: 1, category: 1 });
expenseSchema.index({ date: -1 });

// Statics for financial P&L aggregation
expenseSchema.statics.getMonthlyTotal = async function(year, month) {
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 0, 23, 59, 59);

  const result = await this.aggregate([
    { $match: { date: { $gte: start, $lte: end }, isDeleted: { $ne: true } } },
    { $group: { _id: null, total: { $sum: '$amount' } } }
  ]);

  return result.length > 0 ? result[0].total : 0;
};

expenseSchema.statics.getCategoryBreakdown = async function(year, month) {
  const matchStage = { isDeleted: { $ne: true } };
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
