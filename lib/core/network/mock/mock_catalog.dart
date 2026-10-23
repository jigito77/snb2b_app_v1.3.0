/// Демонстрационные данные, структурно повторяющие каталог SNB2B:
/// бренды, категории и ~140 товаров. Генерируются детерминированно.
///
/// ВАЖНО: артикулы, цены и описания — тестовые, не реальные позиции каталога.
class _BrandDef {
  const _BrandDef(this.id, this.name, this.shortName, this.models, this.base, this.factor);

  final String id;
  final String name;
  final String shortName;
  final List<String> models;
  final int base;
  final double factor;
}

class _Tpl {
  const _Tpl(this.cat, this.name, this.price, this.specName, this.specValue);

  final String cat;
  final String name;
  final int price;
  final String specName;
  final String specValue;
}

const List<_BrandDef> _brandDefs = <_BrandDef>[
  _BrandDef('slp', 'SLP Swedish Lorry Parts AB', 'SLP',
      <String>['Volvo FH', 'Volvo FM', 'Volvo FMX'], 2100000, 0.78),
  _BrandDef('volvo-trucks', 'Volvo Trucks', 'Volvo',
      <String>['Volvo FH12', 'Volvo FH16', 'Volvo FM', 'Volvo FMX'], 4076965, 1.0),
  _BrandDef('volvo-penta', 'Volvo Penta', 'Volvo Penta',
      <String>['D13', 'D16', 'TAMD 63'], 3830000, 1.12),
  _BrandDef('volvo-ce', 'Volvo Construction Equipment', 'Volvo CE',
      <String>['EC210', 'EC240', 'L90'], 1450000, 1.06),
  _BrandDef('sany', 'SANY', 'SANY', <String>['SY215', 'SY365H'], 6010000, 0.82),
  _BrandDef('cat', 'Caterpillar', 'Caterpillar',
      <String>['320D', '330D', 'C13'], 2370000, 1.18),
  _BrandDef('kamaz', 'КАМАЗ', 'КАМАЗ',
      <String>['КАМАЗ-5320', 'КАМАЗ-65115', 'КАМАЗ-43118'], 1110000, 0.55),
  _BrandDef('sachs', 'SACHS', 'SACHS',
      <String>['Volvo FH', 'Scania R', 'КАМАЗ-5490'], 3000000, 1.0),
  _BrandDef('scania', 'Scania', 'Scania',
      <String>['R440', 'P-series', 'G-series'], 1780000, 1.08),
];

const List<_Tpl> _tpls = <_Tpl>[
  _Tpl('filters-oil', 'Фильтр масляный', 2450, 'Тип', 'Накручиваемый'),
  _Tpl('filters-fuel', 'Фильтр топливный', 3120, 'Тип', 'Тонкой очистки'),
  _Tpl('filters-air', 'Фильтр воздушный', 4380, 'Тип', 'Сменный элемент'),
  _Tpl('engine-turbo', 'Турбокомпрессор', 84500, 'Давление наддува', '1,8 бар'),
  _Tpl('engine-gasket', 'Прокладка ГБЦ', 9800, 'Материал', 'Металл-эластомер'),
  _Tpl('engine-belts', 'Ремень поликлиновой', 2790, 'Количество ручьёв', '8'),
  _Tpl('fuel-injector', 'Форсунка топливная', 38900, 'Тип', 'Электронная'),
  _Tpl('fuel-pump', 'Топливный насос', 27400, 'Тип', 'Высокого давления'),
  _Tpl('brakes-pads', 'Колодки тормозные, комплект', 7600, 'Комплектность', 'Одна ось'),
  _Tpl('brakes-discs', 'Тормозной диск', 11200, 'Диаметр', '430 мм'),
  _Tpl('trans-clutch', 'Сцепление в сборе', 46800, 'Диаметр диска', '430 мм'),
  _Tpl('susp-shock', 'Амортизатор', 9400, 'Тип', 'Газомасляный'),
  _Tpl('el-starter', 'Стартер', 31500, 'Напряжение', '24 В'),
  _Tpl('el-alt', 'Генератор', 36200, 'Мощность', '28 В / 100 А'),
  _Tpl('el-sensor', 'Датчик давления масла', 3650, 'Диапазон', '0–10 бар'),
  _Tpl('cool-pump', 'Водяной насос', 12800, 'Тип привода', 'Ременной'),
  _Tpl('cool-rad', 'Радиатор охлаждения', 58900, 'Материал', 'Алюминий'),
];

