import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/auth/app_session.dart';

abstract interface class AuthService {
  Future<Result<AppSession?>> getCurrentSession();
  Future<Result<void>> signIn(SocialAuthProvider provider);
  Future<Result<void>> signOut();
}
