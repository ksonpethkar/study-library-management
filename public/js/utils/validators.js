/**
 * 🛡️ Study Library Management System — Universal Client Validation Engine
 * Provides instant live input feedback, regex pattern enforcement, and form submission guards.
 */

export const Validators = {
  // Regex Constants
  PATTERNS: {
    PHONE: /^(\+?91[\-\s]?)?[6-9]\d{9}$/,
    EMAIL: /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/,
    GSTIN: /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/,
    PAN: /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/,
    AADHAAR: /^\d{12}$/,
    UPI: /^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$/,
    TIME_24H: /^([01]\d|2[0-3]):[0-5]\d$/
  },

  /**
   * Validates a 10-digit Indian mobile number
   */
  phone(val, required = true) {
    if (!val || !String(val).trim()) {
      return required ? { valid: false, message: 'Mobile number is required' } : { valid: true };
    }
    const clean = String(val).replace(/[^0-9]/g, '');
    const num = clean.length === 12 && clean.startsWith('91') ? clean.slice(2) : clean;
    if (!/^[6-9]\d{9}$/.test(num)) {
      return { valid: false, message: 'Enter a valid 10-digit mobile number (starts with 6, 7, 8, or 9)' };
    }
    return { valid: true, cleanValue: num };
  },

  /**
   * Validates an email address
   */
  email(val, required = false) {
    if (!val || !String(val).trim()) {
      return required ? { valid: false, message: 'Email address is required' } : { valid: true };
    }
    const clean = String(val).trim().toLowerCase();
    if (!this.PATTERNS.EMAIL.test(clean)) {
      return { valid: false, message: 'Please enter a valid email address (e.g. name@domain.com)' };
    }
    return { valid: true, cleanValue: clean };
  },

  /**
   * Validates a text length range
   */
  text(val, min = 2, max = 100, fieldName = 'This field', required = true) {
    if (!val || !String(val).trim()) {
      return required ? { valid: false, message: `${fieldName} is required` } : { valid: true };
    }
    const len = String(val).trim().length;
    if (len < min) return { valid: false, message: `${fieldName} must be at least ${min} characters` };
    if (len > max) return { valid: false, message: `${fieldName} cannot exceed ${max} characters` };
    return { valid: true, cleanValue: String(val).trim() };
  },

  /**
   * Validates positive financial amounts
   */
  amount(val, min = 0.01, max = 1000000, required = true) {
    if (val === undefined || val === null || val === '') {
      return required ? { valid: false, message: 'Amount is required' } : { valid: true };
    }
    const num = parseFloat(val);
    if (isNaN(num)) return { valid: false, message: 'Please enter a valid number' };
    if (num < min) return { valid: false, message: `Amount must be at least ₹${min}` };
    if (num > max) return { valid: false, message: `Amount cannot exceed ₹${max.toLocaleString('en-IN')}` };
    return { valid: true, cleanValue: num };
  },

  /**
   * Validates Indian 12-digit Aadhaar Card number
   */
  aadhaar(val, required = false) {
    if (!val || !String(val).trim()) {
      return required ? { valid: false, message: 'Aadhaar number is required' } : { valid: true };
    }
    const clean = String(val).replace(/[^0-9]/g, '');
    if (clean.length !== 12) {
      return { valid: false, message: 'Aadhaar number must be exactly 12 digits' };
    }
    return { valid: true, cleanValue: clean };
  },

  /**
   * Validates 10-character PAN Card number
   */
  pan(val, required = false) {
    if (!val || !String(val).trim()) {
      return required ? { valid: false, message: 'PAN number is required' } : { valid: true };
    }
    const clean = String(val).trim().toUpperCase();
    if (!this.PATTERNS.PAN.test(clean)) {
      return { valid: false, message: 'Invalid PAN format (e.g. ABCDE1234F)' };
    }
    return { valid: true, cleanValue: clean };
  },

  /**
   * Validates 15-character GSTIN number
   */
  gstin(val, required = false) {
    if (!val || !String(val).trim()) {
      return required ? { valid: false, message: 'GSTIN is required' } : { valid: true };
    }
    const clean = String(val).trim().toUpperCase();
    if (!this.PATTERNS.GSTIN.test(clean)) {
      return { valid: false, message: 'Invalid 15-digit GSTIN (e.g. 27AAAAA0000A1Z5)' };
    }
    return { valid: true, cleanValue: clean };
  },

  /**
   * Validates UPI VPA ID
   */
  upi(val, required = false) {
    if (!val || !String(val).trim()) {
      return required ? { valid: false, message: 'UPI ID is required' } : { valid: true };
    }
    const clean = String(val).trim().toLowerCase();
    if (!this.PATTERNS.UPI.test(clean)) {
      return { valid: false, message: 'Invalid UPI ID format (e.g. user@bank)' };
    }
    return { valid: true, cleanValue: clean };
  },

  /**
   * Validates date range (expiry >= start)
   */
  dateRange(startDate, endDate) {
    if (!startDate || !endDate) return { valid: true };
    const s = new Date(startDate);
    const e = new Date(endDate);
    if (isNaN(s.getTime()) || isNaN(e.getTime())) return { valid: false, message: 'Invalid date format' };
    if (e < s) return { valid: false, message: 'Expiry date cannot be earlier than start date' };
    return { valid: true };
  },

  /**
   * Attaches real-time visual validation feedback to an input element
   */
  attachLiveValidation(inputEl, validatorFn) {
    if (!inputEl) return;

    let feedbackEl = inputEl.parentNode?.querySelector('.invalid-feedback');
    if (!feedbackEl && inputEl.parentNode) {
      feedbackEl = document.createElement('div');
      feedbackEl.className = 'invalid-feedback';
      feedbackEl.style.cssText = 'font-size: 0.78rem; color: #ef4444; margin-top: 3px; font-weight: 600; display: none;';
      inputEl.parentNode.appendChild(feedbackEl);
    }

    const validateNow = () => {
      const result = validatorFn(inputEl.value);
      if (!result.valid) {
        inputEl.classList.add('is-invalid');
        inputEl.classList.remove('is-valid');
        inputEl.style.borderColor = '#ef4444';
        if (feedbackEl) {
          feedbackEl.textContent = result.message || 'Invalid input';
          feedbackEl.style.display = 'block';
        }
        return false;
      } else {
        inputEl.classList.remove('is-invalid');
        inputEl.classList.add('is-valid');
        inputEl.style.borderColor = '#10b981';
        if (feedbackEl) {
          feedbackEl.style.display = 'none';
        }
        return true;
      }
    };

    inputEl.addEventListener('input', validateNow);
    inputEl.addEventListener('blur', validateNow);
    return validateNow;
  },

  /**
   * Validates all required inputs within a container or form
   */
  validateContainer(containerEl) {
    if (!containerEl) return { valid: true };
    let isValid = true;
    let firstInvalid = null;

    const requiredInputs = containerEl.querySelectorAll('input[required], select[required], textarea[required]');
    requiredInputs.forEach(input => {
      let isInputValid = true;
      const val = input.value?.trim() || '';

      if (!val) {
        isInputValid = false;
      } else if (input.type === 'email') {
        isInputValid = this.email(val, true).valid;
      } else if (input.type === 'tel' || input.name === 'phone' || input.name === 'mobile') {
        isInputValid = this.phone(val, true).valid;
      } else if (input.type === 'number') {
        const min = parseFloat(input.min) || 0;
        isInputValid = this.amount(val, min, 10000000, true).valid;
      }

      if (!isInputValid) {
        isValid = false;
        input.classList.add('is-invalid');
        input.style.borderColor = '#ef4444';
        if (!firstInvalid) firstInvalid = input;
      } else {
        input.classList.remove('is-invalid');
        input.style.borderColor = '';
      }
    });

    if (firstInvalid) {
      firstInvalid.focus();
      if (typeof firstInvalid.scrollIntoView === 'function') {
        firstInvalid.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }

    return { valid: isValid, firstInvalid };
  }
};

if (typeof window !== 'undefined') {
  window.Validators = Validators;
}

export default Validators;
