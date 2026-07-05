import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/domain/models/analytics/reference_range.dart';
import 'package:yuktoe/presentation/analytics/view_models/metric_card_data.dart';
import 'package:yuktoe/presentation/analytics/view_models/sleep_card_view_model.dart';

void main() {
  late SleepCardViewModel vm;
  const range = ReferenceRange(min: 720, max: 960);

  setUp(() => vm = SleepCardViewModel());

  test('값을 "N시간 M분" 으로 포맷한다', () {
    vm.bind(const MetricComparison(value: 810));
    expect(vm.card.valueText, '13시간 30분');
  });

  test('AC-P5: below → "권장보다 짧음"(tone below)', () {
    vm.bind(const MetricComparison(
      value: 600,
      reference: range,
      position: ComparisonPosition.below,
    ));
    expect(vm.card.badge,
        const MetricBadgeData(tone: ComparisonTone.below, label: '권장보다 짧음'));
  });

  test('AC-P5: within → "적정"(tone within)', () {
    vm.bind(const MetricComparison(
      value: 810,
      reference: range,
      position: ComparisonPosition.within,
    ));
    expect(vm.card.badge,
        const MetricBadgeData(tone: ComparisonTone.within, label: '적정'));
  });

  test('AC-P5: above → "권장보다 김"(tone above)', () {
    vm.bind(const MetricComparison(
      value: 1000,
      reference: range,
      position: ComparisonPosition.above,
    ));
    expect(vm.card.badge,
        const MetricBadgeData(tone: ComparisonTone.above, label: '권장보다 김'));
  });

  test('AC-P5: 비교 없으면(reference null) 배지 없음', () {
    vm.bind(const MetricComparison(value: 810));
    expect(vm.card.badge, isNull);
  });
}
