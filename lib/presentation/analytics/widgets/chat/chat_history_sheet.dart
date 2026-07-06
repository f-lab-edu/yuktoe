import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/domain/models/chat/chat_conversation.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_history_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_view_model.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';

/// 시계 버튼 → 지난 대화 바텀시트. 그 아기의 대화만 최신순으로 보여주고, 선택 시
/// [ChatViewModel.openConversation] 으로 위임한 뒤 시트를 닫는다(spec FR-022·FR-023).
Future<void> showChatHistorySheet(BuildContext context) {
  final chatRepository = context.read<ChatRepository>();
  final chatViewModel = context.read<ChatViewModel>();
  final babyId = context.read<CurrentBabyController>().selectedBabyId;
  if (babyId == null) return Future<void>.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              ChatHistoryViewModel(chatRepository: chatRepository)..load(babyId),
        ),
        ChangeNotifierProvider<ChatViewModel>.value(value: chatViewModel),
      ],
      child: const _ChatHistorySheet(),
    ),
  );
}

class _ChatHistorySheet extends StatelessWidget {
  const _ChatHistorySheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatHistoryViewModel>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                '지난 대화',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            _body(context, vm),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ChatHistoryViewModel vm) {
    switch (vm.state) {
      case ActionState.loading:
      case ActionState.idle:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        );
      case ActionState.error:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: Text('지난 대화를 불러오지 못했습니다.')),
        );
      case ActionState.success:
        if (vm.conversations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('아직 지난 대화가 없어요.')),
          );
        }
        return Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: vm.conversations.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF5F5F5)),
            itemBuilder: (context, index) =>
                _ConversationTile(conversation: vm.conversations[index]),
          ),
        );
    }
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final title = conversation.title ?? _fallbackTitle(conversation.createdAt);
    final lastAt = conversation.lastMessageAt ?? conversation.createdAt;

    return ListTile(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_formatDateTime(lastAt)),
      onTap: () {
        context.read<ChatViewModel>().openConversation(conversation.id);
        Navigator.of(context).pop();
      },
    );
  }

  String _fallbackTitle(DateTime createdAtUtc) =>
      '${_formatDateTime(createdAtUtc)} 대화';

  String _formatDateTime(DateTime utc) =>
      DateFormat('M월 d일 HH:mm').format(utc.toLocal());
}
