const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');
const { Visitor, Announcement, Holiday, LostFound, Feedback, LeaveRequest, SeatChangeRequest, Referral } = require('../models/Operations');
const ReferralConfig = require('../models/ReferralConfig');
const Student = require('../models/Student');

router.use(protect);

// ----------------------------------------------------
// 1. Visitors & Leads
// ----------------------------------------------------
router.get('/visitors', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const visitors = await Visitor.find().sort({ createdAt: -1 }).limit(500).lean();
    res.json({ success: true, data: visitors });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/visitors', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const visitor = await Visitor.create(req.body);
    res.json({ success: true, data: visitor, message: 'Visitor inquiry logged successfully' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/visitors/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const visitor = await Visitor.findByIdAndUpdate(req.params.id, req.body, { new: true, returnDocument: 'after' });
    res.json({ success: true, data: visitor, message: 'Visitor inquiry updated' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/visitors/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { moveToTrash } = require('./trash');
    const visitor = await Visitor.findById(req.params.id);
    if (visitor) {
      await moveToTrash({
        itemType: 'visitor',
        itemId: visitor._id,
        itemTitle: `Visitor: ${visitor.name || 'Inquiry'}`,
        itemSubtitle: `Phone: ${visitor.phone || 'N/A'} • Purpose: ${visitor.purpose || 'Study Hall Visit'}`,
        originalCollection: 'visitors',
        itemData: visitor.toObject ? visitor.toObject() : visitor,
        user: req.user
      });
      await Visitor.findByIdAndDelete(req.params.id);
    }
    res.json({ success: true, message: 'Visitor record moved to Recycle Bin (Trash)' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 2. Announcements & Notice Board
// ----------------------------------------------------
router.get('/announcements', async (req, res) => {
  try {
    const announcements = await Announcement.find().sort({ isPinned: -1, createdAt: -1 }).lean();
    res.json({ success: true, data: announcements });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/announcements', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const announcement = await Announcement.create(req.body);
    res.json({ success: true, data: announcement, message: 'Notice posted successfully' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/announcements/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { moveToTrash } = require('./trash');
    const notice = await Announcement.findById(req.params.id);
    if (notice) {
      await moveToTrash({
        itemType: 'announcement',
        itemId: notice._id,
        itemTitle: `Notice: ${notice.title || 'Announcement'}`,
        itemSubtitle: `Target: ${(notice.targetAudience || 'all').toUpperCase()} • Pinned: ${notice.isPinned ? 'Yes' : 'No'}`,
        originalCollection: 'announcements',
        itemData: notice.toObject ? notice.toObject() : notice,
        user: req.user
      });
      await Announcement.findByIdAndDelete(req.params.id);
    }
    res.json({ success: true, message: 'Notice moved to Recycle Bin (Trash)' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 3. Holidays & Closures
// ----------------------------------------------------
router.get('/holidays', async (req, res) => {
  try {
    const holidays = await Holiday.find().sort({ startDate: 1 }).lean();
    res.json({ success: true, data: holidays });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/holidays', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const holiday = await Holiday.create(req.body);
    res.json({ success: true, data: holiday, message: 'Holiday scheduled' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/holidays/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { moveToTrash } = require('./trash');
    const hol = await Holiday.findById(req.params.id);
    if (hol) {
      await moveToTrash({
        itemType: 'holiday',
        itemId: hol._id,
        itemTitle: `Holiday: ${hol.title || 'Closure'}`,
        itemSubtitle: `Date: ${hol.startDate ? new Date(hol.startDate).toLocaleDateString() : 'TBD'}`,
        originalCollection: 'holidays',
        itemData: hol.toObject ? hol.toObject() : hol,
        user: req.user
      });
      await Holiday.findByIdAndDelete(req.params.id);
    }
    res.json({ success: true, message: 'Holiday removed to Recycle Bin (Trash)' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 4. Lost & Found
// ----------------------------------------------------
router.get('/lostfound', async (req, res) => {
  try {
    const items = await LostFound.find().sort({ createdAt: -1 }).lean();
    res.json({ success: true, data: items });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/lostfound', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const item = await LostFound.create(req.body);
    res.json({ success: true, data: item, message: 'Lost item recorded' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/lostfound/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const item = await LostFound.findByIdAndUpdate(req.params.id, req.body, { new: true, returnDocument: 'after' });
    res.json({ success: true, data: item, message: 'Item status updated' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/lostfound/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { moveToTrash } = require('./trash');
    const lf = await LostFound.findById(req.params.id);
    if (lf) {
      await moveToTrash({
        itemType: 'lost_found',
        itemId: lf._id,
        itemTitle: `Lost Item: ${lf.title || lf.itemName || 'Item'}`,
        itemSubtitle: `Found at: ${lf.location || 'Hall'} • Status: ${(lf.status || 'open').toUpperCase()}`,
        originalCollection: 'lostfounds',
        itemData: lf.toObject ? lf.toObject() : lf,
        user: req.user
      });
      await LostFound.findByIdAndDelete(req.params.id);
    }
    res.json({ success: true, message: 'Record moved to Recycle Bin (Trash)' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 5. Feedback & Complaints
// ----------------------------------------------------
router.get('/feedback', async (req, res) => {
  try {
    const feedbacks = await Feedback.find().sort({ createdAt: -1 }).lean();
    res.json({ success: true, data: feedbacks });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/feedback', async (req, res) => {
  try {
    const fb = await Feedback.create(req.body);
    res.json({ success: true, data: fb, message: 'Feedback submitted' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/feedback/:id/reply', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const fb = await Feedback.findByIdAndUpdate(
      req.params.id,
      { adminReply: req.body.adminReply, status: req.body.status || 'resolved' },
      { new: true, returnDocument: 'after' }
    );
    res.json({ success: true, data: fb, message: 'Reply sent' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/feedback/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { moveToTrash } = require('./trash');
    const fb = await Feedback.findById(req.params.id);
    if (fb) {
      await moveToTrash({
        itemType: 'feedback',
        itemId: fb._id,
        itemTitle: `Feedback: ${fb.subject || fb.title || 'Student Query'}`,
        itemSubtitle: `Student: ${fb.studentName || 'Anonymous'} • Status: ${(fb.status || 'open').toUpperCase()}`,
        originalCollection: 'feedbacks',
        itemData: fb.toObject ? fb.toObject() : fb,
        user: req.user
      });
      await Feedback.findByIdAndDelete(req.params.id);
    }
    res.json({ success: true, message: 'Feedback moved to Recycle Bin (Trash)' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

const Seat = require('../models/Seat');

// ----------------------------------------------------
// 6. Student Leave Requests (Admin)
// ----------------------------------------------------
router.get('/leave-requests', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const leaves = await LeaveRequest.find().sort({ createdAt: -1 }).lean();
    res.json({ success: true, data: leaves });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/leave-requests/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { status, adminReply } = req.body;
    const leave = await LeaveRequest.findByIdAndUpdate(
      req.params.id,
      { status, adminReply },
      { new: true, returnDocument: 'after' }
    );
    res.json({ success: true, data: leave, message: `Leave request ${status}` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 7. Student Seat Change Requests (Admin)
// ----------------------------------------------------
router.get('/seat-changes', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const requests = await SeatChangeRequest.find().populate('currentSeat allocatedSeat').sort({ createdAt: -1 }).lean();
    res.json({ success: true, data: requests });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/seat-changes/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { status, allocatedSeatId, adminReply } = req.body;
    const updateData = { status, adminReply };

    if (status === 'approved' && allocatedSeatId) {
      updateData.allocatedSeat = allocatedSeatId;
      const reqDoc = await SeatChangeRequest.findById(req.params.id).lean();

      if (reqDoc && reqDoc.student) {
        // Release old seat
        if (reqDoc.currentSeat) {
          await Seat.findByIdAndUpdate(reqDoc.currentSeat, { status: 'available', currentStudent: null });
        }
        // Assign new seat
        await Seat.findByIdAndUpdate(allocatedSeatId, {
          status: 'occupied',
          currentStudent: reqDoc.student,
          assignedAt: new Date()
        });
        // Update student record
        await Student.findByIdAndUpdate(reqDoc.student, { seat: allocatedSeatId });
      }
    }

    const updated = await SeatChangeRequest.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, returnDocument: 'after' }
    );

    res.json({ success: true, data: updated, message: `Seat change request ${status}` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 8. Referral Program Configuration & Management (Admin)
// ----------------------------------------------------
router.get('/referrals/config', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const config = await ReferralConfig.getConfig();
    res.json({ success: true, data: config });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/referrals/config', roleCheck('owner'), async (req, res) => {
  try {
    let config = await ReferralConfig.findOne().lean();
    if (!config) {
      config = await ReferralConfig.create(req.body);
    } else {
      config = await ReferralConfig.findByIdAndUpdate(config._id, req.body, { new: true, returnDocument: 'after' });
    }
    res.json({ success: true, data: config, message: 'Referral program settings updated successfully!' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.get('/referrals', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const referrals = await Referral.find()
      .populate('referrerStudent', 'name studentId phone referralCode referralCredits')
      .populate('convertedStudent', 'name studentId phone admissionDate')
      .sort({ createdAt: -1 });
    res.json({ success: true, data: referrals });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/referrals', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { referrerStudentId, refereeName, refereePhone, refereeEmail, targetExam, notes, rewardAmount } = req.body;
    
    let referrerStudent = null;
    let referrerName = req.body.referrerName || 'Staff Manual Entry';
    let referrerPhone = '';
    let referralCode = '';

    if (referrerStudentId) {
      referrerStudent = await Student.findById(referrerStudentId).lean();
      if (referrerStudent) {
        referrerName = referrerStudent.name;
        referrerPhone = referrerStudent.phone;
        referralCode = referrerStudent.referralCode;
      }
    }

    const ref = await Referral.create({
      referrerStudent: referrerStudent ? referrerStudent._id : undefined,
      referrerName,
      referrerPhone,
      refereeName,
      refereePhone,
      refereeEmail: refereeEmail || '',
      referralCode,
      targetExam: targetExam || '',
      notes: notes || '',
      rewardAmount: Number(rewardAmount || 100),
      reward: `₹${rewardAmount || 100} Discount on Next Month Fee`,
      status: 'pending'
    });

    res.status(201).json({ success: true, data: ref, message: 'Referral recorded successfully!' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/referrals/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const { status, reward, rewardAmount, notes } = req.body;
    const updateData = {};
    if (status !== undefined) updateData.status = status;
    if (reward !== undefined) updateData.reward = reward;
    if (rewardAmount !== undefined) updateData.rewardAmount = rewardAmount;
    if (notes !== undefined) updateData.notes = notes;

    const ref = await Referral.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, returnDocument: 'after' }
    );
    res.json({ success: true, data: ref, message: `Referral updated successfully` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/referrals/:id/approve-reward', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const ref = await Referral.findById(req.params.id);
    if (!ref) return res.status(404).json({ success: false, message: 'Referral record not found' });
    
    if (ref.discountApplied) {
      return res.status(400).json({ success: false, message: 'Reward discount has already been applied for this referral' });
    }

    const rewardAmt = Number(req.body.rewardAmount || ref.rewardAmount || 100);

    // Credit to referrer student
    if (ref.referrerStudent) {
      const student = await Student.findById(ref.referrerStudent);
      if (student) {
        student.referralCredits = (student.referralCredits || 0) + rewardAmt;
        student.totalReferralsCount = (student.totalReferralsCount || 0) + 1;
        await student.save();
      }
    }

    ref.status = 'rewarded';
    ref.discountApplied = true;
    ref.rewardAmount = rewardAmt;
    ref.reward = `₹${rewardAmt} Discount on Next Renewal`;
    await ref.save();

    res.json({ success: true, data: ref, message: `₹${rewardAmt} referral reward credited to student account for next renewal!` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/referrals/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    await Referral.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Referral record deleted successfully' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
