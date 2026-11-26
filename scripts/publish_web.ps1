# ==============================================================================
# Cozy Corner - Automated Web Build & Firebase Hosting Deploy Pipeline
# ==============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Cozy Corner - Web Build & Firebase Hosting Deploy" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ErrorActionPreference = 'Stop'

# 0. Synchronize Web Channel Version & Constants from pubspec.yaml
Write-Host "`n[0/4] Synchronizing Web manifest & AppConstants from pubspec.yaml..." -ForegroundColor Yellow
& "$PSScriptRoot\update_version.ps1"

$pubspec = Get-Content "pubspec.yaml" -Raw -Encoding UTF8
$verMatch = [regex]::Match($pubspec, 'version:\s*([\d.]+)\+(\d+)')
$expectedVer = $verMatch.Groups[1].Value
$expectedBuild = $verMatch.Groups[2].Value

# 1. Run Flutter Analyzer
Write-Host "`n[1/4] Running Flutter Analyzer..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos lib/
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Analyzer reported issues in lib/. Aborting." -ForegroundColor Red
    exit 1
}

# 2. Compile Web Release (Wasm + JS fallback) with Base Href /app/
Write-Host "`n[2/4] Compiling Flutter WebAssembly + JS fallback bundle (--base-href /app/)..." -ForegroundColor Yellow
flutter build web --release --wasm --base-href /app/
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter Web build failed. Aborting." -ForegroundColor Red
    exit 1
}

# Verify build/web/version.json matches pubspec.yaml (never deploy stale cached version.json)
$builtVerJson = Get-Content "build\web\version.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if ($builtVerJson.version -ne $expectedVer -or "$($builtVerJson.build_number)" -ne "$expectedBuild") {
    Write-Host "Stale build\web\version.json detected ($($builtVerJson.version)+$($builtVerJson.build_number)). Regenerating..." -ForegroundColor Yellow
    $freshVer = @{
        app_name = "study_library"
        version = $expectedVer
        build_number = "$expectedBuild"
        package_name = "study_library"
    } | ConvertTo-Json -Compress
    Set-Content -Path "build\web\version.json" -Value $freshVer -Encoding UTF8 -NoNewline
}

# 3. Synchronize Web Artifacts & Portals to public/ and ..\public/
Write-Host "`n[3/4] Copying build artifacts to public\app and syncing portals..." -ForegroundColor Yellow
Copy-Item -Path "build\web\*" -Destination "public\app" -Recurse -Force
if (Test-Path "web\flutter_service_worker.js") { Copy-Item -Path "web\flutter_service_worker.js" -Destination "public\app\flutter_service_worker.js" -Force }
if (Test-Path "..\public\app") {
    Copy-Item -Path "build\web\*" -Destination "..\public\app" -Recurse -Force
    if (Test-Path "web\flutter_service_worker.js") { Copy-Item -Path "web\flutter_service_worker.js" -Destination "..\public\app\flutter_service_worker.js" -Force }
}
if (Test-Path "..\public\download") {
    Copy-Item -Path "public\download\index.html" -Destination "..\public\download\index.html" -Force
}
if (Test-Path "..\public") {
    Copy-Item -Path "public\index.html" -Destination "..\public\index.html" -Force
}
node scripts/inject_loader.js

# 4. Deploy to Firebase Hosting (prefer global firebase CLI over npx fallback)
Write-Host "`n[4/4] Deploying to Firebase Hosting (study-lib-mgmt-2026)..." -ForegroundColor Yellow
if (Get-Command firebase -ErrorAction SilentlyContinue) {
    firebase deploy --only hosting --project study-lib-mgmt-2026
} else {
    npx firebase deploy --only hosting --project study-lib-mgmt-2026
}
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "  WEB APP DEPLOYED AND LIVE! (v$expectedVer+$expectedBuild)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Live Web Portal: https://study-lib-mgmt-2026.web.app/app/" -ForegroundColor Cyan
    Write-Host "Download Portal: https://study-lib-mgmt-2026.web.app/download/" -ForegroundColor Cyan
} else {
    Write-Host "`n[ERROR] Firebase Hosting deploy failed." -ForegroundColor Red
    exit 1
}

