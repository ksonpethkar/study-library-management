import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, defaultTargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:study_library/services/badge_service.dart';
import 'package:study_library/services/expiry_scheduler_service.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  bool _googleSignInInitialized = false;

  AuthRepository({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? getCurrentUser() => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    try {
      final UserCredential cred;
      if (kIsWeb) {
        // Web: Use Firebase Auth popup directly
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        cred = await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile: Use google_sign_in v7 native flow
        cred = await _nativeGoogleSignIn();
      }

      // Log event to Firestore login_history
      if (cred.user != null) {
        logSignInEvent(cred.user!);
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      if (e.toString().contains('cancel') || e.toString().contains('popup-closed')) {
        throw Exception('Sign in was cancelled. Tap the button whenever you\'re ready.');
      }
      throw Exception('We couldn\'t sign you in right now. Please try again.');
    }
  }

  /// Records an authentication event in users/{userId}/login_history
  Future<void> logSignInEvent(User user) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('login_history')
          .doc();
      await docRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'platform': defaultTargetPlatform.name,
        'authMethod': 'Google Sign-In',
      });
    } catch (e) {
      debugPrint('Login history log error: $e');
    }
  }

  /// Streams recent login events for a user
  Stream<QuerySnapshot<Map<String, dynamic>>> streamLoginHistory(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('login_history')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> warmUpGoogleSignIn() async {
    if (!kIsWeb && !_googleSignInInitialized) {
      try {
        await GoogleSignIn.instance.initialize();
        _googleSignInInitialized = true;
      } catch (e) {
        debugPrint('GoogleSignIn warm-up: $e');
      }
    }
  }

  Future<UserCredential> _nativeGoogleSignIn() async {
    // Initialize GoogleSignIn once
    if (!_googleSignInInitialized) {
      try {
        await GoogleSignIn.instance.initialize();
      } catch (_) {}
      _googleSignInInitialized = true;
    }

    // Trigger native sign-in
    final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();

    // Get the idToken from authentication
    final idToken = account.authentication.idToken;

    // Create Firebase credential with idToken
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    // Sign in to Firebase
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    try {
      await ExpirySchedulerService.cancelExpiryReminders();
      await BadgeService.clearBadge();
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await _auth.signOut();
    } catch (e) {
      throw Exception('We couldn\'t sign you out. Please try again.');
    }
  }

  Future<void> signOutFromAllDevices() async {
    await signOut();
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Please check your internet connection and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. Try a different Google account.';
      case 'popup-closed-by-user':
        return 'Sign in was cancelled. Tap the button whenever you\'re ready.';
      case 'cancelled-popup-request':
        return 'Sign in was cancelled. Tap the button whenever you\'re ready.';
      default:
        return 'We couldn\'t sign you in right now. Please try again.';
    }
  }
}
