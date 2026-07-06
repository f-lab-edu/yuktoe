import 'package:shared_preferences/shared_preferences.dart';

class AppLocalStorage {
  static const _selectedBabyIdKey = 'selected_baby_id';
  static const _activeConversationIdPrefix = 'chat_active_conversation_';

  final SharedPreferences _prefs;

  AppLocalStorage(this._prefs);

  String? get selectedBabyId => _prefs.getString(_selectedBabyIdKey);

  Future<void> setSelectedBabyId(String babyId) async {
    await _prefs.setString(_selectedBabyIdKey, babyId);
  }

  Future<void> removeSelectedBabyId() async {
    await _prefs.remove(_selectedBabyIdKey);
  }

  /// 아기별 "현재 활성 채팅 세션" id 포인터. 대화·메시지 본문은 서버 SSOT 이고,
  /// 로컬에는 이 포인터만 보관한다(spec FR-025).
  String? activeConversationId(String babyId) =>
      _prefs.getString('$_activeConversationIdPrefix$babyId');

  Future<void> setActiveConversationId(
    String babyId,
    String conversationId,
  ) async {
    await _prefs.setString(
      '$_activeConversationIdPrefix$babyId',
      conversationId,
    );
  }

  Future<void> removeActiveConversationId(String babyId) async {
    await _prefs.remove('$_activeConversationIdPrefix$babyId');
  }
}
