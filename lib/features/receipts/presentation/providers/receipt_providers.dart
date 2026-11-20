import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/models/receipt_model.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepository();
});

final receiptsStreamProvider = StreamProvider<List<ReceiptModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(receiptRepositoryProvider).getReceipts(libraryId);
});

final studentReceiptsStreamProvider =
    StreamProvider.family<List<ReceiptModel>, String>((ref, studentId) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty || studentId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(receiptRepositoryProvider).getReceiptsByStudent(libraryId, studentId);
});

/// Alias for compatibility with receipt_list_screen
final receiptListProvider = receiptsStreamProvider;
