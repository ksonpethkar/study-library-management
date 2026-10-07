import 'package:flutter_riverpod/flutter_riverpod.dart';

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
