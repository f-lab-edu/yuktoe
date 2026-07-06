import 'package:yuktoe/domain/models/analytics/reference_range.dart';

/// `value` 가 `ReferenceRange` 대비 어디에 있는지를 세 분류로 나타낸다.
/// 표시 계층이 "적음/적정/많음" 라벨·색상을 결정하는 입력이 된다.
enum ComparisonPosition {
  /// `value < reference.min` — 권장보다 적음/짧음.
  below,

  /// `reference.min <= value <= reference.max` — 권장 범위 안.
  within,

  /// `value > reference.max` — 권장보다 많음/김.
  above;

  /// `value` 가 `range` 대비 어디인지 분류한다.
  ///
  /// 경계값(`value == min` 또는 `value == max`)은 `within` 으로 판정한다
  /// (범위는 양 끝 포함, analytics_data.md AC-2·AC-3 / spec FR-016).
  static ComparisonPosition fromValue(double value, ReferenceRange range) {
    if (value < range.min) return ComparisonPosition.below;
    if (value > range.max) return ComparisonPosition.above;
    return ComparisonPosition.within;
  }
}
