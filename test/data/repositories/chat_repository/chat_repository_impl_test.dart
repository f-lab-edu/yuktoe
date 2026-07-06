import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository_impl.dart';
import 'package:yuktoe/data/services/chat_service/chat_service.dart';
import 'package:yuktoe/domain/models/chat/chat_conversation.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';
import 'package:yuktoe/domain/models/chat/suggested_questions.dart';

import 'chat_repository_impl_test.mocks.dart';

@GenerateMocks([ChatService, AppLocalStorage])
void main() {
  late MockChatService mockService;
  late MockAppLocalStorage mockStorage;
  late ChatRepositoryImpl repository;

  const babyId = 'baby-1';
  final localDate = DateTime(2026, 7, 6);

  setUpAll(() {
    provideDummy<Result<List<ChatConversation>>>(
      Result.ok(const <ChatConversation>[]),
    );
    provideDummy<Result<List<ChatMessage>>>(Result.ok(const <ChatMessage>[]));
    provideDummy<Result<SuggestedQuestions>>(
      Result.ok(SuggestedQuestions(const ['a', 'b', 'c', 'd', 'e'])),
    );
    provideDummy<Stream<ChatStreamEvent>>(const Stream.empty());
  });

  setUp(() {
    mockService = MockChatService();
    mockStorage = MockAppLocalStorage();
    repository = ChatRepositoryImpl(mockService, mockStorage);
  });

  group('getConversations', () {
    test('D-AC-6: 빈 목록도 성공으로 전달한다', () async {
      when(
        mockService.getConversations(
          babyId,
          cursor: anyNamed('cursor'),
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async => Result.ok(const <ChatConversation>[]));

      final result = await repository.getConversations(babyId);

      expect(result, isA<Ok<List<ChatConversation>>>());
      expect((result as Ok<List<ChatConversation>>).value, isEmpty);
    });

    test('D-AC-8: 호출한 babyId 로 Service 를 호출한다', () async {
      when(
        mockService.getConversations(
          any,
          cursor: anyNamed('cursor'),
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async => Result.ok(const <ChatConversation>[]));

      await repository.getConversations(babyId);

      verify(
        mockService.getConversations(
          babyId,
          cursor: anyNamed('cursor'),
          limit: anyNamed('limit'),
        ),
      ).called(1);
    });

    test('D-AC-7: Service 오류(각 코드)를 그대로 전달한다', () async {
      for (final code in [
        ErrorCode.notFound,
        ErrorCode.unauthorized,
        ErrorCode.networkError,
        ErrorCode.parseFailed,
      ]) {
        when(
          mockService.getConversations(
            any,
            cursor: anyNamed('cursor'),
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => Result.error(AppException(code, 'boom')));

        final result = await repository.getConversations(babyId);

        expect(result, isA<Error<List<ChatConversation>>>());
        expect((result as Error<List<ChatConversation>>).error.code, code);
      }
    });
  });

  group('getMessages', () {
    test('D-AC-6: 빈 목록도 성공으로 전달한다', () async {
      when(
        mockService.getMessages(
          'c1',
          cursor: anyNamed('cursor'),
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async => Result.ok(const <ChatMessage>[]));

      final result = await repository.getMessages('c1');

      expect(result, isA<Ok<List<ChatMessage>>>());
      expect((result as Ok<List<ChatMessage>>).value, isEmpty);
    });
  });

  group('sendMessage', () {
    test('D-AC-2: Meta→Delta*→Done 순서로 스트림을 전달한다', () {
      when(
        mockService.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          ChatStreamMeta('c1'),
          ChatStreamDelta('안'),
          ChatStreamDelta('녕'),
          ChatStreamDone(),
        ]),
      );

      final stream = repository.sendMessage(
        babyId: babyId,
        conversationId: null,
        text: '질문',
        localDate: localDate,
      );

      expect(
        stream,
        emitsInOrder([
          const ChatStreamMeta('c1'),
          const ChatStreamDelta('안'),
          const ChatStreamDelta('녕'),
          const ChatStreamDone(),
          emitsDone,
        ]),
      );
    });

    test('D-AC-4: 중도 실패는 throw 없이 ChatStreamError 로 종료한다', () {
      when(
        mockService.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          ChatStreamMeta('c1'),
          ChatStreamDelta('부분'),
          ChatStreamError(
            AppException(ErrorCode.networkError, 'dropped'),
          ),
        ]),
      );

      final stream = repository.sendMessage(
        babyId: babyId,
        text: '질문',
        localDate: localDate,
      );

      expect(
        stream,
        emitsInOrder([
          const ChatStreamMeta('c1'),
          const ChatStreamDelta('부분'),
          const ChatStreamError(AppException(ErrorCode.networkError, 'dropped')),
          emitsDone,
        ]),
      );
    });

    test('D-AC-10: 전송에 localDate 를 전달한다', () async {
      when(
        mockService.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      await repository
          .sendMessage(babyId: babyId, text: 'q', localDate: localDate)
          .drain<void>();

      verify(
        mockService.sendMessage(
          babyId: babyId,
          conversationId: anyNamed('conversationId'),
          text: 'q',
          localDate: localDate,
        ),
      ).called(1);
    });
  });

  group('getSuggestions', () {
    test('성공 시 5개 풀을 전달한다', () async {
      final questions = SuggestedQuestions(const [
        'q1',
        'q2',
        'q3',
        'q4',
        'q5',
      ]);
      when(
        mockService.getSuggestions(babyId, localDate),
      ).thenAnswer((_) async => Result.ok(questions));

      final result = await repository.getSuggestions(babyId, localDate);

      expect((result as Ok<SuggestedQuestions>).value, questions);
    });

    test('D-AC-5: parseFailed 를 그대로 전달한다(추천만 비노출 신호)', () async {
      when(mockService.getSuggestions(babyId, localDate)).thenAnswer(
        (_) async =>
            Result.error(const AppException(ErrorCode.parseFailed, 'not 5')),
      );

      final result = await repository.getSuggestions(babyId, localDate);

      expect(result, isA<Error<SuggestedQuestions>>());
      expect(
        (result as Error<SuggestedQuestions>).error.code,
        ErrorCode.parseFailed,
      );
    });

    test('D-AC-10: 추천에 localDate 를 전달한다', () async {
      when(
        mockService.getSuggestions(any, any),
      ).thenAnswer((_) async => Result.error(
            const AppException(ErrorCode.parseFailed, 'x'),
          ));

      await repository.getSuggestions(babyId, localDate);

      verify(mockService.getSuggestions(babyId, localDate)).called(1);
    });
  });

  group('활성 세션 포인터', () {
    test('D-AC-9: 포인터는 아기별로 로컬 저장소에 위임된다', () async {
      when(mockStorage.activeConversationId(babyId)).thenReturn('c-1');

      expect(repository.activeConversationId(babyId), 'c-1');

      await repository.setActiveConversationId(babyId, 'c-2');
      verify(mockStorage.setActiveConversationId(babyId, 'c-2')).called(1);

      await repository.clearActiveConversation(babyId);
      verify(mockStorage.removeActiveConversationId(babyId)).called(1);
    });

    test('D-AC-9: 콜드 스타트 후 첫 진입에서 포인터가 비어 있다', () {
      when(mockStorage.activeConversationId(babyId)).thenReturn(null);
      expect(repository.activeConversationId(babyId), isNull);
    });
  });
}
