import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/analytics_repository/analytics_repository.dart';
import 'package:yuktoe/data/services/analytics_service/analytics_service.dart';
import 'package:yuktoe/domain/models/analytics/analytics_summary.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsService _analyticsService;

  AnalyticsRepositoryImpl(this._analyticsService);

  @override
  Future<Result<AnalyticsSummary>> getSummary(
    String babyId,
    DateTime localDate,
  ) async {
    final result = await _analyticsService.getSummary(babyId, localDate);
    switch (result) {
      case Ok<AnalyticsSummary>():
        return Result.ok(result.value);
      case Error<AnalyticsSummary>():
        return Result.error(result.error);
    }
  }
}
