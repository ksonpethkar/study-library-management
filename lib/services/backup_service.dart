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

  /// Creates a JSON backup file containing all library collections.
  Future<File> createBackup(String libraryId) async {
    final data = <String, dynamic>{
      'version': 1,
      'libraryId': libraryId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final collections = ['students', 'seats', 'sections', 'plans', 'receipts', 'payments', 'settings'];

    for (final col in collections) {
      final snapshot = await _firestore.collection('libraries').doc(libraryId).collection(col).get();
      data[col] = snapshot.docs.map((doc) => doc.data()).toList();
    }

    final jsonString = jsonEncode(data);
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/backup_${libraryId}_${DateTime.now().millisecondsSinceEpoch}.json');
    return await file.writeAsString(jsonString);
  }

  /// Restores library data from a JSON backup file.
  Future<void> restoreFromBackup(String libraryId, File backupFile, {void Function(double)? onProgress}) async {
    try {
      if (!await backupFile.exists()) throw Exception('Backup file not found.');
      final jsonString = await backupFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      if (data['version'] != 1) throw Exception('Unsupported backup version.');
      if (data['libraryId'] != libraryId) throw Exception('Backup file belongs to a different library.');

      final collections = ['students', 'seats', 'sections', 'plans', 'receipts', 'payments', 'settings'];
      final batch = _firestore.batch();
      int totalOperations = 0;
      int completedOperations = 0;

      // Count operations
      for (final col in collections) {
        if (data[col] != null) {
          totalOperations += (data[col] as List).length;
        }
      }

      if (totalOperations == 0) return;

      int batchCount = 0;
      for (final col in collections) {
        if (data[col] == null) continue;
        final list = data[col] as List<dynamic>;
        
        for (final item in list) {
          final docData = item as Map<String, dynamic>;
          final docId = docData['id'] as String?;
          if (docId == null) continue;

          final docRef = _firestore.collection('libraries').doc(libraryId).collection(col).doc(docId);
          batch.set(docRef, docData, SetOptions(merge: true));
          batchCount++;
          completedOperations++;

          // Firestore batches are limited to 500 operations
          if (batchCount >= 490) {
            await batch.commit();
            batchCount = 0;
            if (onProgress != null) onProgress(completedOperations / totalOperations);
          }
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
        if (onProgress != null) onProgress(1.0);
      }
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  /// Gets the estimated size of the backup in bytes by calculating average document size.
  Future<int> getBackupSize(String libraryId) async {
    // This is an estimation since Firestore doesn't provide exact collection size easily.
    int estimatedBytes = 0;
    final collections = ['students', 'seats', 'sections', 'plans', 'receipts', 'payments', 'settings'];
    for (final col in collections) {
      final snapshot = await _firestore.collection('libraries').doc(libraryId).collection(col).count().get();
      // Assume average doc size is 1KB
      estimatedBytes += (snapshot.count ?? 0) * 1024;
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
