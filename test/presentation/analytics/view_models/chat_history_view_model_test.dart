import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/domain/models/chat/chat_conversation.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_history_view_model.dart';

import 'chat_history_view_model_test.mocks.dart';

@GenerateMocks([ChatRepository])
void main() {
  late MockChatRepository repo;
  late ChatHistoryViewModel vm;

  const babyId = 'baby-1';

  setUpAll(() {
    provideDummy<Result<List<ChatConversation>>>(
      Result.ok(const <ChatConversation>[]),
    );
  });

  setUp(() {
    repo = MockChatRepository();
    vm = ChatHistoryViewModel(chatRepository: repo);
  });

  test('P-AC-8: 로드 성공 시 그 아기의 대화 목록을 보유한다', () async {
    final conversations = [
      ChatConversation(
        id: 'c1',
        babyId: babyId,
        title: '새벽 수유',
        createdAt: DateTime.utc(2026, 7, 5),
        lastMessageAt: DateTime.utc(2026, 7, 5, 3),
      ),
    ];
    when(
      repo.getConversations(babyId),
    ).thenAnswer((_) async => Result.ok(conversations));

    await vm.load(babyId);

    expect(vm.state, ActionState.success);
    expect(vm.conversations, conversations);
    verify(repo.getConversations(babyId)).called(1);
  });

  test('빈 목록도 성공으로 처리한다', () async {
    when(
      repo.getConversations(babyId),
    ).thenAnswer((_) async => Result.ok(const <ChatConversation>[]));

    await vm.load(babyId);

    expect(vm.state, ActionState.success);
    expect(vm.conversations, isEmpty);
  });

  test('실패 시 error 상태와 errorCode 를 노출한다', () async {
    when(repo.getConversations(babyId)).thenAnswer(
      (_) async =>
          Result.error(const AppException(ErrorCode.networkError, 'boom')),
    );

    await vm.load(babyId);

    expect(vm.state, ActionState.error);
    expect(vm.errorCode, ErrorCode.networkError);
    expect(vm.conversations, isEmpty);
  });
}
