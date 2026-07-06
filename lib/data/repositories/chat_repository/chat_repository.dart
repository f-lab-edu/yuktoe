import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/chat/chat_conversation.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';
import 'package:yuktoe/domain/models/chat/suggested_questions.dart';

/// 채팅이 쓰는 데이터를 도메인 모델 + `Result<T>`/스트림으로 제공한다. ViewModel 이
/// 유일하게 의존하는 데이터 진입점이며(constitution Principle I), Service 를 협력자로
/// 호출한다. 서버 데이터는 [ChatService], 아기별 "현재 활성 세션 포인터" 영속은
/// 로컬 저장소가 담당하지만(책임 분리), ViewModel 이 Repository 하나만 의존하도록
/// 포인터 read/write 도 이 계약으로 노출한다.
///
/// 자체 상태(캐시·lock)를 갖지 않는다 — 진행 중 단일성·세션 상태는 ViewModel 책임.
abstract interface class ChatRepository {
  /// 그 아기의 지난 대화 내역(최신순). 빈 목록은 정상(spec FR-043). 실패:
  /// `unauthorized`/`notFound`/`networkError`/`parseFailed`(spec FR-042).
  Future<Result<List<ChatConversation>>> getConversations(
    String babyId, {
    String? cursor,
    int limit,
  });

  /// 한 세션의 메시지(시간순). 빈 목록은 정상(spec FR-043).
  Future<Result<List<ChatMessage>>> getMessages(
    String conversationId, {
    String? cursor,
    int limit,
  });

  /// 사용자 메시지 전송. `ChatStreamMeta`→`ChatStreamDelta`*→`ChatStreamDone`/
  /// `ChatStreamError` 순으로 방출하며 throw 하지 않는다(spec FR-004).
  Stream<ChatStreamEvent> sendMessage({
    required String babyId,
    String? conversationId,
    required String text,
    required DateTime localDate,
  });

  /// 추천 질문 5개 조회. 실패 시 호출자가 추천만 비노출(spec FR-013).
  Future<Result<SuggestedQuestions>> getSuggestions(
    String babyId,
    DateTime localDate,
  );

  /// 아기별 현재 활성 세션 id(로컬 포인터). 콜드 스타트 후 첫 진입에서 `null` 이라
  /// 새 세션이 시작된다(spec FR-020·FR-025).
  String? activeConversationId(String babyId);

  /// 활성 세션 포인터를 갱신한다(신규 세션의 `Meta` 회신 시, 내역에서 선택 시).
  Future<void> setActiveConversationId(String babyId, String conversationId);

  /// 활성 세션 포인터를 비운다.
  Future<void> clearActiveConversation(String babyId);
}
