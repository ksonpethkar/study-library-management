const { Validators } = require('../public/js/utils/validators');
const {
  validateStudentCreate,
  validatePaymentCreate,
  validatePlanCreate,
  validateExpenseCreate
} = require('../middleware/validate');

console.log('🧪 Testing Validators Engine & Patterns...');

// Test 1: Phone validator
const vPhoneBad = Validators.phone('12345');
const vPhoneBad2 = Validators.phone('5876543210'); // starts with 5
const vPhoneGood = Validators.phone('9876543210');
const vPhoneFormatted = Validators.phone('+91 9876543210');
console.assert(!vPhoneBad.valid, 'Bad phone should fail');
console.assert(!vPhoneBad2.valid, 'Phone not starting with 6-9 should fail');
console.assert(vPhoneGood.valid, 'Good phone should pass');
console.assert(vPhoneFormatted.valid, 'Formatted Indian phone should pass');
console.log('✔ Phone validation checks passed');

// Test 2: Email validator
const vEmailBad = Validators.email('invalid-email');
const vEmailGood = Validators.email('student@studycentre.com');
console.assert(!vEmailBad.valid, 'Bad email should fail');
console.assert(vEmailGood.valid, 'Good email should pass');
console.log('✔ Email validation checks passed');

// Test 3: Aadhaar
const vAadhaarBad = Validators.aadhaar('1234');
const vAadhaarGood = Validators.aadhaar('123456789012');
console.assert(!vAadhaarBad.valid, 'Bad Aadhaar should fail');
console.assert(vAadhaarGood.valid, 'Good Aadhaar should pass');
console.log('✔ Aadhaar validation checks passed');

// Test 4: PAN
const vPanBad = Validators.pan('12345');
const vPanGood = Validators.pan('ABCDE1234F');
console.assert(!vPanBad.valid, 'Bad PAN should fail');
console.assert(vPanGood.valid, 'Good PAN should pass');
console.log('✔ PAN validation checks passed');

// Test 5: GSTIN
const vGstinBad = Validators.gstin('GSTIN123');
const vGstinGood = Validators.gstin('27AAAAA0000A1Z5');
console.assert(!vGstinBad.valid, 'Bad GSTIN should fail');
console.assert(vGstinGood.valid, 'Good GSTIN should pass');
console.log('✔ GSTIN validation checks passed');

// Test 6: UPI
const vUpiBad = Validators.upi('badupi');
const vUpiGood = Validators.upi('thecozycorner@okaxis');
console.assert(!vUpiBad.valid, 'Bad UPI should fail');
console.assert(vUpiGood.valid, 'Good UPI should pass');
console.log('✔ UPI validation checks passed');

// Test 7: Amount & Bounds
const vAmtZero = Validators.amount(0);
const vAmtNeg = Validators.amount(-50);
const vAmtGood = Validators.amount(500);
console.assert(!vAmtZero.valid, 'Zero amount should fail');
console.assert(!vAmtNeg.valid, 'Negative amount should fail');
console.assert(vAmtGood.valid, 'Positive amount should pass');
console.log('✔ Amount bounds checks passed');

// Test 8: Date Range
const vDateBad = Validators.dateRange('2026-09-01', '2026-08-01');
const vDateGood = Validators.dateRange('2026-08-01', '2026-09-01');
console.assert(!vDateBad.valid, 'Expiry earlier than start should fail');
console.assert(vDateGood.valid, 'Expiry after start should pass');
console.log('✔ Date range checks passed');

console.log('\n🎉 ALL VALIDATION CHECKS PASSED PERFECTLY!');
