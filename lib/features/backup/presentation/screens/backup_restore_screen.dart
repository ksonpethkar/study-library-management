import 'dart:convert';
import 'dart:io' show File;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/file_download_helper.dart';
import 'package:study_library/services/backup_service.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  double _restoreProgress = 0.0;
  String _statusText = '';

  Future<void> _createBackup() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    setState(() {
      _isBackingUp = true;
      _statusText = 'Generating full JSON export...';
    });

    try {
      final service = BackupService();
      final jsonString = await service.generateBackupJson(libraryId);
      final bytes = await compute(utf8.encode, jsonString);

      final libName = ref.read(currentLibraryProvider).value?.name.trim();
      final displayName = libName?.isNotEmpty == true ? libName! : 'Library';
      final sanitizedName =
          displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      final fileName =
          '${sanitizedName}_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

      // Cross-platform download: Blob download on Web, File Share on Mobile/Desktop
      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );

      AuditLogger().log(
        action: AuditAction.exported,
        entityType: AuditEntity.settings,
        libraryId: libraryId,
        details: {'type': 'full_json_backup', 'fileName': fileName, 'size': bytes.length},
      ).ignore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup downloaded successfully! ($fileName) ✓'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _statusText = '';
        });
      }
    }
  }

  Future<void> _triggerCloudSnapshot() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    setState(() {
      _isBackingUp = true;
      _statusText = 'Saving daily cloud snapshot...';
    });

    try {
      final service = BackupService();
      await service.saveDailyCloudSnapshot(libraryId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily cloud snapshot saved successfully! ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Snapshot failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _statusText = '';
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Restore Library Data'),
          ],
        ),
        content: const Text(
          'Warning: Restoring from a backup file will merge and update all records in this library. Existing records with matching IDs will be updated.\n\nAre you sure you want to proceed?',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed with Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (pickedFiles.isEmpty) return;

    final pickedFile = pickedFiles.first;
    List<int>? fileBytes;
    try {
      fileBytes = await pickedFile.xFile.readAsBytes();
    } catch (_) {
      if (pickedFile.path != null && !kIsWeb) {
        try {
          final f = File(pickedFile.path!);
          if (await f.exists()) {
            fileBytes = await f.readAsBytes();
          }
        } catch (_) { /* intentionally silent */ }
      }
    }

    if (fileBytes == null || fileBytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected backup file.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRestoring = true;
      _restoreProgress = 0.0;
      _statusText = 'Restoring records...';
    });

    try {
      final service = BackupService();
      await service.restoreFromBackupBytes(
        libraryId,
        fileBytes,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _restoreProgress = progress;
              _statusText = 'Restoring records (${(progress * 100).toInt()}%)...';
            });
          }
        },
      );

      AuditLogger().log(
        action: AuditAction.imported,
        entityType: AuditEntity.settings,
        libraryId: libraryId,
        details: {'type': 'full_json_restore', 'fileName': pickedFile.name},
      ).ignore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data restored successfully! ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusText = '';
        });
      }
    }
  }

  Future<void> _restoreFromCloudSnapshot(String docId, Map<String, dynamic> snapshotData) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final dateKey = snapshotData['dateKey'] ?? docId;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore Cloud Snapshot ($dateKey)'),
        content: Text(
          'Are you sure you want to restore the automatic snapshot from $dateKey? All library records will be synced to this state.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Snapshot'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isRestoring = true;
      _statusText = 'Downloading cloud snapshot ($dateKey)...';
    });

    try {
      final service = BackupService();
      final backupPayload = await service.getDailyCloudSnapshotJson(
        libraryId,
        docId,
        snapshotData,
      );

      setState(() {
        _statusText = 'Restoring records...';
      });

      await service.restoreFromJsonString(
        libraryId,
        backupPayload,
        onProgress: (p) => setState(() => _restoreProgress = p),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloud snapshot ($dateKey) restored successfully! ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusText = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminHome),
        ),
        title: const Text('Backup & Restore'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.cloud_done_rounded, color: Colors.green.shade800, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Automated Cloud Backups Active',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Daily snapshots are retained in Cloud Firestore for 7 days. Export or restore at any time.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isRestoring || _isBackingUp) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _isRestoring && _restoreProgress > 0 ? _restoreProgress : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusText,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text('Manual Export & Import', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 420;
                if (isSmall) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (_isBackingUp || _isRestoring) ? null : _createBackup,
                          icon: _isBackingUp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download_rounded),
                          label: const Text('Export JSON Backup'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: (_isBackingUp || _isRestoring) ? null : _restoreBackup,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Restore from File'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_isBackingUp || _isRestoring) ? null : _createBackup,
                        icon: _isBackingUp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_rounded),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Export JSON Backup'),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isBackingUp || _isRestoring) ? null : _restoreBackup,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Restore from File'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Daily Cloud Snapshots (Rolling 7 Days)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: (_isBackingUp || _isRestoring) ? null : _triggerCloudSnapshot,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('Snapshot Now'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (libraryId.isNotEmpty)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: BackupService().streamDailySnapshots(libraryId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.history_rounded, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No daily snapshots created yet.'),
                              const SizedBox(height: 4),
                              Text(
                                'Tap "Snapshot Now" or daily auto-backup will generate one on first login each day.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final dateKey = data['dateKey'] ?? docs[index].id;
                      final sizeBytes = data['sizeBytes'] as int? ?? 0;
                      final sizeKb = (sizeBytes / 1024).toStringAsFixed(1);
                      final rawTs = data['createdAt'];
                      final createdAt = rawTs is Timestamp ? rawTs.toDate() : null;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0F2FE),
                            child: Icon(Icons.cloud_sync_rounded, color: Color(0xFF0284C7)),
                          ),
                          title: Text(
                            'Snapshot: $dateKey',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : "Automated"}  •  $sizeKb KB',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: TextButton.icon(
                            onPressed: (_isBackingUp || _isRestoring)
                                ? null
                                : () => _restoreFromCloudSnapshot(docs[index].id, data),
                            icon: const Icon(Icons.restore_rounded, size: 16),
                            label: const Text('Restore'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
