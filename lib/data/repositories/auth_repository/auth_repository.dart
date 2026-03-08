import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/domain/models/auth/app_session.dart';

abstract interface class AuthRepository {
  Stream<AppSession?> watchSession();

  Future<AppSession?> getCurrentSession();

  Future<void> signIn(SocialAuthProvider provider);

  Future<void> signOut();
}
