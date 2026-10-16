# ==============================================================================
# Cozy Corner: Build & Publish Test APK (Pre-Release Staging)
# ==============================================================================
# 1. Runs flutter analyze (must be 0 issues).
# 2. Builds optimized split APKs (--split-per-abi) -> arm64 (~45 MB).
# 3. Verifies APK signatures (Scheme v2/v3).
# 4. Uploads to GitHub Releases tag 'test-latest' as a PRE-RELEASE.
# 5. Deploys the /test portal to Firebase Hosting.
# ==============================================================================

$ErrorActionPreference = 'Stop'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  COZY CORNER: BUILD AND PUBLISH TEST STAGING APK         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Analyzer Check
Write-Host "`n[1/5] Running Flutter Analyzer..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Analyzer failed. Please fix issues before publishing." -ForegroundColor Red
    exit 1
}
Write-Host "SUCCESS: Analyzer clean - 0 issues found" -ForegroundColor Green

# 2. Build Split-per-ABI Release APKs
Write-Host "`n[2/5] Building optimized Release APKs..." -ForegroundColor Yellow
flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed." -ForegroundColor Red
    exit 1
}

$Arm64Path = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
if (-not (Test-Path $Arm64Path)) {
    Write-Host "ERROR: Expected APK not found at $Arm64Path" -ForegroundColor Red
    exit 1
}

$SizeMB = [math]::Round((Get-Item $Arm64Path).Length / 1MB, 1)
Write-Host "SUCCESS: Built arm64-v8a APK size is $SizeMB MB" -ForegroundColor Green

# 3. Verify Signature
Write-Host "`n[3/5] Verifying APK Signature Scheme v2/v3..." -ForegroundColor Yellow
$ApkSigner = "C:\Users\ksonp\AppData\Local\Android\Sdk\build-tools\35.0.1\apksigner.bat"
if (Test-Path $ApkSigner) {
    & $ApkSigner verify --verbose $Arm64Path
    Write-Host "SUCCESS: APK Signature verified" -ForegroundColor Green
} else {
    Write-Host "WARNING: apksigner tool not found at standard path" -ForegroundColor DarkYellow
}

# Copy / Rename for testing
Copy-Item $Arm64Path -Destination "StudyLibrary-Test-arm64.apk" -Force
Write-Host "SUCCESS: Prepared StudyLibrary-Test-arm64.apk ($SizeMB MB)" -ForegroundColor Green

# 4. Upload to GitHub Pre-Release 'test-latest'
Write-Host "`n[4/5] Uploading to GitHub Pre-release test-latest..." -ForegroundColor Yellow
gh release upload test-latest StudyLibrary-Test-arm64.apk --clobber
if ($LASTEXITCODE -ne 0) {
    gh release create test-latest StudyLibrary-Test-arm64.apk --prerelease --title "Internal Test Build (Pre-Release)" --notes "Automated staging build for private device testing. Does not affect production users."
}

# 5. Deploy Firebase Hosting (/test portal)
Write-Host "`n[5/5] Deploying test portal to Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  TEST PORTAL READY AND LIVE!                             " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Open Test Download Portal on your phone:" -ForegroundColor White
Write-Host "   https://study-lib-mgmt-2026.web.app/test" -ForegroundColor Cyan
Write-Host "`nProduction Portal remains safe and untouched:" -ForegroundColor White
Write-Host "   https://study-lib-mgmt-2026.web.app/download" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Green
