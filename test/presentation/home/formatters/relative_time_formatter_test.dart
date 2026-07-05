import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/presentation/home/formatters/relative_time_formatter.dart';

void main() {
  final now = DateTime(2026, 7, 5, 12, 0, 0);

  group('formatRelativeTime', () {
    test('60초 이하는 방금', () {
      expect(formatRelativeTime(now.subtract(const Duration(seconds: 5)), now),
          '방금');
      expect(formatRelativeTime(now.subtract(const Duration(seconds: 60)), now),
          '방금');
    });

    test('60초 초과 ~ 60분 미만은 N분 전', () {
      expect(formatRelativeTime(now.subtract(const Duration(seconds: 61)), now),
          '1분 전');
      expect(formatRelativeTime(now.subtract(const Duration(minutes: 45)), now),
          '45분 전');
    });

    test('60분은 시간 표기로 넘어간다', () {
      expect(formatRelativeTime(now.subtract(const Duration(minutes: 60)), now),
          '1시간 전');
    });

    test('시간 + 분 (분이 0 이면 시간만)', () {
      expect(
        formatRelativeTime(
            now.subtract(const Duration(hours: 2, minutes: 15)), now),
        '2시간 15분 전',
      );
      expect(formatRelativeTime(now.subtract(const Duration(hours: 3)), now),
          '3시간 전');
    });

    test('24시간 이상은 N일 전', () {
      expect(formatRelativeTime(now.subtract(const Duration(hours: 24)), now),
          '1일 전');
      expect(formatRelativeTime(now.subtract(const Duration(days: 2)), now),
          '2일 전');
    });
  });
}
