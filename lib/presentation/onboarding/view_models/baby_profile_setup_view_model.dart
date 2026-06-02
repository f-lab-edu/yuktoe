import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/constants/enum/relationship.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/onboarding/models/relationship_option.dart';

class BabyProfileSetupViewModel extends ChangeNotifier {
  static const nicknameMaxLength = 20;

  static const relationshipOptions = [
    RelationshipOption(
      value: Relationship.mother,
      emoji: '👩',
      label: AppStrings.relationshipMom,
    ),
    RelationshipOption(
      value: Relationship.father,
      emoji: '👨',
      label: AppStrings.relationshipDad,
    ),
    RelationshipOption(
      value: Relationship.family,
      emoji: '👨\u200D👩\u200D👧',
      label: AppStrings.relationshipFamily,
    ),
    RelationshipOption(
      value: Relationship.other,
      emoji: '👤',
      label: AppStrings.relationshipOther,
    ),
  ];

  final String babyId;
  final BabyRegistrationRepository _repository;

  BabyProfileSetupViewModel({
    required this.babyId,
    required BabyRegistrationRepository repository,
  }) : _repository = repository;

  Relationship? _relationship;
  String _nickname = '';
  ActionState _state = ActionState.idle;
  String? _error;

  Relationship? get relationship => _relationship;
  String get nickname => _nickname;
  ActionState get state => _state;
  bool get isLoading => _state == ActionState.loading;
  String? get error => _error;

  bool get isValid =>
      _relationship != null && _nickname.trim().isNotEmpty && !isLoading;

  void setRelationship(Relationship value) {
    _relationship = value;
    if (_state == ActionState.error) _state = ActionState.idle;
    _error = null;
    notifyListeners();
  }

  void setNickname(String value) {
    if (value.length <= nicknameMaxLength) {
      _nickname = value;
      if (_state == ActionState.error) _state = ActionState.idle;
      _error = null;
      notifyListeners();
    }
  }

  Future<void> submit() async {
    _state = ActionState.loading;
    _error = null;
    notifyListeners();

    try {
      await _repository.setupUserProfile(
        babyId: babyId,
        relationship: _relationship!.serverValue,
        nickname: _nickname.trim(),
      );
      _state = ActionState.success;
    } catch (e) {
      _state = ActionState.error;
      _error = AppStrings.genericError;
    } finally {
      notifyListeners();
    }
  }
}
