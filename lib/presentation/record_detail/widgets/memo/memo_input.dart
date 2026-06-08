import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_input_controller.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_list_view_model.dart';

class MemoInput extends StatelessWidget {
  const MemoInput({super.key});

  @override
  Widget build(BuildContext context) {
    final inputCtrl = context.watch<MemoInputController>();
    final vm = context.read<MemoListViewModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: inputCtrl.textController,
              decoration: InputDecoration(
                hintText: '메모를 입력하세요...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            shape: const CircleBorder(),
            color: inputCtrl.canSend
                ? const Color(0xFF7C4DFF)
                : const Color(0xFFD9D9D9),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: inputCtrl.canSend
                  ? () async {
                      final content = inputCtrl.textController.text.trim();
                      final ok = await vm.addMemo(content);
                      if (ok) inputCtrl.clear();
                    }
                  : null,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
