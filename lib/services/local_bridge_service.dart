import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// LocalBridgeService connects to a local WhatsApp Web bridge (e.g. Baileys / whatsapp-web.js)
/// running on the library reception desk computer.
/// Dispatches automated WhatsApp messages without Meta API fees across all platforms.
class LocalBridgeService {
  /// Sends a message via the local WhatsApp Web bridge.
  Future<bool> sendMessage({
    required String bridgeUrl,
    required String phone,
    required String message,
  }) async {
    final cleanUrl = bridgeUrl.trim();
    if (cleanUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(cleanUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone.replaceAll(RegExp(r'\D'), ''),
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 6));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      if (kDebugMode) debugPrint('LocalBridgeService error: $e');
      return false;
    }
  }

  /// Pings the local bridge to test connectivity.
  Future<bool> pingBridge({required String bridgeUrl}) async {
    final cleanUrl = bridgeUrl.trim();
    if (cleanUrl.isEmpty) return false;

    try {
      final uri = Uri.parse(cleanUrl.replaceAll(RegExp(r'/send/?$'), '/ping'));
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      if (kDebugMode) debugPrint('LocalBridgeService ping failed: $e');
      return false;
    }
  }
}

final localBridgeServiceProvider = Provider<LocalBridgeService>((ref) => LocalBridgeService());
