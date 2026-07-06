import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/data/services/chat_service/chat_service.dart';
import 'package:yuktoe/domain/models/chat/chat_conversation.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';
import 'package:yuktoe/domain/models/chat/suggested_questions.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatService _chatService;
  final AppLocalStorage _localStorage;

  ChatRepositoryImpl(this._chatService, this._localStorage);

  @override
  Future<Result<List<ChatConversation>>> getConversations(
    String babyId, {
    String? cursor,
    int limit = 20,
  }) async {
    final result = await _chatService.getConversations(
      babyId,
      cursor: cursor,
      limit: limit,
    );
    switch (result) {
      case Ok<List<ChatConversation>>():
        return Result.ok(result.value);
      case Error<List<ChatConversation>>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<List<ChatMessage>>> getMessages(
    String conversationId, {
    String? cursor,
    int limit = 50,
  }) async {
    final result = await _chatService.getMessages(
      conversationId,
      cursor: cursor,
      limit: limit,
    );
    switch (result) {
      case Ok<List<ChatMessage>>():
        return Result.ok(result.value);
      case Error<List<ChatMessage>>():
        return Result.error(result.error);
    }
  }

  @override
  Stream<ChatStreamEvent> sendMessage({
    required String babyId,
    String? conversationId,
    required String text,
    required DateTime localDate,
  }) {
    return _chatService.sendMessage(
      babyId: babyId,
      conversationId: conversationId,
      text: text,
      localDate: localDate,
    );
  }

  @override
  Future<Result<SuggestedQuestions>> getSuggestions(
    String babyId,
    DateTime localDate,
  ) async {
    final result = await _chatService.getSuggestions(babyId, localDate);
    switch (result) {
      case Ok<SuggestedQuestions>():
        return Result.ok(result.value);
      case Error<SuggestedQuestions>():
        return Result.error(result.error);
    }
  }

  @override
  String? activeConversationId(String babyId) =>
      _localStorage.activeConversationId(babyId);

  @override
  Future<void> setActiveConversationId(
    String babyId,
    String conversationId,
  ) => _localStorage.setActiveConversationId(babyId, conversationId);

  @override
  Future<void> clearActiveConversation(String babyId) =>
      _localStorage.removeActiveConversationId(babyId);
}
