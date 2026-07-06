import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';

/// 현재 선택된 아기에 대해 현재 윈도우(오늘 제외 최대 7일) 기준으로 산출된
/// 핵심 지표들을 한 객체로 묶는다. ViewModel 이 받아 화면에 뿌리는 최상위 단위.
///
/// 5개 지표 슬롯은 각각 **독립적으로 `null`(absent)** 일 수 있다. `null` 은
/// "윈도우 안에 그 지표를 산출할 기록이 한 건도 없었다"는 뜻이며(spec FR-004·FR-010),
/// 모든 슬롯이 `null` 인 요약(기록 전혀 없음)도 정상적인 성공 결과다(spec FR-020).
///
/// 집합(aggregate) 객체이므로 직렬화를 스스로 소유하지 않는다 — 슬롯 조립·매핑은
/// data 레이어(`SupabaseAnalyticsService`)가 담당한다. 자체적으로 평균·비교를
/// 계산하지 않으며, 표시용 가공(기저귀 카드 소변+대변 합산 등)은 Presentation 책임.
class AnalyticsSummary {
  /// 이 요약이 어느 아기의 것인지(현재 선택된 아기 식별자).
  final String babyId;

  /// 평균 하루 수유량(분유+유축수유 ml).
  final MetricComparison? feedingVolume;

  /// 평균 하루 소변 기저귀 횟수.
  final MetricComparison? peeCount;

  /// 평균 하루 대변 기저귀 횟수.
  final MetricComparison? poopCount;

  /// 평균 1회 깨어있는 시간(분). 권장치 비교를 제공하지 않으므로
  /// `reference`/`position` 이 항상 null 이다(spec FR-019a).
  final MetricComparison? awakeDuration;

  /// 평균 하루 총 수면시간(분).
  final MetricComparison? totalSleepDuration;

  const AnalyticsSummary({
    required this.babyId,
    this.feedingVolume,
    this.peeCount,
    this.poopCount,
    this.awakeDuration,
    this.totalSleepDuration,
  });
}
