import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/domain/models/analytics/reference_range.dart';
import 'package:yuktoe/presentation/analytics/view_models/feeding_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/metric_card_data.dart';

void main() {
  late FeedingCardViewModel vm;

  setUp(() => vm = FeedingCardViewModel());

  test('null 슬롯 → "데이터 없음"', () {
    vm.bind(null);
    expect(vm.card.hasValue, isFalse);
    expect(vm.card.valueText, isNull);
    expect(vm.card.badge, isNull);
  });

  test('값만 있고 비교 없으면 값만, 배지 없음', () {
    vm.bind(const MetricComparison(value: 750));
    expect(vm.card.hasValue, isTrue);
    expect(vm.card.valueText, '750 ml');
    expect(vm.card.badge, isNull);
  });

  test('within → "적정" 배지(tone within)', () {
    vm.bind(const MetricComparison(
      value: 750,
      reference: ReferenceRange(min: 600, max: 900),
      position: ComparisonPosition.within,
    ));
    expect(vm.card.valueText, '750 ml');
    expect(vm.card.badge, const MetricBadgeData(tone: ComparisonTone.within, label: '적정'));
  });

  test('below/above → 적음/많음 배지', () {
    vm.bind(const MetricComparison(
      value: 500,
      reference: ReferenceRange(min: 600, max: 900),
      position: ComparisonPosition.below,
    ));
    expect(vm.card.badge,
        const MetricBadgeData(tone: ComparisonTone.below, label: '권장보다 적음'));

    vm.bind(const MetricComparison(
      value: 1000,
      reference: ReferenceRange(min: 600, max: 900),
      position: ComparisonPosition.above,
    ));
    expect(vm.card.badge,
        const MetricBadgeData(tone: ComparisonTone.above, label: '권장보다 많음'));
  });

  test('소수 ml 는 반올림된다', () {
    vm.bind(const MetricComparison(value: 749.6));
    expect(vm.card.valueText, '750 ml');
  });
}
