import 'package:flutter/foundation.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/presentation/analytics/view_models/analytics_presenter.dart';
import 'package:yuktoe/presentation/analytics/view_models/metric_card_data.dart';

/// 수유량 카드 ViewModel. 코디네이터가 건네준 `feedingVolume` 슬롯을 표시용
/// `MetricCardData` 로 가공해 보유한다. 네트워크를 모른다.
class FeedingCardViewModel extends ChangeNotifier {
  static const _title = '평균 하루 수유량';

  MetricCardData _card = const MetricCardData.noData(_title);
  MetricCardData get card => _card;

  void bind(MetricComparison? metric) {
    _card = metric == null
        ? const MetricCardData.noData(_title)
        : MetricCardData(
            title: _title,
            hasValue: true,
            valueText: formatMl(metric.value),
            badge: buildBadge(
              metric,
              below: '권장보다 적음',
              within: '적정',
              above: '권장보다 많음',
            ),
          );
    notifyListeners();
  }
}
