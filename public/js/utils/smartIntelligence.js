/**
 * SmartIntelligence - Utility module for Pincode Auto-Fill, Seat Matching & Duplicate Prevention
 */

// Internal Cache for Pincodes (Pre-seeded major Indian postal codes for 0ms lookup)
const PINCODE_CACHE = new Map([
  ['400001', { city: 'Mumbai', state: 'Maharashtra' }],
  ['400002', { city: 'Mumbai', state: 'Maharashtra' }],
  ['411001', { city: 'Pune', state: 'Maharashtra' }],
  ['411002', { city: 'Pune', state: 'Maharashtra' }],
  ['110001', { city: 'New Delhi', state: 'Delhi' }],
  ['110002', { city: 'New Delhi', state: 'Delhi' }],
  ['560001', { city: 'Bengaluru', state: 'Karnataka' }],
  ['500001', { city: 'Hyderabad', state: 'Telangana' }],
  ['600001', { city: 'Chennai', state: 'Tamil Nadu' }],
  ['700001', { city: 'Kolkata', state: 'West Bengal' }],
  ['380001', { city: 'Ahmedabad', state: 'Gujarat' }],
  ['302001', { city: 'Jaipur', state: 'Rajasthan' }],
  ['226001', { city: 'Lucknow', state: 'Uttar Pradesh' }],
  ['800001', { city: 'Patna', state: 'Bihar' }],
  ['413512', { city: 'Latur', state: 'Maharashtra' }],
  ['413601', { city: 'Dharashiv', state: 'Maharashtra' }],
  ['413001', { city: 'Solapur', state: 'Maharashtra' }],
  ['431601', { city: 'Nanded', state: 'Maharashtra' }],
  ['431001', { city: 'Chhatrapati Sambhajinagar', state: 'Maharashtra' }]
]);

// Prefix Fallbacks for Instant 0ms Approximation
const PREFIX_MAP = {
  '400': { city: 'Mumbai', state: 'Maharashtra' },
  '401': { city: 'Thane / Palghar', state: 'Maharashtra' },
  '411': { city: 'Pune', state: 'Maharashtra' },
  '4135': { city: 'Latur / Ausa', state: 'Maharashtra' },
  '4136': { city: 'Dharashiv (Osmanabad)', state: 'Maharashtra' },
  '4130': { city: 'Solapur', state: 'Maharashtra' },
  '4131': { city: 'Solapur / Baramati', state: 'Maharashtra' },
  '4315': { city: 'Hingoli / Parbhani', state: 'Maharashtra' },
  '4316': { city: 'Nanded', state: 'Maharashtra' },
  '4311': { city: 'Beed', state: 'Maharashtra' },
  '4312': { city: 'Jalna', state: 'Maharashtra' },
  '4310': { city: 'Chhatrapati Sambhajinagar', state: 'Maharashtra' },
  '110': { city: 'New Delhi', state: 'Delhi' },
  '560': { city: 'Bengaluru', state: 'Karnataka' },
  '500': { city: 'Hyderabad', state: 'Telangana' },
  '600': { city: 'Chennai', state: 'Tamil Nadu' },
  '700': { city: 'Kolkata', state: 'West Bengal' },
  '380': { city: 'Ahmedabad', state: 'Gujarat' },
  '302': { city: 'Jaipur', state: 'Rajasthan' },
  '226': { city: 'Lucknow', state: 'Uttar Pradesh' },
  '800': { city: 'Patna', state: 'Bihar' }
};

