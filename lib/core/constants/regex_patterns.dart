class RegexPatterns {
  // Indian phone (10 digits, starts 6-9)
  static const String phone = r'^[6-9]\d{9}$';
  
  // Email (RFC 5322 simplified)
  static const String email = r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  
  // Aadhaar (12 digits with or without spaces)
  static const String aadhaar = r'^\d{4}\s?\d{4}\s?\d{4}$';
  
  // PAN (XXXXX0000X)
  static const String pan = r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$';
  
  // Driving Licence (state-wise format, eg. MH1220110000000)
  static const String drivingLicence = r'^[A-Z]{2}[0-9]{2}\s?[0-9]{11}$';
  
  // Pincode (6 digits, valid range in India)
  static const String pincode = r'^[1-9][0-9]{5}$';
  
  // Name (letters and spaces, 2-100)
  static const String name = r'^[a-zA-Z\s]{2,100}$';
  
  // Amount (positive, max 2 decimals)
  static const String amount = r'^\d+(\.\d{1,2})?$';
}
