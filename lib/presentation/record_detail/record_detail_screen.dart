import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_list_view_model.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_ui_state.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_view_model.dart';
import 'package:yuktoe/presentation/record_detail/widgets/delete_record_button.dart';
import 'package:yuktoe/presentation/record_detail/widgets/memo/memo_section.dart';
import 'package:yuktoe/presentation/record_detail/widgets/record_detail_app_bar.dart';
import 'package:yuktoe/presentation/record_detail/widgets/record_detail_header_card.dart';
import 'package:yuktoe/presentation/record_detail/widgets/record_type_detail_view.dart';
import 'package:yuktoe/theme/record_type_palette.dart';

class RecordDetailScreen extends StatelessWidget {
  final CareRecord record;

  const RecordDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final recordRepo = context.read<RecordRepository>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RecordDetailViewModel(
            recordRepository: recordRepo,
            initialRecord: record,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoListViewModel(
            recordRepository: recordRepo,
            recordId: record.id,
          )..refresh(),
        ),
      ],
      child: const _RecordDetailView(),
    );
  }
}

class _RecordDetailView extends StatelessWidget {
  const _RecordDetailView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecordDetailViewModel>();
    final state = vm.state;
    final record = vm.record;

    // Failure 발생 시 snackbar 후 idle 복귀.
    if (state is RecordDetailFailure) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message)),
        );
        vm.clearError();
      });
    }

    // 삭제 완료 시 pop.
    if (state is RecordDetailDeleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.maybePop(context);
      });
    }

    return PopScope(
      canPop: !vm.hasPendingChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('저장하지 않은 변경사항이 있습니다'),
            content: const Text('변경사항을 버리고 나갈까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('나가기',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          vm.discardDraft();
          Navigator.maybePop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8FB),
        appBar: RecordDetailAppBar(title: record.detail.style.title),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RecordDetailHeaderCard(
                      detail: record.detail,
                      date: vm.displayedDetail.occurredAt,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: RecordTypeDetailView(
                        detail: vm.displayedDetail,
                      ),
                    ),
                  ],
                ),
              ),
              const MemoSection(),
              const DeleteRecordButton(),
            ],
          ),
        ),
      ),
    );
  }
}
