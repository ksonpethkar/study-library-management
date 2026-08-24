const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const Expense = require('../models/Expense');
const ExpenseCategory = require('../models/ExpenseCategory');
const Payment = require('../models/Payment');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');

// Protect all expense routes (owner and branch manager)
router.use(protect);
router.use(roleCheck('owner', 'branch_manager'));

function validate(validations) {
  return async (req, res, next) => {
    for (const validation of validations) {
      await validation.run(req);
    }
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array(),
        message: errors.array()[0]?.msg || 'Validation failed'
      });
    }
    next();
  };
}

/**
 * @route   GET /api/expenses/stats
 * @desc    Get expense statistics & monthly breakdown
 */
router.get('/stats', async (req, res) => {
  try {
    const today = new Date();
    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
    const endOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0, 23, 59, 59);

    const [totalAgg, monthAgg, categoryStats] = await Promise.all([
      Expense.aggregate([
        { $match: { isDeleted: { $ne: true } } },
        { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } }
      ]),
      Expense.aggregate([
        { $match: { date: { $gte: startOfMonth, $lte: endOfMonth }, isDeleted: { $ne: true } } },
        { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } }
      ]),
      Expense.aggregate([
        { $match: { isDeleted: { $ne: true } } },
        { $group: { _id: '$category', total: { $sum: '$amount' }, count: { $sum: 1 } } },
        { $sort: { total: -1 } }
      ])
    ]);

    res.json({
      success: true,
      data: {
        totalExpenses: totalAgg[0]?.total || 0,
        totalCount: totalAgg[0]?.count || 0,
        thisMonthExpenses: monthAgg[0]?.total || 0,
        thisMonthCount: monthAgg[0]?.count || 0,
        byCategory: categoryStats
      }
    });
  } catch (err) {
    console.error('Error fetching expense stats:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch expense statistics' });
  }
});

/**
 * @route   GET /api/expenses/summary
 * @desc    Get Profit & Loss Summary (Revenue vs Expenses, Net Profit, Category breakdown)
 */
router.get('/summary', async (req, res) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();
    const month = req.query.month ? parseInt(req.query.month) : null;

    // Build Date Filter
    let dateFilter = {};
    let prevDateFilter = {};

    if (month) {
      const start = new Date(year, month - 1, 1);
      const end = new Date(year, month, 0, 23, 59, 59);
      dateFilter = { $gte: start, $lte: end };

      // Previous month
      const prevMonth = month === 1 ? 12 : month - 1;
      const prevYear = month === 1 ? year - 1 : year;
      prevDateFilter = {
        $gte: new Date(prevYear, prevMonth - 1, 1),
        $lte: new Date(prevYear, prevMonth, 0, 23, 59, 59)
      };
    } else {
      const start = new Date(year, 0, 1);
      const end = new Date(year, 11, 31, 23, 59, 59);
      dateFilter = { $gte: start, $lte: end };

      prevDateFilter = {
        $gte: new Date(year - 1, 0, 1),
        $lte: new Date(year - 1, 11, 31, 23, 59, 59)
      };
    }

    // 1. Total Expenses
    const expenseAgg = await Expense.aggregate([
      { $match: { date: dateFilter, isDeleted: { $ne: true } } },
      { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } }
    ]);
    const totalExpenses = expenseAgg.length > 0 ? expenseAgg[0].total : 0;
    const totalExpenseCount = expenseAgg.length > 0 ? expenseAgg[0].count : 0;

    // 2. Total Revenue from Payments
    const paymentAgg = await Payment.aggregate([
      { $match: { status: 'paid', createdAt: dateFilter, isDeleted: { $ne: true } } },
      { $group: { _id: null, total: { $sum: '$finalAmount' }, count: { $sum: 1 } } }
    ]);
    const totalRevenue = paymentAgg.length > 0 ? paymentAgg[0].total : 0;
    const totalPaymentCount = paymentAgg.length > 0 ? paymentAgg[0].count : 0;

    // 3. Previous Period for growth rates
    const prevExpenseAgg = await Expense.aggregate([
      { $match: { date: prevDateFilter, isDeleted: { $ne: true } } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const prevTotalExpenses = prevExpenseAgg.length > 0 ? prevExpenseAgg[0].total : 0;

    const prevPaymentAgg = await Payment.aggregate([
      { $match: { status: 'paid', createdAt: prevDateFilter, isDeleted: { $ne: true } } },
      { $group: { _id: null, total: { $sum: '$finalAmount' } } }
    ]);
    const prevTotalRevenue = prevPaymentAgg.length > 0 ? prevPaymentAgg[0].total : 0;

    // Net Profit
    const netProfit = totalRevenue - totalExpenses;
    const prevNetProfit = prevTotalRevenue - prevTotalExpenses;
    const profitMargin = totalRevenue > 0 ? ((netProfit / totalRevenue) * 100).toFixed(1) : 0;

    // Category Breakdown
    const categoryBreakdown = await Expense.aggregate([
      { $match: { date: dateFilter, isDeleted: { $ne: true } } },
      {
        $group: {
          _id: '$category',
          total: { $sum: '$amount' },
          count: { $sum: 1 }
        }
      },
      { $sort: { total: -1 } }
    ]);

    // 6-Month Monthly Trends
    const sixMonthsTrend = [];
    const now = new Date();
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const m = d.getMonth() + 1;
      const y = d.getFullYear();
      const mStart = new Date(y, m - 1, 1);
      const mEnd = new Date(y, m, 0, 23, 59, 59);

      const [mExp, mRev] = await Promise.all([
        Expense.aggregate([
          { $match: { date: { $gte: mStart, $lte: mEnd }, isDeleted: { $ne: true } } },
          { $group: { _id: null, total: { $sum: '$amount' } } }
        ]),
        Payment.aggregate([
          { $match: { status: 'paid', createdAt: { $gte: mStart, $lte: mEnd }, isDeleted: { $ne: true } } },
          { $group: { _id: null, total: { $sum: '$finalAmount' } } }
        ])
      ]);

      const rev = mRev.length > 0 ? mRev[0].total : 0;
      const exp = mExp.length > 0 ? mExp[0].total : 0;
      const monthLabel = d.toLocaleString('en-US', { month: 'short' });

      sixMonthsTrend.push({
        label: `${monthLabel} ${y}`,
        revenue: rev,
        expenses: exp,
        netProfit: rev - exp
      });
    }

    res.json({
      success: true,
      data: {
        totalRevenue,
        totalExpenses,
        netProfit,
        profitMargin,
        totalExpenseCount,
        totalPaymentCount,
        prevTotalRevenue,
        prevTotalExpenses,
        prevNetProfit,
        categoryBreakdown,
        sixMonthsTrend
      }
    });
  } catch (err) {
    console.error('Error fetching P&L summary:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch financial summary' });
  }
});

