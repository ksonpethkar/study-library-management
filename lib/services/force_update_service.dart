import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, HttpClient, HttpHeaders, FileMode, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

enum UpdateStatus { upToDate, optionalUpdate, forceUpdate, checkFailed }

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
  final bool isWebUpdate;

  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.storeUrl,
    required this.isForceUpdate,
    required this.message,
    required this.releaseNotes,
    this.apkSize = '51.8 MB',
    this.isWebUpdate = false,
  });

  factory UpdateInfo.fromJson(
    Map<String, dynamic> json, {
    required bool isIos,
    required bool isWeb,
  }) {
    if (isWeb) {
      final webData = (json['web'] as Map<String, dynamic>?) ?? json;
      final rawNotes = webData['releaseNotes'] ?? json['releaseNotes'];
      List<String> notes = [];
      if (rawNotes is List) {
        notes = rawNotes.map((e) => e.toString()).toList();
      } else if (rawNotes is String && rawNotes.isNotEmpty) {
        notes = rawNotes.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty).toList();
      }

      final vCode = (webData['buildNumber'] as num?)?.toInt() ??
          (json['versionCode'] as num?)?.toInt() ??
          56;
      final vName = (webData['version'] ?? json['versionName'] ?? json['latestVersion'] ?? '1.5.48').toString();

      return UpdateInfo(
        versionCode: vCode,
        versionName: vName,
        apkUrl: '',
        storeUrl: '',
        isForceUpdate: false,
        message: 'A fresh web app update is available. Reload to get the latest features.',
        releaseNotes: notes,
        isWebUpdate: true,
      );
    }

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
    final size = (data['apkSize'] ?? '51.8 MB').toString();

    return UpdateInfo(
      versionCode: vCode,
      versionName: vName,
      apkUrl: downloadLink,
      storeUrl: (data['storeUrl'] ?? '').toString(),
      isForceUpdate: data['forceUpdate'] == true,
      message: 'Version ${vName.isNotEmpty ? vName : '?'} is ready to install.',
      releaseNotes: notes,
      apkSize: size.isNotEmpty && size != 'null' ? size : '51.8 MB',
      isWebUpdate: false,
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
    } catch (_) { /* intentionally silent */ }
  }

  /// Returns the persistent APK file path (documents dir, not temp)
  Future<File> _getApkFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/studylibrary_update.apk');
  }

  /// Verifies that the remote APK file is actually reachable on the CDN/server before advertising an update.
  /// Prevents phantom updates and 404 download errors.
  Future<bool> _verifyApkExists(String apkUrl) async {
    if (apkUrl.isEmpty || !apkUrl.startsWith('https://')) return false;
    try {
      final uri = Uri.parse(apkUrl);
      final response = await http.head(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        final cl = int.tryParse(response.headers['content-length'] ?? '') ?? 0;
        // If content-length is reported and under 1MB, it's not a valid APK binary
        if (cl > 0 && cl < 1024 * 1024) {
          if (kDebugMode) debugPrint('APK HEAD check: File size too small ($cl bytes). Suppressing.');
          return false;
        }
        return true;
      }
      if (kDebugMode) debugPrint('APK HEAD check returned HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('APK HEAD check error: $e');
      return false;
    }
  }

  /// Check for updates with strict platform segregation and artifact verification.
  Future<void> checkForUpdate({bool manualCheck = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final isIos = !kIsWeb && Platform.isIOS;
      final updateInfo = await _fetchUpdateMetadata(isIos: isIos, isWeb: kIsWeb);

      if (updateInfo == null) {
        if (manualCheck) {
          state = state.copyWith(
            status: UpdateStatus.checkFailed,
            errorMessage: 'Unable to connect to update server. Please check your internet connection.',
          );
        }
        return;
      }

      // ── WEB APP PLATFORM HANDLING ──────────────────────────────────────────
      // Web apps do NOT use APK installers or native package channels.
      if (kIsWeb) {
        // On web, compare client version code against the web manifest
        final currentWebCode = int.tryParse(packageInfo.buildNumber) ?? 56;
        final hasNewerWebVersion = updateInfo.versionCode > currentWebCode;

        if (hasNewerWebVersion) {
          state = state.copyWith(
            status: UpdateStatus.optionalUpdate,
            info: updateInfo,
            errorMessage: null,
          );
        } else {
          state = state.copyWith(
            status: UpdateStatus.upToDate,
            info: updateInfo,
            errorMessage: manualCheck
                ? 'Web portal is running the latest version (v${updateInfo.versionName}).'
                : null,
          );
        }
        return;
      }

      // ── NATIVE MOBILE APP HANDLING (Android APK / iOS) ─────────────────────
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;

      bool isRemoteForce = false;
      try {
        await _initRemoteConfig();
        final minVersionCode = _remoteConfig.getInt('min_version_code');
        final remoteForceUpdate = _remoteConfig.getBool('force_update');
        isRemoteForce = (remoteForceUpdate && currentVersionCode < minVersionCode);
      } catch (_) { /* intentionally silent */ }

      final isForce = isRemoteForce ||
          (updateInfo.isForceUpdate && currentVersionCode < updateInfo.versionCode);

      final hasNewerVersion = _isNewerVersion(
        updateInfo.versionName,
        updateInfo.versionCode,
        packageInfo.version,
        currentVersionCode,
      );

      if (hasNewerVersion) {
        // GHOST RELEASE PREVENTION:
        // Only trigger update banner if the actual APK binary is live and verified on the CDN/Download page.
        if (!isIos && updateInfo.apkUrl.isNotEmpty) {
          final apkExists = await _verifyApkExists(updateInfo.apkUrl);
          if (!apkExists) {
            if (kDebugMode) {
              debugPrint('Update announced (${updateInfo.versionName}), but APK binary is not reachable on CDN. Suppressing update banner.');
            }
            state = state.copyWith(
              status: UpdateStatus.upToDate,
              info: updateInfo,
              errorMessage: manualCheck
                  ? 'A new build v${updateInfo.versionName} has been announced, but the APK package is still being uploaded to the download page. Please check back shortly.'
                  : null,
            );
            return;
          }
        }

        if (isForce) {
          state = state.copyWith(
            status: UpdateStatus.forceUpdate,
            info: updateInfo,
            errorMessage: null,
          );
          return;
        }

        if (manualCheck) {
          state = state.copyWith(
            status: UpdateStatus.optionalUpdate,
            info: updateInfo,
            errorMessage: null,
          );
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
              } catch (_) { /* intentionally silent */ }

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
                  errorMessage: null,
                );
                return;
              } else {
                try {
                  await apkFile.delete();
                } catch (_) { /* intentionally silent */ }
              }
            }
            state = state.copyWith(
              status: UpdateStatus.optionalUpdate,
              info: updateInfo,
              errorMessage: null,
            );
          }
        }
      } else {
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          info: updateInfo,
          errorMessage: manualCheck
              ? 'You have the latest version of Study Library (v${packageInfo.version} build $currentVersionCode).'
              : null,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Update check failed: $e');
      if (manualCheck) {
        state = state.copyWith(
          status: UpdateStatus.checkFailed,
          errorMessage: 'Failed to check for updates. Please verify your internet connection.',
        );
      } else {
        state = state.copyWith(status: UpdateStatus.upToDate);
      }
    }
  }

  /// Dismiss update card and reminders for 24 hours (does NOT clear downloaded APK path)
  Future<void> dismissLater() async {
    if (state.info != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefDismissedVersionKey, state.info!.versionCode);
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_prefDismissedTimeKey, now);
      await prefs.setInt('last_update_popup_time', now);
      final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      await prefs.setString('last_update_popup_date', todayStr);
    }
    state = state.copyWith(status: UpdateStatus.upToDate);
  }

  /// Start or resume an APK download (Android native only)
  Future<void> startUpdate() async {
    if (kIsWeb) return;

    final info = state.info;
    if (info == null) return;

    // iOS: open App Store
    if (Platform.isIOS) {
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
      } catch (_) { /* intentionally silent */ }

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
        } catch (_) { /* intentionally silent */ }
      }
    }

    // Check permission
    try {
      final canInstall = await _channel.invokeMethod<bool>('canInstallPackages') ?? true;
      if (!canInstall) {
        state = state.copyWith(downloadState: DownloadState.permissionRequired);
        return;
      }
    } catch (_) { /* intentionally silent */ }

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

  /// Cancel an active or paused download, delete partial file, and reset to idle
  Future<void> cancelUpdate() async {
    _isPaused = true;
    _activeClient?.close(force: true);
    _activeClient = null;
    try {
      final apkFile = await _getApkFile();
      if (await apkFile.exists()) {
        await apkFile.delete();
      }
    } catch (_) { /* intentionally silent */ }
    state = state.copyWith(
      downloadState: DownloadState.idle,
      progress: 0.0,
      downloadedBytes: 0,
      clearApkPath: true,
      errorMessage: null,
    );
  }

  /// Resume a paused download
  Future<void> resumeUpdate() async {
    final info = state.info;
    if (info == null || kIsWeb) return;

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

      if (resumeFrom > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$resumeFrom-');
      }

      final response = await request.close();

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final totalBytes = resumeFrom + (contentLength > 0 ? contentLength : 0);
      int received = resumeFrom;

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

      state = state.copyWith(
        downloadState: DownloadState.completed,
        downloadedApkPath: apkFile.path,
        progress: 1.0,
        downloadedBytes: received,
        totalBytes: totalBytes > 0 ? totalBytes : received,
      );
    } catch (e) {
      if (_isPaused) return;
      _activeClient = null;
      state = state.copyWith(
        downloadState: DownloadState.failed,
        errorMessage: 'Download failed. Tap to try again.',
      );
    }
  }

  /// Install the already-downloaded APK
  Future<void> installUpdate() async {
    if (kIsWeb) return;

    final path = state.downloadedApkPath;
    if (path == null || path.isEmpty) {
      state = state.copyWith(downloadState: DownloadState.idle, clearApkPath: true);
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      state = state.copyWith(downloadState: DownloadState.idle, clearApkPath: true);
      return;
    }

    try {
      final canInstall = await _channel.invokeMethod<bool>('canInstallPackages') ?? true;
      if (!canInstall) {
        state = state.copyWith(downloadState: DownloadState.permissionRequired);
        await requestInstallPermission();
        return;
      }
    } catch (_) { /* intentionally silent */ }

    try {
      final isValid = await _channel.invokeMethod<bool>('verifyApk', {'filePath': path}) ?? false;
      if (!isValid) {
        try {
          await file.delete();
        } catch (_) { /* intentionally silent */ }
        state = state.copyWith(
          downloadState: DownloadState.failed,
          errorMessage: 'Downloaded file was incomplete. Please tap to re-download.',
          clearApkPath: true,
        );
        return;
      }
    } catch (_) { /* intentionally silent */ }

    await _installApk(path);
  }

  Future<void> requestInstallPermission() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
      state = state.copyWith(downloadState: DownloadState.idle);
    } catch (_) { /* intentionally silent */ }
  }

  Future<void> _installApk(String filePath) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      state = state.copyWith(
        downloadState: DownloadState.failed,
        errorMessage: 'Could not open package installer: $e',
      );
    }
  }

  Future<UpdateInfo?> _fetchUpdateMetadata({required bool isIos, required bool isWeb}) async {
    try {
      final cacheBustedUrl = '$_metadataUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(
        Uri.parse(cacheBustedUrl),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return UpdateInfo.fromJson(json, isIos: isIos, isWeb: isWeb);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Fetch update metadata error: $e');
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
    } catch (_) { /* intentionally silent */ }

    return false;
  }
}

final updateServiceProvider =
    NotifierProvider<ForceUpdateService, UpdateState>(ForceUpdateService.new);
