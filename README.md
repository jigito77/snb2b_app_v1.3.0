# SNB2B — мобильное B2B-приложение (Flutter)

Нативное приложение для заказа запчастей грузовой техники и спецтехники: каталог, быстрый поиск,
фильтры, карточка товара, корзина, 5-шаговое оформление заказа, личный кабинет с B2B-ценами,
избранное, сравнение, push-уведомления. Android — сразу; iOS — тот же код (см. ниже).

> **Статус проверки.** Исходники написаны без доступа к Flutter SDK (в среде разработки закрыт
> pub.dev), поэтому **код ещё не прошёл `flutter analyze`, тесты и сборку**. Первый запуск
> `./tool/bootstrap.sh && flutter analyze` может показать мелкие замечания — это нужно исправить
> перед релизом. Пакет CI (`.github/workflows/android-apk.yml`) выполняет ровно эти шаги.

## Архитектура

```
lib/
  main.dart                  точка входа (prefs, восстановление сессии, push)
  app/                       composition root: di.dart, router.dart, app.dart, main_shell.dart, session_coordinator.dart
  core/
    constants/               AppConfig (флаги --dart-define)
    theme/                   цвета, типографика, ThemeData (Material 3)
    errors/                  AppException + русские сообщения об ошибках
    network/                 ApiClient → HttpApiClient (Dio, JWT, refresh) / MockApiClient
      mock/                  Mock API: каталог ~140 товаров, заказы, авторизация
    storage/                 secure token storage, LocalCache (офлайн-кэш)
    notifications/           PushService (FCM, не падает без Firebase-конфига)
    utils/                   форматирование, JSON, лаунчер (tel/mailto)
  features/<feature>/
    domain/                  сущности + абстрактные репозитории
    data/                    реализации репозиториев (API + кэш)
    presentation/            providers (Riverpod), pages, widgets
  shared/                    общие виджеты и состояние (избранное/сравнение/недавние)
```

Clean Architecture + Repository: UI → Riverpod-провайдеры → абстрактные репозитории → `ApiClient`.
Переключение Mock ↔ реальный backend — флаг сборки, код экранов не меняется.

Ключевые решения:
* **Local-first** корзина/избранное/сравнение: мгновенный отклик, фоновая синхронизация с сервером
  (debounce), слияние гостевых данных после входа, очистка при выходе.
* **JWT** в `flutter_secure_storage`, автообновление по 401 (single-flight), пароль не хранится.
* **Офлайн**: ответы каталога/заказов кэшируются; при отсутствии сети показываются сохранённые
  данные и баннер «Нет подключения».
* **B2B-цены**: персональная цена + оптовые ступени (`tiers`), минимальная партия, остатки.

## Быстрый старт

Нужен Flutter ≥ 3.22 (Dart ≥ 3.4), Android SDK, JDK 17.

```bash
# 1. Сгенерировать android/ и ios/ и применить настройки (package name, разрешения, подпись)
# (на Windows/Git Bash или если нет права на выполнение: bash ./tool/bootstrap.sh)
APP_ID=com.company.b2bapp APP_NAME="SNB2B" ./tool/bootstrap.sh

# 2. Проверка
flutter analyze
flutter test

# 3. Запуск в демо-режиме (Mock API)
flutter run
```

Демо-вход: **b2b@demo.ru / demo123** (B2B-клиент со скидкой, тестовые заказы 12341–12343).
Поиск по артикулу: введите `4076965`.

### Подключение реального backend

```bash
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.your-domain.ru \
            --dart-define=SUPPORT_PHONE="+7 (000) 000-00-00" --dart-define=SUPPORT_EMAIL=sales@your-domain.ru
```

Контракт — в [docs/API.md](docs/API.md).

## Сборка APK

```bash
# debug
flutter build apk --debug
# release (подписанный)
flutter build apk --release --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.your-domain.ru
# для Google Play
flutter build appbundle --release ...
```
Результат: `build/app/outputs/flutter-apk/app-release.apk`.

