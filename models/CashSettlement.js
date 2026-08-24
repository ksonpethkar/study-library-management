const mongoose = require('mongoose');

const cashSettlementSchema = new mongoose.Schema({
  settlementDate: {
    type: Date,
    default: Date.now,
    index: true
  },
  branch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Branch',
    default: null
  },
  closedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  openingCash: {
    type: Number,
    default: 0
  },
  cashCollected: {
    type: Number,
    required: true,
    default: 0
  },
  cashExpenses: {
    type: Number,
    default: 0
  },
  expectedClosingCash: {
    type: Number,
    required: true,
    default: 0
  },
  actualPhysicalCash: {
    type: Number,
    required: true,
    default: 0
  },
  variance: {
    type: Number,
    default: 0 // actualPhysicalCash - expectedClosingCash
  },
  denominations: {
    d500: { type: Number, default: 0 },
    d200: { type: Number, default: 0 },
    d100: { type: Number, default: 0 },
    d50:  { type: Number, default: 0 },
    d20:  { type: Number, default: 0 },
    d10:  { type: Number, default: 0 },
    coins:{ type: Number, default: 0 }
  },
  handoverTo: {
    type: String,
    trim: true,
    default: 'Next Shift Staff / Owner'
  },
  notes: {
    type: String,
    trim: true,
    default: ''
  },
  status: {
    type: String,
    enum: ['reconciled', 'variance_noted', 'approved'],
    default: 'reconciled'
  }
}, {
  timestamps: true
});

cashSettlementSchema.index({ settlementDate: -1, branch: 1 });

module.exports = mongoose.model('CashSettlement', cashSettlementSchema);
