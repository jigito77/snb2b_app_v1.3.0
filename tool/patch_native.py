#!/usr/bin/env python3
"""Патчит сгенерированные flutter create проекты android/ и ios/.

Что делает:
  * заменяет package name (applicationId/namespace/bundle id) на APP_ID;
  * Android: INTERNET, POST_NOTIFICATIONS, <queries> для tel/mailto/https, label приложения;
  * Android: minSdk 23 (требование flutter_secure_storage), release-подпись из android/key.properties;
  * Android: подключает google-services, если лежит android/app/google-services.json;
  * iOS: отображаемое имя, русская локаль, фоновые режимы для push.
Все шаги безопасны для повторного запуска.
"""
import os
import re
import sys
from pathlib import Path

APP_ID = os.environ.get("APP_ID", "com.company.b2bapp")
APP_NAME = os.environ.get("APP_NAME", "SNP")
BOOT_ORG = os.environ.get("BOOT_ORG", "com.snb2b.bootstrap")
OLD_ID = f"{BOOT_ORG}.snb2b_app"

root = Path(__file__).resolve().parent.parent
android = root / "android"
ios = root / "ios"


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def write(p: Path, s: str) -> None:
    p.write_text(s, encoding="utf-8")


def current_id() -> str:
    for name in ("build.gradle.kts", "build.gradle"):
        f = android / "app" / name
        if f.exists():
            m = re.search(r'applicationId\s*=?\s*"([^"]+)"', read(f))
            if m:
                return m.group(1)
    return OLD_ID


# ---------------------------------------------------------------- package name
def replace_package() -> None:
    old = current_id()
    if old == APP_ID:
        print("package name уже установлен")
        return
    print(f"package: {old} -> {APP_ID}")
    skip_dirs = {"build", ".gradle", ".idea"}
    for base in (android, ios):
        if not base.exists():
            continue
        for dp, dn, fn in os.walk(base):
            dn[:] = [d for d in dn if d not in skip_dirs]
            for f in fn:
                p = Path(dp) / f
                if p.suffix in {".kt", ".java", ".gradle", ".kts", ".xml", ".pbxproj", ".plist", ".json", ".xcconfig"}:
                    try:
                        s = read(p)
                    except UnicodeDecodeError:
                        continue
                    if old in s:
                        write(p, s.replace(old, APP_ID))
    # переносим MainActivity в каталог нового пакета
    for lang in ("kotlin", "java"):
        src_root = android / "app" / "src" / "main" / lang
        if not src_root.exists():
            continue
        old_dir = src_root.joinpath(*old.split("."))
        new_dir = src_root.joinpath(*APP_ID.split("."))
        if old_dir.exists() and old_dir != new_dir:
            new_dir.mkdir(parents=True, exist_ok=True)
            for item in old_dir.iterdir():
                item.rename(new_dir / item.name)
            # убираем опустевшие каталоги старого пакета
            cur = old_dir
            while cur != src_root and cur.exists() and not any(cur.iterdir()):
                cur.rmdir()
                cur = cur.parent


# ---------------------------------------------------------------------- manifest
def patch_manifest() -> None:
    f = android / "app" / "src" / "main" / "AndroidManifest.xml"
    s = read(f)

    perms = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
        # Карта доставки: «Моё местоположение» (запрашивается только по нажатию кнопки)
        '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>',
        '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>',
    ]
    for perm in perms:
        name = re.search(r'android:name="([^"]+)"', perm).group(1)
        if name not in s:
            s = s.replace("<application", perm + "\n    <application", 1)

    if "<queries>" not in s:
        queries = """    <queries>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="mailto"/></intent>
        <intent><action android:name="android.intent.action.PROCESS_TEXT"/><data android:mimeType="text/plain"/></intent>
    </queries>
"""
        # заменяем стандартный блок queries шаблона (он содержит только PROCESS_TEXT), если есть
        s = re.sub(r"<queries>.*?</queries>", "", s, flags=re.S)
        s = s.replace("</manifest>", queries + "</manifest>")

    s = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', s, count=1)
    write(f, s)


# ----------------------------------------------------------------------- gradle
SIGNING_KTS_HEADER = """import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

"""

SIGNING_KTS_BLOCK = """    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

"""

SIGNING_GROOVY_HEADER = """def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

"""

SIGNING_GROOVY_BLOCK = """    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

"""


