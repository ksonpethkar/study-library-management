class FirestorePaths {
  // Base collections
  static const String libraries = 'libraries';
  static const String sections = 'sections';
  static const String seats = 'seats';
  static const String students = 'students';
  static const String plans = 'plans';
  static const String receipts = 'receipts';
  static const String requests = 'requests';
  static const String announcements = 'announcements';
  static const String holidays = 'holidays';
  static const String feedback = 'feedback';
  static const String waitingList = 'waiting_list';
  static const String expenses = 'expenses';
  static const String auditLog = 'audit_log';
  static const String recycleBin = 'recycle_bin';
  static const String users = 'users';
  static const String appConfig = 'app_config';

  // Subcollections
  static const String payments = 'payments';

  // Helper methods to get full paths
  static String libraryPath(String libraryId) => '$libraries/$libraryId';
  
  static String sectionPath(String libraryId, String sectionId) => 
      '$libraries/$libraryId/$sections/$sectionId';
      
  static String seatPath(String libraryId, String seatId) => 
      '$libraries/$libraryId/$seats/$seatId';
      
  static String studentPath(String libraryId, String studentId) => 
      '$libraries/$libraryId/$students/$studentId';
      
  static String studentPaymentPath(String libraryId, String studentId, String paymentId) => 
      '$libraries/$libraryId/$students/$studentId/$payments/$paymentId';
      
  static String planPath(String libraryId, String planId) => 
      '$libraries/$libraryId/$plans/$planId';
}
