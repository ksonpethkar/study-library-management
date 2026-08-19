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
}

export default SmartIntelligence;
