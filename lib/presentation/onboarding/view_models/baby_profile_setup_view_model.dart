import 'package:flutter/foundation.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/constants/enum/relationship.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/presentation/onboarding/models/relationship_option.dart';

class BabyProfileSetupViewModel extends ChangeNotifier {
  static const nicknameMaxLength = 20;

  static const relationshipOptions = [
    RelationshipOption(value: Relationship.mother, emoji: '👩', label: AppStrings.relationshipMom),
    RelationshipOption(value: Relationship.father, emoji: '👨', label: AppStrings.relationshipDad),
    RelationshipOption(value: Relationship.family, emoji: '👨\u200D👩\u200D👧', label: AppStrings.relationshipFamily),
    RelationshipOption(value: Relationship.other, emoji: '👤', label: AppStrings.relationshipOther),
  ];

  final String babyId;
  final BabyRegistrationRepository _repository;

  BabyProfileSetupViewModel({
    required this.babyId,
    required BabyRegistrationRepository repository,
  }) : _repository = repository;

  Relationship? _relationship;
  String _nickname = '';
  bool _isLoading = false;
  String? _error;
  bool _isSuccess = false;

  Relationship? get relationship => _relationship;
  String get nickname => _nickname;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSuccess => _isSuccess;

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
    _isSuccess = false;
    notifyListeners();

    try {
      await _repository.setupUserProfile(
        babyId: babyId,
        relationship: _relationship!.serverValue,
        nickname: _nickname.trim(),
      );
      _isSuccess = true;
    } catch (e) {
      _error = AppStrings.genericError;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
