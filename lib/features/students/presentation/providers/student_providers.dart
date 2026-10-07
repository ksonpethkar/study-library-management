import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/features/students/data/repositories/student_repository.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/core/providers/library_provider.dart';

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
final currentStudentProvider = StreamProvider<StudentModel?>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (libraryId == null || libraryId.isEmpty) return Stream.value(null);
  if (user == null) return Stream.value(null);

  final uid = user.uid;
  final email = user.email ?? '';

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('students')
      .where('userId', isEqualTo: uid)
      .limit(1)
      .snapshots()
      .asyncExpand((snap) async* {
    if (snap.docs.isNotEmpty) {
      yield StudentModel.fromJson({...snap.docs.first.data(), 'id': snap.docs.first.id});
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
          yield StudentModel.fromJson({...doc.data(), 'id': doc.id});
        } else {
          yield null;
        }
      } catch (_) {
        yield null;
      }
    } else {
      yield null;
    }
  });
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
  
  Future<void> loadFirst() async {
    if (libraryId.isEmpty) return;
    state = state.copyWith(isLoading: true, students: [], lastDoc: null, hasMore: true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();
      final students = snap.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})).toList();
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
      final snap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(state.lastDoc!)
          .limit(_pageSize)
          .get();
      final newStudents = snap.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})).toList();
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

