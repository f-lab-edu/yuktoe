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
      RecordType.formula => FormulaDetail.fromJson(json),
      RecordType.sleep => SleepDetail.fromJson(json),
      RecordType.diaper => DiaperDetail.fromJson(json),
      RecordType.supplement => SupplementDetail.fromJson(json),
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
  final int amountMl;

  const PumpingDetail({required this.occurredAt, required this.amountMl});

  @override
  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toIso8601String(),
        'amount_ml': amountMl,
      };

  factory PumpingDetail.fromJson(Map<String, dynamic> json) => PumpingDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        amountMl: json['amount_ml'] as int,
      );
}

class FormulaDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final int amountMl;

  const FormulaDetail({required this.occurredAt, required this.amountMl});

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

class SupplementDetail extends RecordDetailData {
  @override
  final DateTime occurredAt;
  final String name;

  const SupplementDetail({required this.occurredAt, required this.name});

  @override
  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toIso8601String(),
        'name': name,
      };

  factory SupplementDetail.fromJson(Map<String, dynamic> json) =>
      SupplementDetail(
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
  Map<String, dynamic> toJson() => {
        'occurred_at': occurredAt.toIso8601String(),
        'amount_ml': amountMl,
      };

  factory WaterDetail.fromJson(Map<String, dynamic> json) => WaterDetail(
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        amountMl: json['amount_ml'] as int,
      );
}
