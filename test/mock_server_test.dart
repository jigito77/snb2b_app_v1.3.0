import 'package:flutter_test/flutter_test.dart';
import 'package:snb2b_app/core/errors/app_exception.dart';
import 'package:snb2b_app/core/network/mock/mock_server.dart';

void main() {
  late MockServer server;

  setUp(() => server = MockServer());

  test('поиск по артикулу 4076965 находит товар', () {
    final res = server.handle(
      'GET',
      '/api/products',
      <String, dynamic>{'q': '4076965'},
      null,
      null,
    ) as Map;
    final items = res['items'] as List;
    expect(items, isNotEmpty);
    expect((items.first as Map)['article'].toString().replaceAll(RegExp(r'[^0-9]'), ''), contains('4076965'));
  });

  test('вход с демо-аккаунтом возвращает токены', () {
    final res = server.handle(
      'POST',
      '/api/auth/login',
      const <String, dynamic>{},
      <String, dynamic>{'email': 'b2b@demo.ru', 'password': 'demo123'},
      null,
    ) as Map;
    expect(res['accessToken'], isNotNull);
    expect(res['refreshToken'], isNotNull);
  });

  test('неверный пароль — ошибка валидации', () {
    expect(
      () => server.handle(
        'POST',
        '/api/auth/login',
        const <String, dynamic>{},
        <String, dynamic>{'email': 'b2b@demo.ru', 'password': 'wrong'},
        null,
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('заказы требуют авторизации', () {
    expect(
      () => server.handle('GET', '/api/orders', const <String, dynamic>{}, null, null),
      throwsA(isA<AppException>()),
    );
  });
}
