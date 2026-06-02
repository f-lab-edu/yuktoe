import 'package:flutter/foundation.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';

class CurrentBabyController extends ChangeNotifier {
  final AppLocalStorage _storage;
  String? _selectedBabyId;

  CurrentBabyController(AppLocalStorage storage)
    : _storage = storage,
      _selectedBabyId = storage.selectedBabyId;

  String? get selectedBabyId => _selectedBabyId;

  Future<void> select(String babyId) async {
    await _storage.setSelectedBabyId(babyId);
    _selectedBabyId = babyId;
    notifyListeners();
  }

  Future<void> clear() async {
    await _storage.removeSelectedBabyId();
    _selectedBabyId = null;
    notifyListeners();
  }
}
