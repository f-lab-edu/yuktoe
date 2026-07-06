import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_input_controller.dart';

/// 추천 질문 노출/탭. 현재 추천 1개를 칩으로 보여주고, 탭하면 입력창을 채운다
/// (spec FR-012). 풀이 비면 아무것도 그리지 않는다(추천 비노출, spec FR-013).
class SuggestedQuestionChip extends StatelessWidget {
  const SuggestedQuestionChip({super.key});

  @override
  Widget build(BuildContext context) {
    final suggestion = context.select<ChatInputController, String?>(
      (c) => c.currentSuggestion,
    );
    if (suggestion == null) return const SizedBox.shrink();

    return ActionChip(
      avatar: const Icon(Icons.lightbulb_outline, size: 16),
      label: Text(
        suggestion,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () => context.read<ChatInputController>().applySuggestion(),
    );
  }
}
