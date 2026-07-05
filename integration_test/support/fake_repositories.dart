import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/baby/baby_list_item.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';

/// 통합 테스트용 인메모리 [BabyRepository]. 네트워크 없이 실제 흐름을 구동한다.
class FakeBabyRepository implements BabyRepository {
  final List<Baby> babies;

  /// 특정 시나리오 강제용.
  AppException? getMyBabiesError;

  FakeBabyRepository(this.babies);

  @override
  Future<Result<List<BabyListItem>>> getMyBabies() async {
    if (getMyBabiesError != null) return Error(getMyBabiesError!);
    return Ok(
      babies.map((b) => BabyListItem(id: b.id, name: b.name)).toList(),
    );
  }

  @override
  Future<Result<Baby>> getBaby(String babyId) async {
    for (final b in babies) {
      if (b.id == babyId) return Ok(b);
    }
    return Error(const AppException(ErrorCode.notFound, 'baby not found'));
  }
}

/// 통합 테스트용 인메모리 [RecordRepository].
class FakeRecordRepository implements RecordRepository {
  final Map<String, List<CareRecord>> _store = {};
  int _seq = 0;

  AppException? deleteError;

  FakeRecordRepository();

  void seed(String babyId, List<CareRecord> records) {
    _store[babyId] = [...records];
  }

  List<CareRecord> _forBaby(String babyId) => _store[babyId] ?? const [];

  List<CareRecord> _sortedDesc(String babyId) {
    final list = [..._forBaby(babyId)];
    list.sort((a, b) => b.detail.occurredAt.compareTo(a.detail.occurredAt));
    return list;
  }

  @override
  Future<Result<Page<CareRecord>>> getRecords(
    String babyId, {
    String? cursor,
    int limit = 20,
  }) async {
    final all = _sortedDesc(babyId);
    final start = cursor == null ? 0 : int.parse(cursor);
    final slice = all.skip(start).take(limit).toList();
    final nextStart = start + slice.length;
    final hasMore = nextStart < all.length;
    return Ok(Page(
      items: slice,
      nextCursor: hasMore ? nextStart.toString() : null,
      hasMore: hasMore,
    ));
  }

  Future<Result<List<CareRecord>>> _recent(
    String babyId,
    Set<RecordType> types,
    int limit,
  ) async {
    final matched =
        _sortedDesc(babyId).where((r) => types.contains(r.type)).take(limit);
    return Ok(matched.toList());
  }

  @override
  Future<Result<List<CareRecord>>> getRecentFeedings(
    String babyId, {
    int limit = 2,
  }) =>
      _recent(babyId, {RecordType.feeding, RecordType.pumping}, limit);

  @override
  Future<Result<List<CareRecord>>> getRecentDiapers(
    String babyId, {
    int limit = 2,
  }) =>
      _recent(babyId, {RecordType.diaper}, limit);

  @override
  Future<Result<List<CareRecord>>> getRecentWakes(
    String babyId, {
    int limit = 2,
  }) =>
      _recent(babyId, {RecordType.sleep}, limit);

  @override
  Future<Result<CareRecord>> createRecord(
    String babyId,
    RecordDetailData detail,
  ) async {
    final record = CareRecord(
      id: 'gen-${_seq++}',
      babyId: babyId,
      type: detail.type,
      detail: detail,
      createdBy: 'tester',
      createdAt: DateTime.now().toUtc(),
    );
    _store.putIfAbsent(babyId, () => []).add(record);
    return Ok(record);
  }

  @override
  Future<Result<void>> deleteRecord(String recordId) async {
    if (deleteError != null) return Error(deleteError!);
    for (final entry in _store.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((r) => r.id == recordId);
      if (entry.value.length != before) return const Ok(null);
    }
    return Error(const AppException(ErrorCode.notFound, 'record not found'));
  }

  // ── 본 통합 테스트에서 쓰지 않는 메서드 ──
  @override
  Future<Result<CareRecord>> getRecord(String recordId) async =>
      Error(const AppException(ErrorCode.notFound, 'unused'));

  @override
  Future<Result<void>> updateRecord(
    String recordId,
    RecordDetailData detail,
  ) async =>
      const Ok(null);

  @override
  Future<Result<Page<RecordMemo>>> getMemos(
    String recordId, {
    String? cursor,
    int limit = 20,
  }) async =>
      Ok(const Page(items: [], nextCursor: null, hasMore: false));

  @override
  Future<Result<RecordMemo>> addMemo(String recordId, String content) async =>
      Error(const AppException(ErrorCode.unknown, 'unused'));

  @override
  Future<Result<void>> updateMemo(String memoId, String content) async =>
      const Ok(null);

  @override
  Future<Result<void>> deleteMemo(String memoId) async => const Ok(null);
}
