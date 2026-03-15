import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/auth/auth_session_data.dart';

import 'auth_service.dart';

class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;
  final String redirectTo;

  SupabaseAuthService({
    required SupabaseClient client,
    required this.redirectTo,
  }) : _client = client;

  @override
  Future<Result<AuthSessionData?>> getCurrentSession() async {
    try {
      final session = _client.auth.currentSession;
      return Result.ok(_mapSession(session));
    } on Exception catch (e) {
      return Result.error(
        AppException('Failed to get current session', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> signIn(SocialAuthProvider provider) async {
    try {
      switch (provider) {
        case SocialAuthProvider.google:
          await _signInWithGoogle();
        case SocialAuthProvider.apple:
          await _signInWithApple();
        case SocialAuthProvider.kakao:
          await _signInWithKakao();
      }
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(AppException('Failed to sign in', cause: e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(AppException('Failed to sign out', cause: e));
    }
  }

  Future<void> _signInWithGoogle() async {}

  Future<void> _signInWithKakao() async {}

  Future<void> _signInWithApple() async {}

  AuthSessionData? _mapSession(Session? session) {
    if (session == null) return null;

    final user = session.user;
    final metadata = user.userMetadata ?? const {};

    return AuthSessionData(
      userId: user.id,
      accessToken: session.accessToken,
      email: user.email,
      name: (metadata['full_name'] ?? metadata['name']) as String?,
    );
  }
}
