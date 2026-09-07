/**
 * Smart WhatsApp Automation & Marketing Engine
 * Study Library Management System
 */

const Student = require('../models/Student');
const BusinessProfile = require('../models/BusinessProfile');
const Plan = require('../models/Plan');
const notificationService = require('./notificationService');

class MarketingService {
  /**
   * Generates a standard NPCI UPI Intent Deep Link
   * Compatible with Google Pay, PhonePe, Paytm, BHIM, and Banking apps
   */
  generateUpiDeepLink(upiId, libraryName, amount, studentName, note) {
    if (!upiId) return '';
    const cleanUpi = upiId.trim();
    const cleanName = (libraryName || 'Study Library').slice(0, 50);
    const cleanNote = (note || `Fee Renewal ${studentName || ''}`).trim().slice(0, 50);
    const formattedAmount = Number(amount || 0).toFixed(2);

    return `upi://pay?pa=${encodeURIComponent(cleanUpi)}&pn=${encodeURIComponent(cleanName)}&am=${formattedAmount}&cu=INR&tn=${encodeURIComponent(cleanNote)}`;
  }

  /**
   * Finds students approaching expiry (3 days, 1 day, today, or grace period)
   */
  async getRenewalCandidates() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const futureDate = new Date(today);
    futureDate.setDate(today.getDate() + 4); // Next 4 days

    const pastGraceDate = new Date(today);
    pastGraceDate.setDate(today.getDate() - 5); // Expired up to 5 days ago

    const students = await Student.find({
      status: { $in: ['active', 'expired'] },
      expiryDate: { $gte: pastGraceDate, $lte: futureDate }
    })
      .populate('plan')
      .populate('seat')
      .lean();

    const business = await BusinessProfile.getProfile();
    const upiId = business.upiId || '';
    const libraryName = business.businessName || 'The Cozy Corner Centre Study Library';

    return students.map(student => {
      const expDate = new Date(student.expiryDate);
      const diffMs = expDate.getTime() - today.getTime();
      const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

      let statusLabel = '';
      if (diffDays === 0) statusLabel = 'expires TODAY';
      else if (diffDays > 0) statusLabel = `expires in ${diffDays} day(s)`;
      else statusLabel = `expired ${Math.abs(diffDays)} day(s) ago`;

      const planPrice = student.plan?.price || 1500;
      const upiLink = this.generateUpiDeepLink(
        upiId,
        libraryName,
        planPrice,
        student.name,
        `Renewal ${student.studentId || student.name}`
      );

      const messageText = `👋 Hello *${student.name}*,\n\n` +
        `This is a friendly reminder from *${libraryName}*.\n` +
        `Your study membership ${statusLabel} (*${expDate.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}*).\n\n` +
        `💺 *Reserved Desk:* ${student.seat?.seatNumber ? `Seat #${student.seat.seatNumber}` : 'General Hall'}\n` +
        `📋 *Renewal Plan:* ${student.plan?.name || 'Monthly Study Plan'} (₹${planPrice})\n\n` +
        `To retain your desk and uninterrupted 24/7 library access, pay instantly via UPI:\n` +
        `📲 *1-Tap UPI Payment:* ${upiLink || 'Contact Reception'}\n\n` +
        `After payment, simply share your 12-digit UTR reference. Happy Studying! 📖✨`;

      return {
        studentId: student._id,
        code: student.studentId,
        name: student.name,
        phone: student.phone,
        expiryDate: student.expiryDate,
        diffDays,
        statusLabel,
        planName: student.plan?.name || 'Standard Plan',
        amount: planPrice,
        seatNumber: student.seat?.seatNumber || 'Unassigned',
        upiLink,
        messageText
      };
    });
  }

  /**
   * Batch dispatch renewal alerts through active WhatsApp gateway
   */
  async sendRenewalReminders(dryRun = false) {
    const candidates = await this.getRenewalCandidates();
    if (dryRun) {
      return {
        dryRun: true,
        count: candidates.length,
        candidates
      };
    }

    const results = { sent: 0, failed: 0, errors: [] };

    for (const candidate of candidates) {
      try {
        if (!candidate.phone || candidate.phone.length < 10) {
          results.failed++;
          continue;
        }

        const dispatchRes = await notificationService.sendWhatsAppMessage(
          candidate.phone,
          candidate.messageText,
          { studentId: candidate.studentId, type: 'renewal_reminder' }
        );

        if (dispatchRes.success) {
          results.sent++;
        } else {
          results.failed++;
          results.errors.push(`${candidate.name}: ${dispatchRes.error || 'Gateway dispatch failed'}`);
        }
      } catch (sendErr) {
        results.failed++;
        results.errors.push(`${candidate.name}: ${sendErr.message}`);
      }
    }

    return {
      success: true,
      totalCandidates: candidates.length,
      ...results
    };
  }

  /**
   * Generates a motivational study quote broadcast message
   */
  getRandomMotivationQuote() {
    const quotes = [
      "\"Success doesn't come from what you do occasionally, it comes from what you do consistently.\" Keep pushing! 🚀",
      "\"The expert in anything was once a beginner.\" Stay focused during your library hours today! 📚",
      "\"Small daily improvements over time lead to stunning results.\" Make every hour count! 💡",
      "\"Discipline is choosing between what you want now and what you want most.\" Have a productive study day! 🎯"
    ];
    return quotes[Math.floor(Math.random() * quotes.length)];
  }
}

module.exports = new MarketingService();
