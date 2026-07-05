import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/reference_range.dart';

/// 지표 하나에 대해 "내 아기 값"과 "그 값이 권장 범위 대비 어디인지"를 한 묶음으로
/// 표현하는 값 객체. 슬롯이 존재(non-null)하면 `value` 는 반드시 있고, 권장 범위
/// 비교(`reference`/`position`)는 가능할 때만 함께 채워진다.
///
/// 핵심 불변식: `reference != null ⟺ position != null`(둘은 항상 함께 존재하거나
/// 함께 없음, spec FR-016). 정성 라벨·차이 % 등 표시용 가공은 보유하지 않는다.
class MetricComparison {
  /// 윈도우 기준 산출된 평균값. non-null. 단위는 지표별(ml·분·횟수).
  /// 평균이므로 횟수 지표도 소수일 수 있다.
  final double value;

  /// 해당 월령 구간 × 이 지표의 권장 범위. 비교 불가 시 `null`.
  final ReferenceRange? reference;

  /// `value` 가 권장 범위 대비 어디인지. 비교 불가 시 `null`.
  final ComparisonPosition? position;

  const MetricComparison({required this.value, this.reference, this.position})
      : assert(
          (reference == null) == (position == null),
          'reference and position must both be present or both absent',
        );

  Map<String, dynamic> toJson() => {
        'value': value,
        'reference': reference?.toJson(),
        'position': position?.name,
      };

  /// 백엔드 응답 매핑. 불변식(`reference != null ⟺ position != null`)을 위반하거나
  /// 모르는 enum 값이면 예외를 던져 Service 가 `parseFailed` 로 환원한다
  /// (analytics_data.md AC-1 / spec FR-016).
  factory MetricComparison.fromJson(Map<String, dynamic> json) {
    final value = (json['value'] as num).toDouble();

    final referenceJson = json['reference'] as Map<String, dynamic>?;
    final positionName = json['position'] as String?;

    final reference =
        referenceJson == null ? null : ReferenceRange.fromJson(referenceJson);
    final position = positionName == null
        ? null
        : ComparisonPosition.values.byName(positionName);

    if ((reference == null) != (position == null)) {
      throw FormatException(
        'reference and position must both be present or both absent: '
        'reference=$reference, position=$position',
      );
    }

    return MetricComparison(
      value: value,
      reference: reference,
      position: position,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MetricComparison &&
      other.value == value &&
      other.reference == reference &&
      other.position == position;

  @override
  int get hashCode => Object.hash(value, reference, position);
}
