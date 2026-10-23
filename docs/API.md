# Контракт backend API

Приложение работает с REST/JSON. По умолчанию данные отдаёт встроенный Mock API
(`lib/core/network/mock/`), который реализует **тот же контракт**. Чтобы перейти на реальный
сервер, достаточно собрать приложение с флагами:

```
--dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.your-domain.ru
```

Все пути начинаются с `/api`. Авторизация — заголовок `Authorization: Bearer <accessToken>`.
Ошибки: HTTP-статус 4xx/5xx и, желательно, тело `{"message": "Текст для пользователя"}` —
для 400/409/422 текст показывается пользователю как есть.
Все даты — ISO-8601, деньги — числа (рубли).

## Авторизация

| Метод | Путь | Тело / параметры | Ответ |
|---|---|---|---|
| POST | `/api/auth/login` | `{email, password}` | `{accessToken, refreshToken, user}` |
| POST | `/api/auth/register` | `{name, email, password, phone, companyName, inn}` | `{accessToken, refreshToken, user}` |
| POST | `/api/auth/refresh` | `{refreshToken}` | `{accessToken, refreshToken, user?}` |
| POST | `/api/auth/forgot-password` | `{email}` | `{ok:true}` (всегда 200 — не раскрывать существование аккаунта) |
| POST | `/api/auth/logout` | — | `{ok:true}` (инвалидировать refresh-токен) |
| POST | `/api/auth/otp/request` | `{phone}` | `{ok:true}` *(готово в клиенте, UI пока не включён)* |
| POST | `/api/auth/otp/verify` | `{phone, code}` | как login *(готово в клиенте)* |
| POST | `/api/auth/oauth` | `{provider, token}` | как login *(готово в клиенте)* |

Клиент при 401 один раз вызывает `/api/auth/refresh` (single-flight), повторяет запрос;
если refresh не удался — сессия сбрасывается и пользователю показывается «Сессия истекла».

**User:** `{id, name, email, phone, company:{name,inn,kpp,ogrn,legalAddress,bankName,bik,account,corrAccount}|null, isB2b, discountPercent, manager:{name,phone,email}|null}`

## Профиль

| Метод | Путь | Тело | Ответ |
|---|---|---|---|
| GET | `/api/profile` | — | User |
| PUT | `/api/profile` | `{name?, phone?, company?}` | User |
| GET | `/api/profile/addresses` | — | `{items:[Address]}` |
| POST | `/api/profile/addresses` | Address без id | Address |
| PUT | `/api/profile/addresses/{id}` | Address | Address |
| DELETE | `/api/profile/addresses/{id}` | — | `{ok:true}` |
| GET | `/api/manager` | — | `{name, phone, email}` (персональный менеджер, для гостя — отдел продаж) |

**Address:** `{id, title, city, street, comment, isDefault}`

## Каталог и поиск

| Метод | Путь | Параметры | Ответ |
|---|---|---|---|
| GET | `/api/categories` | — | `{items:[{id, name, parentId|null, productCount, icon?}]}` (плоский список, дерево по `parentId`) |
| GET | `/api/brands` | — | `{items:[{id, name, productCount}]}` |
| GET | `/api/catalog/filters` | — | `{manufacturers:[..], compatibilities:[..], priceMin, priceMax}` |
| GET | `/api/products` | `q, categoryId, brandId, manufacturer, priceFrom, priceTo, inStock, isNew, isPopular, isSpecial, compat, sort(popular\|price_asc\|price_desc\|name\|new), page, pageSize, ids` | `{items:[Product], total, page, pageSize}` |
| GET | `/api/products/{id}` | — | Product |
| GET | `/api/products/{id}/analogs` | — | `{items:[Product]}` |
| GET | `/api/search/suggest` | `q` | `{items:[{text, type(product\|brand\|category), id}]}` |
| GET | `/api/search/popular` | — | `{items:[string]}` |

Поиск `q` должен находить по артикулу, OEM-номеру, названию, бренду и категории, нормализуя регистр и
разделители (`4076965` → товар с этим артикулом/OEM). Для авторизованного B2B-клиента сервер
добавляет `personalPrice` в Product; оптовые ступени — в `priceTiers`.

