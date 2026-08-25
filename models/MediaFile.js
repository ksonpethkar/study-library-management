const mongoose = require('mongoose');

const mediaFileSchema = new mongoose.Schema({
  filename: {
    type: String,
    required: true,
    unique: true,
    index: true,
    trim: true
  },
  mimeType: {
    type: String,
    required: true,
    default: 'image/jpeg'
  },
  data: {
    type: Buffer,
    required: true
  },
  size: {
    type: Number,
    default: 0
  },
  folder: {
    type: String,
    default: 'uploads'
  },
  uploadedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('MediaFile', mediaFileSchema);
