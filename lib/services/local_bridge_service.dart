import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// LocalBridgeService connects to a local WhatsApp Web bridge (e.g. Baileys / whatsapp-web.js)
/// running on the library reception desk computer.
/// Dispatches automated WhatsApp messages without Meta API fees.
class LocalBridgeService {
  /// Sends a message via the local WhatsApp Web bridge.
  Future<bool> sendMessage({
    required String bridgeUrl,
    required String phone,
    required String message,
  }) async {
    final cleanUrl = bridgeUrl.trim();
    if (cleanUrl.isEmpty) return false;

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final request = await client.postUrl(Uri.parse(cleanUrl));
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'phone': phone.replaceAll(RegExp(r'\D'), ''),
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });

      request.write(payload);
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('LocalBridgeService error: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  /// Pings the local bridge to test connectivity.
  Future<bool> pingBridge({required String bridgeUrl}) async {
    final cleanUrl = bridgeUrl.trim();
    if (cleanUrl.isEmpty) return false;

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(cleanUrl.replaceAll(RegExp(r'/send/?$'), '/ping'));
      final request = await client.getUrl(uri);
      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('LocalBridgeService ping failed: $e');
      return false;
    } finally {
      client?.close();
    }
  }
}

final localBridgeServiceProvider = Provider<LocalBridgeService>((ref) => LocalBridgeService());
