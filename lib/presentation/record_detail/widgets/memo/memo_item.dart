import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/core/auth/session_manager.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_list_view_model.dart';
import 'package:yuktoe/presentation/record_detail/widgets/modals/text_input_modal.dart';

class MemoItem extends StatelessWidget {
  final RecordMemo memo;

  const MemoItem({super.key, required this.memo});

  static final _timeFormat = DateFormat.jm('ko_KR');

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<SessionManager>().currentUserId;
    final canModify = currentUserId == memo.authorId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: memo.authorName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      memo.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${_timeFormat.format(memo.createdAt)}',
                      style: const TextStyle(
                        color: Color(0xFF8C8C8C),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(memo.content),
                ),
              ],
            ),
          ),
          if (canModify)
            IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF8C8C8C)),
              onPressed: () => _onMorePressed(context),
            ),
        ],
      ),
    );
  }

  Future<void> _onMorePressed(BuildContext context) async {
    final vm = context.read<MemoListViewModel>();
    final action = await showModalBottomSheet<_MemoAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('수정'),
              onTap: () => Navigator.pop(ctx, _MemoAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('삭제',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, _MemoAction.delete),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    switch (action) {
      case _MemoAction.edit:
        final newContent = await showTextInputModal(
          context,
          title: '메모 수정',
          initial: memo.content,
        );
        if (newContent != null) {
          await vm.updateMemo(memo.id, newContent);
        }
      case _MemoAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('메모를 삭제하시겠어요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '삭제',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        if (ok == true) {
          await vm.deleteMemo(memo.id);
        }
      case null:
        break;
    }
  }
}

enum _MemoAction { edit, delete }

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF7C4DFF),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
