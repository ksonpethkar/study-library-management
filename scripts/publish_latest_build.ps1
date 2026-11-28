# ==============================================================================
# Cozy Corner - Automated Android Build, GitHub Release & CDN Verification Script
# Builds arm64-v8a, armeabi-v7a, universal APK + AAB using cozycorner-release.jks,
# publishes to GitHub release v<versionName>, verifies HTTP 200 on all asset URLs,
# and only then updates update.json across all targets + deploys Firebase Hosting.
# ==============================================================================

$ErrorActionPreference = 'Stop'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Cozy Corner - Android Release & CDN Pipeline" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$Repo = "ksonpethkar/study-library-management"

# ── Step 0: Sync constants & read version from pubspec.yaml ───────────────────
& "$PSScriptRoot\update_version.ps1"
$pubspec = Get-Content "pubspec.yaml" -Raw -Encoding UTF8
$verMatch = [regex]::Match($pubspec, 'version:\s*([\d.]+)\+(\d+)')
if (-not $verMatch.Success) { throw "Failed to parse pubspec.yaml version" }
$versionName = $verMatch.Groups[1].Value
$versionCode = [int]$verMatch.Groups[2].Value
$Tag = "v$versionName"
Write-Host "  Target Release: $Tag (Build $versionCode)" -ForegroundColor Cyan

# ── Step 1: Compile Split APKs, Universal APK, and Play App Bundle ────────────
if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk" }
if (-not $env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk" }

Write-Host "`n[1/5] Building single lean 64-bit APK (arm64-v8a)..." -ForegroundColor Yellow
& flutter build apk --release --target-platform android-arm64 --split-debug-info=build/debug-info --obfuscate
if ($LASTEXITCODE -ne 0) { throw "arm64-v8a APK build failed!" }

# ── Step 2: Clean old staging & stage canonical asset name ────────────────────
$releaseDir = "build\release_assets"
if (Test-Path $releaseDir) { Remove-Item "$releaseDir\*" -Recurse -Force }
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

$arm64Out = "$releaseDir\StudyLibrary-arm64-v8a.apk"
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" $arm64Out -Force

$arm64MB = "$([math]::Round((Get-Item $arm64Out).Length / 1MB, 1)) MB"
Write-Host "  Asset staged: arm64=$arm64MB" -ForegroundColor Green

# ── Step 3: Publish to GitHub Release $Tag ────────────────────────────────────
Write-Host "`n[3/5] Publishing release $Tag to GitHub ($Repo)..." -ForegroundColor Yellow
$releaseExists = $false
try {
    & gh release view $Tag --repo $Repo | Out-Null
    if ($LASTEXITCODE -eq 0) { $releaseExists = $true }
} catch {}

if ($releaseExists) {
    & gh release upload $Tag $arm64Out --clobber --repo $Repo
    if ($LASTEXITCODE -ne 0) { throw "gh release upload failed for $Tag" }
} else {
    & gh release create $Tag $arm64Out --repo $Repo --title "Cozy Corner Study Library $Tag (Build $versionCode)" --notes "Official signed release $Tag (Build $versionCode)."
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed for $Tag" }
}

# ── Step 4: Verify HTTP 200 OK on APK asset URL before updating manifest ──────
Write-Host "`n[4/5] Verifying GitHub CDN asset URL (HTTP 200 OK)..." -ForegroundColor Yellow
$baseUrl = "https://github.com/$Repo/releases/download/$Tag"
foreach ($assetName in @("StudyLibrary-arm64-v8a.apk")) {
    $checkUrl = "$baseUrl/$assetName"
    $resp = Invoke-WebRequest -Uri $checkUrl -Method Head -MaximumRedirection 5 -UseBasicParsing
    if ($resp.StatusCode -lt 200 -or $resp.StatusCode -ge 400) {
        throw "CDN verification failed for $checkUrl (HTTP $($resp.StatusCode))"
    }
    Write-Host "  Verified ($($resp.StatusCode)): $assetName" -ForegroundColor Green
}

# Clean up older GitHub Releases beyond the latest 3 to keep release history lean
try {
    $oldTags = & gh release list --repo $Repo --limit 30 --json tagName -q '.[3:][].tagName'
    foreach ($oldTag in $oldTags) {
        if ($oldTag -and $oldTag -ne $Tag) {
            Write-Host "  Pruning old GitHub release: $oldTag" -ForegroundColor DarkGray
            & gh release delete $oldTag --repo $Repo --yes --cleanup-tag | Out-Null
        }
    }
} catch {}

# Sync update.json android + top-level sizes & URLs across all mirrors
& "$PSScriptRoot\update_version.ps1" -SyncAndroid
foreach ($jsonPath in @("public\update.json", "update.json", "..\public\update.json", "..\update.json")) {
    if (Test-Path $jsonPath) {
        $j = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $j.apkSize = $arm64MB
        $j.arm64ApkSize = $arm64MB
        $j.android.apkSize = $arm64MB
        $j.android.arm64ApkSize = $arm64MB
        Set-Content -Path $jsonPath -Value ($j | ConvertTo-Json -Depth 12) -Encoding UTF8
    }
}

# ── Step 5: Deploy Firebase Hosting ───────────────────────────────────────────
Write-Host "`n[5/5] Deploying hosting portals to Firebase..." -ForegroundColor Yellow
if (Test-Path "..\public\download") {
    Copy-Item -Path "public\download\index.html" -Destination "..\public\download\index.html" -Force
}
if (Test-Path "..\public") {
    Copy-Item -Path "public\index.html" -Destination "..\public\index.html" -Force
}
if (Get-Command firebase -ErrorAction SilentlyContinue) {
    firebase deploy --only hosting --project study-lib-mgmt-2026
} else {
    npx firebase deploy --only hosting --project study-lib-mgmt-2026
}
if ($LASTEXITCODE -ne 0) { throw "Firebase Hosting deploy failed!" }

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  RELEASE $Tag (BUILD $versionCode) LIVE ON GITHUB & HOSTING!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
