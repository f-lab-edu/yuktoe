import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/presentation/home/formatters/date_label_formatter.dart';

Baby _baby({DateTime? birth, DateTime? due}) => Baby(
  id: 'b',
  name: 'Liam',
  birthDate: birth,
  dueDate: due,
  gender: Gender.male,
);

void main() {
  // 날짜 차이는 UTC 자정 기준으로 구성하면 timezone 과 무관하게 일정하다.
  DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

  group('formatDateLabel', () {
    test('birthDate 만 있으면 D+N (출생 당일 = D+1)', () {
      final baby = _baby(birth: day(2026, 3, 1));
      expect(formatDateLabel(baby, day(2026, 3, 1)), 'D+1');
      expect(formatDateLabel(baby, day(2026, 3, 2)), 'D+2');
      expect(formatDateLabel(baby, day(2026, 7, 2)), 'D+124');
    });

    test('dueDate 만 있으면 D-N / D-Day / 지난 후 D+N', () {
      final baby = _baby(due: day(2026, 3, 10));
      expect(formatDateLabel(baby, day(2026, 3, 9)), 'D-1');
      expect(formatDateLabel(baby, day(2026, 3, 10)), 'D-Day');
      expect(formatDateLabel(baby, day(2026, 3, 11)), 'D+1');
    });

    test('birthDate 가 dueDate 보다 우선', () {
      final baby = _baby(birth: day(2026, 3, 1), due: day(2026, 3, 10));
      expect(formatDateLabel(baby, day(2026, 3, 1)), 'D+1');
    });

    test('둘 다 null 이면 라벨 없음', () {
      expect(formatDateLabel(_baby(), day(2026, 3, 1)), isNull);
    });
  });
}
