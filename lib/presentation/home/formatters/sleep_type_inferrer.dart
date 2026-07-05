import 'package:yuktoe/constants/enum/sleep_type.dart';

/// Complete 시점의 **디바이스 로컬 시각** 으로 수면 종류를 추론한다 (spec §6.4).
///
/// - `22:00`–`05:59` → `night`.
/// - 그 외 → `nap`.
SleepType inferSleepType(DateTime at) {
  final hour = at.toLocal().hour;
  final isNight = hour >= 22 || hour < 6;
  return isNight ? SleepType.night : SleepType.nap;
}
