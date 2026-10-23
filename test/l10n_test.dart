import 'package:flutter_test/flutter_test.dart';
import 'package:snb2b_app/core/l10n/l10n.dart';
import 'package:snb2b_app/core/l10n/strings_en.dart';
import 'package:snb2b_app/core/l10n/strings_hy.dart';
import 'package:snb2b_app/core/l10n/strings_ka.dart';
import 'package:snb2b_app/core/utils/formatters.dart';

void main() {
  tearDown(() => L10n.lang = 'ru');

  test('таблицы переводов содержат одинаковые ключи', () {
    expect(stringsHy.keys.toSet(), stringsEn.keys.toSet());
    expect(stringsKa.keys.toSet(), stringsEn.keys.toSet());
  });

  test('простые строки переводятся на все языки', () {
    expect(L10n.tr('Корзина', 'en'), 'Cart');
    expect(L10n.tr('Корзина', 'hy'), 'Զամբյուղ');
    expect(L10n.tr('Корзина', 'ka'), 'კალათა');
    expect(L10n.tr('Корзина', 'ru'), 'Корзина');
  });

  test('неизвестные строки и артикулы не меняются', () {
    expect(L10n.tr('4076965', 'en'), '4076965');
    expect(L10n.tr('Что-то совсем новое', 'en'), 'Что-то совсем новое');
  });

  test('динамические строки переводятся по шаблонам', () {
    expect(L10n.tr('В наличии: 5 шт.', 'en'), 'In stock: 5 pcs');
    expect(L10n.tr('Заказ №123 успешно создан', 'en'), 'Order №123 created successfully');
    expect(L10n.tr('Фильтр масляный КАМАЗ-5320', 'en'), 'Oil filter KAMAZ-5320');
  });

  test('Fmt учитывает язык', () {
    L10n.lang = 'en';
    expect(Fmt.products(1), '1 item');
    expect(Fmt.products(5), '5 items');
    expect(Fmt.pieces(3), '3 pcs');
    L10n.lang = 'ru';
    expect(Fmt.products(2), '2 товара');
    expect(Fmt.pieces(3), '3 шт.');
  });
}
