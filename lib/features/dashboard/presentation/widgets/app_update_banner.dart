import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/services/force_update_service.dart';

class AppUpdateBanner extends ConsumerWidget {
  const AppUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateServiceProvider);
    final theme = Theme.of(context);

    // If up to date or no update info, show nothing
    if (updateState.status == UpdateStatus.upToDate || updateState.info == null) {
      return const SizedBox.shrink();
    }

    final info = updateState.info!;
    final isForce = updateState.status == UpdateStatus.forceUpdate;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.system_update_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isForce ? '⚠️ Required Update Available' : '✨ New Version Available',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Version ${info.versionName}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              info.message,
              style: theme.textTheme.bodyMedium,
            ),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...info.releaseNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(note, style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Download State UI
            if (updateState.downloadState == DownloadState.downloading) ...[
              LinearProgressIndicator(
                value: updateState.progress > 0 ? updateState.progress : null,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(updateState.progress * 100).toStringAsFixed(0)}% downloaded',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (updateState.totalBytes > 0)
                    Text(
                      '${_formatBytes(updateState.downloadedBytes)} / ${_formatBytes(updateState.totalBytes)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ] else if (updateState.downloadState == DownloadState.permissionRequired) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Android requires permission to install apps from Cozy Corner. Please enable "Allow from this source".',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => ref.read(updateServiceProvider.notifier).requestInstallPermission(),
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Open Settings'),
                    ),
                  ],
                ),
              ),
            ] else if (updateState.downloadState == DownloadState.failed) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      updateState.errorMessage ?? 'Download failed.',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(updateServiceProvider.notifier).startUpdate(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ] else ...[
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isForce)
                    TextButton(
                      onPressed: () => ref.read(updateServiceProvider.notifier).dismissLater(),
                      child: const Text('Later'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => ref.read(updateServiceProvider.notifier).startUpdate(),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Update Now'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}
