import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/auth/auth_session_data.dart';

abstract interface class AuthService {
  Future<Result<AuthSessionData?>> getCurrentSession();
  Future<Result<void>> signIn(SocialAuthProvider provider);
  Future<Result<void>> signOut();
}
