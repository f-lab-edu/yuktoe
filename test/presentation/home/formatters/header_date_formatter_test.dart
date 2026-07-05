import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/presentation/home/formatters/header_date_formatter.dart';

void main() {
  group('formatHeaderDate', () {
    test('baby 가 없으면 M.D 요일 만', () {
      // 2026-03-02 는 월요일 (로컬 DateTime).
      expect(formatHeaderDate(DateTime(2026, 3, 2), null), '3.2 월요일');
    });

    test('birthDate 있으면 (D+N) 붙음', () {
      final baby = Baby(
        id: 'b',
        name: 'Liam',
        birthDate: DateTime.utc(2026, 3, 1),
        gender: Gender.male,
      );
      // 2026-03-02 로컬 → 표시. 라벨은 birthDate 기준 D+N.
      final result = formatHeaderDate(DateTime.utc(2026, 3, 2), baby);
      expect(result, startsWith('3.2 월요일 (D+'));
      expect(result, endsWith(')'));
    });

    test('요일 매핑 - 일요일', () {
      // 2026-03-08 은 일요일.
      expect(formatHeaderDate(DateTime(2026, 3, 8), null), '3.8 일요일');
    });
  });
}
