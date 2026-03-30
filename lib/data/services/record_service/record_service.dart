import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';

abstract interface class RecordService {
  Future<Result<CareRecord>> getRecord(String recordId);
  Future<Result<void>> updateRecord(
    String recordId,
    Map<String, dynamic> data,
  );
  Future<Result<void>> deleteRecord(String recordId);
  Future<Result<List<RecordMemo>>> getMemos(String recordId);
  Future<Result<RecordMemo>> createMemo(String recordId, String content);
  Future<Result<void>> updateMemo(String memoId, String content);
  Future<Result<void>> deleteMemo(String memoId);
}
