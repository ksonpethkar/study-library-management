import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/plans/data/repositories/plan_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(firestore: ref.watch(firebaseFirestoreProvider));
});

final plansStreamProvider = StreamProvider<List<PlanModel>>((ref) {
  final repo = ref.watch(planRepositoryProvider);
  final libId = ref.watch(currentLibraryIdProvider);
  if (libId == null) return Stream.value([]);
  return repo.getPlans(libId);
});

final activePlansStreamProvider = StreamProvider<List<PlanModel>>((ref) {
  final repo = ref.watch(planRepositoryProvider);
  final libId = ref.watch(currentLibraryIdProvider);
  if (libId == null) return Stream.value([]);
  return repo.getActivePlans(libId);
});

class PlanActionState {
  final bool isLoading;
  final String? error;
  PlanActionState({this.isLoading = false, this.error});
}

class PlanActionNotifier extends Notifier<PlanActionState> {
  @override
  PlanActionState build() => PlanActionState();

  PlanRepository get _repository => ref.read(planRepositoryProvider);
  String get _libraryId => ref.read(currentLibraryIdProvider) ?? '';

  Future<void> createPlan(PlanModel plan) async {
    state = PlanActionState(isLoading: true);
    try {
      if (_libraryId.isEmpty) {
        throw Exception('No library found. Please sign in again.');
      }
      await _repository.createPlan(_libraryId, plan);
      state = PlanActionState(isLoading: false);
    } catch (e) {
      state = PlanActionState(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePlan(PlanModel plan) async {
    state = PlanActionState(isLoading: true);
    try {
      await _repository.updatePlan(_libraryId, plan);
      state = PlanActionState(isLoading: false);
    } catch (e) {
      state = PlanActionState(isLoading: false, error: e.toString());
    }
  }

  Future<void> deletePlan(String planId) async {
    state = PlanActionState(isLoading: true);
    try {
      await _repository.deletePlan(_libraryId, planId);
      state = PlanActionState(isLoading: false);
    } catch (e) {
      state = PlanActionState(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleActive(String planId, bool isActive) async {
    try {
      await _repository.toggleActive(_libraryId, planId, isActive);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> reorder(List<String> planIds) async {
    try {
      await _repository.reorderPlans(_libraryId, planIds);
    } catch (e) {
      // Handle error
    }
  }
}

final planActionProvider =
    NotifierProvider<PlanActionNotifier, PlanActionState>(PlanActionNotifier.new);
