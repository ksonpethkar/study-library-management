const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { protect } = require('../middleware/auth');
const Payment = require('../models/Payment');
const Student = require('../models/Student');
const Plan = require('../models/Plan');
const BusinessProfile = require('../models/BusinessProfile');

function validate(validations) {
    return async (req, res, next) => {
        for (const validation of validations) {
            await validation.run(req);
        }
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ success: false, errors: errors.array(), message: errors.array()[0]?.msg || 'Validation failed' });
        }
        next();
    };
}

router.use(protect);

router.get('/', async (req, res) => {
    try {
        const { student, status, method, startDate, endDate, page = 1, limit = 10 } = req.query;
        let query = {};
        
        if (student) query.student = student;
        if (status) query.status = status;
        if (method) query.paymentMethod = method;
        
        if (startDate || endDate) {
            query.paymentDate = {};
            if (startDate) query.paymentDate.$gte = new Date(startDate);
            if (endDate) query.paymentDate.$lte = new Date(endDate);
        }
        
        const skip = (page - 1) * limit;
        
        const payments = await Payment.find(query)
            .populate('student', 'name studentId phone')
            .populate('plan', 'name')
            .sort({ paymentDate: -1 })
            .skip(skip)
            .limit(parseInt(limit));
            
        const total = await Payment.countDocuments(query);
        
        res.json({
            success: true,
            data: {
                payments,
                pagination: {
                    total,
                    page: parseInt(page),
                    pages: Math.ceil(total / limit)
                }
            },
            message: 'Payments fetched successfully'
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.get('/stats', async (req, res) => {
    try {
        const stats = await Payment.getStats();
        res.json({ success: true, data: stats, message: 'Stats fetched successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.get('/dues', async (req, res) => {
    try {
        const dues = await Payment.getDues();
        res.json({ success: true, data: dues, message: 'Dues fetched successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.get('/student/{*studentId}', async (req, res) => {
    try {
        const payments = await Payment.find({ student: req.params.studentId })
            .populate('plan', 'name')
            .sort({ paymentDate: -1 });
            
        res.json({ success: true, data: payments, message: 'Student payment history fetched' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.get('/{*id}/receipt', async (req, res) => {
    try {
        const payment = await Payment.findById(req.params.id)
            .populate('student', 'name studentId phone email address')
            .populate('plan', 'name duration')
            .populate('collectedBy', 'name');
            
        if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
        
        const businessProfile = await BusinessProfile.getProfile();
        
        const receiptData = {
            businessName: businessProfile.businessName || 'Study Library',
            businessAddress: businessProfile.address || '',
            businessCity: businessProfile.city || '',
            businessState: businessProfile.state || '',
            businessPincode: businessProfile.pincode || '',
            businessPhone: businessProfile.phone || '',
            businessEmail: businessProfile.email || '',
            businessGst: businessProfile.gstNumber || '',
            businessLogo: businessProfile.logo || '',
            stampImage: businessProfile.stampImage || '',
            upiQrCode: businessProfile.upiQrCode || '',
            receiptNumber: payment.receiptNumber,
            date: payment.paymentDate,
            student: payment.student,
            plan: payment.plan,
            paymentDetails: {
                amount: payment.amount,
                discount: payment.discount,
                lateFee: payment.lateFee,
                finalAmount: payment.finalAmount,
                method: payment.paymentMethod,
                transactionId: payment.transactionId
            },
            notes: payment.notes,
            collectedBy: payment.collectedBy ? payment.collectedBy.name : 'System'
        };
        
        res.json({ success: true, data: receiptData, message: 'Receipt generated' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.get('/{*id}', async (req, res) => {
    try {
        const payment = await Payment.findById(req.params.id)
            .populate('student', 'name studentId phone email address')
            .populate('plan', 'name price duration')
            .populate('collectedBy', 'name');
            
        if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
        
        res.json({ success: true, data: payment, message: 'Payment fetched successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.post('/', validate([
    body('student').notEmpty().withMessage('Student is required'),
    body('amount').isNumeric().withMessage('Amount is required and must be a number')
]), async (req, res) => {
    try {
        const payment = new Payment({
            ...req.body,
            collectedBy: req.user._id,
            branch: req.user.branch
        });
        
        await payment.save();
        
        if (payment.plan && payment.status === 'paid') {
            const plan = await Plan.findById(payment.plan);
            if (plan) {
                const student = await Student.findById(payment.student);
                if (student) {
                    const baseDate = (student.expiryDate && student.expiryDate > new Date()) ? student.expiryDate : new Date();
                    const newExpiry = new Date(baseDate);
                    newExpiry.setDate(newExpiry.getDate() + plan.duration);
                    student.expiryDate = newExpiry;
                    await student.save();
                }
            }
        }
        
        res.status(201).json({ success: true, data: payment, message: 'Payment created successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.put('/{*id}', async (req, res) => {
    try {
        const payment = await Payment.findById(req.params.id);
        if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
        
        Object.assign(payment, req.body);
        await payment.save();
        
        res.json({ success: true, data: payment, message: 'Payment updated successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.delete('/{*id}', async (req, res) => {
    try {
        const payment = await Payment.findByIdAndDelete(req.params.id);
        if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
        
        res.json({ success: true, data: null, message: 'Payment deleted successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

module.exports = router;
