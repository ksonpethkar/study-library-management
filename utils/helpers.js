/**
 * Formats a date object to string based on format
 */
const formatDate = (date, format = 'DD/MM/YYYY') => {
  if (!date) return '';
  const d = new Date(date);
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();

  if (format === 'DD/MM/YYYY') return `${day}/${month}/${year}`;
  if (format === 'YYYY-MM-DD') return `${year}-${month}-${day}`;
  return d.toString();
};

/**
 * Format number to Indian Currency Format
 */
const formatCurrency = (amount) => {
  if (amount === undefined || amount === null) return '';
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 2
  }).format(amount);
};

/**
 * Generate IDs
 */
const generateId = (prefix, serial) => {
  return `${prefix}-${serial.toString().padStart(3, '0')}`;
};

/**
 * Sanitize string to remove HTML tags
 */
const sanitizeInput = (str) => {
  if (!str) return '';
  return str.replace(/<[^>]*>?/gm, '');
};

/**
 * Validate Indian Phone number
 */
const isValidPhone = (phone) => {
  const phoneRegex = /^(\+91[\-\s]?)?[0]?(91)?[6789]\d{9}$/;
  return phoneRegex.test(phone);
};

/**
 * Validate Email
 */
const isValidEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

/**
 * Calculate due date
 */
const calculateDueDate = (startDate, durationDays) => {
  const date = new Date(startDate);
  date.setDate(date.getDate() + durationDays);
  return date;
};

/**
 * Days between two dates
 */
const daysBetween = (date1, date2) => {
  const oneDay = 24 * 60 * 60 * 1000;
  const d1 = new Date(date1);
  const d2 = new Date(date2);
  return Math.round(Math.abs((d1 - d2) / oneDay));
};

module.exports = {
  formatDate,
  formatCurrency,
  generateId,
  sanitizeInput,
  isValidPhone,
  isValidEmail,
  calculateDueDate,
  daysBetween
};
