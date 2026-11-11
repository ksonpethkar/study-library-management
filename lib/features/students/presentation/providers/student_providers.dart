import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/features/students/data/repositories/student_repository.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository();
});

/// Stream all students for the current library
final studentsStreamProvider = StreamProvider<List<StudentModel>>((ref) {
  final repository = ref.watch(studentRepositoryProvider);
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null) return Stream.value([]);
  return repository.getStudents(libraryId);
});

/// Stream students by libraryId (family variant)
final studentsProvider = StreamProvider.family<List<StudentModel>, String>((ref, libraryId) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.getStudents(libraryId);
});

final studentCountProvider = FutureProvider.family<int, String>((ref, libraryId) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.getStudentCount(libraryId);
});

final expiringStudentsProvider = FutureProvider.family<List<StudentModel>, Map<String, dynamic>>((ref, params) {
  final repository = ref.watch(studentRepositoryProvider);
  final libraryId = params['libraryId'] as String;
  final daysAhead = params['daysAhead'] as int;
  return repository.getExpiringStudents(libraryId, daysAhead);
});

/// Stream of the current logged-in student (matched by Auth UID first, then email fallback)
/// Yields cached StudentModel instantly (<5ms) for offline access in basements / low connectivity.
final currentStudentProvider = StreamProvider<StudentModel?>((ref) async* {
  final libraryId = ref.watch(currentLibraryIdProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (libraryId == null || libraryId.isEmpty || user == null) {
    yield null;
    return;
  }

  final uid = user.uid;
  final email = user.email ?? '';
  final cacheKey = 'offline_cached_student_${libraryId}_$uid';

  // 1. Instantly yield cached student for offline & instant launch (<5ms)
  try {
    final prefs = ref.read(sharedPreferencesProvider);
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      final Map<String, dynamic> data = jsonDecode(cachedJson);
      yield StudentModel.fromJson(data);
    }
  } catch (_) { /* intentionally silent */ }

  // 2. Stream real-time updates from Firestore
  final stream = FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('students')
      .where('userId', isEqualTo: uid)
      .limit(1)
      .snapshots();

  await for (final snap in stream) {
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      final model = StudentModel.fromJson({...doc.data(), 'id': doc.id});
      // Backfill missing studentUserId on legacy receipts and payments for real-time visibility
      if (model.userId != null && model.userId!.isNotEmpty) {
        ReceiptRepository().healStudentReceiptsAndPayments(libraryId, model.id, model.userId!).ignore();
      }
      // Update cache for next offline launch
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setString(cacheKey, jsonEncode(model.toJson()));
      } catch (_) { /* intentionally silent */ }
      yield model;
    } else if (email.isNotEmpty) {
      // Fallback: match by email for admin-added students
      try {
        final emailSnap = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (emailSnap.docs.isNotEmpty) {
          final doc = emailSnap.docs.first;
          // Backfill userId for future speed
          doc.reference.update({'userId': uid}).ignore();
          final model = StudentModel.fromJson({...doc.data(), 'id': doc.id});
          if (uid.isNotEmpty) {
            ReceiptRepository().healStudentReceiptsAndPayments(libraryId, model.id, uid).ignore();
          }
          try {
            final prefs = ref.read(sharedPreferencesProvider);
            await prefs.setString(cacheKey, jsonEncode(model.toJson()));
          } catch (_) { /* intentionally silent */ }
          yield model;
        } else {
          yield null;
        }
      } catch (_) {
        // In case of offline/network failure, keep serving the cached model
      }
    } else {
      yield null;
    }
  }
});

/// Stream of a specific student by studentId
final studentDetailProvider = StreamProvider.family<StudentModel?, String>((ref, studentId) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty || studentId.isEmpty) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('students')
      .doc(studentId)
      .snapshots()
      .map((doc) {
    if (doc.exists && doc.data() != null) {
      return StudentModel.fromJson({...doc.data()!, 'id': doc.id});
    }
    return null;
  });
});

