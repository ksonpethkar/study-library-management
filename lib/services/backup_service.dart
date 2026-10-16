import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BackupService provides functionality to export and import library data to/from JSON.
class BackupService {
  final FirebaseFirestore _firestore;

  BackupService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

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
          } catch (_) {}
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

  /// Creates a JSON backup file containing all library collections.
  /// Each document includes its Firestore ID stored under '__docId__' key
  /// so it can be restored to the exact same document reference.
  Future<File> createBackup(String libraryId) async {
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
        debugPrint('Backup: could not read collection $col — $e');
        data[col] = []; // Partial backup: empty list for failed collection
      }
    }

    final jsonString = jsonEncode(data);

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
        '${directory.path}/backup_${libraryId}_${DateTime.now().millisecondsSinceEpoch}.json');
    return await file.writeAsString(jsonString);
  }

  /// Restores library data from a JSON backup file.
  Future<void> restoreFromBackup(String libraryId, File backupFile,
      {void Function(double)? onProgress}) async {
    try {
      if (!await backupFile.exists()) throw Exception('Backup file not found.');
      final jsonString = await backupFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final version = data['version'] as int? ?? 1;
      if (version > 2) throw Exception('Unsupported backup version $version.');
      if (data['libraryId'] != libraryId) {
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
          if (batchCount >= 490) {
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

  /// Gets the estimated size of the backup in bytes by calculating average document size.
  Future<int> getBackupSize(String libraryId) async {
    int estimatedBytes = 0;
    for (final col in _supportedCollections) {
      try {
        final snapshot = await _firestore.collection('libraries').doc(libraryId).collection(col).count().get();
        estimatedBytes += (snapshot.count ?? 0) * 1024;
      } catch (_) {}
    }
    return estimatedBytes;
  }

  static const String _keyLastRollingBackup = 'last_rolling_backup_date';

  /// Automatically snapshots library collections every 7 days without interrupting the user.
  /// Retains the last 4 weekly snapshots and cleans up older ones.
  Future<void> checkAndRunRollingBackup(String libraryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDateRaw = prefs.getString(_keyLastRollingBackup);
      if (lastDateRaw != null) {
        final lastDate = DateTime.tryParse(lastDateRaw);
        if (lastDate != null && DateTime.now().difference(lastDate).inDays < 7) {
          // Less than 7 days since last rolling backup
          return;
        }
      }

      // Execute backup snapshot
      final file = await createBackup(libraryId);
      await prefs.setString(_keyLastRollingBackup, DateTime.now().toIso8601String());
      debugPrint('Rolling 7-day auto-backup created: ${file.path}');

      // Clean up snapshots older than 28 days
      await _cleanupOldBackups(libraryId);
    } catch (e) {
      debugPrint('Silent auto-backup error: $e');
    }
  }

  Future<void> _cleanupOldBackups(String libraryId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync().whereType<File>().where(
        (f) => f.path.contains('backup_${libraryId}_') && f.path.endsWith('.json'),
      ).toList();

      // Sort by modified time descending (newest first)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // Keep newest 4, delete older
      if (files.length > 4) {
        for (int i = 4; i < files.length; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning old backups: $e');
    }
  }
}

/// Provider for BackupService
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});
