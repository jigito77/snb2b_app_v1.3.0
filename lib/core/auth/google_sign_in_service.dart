import 'package:google_sign_in/google_sign_in.dart';

import '../errors/app_exception.dart';

/// Вход через Google: приложение получает только idToken и отправляет его на backend
/// (POST /api/auth/oauth/google). Токен проверяет сервер — ключей и секретов в приложении нет.
///
/// [serverClientId] — Web OAuth client ID из Google Cloud (тот же, что GOOGLE_CLIENT_ID на сервере);
/// передаётся при сборке: --dart-define=GOOGLE_SERVER_CLIENT_ID=...
class GoogleSignInService {
  GoogleSignInService._();

  static const String serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static bool get isConfigured => serverClientId.isNotEmpty;

  /// Возвращает idToken и имя, либо null, если пользователь закрыл окно выбора аккаунта.
  static Future<({String idToken, String name})?> signIn() async {
    if (!isConfigured) {
      throw const AppException.validation('Вход через Google не настроен в этой сборке.');
    }
    final google = GoogleSignIn(
      scopes: const <String>['email', 'profile'],
      serverClientId: serverClientId,
    );
    try {
      await google.signOut(); // всегда показываем выбор аккаунта
    } catch (_) {}
    final account = await google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    final token = auth.idToken;
    if (token == null || token.isEmpty) {
      throw const AppException.validation('Google не вернул токен. Проверьте настройку OAuth (SHA-1, Web client ID).');
    }
    return (idToken: token, name: account.displayName ?? '');
  }
}