/// Real-time stream of the current student's active pending seat change request (if any)
final studentPendingSeatChangeProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    yield null;
    return;
  }

  final studentAsync = ref.watch(currentStudentProvider);
  final student = studentAsync.value;
  final curUser = FirebaseAuth.instance.currentUser;
  final curUid = curUser?.uid ?? '';
  final curEmail = curUser?.email?.toLowerCase().trim() ?? '';
  final studentId = student?.id ?? '';
  final studentUserId = student?.userId ?? '';
  final studentEmail = student?.email.toLowerCase().trim() ?? '';
  final studentPhone = student?.phone.replaceAll(RegExp(r'\D'), '') ?? '';

  final effectiveUserId = curUid.isNotEmpty
      ? curUid
      : (studentUserId.isNotEmpty ? studentUserId : studentId);

  if (effectiveUserId.isEmpty) {
    yield null;
    return;
  }

  try {
    // SEC-5 Guard: Firestore security rules enforce (resource.data.userId == uid).
    // Filtering by userId ensures the query matches the security rule without permission-denied.
    final queryStream = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('requests')
        .where('userId', isEqualTo: effectiveUserId)
        .where('type', isEqualTo: 'seat_change')
        .snapshots();

    await for (final snap in queryStream) {
      final docs = snap.docs.where((d) {
        final data = d.data();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        if (status != 'pending') return false;

        final sId = (data['studentId'] ?? '').toString();
        final sUid = (data['studentUserId'] ?? data['userId'] ?? '').toString();
        final sEmail = (data['studentEmail'] ?? '').toString().toLowerCase().trim();
        final sPhone = (data['studentPhone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

        if (studentId.isNotEmpty && sId == studentId) return true;
        if (curUid.isNotEmpty && (sUid == curUid || sId == curUid)) return true;
        if (studentUserId.isNotEmpty && (sUid == studentUserId || sId == studentUserId)) return true;
        if (curEmail.isNotEmpty && sEmail.isNotEmpty && curEmail == sEmail) return true;
        if (studentEmail.isNotEmpty && sEmail.isNotEmpty && studentEmail == sEmail) return true;
        if (studentPhone.isNotEmpty && sPhone.isNotEmpty &&
            (studentPhone == sPhone || studentPhone.endsWith(sPhone) || sPhone.endsWith(studentPhone))) {
          return true;
        }

        return false;
      }).toList();

      if (docs.isEmpty) {
        yield null;
      } else {
        docs.sort((a, b) {
          final tA = a.data()['createdAt'] as Timestamp?;
          final tB = b.data()['createdAt'] as Timestamp?;
          if (tA != null && tB != null) return tB.compareTo(tA);
          return 0;
        });
        final d = docs.first;
        yield {'id': d.id, ...d.data()};
      }
    }
  } catch (e) {
    debugPrint('studentPendingSeatChangeProvider stream error: $e');
    yield null;
  }
});

/// Real-time stream of the current student's pending plan renewal request.
/// Returns the renewal request doc if status is 'pending' or 'desk_payment_pending', null otherwise.
final studentPendingRenewalProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    yield null;
    return;
  }

  final studentAsync = ref.watch(currentStudentProvider);
  final student = studentAsync.value;
  final curUser = FirebaseAuth.instance.currentUser;
  final curUid = curUser?.uid ?? '';
  final curEmail = curUser?.email?.toLowerCase().trim() ?? '';
  final studentId = student?.id ?? '';
  final studentUserId = student?.userId ?? '';
  final studentEmail = student?.email.toLowerCase().trim() ?? '';
  final studentPhone = student?.phone.replaceAll(RegExp(r'\D'), '') ?? '';

  final effectiveUserId = curUid.isNotEmpty
      ? curUid
      : (studentUserId.isNotEmpty ? studentUserId : studentId);

  if (effectiveUserId.isEmpty) {
    yield null;
    return;
  }

  try {
    // SEC-5 Guard: Firestore security rules enforce (resource.data.userId == uid).
    final queryStream = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('requests')
        .where('userId', isEqualTo: effectiveUserId)
        .where('type', isEqualTo: 'renewal')
        .snapshots();

    await for (final snap in queryStream) {
      final docs = snap.docs.where((d) {
        final data = d.data();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        if (status != 'pending' && status != 'desk_payment_pending') return false;

        final sId = (data['studentId'] ?? '').toString();
        final sUid = (data['studentUserId'] ?? data['userId'] ?? '').toString();
        final sEmail = (data['studentEmail'] ?? '').toString().toLowerCase().trim();
        final sPhone = (data['studentPhone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

        if (studentId.isNotEmpty && sId == studentId) return true;
        if (curUid.isNotEmpty && (sUid == curUid || sId == curUid)) return true;
        if (studentUserId.isNotEmpty && (sUid == studentUserId || sId == studentUserId)) return true;
        if (curEmail.isNotEmpty && sEmail.isNotEmpty && curEmail == sEmail) return true;
        if (studentEmail.isNotEmpty && sEmail.isNotEmpty && studentEmail == sEmail) return true;
        if (studentPhone.isNotEmpty && sPhone.isNotEmpty &&
            (studentPhone == sPhone || studentPhone.endsWith(sPhone) || sPhone.endsWith(studentPhone))) {
          return true;
        }

        return false;
      }).toList();

      if (docs.isEmpty) {
        yield null;
      } else {
        docs.sort((a, b) {
          final tA = a.data()['createdAt'] as Timestamp?;
          final tB = b.data()['createdAt'] as Timestamp?;
          if (tA != null && tB != null) return tB.compareTo(tA);
          return 0;
        });
        final d = docs.first;
        yield {'id': d.id, ...d.data()};
      }
    }
  } catch (e) {
    debugPrint('studentPendingRenewalProvider stream error: $e');
    yield null;
  }
});