export class SmartIntelligence {
  /**
   * Fetches city & state for Indian 6-digit pincode in 0ms (uses internal cache + Postal API)
   * @param {string|number} pincode 
   * @returns {Promise<{city: string, state: string, success: boolean, source: string}>}
   */
  static async lookupPincode(pincode) {
    if (!pincode) return { city: '', state: '', success: false };
    const pin = String(pincode).trim().replace(/\D/g, '');
    if (pin.length !== 6) return { city: '', state: '', success: false };

    // 1. Direct hit in internal cache (0ms)
    if (PINCODE_CACHE.has(pin)) {
      const cached = PINCODE_CACHE.get(pin);
      return { city: cached.city, state: cached.state, success: true, source: 'cache' };
    }

    // 2. Check instant prefix match for immediate response
    const p4 = pin.substring(0, 4);
    const p3 = pin.substring(0, 3);
    const prefixMatch = PREFIX_MAP[p4] || PREFIX_MAP[p3];

    let resultCity = prefixMatch ? prefixMatch.city : '';
    let resultState = prefixMatch ? prefixMatch.state : '';

    try {
      // 3. Try backend local pincode API first
      try {
        const res = await fetch(`/api/search/pincode/${pin}`);
        if (res.ok) {
          const json = await res.json();
          if (json.success && json.data) {
            resultCity = json.data.city || json.data.district || resultCity;
            resultState = json.data.state || resultState;
            PINCODE_CACHE.set(pin, { city: resultCity, state: resultState });
            return { city: resultCity, state: resultState, success: true, source: 'local_api' };
          }
        }
      } catch (e) {
        // Fallback to Postal API
      }

      // 4. Try Postal API (postalpincode.in)
      const res = await fetch(`https://api.postalpincode.in/pincode/${pin}`);
      if (res.ok) {
        const data = await res.json();
        if (data && data[0]?.Status === 'Success' && data[0]?.PostOffice?.length > 0) {
          const po = data[0].PostOffice[0];
          resultCity = po.District || po.Division || po.Block || po.Name || resultCity;
          resultState = po.State || resultState;
          PINCODE_CACHE.set(pin, { city: resultCity, state: resultState });
          return { city: resultCity, state: resultState, success: true, source: 'postal_api' };
        }
      }
    } catch (e) {
      // Network or parsing error
    }

    if (resultCity || resultState) {
      PINCODE_CACHE.set(pin, { city: resultCity, state: resultState });
      return { city: resultCity, state: resultState, success: true, source: 'prefix' };
    }

    return { city: '', state: '', success: false };
  }

