/// "방금 / N분 전 / N시간 N분 전 / N일 전" 표기 (spec §3.3).
///
/// `now - then` 의 절대값을 기준으로 한다.
String formatRelativeTime(DateTime then, DateTime now) {
  final diff = now.difference(then).abs();

  if (diff.inSeconds <= 60) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (minutes == 0) return '$hours시간 전';
    return '$hours시간 $minutes분 전';
  }
  return '${diff.inDays}일 전';
}
