import 'package:flutter/material.dart';

/// 스탑워치 카드가 떠 있을 때 다른 모드 진입 시도 (spec §5.3.5).
/// `true` = 닫고 시작, 그 외 = 취소.
Future<bool> showStopwatchConflictDialog(
  BuildContext context, {
  required String currentLabel,
  required String nextLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text('$currentLabel 타이머 카드가 떠 있어요.\n닫고 $nextLabel를 시작할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('닫고 시작'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 스탑워치 진행 중 라우트 이동 (spec §5.3.6).
enum StopwatchNavigateChoice { cancel, completeAndGo, keepAndGo }

Future<StopwatchNavigateChoice> showStopwatchNavigationDialog(
  BuildContext context,
) async {
  final result = await showDialog<StopwatchNavigateChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: const Text('타이머가 진행 중이에요.\n종료하지 않고 이동할까요?'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, StopwatchNavigateChoice.cancel),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, StopwatchNavigateChoice.completeAndGo),
          child: const Text('종료하고 이동'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, StopwatchNavigateChoice.keepAndGo),
          child: const Text('유지하고 이동'),
        ),
      ],
    ),
  );
  return result ?? StopwatchNavigateChoice.cancel;
}
