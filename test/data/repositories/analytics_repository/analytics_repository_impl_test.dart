import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/analytics_repository/analytics_repository_impl.dart';
import 'package:yuktoe/data/services/analytics_service/analytics_service.dart';
import 'package:yuktoe/domain/models/analytics/analytics_summary.dart';
import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/domain/models/analytics/reference_range.dart';

import 'analytics_repository_impl_test.mocks.dart';

@GenerateMocks([AnalyticsService])
void main() {
  late MockAnalyticsService mockService;
  late AnalyticsRepositoryImpl repository;

  final localDate = DateTime(2026, 7, 6);
  const babyId = 'baby-1';

  setUpAll(() {
    provideDummy<Result<AnalyticsSummary>>(
      Result.ok(const AnalyticsSummary(babyId: '')),
    );
  });

  setUp(() {
    mockService = MockAnalyticsService();
    repository = AnalyticsRepositoryImpl(mockService);
  });

  test('getSummary 성공 시 Service 결과를 그대로 전달한다', () async {
    const summary = AnalyticsSummary(
      babyId: babyId,
      feedingVolume: MetricComparison(
        value: 750,
        reference: ReferenceRange(min: 600, max: 900),
        position: ComparisonPosition.within,
      ),
    );
    when(mockService.getSummary(babyId, localDate))
        .thenAnswer((_) async => Result.ok(summary));

    final result = await repository.getSummary(babyId, localDate);

    expect(result, isA<Ok<AnalyticsSummary>>());
    expect((result as Ok<AnalyticsSummary>).value, same(summary));
    verify(mockService.getSummary(babyId, localDate)).called(1);
  });

  test('AC-18: 모든 지표 absent 인 요약도 성공으로 전달한다(에러 아님)', () async {
    const empty = AnalyticsSummary(babyId: babyId);
    when(mockService.getSummary(babyId, localDate))
        .thenAnswer((_) async => Result.ok(empty));

    final result = await repository.getSummary(babyId, localDate);

    expect(result, isA<Ok<AnalyticsSummary>>());
    final value = (result as Ok<AnalyticsSummary>).value;
    expect(value.feedingVolume, isNull);
    expect(value.peeCount, isNull);
    expect(value.poopCount, isNull);
    expect(value.awakeDuration, isNull);
    expect(value.totalSleepDuration, isNull);
  });

  test('AC-19: Service 오류(각 ErrorCode)를 그대로 전달한다', () async {
    for (final code in [
      ErrorCode.notFound,
      ErrorCode.unauthorized,
      ErrorCode.networkError,
      ErrorCode.parseFailed,
    ]) {
      when(mockService.getSummary(babyId, localDate)).thenAnswer(
        (_) async => Result.error(AppException(code, 'boom')),
      );

      final result = await repository.getSummary(babyId, localDate);

      expect(result, isA<Error<AnalyticsSummary>>());
      expect((result as Error<AnalyticsSummary>).error.code, code);
    }
  });
}