def patch_app_gradle() -> None:
    kts = android / "app" / "build.gradle.kts"
    groovy = android / "app" / "build.gradle"
    if kts.exists():
        f, is_kts = kts, True
    elif groovy.exists():
        f, is_kts = groovy, False
    else:
        print("! build.gradle(.kts) не найден")
        return
    s = read(f)

    # minSdk 23 для flutter_secure_storage
    s = re.sub(r"minSdk(Version)?\s*=\s*flutter\.minSdkVersion", "minSdk = 23" if is_kts else "minSdkVersion 23", s)
    s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", s)
    s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", s)

    if "key.properties" not in s:
        if is_kts:
            s = SIGNING_KTS_HEADER + s
            s = s.replace("    buildTypes {", SIGNING_KTS_BLOCK + "    buildTypes {", 1)
            s = s.replace(
                'signingConfig = signingConfigs.getByName("debug")',
                'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
            )
        else:
            s = SIGNING_GROOVY_HEADER + s
            s = s.replace("    buildTypes {", SIGNING_GROOVY_BLOCK + "    buildTypes {", 1)
            s = s.replace(
                "signingConfig signingConfigs.debug",
                "signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug",
            )
            if "import java.io.FileInputStream" not in s:
                s = "import java.io.FileInputStream\n" + s

    # Firebase / google-services — только если файл конфигурации на месте
    if (android / "app" / "google-services.json").exists() and "google-services" not in s:
        plugin = 'id("com.google.gms.google-services")' if is_kts else "id 'com.google.gms.google-services'"
        s = re.sub(
            r'(id\(?["\']dev\.flutter\.flutter-gradle-plugin["\']\)?)',
            lambda m: m.group(1) + "\n    " + plugin,
            s,
            count=1,
        )
        print("google-services подключён в app/build.gradle")
        patch_settings_gradle()
    write(f, s)


def patch_settings_gradle() -> None:
    for name, is_kts in (("settings.gradle.kts", True), ("settings.gradle", False)):
        f = android / name
        if not f.exists():
            continue
        s = read(f)
        if "google-services" in s:
            return
        line = (
            'id("com.google.gms.google-services") version "4.4.2" apply false'
            if is_kts
            else "id 'com.google.gms.google-services' version '4.4.2' apply false"
        )
        s = re.sub(
            r'(id\(?["\']org\.jetbrains\.kotlin\.android["\']\)?[^\n]*)',
            lambda m: m.group(1) + "\n    " + line,
            s,
            count=1,
        )
        write(f, s)
        return


# -------------------------------------------------------------------------- iOS
def patch_ios() -> None:
    f = ios / "Runner" / "Info.plist"
    if not f.exists():
        return
    s = read(f)

    def set_string(key: str, value: str) -> None:
        nonlocal s
        pat = re.compile(rf"(<key>{key}</key>\s*<string>)[^<]*(</string>)")
        if pat.search(s):
            s = pat.sub(rf"\g<1>{value}\g<2>", s)
        else:
            s = s.replace("<dict>", f"<dict>\n\t<key>{key}</key>\n\t<string>{value}</string>", 1)

    set_string("CFBundleDisplayName", APP_NAME)
    set_string("CFBundleName", APP_NAME)
    # Вложения в чате поддержки (image_picker / file_picker)
    for k, v in (
        ("NSPhotoLibraryUsageDescription", "Выбор фото для отправки в чат поддержки"),
        ("NSCameraUsageDescription", "Съёмка фото для отправки в чат поддержки"),
    ):
        if k not in s:
            s = s.replace("<dict>", f"<dict>\n\t<key>{k}</key>\n\t<string>{v}</string>", 1)

    if "CFBundleLocalizations" not in s:
        s = s.replace(
            "</dict>\n</plist>",
            "\t<key>CFBundleDevelopmentRegion</key>\n\t<string>ru</string>\n"
            "\t<key>CFBundleLocalizations</key>\n\t<array>\n\t\t<string>ru</string>\n\t\t<string>en</string>\n\t</array>\n"
            "</dict>\n</plist>",
        )
    if "UIBackgroundModes" not in s:
        s = s.replace(
            "</dict>\n</plist>",
            "\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>fetch</string>\n\t\t<string>remote-notification</string>\n\t</array>\n"
            "</dict>\n</plist>",
        )
    if "LSApplicationQueriesSchemes" not in s:
        s = s.replace(
            "</dict>\n</plist>",
            "\t<key>LSApplicationQueriesSchemes</key>\n\t<array>\n\t\t<string>tel</string>\n\t\t<string>mailto</string>\n\t\t<string>https</string>\n\t</array>\n"
            "</dict>\n</plist>",
        )
    write(f, s)


def main() -> int:
    if not android.exists():
        print("android/ не найден — сначала выполните flutter create")
        return 1
    replace_package()
    patch_manifest()
    patch_app_gradle()
    patch_ios()
    print("Нативные проекты настроены.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
