import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/editable_chip.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/labeled_field.dart';

/// "시간" 라벨 + 단일 시각 chip.
/// 특정 시각 타입 (Diaper, Formula, Pumping, PumpingFeed, BabyFood, Snack, Water) 에서 사용.
class SpecificTimeField extends StatelessWidget {
  final DateTime occurredAt;
  final ValueChanged<DateTime> onTap;

  const SpecificTimeField({
    super.key,
    required this.occurredAt,
    required this.onTap,
  });

  static final _timeFormat = DateFormat.jm('ko_KR');

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: '시간',
      child: EditableChip(
        text: _timeFormat.format(occurredAt),
        onTap: () => onTap(occurredAt),
      ),
    );
  }
}
