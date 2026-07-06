import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';
import 'package:yuktoe/domain/models/chat/suggested_questions.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_input_controller.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_view_model.dart';
import 'package:yuktoe/presentation/analytics/widgets/chat/chat_section.dart';

import 'chat_section_test.mocks.dart';

@GenerateMocks([ChatRepository, BabyRepository])
void main() {
  late MockChatRepository repo;
  late MockBabyRepository babyRepo;

  const babyId = 'baby-1';

  setUpAll(() {
    provideDummy<Result<List<ChatMessage>>>(Result.ok(const <ChatMessage>[]));
    provideDummy<Result<Baby>>(
      Result.error(const AppException(ErrorCode.notFound, 'x')),
    );
    provideDummy<Result<SuggestedQuestions>>(
      Result.error(const AppException(ErrorCode.parseFailed, 'x')),
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
    when(babyRepo.getBaby(any)).thenAnswer(
      (_) async =>
          Result.ok(Baby(id: babyId, name: '물결', gender: Gender.female)),
    );
    when(repo.getSuggestions(any, any)).thenAnswer(
      (_) async =>
          Result.error(const AppException(ErrorCode.parseFailed, 'none')),
    );
  });

  Future<void> pumpSection(WidgetTester tester, ChatViewModel vm) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatViewModel>.value(value: vm),
          ChangeNotifierProvider<ChatInputController>(
            create: (_) => ChatInputController(chatRepository: repo),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ChatSection()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('통합: 진입 시 환영 버블이 보인다', (tester) async {
    final vm = ChatViewModel(chatRepository: repo, babyRepository: babyRepo);
    await vm.enterTab(babyId);

    await pumpSection(tester, vm);

    expect(find.textContaining('궁금한'), findsOneWidget);
  });

  testWidgets('통합: 질문 전송 → optimistic 사용자 버블 + 스트리밍 답변 확정', (tester) async {
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
        ChatStreamDelta('낮잠이 '),
        ChatStreamDelta('많아서예요.'),
        ChatStreamDone(),
      ]),
    );

    final vm = ChatViewModel(chatRepository: repo, babyRepository: babyRepo);
    await vm.enterTab(babyId);
    await pumpSection(tester, vm);

    await tester.enterText(find.byType(TextField), '새벽에 깨는 이유는?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('새벽에 깨는 이유는?'), findsOneWidget); // 사용자 버블
    expect(find.text('낮잠이 많아서예요.'), findsOneWidget); // 확정된 assistant 버블
    expect(vm.isStreaming, isFalse);
  });

  testWidgets('통합: 입력이 비면 전송 버튼이 비활성이다', (tester) async {
    final vm = ChatViewModel(chatRepository: repo, babyRepository: babyRepo);
    await vm.enterTab(babyId);
    await pumpSection(tester, vm);

    // 빈 입력에서 전송 탭 → sendMessage 호출되지 않는다.
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    verifyNever(
      repo.sendMessage(
        babyId: anyNamed('babyId'),
        conversationId: anyNamed('conversationId'),
        text: anyNamed('text'),
        localDate: anyNamed('localDate'),
      ),
    );
    expect(vm.messages, isEmpty);
  });
}
