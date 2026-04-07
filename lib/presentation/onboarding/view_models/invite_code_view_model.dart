import 'package:flutter/foundation.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_summary.dart';

class InviteCodeViewModel extends ChangeNotifier {
  final BabyRegistrationRepository _repository;

  InviteCodeViewModel({required BabyRegistrationRepository repository})
      : _repository = repository;

  String _code = '';
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _error;
  BabySummary? _verifiedBaby;

  String get code => _code;
  bool get agreedToTerms => _agreedToTerms;
  bool get isLoading => _isLoading;
  String? get error => _error;
  BabySummary? get verifiedBaby => _verifiedBaby;

  bool get isValid => _code.trim().isNotEmpty && _agreedToTerms && !_isLoading;

  void setCode(String value) {
    _code = value;
    notifyListeners();
  }

  void toggleAgreedToTerms() {
    _agreedToTerms = !_agreedToTerms;
    notifyListeners();
  }

  Future<void> verifyInviteCode() async {
    _isLoading = true;
    _error = null;
    _verifiedBaby = null;
    notifyListeners();

    try {
      final baby = await _repository.verifyInviteCode(_code);
      _verifiedBaby = baby;
    } catch (_) {
      _error = '초대 코드 확인 중 오류가 발생했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? get babyName => _verifiedBaby?.name;

  String? get babyGenderText {
    final gender = _verifiedBaby?.gender;
    if (gender == null) return null;
    return gender == Gender.male ? AppStrings.maleLabel : AppStrings.femaleLabel;
  }

  String? get babyFormattedDate {
    final date = _verifiedBaby?.birthDate ?? _verifiedBaby?.dueDate;
    if (date == null) return null;
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  int? get babyDDay {
    final date = _verifiedBaby?.birthDate ?? _verifiedBaby?.dueDate;
    if (date == null) return null;
    return DateTime.now().difference(date).inDays;
  }

  void clearVerifiedBaby() {
    _verifiedBaby = null;
    _error = null;
    notifyListeners();
  }
}
