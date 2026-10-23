import '../../errors/app_exception.dart';
import '../../storage/token_storage.dart';
import '../api_client.dart';
import 'mock_server.dart';

/// Клиент, обслуживающий запросы встроенным [MockServer]. Повторяет поведение
/// HttpApiClient: статус сети, обновление токена при 401, истечение сессии.
class MockApiClient implements ApiClient {
  MockApiClient({
    required TokenStorage tokens,
    required void Function() onSessionExpired,
    void Function(bool online)? onStatus,
  })  : _tokens = tokens,
        _onSessionExpired = onSessionExpired,
        _onStatus = onStatus;

  final TokenStorage _tokens;
  final void Function() _onSessionExpired;
  final void Function(bool online)? _onStatus;

  /// Переключатель из «Настроек» для проверки офлайн-режима.
  static bool simulateOffline = false;

  /// Сервер живёт, пока жив процесс, поэтому состояние переживает пересоздание клиента.
  static final MockServer _server = MockServer();

  static const Duration _latency = Duration(milliseconds: 260);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    dynamic body,
    bool skipAuth = false,
  }) async {
    await Future<void>.delayed(_latency);
    if (simulateOffline) {
      _onStatus?.call(false);
      throw const AppException.network();
    }
    _onStatus?.call(true);

    final token = skipAuth ? null : await _tokens.readAccess();
    try {
      return _server.handle(method, path, query ?? const <String, dynamic>{}, body, token);
    } on AppException catch (e) {
      if (e.kind == ErrorKind.unauthorized && !skipAuth && token != null) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          final newToken = await _tokens.readAccess();
          return _server.handle(method, path, query ?? const <String, dynamic>{}, body, newToken);
        }
        await _tokens.clear();
        _onSessionExpired();
      }
      rethrow;
    }
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null) return false;
    try {
      final data = _server.handle(
        'POST',
        '/api/auth/refresh',
        const <String, dynamic>{},
        <String, dynamic>{'refreshToken': refresh},
        null,
      ) as Map;
      await _tokens.save(
        access: data['accessToken'].toString(),
        refresh: data['refreshToken'].toString(),
      );
      return true;
    } on AppException {
      return false;
    }
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  @override
  Future<dynamic> post(String path, {dynamic body, bool skipAuth = false}) =>
      _send('POST', path, body: body, skipAuth: skipAuth);

  @override
  Future<dynamic> put(String path, {dynamic body}) => _send('PUT', path, body: body);

  @override
  Future<dynamic> delete(String path) => _send('DELETE', path);

  @override
  Future<dynamic> upload(
    String path, {
    required Stream<List<int>> data,
    required int length,
    required String contentType,
    required String fileName,
    required String uploadId,
    void Function(int sent, int total)? onProgress,
  }) async {
    await Future<void>.delayed(_latency);
    if (simulateOffline) {
      _onStatus?.call(false);
      throw const AppException.network();
    }
    onProgress?.call(length, length);
    return _server.mockUpload(fileName, contentType, length, uploadId);
  }
}
