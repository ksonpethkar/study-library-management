abstract class AppException implements Exception {
  final String userMessage;
  final String? originalError;

  AppException(this.userMessage, [this.originalError]);

  @override
  String toString() => userMessage;
}

class NetworkException extends AppException {
  NetworkException([String? originalError])
      : super("Please check your internet connection and try again.", originalError);
}

class AuthException extends AppException {
  AuthException([String? originalError])
      : super("Authentication failed. Please verify your credentials and try again.", originalError);
}

class ValidationException extends AppException {
  ValidationException(super.message, [super.originalError]);
}

class StorageException extends AppException {
  StorageException([String? originalError])
      : super("Failed to save or retrieve data from storage. Ensure you have granted storage permissions.", originalError);
}

class DataException extends AppException {
  DataException([String? originalError])
      : super("Failed to process data. The data might be corrupted or in an invalid format.", originalError);
}
