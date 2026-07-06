import 'package:flutter/foundation.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/presentation/analytics/view_models/analytics_presenter.dart';
import 'package:yuktoe/presentation/analytics/view_models/metric_card_data.dart';

/// 깨어있는 시간 카드 ViewModel. `awakeDuration` 슬롯을 표시용으로 가공한다.
///
/// 설계상 권장치 비교를 제공하지 않으므로 **비교 배지를 절대 만들지 않는다**
/// (reference 유무와 무관, spec FR-019a).
class AwakeCardViewModel extends ChangeNotifier {
  static const _title = '평균 1회 깨어있는 시간';

  MetricCardData _card = const MetricCardData.noData(_title);
  MetricCardData get card => _card;

  void bind(MetricComparison? metric) {
    _card = metric == null
        ? const MetricCardData.noData(_title)
        : MetricCardData(
            title: _title,
            hasValue: true,
            valueText: formatDurationMinutes(metric.value),
            badge: null, // 항상 배지 없음
          );
    notifyListeners();
  }
}
