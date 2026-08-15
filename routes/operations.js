const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { Visitor, Announcement, Holiday, LostFound, Feedback } = require('../models/Operations');

router.use(protect);

// ----------------------------------------------------
// 1. Visitors & Leads
// ----------------------------------------------------
router.get('/visitors', async (req, res) => {
  try {
    const visitors = await Visitor.find().sort({ createdAt: -1 });
    res.json({ success: true, data: visitors });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/visitors', async (req, res) => {
  try {
    const visitor = await Visitor.create(req.body);
    res.json({ success: true, data: visitor, message: 'Visitor inquiry logged successfully' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/visitors/:id', async (req, res) => {
  try {
    const visitor = await Visitor.findByIdAndUpdate(req.params.id, req.body, { new: true, returnDocument: 'after' });
    res.json({ success: true, data: visitor, message: 'Visitor inquiry updated' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/visitors/:id', async (req, res) => {
  try {
    await Visitor.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Visitor record deleted' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 2. Announcements & Notice Board
// ----------------------------------------------------
router.get('/announcements', async (req, res) => {
  try {
    const announcements = await Announcement.find().sort({ isPinned: -1, createdAt: -1 });
    res.json({ success: true, data: announcements });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/announcements', async (req, res) => {
  try {
    const announcement = await Announcement.create(req.body);
    res.json({ success: true, data: announcement, message: 'Notice posted successfully' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/announcements/:id', async (req, res) => {
  try {
    await Announcement.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Notice removed' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 3. Holidays & Schedule
// ----------------------------------------------------
router.get('/holidays', async (req, res) => {
  try {
    const holidays = await Holiday.find().sort({ date: 1 });
    res.json({ success: true, data: holidays });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/holidays', async (req, res) => {
  try {
    const holiday = await Holiday.create(req.body);
    res.json({ success: true, data: holiday, message: 'Holiday scheduled' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/holidays/:id', async (req, res) => {
  try {
    await Holiday.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Holiday removed' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 4. Lost & Found
// ----------------------------------------------------
router.get('/lostfound', async (req, res) => {
  try {
    const items = await LostFound.find().sort({ createdAt: -1 });
    res.json({ success: true, data: items });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.post('/lostfound', async (req, res) => {
  try {
    const item = await LostFound.create(req.body);
    res.json({ success: true, data: item, message: 'Lost item recorded' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/lostfound/:id', async (req, res) => {
  try {
    const item = await LostFound.findByIdAndUpdate(req.params.id, req.body, { new: true, returnDocument: 'after' });
    res.json({ success: true, data: item, message: 'Item status updated' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.delete('/lostfound/:id', async (req, res) => {
  try {
    await LostFound.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Record deleted' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ----------------------------------------------------
// 5. Feedback & Complaints
// ----------------------------------------------------
router.get('/feedback', async (req, res) => {
  try {
    const feedbacks = await Feedback.find().sort({ createdAt: -1 });
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

router.put('/feedback/:id/reply', async (req, res) => {
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

router.delete('/feedback/:id', async (req, res) => {
  try {
    await Feedback.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Feedback deleted' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

const { LeaveRequest, SeatChangeRequest, Referral } = require('../models/Operations');
const Seat = require('../models/Seat');
const Student = require('../models/Student');

// ----------------------------------------------------
// 6. Student Leave Requests (Admin)
// ----------------------------------------------------
router.get('/leave-requests', async (req, res) => {
  try {
    const leaves = await LeaveRequest.find().sort({ createdAt: -1 });
    res.json({ success: true, data: leaves });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/leave-requests/:id', async (req, res) => {
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
router.get('/seat-changes', async (req, res) => {
  try {
    const requests = await SeatChangeRequest.find().populate('currentSeat allocatedSeat').sort({ createdAt: -1 });
    res.json({ success: true, data: requests });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/seat-changes/:id', async (req, res) => {
  try {
    const { status, allocatedSeatId, adminReply } = req.body;
    const updateData = { status, adminReply };

    if (status === 'approved' && allocatedSeatId) {
      updateData.allocatedSeat = allocatedSeatId;
      const reqDoc = await SeatChangeRequest.findById(req.params.id);

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
// 8. Referrals (Admin)
// ----------------------------------------------------
router.get('/referrals', async (req, res) => {
  try {
    const referrals = await Referral.find().sort({ createdAt: -1 });
    res.json({ success: true, data: referrals });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

router.put('/referrals/:id', async (req, res) => {
  try {
    const { status, reward } = req.body;
    const ref = await Referral.findByIdAndUpdate(
      req.params.id,
      { status, ...(reward && { reward }) },
      { new: true, returnDocument: 'after' }
    );
    res.json({ success: true, data: ref, message: `Referral status updated to ${status}` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
