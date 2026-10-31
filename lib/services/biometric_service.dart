import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static const String _keyBiometricEnabled = 'security_biometric_enabled';
  static const String _keyPinHash = 'security_pin_hash';
  static const String _keyAutoLockMinutes = 'security_auto_lock_minutes';

  static DateTime? _lastPausedTime;
  static bool _isCurrentlyLocked = false;

  /// Check if hardware supports biometric (fingerprint/face)
  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Trigger biometric authentication prompt
  static Future<bool> authenticate({
    String reason = 'Scan fingerprint or Face ID to unlock the app',
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable' || e.code == 'PasscodeNotSet') {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static bool _verifyStoredHash(String stored, String pin) {
    if (stored.contains(':')) {
      final parts = stored.split(':');
      if (parts.length != 2) return false;
      final salt = parts[0];
      final expectedHash = parts[1];
      final inputHash = sha256.convert(utf8.encode('$salt$pin')).toString();
      return inputHash == expectedHash;
    } else {
      final inputHash = sha256.convert(utf8.encode(pin)).toString();
      return stored == inputHash;
    }
  }

  static Set<String> _extractCandidateIds({
    String? userId,
    String? authUid,
    List<String>? candidateIds,
  }) {
    final ids = <String>{};
    if (userId != null && userId.trim().isNotEmpty) ids.add(userId.trim());
    if (authUid != null && authUid.trim().isNotEmpty) ids.add(authUid.trim());
    if (candidateIds != null) {
      for (final id in candidateIds) {
        if (id.trim().isNotEmpty) ids.add(id.trim());
      }
    }
    return ids;
  }

  /// Check if user has turned on biometric toggle in settings
  static Future<bool> isBiometricEnabled({
    String? userId,
    String? authUid,
    List<String>? candidateIds,
    bool isAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (isAdmin) {
      return prefs.getBool(_keyBiometricEnabled) ?? false;
    }
    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) {
      return false;
    }
    for (final id in ids) {
      final val = prefs.getBool('security_biometric_enabled_$id');
      if (val == true) return true;
    }
    return false;
  }

  /// Set biometric toggle
  static Future<void> setBiometricEnabled(
    bool enabled, {
    String? userId,
    String? authUid,
    List<String>? candidateIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) {
      await prefs.setBool(_keyBiometricEnabled, enabled);
    } else {
      for (final id in ids) {
        await prefs.setBool('security_biometric_enabled_$id', enabled);
      }
    }
  }

  /// Check if user has set a master 4-digit PIN (with candidate ID and Firestore fallback)
  static Future<bool> hasPin({
    String? userId,
    String? authUid,
    String? libraryId,
    List<String>? candidateIds,
    bool isAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (isAdmin) {
      final hash = prefs.getString(_keyPinHash);
      if (hash != null && hash.isNotEmpty) return true;
      if (libraryId != null && libraryId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('settings')
              .doc('security')
              .get();
          final remotePinHash = doc.data()?['pinHash'] as String?;
          if (remotePinHash != null && remotePinHash.isNotEmpty) {
            await prefs.setString(_keyPinHash, remotePinHash);
            return true;
          }
        } catch (_) {}
      }
      return false;
    }

    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) {
      // STRICT SAFETY GUARD: Student with no candidate ID has no pin! Never fall back to admin PIN.
      return false;
    }

    for (final id in ids) {
      final hash = prefs.getString('security_pin_hash_$id');
      if (hash != null && hash.isNotEmpty) return true;
    }

    // Live Firestore fallback if not found in local SharedPreferences
    if (libraryId != null && libraryId.isNotEmpty) {
      try {
        for (final id in ids) {
          final doc = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(id)
              .get();
          if (doc.exists && doc.data()?['pinHash'] != null) {
            final remoteHash = doc.data()!['pinHash'] as String;
            if (remoteHash.isNotEmpty) {
              for (final cid in ids) {
                await prefs.setString('security_pin_hash_$cid', remoteHash);
              }
              return true;
            }
          }
        }

        for (final id in ids) {
          final query = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .where('userId', isEqualTo: id)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty && query.docs.first.data()['pinHash'] != null) {
            final remoteHash = query.docs.first.data()['pinHash'] as String;
            if (remoteHash.isNotEmpty) {
              final docId = query.docs.first.id;
              final allIds = {...ids, docId};
              for (final cid in allIds) {
                await prefs.setString('security_pin_hash_$cid', remoteHash);
              }
              return true;
            }
          }
        }

        // Secondary fallback: check users collection
        final currentAuthUid = authUid ?? FirebaseAuth.instance.currentUser?.uid;
        if (currentAuthUid != null && currentAuthUid.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentAuthUid).get();
          if (userDoc.exists && userDoc.data()?['pinHash'] != null) {
            final remoteHash = userDoc.data()!['pinHash'] as String;
            if (remoteHash.isNotEmpty) {
              for (final cid in ids) {
                await prefs.setString('security_pin_hash_$cid', remoteHash);
              }
              return true;
            }
          }
        }
      } catch (_) {}
    }

    return false;
  }

  /// Verify entered PIN against stored salted SHA-256 hash.
  /// Strict account isolation: Admin Master PIN ONLY verifies for admin contexts.
  /// Student Private PIN verifies across candidate IDs (docId, authUid, membershipNo)
  /// and automatically recovers from Firestore if local cache is absent or mismatched.
  /// Cross-account unlocking is strictly prohibited!
  static Future<bool> verifyPin(
    String pin, {
    String? userId,
    String? authUid,
    String? libraryId,
    List<String>? candidateIds,
    bool isAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. ADMIN LOCK: STRICTLY verify ONLY against Admin Master PIN
    if (isAdmin) {
      final masterStored = prefs.getString(_keyPinHash);
      if (masterStored != null && _verifyStoredHash(masterStored, pin)) {
        return true;
      }
      if (libraryId != null && libraryId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('settings')
              .doc('security')
              .get();
          final remotePinHash = doc.data()?['pinHash'] as String?;
          if (remotePinHash != null && _verifyStoredHash(remotePinHash, pin)) {
            await prefs.setString(_keyPinHash, remotePinHash);
            return true;
          }
        } catch (_) {}
      }
      return false; // Never permit student PINs to unlock Admin!
    }

    // 2. STUDENT LOCK: Verify against candidate identifiers in SharedPreferences and Firestore
    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) {
      return false; // Never permit unlock without identified student context!
    }

    // 2a. Check all candidate keys in SharedPreferences
    for (final id in ids) {
      final userStored = prefs.getString('security_pin_hash_$id');
      if (userStored != null && _verifyStoredHash(userStored, pin)) {
        // Synchronize all candidate keys with this valid hash
        for (final syncId in ids) {
          await prefs.setString('security_pin_hash_$syncId', userStored);
        }
        return true;
      }
    }

    // 2b. Firestore Fallback: Query live Firestore if local cache didn't match
    if (libraryId != null && libraryId.isNotEmpty) {
      try {
        String? remotePinHash;
        String? matchedDocId;

        // Try direct document ID lookup
        for (final id in ids) {
          final doc = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(id)
              .get();
          if (doc.exists && doc.data()?['pinHash'] != null) {
            remotePinHash = doc.data()!['pinHash'] as String?;
            matchedDocId = doc.id;
            break;
          }
        }

        // Try query by userId (Auth UID)
        if (remotePinHash == null) {
          for (final id in ids) {
            final query = await FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('students')
                .where('userId', isEqualTo: id)
                .limit(1)
                .get();
            if (query.docs.isNotEmpty && query.docs.first.data()['pinHash'] != null) {
              remotePinHash = query.docs.first.data()['pinHash'] as String?;
              matchedDocId = query.docs.first.id;
              break;
            }
          }
        }

        if (remotePinHash != null && _verifyStoredHash(remotePinHash, pin)) {
          // Cache verified remote hash to local SharedPreferences for all candidate IDs
          final allToCache = {...ids};
          if (matchedDocId != null) allToCache.add(matchedDocId);
          for (final cid in allToCache) {
            await prefs.setString('security_pin_hash_$cid', remotePinHash);
          }
          return true;
        }
      } catch (_) {}
    }

    return false;
  }

  /// Generate a cryptographically random 16-char hex salt.
  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Set new master 4-digit PIN with random salt (stored across candidate IDs).
  static Future<void> setPin(
    String pin, {
    String? userId,
    String? authUid,
    List<String>? candidateIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final hash = sha256.convert(utf8.encode('$salt$pin')).toString();
    final saltedHash = '$salt:$hash';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) {
      await prefs.setString(_keyPinHash, saltedHash);
      await prefs.setInt('security_pin_local_set_at_master', nowMs);
    } else {
      for (final id in ids) {
        await prefs.setString('security_pin_hash_$id', saltedHash);
        await prefs.setInt('security_pin_local_set_at_$id', nowMs);
        await prefs.setBool('security_pin_configured_$id', true);
        await prefs.remove('security_failed_attempts_student_$id');
        await prefs.remove('security_lockout_until_student_$id');
      }
    }
  }

  /// Remove PIN across candidate IDs
  static Future<void> clearPin({
    String? userId,
    String? authUid,
    List<String>? candidateIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) {
      await prefs.remove(_keyPinHash);
      await prefs.remove('security_pin_local_set_at_master');
    } else {
      for (final id in ids) {
        await prefs.remove('security_pin_hash_$id');
        await prefs.remove('security_pin_local_set_at_$id');
        await prefs.remove('security_pin_configured_$id');
        await prefs.remove('security_failed_attempts_student_$id');
        await prefs.remove('security_lockout_until_student_$id');
      }
    }
  }

  /// Sync security settings to Firestore so they survive uninstalls/reinstalls
  static Future<void> syncSecuritySettingsToFirestore(String libraryId) async {
    if (libraryId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinHash = prefs.getString(_keyPinHash);
      final bioEnabled = prefs.getBool(_keyBiometricEnabled) ?? false;
      final autoLock = prefs.getInt(_keyAutoLockMinutes) ?? 2;

      final data = <String, dynamic>{
        'autoLockMinutes': autoLock,
        'biometricEnabled': bioEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (pinHash != null && pinHash.isNotEmpty) {
        data['pinHash'] = pinHash;
      }
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('security')
          .set(data, SetOptions(merge: true));
    } catch (_) { /* intentionally silent */ }
  }

  /// Restore security settings from Firestore (called on login/app init)
  static Future<void> restoreSecuritySettingsFromFirestore(String libraryId) async {
    if (libraryId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('security')
          .get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;

      final remotePinHash = data['pinHash'] as String?;
      if (remotePinHash != null && remotePinHash.isNotEmpty) {
        await prefs.setString(_keyPinHash, remotePinHash);
      }

      if (data['biometricEnabled'] is bool) {
        await prefs.setBool(_keyBiometricEnabled, data['biometricEnabled'] as bool);
      }

      if (data['autoLockMinutes'] is int) {
        await prefs.setInt(_keyAutoLockMinutes, data['autoLockMinutes'] as int);
      }
    } catch (_) { /* intentionally silent */ }
  }

  /// Remove master PIN from Firestore
  static Future<void> clearPinFromFirestore(String libraryId) async {
    if (libraryId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('security')
          .update({'pinHash': FieldValue.delete()});
    } catch (_) { /* intentionally silent */ }
  }

  /// Is any security lock enabled (either biometric or PIN)?
  /// For students: checks all candidate IDs and live Firestore if libraryId provided.
  /// If student has no identified context or no PIN/biometric configured, returns false (never locks).
  static Future<bool> isLockEnabled({
    String? userId,
    String? authUid,
    String? libraryId,
    List<String>? candidateIds,
    bool isAdmin = false,
  }) async {
    if (isAdmin) {
      final bio = await isBiometricEnabled(isAdmin: true);
      final pin = await hasPin(isAdmin: true, libraryId: libraryId);
      return bio || pin;
    }

    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) {
      // STRICT SAFETY GUARD: A student context with no identified IDs must NEVER lock!
      // (Prevents accidentally checking Admin's master PIN key for students!)
      return false;
    }

    final bio = await isBiometricEnabled(userId: userId, authUid: authUid, candidateIds: candidateIds);
    final pin = await hasPin(userId: userId, authUid: authUid, libraryId: libraryId, candidateIds: candidateIds);
    return bio || pin;
  }

  /// Sync student's personal PIN and biometric status directly to their Firestore student document
  /// and local SharedPreferences under both studentDocId and authUid.
  static Future<void> syncStudentSecurityToFirestore({
    required String libraryId,
    required String studentId,
    required String pin,
    String? authUid,
    List<String>? candidateIds,
    bool biometricEnabled = false,
  }) async {
    if (libraryId.isEmpty || studentId.isEmpty) return;
    try {
      final salt = _generateSalt();
      final hash = sha256.convert(utf8.encode('$salt$pin')).toString();
      final saltedHash = '$salt:$hash';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final prefs = await SharedPreferences.getInstance();
      final ids = _extractCandidateIds(userId: studentId, authUid: authUid, candidateIds: candidateIds);

      for (final id in ids) {
        await prefs.setString('security_pin_hash_$id', saltedHash);
        await prefs.setInt('security_pin_local_set_at_$id', nowMs);
        await prefs.setBool('security_pin_configured_$id', true);
        await prefs.setBool('security_biometric_enabled_$id', biometricEnabled);
        await prefs.remove('security_failed_attempts_student_$id');
        await prefs.remove('security_lockout_until_student_$id');
      }

      final currentAuthUid = authUid ?? FirebaseAuth.instance.currentUser?.uid;
      final payload = <String, dynamic>{
        'pinHash': saltedHash,
        'biometricEnabled': biometricEnabled,
        'pinUpdatedAt': FieldValue.serverTimestamp(),
        'pinResetByAdmin': false,
        'pinResetMessage': '',
      };
      if (currentAuthUid != null && currentAuthUid.isNotEmpty) {
        payload['userId'] = currentAuthUid;
      }

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(studentId)
          .update(payload)
          .catchError((e) {
            // Log for debugging
            debugPrint('[BiometricService] Firestore student pin update error: $e');
          });

      if (currentAuthUid != null && currentAuthUid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(currentAuthUid).set({
          'pinHash': saltedHash,
          'biometricEnabled': biometricEnabled,
          'pinUpdatedAt': FieldValue.serverTimestamp(),
          'pinResetByAdmin': false,
        }, SetOptions(merge: true)).catchError((_) {});
      }
    } catch (e) {
      debugPrint('[BiometricService] syncStudentSecurityToFirestore error: $e');
    }
  }

  /// Restore student's personal PIN and biometric status from Firestore on login or security check.
  /// Protects local PIN: Never wipes local PIN unless admin explicitly reset it strictly AFTER the student set it!
  static Future<void> restoreStudentSecurityFromFirestore({
    required String libraryId,
    required String studentId,
    String? authUid,
    List<String>? candidateIds,
  }) async {
    if (libraryId.isEmpty || studentId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _extractCandidateIds(userId: studentId, authUid: authUid, candidateIds: candidateIds);

      // Check if this device already has an active, locally configured PIN
      String? localHash;
      int localSetAt = 0;
      for (final id in ids) {
        final h = prefs.getString('security_pin_hash_$id');
        if (h != null && h.isNotEmpty) {
          localHash = h;
          final setAt = prefs.getInt('security_pin_local_set_at_$id') ?? 0;
          if (setAt > localSetAt) localSetAt = setAt;
        }
      }

      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(studentId)
          .get();

      if (!doc.exists) {
        // Doc not found or offline: keep local PIN intact!
        return;
      }
      final data = doc.data();
      if (data == null) return;

      final serverPinHash = data['pinHash'] as String?;
      final bioEnabled = data['biometricEnabled'] == true;
      final pinResetByAdmin = data['pinResetByAdmin'] == true;
      final serverResetAtTs = data['pinResetAt'] as Timestamp?;
      final serverResetAtMs = serverResetAtTs?.millisecondsSinceEpoch ?? 0;

      // ── Case 1: Server has an active pinHash ──
      if (serverPinHash != null && serverPinHash.isNotEmpty) {
        for (final id in ids) {
          await prefs.setString('security_pin_hash_$id', serverPinHash);
          await prefs.setBool('security_biometric_enabled_$id', bioEnabled);
        }
        return;
      }

      // ── Case 2: Server lacks pinHash, BUT local device has a configured PIN ──
      if (localHash != null && localHash.isNotEmpty) {
        // ONLY clear local PIN if an admin reset was issued strictly AFTER local PIN was set
        if (pinResetByAdmin && serverResetAtMs > localSetAt && localSetAt > 0) {
          for (final id in ids) {
            await prefs.remove('security_pin_hash_$id');
            await prefs.remove('security_pin_local_set_at_$id');
            await prefs.remove('security_pin_configured_$id');
            await prefs.setBool('security_biometric_enabled_$id', false);
            await prefs.remove('security_failed_attempts_student_$id');
            await prefs.remove('security_lockout_until_student_$id');
          }
          return;
        }

        // Local PIN is current and valid! Self-heal Firestore doc & user doc!
        final currentAuthUid = authUid ?? FirebaseAuth.instance.currentUser?.uid;
        final healPayload = <String, dynamic>{
          'pinHash': localHash,
          'biometricEnabled': bioEnabled,
          'pinUpdatedAt': FieldValue.serverTimestamp(),
          'pinResetByAdmin': false,
          'pinResetMessage': '',
        };
        if (currentAuthUid != null && currentAuthUid.isNotEmpty) {
          healPayload['userId'] = currentAuthUid;
        }
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .doc(studentId)
            .update(healPayload)
            .catchError((_) {});

        if (currentAuthUid != null && currentAuthUid.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(currentAuthUid).set({
            'pinHash': localHash,
            'biometricEnabled': bioEnabled,
            'pinUpdatedAt': FieldValue.serverTimestamp(),
            'pinResetByAdmin': false,
          }, SetOptions(merge: true)).catchError((_) {});
        }
        return;
      }

      // ── Case 3: No local PIN, and pinResetByAdmin is set on server ──
      if (pinResetByAdmin) {
        for (final id in ids) {
          await prefs.remove('security_pin_hash_$id');
          await prefs.remove('security_pin_local_set_at_$id');
          await prefs.remove('security_pin_configured_$id');
          await prefs.setBool('security_biometric_enabled_$id', false);
          await prefs.remove('security_failed_attempts_student_$id');
          await prefs.remove('security_lockout_until_student_$id');
        }
        return;
      }

      // ── Case 4: Secondary fallback to users/{uid} ──
      final currentAuthUid = authUid ?? FirebaseAuth.instance.currentUser?.uid;
      if (currentAuthUid != null && currentAuthUid.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentAuthUid).get();
          if (userDoc.exists) {
            final userPinHash = userDoc.data()?['pinHash'] as String?;
            final userBio = userDoc.data()?['biometricEnabled'] == true;
            if (userPinHash != null && userPinHash.isNotEmpty) {
              for (final id in ids) {
                await prefs.setString('security_pin_hash_$id', userPinHash);
                await prefs.setBool('security_biometric_enabled_$id', userBio);
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) { /* intentionally silent */ }
  }

  /// ONLY Library Admin can administratively reset a student's PIN & clear lock!
  static Future<void> adminResetStudentPin({
    required String libraryId,
    required String studentId,
    String? authUid,
    List<String>? candidateIds,
  }) async {
    if (libraryId.isEmpty || studentId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _extractCandidateIds(userId: studentId, authUid: authUid, candidateIds: candidateIds);

      for (final id in ids) {
        await prefs.remove('security_pin_hash_$id');
        await prefs.remove('security_pin_local_set_at_$id');
        await prefs.remove('security_pin_configured_$id');
        await prefs.remove('security_biometric_enabled_$id');
        await prefs.remove('security_failed_attempts_student_$id');
        await prefs.remove('security_lockout_until_student_$id');
      }

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(studentId)
          .update({
        'pinHash': FieldValue.delete(),
        'biometricEnabled': false,
        'pinResetAt': FieldValue.serverTimestamp(),
        'pinResetByAdmin': true,
        'pinResetMessage': 'Your security PIN was reset by your library admin.',
      });
    } catch (_) { /* intentionally silent */ }
  }

  /// Clears the admin PIN reset notification flag once the student dismisses it or configures a new PIN
  static Future<void> clearAdminPinResetFlag({
    required String libraryId,
    required String studentId,
  }) async {
    if (libraryId.isEmpty || studentId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(studentId)
          .update({
        'pinResetByAdmin': FieldValue.delete(),
        'pinResetMessage': FieldValue.delete(),
      });
    } catch (_) { /* intentionally silent */ }
  }

  /// Auto-lock timeout in minutes (default 2 mins)
  static Future<int> getAutoLockTimeoutMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAutoLockMinutes) ?? 2;
  }

  static Future<void> setAutoLockTimeoutMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoLockMinutes, minutes);
  }

  /// Called when app goes into background
  static void onAppPaused() {
    _lastPausedTime = DateTime.now();
  }

  /// Called when app resumes: returns true if app should navigate to lock screen
  static Future<bool> shouldLockOnResume({
    String? userId,
    String? authUid,
    String? libraryId,
    List<String>? candidateIds,
    bool isAdmin = false,
  }) async {
    if (_isCurrentlyLocked) return false;
    final enabled = await isLockEnabled(
      userId: userId,
      authUid: authUid,
      libraryId: libraryId,
      candidateIds: candidateIds,
      isAdmin: isAdmin,
    );
    if (!enabled) return false;

    if (_lastPausedTime == null) return false;

    final timeoutMinutes = await getAutoLockTimeoutMinutes();
    final difference = DateTime.now().difference(_lastPausedTime!);

    if (difference.inMinutes >= timeoutMinutes) {
      _isCurrentlyLocked = true;
      return true;
    }
    return false;
  }

  /// Marks app as unlocked
  static void markUnlocked() {
    _lastPausedTime = null;
    _isCurrentlyLocked = false;
  }

  // ── Rate Limiting (5 failed attempts -> 15 min cooldown) ───────────────────
  // Strictly isolated: Student lockouts never block Admin, and Admin lockouts never block Students!
  static const String _keyFailedAttempts = 'security_failed_attempts';
  static const String _keyLockoutUntil = 'security_lockout_until';
  static const int maxFailedAttempts = 5;
  static const int lockoutMinutes = 15;

  /// Get current number of consecutive failed attempts (strictly isolated per user/role)
  static Future<int> getFailedAttempts({
    String? userId,
    String? authUid,
    List<String>? candidateIds,
    bool isAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (isAdmin) {
      return prefs.getInt('security_failed_attempts_admin') ?? 0;
    }
    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) return 0;
    int maxAttempts = 0;
    for (final id in ids) {
      final a = prefs.getInt('security_failed_attempts_student_$id') ?? 0;
      if (a > maxAttempts) maxAttempts = a;
    }
    return maxAttempts;
  }

  /// Check if the user is currently in a 15-minute lockout (strictly isolated per user/role)
  static Future<DateTime?> getLockoutUntil({
    String? userId,
    String? authUid,
    List<String>? candidateIds,
    bool isAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (isAdmin) {
      final raw = prefs.getString('security_lockout_until_admin');
      if (raw == null) return null;
      final dt = DateTime.tryParse(raw);
      if (dt == null) return null;
      if (DateTime.now().isAfter(dt)) {
        // Cooldown expired — reset cleanly
        await resetFailedAttempts(isAdmin: true);
        return null;
      }
      return dt;
    }

    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) return null;

    for (final id in ids) {
      final raw = prefs.getString('security_lockout_until_student_$id');
      if (raw != null) {
        final dt = DateTime.tryParse(raw);
        if (dt != null) {
          if (DateTime.now().isAfter(dt)) {
            // Cooldown expired — reset cleanly
            await resetFailedAttempts(
              userId: userId,
              authUid: authUid,
              candidateIds: candidateIds,
              isAdmin: false,
            );
            return null;
          }
          return dt;
        }
      }
    }
    return null;
  }

  /// Record a failed PIN or biometric attempt (strictly isolated per user/role).
  /// Returns the lockout expiry if locked out, or null if attempts remain.
  static Future<DateTime?> recordFailedAttempt({
    String? userId,
    String? authUid,
    List<String>? candidateIds,
    bool isAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (isAdmin) {
      int attempts = (prefs.getInt('security_failed_attempts_admin') ?? 0) + 1;
      await prefs.setInt('security_failed_attempts_admin', attempts);
      if (attempts >= maxFailedAttempts) {
        final lockoutUntil = DateTime.now().add(const Duration(minutes: lockoutMinutes));
        await prefs.setString('security_lockout_until_admin', lockoutUntil.toIso8601String());
        return lockoutUntil;
      }
      return null;
    }

    final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
    if (ids.isEmpty) return null;

    int maxAttempts = 0;
    for (final id in ids) {
      final cur = (prefs.getInt('security_failed_attempts_student_$id') ?? 0) + 1;
      if (cur > maxAttempts) maxAttempts = cur;
    }

    for (final id in ids) {
      await prefs.setInt('security_failed_attempts_student_$id', maxAttempts);
    }

    if (maxAttempts >= maxFailedAttempts) {
      final lockoutUntil = DateTime.now().add(const Duration(minutes: lockoutMinutes));
      for (final id in ids) {
        await prefs.setString('security_lockout_until_student_$id', lockoutUntil.toIso8601String());
      }
      return lockoutUntil;
    }
    return null;
  }

  /// Reset failed attempts and clear lockout on successful authentication (strictly isolated per user/role)
  static Future<void> resetFailedAttempts({
    String? userId,
    String? authUid,
    List<String>? candidateIds,
    bool isAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (isAdmin) {
      await prefs.remove('security_failed_attempts_admin');
      await prefs.remove('security_lockout_until_admin');
    } else {
      final ids = _extractCandidateIds(userId: userId, authUid: authUid, candidateIds: candidateIds);
      for (final id in ids) {
        await prefs.remove('security_failed_attempts_student_$id');
        await prefs.remove('security_lockout_until_student_$id');
      }
    }
    // Also clean up any legacy global keys
    await prefs.remove(_keyFailedAttempts);
    await prefs.remove(_keyLockoutUntil);
  }

  /// Emergency/Self-Service Lockout Clear for authenticated student session
  static Future<void> clearStudentLockout({
    String? userId,
    String? authUid,
    List<String>? candidateIds,
  }) async {
    await resetFailedAttempts(
      userId: userId,
      authUid: authUid,
      candidateIds: candidateIds,
      isAdmin: false,
    );
  }
}
