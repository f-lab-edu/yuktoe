import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_view_model.dart';

/// 환영 메시지(표시 전용, 미저장). 아기 이름이 채워진 고정 문구를 assistant 버블
/// 형태로 표시한다(spec FR-002). 저장·전송 없음.
class ChatWelcomeBubble extends StatelessWidget {
  const ChatWelcomeBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final message = context.select<ChatViewModel, String>(
      (vm) => vm.welcomeMessage,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF262626), height: 1.4),
        ),
      ),
    );
  }
}
