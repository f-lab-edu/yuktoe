import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/home/formatters/relative_time_formatter.dart';
import 'package:yuktoe/presentation/home/home_record_style.dart';
import 'package:yuktoe/presentation/home/models/recent_slot_state.dart';
import 'package:yuktoe/presentation/home/view_models/recent_snapshot_view_model.dart';

/// 최근 요약 `[C]` — 테두리 흰 카드, 3 슬롯 분할 (Figma).
class RecentSnapshotRow extends StatelessWidget {
  final DateTime Function() now;

  const RecentSnapshotRow({super.key, DateTime Function()? now})
    : now = now ?? DateTime.now;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecentSnapshotViewModel>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _slot('recent_feed', '마지막 수유', vm.feed, _feedTime, vm.retryFeed),
            _divider(),
            _slot('recent_diaper', '마지막 기저귀', vm.diaper,
                (r) => r.detail.occurredAt, vm.retryDiaper),
            _divider(),
            _slot('recent_wake', '마지막 기상', vm.wake, _wakeTime, vm.retryWake),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const VerticalDivider(
    width: 1,
    thickness: 1,
    color: HomeColors.border,
  );

  DateTime _feedTime(CareRecord r) {
    final detail = r.detail;
    return detail is BreastDetail ? detail.endedAt : detail.occurredAt;
  }

  DateTime _wakeTime(CareRecord r) {
    final detail = r.detail;
    return detail is SleepDetail ? detail.endedAt : detail.occurredAt;
  }

  Widget _slot(
    String key,
    String title,
    RecentSlotState state,
    DateTime Function(CareRecord) baseTime,
    VoidCallback onRetry,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          key: Key(key),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: HomeColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            _value(state, baseTime, onRetry),
          ],
        ),
      ),
    );
  }

  Widget _value(
    RecentSlotState state,
    DateTime Function(CareRecord) baseTime,
    VoidCallback onRetry,
  ) {
    switch (state.status) {
      case ActionState.idle:
      case ActionState.loading:
        return Container(
          width: 56,
          height: 16,
          decoration: BoxDecoration(
            color: HomeColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case ActionState.error:
        return InkWell(
          onTap: onRetry,
          child: const Icon(Icons.refresh, size: 18,
              color: HomeColors.textMuted),
        );
      case ActionState.success:
        final record = state.record;
        if (record == null) {
          return const Text(
            '기록 없음',
            style: TextStyle(fontSize: 13, color: HomeColors.textMuted),
          );
        }
        return Text(
          formatRelativeTime(baseTime(record), now()),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: HomeColors.textPrimary,
          ),
        );
    }
  }
}
