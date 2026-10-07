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

enum DownloadState { idle, downloading, completed, failed, permissionRequired }

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String storeUrl;
  final bool isForceUpdate;
  final String message;
  final List<String> releaseNotes;

  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.storeUrl,
    required this.isForceUpdate,
    required this.message,
    required this.releaseNotes,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json, {required bool isIos}) {
    // Support BOTH formats:
    // 1. Flat format  (our publish script): { "versionCode": 2, "apkUrl": "...", ... }
    // 2. Nested format: { "android": { "versionCode": 2, ... }, "ios": { ... } }
    final platformKey = isIos ? 'ios' : 'android';
    final nested = json[platformKey] as Map<String, dynamic>?;
    // Use nested if present, otherwise fall back to flat root
    final data = nested ?? json;

    // releaseNotes can be a String (our flat format) or List<String> (nested format)
    final rawNotes = data['releaseNotes'];
    List<String> notes;
    if (rawNotes is List) {
      notes = rawNotes.map((e) => e.toString()).toList();
    } else if (rawNotes is String && rawNotes.isNotEmpty) {
      // Split on '. ' or newlines for readability
      notes = rawNotes.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty).toList();
    } else {
      notes = [];
    }

    return UpdateInfo(
      versionCode: (data['versionCode'] as num?)?.toInt() ?? 0,
      versionName: (data['versionName'] ?? '').toString(),
      apkUrl: (data['apkUrl'] ?? (isIos ? data['iosUrl'] : data['apkUrl']) ?? '').toString(),
      storeUrl: (data['storeUrl'] ?? '').toString(),
      isForceUpdate: data['forceUpdate'] == true,
      message: 'Version ${data['versionName'] ?? '?'} is ready to install.',
      releaseNotes: notes,
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

  const UpdateState({
    this.status = UpdateStatus.upToDate,
    this.info,
    this.downloadState = DownloadState.idle,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateInfo? info,
    DownloadState? downloadState,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
  }) {
    return UpdateState(
      status: status ?? this.status,
      info: info ?? this.info,
      downloadState: downloadState ?? this.downloadState,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage,
    );
  }
}

class ForceUpdateService extends Notifier<UpdateState> {
  static const _channel = MethodChannel('com.studylibrary.app/installer');
  static const _prefDismissedVersionKey = 'dismissed_update_version';
  static const _prefDismissedTimeKey = 'dismissed_update_time';
  static const _metadataUrl = 'https://study-lib-mgmt-2026.web.app/update.json';

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  @override
  UpdateState build() {
    // Start silent background check after build
    Future.microtask(() => checkForUpdate());
    return const UpdateState();
  }

  /// Initialize Firebase Remote Config defaults
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

  /// Check for updates
  Future<void> checkForUpdate({bool manualCheck = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;

      // 1. Fetch Hosting update.json FIRST (direct source of truth)
      final isIos = !kIsWeb && Platform.isIOS;
      final updateInfo = await _fetchUpdateMetadata(isIos: isIos);

      if (updateInfo == null) {
        if (manualCheck) {
          state = state.copyWith(status: UpdateStatus.upToDate);
        }
        return;
      }

      // 2. Check Remote Config safely without blocking
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
        state = state.copyWith(
          status: UpdateStatus.forceUpdate,
          info: updateInfo,
        );
        return;
      }

      // Check if newer version is available (supports ABI-split codes & semantic versions)
      final hasNewerVersion = _isNewerVersion(
        updateInfo.versionName,
        updateInfo.versionCode,
        packageInfo.version,
        currentVersionCode,
      );

      if (hasNewerVersion) {
        if (manualCheck) {
          // Explicit user check in Settings: always show
          state = state.copyWith(
            status: UpdateStatus.optionalUpdate,
            info: updateInfo,
          );
        } else {
          // Silent check: observe 24-hr cooldown
          final prefs = await SharedPreferences.getInstance();
          final dismissedVersion = prefs.getInt(_prefDismissedVersionKey) ?? 0;
          final dismissedTimeMs = prefs.getInt(_prefDismissedTimeKey) ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;

          final isCooldownActive = (dismissedVersion == updateInfo.versionCode) &&
              (now - dismissedTimeMs < const Duration(hours: 24).inMilliseconds);

          if (!isCooldownActive) {
            state = state.copyWith(
              status: UpdateStatus.optionalUpdate,
              info: updateInfo,
            );
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

  /// Dismiss update card for 24 hours
  Future<void> dismissLater() async {
    if (state.info != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefDismissedVersionKey, state.info!.versionCode);
      await prefs.setInt(_prefDismissedTimeKey, DateTime.now().millisecondsSinceEpoch);
    }
    state = state.copyWith(status: UpdateStatus.upToDate);
  }

  /// Download and install the update
  Future<void> startUpdate() async {
    final info = state.info;
    if (info == null) return;

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
      state = state.copyWith(
        downloadState: DownloadState.failed,
        errorMessage: 'Invalid download link.',
      );
      return;
    }

    // Check unknown app install permission on Android
    try {
      final canInstall = await _channel.invokeMethod<bool>('canInstallPackages') ?? true;
      if (!canInstall) {
        state = state.copyWith(downloadState: DownloadState.permissionRequired);
        return;
      }
    } catch (_) {}

    state = state.copyWith(
      downloadState: DownloadState.downloading,
      progress: 0.0,
      downloadedBytes: 0,
      totalBytes: 0,
      errorMessage: null,
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(info.apkUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Download failed with server code ${response.statusCode}');
      }

      final total = response.contentLength;
      int received = 0;

      final sink = apkFile.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;

        final prog = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        state = state.copyWith(
          progress: prog,
          downloadedBytes: received,
          totalBytes: total > 0 ? total : 0,
        );
      }

      await sink.flush();
      await sink.close();
      client.close();

      state = state.copyWith(downloadState: DownloadState.completed);

      // Trigger native package installer
      await _installApk(apkFile.path);
    } catch (e) {
      state = state.copyWith(
        downloadState: DownloadState.failed,
        errorMessage: 'Download failed. Please check your internet connection.',
      );
    }
  }

  /// Request Android install permission
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

    // Normalize ABI offset for split APKs:
    // e.g. 2005 (arm64) % 1000 = 5, 2006 % 1000 = 6, 6 > 5 = true
    final normRemote = remoteCode >= 1000 ? (remoteCode % 1000) : remoteCode;
    final normLocal = localCode >= 1000 ? (localCode % 1000) : localCode;
    if (normRemote > normLocal) return true;
    if (normRemote < normLocal) return false;

    // Fall back to semantic version (e.g. "1.5.0" vs "1.4.0")
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
