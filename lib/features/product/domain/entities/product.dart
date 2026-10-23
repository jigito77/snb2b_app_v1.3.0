import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json_utils.dart';

/// Оптовая ступень цены: от [minQty] штук цена за единицу — [price].
class PriceTier {
  const PriceTier({required this.minQty, required this.price});

  final int minQty;
  final double price;

  factory PriceTier.fromJson(Json j) =>
      PriceTier(minQty: j.integer('minQty', 1), price: j.dbl('price'));

  Json toJson() => <String, dynamic>{'minQty': minQty, 'price': price};
}

class Stock {
  const Stock({required this.available, this.warehouse = ''});

  final int available;
  final String warehouse;

  factory Stock.fromJson(Json j) =>
      Stock(available: j.integer('available'), warehouse: j.str('warehouse'));

  Json toJson() => <String, dynamic>{'available': available, 'warehouse': warehouse};
}

class ProductAttribute {
  const ProductAttribute({required this.name, required this.value});

  final String name;
  final String value;

  factory ProductAttribute.fromJson(Json j) =>
      ProductAttribute(name: j.str('name'), value: j.str('value'));

  Json toJson() => <String, dynamic>{'name': name, 'value': value};
}


/// Предложение ORG / OEM / SNP. Цена приходит с backend уже в выбранной валюте
/// (заголовок X-Currency) и с учётом ступени (розница / MALI OPT / OPT / KRUPNI OPT).
class ProductOffer {
  const ProductOffer({
    required this.type,
    required this.price,
    this.retailPrice,
    this.priceLevel = '',
    this.manufacturer = '',
    this.partNumber = '',
    this.oem = '',
    this.description = '',
    this.warranty = '',
    this.minQty = 1,
    this.weightKg,
    this.images = const <String>[],
  });

  final String type;
  final double price;
  final double? retailPrice;
  final String priceLevel;
  final String manufacturer;
  final String partNumber;
  final String oem;
  final String description;
  final String warranty;
  final int minQty;

  /// Вес 1 шт. в кг (только с backend; пользователь его не вводит).
  final double? weightKg;
  final List<String> images;

  factory ProductOffer.fromJson(Json j) => ProductOffer(
        type: j.str('type'),
        price: j.dbl('price'),
        retailPrice: j.dblOrNull('retailPrice'),
        priceLevel: j.str('priceLevel'),
        manufacturer: j.str('manufacturer'),
        partNumber: j.str('partNumber'),
        oem: j.str('oem'),
        description: j.str('description'),
        warranty: j.str('warranty'),
        minQty: j.integer('minQty', 1),
        weightKg: j.dblOrNull('weightKg'),
        images: j.strings('images'),
      );