/// id, название, parentId ('' для корневых)
const List<List<String>> _cats = <List<String>>[
  <String>['engine', 'Двигатель', ''],
  <String>['engine-turbo', 'Турбокомпрессоры', 'engine'],
  <String>['engine-gasket', 'Прокладки и ремкомплекты', 'engine'],
  <String>['engine-belts', 'Ремни и ролики', 'engine'],
  <String>['filters', 'Фильтры', ''],
  <String>['filters-oil', 'Масляные фильтры', 'filters'],
  <String>['filters-fuel', 'Топливные фильтры', 'filters'],
  <String>['filters-air', 'Воздушные фильтры', 'filters'],
  <String>['fuel', 'Топливная система', ''],
  <String>['fuel-injector', 'Форсунки', 'fuel'],
  <String>['fuel-pump', 'Топливные насосы', 'fuel'],
  <String>['brakes', 'Тормозная система', ''],
  <String>['brakes-pads', 'Тормозные колодки', 'brakes'],
  <String>['brakes-discs', 'Диски и барабаны', 'brakes'],
  <String>['trans', 'Трансмиссия и сцепление', ''],
  <String>['trans-clutch', 'Сцепление', 'trans'],
  <String>['susp', 'Подвеска и рулевое', ''],
  <String>['susp-shock', 'Амортизаторы', 'susp'],
  <String>['el', 'Электрооборудование', ''],
  <String>['el-starter', 'Стартеры', 'el'],
  <String>['el-alt', 'Генераторы', 'el'],
  <String>['el-sensor', 'Датчики', 'el'],
  <String>['cool', 'Охлаждение', ''],
  <String>['cool-pump', 'Водяные насосы', 'cool'],
  <String>['cool-rad', 'Радиаторы', 'cool'],
];

const Map<String, List<String>> _manufacturers = <String, List<String>>{
  'filters': <String>['Mann-Filter', 'Mahle', 'Donaldson', 'Fleetguard'],
  'engine': <String>['Garrett', 'Elring', 'Corteco', 'Contitech'],
  'fuel': <String>['Bosch', 'Delphi', 'Denso', 'Stanadyne'],
  'brakes': <String>['Knorr-Bremse', 'Wabco', 'Textar', 'Brembo'],
  'trans': <String>['Luk', 'Valeo', 'ZF', 'Aisin'],
  'susp': <String>['Monroe', 'Febi', 'Lemförder', 'Boge'],
  'el': <String>['Bosch', 'Hella', 'Valeo', 'Prestolite'],
  'cool': <String>['Behr', 'Nissens', 'Febi', 'Mahle'],
};

const List<String> _countries = <String>[
  'Швеция',
  'Германия',
  'Япония',
  'Россия',
  'Китай',
  'США',
];

class MockCatalog {
  MockCatalog._();

  static List<Map<String, dynamic>> products = _buildProducts();
  static List<Map<String, dynamic>> categories = _buildCategories();
  static List<Map<String, dynamic>> brands = _buildBrands();

  static Map<String, Map<String, dynamic>> byId = _index(products);

  /// true, если каталог загружен из assets/data/catalog.json (реальный каталог SNP).
  static bool loadedFromAsset = false;

  static Map<String, Map<String, dynamic>> _index(List<Map<String, dynamic>> list) =>
      <String, Map<String, dynamic>>{for (final p in list) p['id'] as String: p};

