import 'package:flutter_test/flutter_test.dart';
import 'package:snb2b_app/features/catalog/domain/entities/catalog_entities.dart';
import 'package:snb2b_app/features/product/domain/entities/product.dart';

Product _product({double? personal, List<PriceTier> tiers = const <PriceTier>[], int available = 10, int minQty = 1}) {
  return Product(
    id: '1',
    name: 'Фильтр масляный',
    article: 'A-1',
    oem: 'OEM-1',
    brandId: 'b',
    brandName: 'Brand',
    categoryId: 'c',
    categoryName: 'Категория',
    manufacturer: 'M',
    description: '',
    price: 1000,
    personalPrice: personal,
    tiers: tiers,
    stock: Stock(available: available),
    minQty: minQty,
  );
}

void main() {
  group('Product.unitPrice', () {
    test('розничная цена по умолчанию', () {
      final p = _product();
      expect(p.unitPrice(1), 1000);
      expect(p.priceKind(1), 'retail');
    });

    test('персональная цена приоритетнее розничной', () {
      final p = _product(personal: 900);
      expect(p.unitPrice(1), 900);
      expect(p.priceKind(1), 'personal');
    });

    test('оптовая ступень применяется с порога', () {
      final p = _product(
        personal: 900,
        tiers: const <PriceTier>[PriceTier(minQty: 10, price: 800)],
        available: 50,
      );
      expect(p.unitPrice(9), 900);
      expect(p.unitPrice(10), 800);
      expect(p.priceKind(10), 'wholesale');
    });

    test('минимальное количество не превышает остаток', () {
      final p = _product(available: 3, minQty: 5);
      expect(p.effectiveMinQty, 3);
    });
  });

  group('ProductFilter', () {
    test('activeCount считает только фильтры, без поиска и сортировки', () {
      const f = ProductFilter(query: 'abc', sort: 'name', inStock: true, brandId: 'x');
      expect(f.activeCount, 2);
    });

    test('toQuery содержит заданные поля и сортировку', () {
      const f = ProductFilter(query: ' 4076965 ');
      expect(f.toQuery(), <String, dynamic>{'q': '4076965', 'sort': 'popular'});
    });
  });
}
