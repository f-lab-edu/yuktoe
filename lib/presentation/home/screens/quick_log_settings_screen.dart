import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/home/record_type_labels.dart';
import 'package:yuktoe/presentation/home/view_models/quick_log_buttons_view_model.dart';

/// 빠른 기록 버튼 수정 화면 (spec §5.7). 순서 변경 / 사용 안 함 토글.
/// 변경은 즉시 로컬 영속되며 별도 저장 버튼이 없다.
class QuickLogSettingsScreen extends StatelessWidget {
  const QuickLogSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuickLogButtonsViewModel>();
    final buttons = vm.buttons;
    final enabledCount = buttons.where((b) => b.enabled).length;

    return Scaffold(
      appBar: AppBar(title: const Text('빠른 기록 버튼 수정')),
      body: ReorderableListView(
        onReorder: vm.reorder,
        children: [
          for (final button in buttons)
            SwitchListTile(
              key: Key('quick_log_setting_${button.type.name}'),
              title: Text(button.type.shortLabel),
              value: button.enabled,
              // 마지막 1개는 끄지 못한다 (VM 이 무시하지만 UX 상 비활성 표시).
              onChanged: (button.enabled && enabledCount <= 1)
                  ? null
                  : (_) => vm.toggle(button.type),
              secondary: const Icon(Icons.drag_handle),
            ),
        ],
      ),
    );
  }
}
