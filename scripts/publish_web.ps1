# ==============================================================================
# Cozy Corner - Automated Web Build & Firebase Hosting Deploy Pipeline
# ==============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Cozy Corner - Web Build & Firebase Hosting Deploy" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ErrorActionPreference = 'Stop'

# 1. Run Flutter Analyzer
Write-Host "`n[1/4] Running Flutter Analyzer..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos lib/
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Analyzer reported issues in lib/. Aborting." -ForegroundColor Red
    exit 1
}

# 2. Compile Web Release with Base Href /app/
Write-Host "`n[2/4] Compiling Flutter Web release bundle (--base-href /app/)..." -ForegroundColor Yellow
flutter build web --release --base-href /app/
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter Web build failed. Aborting." -ForegroundColor Red
    exit 1
}

# 3. Synchronize Web Artifacts to public/app/ & Inject Splash Loader
Write-Host "`n[3/4] Copying build artifacts to public\app..." -ForegroundColor Yellow
Copy-Item -Path "build\web\*" -Destination "public\app" -Recurse -Force
node scripts/inject_loader.js

# 4. Deploy to Firebase Hosting
Write-Host "`n[4/4] Deploying to Firebase Hosting (study-lib-mgmt-2026)..." -ForegroundColor Yellow
firebase deploy --only hosting
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "  WEB APP DEPLOYED AND LIVE!" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Live Web Portal: https://study-lib-mgmt-2026.web.app/app/" -ForegroundColor Cyan
} else {
    Write-Host "`n[ERROR] Firebase Hosting deploy failed." -ForegroundColor Red
    exit 1
}
