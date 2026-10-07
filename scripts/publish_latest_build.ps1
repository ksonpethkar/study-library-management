# ==============================================================================
# Cozy Corner - Automated Build, Upload and CDN Deployment Script
# Auto-increments versionCode on every run so OTA banner triggers on all
# devices that have an older installed build.
# ==============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Cozy Corner - Automated Build and Release Pipeline" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$Repo    = "ksonpethkar/study-library-management"
$Tag     = "v1.0.0"
$DestPath = "C:\Users\ksonp\Downloads\StudyLibrary.apk"

# ── Auto-detect version from pubspec.yaml ────────────────────────────────────
$pubspec = Get-Content "pubspec.yaml" -Raw -Encoding UTF8
$verMatch = [regex]::Match($pubspec, 'version:\s*([\d.]+)\+(\d+)')
$versionName = if ($verMatch.Success) { $verMatch.Groups[1].Value } else { "1.1.0" }
$versionCode = if ($verMatch.Success) { [int]$verMatch.Groups[2].Value } else { 2 }
Write-Host "  App version: $versionName+$versionCode" -ForegroundColor Cyan

# ── Step 1: Compile Optimized Production APK ─────────────────────────────────
if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk" }
if (-not $env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk" }
Write-Host "`n[1/5] Compiling optimized mobile APK (flutter build apk --release --split-per-abi)..." -ForegroundColor Yellow
& flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] Flutter build failed! Aborting." -ForegroundColor Red
    exit 1
}

# Target modern 64-bit Android architecture (arm64-v8a)
$ApkPath = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
if (-not (Test-Path $ApkPath)) {
    $ApkPath = "build\app\outputs\flutter-apk\app-release.apk"
}

# ── Step 2: Backup to Downloads and inspect size ──────────────────────────────
Write-Host "`n[2/5] Copying fresh APK to $DestPath..." -ForegroundColor Yellow
Copy-Item -Path $ApkPath -Destination $DestPath -Force
Copy-Item -Path $ApkPath -Destination "..\CozyCorner-Release.apk" -Force
$fileInfo = Get-Item $DestPath
$sizeMB   = [math]::Round($fileInfo.Length / 1MB, 1)
Write-Host "  Optimized APK Size: $sizeMB MB" -ForegroundColor Green

# Update download page badge dynamically
$downloadHtml = "public\download\index.html"
if (Test-Path $downloadHtml) {
    $htmlContent = Get-Content $downloadHtml -Raw -Encoding UTF8
    $replacement = "<span class=`"badge`" id=`"apkSizeBadge`">$sizeMB MB (Optimized)</span>"
    $newHtml = $htmlContent -replace '<span class="badge" id="apkSizeBadge">.*?</span>', $replacement
    $verReplacement = "<span class=`"badge`" id=`"appVersionBadge`">v$versionName (Build $versionCode)</span>"
    $newHtml = $newHtml -replace '<span class="badge" id="appVersionBadge">.*?</span>', $verReplacement
    Set-Content -Path $downloadHtml -Value $newHtml -Encoding UTF8
    Write-Host "  Updated $downloadHtml with size: $sizeMB MB and version: v$versionName (Build $versionCode)" -ForegroundColor Green
}

# ── Step 3: Upload to GitHub CDN Release ─────────────────────────────────────
Write-Host "`n[3/5] Uploading APK to GitHub CDN ($Repo at tag $Tag)..." -ForegroundColor Yellow
& gh release upload $Tag $DestPath --clobber --repo $Repo
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[WARNING] GitHub upload had an issue. Continuing to hosting..." -ForegroundColor Yellow
} else {
    Write-Host "  Uploaded successfully to CDN!" -ForegroundColor Green
}

# ── Step 4: Update update.json with correct version ──────────────────────────
Write-Host "`n[4/5] Updating public/update.json (v$versionName, code=$versionCode)..." -ForegroundColor Yellow
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Release notes — edit this when you ship new features
$releaseNotes = "v$versionName - Client-Side Midnight Auto-Expiration Trigger (auto-expires overdue plans & releases seats on app resume), Reorderable Sections with drag-and-drop on Seat Map, Security Rate Limiting & Login History, and 1-Tap Seat Transfer."

$jsonObj = [ordered]@{
    versionCode    = $versionCode
    versionName    = $versionName
    minVersionCode = 1
    forceUpdate    = $false
    apkUrl         = "https://github.com/$Repo/releases/latest/download/StudyLibrary.apk"
    iosUrl         = ""
    releaseNotes   = $releaseNotes
    releasedAt     = $timestamp
}
$jsonString = $jsonObj | ConvertTo-Json -Depth 4
Set-Content -Path "public\update.json" -Value $jsonString -Encoding UTF8
Write-Host "  update.json written: versionCode=$versionCode, versionName=$versionName" -ForegroundColor Green

# ── Step 5: Deploy to Firebase Hosting ───────────────────────────────────────
Write-Host "`n[5/5] Deploying web portal to Firebase Hosting..." -ForegroundColor Yellow
& firebase deploy --only hosting
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "  PIPELINE COMPLETE AND LIVE!" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Direct CDN Download: https://github.com/$Repo/releases/latest/download/StudyLibrary.apk" -ForegroundColor Cyan
    Write-Host "Public Web Portal:   https://study-lib-mgmt-2026.web.app/download/" -ForegroundColor Cyan
    Write-Host "Live Seat Map:       https://study-lib-mgmt-2026.web.app/seats/" -ForegroundColor Cyan
    Write-Host "Update Feed:         https://study-lib-mgmt-2026.web.app/update.json" -ForegroundColor Cyan
} else {
    Write-Host "`n[ERROR] Firebase hosting deployment failed." -ForegroundColor Red
}
