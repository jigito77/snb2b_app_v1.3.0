import '../../../../core/utils/json_utils.dart';
import '../../../product/domain/entities/product.dart';

/// Строка корзины, посчитанная сервером (POST /api/prices или GET /api/cart).
/// Все суммы — в выбранной валюте. Приложение их не вычисляет: только показывает.
class CartLine {
  const CartLine({
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
    this.retailPrice,
    this.priceLevel = '',
    this.unitWeightKg,
    this.weightKg,
    this.currency = '',
  });

  /// Количество, для которого сервер посчитал строку (если оно изменилось — строка устарела).
  final int qty;
  final double unitPrice;
  final double subtotal;
  final double? retailPrice;

  /// Ступень цены: розница / MALI OPT / OPT / KRUPNI OPT (название приходит с backend).
  final String priceLevel;
  final double? unitWeightKg;
  final double? weightKg;
  final String currency;

  factory CartLine.fromJson(Json j) => CartLine(
        qty: j.integer('qty', 1),
        unitPrice: j.dbl('unitPrice'),
        subtotal: j.dbl('subtotal'),
        retailPrice: j.dblOrNull('retailPrice'),
        priceLevel: j.str('priceLevel'),
        unitWeightKg: j.dblOrNull('unitWeightKg'),
        weightKg: j.dblOrNull('weightKg'),
        currency: j.str('currency'),
      );

  Json toJson() => <String, dynamic>{
        'qty': qty,
        'unitPrice': unitPrice,
        'subtotal': subtotal,
        'retailPrice': retailPrice,
        'priceLevel': priceLevel,
        'unitWeightKg': unitWeightKg,
        'weightKg': weightKg,
        'currency': currency,
      };
}

class CartItem {
  const CartItem({required this.product, required this.qty, this.offer = '', this.line});

  final Product product;
  final int qty;

  /// Тип предложения: ORG / OEM / SNP (пусто — старый формат без предложений).
  final String offer;

  /// Расчёт сервера для этого количества (null, пока не получен).
  final CartLine? line;

  String get key => '${product.id}|$offer';

  CartLine? get _fresh => (line != null && line!.qty == qty) ? line : null;

  ProductOffer? get offerData => product.offerOf(offer);

  /// Цена за 1 шт.: расчёт сервера, а пока его нет — цена предложения (только для отображения).
  double get unitPrice => _fresh?.unitPrice ?? offerData?.price ?? product.unitPrice(qty);

  double get total => _fresh?.subtotal ?? unitPrice * qty;

  double? get unitWeightKg => _fresh?.unitWeightKg ?? offerData?.weightKg ?? product.weightKg;

  double? get weightKg {
    final w = _fresh?.weightKg;
    if (w != null) return w;
    final u = unitWeightKg;
    return u == null ? null : u * qty;
  }

  String get priceLevel => _fresh?.priceLevel ?? '';

  int get minQty => offerData?.minQty ?? product.effectiveMinQty;

  CartItem copyWith({Product? product, int? qty, String? offer, CartLine? line, bool clearLine = false}) =>
      CartItem(
        product: product ?? this.product,
        qty: qty ?? this.qty,
        offer: offer ?? this.offer,
        line: clearLine ? null : (line ?? this.line),
      );

  factory CartItem.fromJson(Json j) {
    final lineJson = j.obj('line');
    return CartItem(
      product: Product.fromJson(asJson(j['product'])),
      qty: j.integer('qty', 1),
      offer: j.str('offer'),
      line: lineJson == null ? null : CartLine.fromJson(lineJson),
    );
  }

  Json toJson() => <String, dynamic>{
        'product': product.toJson(),
        'qty': qty,
        'offer': offer,
        'line': line?.toJson(),
      };
}

extension CartItems on List<CartItem> {
  double get total => fold<double>(0, (sum, e) => sum + e.total);

  int get units => fold<int>(0, (sum, e) => sum + e.qty);

  /// Общий вес корзины, кг (null — ни у одной позиции вес не задан).
  double? get weightKg {
    double sum = 0;
    var any = false;
    for (final e in this) {
      final w = e.weightKg;
      if (w != null) {
        sum += w;
        any = true;
      }
    }
    return any ? sum : null;
  }

  /// Есть позиции без веса: сервер не сможет посчитать доставку.
  bool get hasMissingWeight => any((e) => e.weightKg == null);

  bool get hasUnavailable => any((e) => !e.product.canOrder);
}
