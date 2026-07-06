/// 비교 배지의 색/톤을 결정하는 표시 전용 enum. 도메인 `ComparisonPosition` 을
/// View 계층으로 옮긴 것으로, View 가 도메인 enum 을 import 하지 않도록 카드
/// ViewModel 이 변환한다.
enum ComparisonTone { below, within, above }

/// 권장 범위 비교 배지의 표시 데이터.
class MetricBadgeData {
  final ComparisonTone tone;
  final String label;

  const MetricBadgeData({required this.tone, required this.label});

  @override
  bool operator ==(Object other) =>
      other is MetricBadgeData && other.tone == tone && other.label == label;

  @override
  int get hashCode => Object.hash(tone, label);
}

/// 카드 1개의 표시 데이터. 카드 ViewModel 이 만들어 보유하고 카드 위젯이 읽는다.
/// 합산·라벨·포맷·"데이터 없음" 판정은 이미 카드 ViewModel 이 끝낸 상태로 들어오며,
/// 위젯은 분기 없이 그대로 그린다.
class MetricCardData {
  /// 카드 제목 (예: "평균 하루 수유량").
  final String title;

  /// false → 카드 안에서 "데이터 없음" 표시.
  final bool hasValue;

  /// 포맷된 대표 수치 (예: "750 ml", "13시간 30분"). `hasValue == false` 면 null.
  final String? valueText;

  /// 보조 설명 (기저귀: "소변 5.2 / 대변 1.8"). 없으면 null.
  final String? subtitle;

  /// 권장 범위 비교 배지. null → 배지 미표시(비교 불가 또는 깨어있는 시간/기저귀).
  final MetricBadgeData? badge;

  const MetricCardData({
    required this.title,
    required this.hasValue,
    this.valueText,
    this.subtitle,
    this.badge,
  });

  /// "데이터 없음" 카드.
  const MetricCardData.noData(this.title)
      : hasValue = false,
        valueText = null,
        subtitle = null,
        badge = null;

  @override
  bool operator ==(Object other) =>
      other is MetricCardData &&
      other.title == title &&
      other.hasValue == hasValue &&
      other.valueText == valueText &&
      other.subtitle == subtitle &&
      other.badge == badge;

  @override
  int get hashCode => Object.hash(title, hasValue, valueText, subtitle, badge);
}
