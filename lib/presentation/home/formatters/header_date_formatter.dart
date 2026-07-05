import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/presentation/home/formatters/date_label_formatter.dart';

/// 기록 리스트의 날짜 헤더 문자열 (spec §3.4).
///
/// 형식: `M.D 요일 (D+N)` — 라벨이 없으면 `M.D 요일`.
/// 예: `3.2 월요일 (D+123)`.
String formatHeaderDate(DateTime date, Baby? baby) {
  final local = date.toLocal();
  final weekday = _weekdayKo(local.weekday);
  final base = '${local.month}.${local.day} $weekday';

  if (baby == null) return base;
  final label = formatDateLabel(baby, date);
  if (label == null) return base;
  return '$base ($label)';
}

String _weekdayKo(int weekday) {
  const names = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
  // DateTime.weekday: 1 = 월 ... 7 = 일.
  return names[(weekday - 1) % 7];
}
