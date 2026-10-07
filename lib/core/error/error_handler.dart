import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'app_exception.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// Note: Add firebase_crashlytics import and logger package as needed

class ErrorHandler {
  ErrorHandler._();

  static String handleError(dynamic error, [StackTrace? stack]) {
    String userMessage = "Something went wrong. Please try again.";

    if (error is AppException) {
      userMessage = error.userMessage;
    } else if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          userMessage = "You don't have permission to perform this action.";
          break;
        case 'not-found':
          userMessage = "The item you're looking for doesn't exist or has been removed.";
          break;
        case 'unavailable':
          userMessage = "Our servers are temporarily unavailable. Please try again.";
          break;
        case 'unauthenticated':
          userMessage = "Your session has ended. Please sign in again.";
          break;
        case 'resource-exhausted':
          userMessage = "The app is experiencing high traffic. Please try later.";
          break;
        default:
          userMessage = "A network error occurred. Please try again.";
      }
    } else if (error is Exception) {
      userMessage = error.toString().replaceFirst('Exception: ', '');
    }

    // Log the error
    if (kDebugMode) {
      print('Error: $error');
      if (stack != null) {
        print('Stack: $stack');
      }
    } else {
      FirebaseCrashlytics.instance.recordError(error, stack, reason: 'ErrorHandler handled exception', fatal: false);
    }

    return userMessage;
  }
}
