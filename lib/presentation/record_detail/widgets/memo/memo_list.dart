import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_list_ui_state.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_list_view_model.dart';
import 'package:yuktoe/presentation/record_detail/widgets/memo/memo_item.dart';

class MemoList extends StatelessWidget {
  const MemoList({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MemoListViewModel>();
    final memos = vm.memoList;

    if (memos.isEmpty && vm.state is MemoListIdle) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '아직 작성된 메모가 없습니다.',
            style: TextStyle(color: Color(0xFF8C8C8C)),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) {
          final metrics = n.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent * 0.8 &&
              vm.hasMore &&
              vm.state is! MemoListLoading) {
            vm.loadMore();
          }
        }
        return false;
      },
      child: Column(
        children: [
          for (var i = 0; i < memos.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
            MemoItem(memo: memos[i]),
          ],
          if (vm.state is MemoListLoading && memos.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
