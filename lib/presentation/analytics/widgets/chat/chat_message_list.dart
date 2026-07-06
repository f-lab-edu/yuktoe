import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_view_model.dart';
import 'package:yuktoe/presentation/analytics/widgets/chat/chat_error_bubble.dart';
import 'package:yuktoe/presentation/analytics/widgets/chat/chat_message_bubble.dart';
import 'package:yuktoe/presentation/analytics/widgets/chat/chat_welcome_bubble.dart';

/// 메시지 리스트(스트리밍 표시 포함). 렌더 순서: (loading) 로딩 → 환영 버블 →
/// 확정 메시지 버블들 → 스트리밍 중이면 마지막에 streamingText 버블 →
/// errorMessageId 가 붙은 사용자 메시지 아래 에러 버블. 페이지 자체가 스크롤되므로
/// 이 위젯은 Column 으로 펼친다.
class ChatMessageList extends StatelessWidget {
  const ChatMessageList({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();

    if (vm.state == ActionState.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final children = <Widget>[];

    if (vm.showWelcome) {
      children.add(const ChatWelcomeBubble());
    }

    for (final message in vm.messages) {
      children.add(
        ChatMessageBubble(
          role: message.role,
          content: message.content,
          createdAt: message.createdAt,
        ),
      );
      if (message.id == vm.errorMessageId) {
        children.add(ChatErrorBubble(messageId: message.id));
      }
    }

    if (vm.isStreaming) {
      children.add(
        ChatMessageBubble(
          role: ChatRole.assistant,
          content: vm.streamingText.isEmpty ? '…' : vm.streamingText,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
