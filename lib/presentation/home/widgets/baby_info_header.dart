import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/presentation/home/home_record_style.dart';
import 'package:yuktoe/presentation/home/view_models/home_baby_info_view_model.dart';

/// 헤더 `[A]` — D+N 라벨(hero) + 이름(부제). 전체가 단일 탭 영역 (spec §5.1, Figma).
class BabyInfoHeader extends StatelessWidget {
  final VoidCallback onTapName;

  const BabyInfoHeader({super.key, required this.onTapName});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeBabyInfoViewModel>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomeColors.border)),
      ),
      child: switch (vm.status) {
        ActionState.loading || ActionState.idle => _skeleton(),
        ActionState.error => _error(context, vm),
        ActionState.success => _content(vm),
      },
    );
  }

  Widget _skeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(width: 90, height: 18),
        const SizedBox(height: 4),
        _bar(width: 60, height: 11),
      ],
    );
  }

  Widget _bar({required double width, required double height}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: HomeColors.border,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  Widget _error(BuildContext context, HomeBabyInfoViewModel vm) {
    return Row(
      children: [
        const Text('정보를 불러오지 못했어요',
            style: TextStyle(color: HomeColors.textSecondary)),
        const Spacer(),
        IconButton(
          key: const Key('baby_info_retry'),
          icon: const Icon(Icons.refresh, color: HomeColors.textSecondary),
          onPressed: vm.retry,
        ),
      ],
    );
  }

  Widget _content(HomeBabyInfoViewModel vm) {
    final label = vm.dateLabel;
    final name = vm.name ?? '';
    final heroText = label ?? name;
    final subtitle = label != null ? name : null;

    return InkWell(
      key: const Key('baby_name_tap_area'),
      onTap: onTapName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                heroText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: HomeColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: HomeColors.textMuted),
            ],
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: HomeColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
