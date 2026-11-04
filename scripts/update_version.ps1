# Usage: .\scripts\update_version.ps1
# Reads version from pubspec.yaml and updates web release info in update.json
# NOTE: This updates the WEB channel only. Native Android APK updates are only published
# by .\scripts\publish_latest_build.ps1 when an actual APK binary is compiled and uploaded!

$pubspec = Get-Content 'pubspec.yaml' -Raw
$versionLine = $pubspec | Select-String -Pattern 'version:\s+(.+)' | Select-Object -First 1
$fullVersion = $versionLine.Matches[0].Groups[1].Value.Trim()

# Split version string (e.g., '1.5.48+56') -> name='1.5.48', code=56
$parts = $fullVersion -split '\+'
$versionName = $parts[0]
$versionCode = [int]$parts[1]

Write-Host "Updating Web Channel Version: $versionName (Build $versionCode)" -ForegroundColor Cyan

# Read existing update.json
$targetPath = if (Test-Path 'public/update.json') { 'public/update.json' } else { 'update.json' }
$updateJson = Get-Content $targetPath -Raw | ConvertFrom-Json

# Update Web Channel ONLY (Do NOT modify Android APK release version)
if (-not $updateJson.web) {
    $updateJson | Add-Member -MemberType NoteProperty -Name "web" -Value ([PSCustomObject]@{})
}
$updateJson.web.version = $versionName
$updateJson.web.buildNumber = $versionCode
$updateJson.web.buildDate = (Get-Date -Format 'yyyy-MM-dd')

# Write back
$jsonStr = $updateJson | ConvertTo-Json -Depth 10
Set-Content -Path 'public/update.json' -Value $jsonStr -Encoding UTF8
if (Test-Path 'update.json') {
    Set-Content -Path 'update.json' -Value $jsonStr -Encoding UTF8
}

Write-Host "Web build manifest updated to $versionName (Build $versionCode). Android APK release untouched." -ForegroundColor Green
Write-Host "Run 'firebase deploy --only hosting' to publish web portal."
