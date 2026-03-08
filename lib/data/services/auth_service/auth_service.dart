import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/domain/models/auth/raw_auth_session.dart';

abstract interface class AuthService {
  Stream<RawAuthSession?> watchSession();
  Future<RawAuthSession?> getCurrentSession();
  Future<void> signIn(SocialAuthProvider provider);
  Future<void> signOut();
}
