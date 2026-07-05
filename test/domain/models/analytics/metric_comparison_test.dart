import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/domain/models/analytics/comparison_position.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/domain/models/analytics/reference_range.dart';

void main() {
  group('ReferenceRange', () {
    test('AC-4: min <= max 이면 정상 생성된다', () {
      const range = ReferenceRange(min: 600, max: 900);
      expect(range.min, 600);
      expect(range.max, 900);
    });

    test('min == max 인 범위도 허용된다', () {
      const range = ReferenceRange(min: 5, max: 5);
      expect(range.min, range.max);
    });

    test('AC-4: fromJson 에서 min > max 이면 FormatException', () {
      expect(
        () => ReferenceRange.fromJson({'min': 900, 'max': 600}),
        throwsFormatException,
      );
    });

    test('toJson/fromJson 라운드트립', () {
      const range = ReferenceRange(min: 600, max: 900);
      final restored = ReferenceRange.fromJson(range.toJson());
      expect(restored, range);
    });

    test('정수(num)도 double 로 매핑된다', () {
      final range = ReferenceRange.fromJson({'min': 600, 'max': 900});
      expect(range.min, isA<double>());
      expect(range.max, isA<double>());
    });
  });

  group('ComparisonPosition.fromValue', () {
    const range = ReferenceRange(min: 600, max: 900);

    test('AC-3: value < min → below', () {
      expect(ComparisonPosition.fromValue(599, range), ComparisonPosition.below);
    });

    test('AC-3: value > max → above', () {
      expect(ComparisonPosition.fromValue(901, range), ComparisonPosition.above);
    });

    test('AC-2: 경계값(value == min) → within', () {
      expect(
        ComparisonPosition.fromValue(600, range),
        ComparisonPosition.within,
      );
    });

    test('AC-2: 경계값(value == max) → within', () {
      expect(
        ComparisonPosition.fromValue(900, range),
        ComparisonPosition.within,
      );
    });

    test('범위 안 → within', () {
      expect(
        ComparisonPosition.fromValue(750, range),
        ComparisonPosition.within,
      );
    });
  });

  group('MetricComparison', () {
    test('value 만 있는(비교 없는) 슬롯은 정상이다', () {
      final metric = MetricComparison.fromJson({'value': 750.0});
      expect(metric.value, 750.0);
      expect(metric.reference, isNull);
      expect(metric.position, isNull);
    });

    test('value + reference + position 모두 있는 슬롯', () {
      final metric = MetricComparison.fromJson({
        'value': 750.0,
        'reference': {'min': 600, 'max': 900},
        'position': 'within',
      });
      expect(metric.value, 750.0);
      expect(metric.reference, const ReferenceRange(min: 600, max: 900));
      expect(metric.position, ComparisonPosition.within);
    });

    test('AC-1: reference 만 있고 position 이 없으면 FormatException', () {
      expect(
        () => MetricComparison.fromJson({
          'value': 750.0,
          'reference': {'min': 600, 'max': 900},
        }),
        throwsFormatException,
      );
    });

    test('AC-1: position 만 있고 reference 가 없으면 FormatException', () {
      expect(
        () => MetricComparison.fromJson({
          'value': 750.0,
          'position': 'within',
        }),
        throwsFormatException,
      );
    });

    test('모르는 position enum 값이면 예외를 던진다', () {
      expect(
        () => MetricComparison.fromJson({
          'value': 750.0,
          'reference': {'min': 600, 'max': 900},
          'position': 'unknown_bucket',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toJson/fromJson 라운드트립 (비교 있음)', () {
      const metric = MetricComparison(
        value: 750,
        reference: ReferenceRange(min: 600, max: 900),
        position: ComparisonPosition.within,
      );
      final restored = MetricComparison.fromJson(metric.toJson());
      expect(restored, metric);
    });

    test('toJson/fromJson 라운드트립 (비교 없음)', () {
      const metric = MetricComparison(value: 5.2);
      final restored = MetricComparison.fromJson(metric.toJson());
      expect(restored, metric);
    });
  });
}
