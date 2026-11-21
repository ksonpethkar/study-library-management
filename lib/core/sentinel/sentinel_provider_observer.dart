import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sentinel_models.dart';
import 'sentinel_service.dart';

/// Riverpod ProviderObserver that watches all provider state transitions,
/// catches stream errors, measures mutation reflection latency, and reports
/// to Cozy Sentinel in real time.
base class SentinelProviderObserver extends ProviderObserver {
  final SentinelService _sentinelService;

  SentinelProviderObserver({SentinelService? sentinelService})
      : _sentinelService = sentinelService ?? SentinelService.instance;

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    super.didUpdateProvider(context, previousValue, newValue);

    try {
      final provider = context.provider;
      final providerName = provider.name ?? provider.runtimeType.toString();

      // Check for async error states in providers
      if (newValue is AsyncError) {
        final error = newValue.error;
        final stack = newValue.stackTrace;

        _sentinelService.reportAnomaly(
          SentinelAnomaly(
            id: 'prov_err_${DateTime.now().millisecondsSinceEpoch}_${providerName.hashCode}',
            title: 'Stream Error in $providerName',
            description: error.toString(),
            severity: SentinelSeverity.warning,
            domain: SentinelDomain.streams,
            detectedAt: DateTime.now(),
            canAutoHeal: false,
            rootCauseDiagnosis: 'Provider encountered an unhandled exception or stream failure.',
            remediationSuggestion: 'Check network status or inspect stream query filters.',
            metadata: {
              'provider': providerName,
              'stackTrace': stack.toString().split('\n').take(4).join(' | '),
            },
          ),
        );
      }

      // Feed state changes to Echo Verifier
      _sentinelService.handleProviderStateChange(
        providerName: providerName,
        previousValue: previousValue,
        newValue: newValue,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SentinelObserver] Error observing provider update: $e');
    }
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    super.providerDidFail(context, error, stackTrace);

    final provider = context.provider;
    final providerName = provider.name ?? provider.runtimeType.toString();
    if (kDebugMode) debugPrint('[SentinelObserver] Provider failed: $providerName, error: $error');

    _sentinelService.reportAnomaly(
      SentinelAnomaly(
        id: 'fail_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Provider Failure: $providerName',
        description: error.toString(),
        severity: SentinelSeverity.critical,
        domain: SentinelDomain.streams,
        detectedAt: DateTime.now(),
        canAutoHeal: false,
        rootCauseDiagnosis: 'Provider threw an unhandled runtime error during build or evaluation.',
        remediationSuggestion: 'Inspect the stack trace and verify provider dependencies.',
        metadata: {'provider': providerName},
      ),
    );
  }
}
