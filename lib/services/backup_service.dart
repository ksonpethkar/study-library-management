import 'dart:convert';
import 'dart:io' show File;
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BackupService provides functionality to export and import library data to/from JSON.
/// Fully cross-platform: works seamlessly on Web, Android, iOS, Windows, and macOS.
class BackupService {
  final FirebaseFirestore _firestore;

  BackupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const List<String> _supportedCollections = [
    'students',
    'seats',
    'sections',
    'plans',
    'receipts',
    'payments',
    'settings',
    'announcements',
    'holidays',
    'staff',
    'waiting_list',
    'requests',
  ];

  /// Recursively encodes Firestore types (like Timestamp and DateTime) into JSON-safe representations.
  static dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {
        '__type__': 'timestamp',
        'seconds': value.seconds,
        'nanoseconds': value.nanoseconds,
      };
    } else if (value is DateTime) {
      return {
        '__type__': 'datetime',
        'iso': value.toIso8601String(),
      };
    } else if (value is GeoPoint) {
      return {
        '__type__': 'geopoint',
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    } else if (value is DocumentReference) {
      return {
        '__type__': 'docref',
        'path': value.path,
      };
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _encodeValue(v)));
    } else if (value is List) {
      return value.map(_encodeValue).toList();
    }
    return value;
  }

  /// Recursively decodes JSON representations back into Firestore-compatible objects.
  static dynamic _decodeValue(dynamic value) {
    if (value is Map) {
      if (value['__type__'] == 'timestamp') {
        final sec = value['seconds'] as int? ?? 0;
        final nano = value['nanoseconds'] as int? ?? 0;
        return Timestamp(sec, nano);
      } else if (value['__type__'] == 'datetime') {
        final iso = value['iso'] as String?;
        if (iso != null) {
          try {
            return DateTime.parse(iso);
          } catch (_) { /* intentionally silent */ }
        }
      } else if (value['__type__'] == 'geopoint') {
        final lat = (value['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng = (value['longitude'] as num?)?.toDouble() ?? 0.0;
        return GeoPoint(lat, lng);
      }
      return value.map((k, v) => MapEntry(k.toString(), _decodeValue(v)));
    } else if (value is List) {
      return value.map(_decodeValue).toList();
    }
    return value;
  }

  static String _jsonEncodeWorker(Map<String, dynamic> data) => jsonEncode(data);
  static Map<String, dynamic> _jsonDecodeWorker(String jsonStr) =>
      jsonDecode(jsonStr) as Map<String, dynamic>;

  /// Generates the raw JSON string containing all library collections in memory.
  /// Works 100% in Web and Mobile without filesystem dependencies.
  Future<String> generateBackupJson(String libraryId) async {
    final data = <String, dynamic>{
      'version': 2,
      'libraryId': libraryId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    for (final col in _supportedCollections) {
      try {
        final snapshot = await _firestore
            .collection('libraries')
            .doc(libraryId)
            .collection(col)
            .get();
        // Include doc ID as '__docId__' and encode Firestore timestamps safely
        data[col] = snapshot.docs.map((doc) {
          final rawData = Map<String, dynamic>.from(doc.data());
          final encoded = _encodeValue(rawData) as Map<String, dynamic>;
          encoded['__docId__'] = doc.id;
          return encoded;
        }).toList();
      } catch (e) {
        if (kDebugMode) debugPrint('Backup: could not read collection $col — $e');
        data[col] = []; // Partial backup: empty list for failed collection
      }
    }

    return await compute(_jsonEncodeWorker, data);
  }

  /// Creates a JSON backup file containing all library collections (Mobile / Desktop).
  Future<File> createBackup(String libraryId) async {
    final jsonString = await generateBackupJson(libraryId);

    if (kIsWeb) {
      throw UnsupportedError('File system access not available on Web. Use generateBackupJson instead.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
        '${directory.path}/backup_${libraryId}_${DateTime.now().millisecondsSinceEpoch}.json');
    return await file.writeAsString(jsonString);
  }

  /// Restores library data from in-memory byte list (Web, Mobile, Desktop).
  Future<void> restoreFromBackupBytes(String libraryId, List<int> bytes,
      {void Function(double)? onProgress}) async {
    final jsonString = utf8.decode(bytes);
    await restoreFromJsonString(libraryId, jsonString, onProgress: onProgress);
  }

  /// Restores library data directly from a JSON string.
  Future<void> restoreFromJsonString(String libraryId, String jsonString,
      {void Function(double)? onProgress}) async {
    try {
      final data = await compute(_jsonDecodeWorker, jsonString);

      final version = data['version'] as int? ?? 1;
      if (version > 2) throw Exception('Unsupported backup version $version.');
      if (data['libraryId'] != null && data['libraryId'] != libraryId) {
        throw Exception('Backup file belongs to a different library.');
      }

      // Count total operations for progress
      int totalOperations = 0;
      for (final col in _supportedCollections) {
        if (data[col] != null) {
          totalOperations += (data[col] as List).length;
        }
      }
      if (totalOperations == 0) return;

      int completedOperations = 0;
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (final col in _supportedCollections) {
        if (data[col] == null) continue;
        final list = data[col] as List<dynamic>;

        for (final item in list) {
          final docData = item as Map<String, dynamic>;

          // v2 backups store the real Firestore ID in '__docId__'
          // v1 backups (old format) stored it in 'id' field
          final docId = (docData['__docId__'] as String?) ??
              (docData['id'] as String?);
          if (docId == null || docId.isEmpty) continue;

          // Remove helper key and decode timestamps back into native Firestore types
          final cleanData = Map<String, dynamic>.from(docData)
            ..remove('__docId__');
          final decodedData = _decodeValue(cleanData) as Map<String, dynamic>;

          final docRef = _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection(col)
              .doc(docId);
          batch.set(docRef, decodedData, SetOptions(merge: true));
          batchCount++;
          completedOperations++;

          // Firestore batches are limited to 500 operations
          if (batchCount >= 450) {
            await batch.commit();
            batch = _firestore.batch(); // Create fresh batch
            batchCount = 0;
            onProgress?.call(completedOperations / totalOperations);
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
        onProgress?.call(1.0);
      }
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  /// Restores library data from a JSON backup file (Mobile / Desktop).
  Future<void> restoreFromBackup(String libraryId, File backupFile,
      {void Function(double)? onProgress}) async {
    try {
      if (!await backupFile.exists()) throw Exception('Backup file not found.');
      final bytes = await backupFile.readAsBytes();
      await restoreFromBackupBytes(libraryId, bytes, onProgress: onProgress);
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  /// Gets the estimated size of the backup in bytes by calculating average document size.
  Future<int> getBackupSize(String libraryId) async {
    int estimatedBytes = 0;
    for (final col in _supportedCollections) {
      try {
        final snapshot = await _firestore
            .collection('libraries')
            .doc(libraryId)
            .collection(col)
            .count()
            .get();
        estimatedBytes += (snapshot.count ?? 0) * 1024;
      } catch (_) { /* intentionally silent */ }
    }
    return estimatedBytes;
  }

  static const String _keyLastDailyBackup = 'last_daily_cloud_backup_date';
  static const int _maxChunkChars = 400000; // 400 KB per chunk, well below Firestore 1 MB document limit

  /// Saves a daily cloud backup snapshot directly into Firestore.
  /// Uses GZip compression and subcollection chunking to safely bypass Firestore's 1 MB document limit.
  Future<void> saveDailyCloudSnapshot(String libraryId) async {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy_MM_dd').format(now);
    final jsonString = await generateBackupJson(libraryId);
    final rawBytes = utf8.encode(jsonString);

    // GZip compression: Reduces payload by 70%-90%
    final compressedBytes = GZipEncoder().encode(rawBytes);
    final isCompressed = compressedBytes.length < rawBytes.length;
    final payloadBytes = isCompressed ? compressedBytes : rawBytes;
    final base64Payload = base64Encode(payloadBytes);

    // Chunking into safe slices
    final int totalChunks = (base64Payload.length / _maxChunkChars).ceil().clamp(1, 9999);

    final snapshotRef = _firestore
        .collection('libraries')
        .doc(libraryId)
        .collection('daily_backups')
        .doc(dateKey);

    // 1. Save metadata document (lightweight, under 1 KB, loads instantly in list view)
    await snapshotRef.set({
      'dateKey': dateKey,
      'createdAt': FieldValue.serverTimestamp(),
      'sizeBytes': rawBytes.length,
      'compressedSizeBytes': payloadBytes.length,
      'chunkCount': totalChunks,
      'isCompressed': isCompressed,
      'formatVersion': 3,
    });

    // 2. Save payload chunks into the subcollection
    WriteBatch batch = _firestore.batch();
    for (int i = 0; i < totalChunks; i++) {
      final start = i * _maxChunkChars;
      final end = (start + _maxChunkChars < base64Payload.length)
          ? start + _maxChunkChars
          : base64Payload.length;
      final chunkStr = base64Payload.substring(start, end);

      final chunkDocRef = snapshotRef.collection('chunks').doc(i.toString());
      batch.set(chunkDocRef, {
        'index': i,
        'data': chunkStr,
      });
    }
    await batch.commit();

    // 3. Keep rolling last 7 days: clean older snapshots and their subcollections
    try {
      final oldDocs = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('daily_backups')
          .orderBy('createdAt', descending: true)
          .get();

      if (oldDocs.docs.length > 7) {
        for (int i = 7; i < oldDocs.docs.length; i++) {
          final oldDoc = oldDocs.docs[i];
          // Delete chunks subcollection
          final chunkDocs = await oldDoc.reference.collection('chunks').get();
          for (final cDoc in chunkDocs.docs) {
            await cDoc.reference.delete();
          }
          await oldDoc.reference.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error cleaning old daily backups: $e');
    }
  }

  /// Retrieves and reconstructs the full backup JSON string from a cloud snapshot.
  /// Supports chunked & compressed (v3) as well as legacy single-document (v1/v2) snapshots.
  Future<String> getDailyCloudSnapshotJson(
    String libraryId,
    String docId,
    Map<String, dynamic> metadata,
  ) async {
    final formatVersion = metadata['formatVersion'] as int? ?? 1;
    final chunkCount = metadata['chunkCount'] as int?;

    if (formatVersion >= 3 || chunkCount != null) {
      // Chunked format: load from 'chunks' subcollection
      final chunksSnap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('daily_backups')
          .doc(docId)
          .collection('chunks')
          .orderBy('index')
          .get();

      if (chunksSnap.docs.isEmpty) {
        throw Exception('Snapshot chunks not found in cloud storage.');
      }

      final buffer = StringBuffer();
      for (final doc in chunksSnap.docs) {
        buffer.write(doc.data()['data'] as String? ?? '');
      }

      final fullBase64 = buffer.toString();
      final bytes = base64Decode(fullBase64);

      final isCompressed = metadata['isCompressed'] as bool? ?? false;
      final decompressedBytes = isCompressed
          ? GZipDecoder().decodeBytes(bytes)
          : bytes;

      return utf8.decode(decompressedBytes);
    } else {
      // Legacy format: payload stored directly in backupData field
      final legacyPayload = metadata['backupData'] as String?;
      if (legacyPayload != null && legacyPayload.isNotEmpty) {
        return legacyPayload;
      }
      throw Exception('Invalid or empty snapshot data.');
    }
  }

  /// Automatically snapshots library collections every day without interrupting the user.
  Future<void> checkAndRunRollingBackup(String libraryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastDate = prefs.getString(_keyLastDailyBackup);

      if (lastDate == todayStr) {
        // Already backed up today
        return;
      }

      await saveDailyCloudSnapshot(libraryId);
      await prefs.setString(_keyLastDailyBackup, todayStr);
      if (kDebugMode) debugPrint('Daily automated backup snapshot created for $todayStr');
    } catch (e) {
      if (kDebugMode) debugPrint('Silent auto-backup error: $e');
    }
  }

  /// Stream of recent daily cloud snapshots stored in Firestore
  Stream<QuerySnapshot<Map<String, dynamic>>> streamDailySnapshots(String libraryId) {
    return _firestore
        .collection('libraries')
        .doc(libraryId)
        .collection('daily_backups')
        .orderBy('createdAt', descending: true)
        .limit(7)
        .snapshots();
  }
}

/// Provider for BackupService
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});
