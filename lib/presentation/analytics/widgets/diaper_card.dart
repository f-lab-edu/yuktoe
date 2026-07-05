import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/analytics/view_models/diaper_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/widgets/metric_card_view.dart';

/// 기저귀 카드. 합산 값 + 소변/대변 보조를 구독해 그린다(배지 없음).
class DiaperCard extends StatelessWidget {
  const DiaperCard({super.key});

  @override
  Widget build(BuildContext context) {
    final card = context.watch<DiaperCardViewModel>().card;
    return MetricCardView(data: card);
  }
}
