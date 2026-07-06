import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/analytics/analytics_summary.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';

import 'analytics_service.dart';

/// Supabase 요약 엔드포인트 호출 + 응답을 `AnalyticsSummary` 로 매핑한다.
///
/// NOTE: 요약 계산(평균·교정연령·권장치 조인, spec FR-010~FR-022)은 백엔드 책임이며,
/// 아래 RPC(`get_analytics_summary`)와 응답 스키마는 **가정한 계약**이다. 백엔드
/// 엔드포인트가 준비되면 함수명·파라미터·키를 실제 계약에 맞춰 조정한다.
///
/// 가정한 응답 스키마(각 지표 슬롯은 null 이거나 아래 형태):
/// ```json
/// {
///   "feeding_volume": {"value": 750.0, "reference": {"min": 600, "max": 900}, "position": "within"},
///   "pee_count": {"value": 5.2, "reference": null, "position": null},
///   "poop_count": null,
///   "awake_duration": {"value": 80.0, "reference": null, "position": null},
///   "total_sleep_duration": {"value": 810.0, "reference": {"min": 720, "max": 960}, "position": "within"}
/// }
/// ```
class SupabaseAnalyticsService implements AnalyticsService {
  final SupabaseClient _client;

  SupabaseAnalyticsService({required SupabaseClient client}) : _client = client;

  @override
  Future<Result<AnalyticsSummary>> getSummary(
    String babyId,
    DateTime localDate,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Result.error(
        const AppException(ErrorCode.unauthorized, 'Not signed in'),
      );
    }

    try {
      final data = await _client.rpc(
        'get_analytics_summary',
        params: {
          'p_baby_id': babyId,
          'p_local_date': _localDateString(localDate),
        },
      );

      if (data == null) {
        return Result.error(
          AppException(ErrorCode.notFound, 'Summary not found: $babyId'),
        );
      }

      final map = Map<String, dynamic>.from(data as Map);
      return Result.ok(_mapSummary(babyId, map));
    } catch (e) {
      return Result.error(_classify(e, 'Failed to get analytics summary'));
    }
  }

  AnalyticsSummary _mapSummary(String babyId, Map<String, dynamic> data) {
    return AnalyticsSummary(
      babyId: babyId,
      feedingVolume: _mapMetric(data['feeding_volume']),
      peeCount: _mapMetric(data['pee_count']),
      poopCount: _mapMetric(data['poop_count']),
      awakeDuration: _mapMetric(data['awake_duration']),
      totalSleepDuration: _mapMetric(data['total_sleep_duration']),
    );
  }

  /// 슬롯 하나를 매핑한다. `null` 이면 absent(그대로 `null`).
  MetricComparison? _mapMetric(Object? slot) {
    if (slot == null) return null;
    return MetricComparison.fromJson(Map<String, dynamic>.from(slot as Map));
  }

  /// 로컬 날짜를 `YYYY-MM-DD` 로 포맷한다(타임존 정보 없이 날짜 경계만 전달).
  String _localDateString(DateTime localDate) {
    final y = localDate.year.toString().padLeft(4, '0');
    final m = localDate.month.toString().padLeft(2, '0');
    final d = localDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  AppException _classify(Object e, String message) {
    if (e is AuthException) {
      return AppException(ErrorCode.unauthorized, message, cause: e);
    }
    if (e is PostgrestException || e is SocketException) {
      return AppException(ErrorCode.networkError, message, cause: e);
    }
    if (e is FormatException || e is TypeError || e is ArgumentError) {
      return AppException(ErrorCode.parseFailed, message, cause: e);
    }
    return AppException(ErrorCode.unknown, message, cause: e);
  }
}
