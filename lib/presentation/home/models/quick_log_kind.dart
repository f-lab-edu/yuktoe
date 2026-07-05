import 'package:yuktoe/constants/enum/feeding_type.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';

/// 홈 "빠른 기록 카탈로그" 가 사용자에게 보여주는 9개 종류.
///
/// 도메인은 수유 계열을 [RecordType.feeding] 하나로 묶고 세부 종류를
/// [FeedingType] 으로 구분하지만, 홈 UI 는 여전히 모유/분유/유축수유/이유식을
/// 개별 버튼으로 노출한다. 그 "버튼 종류" 는 도메인이 아니라 프레젠테이션
/// 관심사이므로 이 레이어가 소유한다.
///
/// 값 이름은 로컬 영속(`quick_log_buttons`)의 하위호환을 위해 유지한다.
enum QuickLogKind {
  breast,
  formula,
  pumpingFeed,
  babyFood,
  pumping,
  sleep,
  diaper,
  snack,
  water;

  /// 이 종류로 만들 기록의 도메인 [RecordType]. 수유 계열은 모두 feeding.
  RecordType get recordType => switch (this) {
    QuickLogKind.breast ||
    QuickLogKind.formula ||
    QuickLogKind.pumpingFeed ||
    QuickLogKind.babyFood => RecordType.feeding,
    QuickLogKind.pumping => RecordType.pumping,
    QuickLogKind.sleep => RecordType.sleep,
    QuickLogKind.diaper => RecordType.diaper,
    QuickLogKind.snack => RecordType.snack,
    QuickLogKind.water => RecordType.water,
  };

  /// 수유 계열이면 세부 종류, 아니면 null.
  FeedingType? get feedingType => switch (this) {
    QuickLogKind.breast => FeedingType.breast,
    QuickLogKind.formula => FeedingType.formula,
    QuickLogKind.pumpingFeed => FeedingType.pumpingFeed,
    QuickLogKind.babyFood => FeedingType.babyFood,
    _ => null,
  };

  /// 저장된 기록의 detail 로부터 표시용 종류를 판정한다(타임라인 색/라벨).
  static QuickLogKind fromDetail(RecordDetailData detail) => switch (detail) {
    BreastDetail() => QuickLogKind.breast,
    FormulaDetail() => QuickLogKind.formula,
    PumpingFeedDetail() => QuickLogKind.pumpingFeed,
    BabyFoodDetail() => QuickLogKind.babyFood,
    PumpingDetail() => QuickLogKind.pumping,
    SleepDetail() => QuickLogKind.sleep,
    DiaperDetail() => QuickLogKind.diaper,
    SnackDetail() => QuickLogKind.snack,
    WaterDetail() => QuickLogKind.water,
  };

  /// 미지의 이름이면 null (forward-compat).
  static QuickLogKind? fromName(String name) {
    for (final k in QuickLogKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }
}
