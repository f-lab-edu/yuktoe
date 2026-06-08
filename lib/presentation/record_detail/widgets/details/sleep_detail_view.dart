import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_view_model.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/editable_chip.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/labeled_field.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/time_range_field.dart';
import 'package:yuktoe/presentation/record_detail/widgets/modals/sleep_type_picker_modal.dart';
import 'package:yuktoe/presentation/record_detail/widgets/modals/time_picker_modal.dart';

class SleepDetailView extends StatelessWidget {
  final SleepDetail detail;

  const SleepDetailView({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<RecordDetailViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TimeRangeField(
          startedAt: detail.startedAt,
          endedAt: detail.endedAt,
          onStartedAtTap: (current) async {
            final picked = await showTimePickerModal(context, initial: current);
            if (picked != null) {
              vm.stageDetail(detail.copyWith(startedAt: picked));
            }
          },
          onEndedAtTap: (current) async {
            final picked = await showTimePickerModal(context, initial: current);
            if (picked != null) {
              vm.stageDetail(detail.copyWith(endedAt: picked));
            }
          },
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: '상세 내용',
          child: EditableChip(
            text: _sleepTypeLabel(detail.sleepType),
            onTap: () async {
              final picked = await showSleepTypePickerModal(
                context,
                initial: detail.sleepType,
              );
              if (picked != null) {
                vm.stageDetail(detail.copyWith(sleepType: picked));
              }
            },
          ),
        ),
      ],
    );
  }
}

String _sleepTypeLabel(SleepType type) => switch (type) {
      SleepType.nap => '낮잠',
      SleepType.night => '밤잠',
    };
