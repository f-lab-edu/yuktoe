import 'package:flutter/material.dart';

/// 회색 outline + 투명 배경. 모든 chip 동일 디자인.
/// 탭하면 [onTap] 호출 (각 필드별 모달 진입).
class EditableChip extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const EditableChip({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9D9D9)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
