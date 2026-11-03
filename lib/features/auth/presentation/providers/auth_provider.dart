import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/utils/web_favicon_helper.dart';
import 'package:study_library/features/auth/data/repositories/auth_repository.dart';
import 'package:study_library/features/onboarding/data/repositories/library_repository.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/staff_model.dart';
import 'package:study_library/services/remote_config_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

// Auth providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// Library providers
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});

/// Stores the current library ID for the logged-in admin.
/// Persisted to SharedPreferences so it survives app restarts.
class CurrentLibraryNotifier extends Notifier<String?> {
  static const _prefKey = 'cached_current_library_id';
  bool _hasLoaded = false;

  /// Dynamically resolves the default library ID from Remote Config or public Firestore config.
  /// No unchangeable hardcoded ID is baked in (S1 Fix).
  static String get defaultLibraryId => RemoteConfigService.defaultLibraryId;

  @override
  String? build() {
    // 1. Synchronously load from local cache first
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final cachedId = prefs.getString(_prefKey);
      if (cachedId != null && cachedId.isNotEmpty) {
        _hasLoaded = true;
        return cachedId;
      }
    } catch (_) { /* intentionally silent */ }

    // 2. If user is logged in, auto-resolve their actual library asynchronously
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      if (!_hasLoaded) {
        _hasLoaded = true;
        _autoResolve(user.uid);
      }
      // S3 FIX: Return null while resolving so downstream providers never query the wrong library during load
      return null;
    }

    // 3. For unauthenticated users (e.g. login/onboarding), resolve public default library
    if (!_hasLoaded) {
      _hasLoaded = true;
      _fetchPublicDefault();
    }
    return defaultLibraryId;
  }

  /// Fetches the default library ID from a public Firestore document or Remote Config.
  /// This allows changing the active library without rebuilding the APK.
  /// Document: app_config/default  { defaultLibraryId: "..." }
  Future<void> _fetchPublicDefault() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('default')
          .get();
      final id = doc.data()?['defaultLibraryId'] as String?;
      if (id != null && id.isNotEmpty && (state == null || state == defaultLibraryId)) {
        set(id);
      }
    } catch (_) { /* intentionally silent */ }
  }

  Future<void> _autoResolve(String uid) async {
    try {
      // 1. Check if user is an enrolled student first (Student Precedence)
      final studentDocs = await FirebaseFirestore.instance
          .collectionGroup('students')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      if (studentDocs.docs.isNotEmpty) {
        final doc = studentDocs.docs.first;
        final libId = doc.reference.parent.parent?.id;
        if (libId != null && libId.isNotEmpty) {
          set(libId);
          return;
        }
        set(defaultLibraryId);
        return;
      }

      // 2. Check if user is the official owner of the default library
      final officialLib = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(defaultLibraryId)
          .get();
      if (officialLib.exists && officialLib.data()?['ownerId'] == uid) {
        set(defaultLibraryId);
        return;
      }

      // 3. Fallback: try public config, then Remote Config default
      await _fetchPublicDefault();
      if (state == null || state!.isEmpty) {
        set(defaultLibraryId);
      }
    } catch (e) {
      if (state == null || state!.isEmpty) {
        set(defaultLibraryId);
      }
    }
  }

  void set(String libraryId) {
    _hasLoaded = true;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.setString(_prefKey, libraryId);
    } catch (_) { /* intentionally silent */ }
    state = libraryId;
  }

  void clear() {
    _hasLoaded = false;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.remove(_prefKey);
    } catch (_) { /* intentionally silent */ }
    state = null; // S3 & Session Security: Don't revert to old library on sign out
  }
}

final currentLibraryIdProvider =
    NotifierProvider<CurrentLibraryNotifier, String?>(CurrentLibraryNotifier.new);

/// Streams the current library data and automatically caches branding for instant splash loading
final currentLibraryProvider = StreamProvider<LibraryModel?>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null) return Stream.value(null);
  return ref.watch(libraryRepositoryProvider).streamLibrary(libraryId).map((lib) {
    if (lib != null) {
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        if (lib.name.isNotEmpty) {
          prefs.setString('cached_library_name', lib.name);
          setWebTabBranding(
            logoUrl: lib.logoUrl.isNotEmpty ? lib.logoUrl : null,
            title: lib.name,
          );
        }
        if (lib.logoUrl.isNotEmpty) {
          prefs.setString('cached_library_logo_url', lib.logoUrl);
        }
        if (lib.accentColor != 0) prefs.setInt('cached_library_accent_color', lib.accentColor);
        if (lib.welcomeMessage.isNotEmpty) prefs.setString('cached_library_tagline', lib.welcomeMessage);
      } catch (_) { /* intentionally silent */ }
    }
    return lib;
  });
});

