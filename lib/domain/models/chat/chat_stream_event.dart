import 'package:yuktoe/core/error/app_exception.dart';

/// 메시지 전송(`sendMessage`)의 반환 스트림 이벤트(sealed).
///
/// 전송은 동기 `Result` 가 아니라 **이벤트 스트림**으로 노출된다(토큰 스트리밍,
/// spec FR-004). 실패도 throw 하지 않고 종료 이벤트(`ChatStreamError`)로 표현한다
/// (`Result<T>` 정신의 스트림 적용, constitution Principle III).
///
/// 불변식: 스트림은 [ChatStreamMeta] 로 시작하고 [ChatStreamDone] **또는**
/// [ChatStreamError] 중 정확히 하나로 종료한다(둘 다/없음 불가,
/// analytics_chat_data.md D-AC-2).
sealed class ChatStreamEvent {
  const ChatStreamEvent();

  /// 서버 SSE 이벤트(`event` 이름 + 디코드된 `data`)를 도메인 이벤트로 매핑한다.
  /// `error` 이벤트와 전송 실패는 Service 가 [ChatStreamError] 로 만들어야 하므로
  /// 여기서는 `meta`/`delta`/`done` 만 다루고, 모르는 이벤트·형식 오류는
  /// `FormatException` 을 던져 Service 가 `parseFailed` 로 환원한다.
  factory ChatStreamEvent.fromServerEvent(
    String event,
    Map<String, dynamic>? data,
  ) {
    switch (event) {
      case 'meta':
        final conversationId = data?['conversation_id'] as String?;
        if (conversationId == null) {
          throw const FormatException('meta event missing conversation_id');
        }
        return ChatStreamMeta(conversationId);
      case 'delta':
        final text = data?['text'] as String?;
        if (text == null) {
          throw const FormatException('delta event missing text');
        }
        return ChatStreamDelta(text);
      case 'done':
        return const ChatStreamDone();
      default:
        throw FormatException('Unknown chat stream event: $event');
    }
  }
}

/// 신규 세션이면 서버가 부여한 식별자 회신(spec FR-020). 스트림의 첫 이벤트.
final class ChatStreamMeta extends ChatStreamEvent {
  final String conversationId;

  const ChatStreamMeta(this.conversationId);

  @override
  bool operator ==(Object other) =>
      other is ChatStreamMeta && other.conversationId == conversationId;

  @override
  int get hashCode => conversationId.hashCode;
}

/// 토큰 조각(점진 표시, spec FR-004). 0회 이상 반복된다.
final class ChatStreamDelta extends ChatStreamEvent {
  final String text;

  const ChatStreamDelta(this.text);

  @override
  bool operator ==(Object other) =>
      other is ChatStreamDelta && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// 정상 완료. assistant 메시지가 서버에 확정 저장됨(spec FR-041). 스트림 종료.
final class ChatStreamDone extends ChatStreamEvent {
  const ChatStreamDone();

  @override
  bool operator ==(Object other) => other is ChatStreamDone;

  @override
  int get hashCode => (ChatStreamDone).hashCode;
}

/// 중도 실패. 부분 누적 본문은 폐기 대상(spec Edge Case). 스트림 종료.
final class ChatStreamError extends ChatStreamEvent {
  final AppException error;

  const ChatStreamError(this.error);

  @override
  bool operator ==(Object other) =>
      other is ChatStreamError && other.error.code == error.code;

  @override
  int get hashCode => error.code.hashCode;
}
