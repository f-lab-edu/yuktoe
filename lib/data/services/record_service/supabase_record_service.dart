import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';

import 'record_service.dart';

class SupabaseRecordService implements RecordService {
  final SupabaseClient _client;

  SupabaseRecordService({required SupabaseClient client}) : _client = client;

  @override
  Future<Result<CareRecord>> getRecord(String recordId) async {
    try {
      final data =
          await _client
              .from('care_records')
              .select()
              .eq('id', recordId)
              .single();

      return Result.ok(_mapRecord(data));
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'Failed to get record', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> updateRecord(
    String recordId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _client.from('care_records').update(data).eq('id', recordId);
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'Failed to update record', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> deleteRecord(String recordId) async {
    try {
      await _client.from('care_records').delete().eq('id', recordId);
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'Failed to delete record', cause: e),
      );
    }
  }

  @override
  Future<Result<Page<RecordMemo>>> getMemos(
    String recordId, {
    String? cursor,
    int limit = 20,
  }) async {
    try {
      var query = _client
          .from('record_memos')
          .select('*, baby_members(nickname)')
          .eq('record_id', recordId);

      if (cursor != null) {
        query = query.gt('created_at', cursor);
      }

      final data = await query
          .order('created_at', ascending: true)
          .limit(limit + 1);

      final hasMore = data.length > limit;
      final pageData = hasMore ? data.sublist(0, limit) : data;
      final items = pageData.map(_mapMemo).toList();
      final nextCursor =
          hasMore ? items.last.createdAt.toIso8601String() : null;

      return Result.ok(
        Page(items: items, nextCursor: nextCursor, hasMore: hasMore),
      );
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'Failed to get memos', cause: e),
      );
    }
  }

  @override
  Future<Result<RecordMemo>> createMemo(
    String recordId,
    String content,
  ) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final data = await _client
          .from('record_memos')
          .insert({
            'record_id': recordId,
            'content': content,
            'author_id': userId,
          })
          .select('*, baby_members(nickname)')
          .single();

      return Result.ok(_mapMemo(data));
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'Failed to create memo', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> updateMemo(String memoId, String content) async {
    try {
      await _client
          .from('record_memos')
          .update({'content': content})
          .eq('id', memoId);
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'Failed to update memo', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> deleteMemo(String memoId) async {
    try {
      await _client.from('record_memos').delete().eq('id', memoId);
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'Failed to delete memo', cause: e),
      );
    }
  }

  CareRecord _mapRecord(Map<String, dynamic> data) {
    final type = RecordType.values.byName(data['type'] as String);
    final detail = RecordDetailData.fromJson(
      type,
      data['detail'] as Map<String, dynamic>,
    );

    return CareRecord(
      id: data['id'] as String,
      babyId: data['baby_id'] as String,
      type: type,
      detail: detail,
      createdBy: data['created_by'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  RecordMemo _mapMemo(Map<String, dynamic> data) {
    final memberData = data['baby_members'] as Map<String, dynamic>?;

    return RecordMemo(
      id: data['id'] as String,
      recordId: data['record_id'] as String,
      content: data['content'] as String,
      authorId: data['author_id'] as String,
      authorName: memberData?['nickname'] as String? ?? '',
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}
