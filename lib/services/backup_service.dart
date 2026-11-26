import 'dart:convert';
import 'dart:io' show File;
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Summary report returned after completing a backup restore.
class BackupRestoreSummary {
  final int totalRestored;
  final int totalSkipped;
  final Map<String, int> collectionCounts;
  final List<String> skippedDetails;
  final bool exactMirrorMode;

  const BackupRestoreSummary({
    required this.totalRestored,
    required this.totalSkipped,
    required this.collectionCounts,
    this.skippedDetails = const [],
    this.exactMirrorMode = false,
  });
}

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
    'expenses',
    'feedback',
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

    // Export safe root library metadata (name, address, contact, UPI, billing config, etc.)
    try {
      final libDoc = await _firestore.collection('libraries').doc(libraryId).get();
      if (libDoc.exists && libDoc.data() != null) {
        final rawLib = Map<String, dynamic>.from(libDoc.data()!)
          ..remove('adminFcmToken')
          ..remove('adminFcmUpdatedAt');
        data['libraryProfile'] = _encodeValue(rawLib);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Backup: could not read root library profile — $e');
    }

    for (final col in _supportedCollections) {
      try {
        final snapshot = await _firestore
            .collection('libraries')
            .doc(libraryId)
            .collection(col)
            .get();

        if (col == 'sections') {
          final sectionsList = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final rawData = Map<String, dynamic>.from(doc.data());
            final encoded = _encodeValue(rawData) as Map<String, dynamic>;
            encoded['__docId__'] = doc.id;
            try {
              final seatsSnap = await doc.reference.collection('seats').get();
              encoded['__sub_seats__'] = seatsSnap.docs.map((sDoc) {
                final sRaw = Map<String, dynamic>.from(sDoc.data());
                final sEnc = _encodeValue(sRaw) as Map<String, dynamic>;
                sEnc['__docId__'] = sDoc.id;
                return sEnc;
              }).toList();
            } catch (e) {
              if (kDebugMode) debugPrint('Backup: could not read seats for section ${doc.id} — $e');
            }
            sectionsList.add(encoded);
          }
          data[col] = sectionsList;
        } else {
          // Include doc ID as '__docId__' and encode Firestore timestamps safely
          data[col] = snapshot.docs.map((doc) {
            final rawData = Map<String, dynamic>.from(doc.data());
            final encoded = _encodeValue(rawData) as Map<String, dynamic>;
            encoded['__docId__'] = doc.id;
            return encoded;
          }).toList();
        }
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
  Future<BackupRestoreSummary> restoreFromBackupBytes(
    String libraryId,
    List<int> bytes, {
    void Function(double)? onProgress,
    bool exactMirror = false,
  }) async {
    final jsonString = utf8.decode(bytes);
    return await restoreFromJsonString(
      libraryId,
      jsonString,
      onProgress: onProgress,
      exactMirror: exactMirror,
    );
  }

  /// Restores library data directly from a JSON string with resilient batch fallback & real-time progress.
  Future<BackupRestoreSummary> restoreFromJsonString(
    String libraryId,
    String jsonString, {
    void Function(double)? onProgress,
    bool exactMirror = false,
  }) async {
    try {
      final data = await compute(_jsonDecodeWorker, jsonString);

      final version = data['version'] as int? ?? 1;
      if (version > 2) throw Exception('Unsupported backup version $version.');
      if (data['libraryId'] != null && data['libraryId'] != libraryId) {
        throw Exception('Backup file belongs to a different library.');
      }

      // Count total operations for progress
      int totalOperations = 0;
      if (data['libraryProfile'] is Map) {
        totalOperations += 1;
      }
      for (final col in _supportedCollections) {
        if (data[col] != null) {
          final list = data[col] as List<dynamic>;
          totalOperations += list.length;
          if (col == 'sections') {
            for (final secItem in list) {
              if (secItem is Map && secItem['__sub_seats__'] is List) {
                totalOperations += (secItem['__sub_seats__'] as List).length;
              }
            }
          }
        }
      }
      if (totalOperations == 0) {
        return BackupRestoreSummary(
          totalRestored: 0,
          totalSkipped: 0,
          collectionCounts: const {},
          exactMirrorMode: exactMirror,
        );
      }

      int totalRestored = 0;
      int totalSkipped = 0;
      int completedOperations = 0;
      final Map<String, int> collectionCounts = {};
      final List<String> skippedDetails = [];

      // Restore root library profile safely (never overwrites ownerId)
      if (data['libraryProfile'] is Map) {
        try {
          final rawProfile = Map<String, dynamic>.from(data['libraryProfile'] as Map)
            ..remove('ownerId')
            ..remove('adminFcmToken')
            ..remove('adminFcmUpdatedAt');
          final decodedProfile = _decodeValue(rawProfile) as Map<String, dynamic>;
          await _firestore
              .collection('libraries')
              .doc(libraryId)
              .set(decodedProfile, SetOptions(merge: true));
          totalRestored++;
          collectionCounts['libraryProfile'] = 1;
        } catch (e) {
          totalSkipped++;
          skippedDetails.add('libraryProfile: $e');
        }
        completedOperations++;
        onProgress?.call((completedOperations / totalOperations).clamp(0.01, 0.99));
      }

      // Use smaller batches on Web for smooth progress updates and network resilience over 3G/4G
      final int batchLimit = kIsWeb ? 50 : 250;
      final SetOptions writeOpts = SetOptions(merge: !exactMirror);

      final List<({String col, String id, DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data})> pendingOps = [];

      Future<void> flushBatch() async {
        if (pendingOps.isEmpty) return;
        final batch = _firestore.batch();
        for (final op in pendingOps) {
          batch.set(op.ref, op.data, writeOpts);
        }
        try {
          await batch.commit();
          for (final op in pendingOps) {
            totalRestored++;
            collectionCounts[op.col] = (collectionCounts[op.col] ?? 0) + 1;
          }
        } catch (_) {
          // Resilient fallback: isolate individual failures (e.g., restricted staff or invalid legacy payment)
          // so one bad record never aborts an entire batch of healthy documents.
          for (final op in pendingOps) {
            try {
              await op.ref.set(op.data, writeOpts);
              totalRestored++;
              collectionCounts[op.col] = (collectionCounts[op.col] ?? 0) + 1;
            } catch (docErr) {
              totalSkipped++;
              if (skippedDetails.length < 15) {
                skippedDetails.add('${op.col}/${op.id}: $docErr');
              }
            }
          }
        } finally {
          completedOperations += pendingOps.length;
          pendingOps.clear();
          onProgress?.call((completedOperations / totalOperations).clamp(0.01, 1.0));
          // Yield to UI event loop on Flutter Web so progress bar & animation stay fluid
          await Future.delayed(Duration.zero);
        }
      }

      for (final col in _supportedCollections) {
        if (data[col] == null) continue;
        final list = data[col] as List<dynamic>;

        for (final item in list) {
          if (item is! Map) continue;
          final docData = Map<String, dynamic>.from(item);

          // v2 backups store the real Firestore ID in '__docId__'
          // v1 backups (old format) stored it in 'id' field
          final docId = (docData['__docId__'] as String?) ??
              (docData['id'] as String?);
          if (docId == null || docId.isEmpty) continue;

          // Remove helper keys and decode timestamps back into native Firestore types
          final cleanData = Map<String, dynamic>.from(docData)
            ..remove('__docId__')
            ..remove('__sub_seats__');
          final decodedData = _decodeValue(cleanData) as Map<String, dynamic>;

          final docRef = _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection(col)
              .doc(docId);
          pendingOps.add((col: col, id: docId, ref: docRef, data: decodedData));

          if (pendingOps.length >= batchLimit) {
            await flushBatch();
          }

          // Restore subcollection seats if present (preserves section layout & desks)
          if (col == 'sections' && docData['__sub_seats__'] is List) {
            final subSeats = docData['__sub_seats__'] as List<dynamic>;
            for (final seatItem in subSeats) {
              if (seatItem is! Map) continue;
              final seatMap = Map<String, dynamic>.from(seatItem);
              final seatDocId = (seatMap['__docId__'] as String?) ?? (seatMap['id'] as String?);
              if (seatDocId == null || seatDocId.isEmpty) continue;

              final cleanSeat = Map<String, dynamic>.from(seatMap)..remove('__docId__');
              final decodedSeat = _decodeValue(cleanSeat) as Map<String, dynamic>;

              final seatRef = _firestore
                  .collection('libraries')
                  .doc(libraryId)
                  .collection('sections')
                  .doc(docId)
                  .collection('seats')
                  .doc(seatDocId);

              pendingOps.add((col: 'section_seats', id: '$docId/$seatDocId', ref: seatRef, data: decodedSeat));

              if (pendingOps.length >= batchLimit) {
                await flushBatch();
              }
            }
          }
        }
      }

      if (pendingOps.isNotEmpty) {
        await flushBatch();
      }
      onProgress?.call(1.0);

      return BackupRestoreSummary(
        totalRestored: totalRestored,
        totalSkipped: totalSkipped,
        collectionCounts: collectionCounts,
        skippedDetails: skippedDetails,
        exactMirrorMode: exactMirror,
      );
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  /// Restores library data from a JSON backup file (Mobile / Desktop).
  Future<BackupRestoreSummary> restoreFromBackup(
    String libraryId,
    File backupFile, {
    void Function(double)? onProgress,
    bool exactMirror = false,
  }) async {
    try {
      if (!await backupFile.exists()) throw Exception('Backup file not found.');
      final bytes = await backupFile.readAsBytes();
      return await restoreFromBackupBytes(
        libraryId,
        bytes,
        onProgress: onProgress,
        exactMirror: exactMirror,
      );
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

    // 1. Delete any stale trailing chunks from an earlier larger snapshot on the same day
    try {
      final existingChunks = await snapshotRef.collection('chunks').get();
      if (existingChunks.docs.isNotEmpty) {
        final delBatch = _firestore.batch();
        int delCount = 0;
        for (final cDoc in existingChunks.docs) {
          final idx = int.tryParse(cDoc.id);
          if (idx == null || idx >= totalChunks) {
            delBatch.delete(cDoc.reference);
            delCount++;
          }
        }
        if (delCount > 0) await delBatch.commit();
      }
    } catch (_) {}

    // 2. Commit payload chunks in safe batches (max 15 chunks = ~6 MB per batch, well under Firestore 10 MB limit)
    const int chunksPerBatch = 15;
    for (int startIdx = 0; startIdx < totalChunks; startIdx += chunksPerBatch) {
      final WriteBatch chunkBatch = _firestore.batch();
      final int endIdx = (startIdx + chunksPerBatch < totalChunks) ? startIdx + chunksPerBatch : totalChunks;
      for (int i = startIdx; i < endIdx; i++) {
        final start = i * _maxChunkChars;
        final end = (start + _maxChunkChars < base64Payload.length)
            ? start + _maxChunkChars
            : base64Payload.length;
        final chunkStr = base64Payload.substring(start, end);

        final chunkDocRef = snapshotRef.collection('chunks').doc(i.toString());
        chunkBatch.set(chunkDocRef, {
          'index': i,
          'data': chunkStr,
        });
      }
      await chunkBatch.commit();
    }

    // 3. Save metadata document AFTER all chunks succeed so list readers never hit partial snapshots
    await snapshotRef.set({
      'dateKey': dateKey,
      'createdAt': FieldValue.serverTimestamp(),
      'sizeBytes': rawBytes.length,
      'compressedSizeBytes': payloadBytes.length,
      'chunkCount': totalChunks,
      'isCompressed': isCompressed,
      'formatVersion': 3,
      'isComplete': true,
    });

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
      if (libraryId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final scopedKey = '${_keyLastDailyBackup}_$libraryId';
      final lastDate = prefs.getString(scopedKey);

      if (lastDate == todayStr) {
        // Already backed up today for this library
        return;
      }

      await saveDailyCloudSnapshot(libraryId);
      await prefs.setString(scopedKey, todayStr);
      if (kDebugMode) debugPrint('Daily automated backup snapshot created for $libraryId on $todayStr');
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
