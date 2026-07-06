import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/domain/models/chat/suggested_questions.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_input_controller.dart';

import 'chat_input_controller_test.mocks.dart';

@GenerateMocks([ChatRepository])
void main() {
  late MockChatRepository repo;
  late ChatInputController controller;

  const babyId = 'baby-1';
  final pool = SuggestedQuestions(const ['q1', 'q2', 'q3', 'q4', 'q5']);

  setUpAll(() {
    provideDummy<Result<SuggestedQuestions>>(Result.ok(pool));
  });

  setUp(() {
    repo = MockChatRepository();
    controller = ChatInputController(
      chatRepository: repo,
      now: () => DateTime.utc(2026, 7, 6),
    );
  });

  tearDown(() => controller.dispose());

  group('추천', () {
    test('P-AC-6: 로드 성공 시 첫 추천 노출, 순환, 채우기', () async {
      when(
        repo.getSuggestions(babyId, any),
      ).thenAnswer((_) async => Result.ok(pool));

      await controller.loadFor(babyId);
      expect(controller.currentSuggestion, 'q1');

      controller.cycleSuggestion();
      expect(controller.currentSuggestion, 'q2');

      controller.applySuggestion();
      expect(controller.text, 'q2');
    });

    test('P-AC-6: 순환은 풀 끝에서 처음으로 되돌아온다', () async {
      when(
        repo.getSuggestions(babyId, any),
      ).thenAnswer((_) async => Result.ok(pool));
      await controller.loadFor(babyId);

      for (var i = 0; i < 5; i++) {
        controller.cycleSuggestion();
      }
      expect(controller.currentSuggestion, 'q1');
    });

    test('P-AC-7: 추천 로드 실패 시 추천 비노출(채팅 정상)', () async {
      when(repo.getSuggestions(babyId, any)).thenAnswer(
        (_) async =>
            Result.error(const AppException(ErrorCode.parseFailed, 'not 5')),
      );

      await controller.loadFor(babyId);

      expect(controller.currentSuggestion, isNull);
      expect(controller.suggestions, isEmpty);
    });

    test('같은 아기 재로드는 추가 호출하지 않는다(중복 가드)', () async {
      when(
        repo.getSuggestions(babyId, any),
      ).thenAnswer((_) async => Result.ok(pool));

      await controller.loadFor(babyId);
      await controller.loadFor(babyId);

      verify(repo.getSuggestions(babyId, any)).called(1);
    });
  });

  group('입력', () {
    test('P-AC-2: 공백만이면 canSubmit=false, 유효 텍스트면 true', () {
      controller.textController.text = '   ';
      expect(controller.canSubmit, isFalse);
      controller.textController.text = '안녕';
      expect(controller.canSubmit, isTrue);
    });

    test('P-AC-12: 글자수 상한 초과분은 잘리고 remaining 이 안내된다', () {
      controller.textController.text = 'a' * (ChatInputController.maxLength + 50);
      expect(controller.text.length, ChatInputController.maxLength);
      expect(controller.remaining, 0);
    });

    test('clear 는 입력을 비운다', () {
      controller.textController.text = 'abc';
      controller.clear();
      expect(controller.text, isEmpty);
    });
  });
}
