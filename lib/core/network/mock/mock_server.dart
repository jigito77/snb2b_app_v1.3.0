import '../../errors/app_exception.dart';
import '../../utils/json_utils.dart';
import 'mock_catalog.dart';

class _MockUser {
  _MockUser({required this.json, required this.password});

  Json json;
  String password;
  List<Json> cart = <Json>[];
  List<String> favorites = <String>[];
  List<String> comparison = <String>[];
  List<Json> orders = <Json>[];
  List<Json> addresses = <Json>[];
  List<Json> notifications = <Json>[];
}

/// Имитация backend. Принимает те же запросы, что и реальный API, и отвечает
/// JSON-структурами контракта (см. docs/API.md). Состояние хранится в памяти процесса.
class MockServer {
  MockServer() {
    _seed();
  }

  static const String demoEmail = 'b2b@demo.ru';
  static const String demoPassword = 'demo123';

  final Map<String, _MockUser> _users = <String, _MockUser>{};
  int _orderSeq = 12344;
  int _idSeq = 100;

  static const Json _defaultManager = <String, dynamic>{
    'name': 'Анна Смирнова',
    'phone': '+374 (98) 898-584',
    'email': '',
  };

  // ---------------------------------------------------------------- tokens

  static String accessTokenFor(String email) => 'mock-access|$email';
  static String refreshTokenFor(String email) => 'mock-refresh|$email';

  _MockUser? _userFromToken(String? token) {
    if (token == null || !token.startsWith('mock-access|')) return null;
    return _users[token.substring('mock-access|'.length)];
  }

  _MockUser _require(String? token) {
    final user = _userFromToken(token);
    if (user == null) throw const AppException.unauthorized();
    return user;
  }

  Json _session(_MockUser user) => <String, dynamic>{
        'accessToken': accessTokenFor(user.json['email'] as String),
        'refreshToken': refreshTokenFor(user.json['email'] as String),
        'user': user.json,
      };

  // ---------------------------------------------------------------- routing

  dynamic handle(String method, String path, Map<String, dynamic> query, dynamic body, String? token) {
    final segments = path.split('?').first.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.first != 'api') throw const AppException.notFound();
    final r = segments.sublist(1);
    String at(int i) => i < r.length ? r[i] : '';
    final user = _userFromToken(token);

