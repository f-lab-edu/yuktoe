import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';

sealed class RecordDetailData {
  const RecordDetailData();
}

class BreastDetail extends RecordDetailData {
  final int? leftMinutes;
  final int? rightMinutes;

  const BreastDetail({this.leftMinutes, this.rightMinutes});
}

class PumpingDetail extends RecordDetailData {
  final int amountMl;

  const PumpingDetail({required this.amountMl});
}

class FormulaDetail extends RecordDetailData {
  final int amountMl;

  const FormulaDetail({required this.amountMl});
}

class SleepDetail extends RecordDetailData {
  final SleepType sleepType;
  final DateTime? endTime;

  const SleepDetail({required this.sleepType, this.endTime});
}

class DiaperDetail extends RecordDetailData {
  final DiaperType diaperType;

  const DiaperDetail({required this.diaperType});
}

class SupplementDetail extends RecordDetailData {
  final String name;

  const SupplementDetail({required this.name});
}

class WaterDetail extends RecordDetailData {
  final int amountMl;

  const WaterDetail({required this.amountMl});
}
