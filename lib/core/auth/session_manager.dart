import 'package:flutter/foundation.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';

/// 전역 Provider 로 등록되어 현재 로그인 사용자 ID 를 노출.
/// View 가 권한 판정(예: 메모 작성자만 ⋮ 노출)에 사용.
class SessionManager extends ChangeNotifier {
  final AuthRepository _authRepository;

  SessionManager(this._authRepository);

  String? get currentUserId => _authRepository.session?.user.id;
}
