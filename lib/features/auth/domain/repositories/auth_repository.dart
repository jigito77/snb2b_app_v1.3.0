import '../entities/user.dart';

abstract class AuthRepository {
  /// Восстанавливает сессию по сохранённым токенам. null — пользователь не авторизован.
  Future<AppUser?> restoreSession();

  Future<AppUser> signIn(AuthCredentials credentials);

  Future<AppUser> register(RegisterData data);

  /// Подготовка к входу по SMS/OTP.
  Future<void> requestOtp(String phone);

  Future<void> forgotPassword(String email);

  Future<void> logout();
}
