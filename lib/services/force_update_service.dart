import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateStatus { upToDate, optionalUpdate, forceUpdate }

// Added: paused state for pause/resume support
enum DownloadState { idle, downloading, paused, completed, failed, permissionRequired }

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String storeUrl;
  final bool isForceUpdate;
  final String message;
  final List<String> releaseNotes;
  final String apkSize;

  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.storeUrl,
    required this.isForceUpdate,
    required this.message,
    required this.releaseNotes,
    this.apkSize = '74.0 MB',
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json, {required bool isIos}) {
    final platformKey = isIos ? 'ios' : 'android';
    final nested = json[platformKey] as Map<String, dynamic>?;
    final data = nested ?? json;

    final rawNotes = data['releaseNotes'];
    List<String> notes;
    if (rawNotes is List) {
      notes = rawNotes.map((e) => e.toString()).toList();
    } else if (rawNotes is String && rawNotes.isNotEmpty) {
      notes = rawNotes.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty).toList();
    } else {
      notes = [];
    }

    final vCode = (data['versionCode'] as num?)?.toInt() ??
        (data['latestVersionCode'] as num?)?.toInt() ??
        (data['latestBuild'] as num?)?.toInt() ??
        0;
    final vName = (data['versionName'] ?? data['latestVersion'] ?? '').toString();
    final downloadLink = (data['apkUrl'] ??
            data['downloadUrl'] ??
            (isIos ? data['iosUrl'] : null) ??
            '')
        .toString();
    final size = (data['apkSize'] ?? '74.0 MB').toString();

    return UpdateInfo(
      versionCode: vCode,
      versionName: vName,
      apkUrl: downloadLink,
      storeUrl: (data['storeUrl'] ?? '').toString(),
      isForceUpdate: data['forceUpdate'] == true,
      message: 'Version ${vName.isNotEmpty ? vName : '?'} is ready to install.',
      releaseNotes: notes,
      apkSize: size,
    );
  }
}

class UpdateState {
  final UpdateStatus status;
  final UpdateInfo? info;
  final DownloadState downloadState;
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;
  final String? downloadedApkPath; // persists path after download completes

  const UpdateState({
    this.status = UpdateStatus.upToDate,
    this.info,
    this.downloadState = DownloadState.idle,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.downloadedApkPath,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateInfo? info,
    DownloadState? downloadState,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
    String? downloadedApkPath,
    bool clearApkPath = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      info: info ?? this.info,
      downloadState: downloadState ?? this.downloadState,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage,
      downloadedApkPath: clearApkPath ? null : (downloadedApkPath ?? this.downloadedApkPath),
    );
  }
}

class ForceUpdateService extends Notifier<UpdateState> {
  static const _channel = MethodChannel('com.studylibrary.app/installer');
  static const _prefDismissedVersionKey = 'dismissed_update_version';
  static const _prefDismissedTimeKey = 'dismissed_update_time';
  static const _metadataUrl = 'https://study-lib-mgmt-2026.web.app/update.json';

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // Active download tracking (for pause/resume)
  bool _isPaused = false;
  HttpClient? _activeClient;

  @override
  UpdateState build() {
    Future.microtask(() => checkForUpdate());
    return const UpdateState();
  }

