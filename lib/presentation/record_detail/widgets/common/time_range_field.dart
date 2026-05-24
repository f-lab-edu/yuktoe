import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/editable_chip.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/labeled_field.dart';

/// "시간" 라벨 + [start chip] ~ [end chip] + 총 시간 텍스트.
/// 구간 타입(SleepDetail, BreastDetail) 에서 사용.
class TimeRangeField extends StatelessWidget {
  final DateTime startedAt;
  final DateTime endedAt;
  final ValueChanged<DateTime> onStartedAtTap;
  final ValueChanged<DateTime> onEndedAtTap;

  const TimeRangeField({
    super.key,
    required this.startedAt,
    required this.endedAt,
    required this.onStartedAtTap,
    required this.onEndedAtTap,
  });

  static final _timeFormat = DateFormat.jm('ko_KR');

  @override
  Widget build(BuildContext context) {
    final duration = endedAt.difference(startedAt);

    return LabeledField(
      label: '시간',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EditableChip(
                text: _timeFormat.format(startedAt),
                onTap: () => onStartedAtTap(startedAt),
              ),
              const SizedBox(width: 8),
              const Text('~', style: TextStyle(color: Color(0xFF8C8C8C))),
              const SizedBox(width: 8),
              EditableChip(
                text: _timeFormat.format(endedAt),
                onTap: () => onEndedAtTap(endedAt),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatDuration(duration),
            style: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 13),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours == 0) return '$minutes분';
    if (minutes == 0) return '$hours시간';
    return '$hours시간 $minutes분';
  }
}
