# SNP — мобильное приложение на том же backend

Схема: **сайт → backend/API (snp.am) → Android-приложение**. Данные, пользователи, заказы, цены, вес, доставка и курсы —
одни и те же. Приложение ничего не считает само: показывает ответ сервера. Ни ключей, ни секретов в приложении нет.

## Что использует приложение (существующие endpoints, новых нет)
| Назначение | Endpoint |
|---|---|
| Каталог, карточка | `GET /api/products`, `GET /api/products/:id` (ORG/OEM/SNP, `offers[]`, `weightKg`) |
| Цены / ступени опта / вес | `POST /api/prices` (`productId`, `offer`, `qty`) |
| Корзина | `GET/PUT /api/cart` (`productId`, `offer`, `qty`) |
| Карта | `GET /api/geo/search?q=`, `GET /api/geo/reverse?lat=&lng=` (OpenStreetMap, как на сайте) |
| Доставка | `POST /api/delivery/calculate` — `расстояние/1000 × вес × тариф` считает сервер |
| Заказ | `POST /api/orders` (только верифицированный), `GET /api/orders`, `GET /api/orders/:id` |
| Валюта | заголовок `X-Currency: AMD|RUB|USD|EUR` — суммы приходят уже в этой валюте |
| Вход | `POST /api/auth/login`, `/api/auth/register`, `POST /api/auth/oauth/google` (idToken) |
| Статус верификации | `user.verification` в ответах auth/profile, `GET /api/account/verification` |
| Уведомления | `GET /api/notifications`, `POST /api/devices` (FCM-токен) |

## Сборка
GitHub Actions → *Android APK* → Run workflow (значения по умолчанию: backend `https://snp.am`, id `am.snp.shop`).
Локально:
```
flutter build apk --release --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://snp.am ^
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID>
```
APK: `build/app/outputs/flutter-apk/app-release.apk`.

## Окружение
- Сервер: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` (+ `GOOGLE_MOBILE_CLIENT_IDS` при необходимости) в `/etc/snp.env`.
- Приложение: `API_BASE_URL`, `USE_MOCK_API=false`, `GOOGLE_SERVER_CLIENT_ID`.
- Google Cloud: OAuth-клиент типа **Android** (package `am.snp.shop` + SHA-1 ключа подписи).
- Push: `google-services.json` в `android/app/` + серверная отправка FCM (в backend пока только хранение токенов и ленты уведомлений).

## Права Android
`INTERNET`, `POST_NOTIFICATIONS`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` (только по кнопке «Моё местоположение»).

## Проверки
- `node server/test/mobile.js` — контракт backend для приложения (цены, ступени, вес, доставка $6.75 при 3000 км × 0.9 кг, заказ, верификация, уведомления).
- `flutter test` — модели приложения (`test/mobile_parity_test.dart`).

## Чат поддержки (v1.2.0)

Экран «Профиль → Чат с поддержкой» (`/support/chat`) использует **тот же backend и ту же базу**, что виджет на сайте и раздел «Чат» в админ-панели: `GET /api/chat/me`, `POST /api/chat/messages`, `POST /api/chat/read` (Bearer-токен пользователя). Обновление — опрос раз в 3 с, пока экран открыт; ответ оператора при закрытом приложении попадает в «Уведомления». Диалог привязан к аккаунту; гостевого чата в приложении нет (нужен вход). ИИ-ассистент не подключён — отвечает реальный оператор.