  Future<void> _initRemoteConfig() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _remoteConfig.setDefaults(const {
        'min_version_code': 1,
        'force_update': false,
      });
      await _remoteConfig.fetchAndActivate();
    } catch (_) {}
  }

  /// Returns the persistent APK file path (documents dir, not temp)
  Future<File> _getApkFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/studylibrary_update.apk');
  }

  /// Check for updates
  Future<void> checkForUpdate({bool manualCheck = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;

      final isIos = !kIsWeb && Platform.isIOS;
      final updateInfo = await _fetchUpdateMetadata(isIos: isIos);

      if (updateInfo == null) {
        if (manualCheck) {
          state = state.copyWith(status: UpdateStatus.upToDate);
        }
        return;
      }

      bool isRemoteForce = false;
      try {
        await _initRemoteConfig();
        final minVersionCode = _remoteConfig.getInt('min_version_code');
        final remoteForceUpdate = _remoteConfig.getBool('force_update');
        isRemoteForce = (remoteForceUpdate && currentVersionCode < minVersionCode);
      } catch (_) {}

      final isForce = isRemoteForce ||
          (updateInfo.isForceUpdate && currentVersionCode < updateInfo.versionCode);

      if (isForce) {
        state = state.copyWith(status: UpdateStatus.forceUpdate, info: updateInfo);
        return;
      }

      final hasNewerVersion = _isNewerVersion(
        updateInfo.versionName,
        updateInfo.versionCode,
        packageInfo.version,
        currentVersionCode,
      );

      if (hasNewerVersion) {
        if (manualCheck) {
          state = state.copyWith(status: UpdateStatus.optionalUpdate, info: updateInfo);
        } else {
          final prefs = await SharedPreferences.getInstance();
          final dismissedVersion = prefs.getInt(_prefDismissedVersionKey) ?? 0;
          final dismissedTimeMs = prefs.getInt(_prefDismissedTimeKey) ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;

          final isCooldownActive = (dismissedVersion == updateInfo.versionCode) &&
              (now - dismissedTimeMs < const Duration(hours: 24).inMilliseconds);

          if (!isCooldownActive) {
            final apkFile = await _getApkFile();
            if (await apkFile.exists()) {
              bool isValid = false;
              try {
                isValid = await _channel.invokeMethod<bool>('verifyApk', {'filePath': apkFile.path}) ?? false;
              } catch (_) {}

              if (isValid) {
                final fileSize = await apkFile.length();
                state = state.copyWith(
                  status: UpdateStatus.optionalUpdate,
                  info: updateInfo,
                  downloadState: DownloadState.completed,
                  downloadedApkPath: apkFile.path,
                  progress: 1.0,
                  downloadedBytes: fileSize,
                  totalBytes: fileSize,
                );
                return;
              } else {
                // Incomplete or corrupted file from prior interrupted download — delete cleanly
                try {
                  await apkFile.delete();
                } catch (_) {}
              }
            }
            state = state.copyWith(status: UpdateStatus.optionalUpdate, info: updateInfo);
          }
        }
      } else {
        state = state.copyWith(status: UpdateStatus.upToDate, info: updateInfo);
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      state = state.copyWith(status: UpdateStatus.upToDate);
    }
  }

  /// Dismiss update card for 24 hours (does NOT clear downloaded APK path)
  Future<void> dismissLater() async {
    if (state.info != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefDismissedVersionKey, state.info!.versionCode);
      await prefs.setInt(_prefDismissedTimeKey, DateTime.now().millisecondsSinceEpoch);
    }
    state = state.copyWith(status: UpdateStatus.upToDate);
  }

  /// Start or resume a download
  Future<void> startUpdate() async {
    final info = state.info;
    if (info == null) return;

    // iOS: open App Store
    if (!kIsWeb && Platform.isIOS) {
      if (info.storeUrl.isNotEmpty) {
        final uri = Uri.tryParse(info.storeUrl);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return;
    }

    if (info.apkUrl.isEmpty || !info.apkUrl.startsWith('https://')) {
      state = state.copyWith(downloadState: DownloadState.failed, errorMessage: 'Invalid download link.');
      return;
    }

    // Check if already fully downloaded & valid
    final apkFile = await _getApkFile();
    if (await apkFile.exists()) {
      bool isValid = false;
      try {
        isValid = await _channel.invokeMethod<bool>('verifyApk', {'filePath': apkFile.path}) ?? false;
      } catch (_) {}

      if (isValid) {
        final fileSize = await apkFile.length();
        state = state.copyWith(
          downloadState: DownloadState.completed,
          downloadedApkPath: apkFile.path,
          progress: 1.0,
          downloadedBytes: fileSize,
          totalBytes: fileSize,
        );
        return;
      } else {
        try {
          await apkFile.delete();
        } catch (_) {}
      }
    }

    // Check permission
    try {
      final canInstall = await _channel.invokeMethod<bool>('canInstallPackages') ?? true;
      if (!canInstall) {
        state = state.copyWith(downloadState: DownloadState.permissionRequired);
        return;
      }
    } catch (_) {}

    _isPaused = false;
    await _doDownload(apkFile, info.apkUrl, resumeFrom: 0);
  }

  /// Pause an active download
  void pauseUpdate() {
    _isPaused = true;
    _activeClient?.close(force: true);
    _activeClient = null;
    state = state.copyWith(downloadState: DownloadState.paused);
  }

  /// Resume a paused download
  Future<void> resumeUpdate() async {
    final info = state.info;
    if (info == null) return;

    _isPaused = false;
    final apkFile = await _getApkFile();
    final resumeFrom = await apkFile.exists() ? await apkFile.length() : 0;

    state = state.copyWith(downloadState: DownloadState.downloading);
    await _doDownload(apkFile, info.apkUrl, resumeFrom: resumeFrom);
  }

  Future<void> _doDownload(File apkFile, String apkUrl, {required int resumeFrom}) async {
    state = state.copyWith(
      downloadState: DownloadState.downloading,
      progress: resumeFrom > 0 ? (state.totalBytes > 0 ? resumeFrom / state.totalBytes : 0.0) : 0.0,
      downloadedBytes: resumeFrom,
      errorMessage: null,
    );

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      _activeClient = client;

      final request = await client.getUrl(Uri.parse(apkUrl));

      // Support resume via HTTP Range header
      if (resumeFrom > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$resumeFrom-');
      }

      final response = await request.close();

      // 206 = Partial Content (resume), 200 = full download
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final totalBytes = resumeFrom + (contentLength > 0 ? contentLength : 0);
      int received = resumeFrom;

      // Append if resuming, overwrite if starting fresh
      final sink = apkFile.openWrite(mode: resumeFrom > 0 ? FileMode.append : FileMode.write);

      await for (final chunk in response) {
        if (_isPaused) {
          await sink.flush();
          await sink.close();
          return;
        }
        sink.add(chunk);
        received += chunk.length;

        final prog = totalBytes > 0 ? (received / totalBytes).clamp(0.0, 1.0) : 0.0;
        state = state.copyWith(
          progress: prog,
          downloadedBytes: received,
          totalBytes: totalBytes,
        );
      }

      await sink.flush();
      await sink.close();
      client.close();
      _activeClient = null;

      // ✅ Download complete — show Install button, don't auto-launch
      state = state.copyWith(
        downloadState: DownloadState.completed,
        downloadedApkPath: apkFile.path,
        progress: 1.0,
        downloadedBytes: received,
        totalBytes: totalBytes > 0 ? totalBytes : received,
      );
    } catch (e) {
      if (_isPaused) return; // Intentional cancellation
      _activeClient = null;
      state = state.copyWith(
        downloadState: DownloadState.failed,
        errorMessage: 'Download failed. Tap to try again.',
      );
    }
  }

  /// Install the already-downloaded APK
  Future<void> installUpdate() async {
    final path = state.downloadedApkPath;
    if (path == null || path.isEmpty) {
      // Path lost — restart download
      state = state.copyWith(downloadState: DownloadState.idle, clearApkPath: true);
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      state = state.copyWith(downloadState: DownloadState.idle, clearApkPath: true);
      return;
    }

    // Check package installer permission
    try {
      final canInstall = await _channel.invokeMethod<bool>('canInstallPackages') ?? true;
      if (!canInstall) {
        state = state.copyWith(downloadState: DownloadState.permissionRequired);
        await requestInstallPermission();
        return;
      }
    } catch (_) {}

    // Verify APK archive integrity before launching installer
    try {
      final isValid = await _channel.invokeMethod<bool>('verifyApk', {'filePath': path}) ?? false;
      if (!isValid) {
        try {
          await file.delete();
        } catch (_) {}
        state = state.copyWith(
          downloadState: DownloadState.failed,
          errorMessage: 'Downloaded file was incomplete. Please tap to re-download.',
          clearApkPath: true,
        );
        return;
      }
    } catch (_) {}

    await _installApk(path);
  }

  Future<void> requestInstallPermission() async {
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
      state = state.copyWith(downloadState: DownloadState.idle);
    } catch (_) {}
  }

  Future<void> _installApk(String filePath) async {
    try {
      await _channel.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      state = state.copyWith(
        downloadState: DownloadState.failed,
        errorMessage: 'Could not open package installer: $e',
      );
    }
  }

  Future<UpdateInfo?> _fetchUpdateMetadata({required bool isIos}) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final cacheBustedUrl = '$_metadataUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final request = await client.getUrl(Uri.parse(cacheBustedUrl));
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
      request.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        client.close();
        return UpdateInfo.fromJson(json, isIos: isIos);
      }
    } catch (e) {
      debugPrint('Fetch update metadata error: $e');
    }
    return null;
  }

  static bool _isNewerVersion(
    String remoteVer,
    int remoteCode,
    String localVer,
    int localCode,
  ) {
    if (remoteCode > localCode) return true;

    final normRemote = remoteCode >= 1000 ? (remoteCode % 1000) : remoteCode;
    final normLocal = localCode >= 1000 ? (localCode % 1000) : localCode;
    if (normRemote > normLocal) return true;
    if (normRemote < normLocal) return false;

    try {
      final r = remoteVer.split('.').map((s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
      final l = localVer.split('.').map((s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final rPart = i < r.length ? r[i] : 0;
        final lPart = i < l.length ? l[i] : 0;
        if (rPart > lPart) return true;
        if (rPart < lPart) return false;
      }
    } catch (_) {}

    return false;
  }
}

final updateServiceProvider =
    NotifierProvider<ForceUpdateService, UpdateState>(ForceUpdateService.new);
