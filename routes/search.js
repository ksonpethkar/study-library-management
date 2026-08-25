const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const Student = require('../models/Student');
const Seat = require('../models/Seat');
const Plan = require('../models/Plan');
const Payment = require('../models/Payment');
const { lookupPincode } = require('../utils/pincodeLookup');

// @route   POST /api/search/ocr-id-proof
// @desc    Auto-detects and extracts Government ID proof type and document number from image/data (Public)
router.post('/ocr-id-proof', async (req, res) => {
  try {
    const { image, fileName, ocrText } = req.body || {};
    let detectedType = null;
    let detectedNumber = null;
    let confidence = 0;

    let sourceText = `${fileName || ''} ${ocrText || ''}`;
    if (typeof image === 'string' && !image.startsWith('data:image/')) {
      sourceText += ` ${image}`;
    }

    // 1. Scan for PAN Card (5 uppercase letters, 4 digits, 1 uppercase letter)
    const panMatch = sourceText.match(/\b([A-Za-z]{5}\d{4}[A-Za-z]{1})\b/);
    if (panMatch) {
      detectedType = 'PAN Card';
      detectedNumber = panMatch[1].toUpperCase();
      confidence = 0.98;
    }

    // 2. Scan for Aadhaar (12 digits starting 2-9)
    if (!detectedNumber) {
      const aadhaarMatch = sourceText.match(/\b([2-9]\d{3})\s?(\d{4})\s?(\d{4})\b/);
      if (aadhaarMatch) {
        detectedType = 'Aadhaar Card';
        detectedNumber = `${aadhaarMatch[1]} ${aadhaarMatch[2]} ${aadhaarMatch[3]}`;
        confidence = 0.95;
      } else {
        const aadhaarRaw = sourceText.match(/\b([2-9]\d{11})\b/);
        if (aadhaarRaw) {
          const d = aadhaarRaw[1];
          detectedType = 'Aadhaar Card';
          detectedNumber = `${d.slice(0, 4)} ${d.slice(4, 8)} ${d.slice(8)}`;
          confidence = 0.90;
        }
      }
    }

    // 3. Scan for Voter ID / EPIC
    if (!detectedNumber) {
      const voterMatch = sourceText.match(/\b([A-Za-z]{3}\d{7})\b/);
      if (voterMatch) {
        detectedType = 'Voter ID';
        detectedNumber = voterMatch[1].toUpperCase();
        confidence = 0.90;
      }
    }

    // 4. Scan for Passport
    if (!detectedNumber) {
      const passMatch = sourceText.match(/\b([A-PR-WYa-pr-wy]\d{7})\b/);
      if (passMatch) {
        detectedType = 'Passport';
        detectedNumber = passMatch[1].toUpperCase();
        confidence = 0.90;
      }
    }

    // 5. Scan for Driving License
    if (!detectedNumber) {
      const dlMatch = sourceText.match(/\b([A-Za-z]{2}[0-9A-Za-z\/\-\s]{8,18})\b/);
      if (dlMatch && dlMatch[1].length >= 10 && /\d/.test(dlMatch[1])) {
        detectedType = 'Driving License';
        detectedNumber = dlMatch[1].toUpperCase().replace(/\s+/g, ' ');
        confidence = 0.85;
      }
    }

    return res.json({
      success: true,
      data: {
        detectedType,
        detectedNumber,
        confidence
      },
      message: detectedNumber ? `Auto-detected ${detectedType} number successfully` : 'No Government ID number pattern found'
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

const { roleCheck } = require('../middleware/roleCheck');

router.use(protect);
router.use(roleCheck('owner', 'superadmin', 'admin', 'branch_manager', 'staff'));

// @route   GET /api/search
// @desc    Global multi-source search across students, seats, plans, and payments
router.get('/', async (req, res) => {
  try {
    const q = (req.query.q || '').trim();
    if (!q || q.length < 1) {
      return res.json({
        success: true,
        data: {
          students: [],
          seats: [],
          plans: [],
          payments: [],
          actions: [
            { label: 'Add New Student', icon: '🧑‍🎓', link: '#/students', category: 'Action' },
            { label: 'Collect Fee Payment', icon: '💰', link: '#/payments', category: 'Action' },
            { label: 'Manage Seats & Desks', icon: '💺', link: '#/seats', category: 'Action' },
            { label: 'Daily Attendance Log', icon: '⏱️', link: '#/attendance', category: 'Action' },
            { label: 'Revenue & Attendance Reports', icon: '📈', link: '#/reports', category: 'Action' },
            { label: 'System & Business Settings', icon: '⚙️', link: '#/settings', category: 'Action' }
          ]
        }
      });
    }

    const regex = new RegExp(q, 'i');

    const [students, seats, plans, payments] = await Promise.all([
      Student.find({
        $or: [
          { name: regex },
          { phone: regex },
          { studentId: regex },
          { email: regex }
        ]
      }).select('name studentId phone status plan seat').populate('plan', 'name').limit(6),

      Seat.find({
        $or: [
          { seatNumber: regex },
          { zone: regex }
        ]
      }).select('seatNumber zone type status').limit(6),

      Plan.find({
        $or: [
          { name: regex },
          { seatType: regex },
          { shift: regex }
        ]
      }).select('name price duration durationType').limit(4),

      Payment.find({
        $or: [
          { receiptNumber: regex },
          { transactionId: regex }
        ]
      }).select('receiptNumber finalAmount paymentDate status').populate('student', 'name').limit(4)
    ]);

    res.json({
      success: true,
      data: {
        students,
        seats,
        plans,
        payments
      },
      message: 'Search completed'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
