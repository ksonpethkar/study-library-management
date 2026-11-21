import 'sentinel_models.dart';

/// The Sentinel AI Diagnostic Copilot synthesizes raw anomalies, stack traces,
/// and state diffs into plain-language diagnostic summaries, root-cause deductions,
/// and actionable 1-tap remediation steps.
class SentinelAiDiagnostic {
  const SentinelAiDiagnostic();

  /// Generates an executive health summary for the Admin Diagnostic Console.
  String generateExecutiveSummary(SentinelHealthMetrics metrics, List<SentinelAnomaly> anomalies) {
    if (metrics.score >= 98.0 && anomalies.isEmpty) {
      return 'All operational systems are operating normally. Real-time streams, desk assignments, and payment ledgers are 100% consistent across both portals.';
    }

    if (metrics.criticalCount > 0) {
      return '${metrics.criticalCount} critical discrepancy detected! Immediate counter attention recommended to prevent desk assignment collisions or student pass mismatches.';
    }

    if (metrics.warningCount > 0) {
      return '${metrics.warningCount} operational warning(s) detected. Systems are functional, but soft-locks or minor desynchronizations require automated resolution.';
    }

    return 'System operational with ${metrics.advisoryCount} advisory item(s) (e.g. pending plan renewals or grace period expiries).';
  }

  /// Formulates an AI root-cause analysis and step-by-step remediation plan
  /// for a given anomaly.
  Map<String, String> analyzeAnomaly(SentinelAnomaly anomaly) {
    switch (anomaly.domain) {
      case SentinelDomain.seats:
        if (anomaly.id.startsWith('zombie_hold')) {
          return {
            'diagnosis':
                'An applicant initiated seat selection during registration but dropped off before completing the form. The 5-minute reservation timer has elapsed.',
            'remediation':
                'Desk can be safely auto-released back to the available inventory with 0 risk of duplicate assignment.',
            'actionLabel': 'Release Desk Now',
          };
        }
        if (anomaly.id.contains('no_student')) {
          return {
            'diagnosis':
                'A previous student was removed or their pass expired, but the seat status flag was left marked as occupied.',
            'remediation':
                'Reset the desk status to available so it appears on the live interactive seat map.',
            'actionLabel': 'Reset to Available',
          };
        }
        return {
          'diagnosis':
              'Discrepancy detected between desk occupancy status and student enrollment records.',
          'remediation':
              'Re-synchronize the student profile with the assigned desk number.',
          'actionLabel': 'Re-sync Seat',
        };

      case SentinelDomain.students:
        return {
          'diagnosis':
              'Student record references a desk or status that is out of sync with the library section database.',
          'remediation':
              'Verify student registration and update their assigned desk in the student dossier.',
          'actionLabel': 'Auto-Heal Reference',
        };

      case SentinelDomain.payments:
        return {
          'diagnosis':
              'A payment record was processed or modified that resulted in an unexpected negative outstanding dues balance.',
          'remediation':
              'Reset the outstanding balance to ₹0.00 and verify receipt entries in the financial drawer.',
          'actionLabel': 'Clear Negative Due',
        };

      case SentinelDomain.settings:
        return {
          'diagnosis':
              'Dual-portal settings (such as ID Card or Receipt templates) differ between Admin and Student portals.',
          'remediation':
              'Trigger a background cache refresh to force client devices to consume the latest Firestore template.',
          'actionLabel': 'Force Sync Settings',
        };

      case SentinelDomain.streams:
        return {
          'diagnosis':
              'Firestore real-time snapshot latency exceeded the 2.5-second SLA, likely due to mobile cellular network throttling or packet drops.',
          'remediation':
              'Ensure internet connectivity is stable. Local offline cache is currently serving data gracefully.',
          'actionLabel': 'Check Connection',
        };

      case SentinelDomain.cache:
      case SentinelDomain.uiLifecycle:
      case SentinelDomain.requests:
        return {
          'diagnosis': anomaly.rootCauseDiagnosis ?? 'System invariant check flagged an operational discrepancy.',
          'remediation': anomaly.remediationSuggestion ?? 'Review details and apply recommended action.',
          'actionLabel': 'Inspect & Fix',
        };
    }
  }
}
