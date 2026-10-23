import '../../core/utils/json_utils.dart';

/// Точка доставки, выбранная на карте.
class GeoPoint {
  const GeoPoint({required this.lat, required this.lng, this.address = ''});

  final double lat;
  final double lng;
  final String address;

  GeoPoint copyWith({String? address}) => GeoPoint(lat: lat, lng: lng, address: address ?? this.address);

  factory GeoPoint.fromJson(Json j) =>
      GeoPoint(lat: j.dbl('lat'), lng: j.dbl('lng'), address: j.str('address'));
}

/// Результат POST /api/delivery/calculate. Все числа считает backend (та же формула, что на сайте):
/// стоимость = расстояние (км) / 1000 × вес (кг) × тариф. Приложение только показывает.
class DeliveryQuote {
  const DeliveryQuote({
    required this.distanceKm,
    required this.weightKg,
    required this.ratePer1000KmPerKg,
    required this.rateCurrency,
    required this.price,
    required this.priceCurrency,
    required this.raw,
  });

  final double distanceKm;
  final double weightKg;

  /// Тариф: за 1 кг на 1000 км, в валюте [rateCurrency] (по умолчанию USD).
  final double ratePer1000KmPerKg;
  final String rateCurrency;

  /// Итоговая стоимость доставки в запрошенной валюте.
  final double price;
  final String priceCurrency;

  /// Стоимость до округления в валюте тарифа.
  final double raw;

  factory DeliveryQuote.fromJson(Json j) => DeliveryQuote(
        distanceKm: j.dbl('distanceKm'),
        weightKg: j.dbl('weightKg'),
        ratePer1000KmPerKg: j.dbl('ratePer1000KmPerKg'),
        rateCurrency: j.str('currency'),
        price: j.dbl('outPrice'),
        priceCurrency: j.str('outCurrency'),
        raw: j.dbl('raw'),
      );
}
