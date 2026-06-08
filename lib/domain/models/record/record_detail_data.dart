import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';

sealed class RecordDetailData {
  const RecordDetailData();

  /// 사건이 일어난(또는 시작된) 시각. 정렬·표시의 단일 기준점.
  /// 구간 타입은 `startedAt` 으로부터 derive.
  DateTime get occurredAt;

  Map<String, dynamic> toJson();

  static RecordDetailData fromJson(
    RecordType type,
    Map<String, dynamic> json,
  ) {
    return switch (type) {
      RecordType.breast => BreastDetail.fromJson(json),
      RecordType.pumping => PumpingDetail.fromJson(json),
      RecordType.pumpingFeed => PumpingFeedDetail.fromJson(json),
      RecordType.formula => FormulaDetail.fromJson(json),
      RecordType.sleep => SleepDetail.fromJson(json),
      RecordType.diaper => DiaperDetail.fromJson(json),
      RecordType.babyFood => BabyFoodDetail.fromJson(json),
      RecordType.snack => SnackDetail.fromJson(json),
      RecordType.water => WaterDetail.fromJson(json),
    };
  }
}

class BreastDetail extends RecordDetailData {
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

class PumpingFeedDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final int amountMl;

  const PumpingFeedDetail({
    required this.occurredAt,
    required this.amountMl,
  });

  PumpingFeedDetail copyWith({DateTime? occurredAt, int? amountMl}) =>
      PumpingFeedDetail(
        occurredAt: occurredAt ?? this.occurredAt,
        amountMl: amountMl ?? this.amountMl,
      );

  @override
  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toIso8601String(),
        'amount_ml': amountMl,
      };

  factory PumpingFeedDetail.fromJson(Map<String, dynamic> json) =>
      PumpingFeedDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        amountMl: json['amount_ml'] as int,
      );
}

class FormulaDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final int amountMl;

  const FormulaDetail({required this.occurredAt, required this.amountMl});

  FormulaDetail copyWith({DateTime? occurredAt, int? amountMl}) =>
      FormulaDetail(
        occurredAt: occurredAt ?? this.occurredAt,
        amountMl: amountMl ?? this.amountMl,
      );

  @override
  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toIso8601String(),
        'amount_ml': amountMl,
      };

  factory FormulaDetail.fromJson(Map<String, dynamic> json) => FormulaDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        amountMl: json['amount_ml'] as int,
      );
}

class DiaperDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final DiaperType diaperType;

  const DiaperDetail({required this.occurredAt, required this.diaperType});

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

class BabyFoodDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final String name;
  final int amountMl;

  const BabyFoodDetail({
    required this.occurredAt,
    required this.name,
    required this.amountMl,
  });

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

class SnackDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final String name;

  const SnackDetail({required this.occurredAt, required this.name});

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
