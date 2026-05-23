import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';

abstract interface class RecordRepository {
  Future<Result<CareRecord>> getRecord(String recordId);
  Future<Result<void>> updateRecord(String recordId, RecordDetailData detail);
  Future<Result<void>> deleteRecord(String recordId);
  Future<Result<Page<RecordMemo>>> getMemos(
    String recordId, {
    String? cursor,
    int limit = 20,
  });
  Future<Result<RecordMemo>> addMemo(String recordId, String content);
  Future<Result<void>> updateMemo(String memoId, String content);
  Future<Result<void>> deleteMemo(String memoId);
}
