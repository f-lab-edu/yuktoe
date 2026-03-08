import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/domain/models/auth/raw_auth_session.dart';

import 'auth_service.dart';

class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;
  final String redirectTo;

  SupabaseAuthService({
    required SupabaseClient client,
    required this.redirectTo,
  }) : _client = client;

  @override
  Stream<RawAuthSession?> watchSession() {
    return _client.auth.onAuthStateChange.map(
      (state) => _mapSession(state.session),
    );
  }

  @override
  Future<RawAuthSession?> getCurrentSession() async {
    final session = _client.auth.currentSession;
    return _mapSession(session);
  }

  @override
  Future<void> signIn(SocialAuthProvider provider) async {
    switch (provider) {
      case SocialAuthProvider.google:
        await _signInWithGoogle();
        return;
      case SocialAuthProvider.apple:
        await _signInWithApple();
        return;
      case SocialAuthProvider.kakao:
        await _signInWithKakao();
        return;
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> _signInWithGoogle() async {}

  Future<void> _signInWithKakao() async {}

  Future<void> _signInWithApple() async {}

  RawAuthSession? _mapSession(Session? session) {
    if (session == null) return null;

    final user = session.user;
    final metadata = user.userMetadata ?? const {};

    return RawAuthSession(
      userId: user.id,
      accessToken: session.accessToken,
      email: user.email,
      name: (metadata['full_name'] ?? metadata['name']) as String?,
    );
  }
}
