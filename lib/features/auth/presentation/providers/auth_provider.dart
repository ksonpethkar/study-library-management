import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/features/auth/data/repositories/auth_repository.dart';
import 'package:study_library/features/onboarding/data/repositories/library_repository.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/staff_model.dart';

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
  // Compile-time fallback only — the real value is fetched from
  // Firestore 'app_config/default' doc at runtime (see _autoResolve).
  // This constant only applies if Firestore is unreachable AND no cached ID exists.
  static const _compileFallbackId = 'aPSMq8xSAjuZQh2fTtuY';
  bool _hasLoaded = false;

  /// Public getter for other code that needs a fallback library ID.
  static String get defaultLibraryId => _compileFallbackId;

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
    } catch (_) {}

    // 2. Auto-resolve library ID from Firestore if user is logged in
    final user = ref.watch(currentUserProvider);
    if (user != null && !_hasLoaded) {
      _hasLoaded = true;
      _autoResolve(user.uid);
    }
    // Return fallback while Firestore resolves; _fetchPublicDefault also runs
    if (!_hasLoaded) {
      _hasLoaded = true;
      _fetchPublicDefault(); // load from app_config/default for unauthenticated users
    }
    return _compileFallbackId;
  }

  /// Fetches the default library ID from a public Firestore document.
  /// This allows changing the active library without rebuilding the APK.
  /// Document: app_config/default  { defaultLibraryId: "..." }
  Future<void> _fetchPublicDefault() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('default')
          .get();
      final id = doc.data()?['defaultLibraryId'] as String?;
      if (id != null && id.isNotEmpty && state == _compileFallbackId) {
        set(id);
      }
    } catch (_) {}
  }

  Future<void> _autoResolve(String uid) async {
    try {
      // 1. Check if user is a library owner
      final snapshot = await FirebaseFirestore.instance
          .collection('libraries')
          .where('ownerId', isEqualTo: uid)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final docs = snapshot.docs.toList()
          ..sort((a, b) {
            final aTime = (a.data()['updatedAt'] ?? a.data()['createdAt']) as Timestamp?;
            final bTime = (b.data()['updatedAt'] ?? b.data()['createdAt']) as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
        set(docs.first.id);
        return;
      }

      // 2. Check if user is an enrolled student
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
      }

      // 3. Fallback: try public config, then compile constant
      await _fetchPublicDefault();
      if (state == null || state!.isEmpty) {
        set(_compileFallbackId);
      }
    } catch (e) {
      if (state == null || state!.isEmpty) {
        set(_compileFallbackId);
      }
    }
  }

  void set(String libraryId) {
    _hasLoaded = true;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.setString(_prefKey, libraryId);
    } catch (_) {}
    state = libraryId;
  }

  void clear() {
    _hasLoaded = false;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.remove(_prefKey);
    } catch (_) {}
    state = _compileFallbackId;
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
        if (lib.name.isNotEmpty) prefs.setString('cached_library_name', lib.name);
        if (lib.logoUrl.isNotEmpty) prefs.setString('cached_library_logo_url', lib.logoUrl);
        if (lib.accentColor != 0) prefs.setInt('cached_library_accent_color', lib.accentColor);
        if (lib.welcomeMessage.isNotEmpty) prefs.setString('cached_library_tagline', lib.welcomeMessage);
      } catch (_) {}
    }
    return lib;
  });
});

/// Checks if the current user has a library (used during login/splash)
final userLibraryCheckProvider = FutureProvider<LibraryModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(libraryRepositoryProvider).getLibraryByOwnerId(user.uid);
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
    } catch (_) {}
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
    } catch (_) {}
    state = role;
  }

  void clear() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.remove(_prefKey);
    } catch (_) {}
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
  } catch (_) {}
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
  } catch (_) {}
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
