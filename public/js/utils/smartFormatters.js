/**
 * Smart Micro-Formatters for Indian standard formats & relative dates
 */
export const SmartFormatters = {
  /**
   * Auto-formats mobile numbers into Indian standard +91 XXXXX XXXXX
   * @param {string|number} val
   * @returns {string}
   */
  phone(val) {
    if (val === null || val === undefined || val === '') return '';
    const str = String(val).trim();
    const digits = str.replace(/\D/g, '');
    if (!digits) return str;

    let num = digits;
    if (num.length === 12 && num.startsWith('91')) {
      num = num.slice(2);
    } else if (num.length === 11 && num.startsWith('0')) {
      num = num.slice(1);
    }

    if (num.length === 10) {
      return `+91 ${num.slice(0, 5)} ${num.slice(5)}`;
    }

    return str;
  },

  /**
   * Auto-formats currency with Indian comma system ₹1,500
   * @param {number|string} val
   * @returns {string}
   */
  currency(val) {
    if (val === null || val === undefined || val === '') return '₹0';
    const num = Number(val);
    if (isNaN(num)) return '₹0';

    const isNegative = num < 0;
    const absNum = Math.abs(num);
    const formatted = Math.round(absNum).toLocaleString('en-IN');
    return isNegative ? `-₹${formatted}` : `₹${formatted}`;
  },

  /**
   * Formats Aadhaar number into 4-digit blocks (1234 5678 9012)
   * @param {string|number} val
   * @returns {string}
   */
  aadhaar(val) {
    if (val === null || val === undefined || val === '') return '';
    const digits = String(val).replace(/\D/g, '');
    if (!digits) return String(val).trim();

    const chunks = digits.match(/.{1,4}/g);
    return chunks ? chunks.join(' ') : digits;
  },

  /**
   * Returns human-readable relative time string ("15 mins ago", "Yesterday", "In 2 days")
   * @param {Date|string|number} date
   * @returns {string}
   */
  timeAgo(date) {
    if (!date) return '-';
    const d = new Date(date);
    if (isNaN(d.getTime())) return '-';

    const now = Date.now();
    const diffMs = now - d.getTime();
    const diffSec = Math.floor(diffMs / 1000);
    const absSec = Math.abs(diffSec);

    if (diffSec >= 0) {
      // Past dates
      if (diffSec < 45) return 'Just now';
      if (diffSec < 90) return '1 min ago';
      const mins = Math.floor(diffSec / 60);
      if (diffSec < 3600) return `${mins} mins ago`;

      const hours = Math.floor(diffSec / 3600);
      if (hours === 1) return '1 hour ago';
      if (diffSec < 86400) return `${hours} hours ago`;

      const days = Math.floor(diffSec / 86400);
      if (days === 1) return 'Yesterday';
      if (diffSec < 2592000) return `${days} days ago`;

      const months = Math.floor(diffSec / 2592000);
      if (months === 1) return '1 month ago';
      if (diffSec < 31536000) return `${months} months ago`;

      const years = Math.floor(diffSec / 31536000);
      return years === 1 ? '1 year ago' : `${years} years ago`;
    } else {
      // Future dates
      if (absSec < 45) return 'In a few seconds';
      if (absSec < 90) return 'In 1 min';
      const mins = Math.floor(absSec / 60);
      if (absSec < 3600) return `In ${mins} mins`;

      const hours = Math.floor(absSec / 3600);
      if (hours === 1) return 'In 1 hour';
      if (absSec < 86400) return `In ${hours} hours`;

      const days = Math.floor(absSec / 86400);
      if (days === 1) return 'Tomorrow';
      return `In ${days} days`;
    }
  }
};

if (typeof window !== 'undefined') {
  window.SmartFormatters = SmartFormatters;
}

export default SmartFormatters;
