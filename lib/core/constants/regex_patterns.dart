class RegexPatterns {
  // Indian phone (10 digits, starts 6-9)
  static const String phone = r'^[6-9]\d{9}$';
  
  // Email (RFC 5322 compliant simplified)
  static const String email = r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  
  // Aadhaar (12 digits with or without spaces)
  static const String aadhaar = r'^\d{4}\s?\d{4}\s?\d{4}$';
  
  // PAN (XXXXX0000X: 5 letters, 4 numbers, 1 letter)
  static const String pan = r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$';
  
  // Driving Licence — supports both with and without hyphens/spaces:
  // e.g. MH1220210001234 | MH12 20210001234 | MH-12-20210001234
  static const String drivingLicence = r'^[A-Z]{2}[\s\-]?[0-9]{2}[\s\-]?[0-9A-Z]{11,12}$';

  // Voter ID / EPIC (3 uppercase letters + 7 digits)
  static const String voterId = r'^[A-Z]{3}[0-9]{7}$';

  // Indian Passport (1 uppercase letter + 7 digits)
  static const String passport = r'^[A-Z][0-9]{7}$';

  // College / Student ID (Roll No / Enrollment No)
  static const String collegeId = r'^[A-Za-z0-9/\-]{2,30}$';
  
  // Pincode (6 digits, valid range in India: 100000 to 999999)
  static const String pincode = r'^[1-9][0-9]{5}$';
  
  // Name (Unicode letters and marks across all scripts, spaces, dots, hyphens, and apostrophes; 2 to 100 chars)
  static const String name = r"^[\p{L}\p{M}\s\.\-']{2,100}$";
  
  // Amount (positive, max 2 decimals)
  static const String amount = r'^\d+(\.\d{1,2})?$';

  // Indian GSTIN (15 characters: 2 state digits + 10 PAN + 1 entity + 1 'Z' + 1 checksum)
  static const String gstin = r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$';

  // UPI Virtual Payment Address (VPA) / UPI ID (e.g. library@oksbi, payment@upi)
  static const String upiId = r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$';

  // Bank UTR / UPI Transaction Reference (6-35 alphanumeric chars)
  static const String utr = r'^[a-zA-Z0-9_\-]{6,35}$';

  // Indian Bank Cheque Number (exactly 6 numeric digits)
  static const String cheque = r'^\d{6}$';

  // Blood Group (A+, A-, B+, B-, AB+, AB-, O+, O-)
  static const String bloodGroup = r'^(A|B|AB|O)[+-]$';

  // Seat Label (e.g. S-1, 101, A12, CAB-5)
  static const String seatLabel = r'^[A-Za-z0-9\-_]{1,10}$';

  // Web URL (http/https)
  static const String url = r'^https?:\/\/[a-zA-Z0-9\-._~:/?#\[\]@!$&()*+,;=]+$';
}
