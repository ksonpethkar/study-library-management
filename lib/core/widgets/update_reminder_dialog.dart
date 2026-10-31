import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/services/force_update_service.dart';

/// Helper that shows a compact update reminder popup on the 1st login/launch of each day (or every 24 hours).
class UpdateReminderDialog {
  static const _prefLastPopupDateKey = 'last_update_popup_date';
  static const _prefLastPopupTimeKey = 'last_update_popup_time';
  static bool _dialogCurrentlyOpen = false;

  /// Checks if an update is available and presents a friendly daily reminder modal.
  static Future<void> checkAndShow(BuildContext context, WidgetRef ref) async {
    try {
      // 1. Wait a moment for dashboard frame to settle
      await Future.delayed(const Duration(milliseconds: 700));
      if (!context.mounted) return;

      final updateState = ref.read(updateServiceProvider);
      // Only show if an update is available and not already marked up-to-date
      if (updateState.info == null ||
          updateState.status == UpdateStatus.upToDate) {
        return;
      }

      final info = updateState.info!;
      final isForce = updateState.status == UpdateStatus.forceUpdate;

      // 2. 24-Hour / 1st Login of the Day Cooldown check
      if (!isForce) {
        final prefs = await SharedPreferences.getInstance();
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final lastDate = prefs.getString(_prefLastPopupDateKey);
        final lastTimeMs = prefs.getInt(_prefLastPopupTimeKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final hoursPassed = (now - lastTimeMs) / (1000 * 60 * 60);

        final isSameDay = lastDate == todayStr;
        final isUnder24Hours = hoursPassed < 24;

        if (isSameDay && isUnder24Hours) {
          // Already shown today on 1st login / within 24 hours, do not show popup again today
          return;
        }

        // Save today's date and timestamp
        await prefs.setString(_prefLastPopupDateKey, todayStr);
        await prefs.setInt(_prefLastPopupTimeKey, now);
      }

      if (_dialogCurrentlyOpen || !context.mounted) return;

      _dialogCurrentlyOpen = true;

      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      await showDialog<void>(
        context: context,
        barrierDismissible: !isForce,
        builder: (dlgContext) {
          return Consumer(
            builder: (context, consumerRef, _) {
              final liveState = consumerRef.watch(updateServiceProvider);
              final liveDownloaded = liveState.downloadState == DownloadState.completed;

              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Icon, Title, and Close Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: liveDownloaded
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : theme.colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              liveDownloaded
                                  ? Icons.check_circle_rounded
                                  : Icons.system_update_rounded,
                              color: liveDownloaded ? Colors.green : theme.colorScheme.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  liveDownloaded
                                      ? 'Update Ready to Install 🎉'
                                      : '✨ New Version Available',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Version ${info.versionName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isForce)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Close',
                              onPressed: () {
                                Navigator.of(dlgContext).pop();
                                consumerRef.read(updateServiceProvider.notifier).dismissLater();
                              },
                            ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Description
                      Text(
                        liveDownloaded
                            ? 'Download is complete (${info.apkSize}). Version ${info.versionName} is ready to install.'
                            : 'Version ${info.versionName} is available with recent features and performance updates.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey.shade800,
                          height: 1.35,
                        ),
                      ),

                      if (info.releaseNotes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: info.releaseNotes.take(2).map((note) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.grey.shade700),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isForce)
                            TextButton(
                              onPressed: () {
                                Navigator.of(dlgContext).pop();
                                consumerRef.read(updateServiceProvider.notifier).dismissLater();
                              },
                              child: const Text('Later (Tomorrow)'),
                            ),
                          const SizedBox(width: 8),
                          if (liveDownloaded)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.of(dlgContext).pop();
                                consumerRef.read(updateServiceProvider.notifier).installUpdate();
                              },
                              icon: const Icon(Icons.install_mobile_rounded, size: 18),
                              label: const Text('Install Now'),
                            )
                          else
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                              ),
                              onPressed: () {
                                Navigator.of(dlgContext).pop();
                                consumerRef.read(updateServiceProvider.notifier).startUpdate();
                              },
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: Text('Download & Update (${info.apkSize})'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Update reminder dialog error: $e');
    } finally {
      _dialogCurrentlyOpen = false;
    }
  }
}
