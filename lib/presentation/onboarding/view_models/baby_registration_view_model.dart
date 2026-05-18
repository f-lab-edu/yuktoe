import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/constants/app_strings.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';

class BabyRegistrationViewModel extends ChangeNotifier {
  final BabyRegistrationRepository _repository;

  BabyRegistrationViewModel({required BabyRegistrationRepository repository})
    : _repository = repository;

  String _name = '';
  Gender? _gender;
  DateTime? _birthDate;
  DateTime? _dueDate;
  bool _agreedToTerms = false;
  ActionState _state = ActionState.idle;
  String? _error;
  String? _babyId;

  String get name => _name;
  Gender? get gender => _gender;
  DateTime? get birthDate => _birthDate;
  DateTime? get dueDate => _dueDate;
  bool get agreedToTerms => _agreedToTerms;
  ActionState get state => _state;
  bool get isLoading => _state == ActionState.loading;
  String? get error => _error;
  String? get babyId => _babyId;

  bool get isValid =>
      _name.trim().isNotEmpty &&
      _gender != null &&
      _birthDate != null &&
      _agreedToTerms &&
      !isLoading;

  void setName(String value) {
    _name = value;
    if (_state == ActionState.error) _state = ActionState.idle;
    _error = null;
    notifyListeners();
  }

  void setGender(Gender value) {
    _gender = value;
    if (_state == ActionState.error) _state = ActionState.idle;
    _error = null;
    notifyListeners();
  }

  void setBirthDate(DateTime value) {
    _birthDate = value;
    if (_state == ActionState.error) _state = ActionState.idle;
    _error = null;
    notifyListeners();
  }

  void setDueDate(DateTime? value) {
    _dueDate = value;
    if (_state == ActionState.error) _state = ActionState.idle;
    _error = null;
    notifyListeners();
  }

  void toggleAgreedToTerms() {
    _agreedToTerms = !_agreedToTerms;
    notifyListeners();
  }

  Future<void> submit() async {
    _state = ActionState.loading;
    _error = null;
    _babyId = null;
    notifyListeners();

    try {
      _babyId = await _repository.createBaby(
        name: _name,
        birthDate: _formatDate(_birthDate!),
        dueDate: _dueDate != null ? _formatDate(_dueDate!) : null,
        gender: _gender!.serverValue,
      );
      _state = ActionState.success;
    } catch (e) {
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

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