/**
 * @route   GET /api/expenses/categories
 * @desc    Get all active expense categories
 */
router.get('/categories', async (req, res) => {
  try {
    await ExpenseCategory.seedDefaultCategories();
    const categories = await ExpenseCategory.find().sort({ isSystem: -1, name: 1 }).lean();
    res.json({ success: true, data: categories });
  } catch (err) {
    console.error('Error fetching expense categories:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch categories' });
  }
});

/**
 * @route   POST /api/expenses/categories
 * @desc    Create new expense category
 */
router.post(
  '/categories',
  roleCheck('owner'),
  validate([
    body('name').trim().notEmpty().withMessage('Category name is required')
  ]),
  async (req, res) => {
    try {
      const { name, icon, color, description } = req.body;
      const exists = await ExpenseCategory.findOne({ name: new RegExp(`^${name}$`, 'i') });
      if (exists) {
        return res.status(400).json({ success: false, message: 'Category already exists' });
      }
      const category = new ExpenseCategory({ name, icon, color, description });
      await category.save();
      res.status(201).json({ success: true, message: 'Category created', data: category });
    } catch (err) {
      console.error('Error creating category:', err);
      res.status(500).json({ success: false, message: 'Failed to create category' });
    }
  }
);

/**
 * @route   PUT /api/expenses/categories/:id
 * @desc    Edit expense category
 */
router.put(
  '/categories/:id',
  roleCheck('owner'),
  validate([
    body('name').optional().trim().notEmpty().withMessage('Category name cannot be empty')
  ]),
  async (req, res) => {
    try {
    const category = await ExpenseCategory.findById(req.params.id).lean();
      if (!category) {
        return res.status(404).json({ success: false, message: 'Category not found' });
      }
      if (category.isSystem && req.body.name && req.body.name !== category.name) {
        return res.status(400).json({ success: false, message: 'Cannot rename system categories' });
      }
      
      const updated = await ExpenseCategory.findByIdAndUpdate(
        req.params.id,
        { ...req.body },
        { new: true, runValidators: true }
      );
      res.json({ success: true, message: 'Category updated', data: updated });
    } catch (err) {
      console.error('Error updating category:', err);
      res.status(500).json({ success: false, message: 'Failed to update category' });
    }
  }
);

/**
 * @route   DELETE /api/expenses/categories/:id
 * @desc    Delete custom expense category
 */
router.delete('/categories/:id', roleCheck('owner'), async (req, res) => {
  try {
    const category = await ExpenseCategory.findById(req.params.id).lean();
    if (!category) {
      return res.status(404).json({ success: false, message: 'Category not found' });
    }
    if (category.isSystem) {
      return res.status(400).json({ success: false, message: 'Cannot delete system categories' });
    }
    await ExpenseCategory.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Category deleted' });
  } catch (err) {
    console.error('Error deleting category:', err);
    res.status(500).json({ success: false, message: 'Failed to delete category' });
  }
});

