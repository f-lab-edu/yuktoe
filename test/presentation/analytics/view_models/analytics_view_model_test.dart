import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/analytics_repository/analytics_repository.dart';
import 'package:yuktoe/domain/models/analytics/analytics_summary.dart';
import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/domain/models/analytics/reference_range.dart';
import 'package:yuktoe/presentation/analytics/view_models/analytics_view_model.dart';

import 'analytics_view_model_test.mocks.dart';

@GenerateMocks([AnalyticsRepository])
void main() {
  late MockAnalyticsRepository mockRepo;
  late AnalyticsViewModel vm;

  const babyId = 'baby-1';

  const fullSummary = AnalyticsSummary(
    babyId: babyId,
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
      position: ComparisonPosition.within,
    ),
  );

  setUpAll(() {
    provideDummy<Result<AnalyticsSummary>>(
      Result.ok(const AnalyticsSummary(babyId: '')),
    );
  });

  setUp(() {
    mockRepo = MockAnalyticsRepository();
    vm = AnalyticsViewModel(analyticsRepository: mockRepo);
  });

  test('AC-P1: 성공 시 state==success 이고 4개 카드에 슬롯이 분배된다', () async {
    when(mockRepo.getSummary(any, any))
        .thenAnswer((_) async => Result.ok(fullSummary));

    await vm.loadFor(babyId);

    expect(vm.state, ActionState.success);
    expect(vm.errorCode, isNull);
    expect(vm.feedingCard.card.valueText, '750 ml');
    expect(vm.diaperCard.card.valueText, '7.0 회');
    expect(vm.diaperCard.card.subtitle, '소변 5.2 / 대변 1.8');
    expect(vm.awakeCard.card.valueText, '1시간 20분');
    expect(vm.sleepCard.card.valueText, '13시간 30분');
  });

  test('AC-P2: 모든 지표 absent → success 이고 4개 카드 모두 hasValue==false', () async {
    when(mockRepo.getSummary(any, any))
        .thenAnswer((_) async => Result.ok(const AnalyticsSummary(babyId: babyId)));

    await vm.loadFor(babyId);

    expect(vm.state, ActionState.success);
    expect(vm.feedingCard.card.hasValue, isFalse);
    expect(vm.diaperCard.card.hasValue, isFalse);
    expect(vm.awakeCard.card.hasValue, isFalse);
    expect(vm.sleepCard.card.hasValue, isFalse);
  });

  test('AC-P6: Repository 오류 → state==error 이고 errorCode 가 그대로 노출된다', () async {
    for (final code in [
      ErrorCode.networkError,
      ErrorCode.unauthorized,
      ErrorCode.parseFailed,
    ]) {
      final vmLocal = AnalyticsViewModel(analyticsRepository: mockRepo);
      when(mockRepo.getSummary(any, any))
          .thenAnswer((_) async => Result.error(AppException(code, 'boom')));

      await vmLocal.loadFor(babyId);

      expect(vmLocal.state, ActionState.error);
      expect(vmLocal.errorCode, code);
    }
  });

  test('AC-P7: 같은 babyId 는 재조회하지 않고, 바뀐 babyId 는 재조회한다', () async {
    when(mockRepo.getSummary(any, any))
        .thenAnswer((_) async => Result.ok(fullSummary));

    await vm.loadFor(babyId);
    await vm.loadFor(babyId); // 중복 가드
    verify(mockRepo.getSummary(babyId, any)).called(1);

    await vm.loadFor('baby-2');
    verify(mockRepo.getSummary('baby-2', any)).called(1);
  });

  test('AC-P8: retry() 는 마지막 babyId 로 재조회한다', () async {
    when(mockRepo.getSummary(any, any))
        .thenAnswer((_) async => Result.error(
              const AppException(ErrorCode.networkError, 'net'),
            ));
    await vm.loadFor(babyId);
    expect(vm.state, ActionState.error);

    when(mockRepo.getSummary(any, any))
        .thenAnswer((_) async => Result.ok(fullSummary));
    await vm.retry();

    expect(vm.state, ActionState.success);
    verify(mockRepo.getSummary(babyId, any)).called(2);
  });

  test('babyId == null → idle 이고 조회하지 않는다', () async {
    await vm.loadFor(null);

    expect(vm.state, ActionState.idle);
    verifyNever(mockRepo.getSummary(any, any));
  });
}
