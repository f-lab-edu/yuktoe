import 'package:yuktoe/constants/enum/record_type.dart';
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
    String recordId,
    RecordDetailData detail,
  ) async {
    final result = await _recordService.updateRecord(
      recordId,
      {'detail': detail.toJson()},
    );
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

  @override
  Future<Result<Page<CareRecord>>> getRecords(
    String babyId, {
    String? cursor,
    int limit = 20,
  }) async {
    _checkLimit(limit, min: 1, max: 100);

    final result = await _recordService.getRecords(
      babyId,
      cursor: cursor,
      limit: limit,
    );
    switch (result) {
      case Ok<Page<CareRecord>>():
        return Result.ok(result.value);
      case Error<Page<CareRecord>>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<List<CareRecord>>> getRecentFeedings(
    String babyId, {
    int limit = 2,
  }) {
    _checkLimit(limit, min: 1, max: 10);
    return _recordService.getRecentRecords(
      babyId,
      types: const {
        RecordType.breast,
        RecordType.formula,
        RecordType.pumping,
        RecordType.pumpingFeed,
        RecordType.babyFood,
      },
      orderKey: RecordOrderKey.feedingEffectiveAt,
      limit: limit,
    );
  }

  @override
  Future<Result<List<CareRecord>>> getRecentDiapers(
    String babyId, {
    int limit = 2,
  }) {
    _checkLimit(limit, min: 1, max: 10);
    return _recordService.getRecentRecords(
      babyId,
      types: const {RecordType.diaper},
      orderKey: RecordOrderKey.occurredAt,
      limit: limit,
    );
  }

  @override
  Future<Result<List<CareRecord>>> getRecentWakes(
    String babyId, {
    int limit = 2,
  }) {
    _checkLimit(limit, min: 1, max: 10);
    return _recordService.getRecentRecords(
      babyId,
      types: const {RecordType.sleep},
      orderKey: RecordOrderKey.endedAt,
      limit: limit,
    );
  }

  @override
  Future<Result<CareRecord>> createRecord(
    String babyId,
    RecordDetailData detail,
  ) {
    return _recordService.createRecord(babyId, detail);
  }

  void _checkLimit(int limit, {required int min, required int max}) {
    if (limit < min || limit > max) {
      throw ArgumentError.value(limit, 'limit', 'must be in $min..$max');
    }
  }
}
