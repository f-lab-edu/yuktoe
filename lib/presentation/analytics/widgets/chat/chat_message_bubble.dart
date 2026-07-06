import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yuktoe/domain/models/chat/chat_message.dart';

/// user/assistant 버블 + 시각(로컬). 순수 표시 위젯으로 ViewModel 을 직접 구독하지
/// 않고 부모가 값을 주입한다(테스트 용이). 시각은 로컬 타임존으로 표시(spec FR-006).
class ChatMessageBubble extends StatelessWidget {
  final ChatRole role;
  final String content;

  /// 확정 메시지의 생성 시각(UTC). 스트리밍 중 임시 버블은 `null`.
  final DateTime? createdAt;

  const ChatMessageBubble({
    super.key,
    required this.role,
    required this.content,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = role == ChatRole.user;
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser ? scheme.primary : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              content,
              style: TextStyle(
                color: isUser ? scheme.onPrimary : const Color(0xFF262626),
                height: 1.4,
              ),
            ),
          ),
          if (createdAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                DateFormat.Hm().format(createdAt!.toLocal()),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFBFBFBF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
