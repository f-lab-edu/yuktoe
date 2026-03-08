import 'app_user.dart';

class AppSession {
  final AppUser user;
  final String accessToken;

  const AppSession({
    required this.user,
    required this.accessToken,
  });
}