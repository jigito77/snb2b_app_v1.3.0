import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/app_config.dart';
import '../l10n/l10n.dart';
import '../utils/currency.dart';
import '../errors/app_exception.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';

/// Реальный HTTP-клиент: HTTPS, JWT access token, автоматический refresh при 401,
/// единая обработка ошибок.
class HttpApiClient implements ApiClient {
  HttpApiClient({
    required TokenStorage tokens,
    required void Function() onSessionExpired,
    void Function(bool online)? onStatus,
    String? baseUrl,
  })  : _tokens = tokens,
        _onSessionExpired = onSessionExpired,
        _onStatus = onStatus,
        _dio = Dio(_options(baseUrl ?? AppConfig.apiBaseUrl)),
        _authDio = Dio(_options(baseUrl ?? AppConfig.apiBaseUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final TokenStorage _tokens;
  final void Function() _onSessionExpired;
  final void Function(bool online)? _onStatus;
  final Dio _dio;
  final Dio _authDio; // без интерцепторов — для refresh
  Future<bool>? _refreshing;

  static BaseOptions _options(String baseUrl) => BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        responseType: ResponseType.json,
        headers: const <String, dynamic>{'Accept': 'application/json'},
      );

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skipAuth'] != true) {
      final token = await _tokens.readAccess();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    options.headers['Accept-Language'] = L10n.lang;
    options.headers['X-Currency'] = AppCurrency.current.code;
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    final isUnauthorized = error.response?.statusCode == 401;
    if (isUnauthorized && request.extra['retried'] != true && request.extra['skipAuth'] != true) {
      final refreshed = await _refresh();
      if (refreshed) {
        try {
          request.extra['retried'] = true;
          final response = await _dio.fetch<dynamic>(request);
          return handler.resolve(response);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      } else {
        await _tokens.clear();
        _onSessionExpired();
      }
    }
    handler.next(error);
  }

  Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await _authDio.post<dynamic>(
        '/api/auth/refresh',
        data: <String, dynamic>{'refreshToken': refresh},
      );
      final data = response.data;
      if (data is Map && data['accessToken'] != null) {
        await _tokens.save(
          access: data['accessToken'].toString(),
          refresh: (data['refreshToken'] ?? refresh).toString(),
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    dynamic body,
    bool skipAuth = false,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, extra: <String, dynamic>{'skipAuth': skipAuth}),
      );
      _onStatus?.call(true);
      return response.data;
    } on DioException catch (e) {
      final mapped = _map(e);
      if (mapped.kind == ErrorKind.network) _onStatus?.call(false);
      throw mapped;
    }
  }

  AppException _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException.network();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final data = e.response?.data;
        final serverMessage = data is Map && data['message'] is String ? data['message'] as String : null;
        if (status == 401) return const AppException.unauthorized();
        if (status == 404) return const AppException.notFound();
        if (status == 409 && serverMessage != null && serverMessage.contains('stock')) {
          return const AppException.outOfStock();
        }
        if ((status == 400 || status == 403 || status == 409 || status == 413 || status == 415 || status == 422 || status == 429) && serverMessage != null) {
          return AppException.validation(serverMessage, statusCode: status);
        }
        return AppException.server(statusCode: status);
      default:
        // cancel, badCertificate, unknown и любые новые типы из будущих версий Dio
        if (e.error is AppException) return e.error as AppException;
        return const AppException.unknown();
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
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(
          method: 'POST',
          contentType: contentType,
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
          headers: <String, dynamic>{
            Headers.contentLengthHeader: length,
            'X-File-Name': Uri.encodeComponent(fileName),
            'X-Upload-Id': uploadId,
            'X-Requested-With': 'snp',
          },
        ),
        onSendProgress: onProgress,
      );
      _onStatus?.call(true);
      return response.data;
    } on DioException catch (e) {
      final mapped = _map(e);
      if (mapped.kind == ErrorKind.network) _onStatus?.call(false);
      throw mapped;
    }
  }
}
