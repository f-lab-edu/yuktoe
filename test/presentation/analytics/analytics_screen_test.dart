import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/analytics_repository/analytics_repository.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/domain/models/analytics/analytics_summary.dart';
import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/domain/models/analytics/reference_range.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/baby/baby_list_item.dart';
import 'package:yuktoe/domain/models/chat/chat_conversation.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/domain/models/chat/chat_stream_event.dart';
import 'package:yuktoe/domain/models/chat/suggested_questions.dart';
import 'package:yuktoe/presentation/analytics/views/analytics_screen.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';

/// 채팅 영역이 화면에 함께 있으므로, 요약 위젯 테스트에서도 채팅 의존을 benign 하게
/// 채워 렌더가 성립하도록 한다(채팅 동작 자체는 chat 전용 테스트에서 검증).
class _FakeChatRepository implements ChatRepository {
  @override
  String? activeConversationId(String babyId) => null;

  @override
  Future<void> clearActiveConversation(String babyId) async {}

  @override
  Future<void> setActiveConversationId(String babyId, String conversationId) async {}

  @override
  Future<Result<List<ChatConversation>>> getConversations(
    String babyId, {
    String? cursor,
    int limit = 20,
  }) async => Result.ok(const []);

  @override
  Future<Result<List<ChatMessage>>> getMessages(
    String conversationId, {
    String? cursor,
    int limit = 50,
  }) async => Result.ok(const []);

  @override
  Stream<ChatStreamEvent> sendMessage({
    required String babyId,
    String? conversationId,
    required String text,
    required DateTime localDate,
  }) => const Stream.empty();

  @override
  Future<Result<SuggestedQuestions>> getSuggestions(
    String babyId,
    DateTime localDate,
  ) async => Result.error(const AppException(ErrorCode.parseFailed, 'none'));
}

class _FakeBabyRepository implements BabyRepository {
  @override
  Future<Result<List<BabyListItem>>> getMyBabies() async =>
      Result.ok(const []);

  @override
  Future<Result<Baby>> getBaby(String babyId) async =>
      Result.ok(Baby(id: babyId, name: '물결', gender: Gender.female));
}

/// presentation 스택 전체(화면 + 코디네이터 + 카드 VM + Provider 배선)를
/// fake repository 로 묶어 렌더까지 검증하는 위젯 레벨 통합 테스트.
class _FakeAnalyticsRepository implements AnalyticsRepository {
  Result<AnalyticsSummary> Function() responder;
  int callCount = 0;

  _FakeAnalyticsRepository(this.responder);

  @override
  Future<Result<AnalyticsSummary>> getSummary(
    String babyId,
    DateTime localDate,
  ) async {
    callCount++;
    return responder();
  }
}

const _fullSummary = AnalyticsSummary(
  babyId: 'baby-1',
  feedingVolume: MetricComparison(
    value: 750,
    reference: ReferenceRange(min: 600, max: 900),
    position: ComparisonPosition.within,
  ),
  peeCount: MetricComparison(value: 5.2),
  poopCount: MetricComparison(value: 1.8),
  awakeDuration: MetricComparison(value: 80),
  totalSleepDuration: MetricComparison(
    value: 810,
    reference: ReferenceRange(min: 720, max: 960),
    position: ComparisonPosition.below,
  ),
);

Future<CurrentBabyController> _controllerWithBaby() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = CurrentBabyController(AppLocalStorage(prefs));
  await controller.select('baby-1');
  return controller;
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required AnalyticsRepository repository,
  required CurrentBabyController controller,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CurrentBabyController>.value(value: controller),
        Provider<AnalyticsRepository>.value(value: repository),
        Provider<ChatRepository>.value(value: _FakeChatRepository()),
        Provider<BabyRepository>.value(value: _FakeBabyRepository()),
      ],
      child: const MaterialApp(home: AnalyticsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('성공: 4개 카드가 값·보조·배지와 함께 렌더된다', (tester) async {
    final controller = await _controllerWithBaby();
    final repo = _FakeAnalyticsRepository(() => Result.ok(_fullSummary));

    await _pumpScreen(tester, repository: repo, controller: controller);

    expect(find.text('750 ml'), findsOneWidget);
    expect(find.text('7.0 회'), findsOneWidget);
    expect(find.text('소변 5.2 / 대변 1.8'), findsOneWidget);
    expect(find.text('1시간 20분'), findsOneWidget); // 깨어있는 시간
    expect(find.text('13시간 30분'), findsOneWidget); // 총 수면
    expect(find.text('적정'), findsOneWidget); // 수유량 within 배지
    expect(find.text('권장보다 짧음'), findsOneWidget); // 총 수면 below 배지
    expect(repo.callCount, 1);
  });

  testWidgets('빈 데이터: 4개 카드 모두 "데이터 없음"(에러 아님)', (tester) async {
    final controller = await _controllerWithBaby();
    final repo = _FakeAnalyticsRepository(
      () => Result.ok(const AnalyticsSummary(babyId: 'baby-1')),
    );

    await _pumpScreen(tester, repository: repo, controller: controller);

    expect(find.text('데이터 없음'), findsNWidgets(4));
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('networkError: 에러 문구 + "다시 시도" 버튼', (tester) async {
    final controller = await _controllerWithBaby();
    final repo = _FakeAnalyticsRepository(
      () => Result.error(const AppException(ErrorCode.networkError, 'net')),
    );

    await _pumpScreen(tester, repository: repo, controller: controller);

    expect(find.text('네트워크 연결을 확인해주세요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    // 재시도 → 성공 응답으로 바꾸고 탭하면 카드가 렌더된다.
    repo.responder = () => Result.ok(_fullSummary);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('750 ml'), findsOneWidget);
  });
}
