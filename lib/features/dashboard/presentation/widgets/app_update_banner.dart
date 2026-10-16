import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/services/force_update_service.dart';

class AppUpdateBanner extends ConsumerWidget {
  const AppUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateServiceProvider);
    final theme = Theme.of(context);

    if (updateState.status == UpdateStatus.upToDate || updateState.info == null) {
      return const SizedBox.shrink();
    }

    final info = updateState.info!;
    final isForce = updateState.status == UpdateStatus.forceUpdate;
    final dl = updateState.downloadState;

    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isDark ? 3 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          width: isDark ? 1.5 : 1.0,
        ),
      ),
      color: isDark
          ? theme.colorScheme.surfaceContainerHigh
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.primary.withValues(alpha: 0.25)
                        : theme.colorScheme.primary.withValues(alpha: 0.15),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      Text(
                        'Version ${info.versionName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              info.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white : null,
              ),
            ),

            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...info.releaseNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      Expanded(
                        child: Text(
                          note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Downloading ───────────────────────────────────────────
            if (dl == DownloadState.downloading) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: updateState.progress > 0 ? updateState.progress : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Pause button
                  IconButton(
                    icon: const Icon(Icons.pause_circle_filled_rounded),
                    tooltip: 'Pause',
                    onPressed: () => ref.read(updateServiceProvider.notifier).pauseUpdate(),
                    color: theme.colorScheme.primary,
                    iconSize: 28,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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

            // ── Paused ───────────────────────────────────────────────
            ] else if (dl == DownloadState.paused) ...[
              LinearProgressIndicator(
                value: updateState.progress > 0 ? updateState.progress : null,
                borderRadius: BorderRadius.circular(4),
                color: Colors.orange,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paused — ${(updateState.progress * 100).toStringAsFixed(0)}% done',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (updateState.totalBytes > 0)
                    Text(
                      '${_formatBytes(updateState.downloadedBytes)} / ${_formatBytes(updateState.totalBytes)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => ref.read(updateServiceProvider.notifier).resumeUpdate(),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Resume Download'),
              ),

            // ── Completed — Show Install Button ───────────────────────
            ] else if (dl == DownloadState.completed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Download complete!',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          if (updateState.totalBytes > 0)
                            Text(
                              '${_formatBytes(updateState.totalBytes)} ready to install',
                              style: const TextStyle(fontSize: 12, color: Colors.green),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => ref.read(updateServiceProvider.notifier).installUpdate(),
                      icon: const Icon(Icons.install_mobile_rounded, size: 18),
                      label: const Text('Install Now'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ],
                ),
              ),

            // ── Permission Required ───────────────────────────────────
            ] else if (dl == DownloadState.permissionRequired) ...[
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
                      onPressed: () =>
                          ref.read(updateServiceProvider.notifier).requestInstallPermission(),
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Open Settings'),
                    ),
                  ],
                ),
              ),

            // ── Failed ───────────────────────────────────────────────
            ] else if (dl == DownloadState.failed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        updateState.errorMessage ?? 'Download failed. Please try again.',
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(updateServiceProvider.notifier).startUpdate(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),

            // ── Idle — Action Buttons ─────────────────────────────────
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isForce)
                    TextButton(
                      onPressed: () => ref.read(updateServiceProvider.notifier).dismissLater(),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('Later'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => ref.read(updateServiceProvider.notifier).startUpdate(),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Update Now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
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
