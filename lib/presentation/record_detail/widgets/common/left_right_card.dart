import 'package:flutter/material.dart';

/// 모유수유 "소요 시간" / 유축 "유축량" 표시용.
/// 왼쪽 [child] ↔ 오른쪽 [child] + 하단 "총 N분"/"총 N ml".
class LeftRightCard extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final Widget leftValue;
  final Widget rightValue;
  final String totalText;

  const LeftRightCard({
    super.key,
    this.leftLabel = '왼쪽',
    this.rightLabel = '오른쪽',
    required this.leftValue,
    required this.rightValue,
    required this.totalText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _side(leftLabel, leftValue)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.swap_horiz, color: Color(0xFF8C8C8C)),
              ),
              Expanded(child: _side(rightLabel, rightValue)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            totalText,
            style: const TextStyle(color: Color(0xFF595959), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _side(String label, Widget value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 13),
        ),
        const SizedBox(height: 6),
        value,
      ],
    );
  }
}
