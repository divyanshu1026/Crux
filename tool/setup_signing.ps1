<#
    Crux — one-time release signing setup.

    Creates the upload keystore and android/key.properties so
    `flutter build appbundle --release` produces a Play-acceptable, release-signed
    bundle instead of a debug-signed one.

    Run from the project root in PowerShell:

        powershell -ExecutionPolicy Bypass -File tool\setup_signing.ps1

    You will be asked for a password. Everything stays on your machine — the
    keystore and key.properties are git-ignored and are never uploaded.

    ⚠️  BACK UP THE .jks FILE. With Play App Signing a lost upload key can be
    reset through Google support, but recovery is far easier if you still have it.
#>

$ErrorActionPreference = 'Stop'

# --- Locate keytool (ships with any JDK; Android Studio bundles one) ---------
$keytool = $null
$candidates = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe",
    "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe"
)
foreach ($c in $candidates) {
    if ($c -and (Test-Path $c)) { $keytool = $c; break }
}
if (-not $keytool) {
    $onPath = Get-Command keytool -ErrorAction SilentlyContinue
    if ($onPath) { $keytool = $onPath.Source }
}
if (-not $keytool) {
    Write-Host "Could not find keytool. Install a JDK (or Android Studio) and retry." -ForegroundColor Red
    exit 1
}
Write-Host "Using keytool: $keytool" -ForegroundColor DarkGray

# --- Paths ------------------------------------------------------------------
$projectRoot = Split-Path -Parent $PSScriptRoot
$propsPath   = Join-Path $projectRoot 'android\key.properties'
$keystorePath = Join-Path $env:USERPROFILE 'crux-upload.jks'
$alias = 'crux'

if (Test-Path $propsPath) {
    Write-Host "`nandroid/key.properties already exists." -ForegroundColor Yellow
    $ans = Read-Host "Overwrite it? Type YES to continue"
    if ($ans -ne 'YES') { Write-Host "Aborted. Nothing changed."; exit 0 }
}

if (Test-Path $keystorePath) {
    Write-Host "`nA keystore already exists at:`n  $keystorePath" -ForegroundColor Yellow
    Write-Host "Reusing it (this is correct if you've published with it before)." -ForegroundColor Yellow
    $reuse = $true
} else {
    $reuse = $false
}

# --- Password ---------------------------------------------------------------
Write-Host ""
if ($reuse) {
    $sec1 = Read-Host "Enter the EXISTING keystore password" -AsSecureString
} else {
    Write-Host "Choose a keystore password (min 6 characters). Store it in your"
    Write-Host "password manager — you need it for every future app update."
    $sec1 = Read-Host "New keystore password" -AsSecureString
    $sec2 = Read-Host "Confirm password" -AsSecureString
    $p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec1))
    $p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec2))
    if ($p1 -ne $p2) { Write-Host "`nPasswords did not match. Nothing changed." -ForegroundColor Red; exit 1 }
    if ($p1.Length -lt 6) { Write-Host "`nPassword must be at least 6 characters." -ForegroundColor Red; exit 1 }
}
$pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec1))

# --- Create the keystore ----------------------------------------------------
if (-not $reuse) {
    Write-Host "`nCreating keystore at $keystorePath ..." -ForegroundColor Cyan
    # -dname supplied non-interactively; these fields are cosmetic for an
    # upload key and are not shown to users anywhere.
    & $keytool -genkeypair -v `
        -keystore $keystorePath `
        -storetype JKS `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -alias $alias `
        -storepass $pw -keypass $pw `
        -dname "CN=Crux, OU=Crux, O=Crux, L=Unknown, S=Unknown, C=IN"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "keytool failed. Nothing written." -ForegroundColor Red
        exit 1
    }
}

# --- Write key.properties ---------------------------------------------------
# Gradle reads this file; forward slashes work on every platform.
$storeForGradle = $keystorePath -replace '\\', '/'
@"
storePassword=$pw
keyPassword=$pw
keyAlias=$alias
storeFile=$storeForGradle
"@ | Set-Content -Path $propsPath -Encoding UTF8 -NoNewline

Write-Host "`n✅ Done." -ForegroundColor Green
Write-Host "   Keystore      : $keystorePath"
Write-Host "   key.properties: $propsPath  (git-ignored)"
Write-Host ""
Write-Host "⚠️  Back up the .jks file and the password now." -ForegroundColor Yellow
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "   flutter build appbundle --release ``"
Write-Host "     --dart-define=SUPABASE_URL=https://ryklcllmzkpaxxpbsitg.supabase.co ``"
Write-Host "     --dart-define=SUPABASE_ANON_KEY=sb_publishable_aEyoZCvFj0ZCWct6dCOCRw_ClP3_7ww"
Write-Host ""
Write-Host "Then verify it is release-signed (should NOT say 'Android Debug'):"
Write-Host "   & '$keytool' -printcert -jarfile build\app\outputs\bundle\release\app-release.aab"
