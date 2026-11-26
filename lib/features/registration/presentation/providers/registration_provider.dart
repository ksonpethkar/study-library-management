import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores registration data across all steps
final registrationDataProvider = Provider<Map<String, dynamic>>((ref) => {});

/// Registration data notifier for complex state updates
class RegistrationNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() => {};

  void updateField(String key, dynamic value) {
    state = {...state, key: value};
  }

  void updateFields(Map<String, dynamic> fields) {
    state = {...state, ...fields};
  }

  void clear() {
    state = {};
  }
}

final registrationNotifierProvider =
    NotifierProvider<RegistrationNotifier, Map<String, dynamic>>(RegistrationNotifier.new);

/// OCR result notifier
class OcrResultNotifier extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => {};

  void setResult(Map<String, String?> result) {
    state = result;
  }

  void clear() {
    state = {};
  }
}

final ocrResultProvider =
    NotifierProvider<OcrResultNotifier, Map<String, String?>>(OcrResultNotifier.new);

/// Selected seat notifier
class SelectedSeatNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String seatId) => state = seatId;
  void clear() => state = null;
}

final selectedSeatProvider =
    NotifierProvider<SelectedSeatNotifier, String?>(SelectedSeatNotifier.new);

/// Detailed seat selection state containing desk metadata and auto-assign preferences
class SelectedSeatDetails {
  final String? seatId;
  final String? seatLabel;
  final String? sectionId;
  final String? sectionName;
  final bool isAutoAssign;

  const SelectedSeatDetails({
    this.seatId,
    this.seatLabel,
    this.sectionId,
    this.sectionName,
    this.isAutoAssign = false,
  });

  bool get hasSelection => isAutoAssign || (seatId != null && seatId!.isNotEmpty);

  SelectedSeatDetails copyWith({
    String? seatId,
    String? seatLabel,
    String? sectionId,
    String? sectionName,
    bool? isAutoAssign,
  }) {
    return SelectedSeatDetails(
      seatId: seatId ?? this.seatId,
      seatLabel: seatLabel ?? this.seatLabel,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      isAutoAssign: isAutoAssign ?? this.isAutoAssign,
    );
  }
}

class SelectedSeatDetailsNotifier extends Notifier<SelectedSeatDetails> {
  @override
  SelectedSeatDetails build() => const SelectedSeatDetails();

  void selectSeat({
    required String seatId,
    required String seatLabel,
    required String sectionId,
    required String sectionName,
  }) {
    state = SelectedSeatDetails(
      seatId: seatId,
      seatLabel: seatLabel,
      sectionId: sectionId,
      sectionName: sectionName,
      isAutoAssign: false,
    );
    ref.read(selectedSeatProvider.notifier).select(seatId);
  }

  void selectAutoAssign({
    String? sectionId,
    String? sectionName,
  }) {
    state = SelectedSeatDetails(
      seatId: null,
      seatLabel: 'Auto-Assign',
      sectionId: sectionId,
      sectionName: sectionName ?? 'Any Available Section',
      isAutoAssign: true,
    );
    ref.read(selectedSeatProvider.notifier).clear();
  }

  void clear() {
    state = const SelectedSeatDetails();
    ref.read(selectedSeatProvider.notifier).clear();
  }
}

final selectedSeatDetailsProvider =
    NotifierProvider<SelectedSeatDetailsNotifier, SelectedSeatDetails>(
        SelectedSeatDetailsNotifier.new);

/// Captures optional `?lib=...&section=...&seat=...` deep-link parameters
/// when an applicant taps "Register for Admission Online" from Public `/seats`.
class RegistrationDeepLink {
  final String? libraryId;
  final String? sectionId;
  final String? seatId;

  const RegistrationDeepLink({
    this.libraryId,
    this.sectionId,
    this.seatId,
  });

  bool get hasSeatTarget =>
      (seatId != null && seatId!.isNotEmpty) ||
      (sectionId != null && sectionId!.isNotEmpty);
}

class RegistrationDeepLinkNotifier extends Notifier<RegistrationDeepLink> {
  @override
  RegistrationDeepLink build() => const RegistrationDeepLink();

  void setTarget({String? libraryId, String? sectionId, String? seatId}) {
    state = RegistrationDeepLink(
      libraryId: libraryId,
      sectionId: sectionId,
      seatId: seatId,
    );
  }

  void clear() => state = const RegistrationDeepLink();
}

final registrationDeepLinkProvider =
    NotifierProvider<RegistrationDeepLinkNotifier, RegistrationDeepLink>(
        RegistrationDeepLinkNotifier.new);

/// Selected plan notifier
class SelectedPlanNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String planId) => state = planId;
  void clear() => state = null;
}

