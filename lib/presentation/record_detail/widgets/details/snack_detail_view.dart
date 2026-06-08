import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_view_model.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/editable_chip.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/labeled_field.dart';
import 'package:yuktoe/presentation/record_detail/widgets/common/specific_time_field.dart';
import 'package:yuktoe/presentation/record_detail/widgets/modals/text_input_modal.dart';
import 'package:yuktoe/presentation/record_detail/widgets/modals/time_picker_modal.dart';

class SnackDetailView extends StatelessWidget {
  final SnackDetail detail;

  const SnackDetailView({super.key, required this.detail});

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
          label: '종류',
          child: EditableChip(
            text: detail.name,
            onTap: () async {
              final picked = await showTextInputModal(
                context,
                title: '간식 종류',
                initial: detail.name,
                hint: '예: 바나나',
              );
              if (picked != null) {
                vm.stageDetail(detail.copyWith(name: picked));
              }
            },
          ),
        ),
      ],
    );
  }
}
