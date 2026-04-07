import 'package:flutter/foundation.dart';
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
  bool _isLoading = false;
  String? _error;
  String? _babyId;

  String get name => _name;
  Gender? get gender => _gender;
  DateTime? get birthDate => _birthDate;
  DateTime? get dueDate => _dueDate;
  bool get agreedToTerms => _agreedToTerms;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get babyId => _babyId;

  bool get isValid =>
      _name.trim().isNotEmpty &&
      _gender != null &&
      _birthDate != null &&
      _agreedToTerms &&
      !_isLoading;

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setGender(Gender value) {
    _gender = value;
    notifyListeners();
  }

  void setBirthDate(DateTime value) {
    _birthDate = value;
    notifyListeners();
  }

  void setDueDate(DateTime? value) {
    _dueDate = value;
    notifyListeners();
  }

  void toggleAgreedToTerms() {
    _agreedToTerms = !_agreedToTerms;
    notifyListeners();
  }

  Future<void> submit() async {
    _isLoading = true;
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
    } catch (e) {
      _error = AppStrings.genericError;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
