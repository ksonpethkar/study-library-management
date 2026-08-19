const mongoose = require('mongoose');

// 1. Visitor / Inquiry Schema
const visitorSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  phone: { type: String, required: true, trim: true },
  email: { type: String, trim: true },
  targetExam: { type: String, trim: true },
  preferredSlot: { type: String, trim: true },
  trialDate: { type: Date },
  followUpDate: { type: Date },
  status: { type: String, enum: ['inquiry', 'trial_booked', 'admitted', 'dropped'], default: 'inquiry' },
  notes: { type: String },
  branch: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' }
}, { timestamps: true });

// 2. Announcement / Notice Schema
const announcementSchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true },
  message: { type: String, required: true },
  category: { type: String, enum: ['general', 'holiday', 'rules', 'exam_alert', 'maintenance'], default: 'general' },
  priority: { type: String, enum: ['normal', 'high', 'urgent'], default: 'normal' },
  isPinned: { type: Boolean, default: false },
  branch: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' }
}, { timestamps: true });

// 3. Holiday Schema
const holidaySchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true },
  date: { type: Date, required: true },
  type: { type: String, enum: ['national', 'festival', 'maintenance', 'special'], default: 'festival' },
  isLibraryClosed: { type: Boolean, default: false },
  timingOverride: { type: String },
  description: { type: String }
}, { timestamps: true });

// 4. Lost & Found Schema
const lostFoundSchema = new mongoose.Schema({
  itemName: { type: String, required: true, trim: true },
  description: { type: String },
  category: { type: String, enum: ['electronics', 'books', 'stationery', 'clothing', 'other'], default: 'other' },
  foundLocation: { type: String, trim: true },
  foundDate: { type: Date, default: Date.now },
  status: { type: String, enum: ['found', 'claimed', 'discarded'], default: 'found' },
  claimedBy: { type: String, trim: true }
}, { timestamps: true });

// 5. Feedback & Complaint Schema
const feedbackSchema = new mongoose.Schema({
  studentName: { type: String, required: true, trim: true },
  category: { type: String, enum: ['cleanliness', 'ac_wifi', 'noise', 'seats', 'management', 'other'], default: 'other' },
  rating: { type: Number, min: 1, max: 5, default: 5 },
  message: { type: String, required: true },
  status: { type: String, enum: ['pending', 'in_progress', 'resolved'], default: 'pending' },
  adminReply: { type: String }
}, { timestamps: true });

// 6. Student Leave / Absence Request Schema
const leaveRequestSchema = new mongoose.Schema({
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'Student' },
  studentName: { type: String, required: true, trim: true },
  studentPhone: { type: String, trim: true },
  startDate: { type: Date, required: true },
  endDate: { type: Date, required: true },
  reason: { type: String, required: true, trim: true },
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' },
  adminReply: { type: String, default: '' },
  branch: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' }
}, { timestamps: true });

// 7. Student Seat Change Request Schema
const seatChangeRequestSchema = new mongoose.Schema({
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'Student' },
  studentName: { type: String, required: true, trim: true },
  studentPhone: { type: String, trim: true },
  currentSeat: { type: mongoose.Schema.Types.ObjectId, ref: 'Seat' },
  currentSeatNumber: { type: String },
  preferredZone: { type: String, required: true },
  reason: { type: String, required: true, trim: true },
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' },
  allocatedSeat: { type: mongoose.Schema.Types.ObjectId, ref: 'Seat' },
  adminReply: { type: String, default: '' }
}, { timestamps: true });

// 8. Refer-a-Friend / Referral System Schema
const referralSchema = new mongoose.Schema({
  referrerStudent: { type: mongoose.Schema.Types.ObjectId, ref: 'Student' },
  referrerName: { type: String, required: true, trim: true },
  referrerPhone: { type: String, trim: true },
  refereeName: { type: String, required: true, trim: true },
  refereePhone: { type: String, required: true, trim: true },
  refereeEmail: { type: String, trim: true, default: '' },
  referralCode: { type: String, uppercase: true, trim: true },
  targetExam: { type: String, trim: true, default: '' },
  notes: { type: String, trim: true, default: '' },
  status: { type: String, enum: ['pending', 'joined', 'approved', 'rewarded', 'rejected'], default: 'pending' },
  rewardAmount: { type: Number, default: 100 },
  reward: { type: String, default: '₹100 Discount on Next Month Fee' },
  discountApplied: { type: Boolean, default: false },
  convertedStudent: { type: mongoose.Schema.Types.ObjectId, ref: 'Student' },
  branch: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' }
}, { timestamps: true });

// Database Indexes for Operations Models
visitorSchema.index({ branch: 1, createdAt: -1 });
visitorSchema.index({ phone: 1 });
announcementSchema.index({ branch: 1, isPinned: -1, createdAt: -1 });
holidaySchema.index({ date: 1 });
lostFoundSchema.index({ status: 1, createdAt: -1 });
feedbackSchema.index({ status: 1, createdAt: -1 });
leaveRequestSchema.index({ branch: 1, status: 1, createdAt: -1 });
leaveRequestSchema.index({ student: 1, createdAt: -1 });
seatChangeRequestSchema.index({ status: 1, createdAt: -1 });
seatChangeRequestSchema.index({ student: 1 });
referralSchema.index({ referrerStudent: 1 });
referralSchema.index({ refereePhone: 1 });

const Visitor = mongoose.model('Visitor', visitorSchema);
const Announcement = mongoose.model('Announcement', announcementSchema);
const Holiday = mongoose.model('Holiday', holidaySchema);
const LostFound = mongoose.model('LostFound', lostFoundSchema);
const Feedback = mongoose.model('Feedback', feedbackSchema);
const LeaveRequest = mongoose.model('LeaveRequest', leaveRequestSchema);
const SeatChangeRequest = mongoose.model('SeatChangeRequest', seatChangeRequestSchema);
const Referral = mongoose.model('Referral', referralSchema);

module.exports = {
  Visitor,
  Announcement,
  Holiday,
  LostFound,
  Feedback,
  LeaveRequest,
  SeatChangeRequest,
  Referral
};
