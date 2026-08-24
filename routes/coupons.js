const express = require('express');
const router = express.Router();
const Coupon = require('../models/Coupon');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');

// @route   GET /api/coupons
// @desc    List all coupon codes
// @access  Private (Owner, Branch Manager)
router.get('/', protect, roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const coupons = await Coupon.find().sort({ createdAt: -1 });
    res.json({ success: true, coupons });
  } catch (error) {
    console.error('Error fetching coupons:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   POST /api/coupons
// @desc    Create new coupon code
// @access  Private (Owner)
router.post('/', protect, roleCheck('owner'), async (req, res) => {
  try {
    const { code, discountType, discountValue, minPlanAmount, maxDiscount, validUntil, usageLimit, isActive } = req.body;
    
    // Check if code exists
    const existing = await Coupon.findOne({ code: code.toUpperCase() });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Coupon code already exists' });
    }

    const coupon = new Coupon({
      code,
      discountType,
      discountValue,
      minPlanAmount,
      maxDiscount,
      validUntil,
      usageLimit,
      isActive
    });

    await coupon.save();
    res.status(201).json({ success: true, coupon });
  } catch (error) {
    console.error('Error creating coupon:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   PUT /api/coupons/:id
// @desc    Update coupon details
// @access  Private (Owner)
router.put('/:id', protect, roleCheck('owner'), async (req, res) => {
  try {
    const coupon = await Coupon.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!coupon) {
      return res.status(404).json({ success: false, message: 'Coupon not found' });
    }
    res.json({ success: true, coupon });
  } catch (error) {
    console.error('Error updating coupon:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   DELETE /api/coupons/:id
// @desc    Delete coupon code
// @access  Private (Owner)
router.delete('/:id', protect, roleCheck('owner'), async (req, res) => {
  try {
    const { moveToTrash } = require('./trash');
    const coupon = await Coupon.findById(req.params.id);
    if (!coupon) {
      return res.status(404).json({ success: false, message: 'Coupon not found' });
    }

    await moveToTrash({
      itemType: 'coupon',
      itemId: coupon._id,
      itemTitle: `Promo Code: ${coupon.code || 'COUPON'}`,
      itemSubtitle: `Discount: ${coupon.discountType === 'percentage' ? `${coupon.discountValue}%` : `₹${coupon.discountValue}`} • Uses: ${coupon.usedCount || 0}/${coupon.maxUses || '∞'}`,
      originalCollection: 'coupons',
      itemData: coupon.toObject ? coupon.toObject() : coupon,
      user: req.user,
      reason: req.body?.reason || ''
    });

    coupon.isActive = false;
    coupon.isDeleted = true;
    await coupon.save();

    res.json({ success: true, message: `Coupon "${coupon.code}" moved to Recycle Bin (Trash).` });
  } catch (error) {
    console.error('Error deleting coupon:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   POST /api/coupons/validate
// @desc    Validate coupon and calculate discount
// @access  Public
router.post('/validate', async (req, res) => {
  try {
    const { code, planAmount } = req.body;
    
    if (!code || planAmount == null) {
      return res.status(400).json({ success: false, message: 'Code and planAmount are required' });
    }

    const numericPlanAmount = parseFloat(planAmount);
    if (isNaN(numericPlanAmount) || numericPlanAmount < 0) {
      return res.status(400).json({ success: false, message: 'Invalid plan amount' });
    }

    const coupon = await Coupon.findOne({ code: code.toUpperCase() });
    
    if (!coupon) {
      // Check Student Referral Code
      try {
        const Student = require('../models/Student');
        const ReferralConfig = require('../models/ReferralConfig');
        const refConfig = await ReferralConfig.getConfig();

        if (refConfig && refConfig.isEnabled) {
          const student = await Student.findOne({
            $or: [
              { referralCode: code.toUpperCase() },
              { studentId: code.toUpperCase() },
              { phone: code }
            ]
          });

          if (student) {
            let discount = 0;
            if (refConfig.refereeRewardType === 'percentage') {
              discount = Math.round((numericPlanAmount * (refConfig.refereeRewardAmount || 10)) / 100);
            } else {
              discount = Math.min(numericPlanAmount, refConfig.refereeRewardAmount || 100);
            }
            const finalPrice = Math.max(0, numericPlanAmount - discount);

            return res.json({
              success: true,
              isReferral: true,
              referrerName: student.name,
              discount,
              finalPrice,
              message: `🎉 Referral code from ${student.name} applied! You get ₹${discount} instant discount!`
            });
          }
        }
      } catch (refErr) {
        console.warn('Referral validation check error:', refErr);
      }

      return res.status(404).json({ success: false, message: 'Invalid promo or referral code' });
    }

    if (!coupon.isActive) {
      return res.status(400).json({ success: false, message: 'Coupon is not active' });
    }

    if (coupon.validUntil && new Date(coupon.validUntil) < new Date()) {
      return res.status(400).json({ success: false, message: 'Coupon has expired' });
    }

    if (coupon.usageLimit <= coupon.usedCount) {
      return res.status(400).json({ success: false, message: 'Coupon usage limit exceeded' });
    }

    if (coupon.minPlanAmount && numericPlanAmount < coupon.minPlanAmount) {
      return res.status(400).json({ success: false, message: `Minimum plan amount of ₹${coupon.minPlanAmount} required` });
    }

    let discountAmount = 0;
    if (coupon.discountType === 'percentage') {
      discountAmount = (numericPlanAmount * coupon.discountValue) / 100;
      if (coupon.maxDiscount && discountAmount > coupon.maxDiscount) {
        discountAmount = coupon.maxDiscount;
      }
    } else {
      discountAmount = coupon.discountValue;
    }

    // Ensure discount doesn't exceed plan amount
    discountAmount = Math.min(discountAmount, numericPlanAmount);
    
    const finalPrice = numericPlanAmount - discountAmount;

    res.json({
      success: true,
      discountAmount,
      finalPrice,
      couponId: coupon._id
    });

  } catch (error) {
    console.error('Error validating coupon:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
