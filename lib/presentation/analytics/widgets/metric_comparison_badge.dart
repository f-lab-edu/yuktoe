import 'package:flutter/material.dart';
import 'package:yuktoe/presentation/analytics/view_models/metric_card_data.dart';

/// 적음/적정/많음 비교 배지. `MetricBadgeData` 를 받아 톤 색상 + 라벨만 그린다
/// (무상태·표시 전용). 어떤 배지를 그릴지/생략할지는 카드 ViewModel 이 이미 결정한다.
class MetricComparisonBadge extends StatelessWidget {
  final MetricBadgeData data;

  const MetricComparisonBadge({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colors(context, data.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        data.label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  (Color fg, Color bg) _colors(BuildContext context, ComparisonTone tone) {
    final scheme = Theme.of(context).colorScheme;
    return switch (tone) {
      ComparisonTone.within => (Colors.green.shade700, Colors.green.shade50),
      ComparisonTone.below => (scheme.primary, scheme.primaryContainer),
      ComparisonTone.above => (Colors.orange.shade800, Colors.orange.shade50),
    };
  }
}
