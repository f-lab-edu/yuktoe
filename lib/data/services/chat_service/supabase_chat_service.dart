import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/chat/chat_conversation.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';
import 'package:yuktoe/domain/models/chat/suggested_questions.dart';

import 'chat_service.dart';

/// Edge Function `analytics_chat`(전송/추천) 호출 + `chat_conversations`/
/// `chat_messages` 테이블 select(내역/메시지) + JSON→도메인 매핑.
///
/// NOTE: 서버(Edge Function/테이블/RLS)는 [`analytics_chat_backend.md`] 의 별도
/// 책임이며, 아래 함수명(`analytics_chat`)·액션(`send`/`suggest`)·SSE 이벤트
/// (`meta`/`delta`/`done`/`error`)·컬럼명은 그 계약을 **가정**한 것이다. 서버가
/// 준비되면 실제 계약에 맞춰 조정한다. 내역·메시지 조회는 LLM 이 필요 없으므로
/// Edge Function 이 아닌 테이블 직접 select 로 처리한다(RLS 보호).
class SupabaseChatService implements ChatService {
  static const _functionName = 'analytics_chat';

  final SupabaseClient _client;

  SupabaseChatService({required SupabaseClient client}) : _client = client;

  @override
  Future<Result<List<ChatConversation>>> getConversations(
    String babyId, {
    String? cursor,
    int limit = 20,
  }) async {
    try {
      var query = _client
          .from('chat_conversations')
          .select()
          .eq('baby_id', babyId);

      if (cursor != null) {
        query = query.lt('last_message_at', cursor);
      }

      final data = await query
          .order('last_message_at', ascending: false)
          .limit(limit);

      final items = data.map(ChatConversation.fromJson).toList();
      return Result.ok(items);
    } catch (e) {
      return Result.error(_classify(e, 'Failed to get conversations'));
    }
  }

