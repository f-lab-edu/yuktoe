import 'package:flutter/foundation.dart';
import 'package:yuktoe/domain/models/analytics/metric_comparison.dart';
import 'package:yuktoe/presentation/analytics/view_models/analytics_presenter.dart';
import 'package:yuktoe/presentation/analytics/view_models/metric_card_data.dart';

/// 기저귀 카드 ViewModel. 소변(`peeCount`)·대변(`poopCount`) 두 슬롯을 합쳐
/// 하나의 카드로 표시한다.
///
/// - 합산 타이틀("7.0 회") + 보조("소변 5.2 / 대변 1.8")를 만든다.
/// - 합산값에 대응하는 단일 권장 범위가 없으므로 **배지는 항상 없음**.
/// - 한쪽만 absent 면 있는 쪽만 합산에 반영하고 없는 쪽은 "데이터 없음" 표기,
///   둘 다 absent 면 카드 전체가 "데이터 없음"(spec FR-002a, plan AC-P3).
class DiaperCardViewModel extends ChangeNotifier {
  static const _title = '평균 하루 기저귀';

  MetricCardData _card = const MetricCardData.noData(_title);
  MetricCardData get card => _card;

  void bind(MetricComparison? pee, MetricComparison? poop) {
    if (pee == null && poop == null) {
      _card = const MetricCardData.noData(_title);
      notifyListeners();
      return;
    }

    final total = (pee?.value ?? 0) + (poop?.value ?? 0);
    final peeText = pee == null ? '데이터 없음' : formatCount(pee.value);
    final poopText = poop == null ? '데이터 없음' : formatCount(poop.value);

    _card = MetricCardData(
      title: _title,
      hasValue: true,
      valueText: '${formatCount(total)} 회',
      subtitle: '소변 $peeText / 대변 $poopText',
      badge: null, // 합산값에 대응하는 권장 범위 없음 → 배지 없음
    );
    notifyListeners();
  }
}
