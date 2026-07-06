import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_view_model.dart';

/// 전송 실패 안내 + "다시 시도" 버블. 재시도는 실패한 사용자 메시지를 같은 본문으로
/// 재전송한다(spec FR-042·Edge Case).
class ChatErrorBubble extends StatelessWidget {
  final String messageId;

  const ChatErrorBubble({super.key, required this.messageId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 18, color: scheme.error),
            const SizedBox(width: 8),
            Text(
              '답변을 받지 못했어요.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () =>
                  context.read<ChatViewModel>().retry(messageId),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
