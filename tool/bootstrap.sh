#!/usr/bin/env bash
# Генерирует нативные проекты android/ и ios/ и применяет настройки приложения.
#
# Использование:
#   ./tool/bootstrap.sh                          # id по умолчанию: com.company.b2bapp
#   APP_ID=ru.mycompany.parts APP_NAME="Мои запчасти" ./tool/bootstrap.sh
#
# Скрипт идемпотентен: если android/ уже есть, повторный запуск ничего не ломает.
set -euo pipefail
export PYTHONUTF8=1

cd "$(dirname "$0")/.."

APP_ID="${APP_ID:-am.snp.shop}"
APP_NAME="${APP_NAME:-SNP}"
BOOT_ORG="com.snb2b.bootstrap"

command -v flutter >/dev/null || { echo "Flutter SDK не найден в PATH"; exit 1; }

echo "==> Package name: $APP_ID, название: $APP_NAME"

if [ ! -d android ] || [ ! -d ios ]; then
  echo "==> flutter create (android, ios)"
  tmp="$(mktemp -d)"
  cp -r lib "$tmp/lib"
  cp pubspec.yaml "$tmp/pubspec.yaml"
  cp -r assets "$tmp/assets" 2>/dev/null || true
  [ -d test ] && cp -r test "$tmp/test"

  flutter create --platforms=android,ios --org "$BOOT_ORG" --project-name snb2b_app .

  # flutter create мог затронуть наши файлы — возвращаем оригиналы
  rm -rf lib && cp -r "$tmp/lib" lib
  cp "$tmp/pubspec.yaml" pubspec.yaml
  rm -rf test && { [ -d "$tmp/test" ] && cp -r "$tmp/test" test || mkdir -p test; }
  rm -rf "$tmp"
fi

echo "==> Применяем package name / настройки"
APP_ID="$APP_ID" APP_NAME="$APP_NAME" BOOT_ORG="$BOOT_ORG" python3 tool/patch_native.py

echo "==> flutter pub get"
flutter pub get

echo "==> Иконки и splash (не критично, если не удалось)"
dart run flutter_launcher_icons || echo "! flutter_launcher_icons не отработал"
dart run flutter_native_splash:create || echo "! flutter_native_splash не отработал"

echo
echo "Готово. Дальше:"
echo "  flutter analyze && flutter test"
echo "  flutter run                       # демо-режим (Mock API)"
echo "  flutter build apk --release"
