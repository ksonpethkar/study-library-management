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
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/services/inactivity_lock_service.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/features/settings/presentation/providers/settings_provider.dart';

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
      _statusText = 'Preparing secure library backup file...';
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
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'backup');
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
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'backup');
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

  void _invalidateAppProviders() {
    ref.invalidate(currentLibraryProvider);
    ref.invalidate(studentsStreamProvider);
    ref.invalidate(sectionsProvider);
    ref.invalidate(plansStreamProvider);
    ref.invalidate(idCardTemplateStreamProvider);
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  Future<({bool confirmed, bool exactMirror})?> _showRestoreConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    bool exactMirror = false;
    return showDialog<({bool confirmed, bool exactMirror})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(height: 1.4, fontSize: 13.5)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: exactMirror,
                    onChanged: (v) => setDialogState(() => exactMirror = v ?? false),
                    title: const Text(
                      'Strict Snapshot Replace Mode',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    subtitle: const Text(
                      'Replaces entire document fields to revert edits made after this snapshot (instead of merging).',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, (confirmed: false, exactMirror: false)),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, (confirmed: true, exactMirror: exactMirror)),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRestoreSummaryDialog(
    BackupRestoreSummary summary, {
    required String sourceLabel,
  }) async {
    if (!mounted) return;
    final prettyNames = <String, String>{
      'students': 'Students',
      'section_seats': 'Hall Desks',
      'sections': 'Hall Sections',
      'plans': 'Plans',
      'payments': 'Payments',
      'receipts': 'Receipts',
      'expenses': 'Expenses',
      'feedback': 'Feedback',
      'settings': 'Settings Docs',
      'announcements': 'Announcements',
      'holidays': 'Holidays',
      'staff': 'Staff Accounts',
      'waiting_list': 'Waiting List',
      'requests': 'Requests',
      'libraryProfile': 'Library Profile',
    };

    final entries = summary.collectionCounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Expanded(child: Text('Restore Verified in Cloud')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$sourceLabel completed. ${summary.totalRestored} database record(s) written cleanly to Cloud Firestore (${summary.exactMirrorMode ? 'Strict Replace' : 'Merge & Update'}).',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              if (entries.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(prettyNames[e.key] ?? e.key, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                              Text('${e.value}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (summary.totalSkipped > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '${summary.totalSkipped} item(s) skipped due to permission or schema validation constraints (healthy records were still restored).',
                  style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final result = await _showRestoreConfirmDialog(
      title: 'Restore Library Data',
      message: 'Restoring from a backup file updates records in Cloud Firestore for this library.',
      confirmLabel: 'Proceed with Restore',
    );

    if (result == null || !result.confirmed) return;

    List<PlatformFile> pickedFiles = const [];
    InactivityLockService.setExternalDialogActive(true);
    try {
      pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } finally {
      InactivityLockService.setExternalDialogActive(false);
    }

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
      _statusText = 'Restoring records (0%)...';
    });

    try {
      final service = BackupService();
      final summary = await service.restoreFromBackupBytes(
        libraryId,
        fileBytes,
        exactMirror: result.exactMirror,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _restoreProgress = progress;
              _statusText = 'Restoring records (${(progress * 100).toInt()}%)...';
            });
          }
        },
      );

      _invalidateAppProviders();

      AuditLogger().log(
        action: AuditAction.imported,
        entityType: AuditEntity.settings,
        libraryId: libraryId,
        details: {
          'type': 'full_json_restore',
          'fileName': pickedFile.name,
          'totalRestored': summary.totalRestored,
          'totalSkipped': summary.totalSkipped,
          'exactMirror': summary.exactMirrorMode,
        },
      ).ignore();

      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusText = '';
        });
        await _showRestoreSummaryDialog(summary, sourceLabel: 'File restore (${pickedFile.name})');
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'backup');
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
    final result = await _showRestoreConfirmDialog(
      title: 'Restore Snapshot ($dateKey)',
      message: 'Restore the automatic cloud snapshot from $dateKey into Cloud Firestore?',
      confirmLabel: 'Restore Snapshot',
    );

    if (result == null || !result.confirmed) return;

    setState(() {
      _isRestoring = true;
      _restoreProgress = 0.0;
      _statusText = 'Downloading cloud snapshot ($dateKey)...';
    });

    try {
      final service = BackupService();
      final backupPayload = await service.getDailyCloudSnapshotJson(
        libraryId,
        docId,
        snapshotData,
      );

      if (mounted) {
        setState(() {
          _statusText = 'Restoring records (0%)...';
        });
      }

      final summary = await service.restoreFromJsonString(
        libraryId,
        backupPayload,
        exactMirror: result.exactMirror,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _restoreProgress = p;
              _statusText = 'Restoring records (${(p * 100).toInt()}%)...';
            });
          }
        },
      );

      _invalidateAppProviders();

      AuditLogger().log(
        action: AuditAction.imported,
        entityType: AuditEntity.settings,
        libraryId: libraryId,
        details: {
          'type': 'cloud_snapshot_restore',
          'dateKey': dateKey,
          'totalRestored': summary.totalRestored,
          'totalSkipped': summary.totalSkipped,
          'exactMirror': summary.exactMirrorMode,
        },
      ).ignore();

      if (mounted) {
        setState(() {
          _isRestoring = false;
          _statusText = '';
        });
        await _showRestoreSummaryDialog(summary, sourceLabel: 'Cloud snapshot ($dateKey)');
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'backup');
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
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_heart_rounded),
            tooltip: 'System Diagnostics & Health',
            onPressed: () => context.push(Routes.adminMaintenance),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20.0,
          20.0,
          20.0,
          80.0 + MediaQuery.of(context).padding.bottom,
        ),
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
                          label: const Text('Export Full Library Backup'),
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
                        label: const Text('Export Library Backup'),
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
              },
            ),

            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Cloud Snapshots',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Rolling 7-day compressed history',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
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
                      final compressedBytes = data['compressedSizeBytes'] as int? ?? 0;
                      final sizeDisplay = compressedBytes > 0
                          ? '${_formatBytes(sizeBytes)} (${_formatBytes(compressedBytes)} zipped)'
                          : _formatBytes(sizeBytes);
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
                            '${createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : "Automated"}  •  $sizeDisplay',
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
