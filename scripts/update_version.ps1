# Usage: .\scripts\update_version.ps1
# Reads version from pubspec.yaml and updates update.json + deploys to Firebase Hosting

$pubspec = Get-Content 'pubspec.yaml' -Raw
$versionLine = $pubspec | Select-String -Pattern 'version:\s+(.+)' | Select-Object -First 1
$fullVersion = $versionLine.Matches[0].Groups[1].Value.Trim()

# Split version string (e.g., '1.5.3+10') -> name='1.5.3', code=10
$parts = $fullVersion -split '\+'
$versionName = $parts[0]
$versionCode = [int]$parts[1]

Write-Host "Version: $versionName ($versionCode)"

# Read existing update.json
$updateJson = Get-Content 'update.json' -Raw | ConvertFrom-Json

# Update fields
$updateJson.latestVersion = $versionName
$updateJson.latestVersionCode = $versionCode
$updateJson.releaseDate = (Get-Date -Format 'yyyy-MM-dd')

# Write back
$updateJson | ConvertTo-Json -Depth 10 | Set-Content 'update.json'
if (Test-Path 'public/update.json') {
    $updateJson | ConvertTo-Json -Depth 10 | Set-Content 'public/update.json'
}

Write-Host "update.json updated to $versionName+$versionCode"
Write-Host "Run 'firebase deploy --only hosting' to publish."
