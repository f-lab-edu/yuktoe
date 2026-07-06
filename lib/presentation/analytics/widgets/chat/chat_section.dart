import 'package:flutter/material.dart';
import 'package:yuktoe/presentation/analytics/widgets/chat/chat_history_sheet.dart';
import 'package:yuktoe/presentation/analytics/widgets/chat/chat_input_bar.dart';
import 'package:yuktoe/presentation/analytics/widgets/chat/chat_message_list.dart';

/// 채팅 영역 컨테이너(헤더 + 메시지 리스트 + 입력). 요약 카드 아래에 놓인다
/// (기존 memo_section 카드 셸 스타일 재사용). 자체 상태는 없다.
class ChatSection extends StatelessWidget {
  const ChatSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Color(0xFF7C4DFF),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI 상담',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '지난 대화',
                  icon: const Icon(Icons.history, size: 20),
                  onPressed: () => showChatHistorySheet(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const ChatMessageList(),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const ChatInputBar(),
        ],
      ),
    );
  }
}
