import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/presentation/home/formatters/header_date_formatter.dart';
import 'package:yuktoe/presentation/home/formatters/record_chip_formatter.dart';
import 'package:yuktoe/presentation/home/home_record_style.dart';
import 'package:yuktoe/presentation/home/record_type_labels.dart';
import 'package:yuktoe/presentation/home/view_models/home_baby_info_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/record_timeline_view_model.dart';

/// 기록 리스트 `[E]` — 날짜 헤더 + 항목 + 무한 스크롤 (spec §5.8, plan §4.5).
class RecordTimelineSection extends StatelessWidget {
  final void Function(CareRecord record) onTapRecord;
  final Future<void> Function(CareRecord record) onSwipeDelete;

  const RecordTimelineSection({
    super.key,
    required this.onTapRecord,
    required this.onSwipeDelete,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecordTimelineViewModel>();
    final baby = context.watch<HomeBabyInfoViewModel>().baby;

    switch (vm.firstPageStatus) {
      case ActionState.idle:
      case ActionState.loading:
        return _skeleton();
      case ActionState.error:
        return _firstPageError(vm);
      case ActionState.success:
        if (vm.isEmpty) return _empty();
        return _list(context, vm, baby);
    }
  }

  Widget _skeleton() {
    return ListView(
      key: const Key('timeline_skeleton'),
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAEA),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty() {
    return const Center(
      key: Key('timeline_empty'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '아직 기록이 없어요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('버튼을 눌러 기록을 추가해보세요',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _firstPageError(RecordTimelineViewModel vm) {
    return Center(
      key: const Key('timeline_error'),
      child: ElevatedButton(
        onPressed: vm.loadFirstPage,
        child: const Text('다시 시도'),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    RecordTimelineViewModel vm,
    Baby? baby,
  ) {
    final items = vm.items;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        // 마지막에서 5 row(≈ 5*72px) 이내 진입 시 prefetch (spec §5.8).
        if (metrics.pixels >= metrics.maxScrollExtent - 360) {
          vm.loadNextPage();
        }
        return false;
      },
      child: ListView.builder(
        key: const Key('timeline_list'),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) return _footer(vm);

          final record = items[index];
          final showHeader = index == 0 ||
              !_sameLocalDate(
                items[index - 1].detail.occurredAt,
                record.detail.occurredAt,
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Text(
                    formatHeaderDate(record.detail.occurredAt, baby),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: HomeColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              _item(record),
            ],
          );
        },
      ),
    );
  }

  Widget _footer(RecordTimelineViewModel vm) {
    if (vm.nextPageStatus == ActionState.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (vm.nextPageStatus == ActionState.error) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('불러오기에 실패했어요'),
            TextButton(
              onPressed: vm.loadNextPage,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _item(CareRecord record) {
    final chip = formatRecordChip(record);
    final style = record.type.homeStyle;
    final time = DateFormat('HH:mm a').format(record.detail.occurredAt.toLocal());

    return Dismissible(
      key: Key('timeline_item_${record.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await onSwipeDelete(record);
        return false; // 리스트 제거는 ViewModel 이 담당.
      },
      child: InkWell(
        onTap: () => onTapRecord(record),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: style.dot,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            record.type.shortLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: HomeColors.textPrimary,
                            ),
                          ),
                        ),
                        if (chip != null) ...[
                          const SizedBox(width: 8),
                          _chip(chip, style),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: HomeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, HomeRecordStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.chipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: style.chipForeground,
        ),
      ),
    );
  }

  bool _sameLocalDate(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}
