import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/features/requests/presentation/screens/request_list_screen.dart';
import 'package:study_library/features/feedback/presentation/screens/feedback_list_screen.dart';
import 'package:study_library/features/waiting_list/data/repositories/waiting_list_repository.dart';

/// Representation of pending request counts broken down across every module.
class RequestModuleCounts {
  final int totalPending;
  final int admissionsPending;
  final int seatChangesPending;
  final int renewalsPending;
  final int profileUpdatesPending;
  final int otherPending;

  // Cross-module counts
  final int openFeedbackCount;
  final int waitingListCount;

  const RequestModuleCounts({
    this.totalPending = 0,
    this.admissionsPending = 0,
    this.seatChangesPending = 0,
    this.renewalsPending = 0,
    this.profileUpdatesPending = 0,
    this.otherPending = 0,
    this.openFeedbackCount = 0,
    this.waitingListCount = 0,
  });

  /// Total count across all action-required modules in the library.
  int get totalActionableItems => totalPending + openFeedbackCount + waitingListCount;

  bool get hasAnyActionable => totalActionableItems > 0;

  /// Human-readable concise summary (e.g., "2 Adm • 1 Seat • 1 Renew")
  String get summaryText {
    final parts = <String>[];
    if (admissionsPending > 0) parts.add('$admissionsPending Adm');
    if (seatChangesPending > 0) parts.add('$seatChangesPending Seat');
    if (renewalsPending > 0) parts.add('$renewalsPending Renew');
    if (profileUpdatesPending > 0) parts.add('$profileUpdatesPending Profile');
    if (openFeedbackCount > 0) parts.add('$openFeedbackCount Feedback');
    if (waitingListCount > 0) parts.add('$waitingListCount Waitlist');
    return parts.isEmpty ? 'All clear' : parts.join(' • ');
  }

  /// Longer descriptive breakdown for hero cards / banners
  String get detailedSummary {
    final parts = <String>[];
    if (admissionsPending > 0) {
      parts.add('$admissionsPending Admission${admissionsPending > 1 ? "s" : ""}');
    }
    if (seatChangesPending > 0) {
      parts.add('$seatChangesPending Seat Change${seatChangesPending > 1 ? "s" : ""}');
    }
    if (renewalsPending > 0) {
      parts.add('$renewalsPending Plan Renewal${renewalsPending > 1 ? "s" : ""}');
    }
    if (profileUpdatesPending > 0) {
      parts.add('$profileUpdatesPending Profile Edit${profileUpdatesPending > 1 ? "s" : ""}');
    }
    if (openFeedbackCount > 0) {
      parts.add('$openFeedbackCount Open Feedback');
    }
    if (waitingListCount > 0) {
      parts.add('$waitingListCount in Waiting List');
    }
    return parts.isEmpty ? 'No pending requests across modules.' : parts.join(' • ');
  }
}

/// Reactive provider that analyzes all incoming requests and categorizes them by module.
final requestModuleCountsProvider = Provider<RequestModuleCounts>((ref) {
  final requestsAsync = ref.watch(requestsStreamProvider);
  final feedbackAsync = ref.watch(feedbackStreamProvider);
  final waitingListAsync = ref.watch(waitingListStreamProvider);

  final requests = requestsAsync.value ?? [];
  final pending = requests.where((r) => r.isPending).toList();

  int admissions = 0;
  int seatChanges = 0;
  int renewals = 0;
  int profileUpdates = 0;
  int other = 0;

  for (final r in pending) {
    final t = r.type.toLowerCase().trim();
    if (t == 'registration' || t == 'newregistration') {
      admissions++;
    } else if (t == 'seat_change' || t == 'seatchange') {
      seatChanges++;
    } else if (t == 'renewal' || t == 'plan_renewal') {
      renewals++;
    } else if (t == 'profile_update') {
      profileUpdates++;
    } else {
      other++;
    }
  }

  final feedbacks = feedbackAsync.value ?? [];
  final openFeedbacks = feedbacks.where((f) => f.status != 'resolved').length;

  final waitingList = waitingListAsync.value ?? [];
  final waitingCount = waitingList.length;

  return RequestModuleCounts(
    totalPending: pending.length,
    admissionsPending: admissions,
    seatChangesPending: seatChanges,
    renewalsPending: renewals,
    profileUpdatesPending: profileUpdates,
    otherPending: other,
    openFeedbackCount: openFeedbacks,
    waitingListCount: waitingCount,
  );
});
