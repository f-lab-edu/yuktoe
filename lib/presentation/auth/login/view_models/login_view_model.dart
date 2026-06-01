import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/constants/enum/social_auth_provider.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';
import 'package:yuktoe/domain/models/auth/app_session.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  LoginViewModel(this._authRepository);

  ActionState _state = ActionState.idle;
  ActionState get state => _state;
  bool get isLoading => _state == ActionState.loading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AppSession? _session;
  AppSession? get session => _session;

  bool get isLoggedIn => _session != null;

  Future<void> signIn(SocialAuthProvider provider) async {
    if (_state == ActionState.loading) return;

    _state = ActionState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authRepository.signIn(provider);

      switch (result) {
        case Ok<void>():
          _session = _authRepository.session;
          _state = ActionState.success;
        case Error<void>():
          _session = null;
          _state = ActionState.error;
          _errorMessage = AppStrings.genericError;
      }
    } catch (e) {
      _session = null;
      _state = ActionState.error;
      _errorMessage = AppStrings.genericError;
    } finally {
      notifyListeners();
    }
  }
}