**Подпись release.** Создайте keystore и файл `android/key.properties`:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/абсолютный/путь/upload-keystore.jks
```
`bootstrap.sh` уже подключает чтение `key.properties`; без файла release подписывается debug-ключом
(только для проверки). Keystore и `key.properties` в `.gitignore` — не коммитьте.

**Сменить package name позже:** повторите `APP_ID=... ./tool/bootstrap.sh` на чистой копии
(удалите `android/` и `ios/`), либо замените id вручную в `android/app/build.gradle(.kts)`,
`AndroidManifest.xml`, каталоге `MainActivity`.

## Push-уведомления (FCM)

1. Создайте проект в Firebase, добавьте Android-приложение с вашим package name.
2. Скачайте `google-services.json` → `android/app/google-services.json`.
3. Запустите `./tool/bootstrap.sh` ещё раз — плагин `google-services` подключится автоматически.
4. Backend отправляет сообщения через FCM HTTP v1 на токены, полученные из `POST /api/devices`.

Без `google-services.json` приложение работает, push просто отключены.

## Подготовка к iOS

Код общий. На macOS с Xcode:

1. `./tool/bootstrap.sh` (создаст `ios/`, пропишет Info.plist: имя, ru-локаль, background modes,
   `LSApplicationQueriesSchemes`).
2. Откройте `ios/Runner.xcworkspace`, укажите Team и Bundle Identifier, включите capabilities
   **Push Notifications** и **Background Modes → Remote notifications**.
3. Firebase: добавьте `GoogleService-Info.plist` в Runner, загрузите APNs-ключ в Firebase Console.
4. Иконки и splash уже генерируются из `assets/icon/` (`flutter_launcher_icons`, `flutter_native_splash`);
   замените исходные картинки на фирменные и повторите `dart run flutter_launcher_icons && dart run flutter_native_splash:create`.
5. `flutter build ipa --release`.

## Что ещё нужно до продакшена

* Реальный backend по [docs/API.md](docs/API.md); серверный пересчёт цен/остатков; rate-limit на авторизацию.
* HTTPS-only на всех окружениях, certificate pinning (по требованиям безопасности).
* Фирменные цвета, шрифты, иконка и splash (сейчас — нейтральная палитра, не копия сайта).
* Тексты страниц «Доставка/Оплата/Гарантия/Контакты» — заменить реальными или отдавать с backend.
* Настоящие изображения товаров (сейчас заглушки по категории).
* Онлайн-оплата (эквайринг), если нужна; сейчас оплата — счёт/карта/наличные как выбор способа.
* Push: серверная отправка, deep-link по тапу на уведомление, отметка «прочитано».
* OTP-вход и OAuth: клиентский слой готов (`PhoneOtpCredentials`, `OAuthCredentials`), нужны endpoint'ы и UI.
* Аналитика и crash-репортинг (Firebase Crashlytics/Sentry), соглашения о персональных данных.
* Интеграционные и golden-тесты, прогон на реальных устройствах, проверка доступности (TalkBack).
* Подписанные релизы в Google Play / App Store, политика конфиденциальности.


## Бренд, дизайн и языки

**Бренд SNP.** Фирменные цвета — графит и жёлтый (`lib/core/theme/app_colors.dart`, цвет текста на жёлтом — `AppColors.onAccent`).
Логотипы лежат в `assets/brand/` (эмблема, горизонтальный знак для светлого и тёмного фона), иконка приложения и splash — в `assets/icon/`.
После замены картинок выполните: `dart run flutter_launcher_icons` и `dart run flutter_native_splash:create`.

**Языки.** Интерфейс переключается между Հայերեն, English, ქართული и Русский: кнопка-глобус на главной, на экране входа,
в профиле и в «Настройки → Язык приложения». Выбор сохраняется, по умолчанию берётся язык устройства (если он поддерживается, иначе русский).
Выбранный язык также уходит на сервер в заголовке `Accept-Language`.

Как это устроено:
- В коде строки написаны по-русски. Виджет `Text` из `lib/core/l10n/app_text.dart` подменяет стандартный и переводит строку по словарю;
  строки вне `Text` (подсказки, валидаторы) оборачиваются в `tr('…')`.
- Словари `lib/core/l10n/strings_*.dart` и правила для динамических строк (`rules.dart`) **генерируются** скриптом
  `python3 tool/i18n/gen.py` из `tool/i18n/part*.py` и `tool/i18n/rules.py`. Правьте переводы там, затем запускайте скрипт.
- Новая строка в интерфейсе: напишите её по-русски в `Text(...)`, добавьте строку `"ru": ("en", "hy", "ka")` в `tool/i18n/part*.py`
  и перегенерируйте словари. Непереведённая строка просто показывается по-русски.
- Новый язык: добавьте код в `L10n.languages`/`supportedLocales` (`lib/core/l10n/l10n.dart`), словарь в `gen.py` и поддержку в `flutter_localizations`.

## Встроенный каталог (режим без сервера)
`assets/data/catalog.json` — реальный каталог SNP (≈5000 позиций с snb2b.ru). Приложение в режиме по умолчанию (`USE_MOCK_API=true`)
загружает его при старте. Заказы в этом режиме остаются на устройстве (не уходят в компанию) — для приёма заказов нужен сервер (`server/`).


## Вложения в чате поддержки

Тот же `/api/chat/*`, та же база и приватное хранилище, что у сайта и админ-панели. В поле ввода — кнопка «скрепка»:
галерея / камера (`image_picker`) и документы PDF/Word/Excel/TXT (`file_picker`), до 10 файлов в сообщении.
Файл загружается сразу (один запрос — один файл, `X-Upload-Id` защищает от дублей при повторе), показывается прогресс,
при ошибке — «Повторить». Разрешённые типы и лимит размера приходят с сервера (`GET /api/chat/status` → `files`) и
настраиваются в админке (Чат → «Файлы»); окончательную проверку делает сервер. Картинки — превью и полноэкранный
просмотр с zoom, документы — карточки «Открыть / Скачать» (подписанные ссылки, открываются через `url_launcher`).
> Код вложений в приложении добавлен без доступа к Flutter SDK: проверьте `flutter analyze` и сборку в CI.
