$token = (gh auth token).Trim()
$filePath = "c:\Users\ksonp\Downloads\Cozy Corner\study_library\StudyLibrary.apk"
$releaseId = "442198460"
$url = "https://uploads.github.com/repos/ksonpethkar/study-library-management/releases/$releaseId/assets?name=StudyLibrary.apk"

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromMinutes(20)
$client.DefaultRequestHeaders.Add("Authorization", "token $token")
$client.DefaultRequestHeaders.Add("User-Agent", "PowerShell-ReleaseUploader")
$client.DefaultRequestHeaders.Add("Accept", "application/vnd.github+json")

$bytes = [System.IO.File]::ReadAllBytes($filePath)
Write-Host "Read $($bytes.Length) bytes into memory ($([math]::Round($bytes.Length / 1MB, 2)) MB)"

$content = [System.Net.Http.ByteArrayContent]::new($bytes)
$content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/vnd.android.package-archive")

Write-Host "Uploading StudyLibrary.apk to GitHub release $releaseId..."
$response = $client.PostAsync($url, $content).GetAwaiter().GetResult()
Write-Host "StatusCode: $($response.StatusCode)"
$body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

if ($response.IsSuccessStatusCode) {
    Write-Host "Successfully uploaded StudyLibrary.apk!" -ForegroundColor Green

    # Also upload StudyLibrary-Universal.apk
    $urlUniversal = "https://uploads.github.com/repos/ksonpethkar/study-library-management/releases/$releaseId/assets?name=StudyLibrary-Universal.apk"
    $contentUniversal = [System.Net.Http.ByteArrayContent]::new($bytes)
    $contentUniversal.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/vnd.android.package-archive")
    Write-Host "Uploading StudyLibrary-Universal.apk..."
    $response2 = $client.PostAsync($urlUniversal, $contentUniversal).GetAwaiter().GetResult()
    Write-Host "StatusCode: $($response2.StatusCode)"

    # Publish the release (remove draft status and make it latest)
    Write-Host "Publishing release $releaseId (draft -> false, latest -> true)..."
    $patchBody = '{"draft":false,"make_latest":"true"}'
    $patchContent = [System.Net.Http.StringContent]::new($patchBody, [System.Text.Encoding]::UTF8, "application/json")
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Patch, "https://api.github.com/repos/ksonpethkar/study-library-management/releases/$releaseId")
    $request.Content = $patchContent
    $publishResponse = $client.SendAsync($request).GetAwaiter().GetResult()
    Write-Host "Publish StatusCode: $($publishResponse.StatusCode)"
    Write-Host "Release published successfully!" -ForegroundColor Green
} else {
    Write-Host "Upload failed: $body" -ForegroundColor Red
}
