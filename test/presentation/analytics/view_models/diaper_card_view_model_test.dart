import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/presentation/analytics/view_models/diaper_card_view_model.dart';

void main() {
  late DiaperCardViewModel vm;

  setUp(() => vm = DiaperCardViewModel());

  test('AC-P3: 소변+대변 합산 타이틀 + "소변 n / 대변 m" 보조, 배지 없음', () {
    vm.bind(
      const MetricComparison(value: 5.2),
      const MetricComparison(value: 1.8),
    );
    expect(vm.card.hasValue, isTrue);
    expect(vm.card.valueText, '7.0 회');
    expect(vm.card.subtitle, '소변 5.2 / 대변 1.8');
    expect(vm.card.badge, isNull);
  });

  test('AC-P3: 한쪽만 absent 면 있는 쪽만 합산, 없는 쪽은 "데이터 없음" 표기', () {
    vm.bind(const MetricComparison(value: 5.2), null);
    expect(vm.card.hasValue, isTrue);
    expect(vm.card.valueText, '5.2 회');
    expect(vm.card.subtitle, '소변 5.2 / 대변 데이터 없음');
  });

  test('AC-P3: 둘 다 absent → hasValue==false', () {
    vm.bind(null, null);
    expect(vm.card.hasValue, isFalse);
    expect(vm.card.valueText, isNull);
  });
}
