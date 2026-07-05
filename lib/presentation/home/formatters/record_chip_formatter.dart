import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';

/// 기록 리스트 항목 row 의 메타 chip 라벨을 만든다 (spec §3.5).
///
/// `null` 을 반환하면 chip 을 그리지 않는다. chip 의 색은 위젯이
/// `record.type` 으로 팔레트에서 결정하므로, 본 formatter 는 라벨만 책임진다.
String? formatRecordChip(CareRecord record) {
  final detail = record.detail;
  return switch (detail) {
    BreastDetail() => _breastChip(detail),
    SleepDetail() => _durationChip(detail.duration),
    FormulaDetail() => '${detail.amountMl}ml',
    PumpingFeedDetail() => '${detail.amountMl}ml',
    PumpingDetail() => _pumpingChip(detail),
    BabyFoodDetail() =>
      detail.name.trim().isNotEmpty ? detail.name.trim() : '${detail.amountMl}ml',
    SnackDetail() => detail.name.trim().isNotEmpty ? detail.name.trim() : null,
    WaterDetail() => '${detail.amountMl}ml',
    DiaperDetail() => _diaperChip(detail),
  };
}

String? _breastChip(BreastDetail d) {
  final l = d.leftMinutes;
  final r = d.rightMinutes;
  if (l == null && r == null) return null;
  if (l != null && r == null) return '왼쪽';
  if (r != null && l == null) return '오른쪽';
  // 둘 다 non-null: 더 긴 쪽, 동률이면 양쪽.
  if (l! > r!) return '왼쪽';
  if (r > l) return '오른쪽';
  return '양쪽';
}

String? _pumpingChip(PumpingDetail d) {
  if (d.leftAmountMl == null && d.rightAmountMl == null) return null;
  final sum = (d.leftAmountMl ?? 0) + (d.rightAmountMl ?? 0);
  return '${sum}ml';
}

String _diaperChip(DiaperDetail d) {
  return switch (d.diaperType) {
    DiaperType.pee => '소변',
    DiaperType.poop => '대변',
    DiaperType.mixed => '혼합',
  };
}

/// 지속 시간(=endedAt−startedAt)을 `N시간 N분` / `N시간` / `N분` 으로.
String _durationChip(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}
