import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище JWT-токенов. В реальном приложении токены лежат только в
/// Android Keystore / iOS Keychain. Пароль пользователя нигде не сохраняется.
abstract class TokenStorage {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'auth.access_token';
  static const String _refreshKey = 'auth.refresh_token';

  @override
  Future<String?> readAccess() => _read(_accessKey);

  @override
  Future<String?> readRefresh() => _read(_refreshKey);

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // Повреждённое хранилище (например, после восстановления из бэкапа) — считаем, что токена нет.
      return null;
    }
  }

  @override
  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {
      // игнорируем: токена уже нет
    }
  }
}
