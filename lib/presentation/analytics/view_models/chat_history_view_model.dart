import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/domain/models/chat/chat_conversation.dart';

/// 시계 버튼으로 바텀시트가 열릴 때 그 아기의 대화 목록을 조회·표시한다. 선택은
/// 호출부가 [ChatViewModel.openConversation] 으로 위임한다. 바텀시트가 열려 있는
/// 동안만 산다.
class ChatHistoryViewModel extends ChangeNotifier {
  final ChatRepository _chatRepository;

  ChatHistoryViewModel({required ChatRepository chatRepository})
    : _chatRepository = chatRepository;

  ActionState _state = ActionState.idle;
  ActionState get state => _state;

  ErrorCode? _errorCode;
  ErrorCode? get errorCode => _errorCode;

  List<ChatConversation> _conversations = const [];
  List<ChatConversation> get conversations => _conversations;

  /// 시트 오픈 시 그 아기의 대화 목록(최신순)을 조회한다. 빈 목록은 정상이다.
  Future<void> load(String babyId) async {
    _state = ActionState.loading;
    _errorCode = null;
    notifyListeners();

    final result = await _chatRepository.getConversations(babyId);
    switch (result) {
      case Ok<List<ChatConversation>>():
        _conversations = result.value;
        _state = ActionState.success;
      case Error<List<ChatConversation>>():
        _conversations = const [];
        _state = ActionState.error;
        _errorCode = result.error.code;
    }
    notifyListeners();
  }
}