  /**
   * Recommends best available vacant desk number matching student preferences
   * @param {string|null} shiftId 
   * @param {string|null} zoneName 
   * @param {Array} seats 
   * @returns {Object|null} Recommended seat object with match details
   */
  static suggestSeat(shiftId = null, zoneName = null, seats = []) {
    if (!Array.isArray(seats) || seats.length === 0) return null;

    // Filter available seats
    const availableSeats = seats.filter(s => {
      if (!s) return false;
      const isAvailable = s.status === 'available' || s.status === 'vacant' || (!s.currentStudent && s.status !== 'occupied' && s.status !== 'maintenance');
      const isActive = s.isActive !== false;
      return isAvailable && isActive;
    });

    if (availableSeats.length === 0) return null;

    const normZone = zoneName ? String(zoneName).trim().toLowerCase() : null;
    const normShift = shiftId ? String(shiftId).trim().toLowerCase() : null;

    // Score seats based on preferences
    const scoredSeats = availableSeats.map(seat => {
      let score = 0;
      const seatZone = seat.zone ? String(seat.zone).trim().toLowerCase() : '';
      const seatType = seat.seatType || seat.type || '';
      const seatShift = seat.shift ? String(seat.shift).trim().toLowerCase() : null;

      // 1. Zone Preference Match
      if (normZone) {
        if (seatZone === normZone) {
          score += 100;
        } else if (seatZone.includes(normZone) || normZone.includes(seatZone)) {
          score += 50;
        }
      }

      // 2. Shift Compatibility
      if (normShift) {
        if (seatShift === normShift) {
          score += 50;
        } else if (!seatShift) {
          score += 20;
        }
      }

      // 3. Seat Type & Tier Bonuses
      if (seatType === 'premium' || seat.type === 'premium') score += 15;
      if (seatType === 'glass_cabin' || seatType === 'cabin') score += 12;
      if (seatType === 'corner_desk') score += 10;
      if (Array.isArray(seat.amenities) && seat.amenities.length > 0) {
        score += Math.min(seat.amenities.length * 2, 10);
      }

      return { seat, score };
    });

    // Sort descending by score, then ascending by seat number
    scoredSeats.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      const numA = parseInt(String(a.seat.seatNumber).replace(/\D/g, ''), 10) || 0;
      const numB = parseInt(String(b.seat.seatNumber).replace(/\D/g, ''), 10) || 0;
      return numA - numB;
    });

    const bestMatch = scoredSeats[0];
    return {
      seat: bestMatch.seat,
      seatNumber: bestMatch.seat.seatNumber,
      seatId: bestMatch.seat._id || bestMatch.seat.id,
      zone: bestMatch.seat.zone,
      score: bestMatch.score,
      matchReason: normZone && bestMatch.seat.zone?.toLowerCase().includes(normZone)
        ? `Best vacant desk matching "${zoneName}" zone`
        : 'Recommended vacant seat'
    };
  }

  /**
   * Checks if a student with matching phone or email already exists and returns warning details
   * @param {string} phone 
   * @param {string} email 
   * @param {Array} existingStudents 
   * @returns {{isDuplicate: boolean, duplicateField: string|null, matchedStudent: Object|null, message: string}}
   */
  static checkDuplicateStudent(phone = '', email = '', existingStudents = []) {
    const cleanPhone = String(phone || '').replace(/\D/g, '').slice(-10);
    const cleanEmail = String(email || '').trim().toLowerCase();

    if (!cleanPhone && !cleanEmail) {
      return { isDuplicate: false, duplicateField: null, matchedStudent: null, message: '' };
    }

    if (!Array.isArray(existingStudents) || existingStudents.length === 0) {
      return { isDuplicate: false, duplicateField: null, matchedStudent: null, message: '' };
    }

    let phoneMatch = null;
    let emailMatch = null;

    for (const student of existingStudents) {
      if (!student) continue;

      if (cleanPhone && student.phone) {
        const sPhone = String(student.phone).replace(/\D/g, '').slice(-10);
        if (sPhone && sPhone === cleanPhone) {
          phoneMatch = student;
        }
      }

      if (cleanEmail && student.email) {
        const sEmail = String(student.email).trim().toLowerCase();
        if (sEmail && sEmail === cleanEmail) {
          emailMatch = student;
        }
      }

      if (phoneMatch && emailMatch) break;
    }

    if (phoneMatch && emailMatch) {
      const studentName = phoneMatch.name || 'Existing Student';
      const studentId = phoneMatch.studentId || phoneMatch._id || '';
      return {
        isDuplicate: true,
        duplicateField: 'both',
        matchedStudent: phoneMatch,
        message: `⚠️ Student with this mobile number (${phone}) & email (${email}) is already registered as ${studentName} ${studentId ? '(' + studentId + ')' : ''}.`
      };
    } else if (phoneMatch) {
      const studentName = phoneMatch.name || 'Existing Student';
      const studentId = phoneMatch.studentId || phoneMatch._id || '';
      return {
        isDuplicate: true,
        duplicateField: 'phone',
        matchedStudent: phoneMatch,
        message: `⚠️ Mobile number ${phone} is already registered to ${studentName} ${studentId ? '(' + studentId + ')' : ''}.`
      };
    } else if (emailMatch) {
      const studentName = emailMatch.name || 'Existing Student';
      const studentId = emailMatch.studentId || emailMatch._id || '';
      return {
        isDuplicate: true,
        duplicateField: 'email',
        matchedStudent: emailMatch,
        message: `⚠️ Email ${email} is already registered to ${studentName} ${studentId ? '(' + studentId + ')' : ''}.`
      };
    }

    return { isDuplicate: false, duplicateField: null, matchedStudent: null, message: '' };
  }

  /**
   * Returns exact label, placeholder, regex pattern, formatting function, and error message for selected ID proof type.
   * @param {string} idType - e.g. "Aadhaar Card", "PAN Card", "Voter ID", "Driving License", "College Student ID", "Passport"
   */
  static getIDProofConfig(idType = '') {
    const norm = String(idType || '').trim().toLowerCase();

    if (norm.includes('aadhaar') || norm.includes('adhar')) {
      return {
        type: 'aadhaar',
        name: 'Aadhaar Card',
        label: 'Aadhaar Card Number',
        placeholder: 'Enter 12-digit Aadhaar (e.g. 5432 1098 7654)',
        pattern: '^[2-9]{1}[0-9]{3}\\s?[0-9]{4}\\s?[0-9]{4}$|^[2-9]{1}[0-9]{11}$',
        regex: /^[2-9]\d{3}\s?\d{4}\s?\d{4}$|^[2-9]\d{11}$/,
        formatFn: (v) => {
          const digits = String(v || '').replace(/\D/g, '').slice(0, 12);
          if (digits.length <= 4) return digits;
          if (digits.length <= 8) return `${digits.slice(0, 4)} ${digits.slice(4)}`;
          return `${digits.slice(0, 4)} ${digits.slice(4, 8)} ${digits.slice(8)}`;
        },
        errorMessage: 'Invalid Aadhaar Number! Must be 12 digits (cannot start with 0 or 1, e.g. 5432 1098 7654).'
      };
    } else if (norm.includes('pan')) {
      return {
        type: 'pan',
        name: 'PAN Card',
        label: 'PAN Card Number',
        placeholder: 'Enter 10-character PAN (e.g. ABCDE1234F)',
        pattern: '^[A-Z]{5}[0-9]{4}[A-Z]{1}$',
        regex: /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/i,
        formatFn: (v) => String(v || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10),
        errorMessage: 'Invalid PAN Number! Must be 10 characters: 5 letters, 4 digits, 1 letter (e.g. ABCDE1234F).'
      };
    } else if (norm.includes('voter') || norm.includes('epic')) {
      return {
        type: 'voter',
        name: 'Voter ID Card',
        label: 'Voter ID / EPIC Number',
        placeholder: 'Enter Voter ID (e.g. ABC1234567)',
        pattern: '^[A-Z]{3}[0-9]{7}$|^[A-Z0-9\\/\\-]{6,16}$',
        regex: /^[A-Z]{3}[0-9]{7}$/i,
        formatFn: (v) => String(v || '').toUpperCase().replace(/[^A-Z0-9\/\-]/g, '').slice(0, 14),
        errorMessage: 'Invalid Voter ID! Standard EPIC format is 3 letters followed by 7 digits (e.g. ABC1234567).'
      };
    } else if (norm.includes('driving') || norm.includes('dl') || norm.includes('license')) {
      return {
        type: 'dl',
        name: 'Driving License',
        label: 'Driving License Number',
        placeholder: 'Enter DL Number (e.g. MH12 20180012345)',
        pattern: '^[A-Z]{2}[0-9A-Z\\/\\-\\s]{8,18}$',
        regex: /^[A-Z]{2}[0-9A-Z\/\-\s]{8,18}$/i,
        formatFn: (v) => String(v || '').toUpperCase().replace(/[^A-Z0-9\/\-\s]/g, '').slice(0, 18),
        errorMessage: 'Invalid Driving License Number! Must start with 2-letter State code (e.g. MH12 20180012345).'
      };
    } else if (norm.includes('college') || norm.includes('student')) {
      return {
        type: 'college',
        name: 'College Student ID',
        label: 'College Student Roll No / ID Number',
        placeholder: 'Enter Student Roll No / ID (e.g. STU-98765)',
        pattern: '^[A-Za-z0-9\\-\\/]{3,25}$',
        regex: /^[A-Za-z0-9\-\/]{3,25}$/,
        formatFn: (v) => String(v || '').slice(0, 25),
        errorMessage: 'Enter a valid Student ID Number (minimum 3 characters).'
      };
    } else if (norm.includes('passport')) {
      return {
        type: 'passport',
        name: 'Passport',
        label: 'Passport Number',
        placeholder: 'Enter 8-character Passport (e.g. A1234567)',
        pattern: '^[A-PR-WYa-pr-wy][0-9]{7}$',
        regex: /^[A-PR-WYa-pr-wy][0-9]{7}$/i,
        formatFn: (v) => String(v || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 8),
        errorMessage: 'Invalid Passport Number! Must be 1 letter followed by 7 digits (e.g. A1234567).'
      };
    }

    return {
      type: 'generic',
      name: idType || 'ID Proof',
      label: `${idType || 'ID Proof'} Document Number`,
      placeholder: `Enter ${idType || 'ID Proof'} Number`,
      pattern: '.*',
      regex: /^[A-Za-z0-9\/\-\s]{3,30}$/,
      formatFn: (v) => String(v || '').slice(0, 30),
      errorMessage: 'Invalid ID Proof document number format (minimum 3 characters).'
    };
  }

  /**
   * Validates Government ID format.
   * @param {string} idType 
   * @param {string} idNumber 
   * @returns {{isValid: boolean, message: string}}
   */
  static validateGovernmentID(idType = '', idNumber = '') {
    if (!idNumber || !idNumber.trim()) return { isValid: true, message: '' };
    const config = this.getIDProofConfig(idType);
    const clean = idNumber.trim();
    if (config.regex && !config.regex.test(clean)) {
      return { isValid: false, message: config.errorMessage || `Invalid ${config.name} number format.` };
    }
    return { isValid: true, message: `✅ Valid ${config.name} format` };
  }

  /**
   * Auto-infers the Government ID Proof Type from a typed or pasted number
   * @param {string} inputVal 
   * @returns {string|null} "Aadhaar Card" | "PAN Card" | "Voter ID" | "Driving License" | "Passport" | null
   */
  static detectIDTypeFromNumber(inputVal = '') {
    if (!inputVal) return null;
    const raw = String(inputVal).trim();
    const cleanDigits = raw.replace(/\D/g, '');
    const cleanAlphaNum = raw.replace(/[^A-Za-z0-9]/g, '').toUpperCase();

    // 1. Aadhaar: exactly 12 digits (starting with 2-9)
    if (cleanDigits.length === 12 && /^[2-9]\d{11}$/.test(cleanDigits)) {
      return 'Aadhaar Card';
    }

    // 2. PAN Card: 5 uppercase letters + 4 digits + 1 letter (10 chars)
    if (cleanAlphaNum.length === 10 && /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/.test(cleanAlphaNum)) {
      return 'PAN Card';
    }

    // 3. Voter ID / EPIC: 3 letters + 7 digits
    if (cleanAlphaNum.length === 10 && /^[A-Z]{3}[0-9]{7}$/.test(cleanAlphaNum)) {
      return 'Voter ID';
    }

    // 4. Passport: 1 letter + 7 digits (8 chars)
    if (cleanAlphaNum.length === 8 && /^[A-PR-WYa-pr-wy][0-9]{7}$/i.test(cleanAlphaNum)) {
      return 'Passport';
    }

    // 5. Driving License: 2-letter state code + 10-16 alphanumeric chars
    if (cleanAlphaNum.length >= 12 && cleanAlphaNum.length <= 18 && /^[A-Z]{2}[0-9A-Z]{10,16}$/.test(cleanAlphaNum)) {
      return 'Driving License';
    }

    return null;
  }

  /**
   * Scans an uploaded file or Base64 image URL to extract Government ID type & document number
   * @param {File|Blob|string} fileOrDataUrl 
   * @param {string} fallbackType 
   * @returns {Promise<{detectedType: string|null, detectedNumber: string|null, confidence: number}>}
   */
  static async scanDocumentImage(fileOrDataUrl, fallbackType = '') {
    if (!fileOrDataUrl) return { detectedType: null, detectedNumber: null, confidence: 0 };

    let imageString = '';
    let fileName = '';

    if (typeof fileOrDataUrl === 'string') {
      imageString = fileOrDataUrl;
    } else if (fileOrDataUrl instanceof File || fileOrDataUrl instanceof Blob) {
      fileName = fileOrDataUrl.name || '';
      try {
        imageString = await new Promise((resolve) => {
          const reader = new FileReader();
          reader.onload = () => resolve(reader.result || '');
          reader.onerror = () => resolve('');
          reader.readAsDataURL(fileOrDataUrl);
        });
      } catch (e) {
        imageString = '';
      }
    }

    // 1. Client-Side instant pattern match from filename or text stream
    const sourceStream = `${fileName} ${imageString.slice(0, 3000)}`;

    const aadhaarMatch = sourceStream.match(/\b([2-9]\d{3})\s?(\d{4})\s?(\d{4})\b/) || sourceStream.match(/\b([2-9]\d{11})\b/);
    if (aadhaarMatch) {
      const clean = (aadhaarMatch[0] || '').replace(/\D/g, '');
      if (clean.length === 12) {
        return {
          detectedType: 'Aadhaar Card',
          detectedNumber: `${clean.slice(0, 4)} ${clean.slice(4, 8)} ${clean.slice(8)}`,
          confidence: 0.95
        };
      }
    }

    const panMatch = sourceStream.match(/\b([A-Za-z]{5}\d{4}[A-Za-z]{1})\b/);
    if (panMatch) {
      return {
        detectedType: 'PAN Card',
        detectedNumber: panMatch[1].toUpperCase(),
        confidence: 0.95
      };
    }

    const voterMatch = sourceStream.match(/\b([A-Za-z]{3}\d{7})\b/);
    if (voterMatch) {
      return {
        detectedType: 'Voter ID',
        detectedNumber: voterMatch[1].toUpperCase(),
        confidence: 0.90
      };
    }

    const passMatch = sourceStream.match(/\b([A-PR-WYa-pr-wy]\d{7})\b/);
    if (passMatch) {
      return {
        detectedType: 'Passport',
        detectedNumber: passMatch[1].toUpperCase(),
        confidence: 0.90
      };
    }

    // 2. Query backend OCR detector
    try {
      const res = await fetch('/api/search/ocr-id-proof', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ image: imageString.slice(0, 10000), fileName })
      });
      if (res.ok) {
        const json = await res.json();
        if (json.success && json.data && json.data.detectedNumber) {
          return json.data;
        }
      }
    } catch (err) {
      // Backend lookup fallback
    }

    return { detectedType: null, detectedNumber: null, confidence: 0 };
  }

  /**
   * Dynamically binds ID Proof Type select, Number input, and Auto-Fetch from Document Upload
   * @param {HTMLElement|Document} rootEl 
   */
  static bindDynamicIDProofValidation(rootEl = document) {
    const typeSelect = rootEl.querySelector('select[name="idProof.type"], select[name="idProofType"], select[name="idprooftype"], select[data-field="idprooftype"], select[data-field="idProofType"], select[name="cf_idprooftype"], select[name="cf_idproof_type"], select[data-field="idproof_type"]');
    const numInput = rootEl.querySelector('input[name="idProof.number"], input[name="idProofNumber"], input[name="idproofnumber"], input[data-field="idproofnumber"], input[data-field="idProofNumber"], input[name="cf_idproofnumber"], input[name="cf_idproof_number"], input[data-field="idproof_number"]');

    if (!typeSelect || !numInput) return;

    const numWrapper = numInput.closest('.form-group, .dynamic-field-wrapper, div');
    const labelEl = numWrapper ? (numWrapper.querySelector('label') || document.querySelector('#idProofNumberLabel')) : null;

    let alertDiv = numWrapper ? numWrapper.querySelector('.id-proof-feedback-msg') : null;
    if (!alertDiv && numWrapper) {
      alertDiv = document.createElement('div');
      alertDiv.className = 'id-proof-feedback-msg mt-1 small';
      alertDiv.style.fontWeight = '600';
      alertDiv.style.transition = 'all 0.3s ease';
      numWrapper.appendChild(alertDiv);
    }

    function applyRules() {
      const selectedType = typeSelect.value || '';
      const config = SmartIntelligence.getIDProofConfig(selectedType);

      if (labelEl) {
        labelEl.innerHTML = `${config.label} ${numInput.required ? '<span style="color: var(--color-danger);">*</span>' : ''}`;
      }
      numInput.placeholder = config.placeholder;
      if (config.pattern) numInput.setAttribute('pattern', config.pattern);
      else numInput.removeAttribute('pattern');

      const val = numInput.value;
      if (val) {
        const formatted = config.formatFn(val);
        numInput.value = formatted;
        validateInput(formatted, config);
      } else if (alertDiv) {
        alertDiv.textContent = '';
      }
    }

    function validateInput(val, config) {
      if (!val || !val.trim()) {
        if (alertDiv) alertDiv.textContent = '';
        return;
      }

      if (config.regex && !config.regex.test(val.trim())) {
        if (alertDiv) {
          alertDiv.style.color = 'var(--color-danger, #ef4444)';
          alertDiv.textContent = `❌ ${config.errorMessage}`;
        }
      } else {
        if (alertDiv) {
          alertDiv.style.color = 'var(--color-success, #10b981)';
          alertDiv.textContent = `✅ Valid ${config.name} format`;
        }
      }
    }

    // Auto-switch dropdown type if typed or pasted value matches specific format
    function handleAutoTypeSwitch(val) {
      if (!val || val.length < 5) return;
      const detected = SmartIntelligence.detectIDTypeFromNumber(val);
      if (detected && typeSelect.value !== detected) {
        // Find matching option in select
        for (let i = 0; i < typeSelect.options.length; i++) {
          const opt = typeSelect.options[i];
          if (opt.value.toLowerCase().includes(detected.toLowerCase()) || detected.toLowerCase().includes(opt.value.toLowerCase())) {
            typeSelect.selectedIndex = i;
            applyRules();
            break;
          }
        }
      }
    }

    typeSelect.addEventListener('change', applyRules);

    ['input', 'blur', 'keyup', 'paste'].forEach(evt => {
      numInput.addEventListener(evt, (e) => {
        handleAutoTypeSwitch(e.target.value);
        const selectedType = typeSelect.value || '';
        const config = SmartIntelligence.getIDProofConfig(selectedType);
        const formatted = config.formatFn(e.target.value);
        e.target.value = formatted;
        validateInput(formatted, config);
      });
    });

    // ── Auto-Fetch from ID Proof Document Upload ──────────────────────────
    const idProofUploadContainer = rootEl.querySelector('#mount-student-idproof, #public-idproof-mount, #mount-portal-idproof, .custom-media-mount[data-field="idProofImage"], .custom-media-mount[data-field="idproofimage"]');

    if (idProofUploadContainer) {
      const handleDocumentUpload = async (imageSrcOrFile) => {
        if (!imageSrcOrFile) return;

        if (alertDiv) {
          alertDiv.style.color = 'var(--color-primary, #6c5ce7)';
          alertDiv.textContent = '🔍 Auto-scanning uploaded ID document for details...';
        }

        const scanRes = await SmartIntelligence.scanDocumentImage(imageSrcOrFile, typeSelect.value);

        if (scanRes && scanRes.detectedNumber) {
          if (scanRes.detectedType) {
            for (let i = 0; i < typeSelect.options.length; i++) {
              const opt = typeSelect.options[i];
              if (opt.value.toLowerCase().includes(scanRes.detectedType.toLowerCase()) || scanRes.detectedType.toLowerCase().includes(opt.value.toLowerCase())) {
                typeSelect.selectedIndex = i;
                break;
              }
            }
          }

          applyRules();
          numInput.value = scanRes.detectedNumber;
          numInput.dispatchEvent(new Event('input', { bubbles: true }));
          numInput.dispatchEvent(new Event('change', { bubbles: true }));

          // Green highlight visual feedback
          numInput.style.borderColor = 'var(--color-success, #10b981)';
          numInput.style.boxShadow = '0 0 0 3px rgba(16, 185, 129, 0.25)';
          setTimeout(() => {
            numInput.style.borderColor = '';
            numInput.style.boxShadow = '';
          }, 3000);

          if (alertDiv) {
            alertDiv.style.color = 'var(--color-success, #10b981)';
            alertDiv.textContent = `✨ Auto-fetched ${scanRes.detectedType || 'ID'} (${scanRes.detectedNumber}) from document photo!`;
          }
        } else if (alertDiv && !numInput.value) {
          alertDiv.style.color = 'var(--color-text-secondary, #888)';
          alertDiv.textContent = '📑 Document attached. Enter ID proof number if not auto-detected.';
        }
      };

      // Watch file input
      const fileInput = idProofUploadContainer.querySelector('.mfp-file-input, input[type="file"]');
      if (fileInput) {
        fileInput.addEventListener('change', (e) => {
          const file = e.target.files?.[0];
          if (file) handleDocumentUpload(file);
        });
      }

      // Watch hidden value
      const hiddenInput = idProofUploadContainer.querySelector('.mfp-hidden-value, input[type="hidden"]');
      if (hiddenInput) {
        ['input', 'change'].forEach(evt => {
          hiddenInput.addEventListener(evt, (e) => {
            if (e.target.value) handleDocumentUpload(e.target.value);
          });
        });
      }
    }

    applyRules();
  }
}

export default SmartIntelligence;
