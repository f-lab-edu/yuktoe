import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/feeding_type.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';

sealed class RecordDetailData {
  const RecordDetailData();

  /// 기록 카테고리. 카테고리의 SOT 는 이 getter 다.
  RecordType get type;

  /// 사건이 일어난(또는 시작된) 시각. 정렬·표시의 단일 기준점.
  /// 구간 타입은 `startedAt` 으로부터 derive.
  DateTime get occurredAt;

  Map<String, dynamic> toJson();

  static RecordDetailData fromJson(
    RecordType type,
    Map<String, dynamic> json,
  ) {
    return switch (type) {
      RecordType.feeding => FeedingDetail.fromJson(json),
      RecordType.pumping => PumpingDetail.fromJson(json),
      RecordType.sleep => SleepDetail.fromJson(json),
      RecordType.diaper => DiaperDetail.fromJson(json),
      RecordType.snack => SnackDetail.fromJson(json),
      RecordType.water => WaterDetail.fromJson(json),
    };
  }
}

/// 수유 계열 detail 의 공통 그룹. `RecordType.feeding` 한 종류에 속하며,
/// 구체 종류는 [feedingType] 으로 구분한다. sealed 중간 클래스이므로
/// feeding 멤버는 이 4개로 타입 수준에서 강제된다.
sealed class FeedingDetail extends RecordDetailData {
  const FeedingDetail();

  @override
  RecordType get type => RecordType.feeding;

  /// 수유 세부 종류. feeding 카테고리 내에서의 SOT.
  FeedingType get feedingType;

  factory FeedingDetail.fromJson(Map<String, dynamic> json) {
    final feedingType = FeedingType.values.byName(json['feeding_type'] as String);
    return switch (feedingType) {
      FeedingType.breast => BreastDetail.fromJson(json),
      FeedingType.formula => FormulaDetail.fromJson(json),
      FeedingType.pumpingFeed => PumpingFeedDetail.fromJson(json),
      FeedingType.babyFood => BabyFoodDetail.fromJson(json),
    };
  }
}

class BreastDetail extends FeedingDetail {
  final DateTime startedAt;
  final DateTime endedAt;
  final int? leftMinutes;
  final int? rightMinutes;

  const BreastDetail({
    required this.startedAt,
    required this.endedAt,
    this.leftMinutes,
    this.rightMinutes,
  });

  @override
  FeedingType get feedingType => FeedingType.breast;

  @override
  DateTime get occurredAt => startedAt;

  Duration get duration => endedAt.difference(startedAt);

  BreastDetail copyWith({
    DateTime? startedAt,
    DateTime? endedAt,
    int? leftMinutes,
    int? rightMinutes,
  }) =>
      BreastDetail(
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        leftMinutes: leftMinutes ?? this.leftMinutes,
        rightMinutes: rightMinutes ?? this.rightMinutes,
      );

  @override
  Map<String, dynamic> toJson() => {
        'feeding_type': feedingType.name,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'left_minutes': leftMinutes,
        'right_minutes': rightMinutes,
      };

  factory BreastDetail.fromJson(Map<String, dynamic> json) => BreastDetail(
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: DateTime.parse(json['ended_at'] as String),
        leftMinutes: json['left_minutes'] as int?,
        rightMinutes: json['right_minutes'] as int?,
      );
}

class FormulaDetail extends FeedingDetail {
  @override
  final DateTime occurredAt;
  final int amountMl;

  const FormulaDetail({required this.occurredAt, required this.amountMl});

  @override
  FeedingType get feedingType => FeedingType.formula;

  FormulaDetail copyWith({DateTime? occurredAt, int? amountMl}) =>
      FormulaDetail(
        occurredAt: occurredAt ?? this.occurredAt,
        amountMl: amountMl ?? this.amountMl,
      );

  @override
  Map<String, dynamic> toJson() => {
        'feeding_type': feedingType.name,
        'occurred_at': occurredAt.toIso8601String(),
        'amount_ml': amountMl,
      };

  factory FormulaDetail.fromJson(Map<String, dynamic> json) => FormulaDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        amountMl: json['amount_ml'] as int,
      );
}

class PumpingFeedDetail extends FeedingDetail {
  @override
  final DateTime occurredAt;
  final int amountMl;

  const PumpingFeedDetail({
    required this.occurredAt,
    required this.amountMl,
  });

  @override
  FeedingType get feedingType => FeedingType.pumpingFeed;

  PumpingFeedDetail copyWith({DateTime? occurredAt, int? amountMl}) =>
      PumpingFeedDetail(
        occurredAt: occurredAt ?? this.occurredAt,
        amountMl: amountMl ?? this.amountMl,
      );

  @override
  Map<String, dynamic> toJson() => {
        'feeding_type': feedingType.name,
        'occurred_at': occurredAt.toIso8601String(),
        'amount_ml': amountMl,
      };

