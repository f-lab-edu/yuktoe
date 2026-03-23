import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/auth/app_session.dart';

abstract interface class AuthRepository {
  bool get isLoggedIn;
  AppSession? get session;
  Future<Result<AppSession?>> getSession();
  Future<Result<void>> signIn(SocialAuthProvider provider);
  Future<Result<void>> signOut();
}
