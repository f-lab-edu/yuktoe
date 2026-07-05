import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/analytics_repository/analytics_repository.dart';
import 'package:yuktoe/domain/models/analytics/analytics_summary.dart';
import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/domain/models/analytics/reference_range.dart';
import 'package:yuktoe/presentation/analytics/views/analytics_screen.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';

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
