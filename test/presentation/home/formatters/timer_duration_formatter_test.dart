import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/presentation/home/formatters/timer_duration_formatter.dart';

void main() {
  group('formatTimerDuration', () {
    test('1시간 미만은 MM:SS', () {
      expect(formatTimerDuration(0), '00:00');
      expect(formatTimerDuration(1), '00:01');
      expect(formatTimerDuration(59), '00:59');
      expect(formatTimerDuration(60), '01:00');
      expect(formatTimerDuration(3599), '59:59');
    });

    test('1시간 이상은 HH:MM:SS', () {
      expect(formatTimerDuration(3600), '01:00:00');
      expect(formatTimerDuration(3601), '01:00:01');
      expect(formatTimerDuration(5023), '01:23:43');
    });

    test('음수는 0 으로 취급', () {
      expect(formatTimerDuration(-5), '00:00');
    });
  });
}
