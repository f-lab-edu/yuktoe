import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';

enum RecordOrderKey {
  occurredAt,
  endedAt,
  feedingEffectiveAt;

  String get column => switch (this) {
        RecordOrderKey.occurredAt => 'occurred_at',
        RecordOrderKey.endedAt => 'ended_at',
        RecordOrderKey.feedingEffectiveAt => 'feeding_effective_at',
      };
}

abstract interface class RecordService {
  Future<Result<CareRecord>> getRecord(String recordId);
  Future<Result<void>> updateRecord(
    String recordId,
    Map<String, dynamic> data,
  );
  Future<Result<void>> deleteRecord(String recordId);
  Future<Result<Page<RecordMemo>>> getMemos(
    String recordId, {
    String? cursor,
    int limit = 20,
  });
  Future<Result<RecordMemo>> createMemo(String recordId, String content);
  Future<Result<void>> updateMemo(String memoId, String content);
  Future<Result<void>> deleteMemo(String memoId);

  Future<Result<Page<CareRecord>>> getRecords(
    String babyId, {
    String? cursor,
    required int limit,
  });

  Future<Result<List<CareRecord>>> getRecentRecords(
    String babyId, {
    required Set<RecordType> types,
    required RecordOrderKey orderKey,
    required int limit,
  });

  Future<Result<CareRecord>> createRecord(
    String babyId,
    RecordDetailData detail,
  );
}
