import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/presentation/analytics/view_models/metric_card_data.dart';

/// 카드 ViewModel 들이 공유하는 표시용 순수 가공 함수 모음.
/// (도메인 슬롯 → 포맷 문자열 / 배지). 상태 없음, 부수효과 없음.

/// ml 값을 정수로 반올림해 "750 ml" 로 포맷.
String formatMl(double value) => '${value.round()} ml';

/// 평균 횟수를 소수 1자리로 포맷 (예: "5.2", "7.0").
String formatCount(double value) => value.toStringAsFixed(1);

/// 분 단위 값을 "N시간 M분" 으로 포맷 (예: 810 → "13시간 30분", 80 → "1시간 20분",
/// 45 → "45분", 120 → "2시간").
String formatDurationMinutes(double minutes) {
  final total = minutes.round();
  final hours = total ~/ 60;
  final mins = total % 60;
  if (hours == 0) return '$mins분';
  if (mins == 0) return '$hours시간';
  return '$hours시간 $mins분';
}

/// 도메인 `ComparisonPosition` → 표시용 `ComparisonTone`.
ComparisonTone toneOf(ComparisonPosition position) => switch (position) {
      ComparisonPosition.below => ComparisonTone.below,
      ComparisonPosition.within => ComparisonTone.within,
      ComparisonPosition.above => ComparisonTone.above,
    };

/// 비교 배지를 만든다. `metric` 이 없거나 `position` 이 없으면(비교 불가) null.
/// [below]/[within]/[above] 는 지표 성격에 맞는 라벨(수량은 적음/많음, 지속시간은
/// 짧음/김 등)이며 카드 ViewModel 이 전달한다.
MetricBadgeData? buildBadge(
  MetricComparison? metric, {
  required String below,
  required String within,
  required String above,
}) {
  final position = metric?.position;
  if (position == null) return null;
  final label = switch (position) {
    ComparisonPosition.below => below,
    ComparisonPosition.within => within,
    ComparisonPosition.above => above,
  };
  return MetricBadgeData(tone: toneOf(position), label: label);
}
