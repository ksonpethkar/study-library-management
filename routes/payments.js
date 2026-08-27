const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');
const { validate, validatePaymentCreate, validatePaymentUpdate } = require('../middleware/validate');
const Payment = require('../models/Payment');
const Student = require('../models/Student');
const Plan = require('../models/Plan');
const BusinessProfile = require('../models/BusinessProfile');
const { moveToTrash } = require('./trash');

router.use(protect);
router.use(roleCheck('owner', 'branch_manager'));

router.get('/', async (req, res) => {
    try {
        const { student, status, method, startDate, endDate, page = 1, limit = 10 } = req.query;
        let query = { isDeleted: { $ne: true } };
        
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
            .limit(parseInt(limit))
            .lean();
            
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

router.get('/student/:studentId', async (req, res) => {
    try {
        const payments = await Payment.find({ student: req.params.studentId })
            .populate('plan', 'name')
            .sort({ paymentDate: -1 })
            .lean();
            
        res.json({ success: true, data: payments, message: 'Student payment history fetched' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.get('/pending-installments', async (req, res) => {
    try {
        const payments = await Payment.find({ balanceDue: { $gt: 0 } })
            .populate('student', 'name studentId phone')
            .populate('plan', 'name')
            .sort({ dueDate: 1 })
            .lean();
            
        res.json({ success: true, data: payments, message: 'Pending installments fetched' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.get('/:id/receipt', async (req, res) => {
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
            balanceDue: payment.balanceDue,
            installments: payment.installments,
            notes: payment.notes,
            collectedBy: payment.collectedBy ? payment.collectedBy.name : 'System'
        };
        
        res.json({ success: true, data: receiptData, message: 'Receipt generated' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.post('/:id/pay-balance', roleCheck('owner', 'branch_manager'), async (req, res) => {
    try {
        const { amount, method, transactionId } = req.body;
        const payment = await Payment.findById(req.params.id);
        
        if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
        if (payment.balanceDue <= 0) return res.status(400).json({ success: false, message: 'No balance due on this payment' });
        
        const payAmount = parseFloat(amount);
        if (isNaN(payAmount) || payAmount <= 0) return res.status(400).json({ success: false, message: 'Invalid payment amount' });
        if (payAmount > payment.balanceDue) return res.status(400).json({ success: false, message: 'Amount exceeds balance due' });
        
        payment.installments.push({
            amount: payAmount,
            method: method || 'cash',
            transactionId: transactionId,
            collectedBy: req.user._id
        });
        
        payment.balanceDue -= payAmount;
        if (payment.balanceDue <= 0) {
            payment.status = 'paid';
            if (payment.plan) {
    const plan = await Plan.findById(payment.plan).lean();
                if (plan) {
                    const student = await Student.findById(payment.student);
                    if (student) {
                        student.status = 'active';
                        const baseDate = (student.expiryDate && student.expiryDate > new Date()) ? student.expiryDate : new Date();
                        const newExpiry = new Date(baseDate);
                        newExpiry.setDate(newExpiry.getDate() + (plan.duration || 30));
                        student.expiryDate = newExpiry;
                        await student.save();
                    }
                }
            }
        }
        
        await payment.save();
        res.json({ success: true, data: payment, message: 'Installment paid successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.get('/:id', async (req, res) => {
    try {
    const payment = await Payment.findById(req.params.id).lean()
            .populate('student', 'name studentId phone email address')
            .populate('plan', 'name price duration')
            .populate('collectedBy', 'name');
            
        if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
        
        res.json({ success: true, data: payment, message: 'Payment fetched successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.post('/', roleCheck('owner', 'branch_manager'), validatePaymentCreate, async (req, res) => {
    try {
        const paymentData = {
            ...req.body,
            collectedBy: req.user._id,
            branch: req.user.branch || req.body.branch || null
        };

        if (paymentData.referenceNumber && String(paymentData.referenceNumber).trim()) {
            const cleanRef = String(paymentData.referenceNumber).trim();
            const existingRef = await Payment.findOne({
                referenceNumber: cleanRef,
                status: { $ne: 'failed' }
            }).lean();
            if (existingRef) {
                return res.status(400).json({
                    success: false,
                    message: `Payment with UTR / Reference Number "${cleanRef}" already recorded.`
                });
            }
        }

        const amount = Number(paymentData.amount) || 0;
        const discount = Number(paymentData.discount) || 0;
        const lateFee = Number(paymentData.lateFee) || 0;
        const finalAmount = Math.max(0, amount - discount + lateFee);
        paymentData.finalAmount = finalAmount;

        if (paymentData.status === 'paid') {
            paymentData.balanceDue = 0;
        } else if (paymentData.status === 'partial') {
            const paidAmount = Number(paymentData.paidAmount);
            if (!isNaN(paidAmount) && paidAmount > 0) {
                paymentData.balanceDue = Math.max(0, finalAmount - paidAmount);
                paymentData.installments = [{
                    amount: paidAmount,
                    date: new Date(),
                    method: paymentData.paymentMethod || 'cash',
                    transactionId: paymentData.transactionId || '',
                    collectedBy: req.user._id
                }];
            } else if (paymentData.balanceDue === undefined) {
                paymentData.balanceDue = finalAmount;
            }
        } else if (paymentData.status === 'pending' && paymentData.balanceDue === undefined) {
            paymentData.balanceDue = finalAmount;
        }

        const payment = new Payment(paymentData);
        await payment.save();
        
        if (payment.plan && payment.status === 'paid') {
    const plan = await Plan.findById(payment.plan).lean();
            if (plan) {
                const student = await Student.findById(payment.student);
                if (student) {
                    student.status = 'active';
                    const baseDate = (student.expiryDate && student.expiryDate > new Date()) ? student.expiryDate : new Date();
                    const newExpiry = new Date(baseDate);
                    newExpiry.setDate(newExpiry.getDate() + (plan.duration || 30));
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

router.put('/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
    try {
        const payment = await Payment.findById(req.params.id);
        if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
        
        Object.assign(payment, req.body);
        if (req.body.status === 'paid' && (!req.body.balanceDue || req.body.balanceDue < 0)) {
            payment.balanceDue = 0;
        }
        await payment.save();
        
        res.json({ success: true, data: payment, message: 'Payment updated successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.delete('/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
    try {
        const payment = await Payment.findById(req.params.id).populate('student', 'name studentId phone');
        if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
        
        await moveToTrash({
            itemType: 'payment',
            itemId: payment._id,
            itemTitle: `Receipt #${payment.receiptNumber || 'REC'} — ₹${payment.amountPaid}`,
            itemSubtitle: `Student: ${payment.student?.name || 'N/A'} • Method: ${(payment.paymentMethod || 'UPI').toUpperCase()} • Status: ${(payment.status || 'Paid').toUpperCase()}`,
            originalCollection: 'payments',
            itemData: payment.toObject ? payment.toObject() : payment,
            user: req.user,
            reason: req.body?.reason || ''
        });
        
        res.json({ success: true, data: null, message: `Payment receipt #${payment.receiptNumber || ''} moved to Recycle Bin (Trash).` });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

// ── Cash Register & Shift Handover Endpoints ─────────────────────────
router.get('/cash-register/summary', protect, async (req, res) => {
    try {
        const CashSettlement = require('../models/CashSettlement');
        const Expense = require('../models/Expense');
        const startOfDay = new Date();
        startOfDay.setHours(0, 0, 0, 0);
        const endOfDay = new Date();
        endOfDay.setHours(23, 59, 59, 999);

        // Fetch all cash payments collected today
        const cashPayments = await Payment.find({
            paymentDate: { $gte: startOfDay, $lte: endOfDay },
            paymentMethod: 'cash',
            status: 'paid'
        }).populate('student', 'name studentId').lean();

        const onlinePayments = await Payment.find({
            paymentDate: { $gte: startOfDay, $lte: endOfDay },
            paymentMethod: { $ne: 'cash' },
            status: 'paid'
        }).lean();

        const todayExpenses = await Expense.find({
            date: { $gte: startOfDay, $lte: endOfDay },
            paymentMethod: 'cash'
        }).lean().catch(() => []);

        const totalCashCollected = cashPayments.reduce((acc, p) => acc + (p.amount || 0), 0);
        const totalOnlineCollected = onlinePayments.reduce((acc, p) => acc + (p.amount || 0), 0);
        const totalCashExpenses = todayExpenses.reduce((acc, e) => acc + (e.amount || 0), 0);

        // Latest previous settlement to get opening cash
        const lastSettlement = await CashSettlement.findOne().sort({ createdAt: -1 }).lean();
        const openingCash = lastSettlement ? lastSettlement.actualPhysicalCash : 0;
        const expectedClosingCash = Math.max(0, openingCash + totalCashCollected - totalCashExpenses);

        const todaySettlement = await CashSettlement.findOne({
            settlementDate: { $gte: startOfDay, $lte: endOfDay }
        }).populate('closedBy', 'name role').lean();

        res.json({
            success: true,
            data: {
                openingCash,
                totalCashCollected,
                totalOnlineCollected,
                totalCashExpenses,
                expectedClosingCash,
                cashTransactionsCount: cashPayments.length,
                onlineTransactionsCount: onlinePayments.length,
                todaySettlement,
                recentCashPayments: cashPayments.slice(0, 10)
            }
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
});

router.post('/cash-register/settle', protect, async (req, res) => {
    try {
        const CashSettlement = require('../models/CashSettlement');
        const {
            openingCash = 0,
            cashCollected = 0,
            cashExpenses = 0,
            expectedClosingCash = 0,
            actualPhysicalCash = 0,
            denominations = {},
            handoverTo = '',
            notes = ''
        } = req.body;

        const variance = Number(actualPhysicalCash) - Number(expectedClosingCash);
        const status = variance === 0 ? 'reconciled' : 'variance_noted';

        const settlement = new CashSettlement({
            settlementDate: new Date(),
            branch: req.user.branch || null,
            closedBy: req.user._id,
            openingCash: Number(openingCash),
            cashCollected: Number(cashCollected),
            cashExpenses: Number(cashExpenses),
            expectedClosingCash: Number(expectedClosingCash),
            actualPhysicalCash: Number(actualPhysicalCash),
            variance,
            denominations,
            handoverTo: handoverTo || 'Next Shift / Owner',
            notes,
            status
        });

        await settlement.save();

        res.json({
            success: true,
            data: settlement,
            message: `Cash register settled successfully. Variance: ${variance >= 0 ? '+' : ''}₹${variance}`
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
});

// @route   GET /api/payments/verification-queue
// @desc    Get all online payments awaiting front desk UTR verification
router.get('/verification-queue', async (req, res) => {
    try {
        const queue = await Payment.find({
            status: 'pending_verification',
            isDeleted: { $ne: true }
        })
        .populate('student', 'name studentId phone email seat')
        .populate('plan', 'name price duration')
        .sort({ createdAt: -1 })
        .lean();

        res.json({
            success: true,
            count: queue.length,
            data: queue
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
});

// @route   PUT /api/payments/:id/verify-utr
// @desc    1-Click approve and verify student UPI UTR payment
router.put('/:id/verify-utr', async (req, res) => {
    try {
        const payment = await Payment.findById(req.params.id);
        if (!payment) {
            return res.status(404).json({ success: false, message: 'Payment record not found' });
        }

        payment.status = 'paid';
        payment.notes = payment.notes ? `${payment.notes} • Verified by Staff on ${new Date().toLocaleDateString()}` : `Verified by Staff on ${new Date().toLocaleDateString()}`;
        if (!payment.verifiedAt) payment.verifiedAt = new Date();
        if (!payment.verifiedBy && req.user) payment.verifiedBy = req.user._id;
        await payment.save();

        // Update student status to active
        if (payment.student) {
            await Student.findByIdAndUpdate(payment.student, {
                status: 'active',
                isFeeDue: false
            });
        }

        // Send confirmation notification
        const Notification = require('../models/Notification');
        await Notification.create({
            title: `✅ Payment Verified: ₹${payment.finalAmount || payment.amount}`,
            message: `UTR: ${payment.transactionId} verified successfully for ${payment.receiptNumber}.`,
            type: 'payment',
            link: '#/payments'
        }).catch(() => {});

        res.json({
            success: true,
            message: `Payment ${payment.receiptNumber} verified successfully! Student membership is fully active.`,
            data: payment
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
});

// @route   PUT /api/payments/:id/reject-utr
// @desc    Reject unverified / fraudulent UTR payment
router.put('/:id/reject-utr', async (req, res) => {
    try {
        const payment = await Payment.findById(req.params.id);
        if (!payment) {
            return res.status(404).json({ success: false, message: 'Payment record not found' });
        }

        const reason = req.body.reason || 'Unverified or invalid bank UTR reference';
        payment.status = 'failed';
        payment.notes = payment.notes ? `${payment.notes} • REJECTED: ${reason}` : `REJECTED: ${reason}`;
        await payment.save();

        res.json({
            success: true,
            message: `Payment ${payment.receiptNumber} marked as rejected.`,
            data: payment
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
});

module.exports = router;
