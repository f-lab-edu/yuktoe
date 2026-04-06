import 'package:flutter/foundation.dart';
import 'package:yuktoe/constants/enum/relationship.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/domain/models/baby_registration/onboarding_flow.dart';

class BabyProfileSetupViewModel extends ChangeNotifier {
  static const nicknameMaxLength = 20;

  final OnboardingFlow flow;
  final BabyRegistrationRepository _repository;

  BabyProfileSetupViewModel({
    required this.flow,
    required BabyRegistrationRepository repository,
  }) : _repository = repository;

  Relationship? _relationship;
  String _nickname = '';
  bool _isLoading = false;
  String? _error;
  String? _babyId;

  Relationship? get relationship => _relationship;
  String get nickname => _nickname;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get babyId => _babyId;

  bool get isValid =>
      _relationship != null && _nickname.trim().isNotEmpty && !_isLoading;

  void setRelationship(Relationship value) {
    _relationship = value;
    notifyListeners();
  }

  void setNickname(String value) {
    if (value.length <= nicknameMaxLength) {
      _nickname = value;
      notifyListeners();
    }
  }

  Future<void> submit() async {
    _isLoading = true;
    _error = null;
    _babyId = null;
    notifyListeners();

    try {
      _babyId = switch (flow) {
        CreateBabyFlow(
          :final name,
          :final gender,
          :final birthDate,
          :final dueDate,
        ) =>
          await _repository.createBaby(
            name: name,
            birthDate: _formatDate(birthDate),
            dueDate: dueDate != null ? _formatDate(dueDate) : null,
            gender: gender.serverValue,
            relationship: _relationship!.serverValue,
            nickname: _nickname.trim(),
          ),
        JoinBabyFlow(:final inviteCode) =>
          await _repository.joinBabyByInviteCode(
            code: inviteCode,
            relationship: _relationship!.serverValue,
            nickname: _nickname.trim(),
          ),
      };
    } catch (e) {
      _error = '오류가 발생했습니다. 다시 시도해주세요.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
