import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_preview.dart';

class InviteCodeViewModel extends ChangeNotifier {
  final BabyRegistrationRepository _repository;

  InviteCodeViewModel({required BabyRegistrationRepository repository})
      : _repository = repository;

  String _code = '';
  bool _agreedToTerms = false;
  ActionState _state = ActionState.idle;
  String? _error;
  BabyPreview? _verifiedBaby;
  String? _babyId;
  bool _isConfirmModalShown = false;

  String get code => _code;
  bool get agreedToTerms => _agreedToTerms;
  ActionState get state => _state;
  bool get isLoading => _state == ActionState.loading;
  String? get error => _error;
  BabyPreview? get verifiedBaby => _verifiedBaby;
  String? get babyId => _babyId;
  bool get shouldShowConfirmModal =>
      _state == ActionState.success &&
      _verifiedBaby != null &&
      _babyId == null &&
      !_isConfirmModalShown;

  bool get isValid => _code.trim().isNotEmpty && _agreedToTerms && !isLoading;

  void setCode(String value) {
    _code = value;
    if (_state == ActionState.error) _state = ActionState.idle;
    _error = null;
    notifyListeners();
  }

  void toggleAgreedToTerms() {
    _agreedToTerms = !_agreedToTerms;
    notifyListeners();
  }

  Future<void> verifyInviteCode() async {
    _state = ActionState.loading;
    _error = null;
    _verifiedBaby = null;
    _isConfirmModalShown = false;
    notifyListeners();

    try {
      final baby = await _repository.verifyInviteCode(_code);
      _verifiedBaby = baby;
      _state = ActionState.success;
    } catch (_) {
      _state = ActionState.error;
      _error = '초대 코드 확인 중 오류가 발생했습니다.';
    } finally {
      notifyListeners();
    }
  }

  void onConfirmModalShown() {
    _isConfirmModalShown = true;
  }

  String? get babyName => _verifiedBaby?.maskedName;

  String? get babyGenderText {
    final gender = _verifiedBaby?.gender;
    if (gender == null) return null;
    return gender == Gender.male ? AppStrings.maleLabel : AppStrings.femaleLabel;
  }

  String? get babyBirthYear {
    final year = _verifiedBaby?.birthYear;
    if (year == null) return null;
    return '$year년생';
  }

  Future<void> joinBaby() async {
    if (_verifiedBaby == null) return;

    _state = ActionState.loading;
    _error = null;
    _babyId = null;
    notifyListeners();

    try {
      await _repository.joinBaby(babyId: _verifiedBaby!.babyId);
      _babyId = _verifiedBaby!.babyId;
      _state = ActionState.success;
    } catch (_) {
      _state = ActionState.error;
      _error = AppStrings.genericError;
    } finally {
      notifyListeners();
    }
  }

  void resetState() {
    _state = ActionState.idle;
    _babyId = null;
    _error = null;
  }

  void clearVerifiedBaby() {
    _verifiedBaby = null;
    _error = null;
    notifyListeners();
  }
}
