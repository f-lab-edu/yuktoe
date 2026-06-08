import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_ui_state.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_view_model.dart';

class RecordDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const RecordDetailAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecordDetailViewModel>();
    final state = vm.state;
    final updating =
        state is RecordDetailLoading && state.action == RecordDetailAction.update;
    final otherLoading =
        state is RecordDetailLoading && state.action != RecordDetailAction.update;

    return AppBar(
      leading: const BackButton(),
      title: Text(title),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: updating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.check),
                    color: vm.hasPendingChanges
                        ? const Color(0xFF7C4DFF)
                        : Colors.grey,
                    onPressed:
                        vm.hasPendingChanges && !otherLoading
                            ? vm.commitChanges
                            : null,
                  ),
          ),
        ),
      ],
    );
  }
}
