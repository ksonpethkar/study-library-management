const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  message: {
    type: String,
    required: true,
    trim: true
  },
  type: {
    type: String,
    enum: ['expiry', 'payment', 'admission', 'system', 'seat', 'student', 'general'],
    default: 'system'
  },
  link: {
    type: String,
    default: ''
  },
  isRead: {
    type: Boolean,
    default: false
  },
  recipient: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  student: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Student',
    default: null
  },
  targetRole: {
    type: String,
    enum: ['admin', 'student', 'all'],
    default: 'all'
  }
}, {
  timestamps: true
});

notificationSchema.index({ isRead: 1, createdAt: -1 });
notificationSchema.index({ recipient: 1, isRead: 1 });
notificationSchema.index({ student: 1, isRead: 1 });
notificationSchema.index({ targetRole: 1, isRead: 1 });

module.exports = mongoose.model('Notification', notificationSchema);
