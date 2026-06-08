import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_input_controller.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_list_view_model.dart';
import 'package:yuktoe/presentation/record_detail/widgets/memo/memo_input.dart';
import 'package:yuktoe/presentation/record_detail/widgets/memo/memo_list.dart';

class MemoSection extends StatelessWidget {
  const MemoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<MemoListViewModel>().memoList.length;

    return ChangeNotifierProvider(
      create: (_) => MemoInputController(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 18, color: Color(0xFF595959)),
                  const SizedBox(width: 8),
                  const Text(
                    '메모',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '($count)',
                    style: const TextStyle(color: Color(0xFF8C8C8C)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const MemoList(),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const MemoInput(),
          ],
        ),
      ),
    );
  }
}
