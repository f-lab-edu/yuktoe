import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/analytics/view_models/feeding_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/widgets/metric_card_view.dart';

/// 수유량 카드. 자기 ViewModel 의 표시 데이터를 구독해 그린다.
class FeedingCard extends StatelessWidget {
  const FeedingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final card = context.watch<FeedingCardViewModel>().card;
    return MetricCardView(data: card);
  }
}
