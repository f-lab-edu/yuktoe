import 'package:flutter/material.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/record_detail/widgets/details/baby_food_detail_view.dart';
import 'package:yuktoe/presentation/record_detail/widgets/details/breast_detail_view.dart';
import 'package:yuktoe/presentation/record_detail/widgets/details/diaper_detail_view.dart';
import 'package:yuktoe/presentation/record_detail/widgets/details/formula_detail_view.dart';
import 'package:yuktoe/presentation/record_detail/widgets/details/pumping_detail_view.dart';
import 'package:yuktoe/presentation/record_detail/widgets/details/pumping_feed_detail_view.dart';
import 'package:yuktoe/presentation/record_detail/widgets/details/sleep_detail_view.dart';
import 'package:yuktoe/presentation/record_detail/widgets/details/snack_detail_view.dart';
import 'package:yuktoe/presentation/record_detail/widgets/details/water_detail_view.dart';

class RecordTypeDetailView extends StatelessWidget {
  final RecordDetailData detail;

  const RecordTypeDetailView({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return switch (detail) {
      DiaperDetail d => DiaperDetailView(detail: d),
      SleepDetail d => SleepDetailView(detail: d),
      BreastDetail d => BreastDetailView(detail: d),
      FormulaDetail d => FormulaDetailView(detail: d),
      PumpingFeedDetail d => PumpingFeedDetailView(detail: d),
      PumpingDetail d => PumpingDetailView(detail: d),
      BabyFoodDetail d => BabyFoodDetailView(detail: d),
      SnackDetail d => SnackDetailView(detail: d),
      WaterDetail d => WaterDetailView(detail: d),
    };
  }
}
