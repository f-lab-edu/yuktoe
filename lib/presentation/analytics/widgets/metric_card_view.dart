import 'package:flutter/material.dart';
import 'package:yuktoe/presentation/analytics/view_models/metric_card_data.dart';
import 'package:yuktoe/presentation/analytics/widgets/metric_comparison_badge.dart';

/// 카드 1장의 공통 시각 레이아웃. `MetricCardData` 를 받아 제목·값(또는 "데이터
/// 없음")·보조 설명·배지를 분기 없이 그대로 그린다(무상태·표시 전용). 4개 카드
/// 위젯이 각자 자기 ViewModel 의 `card` 를 이 위젯에 넘겨 재사용한다.
class MetricCardView extends StatelessWidget {
  final MetricCardData data;

  const MetricCardView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(data.title, style: textTheme.labelMedium),
          const SizedBox(height: 8),
          if (data.hasValue) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    data.valueText ?? '',
                    style: textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (data.badge != null) MetricComparisonBadge(data: data.badge!),
              ],
            ),
            if (data.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(data.subtitle!, style: textTheme.bodySmall),
            ],
          ] else
            Text(
              '데이터 없음',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }
}
