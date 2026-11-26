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

Write-Host "`n[1/5] Building split APKs (arm64-v8a & armeabi-v7a)..." -ForegroundColor Yellow
& flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { throw "Split APK build failed!" }

Write-Host "`n[1b/5] Building universal APK..." -ForegroundColor Yellow
& flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "Universal APK build failed!" }

Write-Host "`n[1c/5] Building release AAB..." -ForegroundColor Yellow
& flutter build appbundle --release
if ($LASTEXITCODE -ne 0) { throw "AAB build failed!" }

# ── Step 2: Stage canonical asset names & compute exact sizes ─────────────────
$releaseDir = "build\release_assets"
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

$arm64Out = "$releaseDir\StudyLibrary-arm64-v8a.apk"
$arm32Out = "$releaseDir\StudyLibrary-armeabi-v7a.apk"
$uniOut   = "$releaseDir\StudyLibrary.apk"
$aabOut   = "$releaseDir\StudyLibrary.aab"

Copy-Item "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" $arm64Out -Force
Copy-Item "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" $arm32Out -Force
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" $uniOut -Force
Copy-Item "build\app\outputs\bundle\release\app-release.aab" $aabOut -Force

$arm64MB = "$([math]::Round((Get-Item $arm64Out).Length / 1MB, 1)) MB"
$arm32MB = "$([math]::Round((Get-Item $arm32Out).Length / 1MB, 1)) MB"
$uniMB   = "$([math]::Round((Get-Item $uniOut).Length / 1MB, 1)) MB"
$aabMB   = "$([math]::Round((Get-Item $aabOut).Length / 1MB, 1)) MB"
Write-Host "  Assets staged: arm64=$arm64MB | arm32=$arm32MB | universal=$uniMB | aab=$aabMB" -ForegroundColor Green

# ── Step 3: Publish to GitHub Release $Tag ────────────────────────────────────
Write-Host "`n[3/5] Publishing release $Tag to GitHub ($Repo)..." -ForegroundColor Yellow
$releaseExists = $false
try {
    & gh release view $Tag --repo $Repo | Out-Null
    if ($LASTEXITCODE -eq 0) { $releaseExists = $true }
} catch {}

if ($releaseExists) {
    & gh release upload $Tag $arm64Out $arm32Out $uniOut $aabOut --clobber --repo $Repo
    if ($LASTEXITCODE -ne 0) { throw "gh release upload failed for $Tag" }
} else {
    & gh release create $Tag $arm64Out $arm32Out $uniOut $aabOut --repo $Repo --title "Cozy Corner Study Library $Tag (Build $versionCode)" --notes "Official signed release $Tag (Build $versionCode)."
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed for $Tag" }
}

# ── Step 4: Verify HTTP 200 OK on all APK asset URLs before updating manifest ───
Write-Host "`n[4/5] Verifying GitHub CDN asset URLs (HTTP 200 OK)..." -ForegroundColor Yellow
$baseUrl = "https://github.com/$Repo/releases/download/$Tag"
foreach ($assetName in @("StudyLibrary-arm64-v8a.apk", "StudyLibrary-armeabi-v7a.apk", "StudyLibrary.apk", "StudyLibrary.aab")) {
    $checkUrl = "$baseUrl/$assetName"
    $resp = Invoke-WebRequest -Uri $checkUrl -Method Head -MaximumRedirection 5 -UseBasicParsing
    if ($resp.StatusCode -lt 200 -or $resp.StatusCode -ge 400) {
        throw "CDN verification failed for $checkUrl (HTTP $($resp.StatusCode))"
    }
    Write-Host "  Verified ($($resp.StatusCode)): $assetName" -ForegroundColor Green
}

# Sync update.json android + top-level sizes & URLs across all mirrors
& "$PSScriptRoot\update_version.ps1" -SyncAndroid
foreach ($jsonPath in @("public\update.json", "update.json", "..\public\update.json", "..\update.json")) {
    if (Test-Path $jsonPath) {
        $j = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $j.apkSize = $arm64MB
        $j.arm64ApkSize = $arm64MB
        $j.legacy32ApkSize = $arm32MB
        $j.universalApkSize = $uniMB
        $j.aabSize = $aabMB
        $j.android.apkSize = $arm64MB
        $j.android.arm64ApkSize = $arm64MB
        $j.android.legacy32ApkSize = $arm32MB
        $j.android.universalApkSize = $uniMB
        $j.android.aabSize = $aabMB
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
npx firebase deploy --only hosting --project study-lib-mgmt-2026
if ($LASTEXITCODE -ne 0) { throw "Firebase Hosting deploy failed!" }

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  RELEASE $Tag (BUILD $versionCode) LIVE ON GITHUB & HOSTING!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