/// Checks if the current user has a library (used during login/splash)
final userLibraryCheckProvider = FutureProvider<LibraryModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final lib = await ref.read(libraryRepositoryProvider).getLibraryByOwnerId(user.uid);
  if (lib != null && lib.id == CurrentLibraryNotifier.defaultLibraryId) {
    return lib;
  }
  return null;
});

// ── Role-based access control ─────────────────────────────────────────────────

enum AppUserRole { admin, student, none }

/// Stores the role of the currently signed-in user.
/// Persisted to SharedPreferences so it survives app restarts.
class UserRoleNotifier extends Notifier<AppUserRole> {
  static const _prefKey = 'cached_current_user_role';

  @override
  AppUserRole build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final cachedRole = prefs.getString(_prefKey);
      if (cachedRole == 'admin') return AppUserRole.admin;
      if (cachedRole == 'student') return AppUserRole.student;
    } catch (_) { /* intentionally silent */ }
    return AppUserRole.none;
  }

  void setRole(AppUserRole role) {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (role == AppUserRole.none) {
        prefs.remove(_prefKey);
      } else {
        prefs.setString(_prefKey, role.name);
      }
    } catch (_) { /* intentionally silent */ }
    state = role;
  }

  void clear() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.remove(_prefKey);
    } catch (_) { /* intentionally silent */ }
    state = AppUserRole.none;
  }
}

final userRoleProvider =
    NotifierProvider<UserRoleNotifier, AppUserRole>(UserRoleNotifier.new);

/// Persists the resolved role to SharedPreferences AND Firestore so it survives restarts.
Future<void> persistUserRole({
  required String uid,
  required String email,
  required String displayName,
  required AppUserRole role,
  required String libraryId,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('persisted_role', role.name);
    await prefs.setString('persisted_uid', uid);
    await prefs.setString('persisted_library_id', libraryId);
    await prefs.setString('cached_current_library_id', libraryId);
    await prefs.setString('cached_current_user_role', role.name); // fixed: was 'user_role' (orphan key)

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': role.name, // 'admin' | 'student' | 'none'
      'libraryId': libraryId,
      'email': email,
      'displayName': displayName,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (_) { /* intentionally silent */ }
}

/// Reads a previously persisted role from SharedPreferences first (instant), then Firestore.
Future<Map<String, dynamic>?> readPersistedUserRole(String uid) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cachedUid = prefs.getString('persisted_uid');
    final cachedRole = prefs.getString('persisted_role');
    final cachedLibId = prefs.getString('persisted_library_id');

    if (cachedUid == uid && cachedRole != null && cachedRole.isNotEmpty) {
      return {
        'role': cachedRole,
        'libraryId': cachedLibId ?? CurrentLibraryNotifier.defaultLibraryId,
      };
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['role'] != null) {
        await prefs.setString('persisted_role', data['role']);
        await prefs.setString('persisted_uid', uid);
        if (data['libraryId'] != null) {
          await prefs.setString('persisted_library_id', data['libraryId']);
          await prefs.setString('cached_current_library_id', data['libraryId']);
        }
      }
      return data;
    }
  } catch (_) { /* intentionally silent */ }
  return null;
}

// ── Staff permission provider ─────────────────────────────────────────────────
/// Streams the StaffModel for the currently signed-in staff member.
/// Returns null if the user is the library owner (owner has all permissions)
/// or is not a staff member.
final currentStaffProvider = StreamProvider<StaffModel?>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  final user = ref.watch(currentUserProvider);
  if (libraryId == null || user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('staff')
      .doc(user.uid)
      .snapshots()
      .map((snap) {
    if (!snap.exists) return null;
    return StaffModel.fromJson({...snap.data()!, 'id': snap.id});
  });
});

/// Quick permission check helper.
/// Usage: ref.read(canDoProvider('canRecordPayments'))
/// Returns true for owner (role == admin who owns the library) always.
/// For staff, checks the specific permission flag.
final staffPermProvider = Provider.family<bool, String>((ref, permission) {
  final role = ref.watch(userRoleProvider);
  // Library owner always has all permissions
  if (role == AppUserRole.admin) {
    final staff = ref.watch(currentStaffProvider).value;
    // If no staff doc exists → this is the owner → full access
    if (staff == null) return true;
    // If staff doc exists → check specific flag
    switch (permission) {
      case 'canManageSeats':
        return staff.canManageSeats;
      case 'canRecordPayments':
        return staff.canRecordPayments;
      case 'canManageStudents':
        return staff.canManageStudents;
      case 'canDeleteStudents':
        return staff.canDeleteStudents;
      case 'canViewRevenue':
        return staff.canViewRevenue;
      case 'canManageSettings':
        return staff.canManageSettings;
      default:
        return false;
    }
  }
  return false; // Students never have admin permissions
});