/**
 * @route   GET /api/expenses
 * @desc    Get paginated expenses with filters
 */
router.get('/', async (req, res) => {
  try {
    const { page = 1, limit = 15, category, search, startDate, endDate, paymentMethod } = req.query;

    const query = { isDeleted: { $ne: true } };

    if (category && category !== 'all') {
      query.category = category;
    }

    if (paymentMethod && paymentMethod !== 'all') {
      query.paymentMethod = paymentMethod;
    }

    if (search) {
      query.$or = [
        { title: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { vendor: { $regex: search, $options: 'i' } }
      ];
    }

    if (startDate || endDate) {
      query.date = {};
      if (startDate) query.date.$gte = new Date(startDate);
      if (endDate) {
        const e = new Date(endDate);
        e.setHours(23, 59, 59, 999);
        query.date.$lte = e;
      }
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const [expenses, total] = await Promise.all([
      Expense.find(query).lean()
        .populate('createdBy', 'name email')
        .sort({ date: -1, createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .lean(),
      Expense.countDocuments(query)
    ]);

    res.json({
      success: true,
      data: {
        expenses,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / parseInt(limit))
        }
      }
    });
  } catch (err) {
    console.error('Error fetching expenses:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch expenses' });
  }
});

/**
 * @route   POST /api/expenses
 * @desc    Create new expense
 */
router.post(
  '/',
  validate([
    body('title').trim().notEmpty().withMessage('Expense title is required'),
    body('amount').isNumeric().withMessage('Valid amount is required'),
    body('category').notEmpty().withMessage('Category is required')
  ]),
  async (req, res) => {
    try {
      const { title, category, description, amount, date, paymentMethod, vendor, receiptUrl, receiptImage, isRecurring, recurringFrequency } = req.body;

      const expense = new Expense({
        title,
        category,
        description: description || '',
        amount: parseFloat(amount),
        date: date ? new Date(date) : new Date(),
        paymentMethod: paymentMethod || 'upi',
        vendor: vendor || '',
        receiptUrl: receiptUrl || receiptImage || '',
        receiptImage: receiptImage || receiptUrl || '',
        isRecurring: !!isRecurring,
        recurringFrequency: recurringFrequency || 'none',
        createdBy: req.user._id
      });

      await expense.save();

      res.status(201).json({
        success: true,
        message: 'Expense recorded successfully',
        data: expense
      });
    } catch (err) {
      console.error('Error creating expense:', err);
      res.status(500).json({ success: false, message: 'Failed to record expense' });
    }
  }
);

/**
 * @route   PUT /api/expenses/:id
 * @desc    Update an expense
 */
router.put(
  '/:id',
  validate([
    body('title').optional().trim().notEmpty().withMessage('Expense title cannot be empty'),
    body('amount').optional().isNumeric().withMessage('Valid amount is required')
  ]),
  async (req, res) => {
    try {
      const expense = await Expense.findByIdAndUpdate(
        req.params.id,
        { ...req.body },
        { new: true, runValidators: true }
      );

      if (!expense) {
        return res.status(404).json({ success: false, message: 'Expense not found' });
      }

      res.json({
        success: true,
        message: 'Expense updated successfully',
        data: expense
      });
    } catch (err) {
      console.error('Error updating expense:', err);
      res.status(500).json({ success: false, message: 'Failed to update expense' });
    }
  }
);

/**
 * @route   DELETE /api/expenses/:id
 * @desc    Delete an expense
 */
router.delete('/:id', async (req, res) => {
  try {
    const { moveToTrash } = require('./trash');
    const expense = await Expense.findById(req.params.id);
    if (!expense) {
      return res.status(404).json({ success: false, message: 'Expense not found' });
    }

    await moveToTrash({
      itemType: 'expense',
      itemId: expense._id,
      itemTitle: `${expense.title || 'Expense'} (₹${expense.amount})`,
      itemSubtitle: `Category: ${expense.category || 'General'} • Paid To: ${expense.paidTo || 'N/A'} • Method: ${(expense.paymentMethod || 'Cash').toUpperCase()}`,
      originalCollection: 'expenses',
      itemData: expense.toObject ? expense.toObject() : expense,
      user: req.user,
      reason: req.body?.reason || ''
    });

    res.json({
      success: true,
      message: `Expense "${expense.title || 'Expense'}" moved to Recycle Bin (Trash).`
    });
  } catch (err) {
    console.error('Error deleting expense:', err);
    res.status(500).json({ success: false, message: 'Failed to delete expense' });
  }
});

module.exports = router;
