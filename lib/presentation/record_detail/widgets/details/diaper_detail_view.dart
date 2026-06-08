import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_view_model.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/editable_chip.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/labeled_field.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/specific_time_field.dart';
import 'package:yuktoe/presentation/record_detail/widgets/modals/diaper_type_picker_modal.dart';
import 'package:yuktoe/presentation/record_detail/widgets/modals/time_picker_modal.dart';

class DiaperDetailView extends StatelessWidget {
  final DiaperDetail detail;

  const DiaperDetailView({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<RecordDetailViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpecificTimeField(
          occurredAt: detail.occurredAt,
          onTap: (current) async {
            final picked = await showTimePickerModal(context, initial: current);
            if (picked != null) {
              vm.stageDetail(detail.copyWith(occurredAt: picked));
            }
          },
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: '상세 내용',
          child: EditableChip(
            text: _diaperTypeLabel(detail.diaperType),
            onTap: () async {
              final picked = await showDiaperTypePickerModal(
                context,
                initial: detail.diaperType,
              );
              if (picked != null) {
                vm.stageDetail(detail.copyWith(diaperType: picked));
              }
            },
          ),
        ),
      ],
    );
  }
}

String _diaperTypeLabel(DiaperType type) => switch (type) {
      DiaperType.pee => '소변',
      DiaperType.poop => '대변',
      DiaperType.mixed => '대소변',
    };
