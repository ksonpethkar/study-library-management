const { body, param, query, validationResult } = require('express-validator');

/**
 * Middleware to handle validation errors from express-validator
 */
const handleValidationErrors = (req, res, next) => {
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

/**
 * Creates a single middleware function from validation rules
 * Compatible with Express v5 which doesn't auto-flatten arrays
 */
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

// Reusable regex helpers
const PHONE_REGEX = /^(\+?91[\-\s]?)?[6-9]\d{9}$/;
const GSTIN_REGEX = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/;
const PAN_REGEX = /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/;
const AADHAAR_REGEX = /^\d{12}$/;
const TIME_24H_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;
const UPI_REGEX = /^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$/;

// ── Auth & Users ─────────────────────────────────────────────────────────────
const validateRegistration = validate([
  body('name').trim().notEmpty().withMessage('Name is required').isLength({ min: 2, max: 100 }).withMessage('Name must be between 2 and 100 characters'),
  body('email').isEmail().withMessage('Please include a valid email address').normalizeEmail(),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
]);

const validateLogin = validate([
  body('email').isEmail().withMessage('Please include a valid email address').normalizeEmail(),
  body('password').notEmpty().withMessage('Password is required'),
]);

const validateSetup = validate([
  body('name').trim().notEmpty().withMessage('Admin name is required').isLength({ min: 2, max: 100 }).withMessage('Name must be between 2 and 100 characters'),
  body('email').isEmail().withMessage('Please include a valid email address').normalizeEmail(),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('businessName').trim().notEmpty().withMessage('Business / Library name is required').isLength({ min: 2, max: 120 }).withMessage('Business name must be between 2 and 120 characters'),
]);

const validatePasswordChange = validate([
  body('currentPassword').notEmpty().withMessage('Current password is required'),
  body('newPassword').isLength({ min: 6 }).withMessage('New password must be at least 6 characters'),
]);

// ── Students ─────────────────────────────────────────────────────────────────
const validateStudentCreate = validate([
  body('name').trim().notEmpty().withMessage('Student name is required').isLength({ min: 2, max: 100 }).withMessage('Student name must be 2-100 characters'),
  body('phone').trim().notEmpty().withMessage('Phone number is required').custom(val => {
    const clean = String(val).replace(/[^0-9]/g, '');
    const num = clean.length === 12 && clean.startsWith('91') ? clean.slice(2) : clean;
    if (!/^[6-9]\d{9}$/.test(num)) {
      throw new Error('Please enter a valid 10-digit Indian mobile number (starting with 6, 7, 8, or 9)');
    }
    return true;
  }),
  body('email').optional({ checkFalsy: true }).isEmail().withMessage('Please enter a valid email address').normalizeEmail(),
  body('gender').optional({ checkFalsy: true }).isIn(['male', 'female', 'other', 'Male', 'Female', 'Other']).withMessage('Gender must be Male, Female, or Other'),
  body('dateOfBirth').optional({ checkFalsy: true }).isISO8601().withMessage('Please enter a valid date of birth (YYYY-MM-DD)').custom(val => {
    if (new Date(val) > new Date()) throw new Error('Date of birth cannot be in the future');
    return true;
  }),
  body('admissionDate').optional({ checkFalsy: true }).isISO8601().withMessage('Please enter a valid admission date (YYYY-MM-DD)'),
  body('expiryDate').optional({ checkFalsy: true }).isISO8601().withMessage('Please enter a valid expiry date (YYYY-MM-DD)').custom((val, { req }) => {
    if (req.body.admissionDate && new Date(val) < new Date(req.body.admissionDate)) {
      throw new Error('Validity expiry date cannot be earlier than admission date');
    }
    return true;
  }),
  body('bloodGroup').optional({ checkFalsy: true }).isIn(['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', '']).withMessage('Invalid blood group'),
  body('emergencyContact.phone').optional({ checkFalsy: true }).custom(val => {
    const clean = String(val).replace(/[^0-9]/g, '');
    const num = clean.length === 12 && clean.startsWith('91') ? clean.slice(2) : clean;
    if (!/^[6-9]\d{9}$/.test(num)) {
      throw new Error('Emergency contact must be a valid 10-digit mobile number');
    }
    return true;
  })
]);

const validateStudentUpdate = validate([
  body('name').optional().trim().notEmpty().withMessage('Student name cannot be empty').isLength({ min: 2, max: 100 }),
  body('phone').optional().trim().custom(val => {
    if (!val) return true;
    const clean = String(val).replace(/[^0-9]/g, '');
    const num = clean.length === 12 && clean.startsWith('91') ? clean.slice(2) : clean;
    if (!/^[6-9]\d{9}$/.test(num)) {
      throw new Error('Please enter a valid 10-digit Indian mobile number');
    }
    return true;
  }),
  body('email').optional({ checkFalsy: true }).isEmail().withMessage('Please enter a valid email address').normalizeEmail(),
  body('gender').optional({ checkFalsy: true }).isIn(['male', 'female', 'other', 'Male', 'Female', 'Other']).withMessage('Gender must be Male, Female, or Other'),
  body('dateOfBirth').optional({ checkFalsy: true }).isISO8601().withMessage('Please enter a valid date of birth'),
  body('expiryDate').optional({ checkFalsy: true }).isISO8601().withMessage('Please enter a valid expiry date')
]);

const validatePublicRegister = validate([
  body('name').trim().notEmpty().withMessage('Full Name is required').isLength({ min: 2, max: 100 }).withMessage('Full Name must be 2-100 characters'),
  body('phone').trim().notEmpty().withMessage('Mobile Number is required').custom(val => {
    const clean = String(val).replace(/[^0-9]/g, '');
    const num = clean.length === 12 && clean.startsWith('91') ? clean.slice(2) : clean;
    if (!/^[6-9]\d{9}$/.test(num)) {
      throw new Error('Please enter a valid 10-digit Indian mobile number (starting with 6, 7, 8, or 9)');
    }
    return true;
  }),
  body('email').optional({ checkFalsy: true }).isEmail().withMessage('Please enter a valid email address').normalizeEmail(),
  body('gender').optional({ checkFalsy: true }).isIn(['male', 'female', 'other', 'Male', 'Female', 'Other']).withMessage('Please select a valid gender')
]);

// ── Payments & Invoices ──────────────────────────────────────────────────────
const validatePaymentCreate = validate([
  body('student').trim().notEmpty().withMessage('Student ID is required for payment'),
  body('amount').notEmpty().withMessage('Payment amount is required').isFloat({ min: 0.01 }).withMessage('Payment amount must be greater than 0'),
  body('discount').optional().isFloat({ min: 0 }).withMessage('Discount cannot be negative').custom((val, { req }) => {
    const amt = parseFloat(req.body.amount || 0);
    if (parseFloat(val) > amt) throw new Error('Discount cannot exceed payment amount');
    return true;
  }),
  body('tax').optional().isFloat({ min: 0 }).withMessage('Tax cannot be negative'),
  body('paymentMode').optional().isIn(['cash', 'upi', 'card', 'bank_transfer', 'online', 'cheque', 'other', 'Cash', 'UPI', 'Card', 'Bank Transfer', 'Online']).withMessage('Invalid payment mode'),
  body('paymentType').optional().isIn(['plan_fee', 'registration_fee', 'locker_fee', 'security_deposit', 'fine', 'other']).withMessage('Invalid payment type')
]);

const validatePaymentUpdate = validate([
  body('amount').optional().isFloat({ min: 0.01 }).withMessage('Amount must be greater than 0'),
  body('discount').optional().isFloat({ min: 0 }).withMessage('Discount cannot be negative'),
  body('tax').optional().isFloat({ min: 0 }).withMessage('Tax cannot be negative'),
  body('paymentMode').optional().isIn(['cash', 'upi', 'card', 'bank_transfer', 'online', 'cheque', 'other', 'Cash', 'UPI', 'Card', 'Bank Transfer', 'Online']).withMessage('Invalid payment mode')
]);

// ── Plans ────────────────────────────────────────────────────────────────────
const validatePlanCreate = validate([
  body('name').trim().notEmpty().withMessage('Plan name is required').isLength({ min: 2, max: 100 }).withMessage('Plan name must be 2-100 characters'),
  body('price').notEmpty().withMessage('Plan fee price is required').isFloat({ min: 0 }).withMessage('Plan price cannot be negative'),
  body('duration').notEmpty().withMessage('Duration is required').isInt({ min: 1 }).withMessage('Duration must be at least 1'),
  body('durationType').optional().isIn(['days', 'months', 'years', 'hours', 'day', 'month', 'year', 'hour']).withMessage('Duration type must be days, months, years, or hours')
]);

const validatePlanUpdate = validate([
  body('name').optional().trim().notEmpty().withMessage('Plan name cannot be empty').isLength({ min: 2, max: 100 }),
  body('price').optional().isFloat({ min: 0 }).withMessage('Price cannot be negative'),
  body('duration').optional().isInt({ min: 1 }).withMessage('Duration must be at least 1'),
  body('durationType').optional().isIn(['days', 'months', 'years', 'hours', 'day', 'month', 'year', 'hour']).withMessage('Invalid duration type')
]);

// ── Seats & Desks ────────────────────────────────────────────────────────────
const validateSeatCreate = validate([
  body('seatNumber').trim().notEmpty().withMessage('Seat / Desk number is required').isLength({ min: 1, max: 30 }).withMessage('Seat number max 30 characters'),
  body('branch').trim().notEmpty().withMessage('Branch selection is required'),
  body('type').optional().isIn(['regular', 'premium', 'discussion', 'silent', 'cubicle', 'ac', 'non-ac', 'window']).withMessage('Invalid seat type')
]);

const validateSeatUpdate = validate([
  body('seatNumber').optional().trim().notEmpty().withMessage('Seat number cannot be empty'),
  body('type').optional().isIn(['regular', 'premium', 'discussion', 'silent', 'cubicle', 'ac', 'non-ac', 'window']).withMessage('Invalid seat type')
]);

// ── Shifts ───────────────────────────────────────────────────────────────────
const validateShiftCreate = validate([
  body('name').trim().notEmpty().withMessage('Shift name is required').isLength({ min: 2, max: 60 }),
  body('startTime').optional({ checkFalsy: true }).matches(TIME_24H_REGEX).withMessage('Start time must be in HH:MM format (24-hour)'),
  body('endTime').optional({ checkFalsy: true }).matches(TIME_24H_REGEX).withMessage('End time must be in HH:MM format (24-hour)')
]);

const validateShiftUpdate = validate([
  body('name').optional().trim().notEmpty().withMessage('Shift name cannot be empty'),
  body('startTime').optional({ checkFalsy: true }).matches(TIME_24H_REGEX).withMessage('Start time must be in HH:MM format'),
  body('endTime').optional({ checkFalsy: true }).matches(TIME_24H_REGEX).withMessage('End time must be in HH:MM format')
]);

// ── Expenses ─────────────────────────────────────────────────────────────────
const validateExpenseCreate = validate([
  body('title').trim().notEmpty().withMessage('Expense title is required').isLength({ min: 2, max: 120 }),
  body('amount').notEmpty().withMessage('Expense amount is required').isFloat({ min: 0.01 }).withMessage('Expense amount must be greater than 0'),
  body('category').optional().isIn(['rent', 'electricity', 'internet', 'maintenance', 'salaries', 'supplies', 'marketing', 'software', 'cleaning', 'tea_snacks', 'other']).withMessage('Invalid expense category'),
  body('date').optional({ checkFalsy: true }).isISO8601().withMessage('Please enter a valid expense date')
]);

const validateExpenseUpdate = validate([
  body('title').optional().trim().notEmpty().withMessage('Expense title cannot be empty'),
  body('amount').optional().isFloat({ min: 0.01 }).withMessage('Amount must be greater than 0'),
  body('category').optional().isIn(['rent', 'electricity', 'internet', 'maintenance', 'salaries', 'supplies', 'marketing', 'software', 'cleaning', 'tea_snacks', 'other']).withMessage('Invalid category'),
  body('date').optional({ checkFalsy: true }).isISO8601().withMessage('Please enter a valid date')
]);

// ── Lockers ──────────────────────────────────────────────────────────────────
const validateLockerCreate = validate([
  body('lockerNumber').trim().notEmpty().withMessage('Locker number is required').isLength({ min: 1, max: 30 }),
  body('branch').trim().notEmpty().withMessage('Branch is required for locker allotment'),
  body('fee').optional().isFloat({ min: 0 }).withMessage('Locker fee cannot be negative'),
  body('deposit').optional().isFloat({ min: 0 }).withMessage('Security deposit cannot be negative')
]);

const validateLockerUpdate = validate([
  body('lockerNumber').optional().trim().notEmpty().withMessage('Locker number cannot be empty'),
  body('fee').optional().isFloat({ min: 0 }).withMessage('Locker fee cannot be negative'),
  body('deposit').optional().isFloat({ min: 0 }).withMessage('Security deposit cannot be negative')
]);

// ── Branches ─────────────────────────────────────────────────────────────────
const validateBranchCreate = validate([
  body('name').trim().notEmpty().withMessage('Branch name is required').isLength({ min: 2, max: 100 }),
  body('totalSeats').optional().isInt({ min: 1 }).withMessage('Total seats must be at least 1'),
  body('phone').optional({ checkFalsy: true }).custom(val => {
    const clean = String(val).replace(/[^0-9]/g, '');
    const num = clean.length === 12 && clean.startsWith('91') ? clean.slice(2) : clean;
    if (!/^[6-9]\d{9}$/.test(num)) throw new Error('Please enter a valid 10-digit branch contact phone');
    return true;
  }),
  body('email').optional({ checkFalsy: true }).isEmail().withMessage('Invalid branch email address').normalizeEmail()
]);

const validateBranchUpdate = validate([
  body('name').optional().trim().notEmpty().withMessage('Branch name cannot be empty'),
  body('totalSeats').optional().isInt({ min: 1 }).withMessage('Total seats must be at least 1')
]);

// ── Custom Fields & Form Builder ─────────────────────────────────────────────
const validateCustomField = validate([
  body('label').trim().notEmpty().withMessage('Question field label is required').isLength({ min: 1, max: 150 }),
  body('fieldName').optional().trim().matches(/^[a-zA-Z0-9_]+$/).withMessage('Field key must contain only letters, numbers, and underscores'),
  body('type').optional().isIn([
    'text', 'number', 'textarea', 'select', 'radio', 'checkbox', 'date', 
    'photo_upload', 'file', 'email', 'phone', 'blood_group', 'exam_badge', 
    'star_rating', 'terms_checkbox', 'consent_checkbox', 'heading', 'divider'
  ]).withMessage('Invalid custom field type')
]);

// ── Business Profile & Settings ──────────────────────────────────────────────
const validateBusinessProfile = validate([
  body('businessName').optional().trim().notEmpty().withMessage('Business name cannot be empty').isLength({ min: 2, max: 120 }),
  body('email').optional({ checkFalsy: true }).isEmail().withMessage('Please enter a valid official email').normalizeEmail(),
  body('phone').optional({ checkFalsy: true }).custom(val => {
    const clean = String(val).replace(/[^0-9]/g, '');
    const num = clean.length === 12 && clean.startsWith('91') ? clean.slice(2) : clean;
    if (!/^[6-9]\d{9}$/.test(num)) throw new Error('Please enter a valid 10-digit phone number');
    return true;
  }),
  body('gstNumber').optional({ checkFalsy: true }).custom(val => {
    if (!GSTIN_REGEX.test(String(val).trim())) throw new Error('Invalid GSTIN format (e.g. 27AAAAA0000A1Z5)');
    return true;
  }),
  body('upiId').optional({ checkFalsy: true }).custom(val => {
    if (!UPI_REGEX.test(String(val).trim())) throw new Error('Invalid UPI ID format (e.g. user@okhdfcbank)');
    return true;
  })
]);

module.exports = {
  validate,
  handleValidationErrors,
  PHONE_REGEX,
  GSTIN_REGEX,
  PAN_REGEX,
  AADHAAR_REGEX,
  TIME_24H_REGEX,
  UPI_REGEX,
  validateRegistration,
  validateLogin,
  validateSetup,
  validatePasswordChange,
  validateStudentCreate,
  validateStudentUpdate,
  validatePublicRegister,
  validatePaymentCreate,
  validatePaymentUpdate,
  validatePlanCreate,
  validatePlanUpdate,
  validateSeatCreate,
  validateSeatUpdate,
  validateShiftCreate,
  validateShiftUpdate,
  validateExpenseCreate,
  validateExpenseUpdate,
  validateLockerCreate,
  validateLockerUpdate,
  validateBranchCreate,
  validateBranchUpdate,
  validateCustomField,
  validateBusinessProfile
};
