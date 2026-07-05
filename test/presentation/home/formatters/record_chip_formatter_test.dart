import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/home/formatters/record_chip_formatter.dart';

CareRecord _record(RecordType type, RecordDetailData detail) => CareRecord(
  id: 'r',
  babyId: 'b',
  type: type,
  detail: detail,
  createdBy: 'u',
  createdAt: DateTime.utc(2026, 7, 5),
);

void main() {
  final start = DateTime.utc(2026, 7, 5, 1, 0);

  group('formatRecordChip - breast', () {
    BreastDetail breast(int? l, int? r) =>
        BreastDetail(startedAt: start, endedAt: start, leftMinutes: l, rightMinutes: r);

    test('왼쪽이 더 길면 왼쪽', () {
      expect(formatRecordChip(_record(RecordType.breast, breast(10, 5))), '왼쪽');
    });
    test('오른쪽이 더 길면 오른쪽', () {
      expect(formatRecordChip(_record(RecordType.breast, breast(5, 10))), '오른쪽');
    });
    test('동률이면 양쪽', () {
      expect(formatRecordChip(_record(RecordType.breast, breast(5, 5))), '양쪽');
    });
    test('한 쪽만 non-null 이면 그 쪽', () {
      expect(formatRecordChip(_record(RecordType.breast, breast(5, null))), '왼쪽');
      expect(formatRecordChip(_record(RecordType.breast, breast(null, 5))), '오른쪽');
    });
    test('둘 다 null 이면 chip 없음', () {
      expect(formatRecordChip(_record(RecordType.breast, breast(null, null))), isNull);
    });
  });

  test('sleep 은 지속시간', () {
    final detail = SleepDetail(
      startedAt: DateTime.utc(2026, 7, 5, 1, 0),
      endedAt: DateTime.utc(2026, 7, 5, 3, 30),
      sleepType: SleepType.nap,
    );
    expect(formatRecordChip(_record(RecordType.sleep, detail)), '2시간 30분');
  });

  test('formula / pumpingFeed / water 는 Nml', () {
    expect(
      formatRecordChip(_record(
          RecordType.formula, FormulaDetail(occurredAt: start, amountMl: 160))),
      '160ml',
    );
    expect(
      formatRecordChip(_record(RecordType.water,
          WaterDetail(occurredAt: start, amountMl: 50))),
      '50ml',
    );
  });

  group('pumping', () {
    test('합산 Nml', () {
      expect(
        formatRecordChip(_record(
            RecordType.pumping,
            PumpingDetail(
                occurredAt: start, leftAmountMl: 30, rightAmountMl: 40))),
        '70ml',
      );
    });
    test('둘 다 null 이면 chip 없음', () {
      expect(
        formatRecordChip(_record(RecordType.pumping,
            PumpingDetail(occurredAt: start))),
        isNull,
      );
    });
  });

  group('babyFood', () {
    test('이름 있으면 이름', () {
      expect(
        formatRecordChip(_record(
            RecordType.babyFood,
            BabyFoodDetail(occurredAt: start, name: '단호박', amountMl: 80))),
        '단호박',
      );
    });
    test('이름 비면 Nml', () {
      expect(
        formatRecordChip(_record(RecordType.babyFood,
            BabyFoodDetail(occurredAt: start, name: '', amountMl: 80))),
        '80ml',
      );
    });
  });

  group('snack', () {
    test('이름 있으면 이름', () {
      expect(
        formatRecordChip(_record(
            RecordType.snack, SnackDetail(occurredAt: start, name: '치즈'))),
        '치즈',
      );
    });
    test('이름 비면 chip 없음', () {
      expect(
        formatRecordChip(_record(
            RecordType.snack, SnackDetail(occurredAt: start, name: ''))),
        isNull,
      );
    });
  });

  test('diaper 는 소변/대변/혼합', () {
    expect(
      formatRecordChip(_record(RecordType.diaper,
          DiaperDetail(occurredAt: start, diaperType: DiaperType.pee))),
      '소변',
    );
    expect(
      formatRecordChip(_record(RecordType.diaper,
          DiaperDetail(occurredAt: start, diaperType: DiaperType.poop))),
      '대변',
    );
    expect(
      formatRecordChip(_record(RecordType.diaper,
          DiaperDetail(occurredAt: start, diaperType: DiaperType.mixed))),
      '혼합',
    );
  });
}
