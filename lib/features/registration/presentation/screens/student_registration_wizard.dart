import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/registration_provider.dart';
import 'id_scan_screen.dart';
import 'registration_form_screen.dart';
import 'photo_upload_screen.dart';
import 'plan_selection_screen.dart';
import 'review_submit_screen.dart';

class StudentRegistrationWizard extends ConsumerWidget {
  const StudentRegistrationWizard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(registrationStepProvider);

    switch (step) {
      case 1:
        return const IdScanScreen();
      case 2:
        return const RegistrationFormScreen();
      case 3:
        return const PhotoUploadScreen();
      case 4:
        return const PlanSelectionScreen();
      case 5:
        return const ReviewSubmitScreen();
      default:
        return const IdScanScreen();
    }
  }
}
