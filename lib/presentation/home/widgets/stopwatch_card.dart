import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/presentation/home/home_record_style.dart';
import 'package:yuktoe/presentation/home/view_models/breast_stopwatch_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/sleep_stopwatch_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/stopwatch_controller.dart';

/// 스탑워치 카드 `[D]` — 활성인 한 종류만 렌더 (spec §5.3, Figma).
class StopwatchCard extends StatelessWidget {
  final void Function(CareRecord record) onSaved;
  final void Function(AppException error) onUnauthorized;

  const StopwatchCard({
    super.key,
    required this.onSaved,
    required this.onUnauthorized,
  });

  static const _accent = HomeColors.timerAccent; // 핑크
  static const _completeColor = HomeColors.complete; // 그린

  @override
  Widget build(BuildContext context) {
    final breast = context.watch<BreastStopwatchViewModel>();
    final sleep = context.watch<SleepStopwatchViewModel>();

    Widget? body;
    StopwatchController? active;
    if (breast.active) {
      body = _breast(breast);
      active = breast;
    } else if (sleep.active) {
      body = _sleep(sleep);
      active = sleep;
    }
    if (body == null || active == null) return const SizedBox.shrink();

    final showClose = active.saveStatus != SaveStatus.saving;

    return Container(
      key: const Key('stopwatch_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Stack(
        children: [
          body,
          if (showClose)
            Positioned(
              top: -8,
              right: -8,
              child: IconButton(
                key: const Key('stopwatch_close'),
                icon: const Icon(Icons.close, size: 20,
                    color: HomeColors.textMuted),
                tooltip: '타이머 닫기',
                onPressed: () => _close(context, active!),
              ),
            ),
        ],
      ),
    );
  }

  /// 시작→완료 외의 취소 루트. 누적 시간이 있으면 실수 방지 확인 후 폐기.
  Future<void> _close(BuildContext context, StopwatchController vm) async {
    if (vm.hasElapsed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text('타이머를 종료할까요?\n지금까지의 시간은 기록되지 않아요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('종료', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    vm.discard();
  }

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
      color: HomeColors.textSecondary,
    ),
  );

  Widget _breast(BreastStopwatchViewModel vm) {
    final saving = vm.saveStatus == SaveStatus.saving;
    final failed = vm.saveStatus == SaveStatus.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('수유 타이머'),
        const SizedBox(height: 12),
        _breastRow('왼쪽', vm.leftDisplay, vm.leftPhase, saving,
            const Key('breast_toggle_left'), vm.toggleLeft),
        const SizedBox(height: 8),
        _breastRow('오른쪽', vm.rightDisplay, vm.rightPhase, saving,
            const Key('breast_toggle_right'), vm.toggleRight),
        const SizedBox(height: 16),
        if (failed)
          _failedActions(vm)
        else
          _completeButton(
            const Key('breast_complete'),
            enabled: vm.completeEnabled && !saving,
            onPressed: () => _complete(vm, vm.complete),
          ),
      ],
    );
  }

  Widget _breastRow(String label, String time, StopwatchPhase phase,
      bool saving, Key key, VoidCallback onToggle) {
    final running = phase == StopwatchPhase.running;
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF364153))),
        ),
        Expanded(
          child: Text(
            time,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: HomeColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _iconButton(
          key,
          icon: running ? Icons.pause : Icons.play_arrow,
          onPressed: saving ? null : onToggle,
        ),
      ],
    );
  }

  Widget _sleep(SleepStopwatchViewModel vm) {
    final saving = vm.saveStatus == SaveStatus.saving;
    final failed = vm.saveStatus == SaveStatus.failed;
    final running = vm.phase == StopwatchPhase.running;
    final idle = vm.phase == StopwatchPhase.idle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('수면 타이머'),
        const SizedBox(height: 12),
        Center(
          child: Text(
            vm.display,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: HomeColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (failed)
          _failedActions(vm)
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('sleep_toggle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: const BorderSide(color: _accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: saving ? null : vm.toggle,
                  child: Text(idle ? '시작' : (running ? '일시정지' : '재개')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _completeButton(
                  const Key('sleep_complete'),
                  enabled: vm.completeEnabled && !saving,
                  onPressed: () => _complete(vm, vm.complete),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _iconButton(Key key, {required IconData icon, VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: onPressed == null ? Colors.grey.shade200 : _accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        key: key,
        icon: Icon(icon, color: onPressed == null ? Colors.grey : _accent),
        onPressed: onPressed,
      ),
    );
  }

  Widget _completeButton(Key key,
      {required bool enabled,
      required VoidCallback onPressed,
      String label = '완료'}) {
    return ElevatedButton(
      key: key,
      style: ElevatedButton.styleFrom(
        backgroundColor: _completeColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD1D5DC),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: enabled ? onPressed : null,
      child: Text(label),
    );
  }

  Widget _failedActions(StopwatchController vm) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('stopwatch_discard'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: vm.discard,
            child: const Text('버리기'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _completeButton(
            const Key('stopwatch_retry'),
            enabled: true,
            onPressed: () => _complete(vm, vm.retry),
            label: '다시 시도',
          ),
        ),
      ],
    );
  }

  Future<void> _complete(
    StopwatchController vm,
    Future<CareRecord?> Function() action,
  ) async {
    final record = await action();
    if (record != null) {
      onSaved(record);
      return;
    }
    final error = vm.saveError;
    if (error != null && error.code == ErrorCode.unauthorized) {
      onUnauthorized(error);
    }
  }
}
