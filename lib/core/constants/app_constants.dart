class AppConstants {
  static const String appName = 'The Cozy Corner Study Centre';
  // Note: Use PackageInfo.fromPlatform() for runtime version display.
  // This constant is kept as a compile-time fallback only.
  static const String appVersion = '1.5.52';
  static const int buildNumber = 67;

  // Default values
  static const int minAge = 14;
  static const int maxGridRows = 50;
  static const int maxGridCols = 50;
  static const int maxPhotoSizeMB = 5;
  static const int recycleBinDays = 30;

  // Duration constants
  static const Duration splashScreenDuration = Duration(seconds: 2);
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Date formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Currency
  static const String currencySymbol = '₹';
}
