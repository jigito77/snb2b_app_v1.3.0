import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._tokens, this._cache);

  final ApiClient _api;
  final TokenStorage _tokens;
  final LocalCache _cache;

  static const String _userKey = 'user';

  @override
  Future<AppUser?> restoreSession() async {
    final access = await _tokens.readAccess();
    final refresh = await _tokens.readRefresh();
    if ((access == null || access.isEmpty) && (refresh == null || refresh.isEmpty)) {
      return null;
    }
    try {
      final json = await _api.get('/api/profile');
      final user = AppUser.fromJson(asJson(json));
      await _cache.putJson(_userKey, user.toJson());
      return user;
    } on AppException catch (e) {
      if (e.kind == ErrorKind.unauthorized) {
        await _tokens.clear();
        await _cache.remove(_userKey);
        return null;
      }
      // Нет сети / сервер недоступен: работаем с сохранённым профилем.
      final cached = _cache.getJson(_userKey);
      if (cached != null) return AppUser.fromJson(asJson(cached));
      return null;
    }
  }

  @override
  Future<AppUser> signIn(AuthCredentials credentials) async {
    final dynamic json;
    if (credentials is EmailPasswordCredentials) {
      json = await _api.post(
        '/api/auth/login',
        skipAuth: true,
        body: <String, dynamic>{'email': credentials.email, 'password': credentials.password},
      );
    } else if (credentials is PhoneOtpCredentials) {
      json = await _api.post(
        '/api/auth/otp/verify',
        skipAuth: true,
        body: <String, dynamic>{'phone': credentials.phone, 'code': credentials.code},
      );
    } else if (credentials is OAuthCredentials) {
      json = await _api.post(
        '/api/auth/oauth/${credentials.provider}',
        skipAuth: true,
        body: <String, dynamic>{'idToken': credentials.token, 'name': credentials.name},
      );
    } else {
      throw const AppException.unknown();
    }
    return _applySession(asJson(json));
  }

  @override
  Future<AppUser> register(RegisterData data) async {
    final json = await _api.post('/api/auth/register', skipAuth: true, body: data.toJson());
    return _applySession(asJson(json));
  }

  @override
  Future<void> requestOtp(String phone) async {
    await _api.post('/api/auth/otp/request', skipAuth: true, body: <String, dynamic>{'phone': phone});
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _api.post(
      '/api/auth/forgot-password',
      skipAuth: true,
      body: <String, dynamic>{'email': email},
    );
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('/api/auth/logout');
    } on AppException {
      // Выходим локально даже без сети.
    }
    await _tokens.clear();
    await _cache.remove(_userKey);
  }

  Future<AppUser> _applySession(Json json) async {
    await _tokens.save(
      access: json.str('accessToken'),
      refresh: json.str('refreshToken'),
    );
    final user = AppUser.fromJson(asJson(json['user']));
    await _cache.putJson(_userKey, user.toJson());
    return user;
  }
}
