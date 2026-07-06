import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/presentation/analytics/view_models/awake_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/widgets/metric_card_view.dart';

/// 깨어있는 시간 카드. 자기 ViewModel 의 표시 데이터를 구독해 그린다(배지 없음).
class AwakeCard extends StatelessWidget {
  const AwakeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final card = context.watch<AwakeCardViewModel>().card;
    return MetricCardView(data: card);
  }
}
