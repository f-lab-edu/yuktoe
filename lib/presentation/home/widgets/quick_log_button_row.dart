import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/presentation/home/home_record_style.dart';
import 'package:yuktoe/presentation/home/record_type_labels.dart';
import 'package:yuktoe/presentation/home/view_models/quick_log_buttons_view_model.dart';

/// 빠른 기록 줄 `[B]` — 섹션 헤더("빠른 기록" + "편집") + 흰 원형 버튼 (Figma).
class QuickLogButtonRow extends StatelessWidget {
  final void Function(RecordType type) onTapButton;
  final VoidCallback onTapSettings;

  const QuickLogButtonRow({
    super.key,
    required this.onTapButton,
    required this.onTapSettings,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuickLogButtonsViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 12, 4),
          child: Row(
            children: [
              const Text(
                '빠른 기록',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: HomeColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                key: const Key('quick_log_settings_button'),
                onTap: onTapSettings,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '편집',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: HomeColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final button in vm.enabledButtons) _button(button.type),
            ],
          ),
        ),
      ],
    );
  }

  Widget _button(RecordType type) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        key: Key('quick_log_button_${type.name}'),
        onTap: () => onTapButton(type),
        borderRadius: BorderRadius.circular(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: HomeColors.border),
              ),
              alignment: Alignment.center,
              child: Icon(
                type.lineIcon,
                size: 22,
                color: type.homeStyle.dot,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              type.shortLabel,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF364153),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