const _pageSize = 20;

final studentPageProvider = StateNotifierProvider.autoDispose<StudentPageNotifier, StudentPageState>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  return StudentPageNotifier(libraryId ?? '');
});

class StudentPageState {
  final List<StudentModel> students;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDoc;
  
  const StudentPageState({
    this.students = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.lastDoc,
  });
  
  StudentPageState copyWith({
    List<StudentModel>? students,
    bool? isLoading,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDoc,
  }) => StudentPageState(
    students: students ?? this.students,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
    error: error,
    lastDoc: lastDoc ?? this.lastDoc,
  );
}

class StudentPageNotifier extends StateNotifier<StudentPageState> {
  final String libraryId;
  
  StudentPageNotifier(this.libraryId) : super(const StudentPageState()) {
    loadFirst();
  }

  StudentModel _safeParseDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawGovId = data['govIdNumber']?.toString() ?? '';
    final decryptedGovId = EncryptionService.safeDecryptGovId(rawGovId, libraryId);
    return StudentModel.fromJson({
      ...data,
      'id': doc.id,
      'govIdNumber': decryptedGovId,
    });
  }
  
  Future<void> loadFirst() async {
    if (libraryId.isEmpty) return;
    state = state.copyWith(isLoading: true, students: [], lastDoc: null, hasMore: true);
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('libraries').doc(libraryId)
            .collection('students')
            .orderBy('createdAt', descending: true)
            .limit(_pageSize)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('libraries').doc(libraryId)
            .collection('students')
            .limit(_pageSize)
            .get();
      }

      final students = <StudentModel>[];
      for (final doc in snap.docs) {
        try {
          students.add(_safeParseDoc(doc));
        } catch (parseErr) {
          if (kDebugMode) debugPrint('Error parsing student doc ${doc.id}: $parseErr');
        }
      }

      state = state.copyWith(
        students: students,
        isLoading: false,
        hasMore: snap.docs.length == _pageSize,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.lastDoc == null || libraryId.isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('libraries').doc(libraryId)
            .collection('students')
            .orderBy('createdAt', descending: true)
            .startAfterDocument(state.lastDoc!)
            .limit(_pageSize)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('libraries').doc(libraryId)
            .collection('students')
            .startAfterDocument(state.lastDoc!)
            .limit(_pageSize)
            .get();
      }

      final newStudents = <StudentModel>[];
      for (final doc in snap.docs) {
        try {
          newStudents.add(_safeParseDoc(doc));
        } catch (parseErr) {
          if (kDebugMode) debugPrint('Error parsing student doc ${doc.id}: $parseErr');
        }
      }

      state = state.copyWith(
        students: [...state.students, ...newStudents],
        isLoading: false,
        hasMore: snap.docs.length == _pageSize,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  void refresh() => loadFirst();
}

