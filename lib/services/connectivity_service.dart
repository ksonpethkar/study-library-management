import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Stream of connectivity status. Returns true if connected to internet.
  Stream<bool> get isConnected {
    return _connectivity.onConnectivityChanged.map((List<ConnectivityResult> results) {
      // Return true if any connection type is active (not none)
      return results.any((result) => result != ConnectivityResult.none);
    });
  }

  /// Checks the current connection status immediately.
  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      // In case of error (e.g. platform exceptions), default to false
      return false; 
    }
  }
}
