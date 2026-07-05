import 'package:flutter/foundation.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/presentation/analytics/view_models/analytics_presenter.dart';
import 'package:yuktoe/presentation/analytics/view_models/metric_card_data.dart';

/// 총 수면 카드 ViewModel. `totalSleepDuration` 슬롯을 표시용으로 가공한다.
class SleepCardViewModel extends ChangeNotifier {
  static const _title = '평균 하루 총 수면';

  MetricCardData _card = const MetricCardData.noData(_title);
  MetricCardData get card => _card;

  void bind(MetricComparison? metric) {
    _card = metric == null
        ? const MetricCardData.noData(_title)
        : MetricCardData(
            title: _title,
            hasValue: true,
            valueText: formatDurationMinutes(metric.value),
            badge: buildBadge(
              metric,
              below: '권장보다 짧음',
              within: '적정',
              above: '권장보다 김',
            ),
          );
    notifyListeners();
  }
}