    switch (at(0)) {
      case 'auth':
        return _authRoutes(method, at(1), body, token);
      case 'profile':
        return _profileRoutes(method, r, body, token);
      case 'products':
        return _productRoutes(method, r, query, user);
      case 'catalog':
        if (at(1) == 'filters') return _filterOptions();
        break;
      case 'categories':
        return <String, dynamic>{'items': MockCatalog.categories};
      case 'brands':
        return <String, dynamic>{'items': MockCatalog.brands};
      case 'search':
        if (at(1) == 'suggest') return _suggest((query['q'] ?? '').toString());
        if (at(1) == 'popular') return <String, dynamic>{'items': MockCatalog.popularQueries};
        break;
      case 'banners':
        return <String, dynamic>{'items': _banners};
      case 'news':
        return _newsRoutes(at(1));
      case 'manager':
        return user?.json['manager'] ?? _defaultManager;
      case 'cart':
        return _cartRoutes(method, body, token);
      case 'favorites':
        return _idListRoutes(method, body, token, favorites: true);
      case 'comparison':
        return _idListRoutes(method, body, token, favorites: false);
      case 'orders':
        return _orderRoutes(method, r, body, token, user);
      case 'requests':
        if (at(1) == 'quote' && method == 'POST') {
          return <String, dynamic>{'ok': true, 'number': 'КП-${++_idSeq}'};
        }
        break;
      case 'notifications':
        return _notificationRoutes(method, at(1), token);
      case 'chat':
        return _chatRoutes(method, at(1), body, token);
      case 'devices':
        _require(token);
        return <String, dynamic>{'ok': true};
    }
    throw const AppException.notFound();
  }

  // ------------------------------------------------------------------ chat (demo)

  final List<Map<String, dynamic>> _chatMsgs = <Map<String, dynamic>>[];
  final Map<String, Map<String, dynamic>> _chatFiles = <String, Map<String, dynamic>>{};

  /// Демо-загрузка файла в чат: файл нигде не хранится, в сообщении остаётся карточка без ссылки.
  Map<String, dynamic> mockUpload(String name, String mime, int size, String uploadId) {
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    const images = <String>['jpg', 'jpeg', 'png', 'webp'];
    final kind = images.contains(ext)
        ? 'image'
        : ext == 'pdf'
            ? 'pdf'
            : (ext == 'doc' || ext == 'docx')
                ? 'word'
                : (ext == 'xls' || ext == 'xlsx')
                    ? 'excel'
                    : 'text';
    final id = 'f-$uploadId';
    final att = <String, dynamic>{
      'id': id,
      'name': name,
      'ext': ext,
      'mime': mime,
      'kind': kind,
      'size': size,
      'at': DateTime.now().toUtc().toIso8601String(),
      'url': '',
    };
    _chatFiles[id] = att;
    return <String, dynamic>{'attachment': att};
  }

  dynamic _chatRoutes(String method, String sub, dynamic body, String? token) {
    _require(token);
    Map<String, dynamic>? conv() => _chatMsgs.isEmpty
        ? null
        : <String, dynamic>{
            'id': 'c-mock',
            'status': 'open',
            'type': 'HUMAN',
            'unread': 0,
            'messages': List<Map<String, dynamic>>.from(_chatMsgs),
          };
    if (sub == 'status') {
      return <String, dynamic>{
        'online': false,
        'files': <String, dynamic>{'enabled': true, 'maxMb': 25, 'exts': <String>['jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt']},
      };
    }
    if (sub == 'me') return <String, dynamic>{'online': false, 'conversation': conv()};
    if (sub == 'read' || sub == 'typing') return <String, dynamic>{'ok': true};
    if (sub == 'messages' && method == 'POST') {
      final text = ((body is Map ? body['text'] : null) ?? '').toString().trim();
      final ids = body is Map && body['attachments'] is List ? (body['attachments'] as List).map((e) => '$e').toList() : <String>[];
      final atts = <Map<String, dynamic>>[for (final i in ids) if (_chatFiles.containsKey(i)) _chatFiles.remove(i)!];
      if (text.isEmpty && atts.isEmpty) throw const AppException.validation('Введите сообщение.');
      _chatMsgs.add(<String, dynamic>{
        'id': 'm${++_idSeq}',
        'sender': 'customer',
        'senderName': '',
        'text': text,
        'at': DateTime.now().toUtc().toIso8601String(),
        'readAt': null,
        'attachments': atts,
      });
      return <String, dynamic>{'online': false, 'conversation': conv()};
    }
    throw const AppException.notFound();
  }

  // ------------------------------------------------------------------ auth

  dynamic _authRoutes(String method, String action, dynamic body, String? token) {
    final b = body is Map ? asJson(body) : <String, dynamic>{};
    switch (action) {
      case 'login':
        {
          final email = b.str('email').trim().toLowerCase();
          final user = _users[email];
          if (user == null || user.password != b.str('password')) {
            throw const AppException.validation('Неверный email или пароль.', statusCode: 400);
          }
          return _session(user);
        }
      case 'register':
        {
          final email = b.str('email').trim().toLowerCase();
          if (email.isEmpty || !email.contains('@')) {
            throw const AppException.validation('Укажите корректный email.', statusCode: 422);
          }
          if (_users.containsKey(email)) {
            throw const AppException.validation(
                'Пользователь с таким email уже зарегистрирован.', statusCode: 409);
          }
          final hasCompany = b.str('companyName').trim().isNotEmpty;
          final user = _MockUser(
            password: b.str('password'),
            json: <String, dynamic>{
              'id': 'u${++_idSeq}',
              'name': b.str('name'),
              'email': email,
              'phone': b.str('phone'),
              'company': hasCompany
                  ? <String, dynamic>{'name': b.str('companyName'), 'inn': b.str('inn')}
                  : null,
              'isB2b': false,
              'discountPercent': 0,
              'manager': null,
            },
          );
          _users[email] = user;
          return _session(user);
        }
      case 'refresh':
        {
          final refresh = b.str('refreshToken');
          if (!refresh.startsWith('mock-refresh|')) throw const AppException.unauthorized();
          final user = _users[refresh.substring('mock-refresh|'.length)];
          if (user == null) throw const AppException.unauthorized();
          return _session(user);
        }
      case 'forgot-password':
        if (b.str('email').trim().isEmpty) {
          throw const AppException.validation('Укажите email.', statusCode: 422);
        }
        return <String, dynamic>{'ok': true};
      case 'logout':
        return <String, dynamic>{'ok': true};
      case 'otp':
      case 'oauth':
        throw const AppException.validation('Способ входа пока не поддерживается.');
    }
    throw const AppException.notFound();
  }

  dynamic _profileRoutes(String method, List<String> r, dynamic body, String? token) {
    final user = _require(token);
    final sub = r.length > 1 ? r[1] : '';
    if (sub.isEmpty) {
      if (method == 'GET') return user.json;
      if (method == 'PUT') {
        final b = asJson(body);
        if (b.containsKey('name')) user.json['name'] = b['name'];
        if (b.containsKey('phone')) user.json['phone'] = b['phone'];
        if (b['company'] != null) user.json['company'] = b['company'];
        return user.json;
      }
    }
    if (sub == 'addresses') {
      final id = r.length > 2 ? r[2] : '';
      if (method == 'GET') return <String, dynamic>{'items': user.addresses};
      if (method == 'POST') {
        final a = Map<String, dynamic>.from(asJson(body))..['id'] = 'a${++_idSeq}';
        _applyDefaultAddress(user, a);
        user.addresses.add(a);
        return a;
      }
      if (method == 'PUT') {
        final a = Map<String, dynamic>.from(asJson(body))..['id'] = id;
        final i = user.addresses.indexWhere((e) => e['id'] == id);
        if (i < 0) throw const AppException.notFound();
        _applyDefaultAddress(user, a);
        user.addresses[i] = a;
        return a;
      }
      if (method == 'DELETE') {
        user.addresses.removeWhere((e) => e['id'] == id);
        return <String, dynamic>{'ok': true};
      }
    }
    throw const AppException.notFound();
  }

  void _applyDefaultAddress(_MockUser user, Json address) {
    if (address['isDefault'] == true || user.addresses.isEmpty) {
      address['isDefault'] = true;
      for (final other in user.addresses) {
        if (other['id'] != address['id']) other['isDefault'] = false;
      }
    }
  }

  // --------------------------------------------------------------- catalog

  Json _productFor(Json base, _MockUser? user) {
    final copy = Map<String, dynamic>.from(base);
    final discount = (user?.json['discountPercent'] as num?)?.toDouble() ?? 0;
    if (user != null && user.json['isB2b'] == true && discount > 0) {
      final price = (base['price'] as num).toDouble();
      copy['personalPrice'] = ((price * (1 - discount / 100)) / 10).round() * 10.0;
    }
    return copy;
  }

  dynamic _productRoutes(String method, List<String> r, Map<String, dynamic> q, _MockUser? user) {
    if (method != 'GET') throw const AppException.notFound();
    if (r.length == 1) return _productList(q, user);
    final id = r[1];
    final product = MockCatalog.byId[id];
    if (product == null) throw const AppException.notFound();
    if (r.length == 2) return _productFor(product, user);
    if (r[2] == 'analogs') {
      final ids = (product['analogIds'] as List).map((e) => e.toString());
      return <String, dynamic>{
        'items': ids.map((i) => _productFor(MockCatalog.byId[i]!, user)).toList(),
      };
    }
    throw const AppException.notFound();
  }

  Json _productList(Map<String, dynamic> q, _MockUser? user) {
    final page = int.tryParse('${q['page']}') ?? 1;
    final pageSize = int.tryParse('${q['pageSize']}') ?? 20;

    List<Json> list;
    final idsParam = q['ids']?.toString();
    if (idsParam != null && idsParam.isNotEmpty) {
      list = idsParam
          .split(',')
          .map((id) => MockCatalog.byId[id])
          .whereType<Json>()
          .toList();
    } else {
      list = _filterProducts(q);
    }

    final total = list.length;
    final start = (page - 1) * pageSize;
    final end = start + pageSize > total ? total : start + pageSize;
    final slice = start >= total ? <Json>[] : list.sublist(start, end);
    return <String, dynamic>{
      'items': slice.map((p) => _productFor(p, user)).toList(),
      'total': total,
      'page': page,
      'pageSize': pageSize,
    };
  }

  static String _norm(Object? v) =>
      v.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-яё]'), '');

  int _score(Json p, List<String> tokens) {
    final art = _norm(p['article']);
    final oem = _norm(p['oem']);
    final hay =
        '${p['name']} ${p['brandName']} ${p['categoryName']} ${p['manufacturer']}'.toLowerCase();
    var total = 0;
    for (final t in tokens) {
      final nt = _norm(t);
      var s = 0;
      if (nt.isNotEmpty && (art == nt || oem == nt)) {
        s = 1000;
      } else if (nt.isNotEmpty && (art.startsWith(nt) || oem.startsWith(nt))) {
        s = 500;
      } else if (nt.length >= 3 && (art.contains(nt) || oem.contains(nt))) {
        s = 300;
      } else if (hay.contains(t)) {
        s = 100;
      }
      if (s == 0) return 0;
      total += s;
    }
    return total;
  }

  List<Json> _filterProducts(Map<String, dynamic> q) {
    bool flag(String k) => '${q[k]}' == 'true';
    String? str(String k) {
      final v = q[k]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    final categoryId = str('categoryId');
    final categoryIds = categoryId == null
        ? <String>{}
        : <String>{categoryId, ...MockCatalog.childrenOf(categoryId)};
    final brandId = str('brandId');
    final manufacturer = str('manufacturer');
    final compat = str('compat')?.toLowerCase();
    final priceFrom = double.tryParse('${q['priceFrom']}');
    final priceTo = double.tryParse('${q['priceTo']}');
    final query = (q['q'] ?? '').toString().trim().toLowerCase();
    final tokens = query.isEmpty ? <String>[] : query.split(RegExp(r'\s+'));
    final scores = <String, int>{};

    final result = MockCatalog.products.where((p) {
      if (categoryId != null && !categoryIds.contains(p['categoryId'])) return false;
      if (brandId != null && p['brandId'] != brandId) return false;
      if (manufacturer != null && p['manufacturer'] != manufacturer) return false;
      final price = (p['price'] as num).toDouble();
      if (priceFrom != null && price < priceFrom) return false;
      if (priceTo != null && price > priceTo) return false;
      if (flag('inStock') && (p['stock'] as Map)['available'] == 0) return false;
      if (flag('isNew') && p['isNew'] != true) return false;
      if (flag('isPopular') && p['isPopular'] != true) return false;
      if (flag('isSpecial') && p['isSpecial'] != true) return false;
      if (compat != null &&
          !(p['compatibility'] as List).any((c) => c.toString().toLowerCase().contains(compat))) {
        return false;
      }
      if (tokens.isNotEmpty) {
        final s = _score(p, tokens);
        if (s == 0) return false;
        scores[p['id'] as String] = s;
      }
      return true;
    }).toList();

    final sort = str('sort') ?? 'popular';
    int byId(Json a, Json b) => _idNum(a).compareTo(_idNum(b));
    switch (sort) {
      case 'price_asc':
        result.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
        break;
      case 'price_desc':
        result.sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
        break;
      case 'name':
        result.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        break;
      case 'new':
        result.sort((a, b) {
          final c = (b['isNew'] == true ? 1 : 0).compareTo(a['isNew'] == true ? 1 : 0);
          return c != 0 ? c : byId(a, b);
        });
        break;
      default:
        if (tokens.isNotEmpty) {
          result.sort((a, b) {
            final c = (scores[b['id']] ?? 0).compareTo(scores[a['id']] ?? 0);
            return c != 0 ? c : byId(a, b);
          });
        } else {
          result.sort((a, b) {
            final c = (b['isPopular'] == true ? 1 : 0).compareTo(a['isPopular'] == true ? 1 : 0);
            return c != 0 ? c : byId(a, b);
          });
        }
    }
    return result;
  }

  int _idNum(Json p) => int.tryParse((p['id'] as String).substring(1)) ?? 0;

  Json _filterOptions() {
    final prices = MockCatalog.products.map((p) => (p['price'] as num).toDouble()).toList()..sort();
    return <String, dynamic>{
      'manufacturers': MockCatalog.manufacturers,
      'compatibilities': MockCatalog.compatibilities,
      'priceMin': prices.first,
      'priceMax': prices.last,
    };
  }

  Json _suggest(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return <String, dynamic>{'items': <Json>[]};
    final tokens = q.split(RegExp(r'\s+'));
    final scored = <MapEntry<Json, int>>[];
    for (final p in MockCatalog.products) {
      final s = _score(p, tokens);
      if (s > 0) scored.add(MapEntry<Json, int>(p, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    final items = <Json>[];
    for (final b in MockCatalog.brands) {
      if ((b['name'] as String).toLowerCase().contains(q)) {
        items.add(<String, dynamic>{'text': b['name'], 'type': 'brand', 'id': b['id']});
      }
    }
    for (final c in MockCatalog.categories) {
      if ((c['name'] as String).toLowerCase().contains(q)) {
        items.add(<String, dynamic>{'text': c['name'], 'type': 'category', 'id': c['id']});
      }
    }
    for (final e in scored.take(5)) {
      items.add(<String, dynamic>{
        'text': e.key['name'],
        'type': 'product',
        'id': e.key['id'],
        'subtitle': e.key['article'],
      });
    }
    return <String, dynamic>{'items': items.take(8).toList()};
  }

  // --------------------------------------------------------------- content

  static final List<Json> _banners = <Json>[
    <String, dynamic>{
      'id': 'b1',
      'title': 'Спецпредложения месяца',
      'subtitle': 'Выгодные цены на фильтры, тормозную систему и сцепление',
      'badge': 'Акция',
      'color': 'orange',
      'action': '/products?isSpecial=true&title=Спецпредложения',
    },
    <String, dynamic>{
      'id': 'b2',
      'title': 'Оптовые цены для B2B',
      'subtitle': 'Чем больше партия — тем ниже цена за единицу',
      'badge': 'B2B',
      'color': 'navy',
      'action': '/info/delivery',
    },
    <String, dynamic>{
      'id': 'b3',
      'title': 'Новинки каталога',
      'subtitle': 'Свежие поступления Volvo, Scania, Caterpillar и SANY',
      'badge': 'Новинки',
      'color': 'teal',
      'action': '/products?isNew=true&title=Новинки',
    },
  ];

  static final List<Json> _news = <Json>[
    <String, dynamic>{
      'id': 'n1',
      'title': 'Расширение ассортимента запчастей Volvo Trucks',
      'date': '2026-09-28T09:00:00Z',
      'summary': 'В каталоге появились новые позиции по двигателю и тормозной системе.',
      'body': 'В каталоге появились новые позиции по двигателю, топливной и тормозной системам. '
          'Полный список доступен в разделе «Каталог». Это демонстрационная новость.',
    },
    <String, dynamic>{
      'id': 'n2',
      'title': 'Обновлены оптовые условия для автопарков',
      'date': '2026-09-15T09:00:00Z',
      'summary': 'Новые ступени оптовых цен при заказе от 5 и от 20 единиц.',
      'body': 'Для постоянных клиентов действуют персональные цены, а для всех B2B-заказов — '
          'ступенчатые оптовые цены. Подробности уточняйте у менеджера. Демонстрационная новость.',
    },
    <String, dynamic>{
      'id': 'n3',
      'title': 'Поступление сцеплений SACHS',
      'date': '2026-09-02T09:00:00Z',
      'summary': 'Комплекты сцепления для Volvo FH, Scania R и КАМАЗ уже на складе.',
      'body': 'На склад поступили комплекты сцепления SACHS. Оформите заказ в приложении или '
          'запросите коммерческое предложение. Демонстрационная новость.',
    },
    <String, dynamic>{
      'id': 'n4',
      'title': 'Новое мобильное приложение для клиентов',
      'date': '2026-08-20T09:00:00Z',
      'summary': 'Поиск по артикулу, история заказов и персональные цены — всегда под рукой.',
      'body': 'Мобильное приложение помогает быстро найти запчасть по артикулу или OEM-номеру, '
          'повторить заказ и связаться с менеджером. Демонстрационная новость.',
    },
  ];

  dynamic _newsRoutes(String id) {
    if (id.isEmpty) return <String, dynamic>{'items': _news};
    final item = _news.where((n) => n['id'] == id);
    if (item.isEmpty) throw const AppException.notFound();
    return item.first;
  }

  // ------------------------------------------------------- cart/favorites

  dynamic _cartRoutes(String method, dynamic body, String? token) {
    final user = _require(token);
    if (method == 'GET') {
      return <String, dynamic>{
        'items': user.cart
            .map((l) => <String, dynamic>{
                  'product': _productFor(MockCatalog.byId[l['productId']]!, user),
                  'qty': l['qty'],
                })
            .toList(),
      };
    }
    if (method == 'PUT') {
      final items = asJson(body).list('items');
      user.cart = items.where((l) => MockCatalog.byId.containsKey(l['productId'])).toList();
      return <String, dynamic>{'ok': true};
    }
    throw const AppException.notFound();
  }

  dynamic _idListRoutes(String method, dynamic body, String? token, {required bool favorites}) {
    final user = _require(token);
    if (method == 'GET') {
      return <String, dynamic>{'ids': favorites ? user.favorites : user.comparison};
    }
    if (method == 'PUT') {
      final ids = asJson(body).strings('ids');
      if (favorites) {
        user.favorites = ids;
      } else {
        user.comparison = ids;
      }
      return <String, dynamic>{'ok': true};
    }
    throw const AppException.notFound();
  }

  // ----------------------------------------------------------------- orders

  double _unitPrice(Json product, _MockUser? user, int qty) {
    final withPersonal = _productFor(product, user);
    var best = (withPersonal['personalPrice'] as num?)?.toDouble() ??
        (product['price'] as num).toDouble();
    for (final t in (product['priceTiers'] as List)) {
      final tier = t as Map;
      if (qty >= (tier['minQty'] as num) && (tier['price'] as num) < best) {
        best = (tier['price'] as num).toDouble();
      }
    }
    return best;
  }

  Json _buildOrder({
    required _MockUser user,
    required int number,
    required DateTime createdAt,
    required String status,
    required List<MapEntry<String, int>> lines,
    String deliveryMethod = 'courier',
    String paymentMethod = 'invoice',
    String address = 'Москва, ул. Складская, 12',
    String comment = '',
    String managerComment = '',
    Json? contact,
  }) {
    final items = <Json>[];
    var total = 0.0;
    for (final line in lines) {
      final p = MockCatalog.byId[line.key]!;
      final price = _unitPrice(p, user, line.value);
      total += price * line.value;
      items.add(<String, dynamic>{
        'productId': p['id'],
        'name': p['name'],
        'article': p['article'],
        'qty': line.value,
        'price': price,
      });
    }
    final company = user.json['company'];
    return <String, dynamic>{
      'id': 'o$number',
      'number': '$number',
      'createdAt': createdAt.toUtc().toIso8601String(),
      'status': status,
      'items': items,
      'total': total,
      'deliveryMethod': deliveryMethod,
      'paymentMethod': paymentMethod,
      'address': address,
      'contactName': contact?['name'] ?? user.json['name'],
      'phone': contact?['phone'] ?? user.json['phone'],
      'email': contact?['email'] ?? user.json['email'],
      'company': contact?['company'] ?? (company is Map ? company['name'] : ''),
      'comment': comment,
      'managerComment': managerComment,
    };
  }

  dynamic _orderRoutes(String method, List<String> r, dynamic body, String? token, _MockUser? user) {
    final sub = r.length > 1 ? r[1] : '';

    // Публичная заявка «Купить в 1 клик» — без авторизации.
    if (sub == 'quick' && method == 'POST') {
      final b = asJson(body);
      if (!MockCatalog.byId.containsKey(b.str('productId'))) throw const AppException.notFound();
      return <String, dynamic>{'ok': true, 'number': 'Q-${++_idSeq}'};
    }

    final u = _require(token);
    if (method == 'GET' && sub.isEmpty) {
      final sorted = List<Json>.from(u.orders)
        ..sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
      return <String, dynamic>{'items': sorted};
    }
    if (method == 'GET') {
      final found = u.orders.where((o) => o['id'] == sub);
      if (found.isEmpty) throw const AppException.notFound();
      return found.first;
    }
    if (method == 'POST' && sub.isEmpty) {
      final b = asJson(body);
      final lines = <MapEntry<String, int>>[];
      for (final l in b.list('items')) {
        final p = MockCatalog.byId[l.str('productId')];
        if (p == null) throw const AppException.notFound();
        if ((p['stock'] as Map)['available'] == 0) throw const AppException.outOfStock();
        lines.add(MapEntry<String, int>(p['id'] as String, l.integer('qty', 1)));
      }
      if (lines.isEmpty) {
        throw const AppException.validation('Корзина пуста.', statusCode: 422);
      }
      final delivery = b.obj('delivery') ?? <String, dynamic>{};
      final payment = b.obj('payment') ?? <String, dynamic>{};
      final order = _buildOrder(
        user: u,
        number: ++_orderSeq,
        createdAt: DateTime.now(),
        status: 'accepted',
        lines: lines,
        deliveryMethod: delivery.str('method', 'pickup'),
        paymentMethod: payment.str('method', 'invoice'),
        address: delivery.str('address'),
        comment: b.str('comment'),
        contact: b.obj('contact'),
      );
      u.orders.add(order);
      u.cart = <Json>[];
      u.notifications.insert(0, <String, dynamic>{
        'id': 'nt${++_idSeq}',
        'title': 'Заказ №${order['number']} принят',
        'body': 'Менеджер свяжется с вами для подтверждения.',
        'type': 'order_accepted',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'isRead': false,
        'orderId': order['id'],
      });
      return order;
    }
    if (method == 'POST' && r.length > 2 && r[2] == 'invoice') {
      if (!u.orders.any((o) => o['id'] == sub)) throw const AppException.notFound();
      return <String, dynamic>{'ok': true};
    }
    throw const AppException.notFound();
  }

  dynamic _notificationRoutes(String method, String sub, String? token) {
    final user = _require(token);
    if (method == 'GET') return <String, dynamic>{'items': user.notifications};
    if (method == 'PUT' && sub == 'settings') return <String, dynamic>{'ok': true};
    throw const AppException.notFound();
  }

  // ------------------------------------------------------------------ seed

  void _seed() {
    final demo = _MockUser(
      password: demoPassword,
      json: <String, dynamic>{
        'id': 'u1',
        'name': 'Иван Петров',
        'email': demoEmail,
        'phone': '+7 900 000-00-00',
        'company': <String, dynamic>{
          'name': 'ООО «ТрансЛогистик»',
          'inn': '7701234567',
          'kpp': '770101001',
          'ogrn': '1157700000000',
          'legalAddress': 'г. Москва, ул. Складская, д. 12',
          'bankName': 'АО «Демо-Банк»',
          'bik': '044525000',
          'account': '40702810000000000000',
          'corrAccount': '30101810000000000000',
        },
        'isB2b': true,
        'discountPercent': 7,
        'manager': _defaultManager,
      },
    );
    demo.addresses = <Json>[
      <String, dynamic>{
        'id': 'a1',
        'title': 'Склад',
        'city': 'Москва',
        'street': 'ул. Складская, 12',
        'comment': 'Въезд со стороны шлагбаума',
        'isDefault': true,
      },
      <String, dynamic>{
        'id': 'a2',
        'title': 'Автопарк',
        'city': 'Санкт-Петербург',
        'street': 'Промышленная ул., 5',
        'comment': '',
        'isDefault': false,
      },
    ];
    _users[demoEmail] = demo;

    final now = DateTime.now();
    demo.orders = <Json>[
      _buildOrder(
        user: demo,
        number: 12341,
        createdAt: now.subtract(const Duration(days: 32)),
        status: 'delivered',
        lines: <MapEntry<String, int>>[
          const MapEntry<String, int>('p18', 4),
          const MapEntry<String, int>('p19', 2),
        ],
        managerComment: 'Отгружено со склада в Москве.',
      ),
      _buildOrder(
        user: demo,
        number: 12342,
        createdAt: now.subtract(const Duration(days: 4)),
        status: 'shipped',
        lines: <MapEntry<String, int>>[
          const MapEntry<String, int>('p22', 1),
          const MapEntry<String, int>('p24', 6),
          const MapEntry<String, int>('p29', 2),
        ],
        deliveryMethod: 'transport',
      ),
      _buildOrder(
        user: demo,
        number: 12343,
        createdAt: now.subtract(const Duration(days: 1)),
        status: 'confirmed',
        lines: <MapEntry<String, int>>[
          const MapEntry<String, int>('p26', 10),
        ],
        deliveryMethod: 'pickup',
        paymentMethod: 'card',
        address: '',
      ),
    ];
    demo.notifications = <Json>[
      <String, dynamic>{
        'id': 'nt1',
        'title': 'Заказ №12342 отправлен',
        'body': 'Заказ передан в транспортную компанию.',
        'type': 'order_shipped',
        'createdAt': now.subtract(const Duration(days: 2)).toUtc().toIso8601String(),
        'isRead': false,
        'orderId': 'o12342',
      },
      <String, dynamic>{
        'id': 'nt2',
        'title': 'Заказ №12343 подтверждён',
        'body': 'Менеджер подтвердил наличие и условия поставки.',
        'type': 'order_confirmed',
        'createdAt': now.subtract(const Duration(hours: 20)).toUtc().toIso8601String(),
        'isRead': false,
        'orderId': 'o12343',
      },
      <String, dynamic>{
        'id': 'nt3',
        'title': 'Снизилась цена на товар из избранного',
        'body': 'Проверьте обновлённые цены в избранном.',
        'type': 'price_changed',
        'createdAt': now.subtract(const Duration(days: 6)).toUtc().toIso8601String(),
        'isRead': true,
      },
      <String, dynamic>{
        'id': 'nt4',
        'title': 'Специальные предложения месяца',
        'body': 'Новые скидки на фильтры и тормозную систему.',
        'type': 'promo',
        'createdAt': now.subtract(const Duration(days: 9)).toUtc().toIso8601String(),
        'isRead': true,
      },
    ];
  }
}
