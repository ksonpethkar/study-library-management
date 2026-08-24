const mongoose = require('mongoose');

const trashSchema = new mongoose.Schema({
  itemType: {
    type: String,
    required: true,
    enum: [
      'student', 'payment', 'expense', 'expense_category', 'plan', 'branch',
      'shift', 'seat', 'locker', 'custom_field', 'form_template', 'coupon',
      'waiting_list', 'visitor', 'announcement', 'holiday', 'lost_found', 'feedback', 'other'
    ],
    index: true
  },
  itemId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
    index: true
  },
  itemTitle: {
    type: String,
    required: true,
    trim: true
  },
  itemSubtitle: {
    type: String,
    default: '',
    trim: true
  },
  originalCollection: {
    type: String,
    required: true
  },
  itemData: {
    type: mongoose.Schema.Types.Mixed,
    required: true
  },
  deletedAt: {
    type: Date,
    default: Date.now,
    index: true
  },
  deletedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  deletedByName: {
    type: String,
    default: 'Admin'
  },
  deletionReason: {
    type: String,
    default: ''
  }
}, {
  timestamps: true
});

// Composite Indexes for high-speed filtering and search
trashSchema.index({ itemType: 1, deletedAt: -1 });
trashSchema.index({ deletedAt: -1 });
trashSchema.index({ itemTitle: 'text', itemSubtitle: 'text' });

module.exports = mongoose.model('Trash', trashSchema);