  /// Подменяет демо-данные каталогом из JSON: {products, categories, brands}.
  static void replace(Map<String, dynamic> data) {
    List<Map<String, dynamic>> list(String k) =>
        (data[k] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final p = list('products');
    if (p.isEmpty) return;
    products = p;
    categories = list('categories');
    brands = list('brands');
    byId = _index(p);
    loadedFromAsset = true;
  }

  /// Идентификаторы дочерних категорий.
  static List<String> childrenOf(String categoryId) => categories
      .where((c) => c['parentId'] == categoryId)
      .map((c) => c['id'] as String)
      .toList();

  static List<String> get manufacturers {
    final set = <String>{for (final p in products) p['manufacturer'] as String};
    final list = set.toList()..sort();
    return list;
  }

  static List<String> get compatibilities {
    if (loadedFromAsset) return const <String>[];
    final set = <String>{for (final b in _brandDefs) ...b.models};
    final list = set.toList()..sort();
    return list;
  }

  static const List<String> popularQueries = <String>[
    '4076965',
    'Фильтр масляный',
    'Сцепление SACHS',
    'Турбокомпрессор',
    'Volvo FH',
    'Scania R440',
    'Тормозные колодки',
    'Форсунка',
  ];

  static List<Map<String, dynamic>> _buildCategories() {
    return _cats.map((c) {
      final ids = <String>{c[0], ..._cats.where((x) => x[2] == c[0]).map((x) => x[0])};
      final count = products.where((p) => ids.contains(p['categoryId'])).length;
      return <String, dynamic>{
        'id': c[0],
        'name': c[1],
        'parentId': c[2].isEmpty ? null : c[2],
        'productCount': count,
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _buildBrands() {
    return _brandDefs.map((b) {
      final count = products.where((p) => p['brandId'] == b.id).length;
      return <String, dynamic>{
        'id': b.id,
        'name': b.name,
        'shortName': b.shortName,
        'productCount': count,
        'logoUrl': null,
      };
    }).toList();
  }

  static String _article(String brandId, int n) {
    switch (brandId) {
      case 'slp':
        return 'SLP-$n';
      case 'cat':
        return '${n ~/ 10000}-${(n % 10000).toString().padLeft(4, '0')}';
      case 'kamaz':
        return '740.${1000000 + n % 9000000}';
      case 'sachs':
        return '3000 ${100000 + n % 900000}';
      case 'sany':
        return '60${n % 10000000}';
      default:
        return '$n';
    }
  }

  static double _round10(double v) => (v / 10).round() * 10.0;

  static List<Map<String, dynamic>> _buildProducts() {
    final catNames = <String, String>{for (final c in _cats) c[0]: c[1]};
    final result = <Map<String, dynamic>>[];
    var idx = 0;

    for (final b in _brandDefs) {
      final isSachs = b.id == 'sachs';
      final tplIndexes = isSachs ? <int>[10, 11] : List<int>.generate(_tpls.length, (i) => i);
      var local = 0;
      for (final ti in tplIndexes) {
        final tpl = _tpls[ti];
        final modelCount = isSachs ? b.models.length : 1;
        for (var m = 0; m < modelCount; m++) {
          final modelIdx = isSachs ? m : local % b.models.length;
          final model = b.models[modelIdx];
          final n = b.base + ti * 7919 + modelIdx * 131;
          final top = tpl.cat.split('-').first;

          final raw = tpl.price * b.factor * (0.92 + ((idx * 7 + ti * 3) % 17) / 100);
          final price = _round10(raw);
          final isSpecial = idx % 9 == 0;
          final available = idx % 11 == 0 ? 0 : 3 + (idx * 37) % 117;
          final inStock = available > 0;
          final minQty = tpl.cat.startsWith('filters') && available >= 2 ? 2 : 1;
          final mfrList = _manufacturers[top] ?? const <String>['Febi'];
          final manufacturer = isSachs
              ? 'SACHS'
              : (idx % 3 == 0 ? b.shortName : mfrList[idx % mfrList.length]);
          final weight = (0.4 + (idx % 40) / 10).toStringAsFixed(1).replaceAll('.', ',');
          final yearFrom = 2005 + idx % 8;

          result.add(<String, dynamic>{
            'id': 'p${idx + 1}',
            'name': '${tpl.name} $model',
            'article': _article(b.id, n),
            'oem': '$n',
            'brandId': b.id,
            'brandName': b.name,
            'categoryId': tpl.cat,
            'categoryName': catNames[tpl.cat] ?? '',
            'manufacturer': manufacturer,
            'description':
                '${tpl.name} для техники $model. Подбор по артикулу и OEM-номеру, '
                    'проверка комплектности перед отгрузкой. Рассчитан на эксплуатацию '
                    'в тяжёлых условиях. Демонстрационное описание.',
            'price': price,
            'oldPrice': isSpecial ? _round10(price * 1.14) : null,
            'priceTiers': <Map<String, dynamic>>[
              <String, dynamic>{'minQty': 5, 'price': _round10(price * 0.95)},
              <String, dynamic>{'minQty': 20, 'price': _round10(price * 0.9)},
            ],
            'stock': <String, dynamic>{
              'available': available,
              'warehouse': idx % 2 == 0 ? 'Москва' : 'Санкт-Петербург',
            },
            'delivery': <String, dynamic>{
              'minDays': inStock ? 1 : 10,
              'maxDays': inStock ? 2 : 14,
            },
            'minQty': minQty,
            'images': <String>[],
            'attributes': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Производитель', 'value': manufacturer},
              <String, dynamic>{'name': tpl.specName, 'value': tpl.specValue},
              <String, dynamic>{'name': 'Страна производства', 'value': _countries[idx % _countries.length]},
              <String, dynamic>{'name': 'Вес', 'value': '$weight кг'},
              <String, dynamic>{'name': 'Гарантия', 'value': '12 месяцев'},
            ],
            'compatibility': <String>[
              model,
              ...b.models.where((x) => x != model).take(2),
            ].map((x) => '$x, с $yearFrom г.').toList(),
            'analogIds': <String>[],
            'isNew': idx % 7 == 0,
            'isPopular': idx % 5 == 0,
            'isSpecial': isSpecial,
          });
          idx++;
          local++;
        }
      }
    }

    // Аналоги: товары той же категории от других брендов.
    for (final p in result) {
      final analogs = result
          .where((o) => o['categoryId'] == p['categoryId'] && o['brandId'] != p['brandId'])
          .take(3)
          .map((o) => o['id'] as String)
          .toList();
      p['analogIds'] = analogs;
    }
    return result;
  }
}
