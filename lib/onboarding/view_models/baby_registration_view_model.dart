import 'package:flutter/foundation.dart';
import 'package:yuktoe/constants/enum/gender.dart';

class BabyRegistrationViewModel extends ChangeNotifier {
  String _name = '';
  Gender? _gender;
  DateTime? _birthDate;
  DateTime? _dueDate;
  bool _agreedToTerms = false;

  String get name => _name;
  Gender? get gender => _gender;
  DateTime? get birthDate => _birthDate;
  DateTime? get dueDate => _dueDate;
  bool get agreedToTerms => _agreedToTerms;

  bool get isValid =>
      _name.trim().isNotEmpty &&
      _gender != null &&
      _birthDate != null &&
      _agreedToTerms;

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
}
