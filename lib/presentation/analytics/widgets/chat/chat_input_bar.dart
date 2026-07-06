import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_input_controller.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_view_model.dart';
import 'package:yuktoe/presentation/analytics/widgets/chat/suggested_question_chip.dart';

/// 입력창 + 전송(스트리밍 중 잠금) + 추천 새로고침. 전송 잠금은 [ChatViewModel] 의
/// `isStreaming` 과 입력 유효성(`canSubmit`)을 합성해 결정한다(spec FR-003·FR-005).
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatInputController>();
    final isStreaming = context.select<ChatViewModel, bool>(
      (vm) => vm.isStreaming,
    );
    final canSend = controller.canSubmit && !isStreaming;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SuggestedQuestionChip()),
              IconButton(
                tooltip: '다른 질문 추천',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: context.read<ChatInputController>().cycleSuggestion,
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller.textController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: '무엇이든 물어보세요...',
                    counterText: '${controller.remaining}',
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
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Material(
                  shape: const CircleBorder(),
                  color: canSend ? scheme.primary : const Color(0xFFD9D9D9),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: canSend ? () => _send(context, controller) : null,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.send,
                        color: scheme.onPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _send(
    BuildContext context,
    ChatInputController controller,
  ) async {
    final text = controller.text;
    controller.clear();
    await context.read<ChatViewModel>().send(text);
  }
}
