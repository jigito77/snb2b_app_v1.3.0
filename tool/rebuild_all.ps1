# One-shot: download product images -> embed into app -> build APK (with retries).
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File C:\src\snb2b_app_new\tool\rebuild_all.ps1
$ErrorActionPreference = "Continue"
$env:Path = "C:\src\flutter\bin;C:\Program Files\Git\cmd;" + $env:Path
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
Write-Host "Project: $root"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Host "ERROR: Node.js not found in PATH"; exit 1 }
if (-not (Test-Path "assets\data\catalog.json")) { Write-Host "ERROR: assets\data\catalog.json missing"; exit 1 }
if (-not (Test-Path "android\app")) { Write-Host "ERROR: android folder missing"; exit 1 }

Write-Host "`n=== 1/3 Image compressor (sharp) ==="
Push-Location tool
npm install sharp --no-fund --no-audit
Pop-Location

Write-Host "`n=== 2/3 Downloading product images (5-15 min) ==="
node tool\embed_images.js
$n = (Get-ChildItem assets\products -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne ".keep" }).Count
Write-Host "Images in assets\products: $n"
if ($n -eq 0) { Write-Host "ERROR: no images downloaded (check internet / site access). Stopping."; exit 1 }

Write-Host "`n=== 3/3 Building APK ==="
Push-Location android
.\gradlew.bat --stop
Pop-Location
flutter pub get
$apk = "build\app\outputs\flutter-apk\app-release.apk"
Remove-Item $apk -ErrorAction SilentlyContinue
for ($i = 1; $i -le 4; $i++) {
  Write-Host "--- build attempt $i ---"
  flutter build apk --release --target-platform android-arm64
  if (Test-Path $apk) { break }
}
if (Test-Path $apk) {
  $dst = Join-Path ([Environment]::GetFolderPath("Desktop")) "SNP-app.apk"
  Copy-Item $apk $dst -Force
  Write-Host "`nDONE. APK: $dst  ($([math]::Round((Get-Item $dst).Length/1MB,1)) MB)"
} else {
  Write-Host "`nBuild failed. Send the last 30 lines above."
}
