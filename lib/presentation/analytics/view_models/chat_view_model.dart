import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';

/// 분석 탭 채팅의 코디네이터. 현재 활성 세션의 메시지 목록을 화면에 제공하고,
/// 전송 스트림을 소비해 점진 표시로 누적하며, 전송 잠금·세션 전환·오류를 관리한다.
///
/// 데이터 의존은 [ChatRepository](서버·포인터)이며, 환영 문구의 아기 이름 조회에만
/// [BabyRepository] 를 협력자로 쓴다. 현재 선택 아기는 화면의
/// `ChangeNotifierProxyProvider` 가 [enterTab] 인자로 전달한다.
class ChatViewModel extends ChangeNotifier {
  /// 프로세스 콜드 스타트 여부. 앱 실행 후 첫 진입은 항상 빈 새 세션으로 시작한다
  /// (spec FR-020). 이후 진입/아기 전환은 저장된 활성 세션 포인터를 따른다.
  static bool _coldStart = true;

  @visibleForTesting
  static void resetColdStartForTest() => _coldStart = true;

  final ChatRepository _chatRepository;
  final BabyRepository _babyRepository;
  final DateTime Function() _now;

  ChatViewModel({
    required ChatRepository chatRepository,
    required BabyRepository babyRepository,
    DateTime Function()? now,
  }) : _chatRepository = chatRepository,
       _babyRepository = babyRepository,
       _now = now ?? DateTime.now;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _showWelcome = false;
  bool get showWelcome => _showWelcome;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  String _streamingText = '';
  String get streamingText => _streamingText;

  String? _errorMessageId;
  String? get errorMessageId => _errorMessageId;

  ActionState _state = ActionState.idle;
  ActionState get state => _state;

  String? _activeConversationId;
  String? get activeConversationId => _activeConversationId;

  String? _babyName;

  /// 환영 메시지 문구(표시 전용, 미저장). 아기 이름이 없으면 중립 표현으로 대체한다.
  String get welcomeMessage {
    final name = _babyName;
    if (name == null || name.isEmpty) {
      return '우리 아기에 대해 궁금한 건 무엇이든지 물어보세요.';
    }
    return '$name에 대해 궁금한 건 무엇이든지 물어보세요.';
  }

  String? _babyId;
  String? _lastEnteredBabyId;
  int _localSeq = 0;
  StreamSubscription<ChatStreamEvent>? _subscription;

  /// 탭 진입 / 아기 전환 시 호출된다. 같은 아기면 재초기화하지 않는다(중복 가드).
  Future<void> enterTab(String? babyId) async {
    if (babyId == null) {
      _lastEnteredBabyId = null;
      _babyId = null;
      _resetSession();
      _state = ActionState.idle;
      notifyListeners();
      return;
    }
    if (babyId == _lastEnteredBabyId) return;
    _lastEnteredBabyId = babyId;
    _babyId = babyId;

    _resetSession();
    _state = ActionState.idle;
    notifyListeners();

    unawaited(_resolveBabyName(babyId));

    // 콜드 스타트 후 첫 진입은 빈 새 세션(spec FR-020). 저장된 포인터는 비운다.
    if (_coldStart) {
      _coldStart = false;
      await _chatRepository.clearActiveConversation(babyId);
      _startNewSession();
      return;
    }

    final pointer = _chatRepository.activeConversationId(babyId);
    if (pointer == null) {
      _startNewSession();
      return;
    }
    await _loadConversation(pointer);
  }