  factory PumpingFeedDetail.fromJson(Map<String, dynamic> json) =>
      PumpingFeedDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        amountMl: json['amount_ml'] as int,
      );
}

class BabyFoodDetail extends FeedingDetail {
  @override
  final DateTime occurredAt;
  final String name;
  final int amountMl;

  const BabyFoodDetail({
    required this.occurredAt,
    required this.name,
    required this.amountMl,
  });

  @override
  FeedingType get feedingType => FeedingType.babyFood;

  BabyFoodDetail copyWith({
    DateTime? occurredAt,
    String? name,
    int? amountMl,
  }) =>
      BabyFoodDetail(
        occurredAt: occurredAt ?? this.occurredAt,
        name: name ?? this.name,
        amountMl: amountMl ?? this.amountMl,
      );

  @override
  Map<String, dynamic> toJson() => {
        'feeding_type': feedingType.name,
        'occurred_at': occurredAt.toIso8601String(),
        'name': name,
        'amount_ml': amountMl,
      };

  factory BabyFoodDetail.fromJson(Map<String, dynamic> json) => BabyFoodDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        name: json['name'] as String,
        amountMl: json['amount_ml'] as int,
      );
}

class SleepDetail extends RecordDetailData {
  final DateTime startedAt;
  final DateTime endedAt;
  final SleepType sleepType;

  const SleepDetail({
    required this.startedAt,
    required this.endedAt,
    required this.sleepType,
  });

  @override
  RecordType get type => RecordType.sleep;

  @override
  DateTime get occurredAt => startedAt;

  Duration get duration => endedAt.difference(startedAt);

  SleepDetail copyWith({
    DateTime? startedAt,
    DateTime? endedAt,
    SleepType? sleepType,
  }) =>
      SleepDetail(
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        sleepType: sleepType ?? this.sleepType,
      );

  @override
  Map<String, dynamic> toJson() => {
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'sleep_type': sleepType.name,
      };

  factory SleepDetail.fromJson(Map<String, dynamic> json) => SleepDetail(
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: DateTime.parse(json['ended_at'] as String),
        sleepType: SleepType.values.byName(json['sleep_type'] as String),
      );
}

class PumpingDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final int? leftAmountMl;
  final int? rightAmountMl;

  const PumpingDetail({
    required this.occurredAt,
    this.leftAmountMl,
    this.rightAmountMl,
  });

  @override
  RecordType get type => RecordType.pumping;

  PumpingDetail copyWith({
    DateTime? occurredAt,
    int? leftAmountMl,
    int? rightAmountMl,
  }) =>
      PumpingDetail(
        occurredAt: occurredAt ?? this.occurredAt,
        leftAmountMl: leftAmountMl ?? this.leftAmountMl,
        rightAmountMl: rightAmountMl ?? this.rightAmountMl,
      );

  @override
  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toIso8601String(),
        'left_amount_ml': leftAmountMl,
        'right_amount_ml': rightAmountMl,
      };

  factory PumpingDetail.fromJson(Map<String, dynamic> json) => PumpingDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        leftAmountMl: json['left_amount_ml'] as int?,
        rightAmountMl: json['right_amount_ml'] as int?,
      );
}

class DiaperDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final DiaperType diaperType;

  const DiaperDetail({required this.occurredAt, required this.diaperType});

  @override
  RecordType get type => RecordType.diaper;

  DiaperDetail copyWith({DateTime? occurredAt, DiaperType? diaperType}) =>
      DiaperDetail(
        occurredAt: occurredAt ?? this.occurredAt,
        diaperType: diaperType ?? this.diaperType,
      );

  @override
  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toIso8601String(),
        'diaper_type': diaperType.name,
      };

  factory DiaperDetail.fromJson(Map<String, dynamic> json) => DiaperDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        diaperType: DiaperType.values.byName(json['diaper_type'] as String),
      );
}

class SnackDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final String name;

  const SnackDetail({required this.occurredAt, required this.name});

  @override
  RecordType get type => RecordType.snack;

  SnackDetail copyWith({DateTime? occurredAt, String? name}) => SnackDetail(
        occurredAt: occurredAt ?? this.occurredAt,
        name: name ?? this.name,
      );

  @override
  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toIso8601String(),
        'name': name,
      };

  factory SnackDetail.fromJson(Map<String, dynamic> json) => SnackDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        name: json['name'] as String,
      );
}

class WaterDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final int amountMl;

  const WaterDetail({required this.occurredAt, required this.amountMl});

  @override
  RecordType get type => RecordType.water;

  WaterDetail copyWith({DateTime? occurredAt, int? amountMl}) => WaterDetail(
        occurredAt: occurredAt ?? this.occurredAt,
        amountMl: amountMl ?? this.amountMl,
      );

  @override
  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toIso8601String(),
        'amount_ml': amountMl,
      };

  factory WaterDetail.fromJson(Map<String, dynamic> json) => WaterDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        amountMl: json['amount_ml'] as int,
      );
}
