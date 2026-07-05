import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';
import 'package:yuktoe/presentation/home/formatters/sleep_type_inferrer.dart';

void main() {
  // 로컬 시각 기준이므로 로컬 DateTime 으로 구성한다.
  group('inferSleepType', () {
    test('21:59 는 nap', () {
      expect(inferSleepType(DateTime(2026, 7, 5, 21, 59)), SleepType.nap);
    });

    test('22:00 은 night', () {
      expect(inferSleepType(DateTime(2026, 7, 5, 22, 0)), SleepType.night);
    });

    test('05:59 는 night', () {
      expect(inferSleepType(DateTime(2026, 7, 5, 5, 59)), SleepType.night);
    });

    test('06:00 은 nap', () {
      expect(inferSleepType(DateTime(2026, 7, 5, 6, 0)), SleepType.nap);
    });
  });
}
