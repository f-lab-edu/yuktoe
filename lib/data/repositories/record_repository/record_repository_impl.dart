import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/data/services/record_service/record_service.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';

class RecordRepositoryImpl implements RecordRepository {
  final RecordService _recordService;

  RecordRepositoryImpl(this._recordService);

  @override
  Future<Result<CareRecord>> getRecord(String recordId) async {
    final result = await _recordService.getRecord(recordId);
    switch (result) {
      case Ok<CareRecord>():
        return Result.ok(result.value);
      case Error<CareRecord>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<void>> updateRecord(
    String recordId, {
    DateTime? recordedAt,
    RecordDetailData? detail,
  }) async {
    final data = <String, dynamic>{};

    if (recordedAt != null) {
      data['recorded_at'] = recordedAt.toIso8601String();
    }

    if (detail != null) {
      data['detail'] = _serializeDetail(detail);
    }

    final result = await _recordService.updateRecord(recordId, data);
    switch (result) {
      case Ok<void>():
        return Result.ok(null);
      case Error<void>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<void>> deleteRecord(String recordId) async {
    final result = await _recordService.deleteRecord(recordId);
    switch (result) {
      case Ok<void>():
        return Result.ok(null);
      case Error<void>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<Page<RecordMemo>>> getMemos(
    String recordId, {
    String? cursor,
    int limit = 20,
  }) async {
    final result = await _recordService.getMemos(
      recordId,
      cursor: cursor,
      limit: limit,
    );
    switch (result) {
      case Ok<Page<RecordMemo>>():
        return Result.ok(result.value);
      case Error<Page<RecordMemo>>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<RecordMemo>> addMemo(String recordId, String content) async {
    final result = await _recordService.createMemo(recordId, content);
    switch (result) {
      case Ok<RecordMemo>():
        return Result.ok(result.value);
      case Error<RecordMemo>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<void>> updateMemo(String memoId, String content) async {
    final result = await _recordService.updateMemo(memoId, content);
    switch (result) {
      case Ok<void>():
        return Result.ok(null);
      case Error<void>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<void>> deleteMemo(String memoId) async {
    final result = await _recordService.deleteMemo(memoId);
    switch (result) {
      case Ok<void>():
        return Result.ok(null);
      case Error<void>():
        return Result.error(result.error);
    }
  }

  Map<String, dynamic> _serializeDetail(RecordDetailData detail) {
    return switch (detail) {
      BreastDetail() => {
        'left_minutes': detail.leftMinutes,
        'right_minutes': detail.rightMinutes,
      },
      PumpingDetail() => {'amount_ml': detail.amountMl},
      FormulaDetail() => {'amount_ml': detail.amountMl},
      SleepDetail() => {
        'sleep_type': detail.sleepType.name,
        'end_time': detail.endTime?.toIso8601String(),
      },
      DiaperDetail() => {'diaper_type': detail.diaperType.name},
      SupplementDetail() => {'name': detail.name},
      WaterDetail() => {'amount_ml': detail.amountMl},
    };
  }
}
