/// 스탑워치 누적 초를 디지털 시계 형식으로 (spec §5.3.3).
///
/// - 1 시간 미만 → `MM:SS` (예: `00:01`, `59:59`).
/// - 1 시간 이상 → `HH:MM:SS` (예: `01:00:00`, `01:23:43`).
String formatTimerDuration(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;

  String two(int v) => v.toString().padLeft(2, '0');

  if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}
