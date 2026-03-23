import 'package:flutter/foundation.dart';

class InviteCodeViewModel extends ChangeNotifier {
  String _code = '';
  bool _agreedToTerms = false;

  String get code => _code;
  bool get agreedToTerms => _agreedToTerms;

  bool get isValid => _code.trim().isNotEmpty && _agreedToTerms;

  void setCode(String value) {
    _code = value;
    notifyListeners();
  }

  void toggleAgreedToTerms() {
    _agreedToTerms = !_agreedToTerms;
    notifyListeners();
  }
}
