const SystemSetting = require('../models/SystemSetting');
const Branch = require('../models/Branch');

/**
 * Generate Student ID dynamically from SystemSetting
 * Formats:
 * - prefix-year-serial: e.g. STU-2026-001
 * - prefix-serial: e.g. STU-001
 * - prefix-branch-serial: e.g. STU-MAIN-2026-001 / LIB-PUN-2026-001
 * - prefix-month-serial: e.g. STU-0826-001
 * Uses admission.serialDigits and atomically increments admission.currentSerial
 */
const generateStudentId = async (options = {}) => {
  // Backward compatibility check if called with (prefix, year, lastSerial)
  if (typeof options === 'string') {
    const prefix = options;
    const year = arguments[1] || new Date().getFullYear();
    const lastSerial = arguments[2] || 0;
    const nextSerial = (parseInt(lastSerial, 10) || 0) + 1;
    return `${prefix}-${year}-${nextSerial.toString().padStart(3, '0')}`;
  }

  try {
    const [prefixSetting, formatSetting, digitsSetting, startingSerialSetting] = await Promise.all([
      SystemSetting.getSetting('admission.idPrefix'),
      SystemSetting.getSetting('admission.idFormat'),
      SystemSetting.getSetting('admission.serialDigits'),
      SystemSetting.getSetting('admission.startingSerial')
    ]);

    const prefix = (prefixSetting || 'STU').toString().trim().toUpperCase();
    const format = formatSetting || 'prefix-year-serial';
    const digits = Math.max(1, parseInt(digitsSetting, 10) || 3);
    const startSerial = parseInt(startingSerialSetting, 10) || 1;

    // Atomically increment currentSerial
    let serialNum = startSerial;
    const currentSetting = await SystemSetting.findOne({ key: 'admission.currentSerial' });
    if (!currentSetting) {
      await SystemSetting.create({
        category: 'admission',
        key: 'admission.currentSerial',
        value: startSerial + 1,
        type: 'number',
        label: 'Student ID Current Serial',
        isEditable: true
      });
      serialNum = startSerial;
    } else {
      const updated = await SystemSetting.findOneAndUpdate(
        { key: 'admission.currentSerial' },
        { $inc: { value: 1 } },
        { new: false }
      );
      serialNum = updated && typeof updated.value === 'number' ? updated.value : startSerial;
    }

    const serialPadded = String(serialNum).padStart(digits, '0');
    const now = new Date();
    const year = now.getFullYear();
    const shortYear = String(year).slice(-2);
    const month = String(now.getMonth() + 1).padStart(2, '0');

    let branchCode = 'MAIN';
    if (options && options.branchCode) {
      branchCode = options.branchCode.toString().trim().toUpperCase();
    } else if (options && options.branch) {
      if (typeof options.branch === 'object' && options.branch.code) {
        branchCode = options.branch.code.toString().trim().toUpperCase();
      } else if (typeof options.branch === 'string' || (options.branch.toString && options.branch.toString().match(/^[0-9a-fA-F]{24}$/))) {
        try {
          const b = await Branch.findById(options.branch).lean();
          if (b && b.code) {
            branchCode = b.code.toString().trim().toUpperCase();
          }
        } catch (e) {
          // ignore lookup error
        }
      }
    }

    switch (format) {
      case 'prefix-serial':
        return `${prefix}-${serialPadded}`;
      case 'prefix-branch-serial':
        return `${prefix}-${branchCode}-${year}-${serialPadded}`;
      case 'prefix-month-serial':
        return `${prefix}-${month}${shortYear}-${serialPadded}`;
      case 'prefix-year-serial':
      default:
        return `${prefix}-${year}-${serialPadded}`;
    }
  } catch (error) {
    console.error('Error in dynamic generateStudentId:', error);
    const now = new Date();
    return `STU-${now.getFullYear()}-${Date.now().toString().slice(-4)}`;
  }
};

/**
 * Generate Receipt Number
 */
const generateReceiptNumber = (prefix, financialYear, serial) => {
  const nextSerial = (parseInt(serial) || 0) + 1;
  return `${prefix}/${financialYear}/${nextSerial.toString().padStart(3, '0')}`;
};

/**
 * Generate Seat Number
 */
const generateSeatNumber = (zone, serial) => {
  return `${zone}-${serial.toString().padStart(2, '0')}`;
};

/**
 * Get Financial Year for India (Apr-Mar)
 */
const getFinancialYear = (date = new Date()) => {
  const d = new Date(date);
  let year = d.getFullYear();
  let nextYear = year + 1;
  
  // If month is before April, it belongs to previous financial year
  if (d.getMonth() < 3) {
    year = year - 1;
    nextYear = year + 1;
  }
  
  return `${year}-${nextYear.toString().substring(2)}`;
};

module.exports = {
  generateStudentId,
  generateReceiptNumber,
  generateSeatNumber,
  getFinancialYear
};