  @override
  Future<Result<List<ChatMessage>>> getMessages(
    String conversationId, {
    String? cursor,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId);

      if (cursor != null) {
        query = query.gt('created_at', cursor);
      }

      final data = await query
          .order('created_at', ascending: true)
          .limit(limit);

      final items = data.map(ChatMessage.fromJson).toList();
      return Result.ok(items);
    } catch (e) {
      return Result.error(_classify(e, 'Failed to get messages'));
    }
  }

  @override
  Stream<ChatStreamEvent> sendMessage({
    required String babyId,
    String? conversationId,
    required String text,
    required DateTime localDate,
  }) async* {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      yield const ChatStreamError(
        AppException(ErrorCode.unauthorized, 'Not signed in'),
      );
      return;
    }

    try {
      final response = await _client.functions.invoke(
        _functionName,
        body: {
          'action': 'send',
          'baby_id': babyId,
          if (conversationId != null) 'conversation_id': conversationId,
          'message': text,
          'local_date': _localDateString(localDate),
        },
      );

      final data = response.data;
      if (data is! Stream) {
        yield ChatStreamError(
          AppException(
            ErrorCode.parseFailed,
            'Expected an event stream, got ${data.runtimeType}',
          ),
        );
        return;
      }

      final lines = data
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String? eventName;
      final dataBuffer = StringBuffer();

      await for (final line in lines) {
        // SSE: 빈 줄은 하나의 이벤트 경계다.
        if (line.isEmpty) {
          final event = _dispatch(eventName, dataBuffer.toString());
          eventName = null;
          dataBuffer.clear();
          if (event != null) {
            yield event;
            if (event is ChatStreamDone || event is ChatStreamError) return;
          }
          continue;
        }
        if (line.startsWith(':')) continue; // SSE comment/heartbeat
        if (line.startsWith('event:')) {
          eventName = line.substring('event:'.length).trim();
        } else if (line.startsWith('data:')) {
          dataBuffer.write(line.substring('data:'.length).trim());
        }
      }

      // 스트림이 종료 이벤트 없이 끊긴 경우도 실패로 종료한다(부분 응답 폐기).
      final trailing = _dispatch(eventName, dataBuffer.toString());
      if (trailing != null &&
          trailing is! ChatStreamDone &&
          trailing is! ChatStreamError) {
        yield trailing;
      }
      if (trailing is! ChatStreamDone) {
        yield ChatStreamError(
          trailing is ChatStreamError
              ? trailing.error
              : const AppException(
                  ErrorCode.networkError,
                  'Stream ended without completion',
                ),
        );
      } else {
        yield trailing;
      }
    } on FunctionException catch (e) {
      yield ChatStreamError(_classifyStatus(e.status, 'Failed to send message'));
    } catch (e) {
      yield ChatStreamError(_classify(e, 'Failed to send message'));
    }
  }

  /// 하나의 SSE 이벤트 블록을 도메인 이벤트로 변환한다. 이벤트가 없으면 `null`.
  /// `error` 이벤트와 파싱 실패는 [ChatStreamError] 로 변환한다.
  ChatStreamEvent? _dispatch(String? eventName, String rawData) {
    if (eventName == null || eventName.isEmpty) return null;
    try {
      final payload = rawData.isEmpty
          ? null
          : Map<String, dynamic>.from(jsonDecode(rawData) as Map);
      if (eventName == 'error') {
        return ChatStreamError(
          AppException(
            ErrorCode.networkError,
            payload?['message'] as String? ?? 'Stream error',
          ),
        );
      }
      return ChatStreamEvent.fromServerEvent(eventName, payload);
    } catch (e) {
      return ChatStreamError(_classify(e, 'Failed to parse stream event'));
    }
  }

  @override
  Future<Result<SuggestedQuestions>> getSuggestions(
    String babyId,
    DateTime localDate,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Result.error(
        const AppException(ErrorCode.unauthorized, 'Not signed in'),
      );
    }

    try {
      final response = await _client.functions.invoke(
        _functionName,
        body: {
          'action': 'suggest',
          'baby_id': babyId,
          'local_date': _localDateString(localDate),
        },
      );

      final data = response.data;
      if (data is! Map) {
        return Result.error(
          AppException(
            ErrorCode.parseFailed,
            'Expected a JSON object, got ${data.runtimeType}',
          ),
        );
      }
      return Result.ok(
        SuggestedQuestions.fromJson(Map<String, dynamic>.from(data)),
      );
    } on FunctionException catch (e) {
      return Result.error(
        _classifyStatus(e.status, 'Failed to get suggestions'),
      );
    } catch (e) {
      return Result.error(_classify(e, 'Failed to get suggestions'));
    }
  }

  /// 로컬 날짜를 `YYYY-MM-DD` 로 포맷한다(요약 윈도우·월령 산정용, spec FR-030).
  String _localDateString(DateTime localDate) {
    final y = localDate.year.toString().padLeft(4, '0');
    final m = localDate.month.toString().padLeft(2, '0');
    final d = localDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  AppException _classifyStatus(int status, String message) {
    if (status == 401) {
      return AppException(ErrorCode.unauthorized, message);
    }
    if (status == 403 || status == 404) {
      return AppException(ErrorCode.notFound, message);
    }
    return AppException(ErrorCode.networkError, message);
  }

  AppException _classify(Object e, String message) {
    if (e is AuthException) {
      return AppException(ErrorCode.unauthorized, message, cause: e);
    }
    if (e is FunctionException) {
      return _classifyStatus(e.status, message);
    }
    if (e is PostgrestException || e is SocketException) {
      return AppException(ErrorCode.networkError, message, cause: e);
    }
    if (e is FormatException || e is TypeError || e is ArgumentError) {
      return AppException(ErrorCode.parseFailed, message, cause: e);
    }
    return AppException(ErrorCode.unknown, message, cause: e);
  }
}