  /// 전송 버튼 탭 / 입력창 제출. 스트리밍 중이면 무시한다(단일 진행, spec FR-005).
  Future<void> send(String text) async {
    final trimmed = text.trim();
    final babyId = _babyId;
    if (_isStreaming || trimmed.isEmpty || babyId == null) return;

    final userMessage = ChatMessage(
      id: 'local-user-${_localSeq++}',
      conversationId: _activeConversationId ?? '',
      role: ChatRole.user,
      content: trimmed,
      createdAt: _now().toUtc(),
    );
    _messages.add(userMessage);
    _showWelcome = false;
    _isStreaming = true;
    _streamingText = '';
    _errorMessageId = null;
    _state = ActionState.success;
    notifyListeners();

    final stream = _chatRepository.sendMessage(
      babyId: babyId,
      conversationId: _activeConversationId,
      text: trimmed,
      localDate: _today(),
    );

    final completer = Completer<void>();
    await _subscription?.cancel();
    _subscription = stream.listen(
      (event) => _onStreamEvent(event, userMessage.id),
      onError: (Object error) {
        _onStreamError(userMessage.id);
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        // 종료 이벤트(Done/Error) 없이 끊긴 경우도 실패 처리.
        if (_isStreaming) _onStreamError(userMessage.id);
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  /// 에러 버블의 "다시 시도". 해당 사용자 메시지 본문으로 재전송한다(spec Edge Case).
  Future<void> retry(String messageId) async {
    ChatMessage? target;
    for (final message in _messages) {
      if (message.id == messageId && message.role == ChatRole.user) {
        target = message;
        break;
      }
    }
    if (target == null) return;
    _errorMessageId = null;
    // 실패한 사용자 버블은 남겨두고 같은 본문으로 다시 보낸다.
    await send(target.content);
  }

  /// 내역에서 대화를 선택. 진행 중이던 빈 세션(사용자 메시지 0)은 폐기되고, 선택한
  /// 대화가 활성 세션으로 뜬다(spec FR-023).
  Future<void> openConversation(String conversationId) async {
    if (conversationId == _activeConversationId) return;
    final babyId = _babyId;
    if (babyId != null) {
      await _chatRepository.setActiveConversationId(babyId, conversationId);
    }
    await _loadConversation(conversationId);
  }

  void _onStreamEvent(ChatStreamEvent event, String userMessageId) {
    switch (event) {
      case ChatStreamMeta(:final conversationId):
        _activeConversationId = conversationId;
        final babyId = _babyId;
        if (babyId != null) {
          unawaited(
            _chatRepository.setActiveConversationId(babyId, conversationId),
          );
        }
        _showWelcome = false;
        notifyListeners();
      case ChatStreamDelta(:final text):
        _streamingText += text;
        notifyListeners();
      case ChatStreamDone():
        if (_streamingText.isNotEmpty) {
          _messages.add(
            ChatMessage(
              id: 'local-assistant-${_localSeq++}',
              conversationId: _activeConversationId ?? '',
              role: ChatRole.assistant,
              content: _streamingText,
              createdAt: _now().toUtc(),
            ),
          );
        }
        _streamingText = '';
        _isStreaming = false;
        notifyListeners();
      case ChatStreamError():
        _onStreamError(userMessageId);
    }
  }

  void _onStreamError(String userMessageId) {
    _streamingText = '';
    _isStreaming = false;
    _errorMessageId = userMessageId;
    notifyListeners();
  }

  Future<void> _loadConversation(String conversationId) async {
    _activeConversationId = conversationId;
    _state = ActionState.loading;
    notifyListeners();

    final result = await _chatRepository.getMessages(conversationId);
    switch (result) {
      case Ok<List<ChatMessage>>():
        _messages
          ..clear()
          ..addAll(result.value);
        _showWelcome = !_messages.any((m) => m.role == ChatRole.user);
        _state = ActionState.success;
      case Error<List<ChatMessage>>():
        _state = ActionState.error;
    }
    notifyListeners();
  }

  void _startNewSession() {
    _activeConversationId = null;
    _messages.clear();
    _showWelcome = true;
    _state = ActionState.success;
    notifyListeners();
  }

  void _resetSession() {
    _messages.clear();
    _showWelcome = false;
    _isStreaming = false;
    _streamingText = '';
    _errorMessageId = null;
    _activeConversationId = null;
  }

  Future<void> _resolveBabyName(String babyId) async {
    final result = await _babyRepository.getBaby(babyId);
    if (babyId != _babyId) return;
    switch (result) {
      case Ok<Baby>():
        _babyName = result.value.name;
        if (_showWelcome) notifyListeners();
      case Error<Baby>():
        // 이름 조회 실패는 채팅을 막지 않는다 — 중립 환영 문구로 대체.
        break;
    }
  }

  DateTime _today() {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