final selectedPlanProvider =
    NotifierProvider<SelectedPlanNotifier, String?>(SelectedPlanNotifier.new);

/// Registration step notifier
class RegistrationStepNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void next() => state = state + 1;
  void previous() => state = state > 1 ? state - 1 : 1;
  void goTo(int step) => state = step;
  void reset() => state = 1;
}

final registrationStepProvider =
    NotifierProvider<RegistrationStepNotifier, int>(RegistrationStepNotifier.new);

/// True while ReviewSubmitScreen is holding the confirmation screen open so
/// StudentRegistrationWizard does not unmount it mid-handoff.
class RegistrationSubmissionSuccessNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setSuccess(bool value) => state = value;
}

final registrationSubmissionSuccessProvider =
    NotifierProvider<RegistrationSubmissionSuccessNotifier, bool>(
  RegistrationSubmissionSuccessNotifier.new,
);

/// Persists in-progress multi-step admission drafts across Google OAuth redirects on Web.
class RegistrationDraftStorage {
  static const String _prefKey = 'pending_registration_draft_v1';
  static const String _redirectFlagKey = 'pending_registration_auth_redirect_v1';

  static Future<void> saveDraft(WidgetRef ref) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seat = ref.read(selectedSeatDetailsProvider);
      final payload = <String, dynamic>{
        'savedAt': DateTime.now().toIso8601String(),
        'step': ref.read(registrationStepProvider),
        'regData': ref.read(registrationNotifierProvider),
        'ocrData': ref.read(ocrResultProvider),
        'selectedPlanId': ref.read(selectedPlanProvider),
        'seatDetails': {
          'seatId': seat.seatId,
          'seatLabel': seat.seatLabel,
          'sectionId': seat.sectionId,
          'sectionName': seat.sectionName,
          'isAutoAssign': seat.isAutoAssign,
        },
      };
      await prefs.setString(_prefKey, jsonEncode(payload));
      await prefs.setBool(_redirectFlagKey, true);
    } catch (_) {}
  }

  static Future<bool> hasPendingRedirectDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_redirectFlagKey) ?? false)) return false;
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return false;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse((map['savedAt'] ?? '').toString());
      if (savedAt == null || DateTime.now().difference(savedAt).inHours >= 2) {
        await clearDraft();
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> restoreDraft(WidgetRef ref) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRedirectDraft = prefs.getBool(_redirectFlagKey) ?? false;
      final raw = prefs.getString(_prefKey);
      if (!isRedirectDraft || raw == null || raw.isEmpty) {
        return false;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse((map['savedAt'] ?? '').toString());
      if (savedAt == null || DateTime.now().difference(savedAt).inHours >= 2) {
        await clearDraft();
        return false;
      }

      final regMap = (map['regData'] as Map?)?.cast<String, dynamic>();
      if (regMap != null) {
        ref.read(registrationNotifierProvider.notifier).updateFields(regMap);
      }

      final ocrRaw = (map['ocrData'] as Map?);
      if (ocrRaw != null) {
        final ocrMap = ocrRaw.map((k, v) => MapEntry(k.toString(), v?.toString()));
        ref.read(ocrResultProvider.notifier).setResult(ocrMap);
      }

      final planId = map['selectedPlanId']?.toString();
      if (planId != null && planId.isNotEmpty) {
        ref.read(selectedPlanProvider.notifier).select(planId);
      }

      final seatMap = (map['seatDetails'] as Map?)?.cast<String, dynamic>();
      if (seatMap != null) {
        final isAuto = seatMap['isAutoAssign'] == true;
        final seatId = seatMap['seatId']?.toString();
        final sectionId = seatMap['sectionId']?.toString();
        final sectionName = seatMap['sectionName']?.toString();
        final seatLabel = seatMap['seatLabel']?.toString();
        if (isAuto) {
          ref.read(selectedSeatDetailsProvider.notifier).selectAutoAssign(
                sectionId: sectionId,
                sectionName: sectionName,
              );
        } else if (seatId != null &&
            seatId.isNotEmpty &&
            sectionId != null &&
            sectionId.isNotEmpty) {
          ref.read(selectedSeatDetailsProvider.notifier).selectSeat(
                seatId: seatId,
                seatLabel: seatLabel ?? seatId,
                sectionId: sectionId,
                sectionName: sectionName ?? '',
              );
        }
      }

      final stepVal = (map['step'] as num?)?.toInt() ?? 6;
      ref.read(registrationStepProvider.notifier).goTo(stepVal.clamp(1, 6));
      await prefs.remove(_redirectFlagKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      await prefs.remove(_redirectFlagKey);
    } catch (_) {}
  }
}
