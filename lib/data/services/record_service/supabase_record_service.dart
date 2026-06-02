import 'dart:io';

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
      final affected = await _client
          .from('care_records')
          .delete()
          .eq('id', recordId)
          .select();
      if (affected.isEmpty) {
        return Result.error(
          AppException(ErrorCode.notFound, 'Record not found: $recordId'),
        );
      }
      return Result.ok(null);
    } catch (e) {
      return Result.error(_classify(e, 'Failed to delete record'));
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

  @override
  Future<Result<Page<CareRecord>>> getRecords(
    String babyId, {
    String? cursor,
    required int limit,
  }) async {
    try {
      var query = _client
          .from('care_records')
          .select()
          .eq('baby_id', babyId);

      if (cursor != null) {
        query = query.lt('id', cursor);
      }

      final data = await query
          .order('occurred_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit + 1);

      final hasMore = data.length > limit;
      final pageRows = hasMore ? data.sublist(0, limit) : data;
      final items = pageRows.map(_mapRecord).toList();
      final nextCursor = hasMore ? items.last.id : null;

      return Result.ok(
        Page(items: items, nextCursor: nextCursor, hasMore: hasMore),
      );
    } catch (e) {
      return Result.error(_classify(e, 'Failed to get records'));
    }
  }

  @override
  Future<Result<List<CareRecord>>> getRecentRecords(
    String babyId, {
    required Set<RecordType> types,
    required RecordOrderKey orderKey,
    required int limit,
  }) async {
    try {
      final column = orderKey.column;
      final data = await _client
          .from('care_records')
          .select()
          .eq('baby_id', babyId)
          .inFilter('type', types.map((t) => t.name).toList())
          .not(column, 'is', null)
          .order(column, ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      final items = data.map(_mapRecord).toList();
      return Result.ok(items);
    } catch (e) {
      return Result.error(_classify(e, 'Failed to get recent records'));
    }
  }

  @override
  Future<Result<CareRecord>> createRecord(
    String babyId,
    RecordDetailData detail,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Result.error(
        const AppException(ErrorCode.unauthorized, 'Not signed in'),
      );
    }
    try {
      final inserted = await _client
          .from('care_records')
          .insert({
            'baby_id': babyId,
            'type': _typeOf(detail).name,
            'detail': detail.toJson(),
            'created_by': userId,
          })
          .select()
          .single();

      return Result.ok(_mapRecord(inserted));
    } catch (e) {
      return Result.error(_classify(e, 'Failed to create record'));
    }
  }

  RecordType _typeOf(RecordDetailData detail) => switch (detail) {
        BreastDetail() => RecordType.breast,
        SleepDetail() => RecordType.sleep,
        PumpingDetail() => RecordType.pumping,
        PumpingFeedDetail() => RecordType.pumpingFeed,
        FormulaDetail() => RecordType.formula,
        DiaperDetail() => RecordType.diaper,
        BabyFoodDetail() => RecordType.babyFood,
        SnackDetail() => RecordType.snack,
        WaterDetail() => RecordType.water,
      };

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

  AppException _classify(Object e, String message) {
    if (e is AuthException) {
      return AppException(ErrorCode.unauthorized, message, cause: e);
    }
    if (e is PostgrestException || e is SocketException) {
      return AppException(ErrorCode.networkError, message, cause: e);
    }
    if (e is FormatException || e is TypeError || e is ArgumentError) {
      return AppException(ErrorCode.parseFailed, message, cause: e);
    }
    return AppException(ErrorCode.unknown, message, cause: e);
  }
}
