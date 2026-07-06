import 'package:flutter/widgets.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/domain/models/chat/suggested_questions.dart';

/// 입력창의 텍스트 상태와 추천 질문 풀·순환 인덱스만 담당한다. [ChatViewModel] 과
/// 분리한 이유는 AI 응답 중에도 입력창 타이핑은 허용되므로(spec FR-005), 전송 스트림
/// 상태 변화가 입력 상태를 오염시키지 않게 하기 위함이다.
///
/// 위젯을 `StatelessWidget` 으로 두기 위해 `TextEditingController` 를 이 컨트롤러가
/// 보유한다(기존 `MemoInputController` 패턴). 전송 잠금(`isStreaming`)은 [ChatViewModel]
/// 소관이므로, 최종 전송 가능 여부는 View 에서 `canSubmit && !vm.isStreaming` 으로
/// 합성한다.
class ChatInputController extends ChangeNotifier {
  /// 한 번에 입력 가능한 사용자 메시지 글자수 상한(spec FR-033, 기본 1000자).
  static const maxLength = 1000;

  final TextEditingController textController = TextEditingController();
  final ChatRepository _chatRepository;
  final DateTime Function() _now;

  ChatInputController({
    required ChatRepository chatRepository,
    DateTime Function()? now,
  }) : _chatRepository = chatRepository,
       _now = now ?? DateTime.now {
    textController.addListener(_onTextChanged);
  }

  String get text => textController.text;

  /// 공백 제외 1자 이상이면 제출 가능(전송 잠금은 View 에서 합성, spec FR-003).
  bool get canSubmit => textController.text.trim().isNotEmpty;

  /// 남은 입력 가능 글자수(입력창 하단 카운터).
  int get remaining => maxLength - textController.text.length;

  List<String> _suggestions = const [];
  List<String> get suggestions => _suggestions;

  int _suggestionIndex = 0;

  /// 현재 노출 중인 추천 질문 1개. 풀이 비면 `null`(추천 영역 비노출).
  String? get currentSuggestion =>
      _suggestions.isEmpty ? null : _suggestions[_suggestionIndex];

  String? _lastLoadedBabyId;

  /// 세션 시작 / 아기 전환 시 추천을 1회 로드한다(같은 아기면 재로드 안 함).
  Future<void> loadFor(String? babyId) async {
    if (babyId == null) {
      _lastLoadedBabyId = null;
      _suggestions = const [];
      _suggestionIndex = 0;
      notifyListeners();
      return;
    }
    if (babyId == _lastLoadedBabyId) return;
    _lastLoadedBabyId = babyId;
    await loadSuggestions(babyId);
  }

  /// `getSuggestions` 1회 호출. 실패 시 풀을 빈 채로 두어 추천 영역만 비노출한다
  /// (채팅 차단 없음, spec FR-013).
  Future<void> loadSuggestions(String babyId) async {
    final result = await _chatRepository.getSuggestions(babyId, _today());
    switch (result) {
      case Ok<SuggestedQuestions>():
        _suggestions = result.value.questions;
        _suggestionIndex = 0;
      case Error<SuggestedQuestions>():
        _suggestions = const [];
        _suggestionIndex = 0;
    }
    notifyListeners();
  }

  /// 보유한 추천 풀을 로컬에서 순환한다(추가 네트워크 호출 없음, spec FR-011).
  void cycleSuggestion() {
    if (_suggestions.isEmpty) return;
    _suggestionIndex = (_suggestionIndex + 1) % _suggestions.length;
    notifyListeners();
  }

  /// 현재 추천 질문을 입력창에 채운다(이후 사용자가 전송/수정, spec FR-012).
  void applySuggestion() {
    final suggestion = currentSuggestion;
    if (suggestion == null) return;
    textController.text = suggestion.length > maxLength
        ? suggestion.substring(0, maxLength)
        : suggestion;
  }

  /// 전송 성공 후 입력 비우기.
  void clear() => textController.clear();

  void _onTextChanged() {
    // 글자수 상한 초과분은 잘라낸다(초과 입력 차단, spec FR-033).
    final current = textController.text;
    if (current.length > maxLength) {
      final trimmed = current.substring(0, maxLength);
      textController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
      return; // 위 대입이 리스너를 다시 부른다.
    }
    notifyListeners();
  }

  DateTime _today() {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    textController.removeListener(_onTextChanged);
    textController.dispose();
    super.dispose();
  }
}
