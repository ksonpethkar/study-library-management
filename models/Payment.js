const mongoose = require('mongoose');
const { getFinancialYear } = require('../utils/idGenerator');

const paymentSchema = new mongoose.Schema({
    receiptNumber: {
        type: String,
        unique: true
    },
    student: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Student',
        required: true
    },
    plan: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Plan'
    },
    amount: {
        type: Number,
        required: true
    },
    discount: {
        type: Number,
        default: 0
    },
    lateFee: {
        type: Number,
        default: 0
    },
    finalAmount: {
        type: Number
    },
    paymentMethod: {
        type: String,
        enum: ['cash', 'upi', 'bank_transfer', 'card', 'other'],
        default: 'cash'
    },
    paymentDate: {
        type: Date,
        default: Date.now
    },
    periodStart: Date,
    periodEnd: Date,
    status: {
        type: String,
        enum: ['paid', 'pending', 'partial', 'refunded'],
        default: 'paid'
    },
    balanceDue: {
        type: Number,
        default: 0
    },
    dueDate: Date,
    installments: [{
        amount: Number,
        date: { type: Date, default: Date.now },
        method: String,
        transactionId: String,
        collectedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        }
    }],
    transactionId: String,
    referenceNumber: { type: String, trim: true, index: true },
    notes: String,
    collectedBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    },
    branch: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Branch'
    }
}, { timestamps: true });

// Performance Database Indexes
paymentSchema.index({ student: 1, paymentDate: -1 });
paymentSchema.index({ branch: 1, paymentDate: -1 });
paymentSchema.index({ branch: 1, status: 1, dueDate: 1 });
paymentSchema.index({ branch: 1, createdAt: -1 });
paymentSchema.index({ status: 1, paymentDate: -1 });
paymentSchema.index({ balanceDue: 1, dueDate: 1 });

paymentSchema.pre('save', async function() {
    if (this.isNew && !this.receiptNumber) {
        let finYear = '2026-27';
        try {
            if (getFinancialYear) finYear = getFinancialYear();
        } catch (e) {}
        
        const lastPayment = await this.constructor.findOne(
            { receiptNumber: new RegExp(`^REC/${finYear}/`) },
            {},
            { sort: { 'createdAt': -1 } }
        );
        
        let nextNum = 1;
        if (lastPayment && lastPayment.receiptNumber) {
            const parts = lastPayment.receiptNumber.split('/');
            if (parts.length === 3) {
                nextNum = parseInt(parts[2], 10) + 1;
            }
        }
        
        this.receiptNumber = `REC/${finYear}/${nextNum.toString().padStart(3, '0')}`;
    }
    
    this.finalAmount = (Number(this.amount) || 0) - (Number(this.discount) || 0) + (Number(this.lateFee) || 0);

    // Balance and Installments calculation integrity
    if (this.status === 'paid' && (!this.balanceDue || this.balanceDue < 0)) {
        this.balanceDue = 0;
    } else if (this.status === 'partial' || this.status === 'pending') {
        if (Array.isArray(this.installments) && this.installments.length > 0) {
            const totalPaid = this.installments.reduce((sum, inst) => sum + (Number(inst.amount) || 0), 0);
            if (this.balanceDue === undefined || this.balanceDue === null) {
                this.balanceDue = Math.max(0, this.finalAmount - totalPaid);
            }
        } else if (this.balanceDue === undefined || this.balanceDue === null) {
            this.balanceDue = this.finalAmount;
        }
    }
});

paymentSchema.statics.getStats = async function(dateRange) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
    const startOfYear = new Date(today.getFullYear(), 0, 1);
    
    const [todayStats, monthStats, yearStats, pendingStats] = await Promise.all([
        this.aggregate([
            { $match: { paymentDate: { $gte: today }, status: 'paid' } },
            { $group: { _id: null, total: { $sum: '$finalAmount' } } }
        ]),
        this.aggregate([
            { $match: { paymentDate: { $gte: startOfMonth }, status: 'paid' } },
            { $group: { _id: null, total: { $sum: '$finalAmount' } } }
        ]),
        this.aggregate([
            { $match: { paymentDate: { $gte: startOfYear }, status: 'paid' } },
            { $group: { _id: null, total: { $sum: '$finalAmount' } } }
        ]),
        this.aggregate([
            { $match: { status: { $in: ['pending', 'partial'] } } },
            { $group: { _id: null, total: { $sum: '$finalAmount' } } }
        ])
    ]);
    
    return {
        todayRevenue: todayStats[0]?.total || 0,
        monthRevenue: monthStats[0]?.total || 0,
        yearRevenue: yearStats[0]?.total || 0,
        totalPending: pendingStats[0]?.total || 0
    };
};

paymentSchema.statics.getDues = async function() {
    const Student = mongoose.model('Student');
    const today = new Date();
    
    const studentsWithDues = await Student.find({
        expiryDate: { $lt: today }
    }).select('name studentId phone expiryDate plan').populate('plan');
    
    return studentsWithDues;
};

module.exports = mongoose.model('Payment', paymentSchema);
