import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';
import 'package:yuktoe/data/services/auth_service/auth_service.dart';
import 'package:yuktoe/domain/models/auth/app_session.dart';
import 'package:yuktoe/domain/models/auth/app_user.dart';
import 'package:yuktoe/domain/models/auth/raw_auth_session.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;

  AppSession? _cachedSession;

  AuthRepositoryImpl(this._authService);

  @override
  bool get isLoggedIn => _cachedSession != null;

  @override
  AppSession? get session => _cachedSession;

  @override
  Future<Result<AppSession?>> getSession() async {
    final result = await _authService.getCurrentSession();
    switch (result) {
      case Ok<RawAuthSession?>():
        _cachedSession = _mapSession(result.value);
        return Result.ok(_cachedSession);
      case Error<RawAuthSession?>():
        _cachedSession = null;
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<void>> signIn(SocialAuthProvider provider) async {
    final result = await _authService.signIn(provider);
    switch (result) {
      case Ok<void>():
        await getSession();
        return Result.ok(null);
      case Error<void>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<void>> signOut() async {
    final result = await _authService.signOut();
    switch (result) {
      case Ok<void>():
        _cachedSession = null;
        return Result.ok(null);
      case Error<void>():
        return Result.error(result.error);
    }
  }

  AppSession? _mapSession(RawAuthSession? raw) {
    if (raw == null) return null;

    return AppSession(
      accessToken: raw.accessToken,
      user: AppUser(id: raw.userId, email: raw.email, name: raw.name),
    );
  }
}
