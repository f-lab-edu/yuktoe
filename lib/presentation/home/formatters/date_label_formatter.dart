import 'package:yuktoe/domain/models/baby/baby.dart';

/// D+N / D-N / D-Day / null 라벨을 만든다 (spec §3.2).
///
/// - `birthDate` 가 있으면 **D+N** (출생 후 경과 일수, 출생 당일 = `D+1`).
/// - `birthDate` 가 없고 `dueDate` 만 있으면 **D-N** (예정일까지 남은 일수,
///   당일 = `D-Day`, 지난 날은 `D+N` 으로 전환).
/// - 둘 다 없으면 `null` (라벨 미표시).
///
/// 일수는 **디바이스 로컬 자정** 기준. 저장값은 UTC 이므로 로컬로 변환 후
/// 날짜 부분만으로 차이를 계산한다.
String? formatDateLabel(Baby baby, DateTime now) {
  final birth = baby.birthDate;
  final due = baby.dueDate;

  if (birth != null) {
    final days = _dayDiff(birth, now);
    return 'D+${days + 1}';
  }
  if (due != null) {
    final diff = _dayDiff(now, due);
    if (diff > 0) return 'D-$diff';
    if (diff == 0) return 'D-Day';
    return 'D+${-diff}';
  }
  return null;
}

/// `from` 로컬 자정에서 `to` 로컬 자정까지의 일수 차이.
int _dayDiff(DateTime from, DateTime to) {
  final f = _localDate(from);
  final t = _localDate(to);
  return t.difference(f).inDays;
}

DateTime _localDate(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}
