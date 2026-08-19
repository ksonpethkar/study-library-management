const mongoose = require('mongoose');

const attendanceSchema = new mongoose.Schema({
  student: { type: mongoose.Schema.Types.ObjectId, ref: 'Student', required: true },
  date: { type: Date, required: true },
  checkIn: Date,
  checkOut: Date,
  duration: Number, // in minutes
  status: { type: String, enum: ['present', 'absent', 'late', 'half_day'], default: 'present' },
  seat: { type: mongoose.Schema.Types.ObjectId, ref: 'Seat' },
  shift: String,
  notes: String,
  markedBy: { type: String, enum: ['manual', 'auto', 'self', 'biometric'], default: 'manual' },
  branch: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' }
}, {
  timestamps: true
});

attendanceSchema.index({ student: 1, date: 1 }, { unique: true });
attendanceSchema.index({ branch: 1, date: 1 });
attendanceSchema.index({ branch: 1, student: 1, date: -1 });
attendanceSchema.index({ date: 1, status: 1 });

attendanceSchema.pre('save', async function() {
  if (this.checkIn && this.checkOut) {
    const diffMs = new Date(this.checkOut).getTime() - new Date(this.checkIn).getTime();
    this.duration = Math.max(0, Math.round(diffMs / (1000 * 60)));
  }
});

attendanceSchema.statics.getTodayStats = async function() {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date();
  endOfDay.setHours(23, 59, 59, 999);

  const todayRecords = await this.find({ date: { $gte: startOfDay, $lte: endOfDay } });
  
  const totalPresent = todayRecords.filter(r => ['present', 'late', 'half_day'].includes(r.status)).length;
  const totalAbsent = todayRecords.filter(r => r.status === 'absent').length;
  const currentlyCheckedIn = todayRecords.filter(r => r.checkIn && !r.checkOut).length;

  return { totalPresent, totalAbsent, currentlyCheckedIn };
};

attendanceSchema.statics.getMonthlyReport = async function(studentId, month, year) {
  const startDate = new Date(year, month - 1, 1);
  const endDate = new Date(year, month, 0, 23, 59, 59, 999);

  return this.find({
    student: studentId,
    date: { $gte: startDate, $lte: endDate }
  }).sort({ date: 1 });
};

module.exports = mongoose.model('Attendance', attendanceSchema);
