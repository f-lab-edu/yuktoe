/// 특정 월령 구간 × 특정 지표에 대한 권장치 범위(하한·상한).
///
/// 값 객체(constitution Principle II): 모든 필드 `final`, 자체 계산 없음.
/// 백엔드가 운영자 시드 권장치 테이블에서 조인해 채운다.
class ReferenceRange {
  /// 권장 범위 하한(포함).
  final double min;

  /// 권장 범위 상한(포함).
  final double max;

  const ReferenceRange({required this.min, required this.max})
      : assert(min <= max, 'min must be <= max');

  Map<String, dynamic> toJson() => {'min': min, 'max': max};

  /// 백엔드 응답 매핑. 불변식(`min <= max`)을 위반하는 응답은 `FormatException`
  /// 으로 던져 Service 가 `parseFailed` 로 환원한다(analytics_data.md AC-4).
  factory ReferenceRange.fromJson(Map<String, dynamic> json) {
    final min = (json['min'] as num).toDouble();
    final max = (json['max'] as num).toDouble();
    if (min > max) {
      throw FormatException('ReferenceRange min > max: min=$min, max=$max');
    }
    return ReferenceRange(min: min, max: max);
  }

  @override
  bool operator ==(Object other) =>
      other is ReferenceRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}
