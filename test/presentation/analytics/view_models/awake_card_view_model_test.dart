import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/domain/models/analytics/reference_range.dart';
import 'package:yuktoe/presentation/analytics/view_models/awake_card_view_model.dart';

void main() {
  late AwakeCardViewModel vm;

  setUp(() => vm = AwakeCardViewModel());

  test('값을 "N시간 M분" 으로 포맷한다', () {
    vm.bind(const MetricComparison(value: 80));
    expect(vm.card.hasValue, isTrue);
    expect(vm.card.valueText, '1시간 20분');
  });

  test('AC-P4: reference 가 있어도 비교 배지를 만들지 않는다', () {
    vm.bind(const MetricComparison(
      value: 80,
      reference: ReferenceRange(min: 60, max: 120),
      position: ComparisonPosition.within,
    ));
    expect(vm.card.badge, isNull);
  });

  test('null 슬롯 → "데이터 없음"', () {
    vm.bind(null);
    expect(vm.card.hasValue, isFalse);
  });
}
