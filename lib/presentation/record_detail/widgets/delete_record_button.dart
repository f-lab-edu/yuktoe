import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_ui_state.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_view_model.dart';

class DeleteRecordButton extends StatelessWidget {
  const DeleteRecordButton({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecordDetailViewModel>();
    final state = vm.state;
    final deleting =
        state is RecordDetailLoading && state.action == RecordDetailAction.delete;
    final otherLoading =
        state is RecordDetailLoading && state.action != RecordDetailAction.delete;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: deleting
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : TextButton(
                onPressed: otherLoading ? null : () => _confirm(context, vm),
                child: const Text(
                  '기록 삭제',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    RecordDetailViewModel vm,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록을 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await vm.deleteRecord();
    }
  }
}
