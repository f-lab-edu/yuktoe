import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';
import 'package:yuktoe/data/services/auth_service/auth_service.dart';
import 'package:yuktoe/domain/models/auth/app_session.dart';
import 'package:yuktoe/domain/models/auth/app_user.dart';
import 'package:yuktoe/domain/models/auth/raw_auth_session.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;

  AuthRepositoryImpl(this._authService);

  @override
  Stream<AppSession?> watchSession() {
    return _authService.watchSession().map(_mapSession);
  }

  @override
  Future<AppSession?> getCurrentSession() async {
    final rawSession = await _authService.getCurrentSession();
    return _mapSession(rawSession);
  }

  @override
  Future<void> signIn(SocialAuthProvider provider) {
    return _authService.signIn(provider);
  }

  @override
  Future<void> signOut() {
    return _authService.signOut();
  }

  AppSession? _mapSession(RawAuthSession? raw) {
    if (raw == null) return null;

    return AppSession(
      accessToken: raw.accessToken,
      user: AppUser(
        id: raw.userId,
        email: raw.email,
        name: raw.name,
      ),
    );
  }
}
