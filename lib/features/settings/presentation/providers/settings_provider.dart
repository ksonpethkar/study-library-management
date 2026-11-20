import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/settings/data/repositories/settings_repository.dart';
import 'package:study_library/features/settings/presentation/screens/id_card_customizer_screen.dart'
    show idCardTemplateProvider;
import 'package:study_library/models/id_card_template_model.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// Shared dynamic stream for ID Card Template (ensures Dual-Portal Parity per GEMINI.md Rule 6.2)
final idCardTemplateStreamProvider = Provider<StreamProvider<IdCardTemplateSettings>>((ref) {
  return idCardTemplateProvider;
});

/// Stream provider for Receipt Template configuration
final receiptTemplateStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
  return ref.watch(settingsRepositoryProvider).streamSetting(libraryId, 'receipt_template');
});

/// Stream provider for Payment Methods (UPI, Bank Details, Cash enabled)
final paymentMethodsStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
  return ref.watch(settingsRepositoryProvider).streamSetting(libraryId, 'payment_methods');
});

/// Stream provider for Grace Period and Auto-lock settings
final gracePeriodSettingsStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
  return ref.watch(settingsRepositoryProvider).streamSetting(libraryId, 'grace_period');
});

/// Stream provider for Communications & Messaging Hub settings
final communicationsSettingsStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
  return ref.watch(settingsRepositoryProvider).streamSetting(libraryId, 'communications');
});
