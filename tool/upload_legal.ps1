param(
    [string]$ServiceRoleKey
)

if (-not $ServiceRoleKey) {
    $ServiceRoleKey = Read-Host "Paste your Supabase service_role secret key"
}

if (-not $ServiceRoleKey) {
    Write-Error "Service role key cannot be empty."
    exit 1
}

$files = @("privacy-policy.html", "terms-of-use.html", "account-deletion.html")
$baseUrl = "https://ryklcllmzkpaxxpbsitg.supabase.co/storage/v1/object/Legal"

foreach ($file in $files) {
    $filePath = "store/$file"
    if (-not (Test-Path $filePath)) {
        Write-Warning "File not found: $filePath"
        continue
    }

    Write-Host "Uploading $file..." -ForegroundColor Cyan
    & curl.exe -s -X POST "$baseUrl/$file" `
      -H "Authorization: Bearer $ServiceRoleKey" `
      -H "Content-Type: text/html" `
      -H "x-upsert: true" `
      --data-binary "@$filePath"

    Write-Host "Verifying Content-Type for $file..." -ForegroundColor Green
    $publicUrl = "https://ryklcllmzkpaxxpbsitg.supabase.co/storage/v1/object/public/Legal/$file"
    & curl.exe -sI "$publicUrl" | Select-String -Pattern "content-type" -CaseInsensitive
    Write-Host ""
}

Write-Host "All legal documents processed!" -ForegroundColor Green
