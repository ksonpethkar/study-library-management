/**
 * Generate Student ID
 */
const generateStudentId = (prefix, year, lastSerial) => {
  const nextSerial = (parseInt(lastSerial) || 0) + 1;
  return `${prefix}-${year}-${nextSerial.toString().padStart(3, '0')}`;
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
