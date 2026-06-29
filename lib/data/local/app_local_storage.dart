import 'package:shared_preferences/shared_preferences.dart';

class AppLocalStorage {
  static const _selectedBabyIdKey = 'selected_baby_id';

  final SharedPreferences _prefs;

  AppLocalStorage(this._prefs);

  String? get selectedBabyId => _prefs.getString(_selectedBabyIdKey);

  Future<void> setSelectedBabyId(String babyId) async {
    await _prefs.setString(_selectedBabyIdKey, babyId);
  }

  Future<void> removeSelectedBabyId() async {
    await _prefs.remove(_selectedBabyIdKey);
  }
}
