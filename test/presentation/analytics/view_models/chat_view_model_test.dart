import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_view_model.dart';

import 'chat_view_model_test.mocks.dart';

@GenerateMocks([ChatRepository, BabyRepository])
void main() {
  late MockChatRepository repo;
  late MockBabyRepository babyRepo;
  late ChatViewModel vm;

  const babyId = 'baby-1';
  final now = DateTime.utc(2026, 7, 6, 10);

  ChatMessage message(String id, ChatRole role, String content) => ChatMessage(
    id: id,
    conversationId: 'c1',
    role: role,
    content: content,
    createdAt: now,
  );

  setUpAll(() {
    provideDummy<Result<List<ChatMessage>>>(Result.ok(const <ChatMessage>[]));
    provideDummy<Result<Baby>>(
      Result.error(const AppException(ErrorCode.notFound, 'x')),
    );
    provideDummy<Stream<ChatStreamEvent>>(const Stream.empty());
  });

  setUp(() {
    ChatViewModel.resetColdStartForTest();
    repo = MockChatRepository();
    babyRepo = MockBabyRepository();
    when(repo.activeConversationId(any)).thenReturn(null);
    when(repo.clearActiveConversation(any)).thenAnswer((_) async {});
    when(repo.setActiveConversationId(any, any)).thenAnswer((_) async {});
    when(
      babyRepo.getBaby(any),
    ).thenAnswer((_) async => Result.ok(Baby(id: babyId, name: '물결', gender: Gender.female)));
    vm = ChatViewModel(
      chatRepository: repo,
      babyRepository: babyRepo,
      now: () => now,
    );
  });

  group('enterTab', () {
    test('P-AC-1: 콜드 스타트 첫 진입은 빈 새 세션 + 환영, 저장 호출 없음', () async {
      await vm.enterTab(babyId);

      expect(vm.showWelcome, isTrue);
      expect(vm.messages, isEmpty);
      expect(vm.activeConversationId, isNull);
      verifyNever(repo.getMessages(any));
      verifyNever(
        repo.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      );
    });

    test('환영 문구에 아기 이름이 채워진다', () async {
      await vm.enterTab(babyId);
      await Future<void>.delayed(Duration.zero);
      expect(vm.welcomeMessage, contains('물결'));
    });

    test('콜드 스타트 이후, 활성 포인터가 있으면 그 세션을 로드한다', () async {
      ChatViewModel.resetColdStartForTest();
      // 첫 진입(콜드 스타트) 소비
      await vm.enterTab('baby-cold');
      // 다른 아기로 전환: 포인터 존재 → 로드
      when(repo.activeConversationId('baby-2')).thenReturn('c-2');
      when(repo.getMessages('c-2')).thenAnswer(
        (_) async => Result.ok([message('m1', ChatRole.user, '이전 질문')]),
      );

      await vm.enterTab('baby-2');

      expect(vm.activeConversationId, 'c-2');
      expect(vm.messages.single.content, '이전 질문');
      expect(vm.showWelcome, isFalse);
    });

    test('P-AC-10: 같은 아기 재진입은 재초기화하지 않는다(중복 가드)', () async {
      await vm.enterTab(babyId);
      clearInteractions(repo);
      await vm.enterTab(babyId);
      verifyNever(repo.activeConversationId(any));
    });
  });

  group('send', () {
    test('P-AC-3: optimistic 추가 → Delta 누적 → Done 확정', () async {
      await vm.enterTab(babyId);
      when(
        repo.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          ChatStreamMeta('c-new'),
          ChatStreamDelta('안'),
          ChatStreamDelta('녕'),
          ChatStreamDone(),
        ]),
      );

      await vm.send('새벽에 깨요');

      expect(vm.isStreaming, isFalse);
      expect(vm.streamingText, isEmpty);
      expect(vm.showWelcome, isFalse);
      expect(vm.activeConversationId, 'c-new');
      final roles = vm.messages.map((m) => m.role).toList();
      expect(roles, [ChatRole.user, ChatRole.assistant]);
      expect(vm.messages.last.content, '안녕');
      verify(repo.setActiveConversationId(babyId, 'c-new')).called(1);
    });

    test('P-AC-4: 스트리밍 중 추가 send 는 무시된다', () async {
      await vm.enterTab(babyId);
      final controller = StreamController<ChatStreamEvent>();
      when(
        repo.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      ).thenAnswer((_) => controller.stream);

      final first = vm.send('첫 질문');
      await Future<void>.delayed(Duration.zero);
      expect(vm.isStreaming, isTrue);

      await vm.send('둘째 질문'); // 무시되어야 함

      expect(
        vm.messages.where((m) => m.role == ChatRole.user).length,
        1,
      );
      verify(
        repo.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      ).called(1);

      controller.add(const ChatStreamDone());
      await controller.close();
      await first;
      expect(vm.isStreaming, isFalse);
    });

    test('P-AC-2: 공백만 입력은 전송하지 않는다', () async {
      await vm.enterTab(babyId);
      await vm.send('   ');
      expect(vm.messages, isEmpty);
      verifyNever(
        repo.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      );
    });
  });

  group('retry', () {
    test('P-AC-5: Err → 에러 버블 부착, retry 는 같은 본문을 재전송', () async {
      await vm.enterTab(babyId);
      when(
        repo.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          ChatStreamMeta('c-new'),
          ChatStreamDelta('부분'),
          ChatStreamError(AppException(ErrorCode.networkError, 'dropped')),
        ]),
      );

      await vm.send('질문');
      expect(vm.isStreaming, isFalse);
      final failedId = vm.errorMessageId;
      expect(failedId, isNotNull);

      // 재시도 성공 스트림으로 교체
      when(
        repo.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          ChatStreamDelta('답변'),
          ChatStreamDone(),
        ]),
      );

      await vm.retry(failedId!);

      expect(vm.errorMessageId, isNull);
      expect(
        vm.messages.any(
          (m) => m.role == ChatRole.assistant && m.content == '답변',
        ),
        isTrue,
      );
      verify(
        repo.sendMessage(
          babyId: anyNamed('babyId'),
          conversationId: anyNamed('conversationId'),
          text: anyNamed('text'),
          localDate: anyNamed('localDate'),
        ),
      ).called(2);
    });
  });

  group('openConversation', () {
    test('P-AC-9: 선택 대화를 활성으로 로드하고 포인터를 갱신한다', () async {
      await vm.enterTab(babyId);
      when(repo.getMessages('c-old')).thenAnswer(
        (_) async => Result.ok([
          message('m1', ChatRole.user, '지난 질문'),
          message('m2', ChatRole.assistant, '지난 답변'),
        ]),
      );

      await vm.openConversation('c-old');

      expect(vm.activeConversationId, 'c-old');
      expect(vm.messages.length, 2);
      expect(vm.showWelcome, isFalse);
      expect(vm.state, ActionState.success);
      verify(repo.setActiveConversationId(babyId, 'c-old')).called(1);
    });
  });
}
