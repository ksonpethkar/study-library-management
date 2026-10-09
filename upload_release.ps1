$token = (gh auth token).Trim()
$filePath = "c:\Users\ksonp\Downloads\Cozy Corner\study_library\StudyLibrary.apk"
$url = "https://uploads.github.com/repos/ksonpethkar/study-library-management/releases/401611667/assets?name=StudyLibrary.apk"

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromMinutes(20)
$client.DefaultRequestHeaders.Add("Authorization", "token $token")
$client.DefaultRequestHeaders.Add("User-Agent", "PowerShell-ReleaseUploader")
$client.DefaultRequestHeaders.Add("Accept", "application/vnd.github+json")

$bytes = [System.IO.File]::ReadAllBytes($filePath)
Write-Host "Read $($bytes.Length) bytes into memory ($([math]::Round($bytes.Length / 1MB, 2)) MB)"

$content = [System.Net.Http.ByteArrayContent]::new($bytes)
$content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/vnd.android.package-archive")

Write-Host "Uploading to GitHub..."
$response = $client.PostAsync($url, $content).GetAwaiter().GetResult()
Write-Host "StatusCode: $($response.StatusCode)"
$body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
Write-Host "Response: $body"

if ($response.IsSuccessStatusCode) {
    # Also upload StudyLibrary-Universal.apk
    $urlUniversal = "https://uploads.github.com/repos/ksonpethkar/study-library-management/releases/401611667/assets?name=StudyLibrary-Universal.apk"
    $contentUniversal = [System.Net.Http.ByteArrayContent]::new($bytes)
    $contentUniversal.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/vnd.android.package-archive")
    Write-Host "Uploading StudyLibrary-Universal.apk..."
    $response2 = $client.PostAsync($urlUniversal, $contentUniversal).GetAwaiter().GetResult()
    Write-Host "StatusCode: $($response2.StatusCode)"
}
