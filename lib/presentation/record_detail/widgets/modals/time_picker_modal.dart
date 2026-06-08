import 'package:flutter/material.dart';

/// 시각 선택 모달. 확인 누르면 [DateTime] (날짜는 [initial] 의 것 유지) 반환.
/// 취소/dismiss 시 null.
Future<DateTime?> showTimePickerModal(
  BuildContext context, {
  required DateTime initial,
}) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (picked == null) return null;
  return DateTime(
    initial.year,
    initial.month,
    initial.day,
    picked.hour,
    picked.minute,
  );
}
