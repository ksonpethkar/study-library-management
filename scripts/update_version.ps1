# Usage: .\scripts\update_version.ps1 [-Version "1.5.61"] [-BuildNumber 2078] [-SyncAndroid]
# Synchronizes version across pubspec.yaml, AppConstants, WhatsNewService, version.json, and all update.json mirrors.
param(
    [string]$Version = "",
    [int]$BuildNumber = 0,
    [switch]$SyncAndroid
)

$ErrorActionPreference = 'Stop'

$pubspecPath = "pubspec.yaml"
$pubspec = Get-Content $pubspecPath -Raw -Encoding UTF8

if ($Version -ne "" -and $BuildNumber -gt 0) {
    $pubspec = $pubspec -replace 'version:\s*[\d.]+\+\d+', "version: $Version+$BuildNumber"
    Set-Content -Path $pubspecPath -Value $pubspec -Encoding UTF8 -NoNewline
    $versionName = $Version
    $versionCode = $BuildNumber
} else {
    $verMatch = [regex]::Match($pubspec, 'version:\s*([\d.]+)\+(\d+)')
    if (-not $verMatch.Success) {
        throw "Could not parse version in pubspec.yaml"
    }
    $versionName = $verMatch.Groups[1].Value
    $versionCode = [int]$verMatch.Groups[2].Value
}

Write-Host "Synchronizing Version: $versionName+$versionCode" -ForegroundColor Cyan

# 1. Sync lib/core/constants/app_constants.dart
$appConstPath = "lib\core\constants\app_constants.dart"
if (Test-Path $appConstPath) {
    $appConst = Get-Content $appConstPath -Raw -Encoding UTF8
    $appConst = $appConst -replace "static const String appVersion = '[^']*';", "static const String appVersion = '$versionName';"
    $appConst = $appConst -replace "static const int buildNumber = \d+;", "static const int buildNumber = $versionCode;"
    Set-Content -Path $appConstPath -Value $appConst -Encoding UTF8 -NoNewline
}

# 2. Sync lib/services/whats_new_service.dart
$whatsNewPath = "lib\services\whats_new_service.dart"
if (Test-Path $whatsNewPath) {
    $wn = Get-Content $whatsNewPath -Raw -Encoding UTF8
    $wn = $wn -replace "static const String currentVersionIdentifier = '[^']*';", "static const String currentVersionIdentifier = '$versionName+$versionCode';"
    Set-Content -Path $whatsNewPath -Value $wn -Encoding UTF8 -NoNewline
}

# 3. Sync public/version.json and ..\public\version.json
$verJsonObj = @{
    app_name = "study_library"
    version = $versionName
    build_number = "$versionCode"
    package_name = "study_library"
} | ConvertTo-Json -Compress
Set-Content -Path "public\version.json" -Value $verJsonObj -Encoding UTF8 -NoNewline
if (Test-Path "..\public\version.json") {
    Set-Content -Path "..\public\version.json" -Value $verJsonObj -Encoding UTF8 -NoNewline
}

# 4. Sync update.json (web channel always; android channel if -SyncAndroid)
$targetPath = if (Test-Path "public\update.json") { "public\update.json" } else { "update.json" }
$updateJson = Get-Content $targetPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $updateJson.web) {
    $updateJson | Add-Member -MemberType NoteProperty -Name "web" -Value ([PSCustomObject]@{})
}
$updateJson.web.version = $versionName
$updateJson.web.buildNumber = $versionCode
$updateJson.web.buildDate = (Get-Date -Format 'yyyy-MM-dd')

if ($SyncAndroid) {
    $repo = "ksonpethkar/study-library-management"
    $baseUrl = "https://github.com/$repo/releases/download/v$versionName"
    if (-not $updateJson.android) {
        $updateJson | Add-Member -MemberType NoteProperty -Name "android" -Value ([PSCustomObject]@{})
    }
    $updateJson.android.versionCode = $versionCode
    $updateJson.android.versionName = "$versionName+$versionCode"
    $updateJson.android.downloadUrl = "$baseUrl/StudyLibrary-arm64-v8a.apk"
    $updateJson.android.apkUrl = "$baseUrl/StudyLibrary-arm64-v8a.apk"
    $updateJson.android.arm64DownloadUrl = "$baseUrl/StudyLibrary-arm64-v8a.apk"
    $updateJson.android.legacy32DownloadUrl = "$baseUrl/StudyLibrary-armeabi-v7a.apk"
    $updateJson.android.universalDownloadUrl = "$baseUrl/StudyLibrary.apk"
    $updateJson.android.aabDownloadUrl = "$baseUrl/StudyLibrary.aab"
    $updateJson.android.releaseUrl = "https://github.com/$repo/releases/tag/v$versionName"
    $updateJson.android.releasedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    $updateJson.versionCode = $versionCode
    $updateJson.latestVersionCode = $versionCode
    $updateJson.latestBuild = $versionCode
    $updateJson.latestVersion = $versionName
    $updateJson.versionName = "$versionName+$versionCode"
    $updateJson.arm64DownloadUrl = "$baseUrl/StudyLibrary-arm64-v8a.apk"
    $updateJson.legacy32DownloadUrl = "$baseUrl/StudyLibrary-armeabi-v7a.apk"
    $updateJson.universalDownloadUrl = "$baseUrl/StudyLibrary.apk"
    $updateJson.aabDownloadUrl = "$baseUrl/StudyLibrary.aab"
    $updateJson.downloadUrl = "$baseUrl/StudyLibrary-arm64-v8a.apk"
}

$jsonStr = $updateJson | ConvertTo-Json -Depth 12
foreach ($dest in @("public\update.json", "update.json", "..\public\update.json", "..\update.json")) {
    $parentDir = Split-Path $dest -Parent
    if ($parentDir -eq "" -or (Test-Path $parentDir)) {
        Set-Content -Path $dest -Value $jsonStr -Encoding UTF8
    }
}

Write-Host "Version manifest & constants synchronized to $versionName+$versionCode." -ForegroundColor Green
