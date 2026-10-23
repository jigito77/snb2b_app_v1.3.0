import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../core/network/network_status.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus { unknown, guest, authenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user, this.sessionExpired = false});

  final AuthStatus status;
  final AppUser? user;

  /// Выставляется, когда refresh token не сработал и сессия закончилась.
  final bool sessionExpired;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isB2b => user?.isB2b ?? false;
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    ref.listen<int>(sessionExpiredProvider, (previous, next) => _expire());
    return const AuthState();
  }

  Future<void> restore() async {
    try {
      final user = await _repo.restoreSession();
      state = user == null
          ? const AuthState(status: AuthStatus.guest)
          : AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = const AuthState(status: AuthStatus.guest);
    }
  }

  /// Бросает AppException с понятным сообщением — UI показывает его пользователю.
  Future<void> signIn(AuthCredentials credentials) async {
    final user = await _repo.signIn(credentials);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> register(RegisterData data) async {
    final user = await _repo.register(data);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> forgotPassword(String email) => _repo.forgotPassword(email);

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.guest);
  }

  void updateUser(AppUser user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  void acknowledgeExpired() {
    if (state.sessionExpired) state = const AuthState(status: AuthStatus.guest);
  }

  void _expire() {
    if (state.isAuthenticated) {
      state = const AuthState(status: AuthStatus.guest, sessionExpired: true);
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