**Product:** `{id, name, article, oem, brandId, brandName, categoryId, categoryName, manufacturer, description, price, oldPrice?, personalPrice?, priceTiers:[{minQty, price}], stock:{available, warehouse}, delivery:{minDays, maxDays}, minQty, images:[url], attributes:[{name,value}], compatibility:[string], analogIds:[id], isNew, isPopular, isSpecial}`

## Корзина, избранное, сравнение (синхронизация)

Для гостей данные хранятся только на устройстве. После входа клиент объединяет локальные и
серверные данные и затем отправляет итоговый список (debounce ~600 мс).

| Метод | Путь | Тело | Ответ |
|---|---|---|---|
| GET | `/api/cart` | — | `{items:[{product:Product, qty}]}` |
| PUT | `/api/cart` | `{items:[{productId, qty}]}` | `{ok:true}` |
| GET | `/api/favorites` | — | `{ids:[id]}` |
| PUT | `/api/favorites` | `{ids:[id]}` | `{ok:true}` |
| GET | `/api/comparison` | — | `{ids:[id]}` |
| PUT | `/api/comparison` | `{ids:[id]}` | `{ok:true}` |

## Заказы и заявки

| Метод | Путь | Тело | Ответ |
|---|---|---|---|
| GET | `/api/orders` | — | `{items:[Order]}` |
| GET | `/api/orders/{id}` | — | Order |
| POST | `/api/orders` | `{contact:{name,company,phone,email}, delivery:{method,address}, payment:{method}, comment, items:[{productId,qty}]}` | Order (с `number`, например `12345`) |
| POST | `/api/orders/quick` | `{productId, qty, name, phone}` | `{ok:true}` — «Купить в 1 клик», доступно гостю |
| POST | `/api/orders/{id}/invoice` | — | `{ok:true}` — запрос счёта |
| POST | `/api/requests/quote` | `{contact:{name,phone,email}, comment, items:[{productId,qty}]}` | `{ok:true, number}` — запрос КП, доступно гостю |

`delivery.method`: `pickup | courier | transport`; `payment.method`: `invoice | card | cash`.
`Order.status`: `accepted | confirmed | shipped | delivered | cancelled`.

**Order:** `{id, number, createdAt, status, items:[{productId,name,article,qty,price}], total, deliveryMethod, paymentMethod, address, contactName, phone, email, company, comment, managerComment}`

Сервер **обязан** пересчитывать цены и наличие при создании заказа (клиентским ценам не доверять).

## Контент

| Метод | Путь | Ответ |
|---|---|---|
| GET | `/api/banners` | `{items:[{id,title,subtitle,badge,color(navy\|orange\|teal),action}]}` — `action` это маршрут приложения, напр. `/products?isSpecial=true` |
| GET | `/api/news` | `{items:[{id,title,date,summary}]}` |
| GET | `/api/news/{id}` | `{id,title,date,summary,body}` |

## Уведомления и push

| Метод | Путь | Тело | Ответ |
|---|---|---|---|
| GET | `/api/notifications` | — | `{items:[{id,title,body,type,createdAt,isRead,orderId?}]}` |
| PUT | `/api/notifications/settings` | `{orderStatus, priceChange, inStock, promo}` (bool) | `{ok:true}` |
| POST | `/api/devices` | `{fcmToken, platform(android\|ios)}` | `{ok:true}` |

`type`: `order_accepted | order_confirmed | order_shipped | order_delivered | price_changed | back_in_stock | promo`.
FCM data-сообщение: `{type, orderId?}` + notification `{title, body}`.

## Язык ответов

Клиент отправляет заголовок `Accept-Language: hy | en | ka | ru` (язык интерфейса). Backend может возвращать локализованные
названия категорий, описания и новости; если локализации нет — достаточно вернуть русский текст, приложение покажет его как есть
(известные строки из справочников приложение переведёт само).

## Готовый сервер
В папке `server/` лежит реализация этого контракта + админ-панель (см. `server/README.md`).
