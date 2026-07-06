import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/chat/chat_conversation.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';
import 'package:yuktoe/domain/models/chat/suggested_questions.dart';

/// Repository 의 하부 협력자. Edge Function 호출 + 테이블 select + 인증 컨텍스트
/// 주입 + JSON→도메인 매핑을 담당한다. Repository 만이 Service 에 의존하며 ViewModel
/// 은 Service 를 모른다(constitution Principle I).
///
/// 동기 결과는 `Result<T>`, 전송은 `Stream<ChatStreamEvent>` 로 노출한다. 모든 외부
/// 실패는 `AppException(ErrorCode)` 로 변환하며(스트리밍 실패는 `ChatStreamError`
/// 종료 이벤트), DB 응답/`Map`/SSE raw 라인은 경계 밖으로 나가지 않는다.
abstract interface class ChatService {
  /// 한 아기의 지난 대화 세션 목록(최신순). 빈 목록은 정상(spec FR-043).
  Future<Result<List<ChatConversation>>> getConversations(
    String babyId, {
    String? cursor,
    int limit,
  });

  /// 한 세션의 메시지 목록(시간순). 빈 목록은 정상(spec FR-043).
  Future<Result<List<ChatMessage>>> getMessages(
    String conversationId, {
    String? cursor,
    int limit,
  });

  /// 사용자 메시지를 전송하고 assistant 응답을 스트리밍한다. `conversationId` 가
  /// 없으면 서버가 신규 세션을 lazy 생성하고 `ChatStreamMeta` 로 회신한다. throw
  /// 하지 않으며 실패는 `ChatStreamError` 종료 이벤트로 표현한다.
  Stream<ChatStreamEvent> sendMessage({
    required String babyId,
    String? conversationId,
    required String text,
    required DateTime localDate,
  });

  /// 세션 시작 시 추천 질문 5개를 1회 생성한다. 실패 시 호출자가 추천만 비노출한다
  /// (채팅 차단 없음, spec FR-013).
  Future<Result<SuggestedQuestions>> getSuggestions(
    String babyId,
    DateTime localDate,
  );
}
