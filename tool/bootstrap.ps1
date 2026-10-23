# Windows-версия tool/bootstrap.sh (PowerShell). Запуск из корня проекта:
#   powershell -ExecutionPolicy Bypass -File tool\bootstrap.ps1
#   powershell -ExecutionPolicy Bypass -File tool\bootstrap.ps1 -AppId ru.mycompany.parts -AppName "Мои запчасти"
param(
  [string]$AppId = "com.company.b2bapp",
  [string]$AppName = "SNB2B"
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"
Set-Location (Split-Path $PSScriptRoot -Parent)
$BootOrg = "com.snb2b.bootstrap"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter не найден в PATH. Добавьте <папка flutter>\bin в PATH и откройте новый терминал."
}

$py = $null
foreach ($c in @("python", "py")) {
  if (Get-Command $c -ErrorAction SilentlyContinue) { $py = $c; break }
}
if (-not $py) { throw "Python 3 не найден. Установите с python.org (отметьте Add Python to PATH)." }

Write-Host "==> Package name: $AppId, название: $AppName"

if (-not (Test-Path "android") -or -not (Test-Path "ios")) {
  Write-Host "==> flutter create (android, ios)"
  $tmp = Join-Path $env:TEMP ("snb2b_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory $tmp | Out-Null
  Copy-Item "lib" (Join-Path $tmp "lib") -Recurse
  Copy-Item "pubspec.yaml" (Join-Path $tmp "pubspec.yaml")
  if (Test-Path "test") { Copy-Item "test" (Join-Path $tmp "test") -Recurse }

  flutter create --platforms=android,ios --org $BootOrg --project-name snb2b_app .
  if ($LASTEXITCODE -ne 0) { throw "flutter create завершился с ошибкой" }

  # flutter create мог затронуть наши файлы — возвращаем оригиналы
  Remove-Item "lib" -Recurse -Force
  Copy-Item (Join-Path $tmp "lib") "lib" -Recurse
  Copy-Item (Join-Path $tmp "pubspec.yaml") "pubspec.yaml" -Force
  if (Test-Path "test") { Remove-Item "test" -Recurse -Force }
  if (Test-Path (Join-Path $tmp "test")) {
    Copy-Item (Join-Path $tmp "test") "test" -Recurse
  } else {
    New-Item -ItemType Directory "test" | Out-Null
  }
  Remove-Item $tmp -Recurse -Force
}

Write-Host "==> Применяем package name / настройки"
$env:APP_ID = $AppId
$env:APP_NAME = $AppName
$env:BOOT_ORG = $BootOrg
& $py "tool/patch_native.py"
if ($LASTEXITCODE -ne 0) { throw "patch_native.py завершился с ошибкой" }

Write-Host "==> flutter pub get"
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get завершился с ошибкой" }

Write-Host "==> Иконки и splash (не критично)"
try { dart run flutter_launcher_icons } catch { Write-Host "! flutter_launcher_icons не отработал" }
try { dart run flutter_native_splash:create } catch { Write-Host "! flutter_native_splash не отработал" }

Write-Host ""
Write-Host "Готово. Дальше: flutter run   или   flutter build apk --release"