  Json toJson() => <String, dynamic>{
        'type': type,
        'price': price,
        'retailPrice': retailPrice,
        'priceLevel': priceLevel,
        'manufacturer': manufacturer,
        'partNumber': partNumber,
        'oem': oem,
        'description': description,
        'warranty': warranty,
        'minQty': minQty,
        'weightKg': weightKg,
        'images': images,
      };
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.article,
    required this.oem,
    required this.brandId,
    required this.brandName,
    required this.categoryId,
    required this.categoryName,
    required this.manufacturer,
    required this.description,
    required this.price,
    required this.stock,
    this.oldPrice,
    this.personalPrice,
    this.tiers = const <PriceTier>[],
    this.deliveryMin = 1,
    this.deliveryMax = 2,
    this.minQty = 1,
    this.images = const <String>[],
    this.attributes = const <ProductAttribute>[],
    this.compatibility = const <String>[],
    this.analogIds = const <String>[],
    this.isNew = false,
    this.isPopular = false,
    this.isSpecial = false,
    this.offers = const <ProductOffer>[],
    this.weightKg,
    this.currency = '',
  });

  final String id;
  final String name;
  final String article;
  final String oem;
  final String brandId;
  final String brandName;
  final String categoryId;
  final String categoryName;
  final String manufacturer;
  final String description;

  /// Розничная (базовая) цена.
  final double price;
  final double? oldPrice;

  /// Персональная цена B2B-клиента — приходит с backend только для авторизованных.
  final double? personalPrice;
  final List<PriceTier> tiers;
  final Stock stock;
  final int deliveryMin;
  final int deliveryMax;
  final int minQty;
  final List<String> images;
  final List<ProductAttribute> attributes;
  final List<String> compatibility;
  final List<String> analogIds;
  final bool isNew;
  final bool isPopular;
  final bool isSpecial;

  /// Предложения ORG / OEM / SNP (пусто для старого формата API).
  final List<ProductOffer> offers;

  /// Вес 1 шт. в кг (с backend).
  final double? weightKg;

  /// Валюта, в которой пришли цены (пусто — старый формат: рубли).
  final String currency;

  bool get inStock => stock.available > 0;

  /// Заказать можно всегда, если есть предложения: нет на складе — «под заказ» (как на сайте).
  bool get canOrder => offers.isNotEmpty || inStock;

  /// Максимум для выбора количества: остатки клиенту не показываются, поэтому при наличии предложений ограничение мягкое.
  int get maxQty => offers.isNotEmpty ? 100000 : stock.available;

  ProductOffer? offerOf(String? type) {
    for (final o in offers) {
      if (o.type == type) return o;
    }
    return offers.isEmpty ? null : offers.first;
  }

  bool get hasPersonalPrice => personalPrice != null && personalPrice! < price;

  /// Минимальное количество, которое реально можно заказать (не больше остатка).
  int get effectiveMinQty {
    if (!canOrder) return minQty;
    return minQty > maxQty ? maxQty : minQty;
  }

  String get deliveryLabel => Fmt.days(deliveryMin, deliveryMax);

  /// Цена за единицу при заказе [qty] штук: персональная/розничная цена,
  /// а при достижении порога — оптовая ступень, если она выгоднее.
  double unitPrice(int qty) {
    var best = hasPersonalPrice ? personalPrice! : price;
    for (final tier in tiers) {
      if (qty >= tier.minQty && tier.price < best) best = tier.price;
    }
    return best;
  }

  /// Какая цена действует для [qty]: 'personal', 'wholesale' или 'retail'.
  String priceKind(int qty) {
    final base = hasPersonalPrice ? personalPrice! : price;
    final unit = unitPrice(qty);
    if (unit < base) return 'wholesale';
    return hasPersonalPrice ? 'personal' : 'retail';
  }

  factory Product.fromJson(Json j) {
    final stockJson = j.obj('stock');
    final deliveryJson = j.obj('delivery');
    final offers = j.list('offers').map(ProductOffer.fromJson).toList();
    final hasOffers = offers.isNotEmpty;
    final fromPrice = hasOffers
        ? (j.dblOrNull('priceFrom') ?? offers.map((o) => o.price).reduce((a, b) => a < b ? a : b))
        : j.dbl('price');
    return Product(
      id: j.str('id'),
      name: j.str('name'),
      article: j.str('article'),
      oem: j.str('oem'),
      brandId: j.str('brandId'),
      brandName: j.str('brandName'),
      categoryId: j.str('categoryId'),
      categoryName: j.str('categoryName'),
      manufacturer: j.str('manufacturer'),
      description: j.str('description'),
      price: fromPrice,
      // С предложениями цены считает backend (ступени, скидки, валюта) — старые поля в базовой валюте не используем.
      oldPrice: hasOffers ? null : j.dblOrNull('oldPrice'),
      personalPrice: hasOffers ? null : j.dblOrNull('personalPrice'),
      tiers: hasOffers ? const <PriceTier>[] : j.list('priceTiers').map(PriceTier.fromJson).toList(),
      offers: offers,
      weightKg: j.dblOrNull('weightKg'),
      currency: j.str('currency'),
      stock: stockJson == null ? const Stock(available: 0) : Stock.fromJson(stockJson),
      deliveryMin: deliveryJson?.integer('minDays', 1) ?? 1,
      deliveryMax: deliveryJson?.integer('maxDays', 2) ?? 2,
      minQty: j.integer('minQty', 1),
      images: j.strings('images'),
      attributes: j.list('attributes').map(ProductAttribute.fromJson).toList(),
      compatibility: j.strings('compatibility'),
      analogIds: j.strings('analogIds'),
      isNew: j.flag('isNew'),
      isPopular: j.flag('isPopular'),
      isSpecial: j.flag('isSpecial'),
    );
  }

  Json toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'article': article,
        'oem': oem,
        'brandId': brandId,
        'brandName': brandName,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'manufacturer': manufacturer,
        'description': description,
        'price': price,
        'oldPrice': oldPrice,
        'personalPrice': personalPrice,
        'priceTiers': tiers.map((t) => t.toJson()).toList(),
        'stock': stock.toJson(),
        'delivery': <String, dynamic>{'minDays': deliveryMin, 'maxDays': deliveryMax},
        'minQty': minQty,
        'images': images,
        'attributes': attributes.map((a) => a.toJson()).toList(),
        'compatibility': compatibility,
        'analogIds': analogIds,
        'isNew': isNew,
        'isPopular': isPopular,
        'isSpecial': isSpecial,
        'offers': offers.map((o) => o.toJson()).toList(),
        'priceFrom': offers.isEmpty ? null : price,
        'weightKg': weightKg,
        'currency': currency,
      };
}
