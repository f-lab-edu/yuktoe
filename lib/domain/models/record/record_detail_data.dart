import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';

sealed class RecordDetailData {
  const RecordDetailData();

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
  final int? leftMinutes;
  final int? rightMinutes;

  const BreastDetail({this.leftMinutes, this.rightMinutes});

  @override
  Map<String, dynamic> toJson() => {
        'left_minutes': leftMinutes,
        'right_minutes': rightMinutes,
      };

  factory BreastDetail.fromJson(Map<String, dynamic> json) => BreastDetail(
        leftMinutes: json['left_minutes'] as int?,
        rightMinutes: json['right_minutes'] as int?,
      );
}

class PumpingDetail extends RecordDetailData {
  final int amountMl;

  const PumpingDetail({required this.amountMl});

  @override
  Map<String, dynamic> toJson() => {'amount_ml': amountMl};

  factory PumpingDetail.fromJson(Map<String, dynamic> json) =>
      PumpingDetail(amountMl: json['amount_ml'] as int);
}

class FormulaDetail extends RecordDetailData {
  final int amountMl;

  const FormulaDetail({required this.amountMl});

  @override
  Map<String, dynamic> toJson() => {'amount_ml': amountMl};

  factory FormulaDetail.fromJson(Map<String, dynamic> json) =>
      FormulaDetail(amountMl: json['amount_ml'] as int);
}

class SleepDetail extends RecordDetailData {
  final SleepType sleepType;
  final DateTime? endTime;

  const SleepDetail({required this.sleepType, this.endTime});

  @override
  Map<String, dynamic> toJson() => {
        'sleep_type': sleepType.name,
        'end_time': endTime?.toIso8601String(),
      };

  factory SleepDetail.fromJson(Map<String, dynamic> json) => SleepDetail(
        sleepType: SleepType.values.byName(json['sleep_type'] as String),
        endTime: json['end_time'] != null
            ? DateTime.parse(json['end_time'] as String)
            : null,
      );
}

class DiaperDetail extends RecordDetailData {
  final DiaperType diaperType;

  const DiaperDetail({required this.diaperType});

  @override
  Map<String, dynamic> toJson() => {'diaper_type': diaperType.name};

  factory DiaperDetail.fromJson(Map<String, dynamic> json) => DiaperDetail(
        diaperType: DiaperType.values.byName(json['diaper_type'] as String),
      );
}

class SupplementDetail extends RecordDetailData {
  final String name;

  const SupplementDetail({required this.name});

  @override
  Map<String, dynamic> toJson() => {'name': name};

  factory SupplementDetail.fromJson(Map<String, dynamic> json) =>
      SupplementDetail(name: json['name'] as String);
}

class WaterDetail extends RecordDetailData {
  final int amountMl;

  const WaterDetail({required this.amountMl});

  @override
  Map<String, dynamic> toJson() => {'amount_ml': amountMl};

  factory WaterDetail.fromJson(Map<String, dynamic> json) =>
      WaterDetail(amountMl: json['amount_ml'] as int);
}
