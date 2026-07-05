import 'package:shared_preferences/shared_preferences.dart';

class AppLocalStorage {
  static const _selectedBabyIdKey = 'selected_baby_id';
  static const _quickLogButtonsKey = 'quick_log_buttons';

  final SharedPreferences _prefs;

  AppLocalStorage(this._prefs);

  String? get selectedBabyId => _prefs.getString(_selectedBabyIdKey);

  Future<void> setSelectedBabyId(String babyId) async {
    await _prefs.setString(_selectedBabyIdKey, babyId);
  }

  Future<void> removeSelectedBabyId() async {
    await _prefs.remove(_selectedBabyIdKey);
  }

  /// 빠른 기록 버튼의 사용자 커스터마이즈(순서/노출)를 담은 JSON 문자열.
  /// 형식: `[{"type":"formula","enabled":true}, ...]`. 디바이스 로컬 전용.
  /// 직렬화/역직렬화는 ViewModel 책임 — 여기서는 raw 문자열만 다룬다.
  String? get quickLogButtonsJson => _prefs.getString(_quickLogButtonsKey);

  Future<void> setQuickLogButtonsJson(String json) async {
    await _prefs.setString(_quickLogButtonsKey, json);
  }

  Future<void> removeQuickLogButtonsJson() async {
    await _prefs.remove(_quickLogButtonsKey);
  }
}
