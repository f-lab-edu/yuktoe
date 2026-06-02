import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository_impl.dart';
import 'package:yuktoe/data/services/record_service/record_service.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';

import 'record_repository_impl_test.mocks.dart';

CareRecord _record({
  required String id,
  required RecordType type,
  required RecordDetailData detail,
  String babyId = 'baby-1',
  String createdBy = 'user-1',
  DateTime? createdAt,
}) {
  return CareRecord(
    id: id,
    babyId: babyId,
    type: type,
    detail: detail,
    createdBy: createdBy,
    createdAt: createdAt ?? DateTime(2025, 3, 30, 10),
  );
}

@GenerateMocks([RecordService])
void main() {
  late MockRecordService mockService;
  late RecordRepositoryImpl repository;

  /// [updateRecord]는 non-nullable Map 파라미터 때문에
  /// Mockito의 any/captureAny를 사용할 수 없어 별도 캡처 변수를 사용한다.
  Map<String, dynamic>? lastUpdateData;
  int updateCallCount = 0;
  Result<void> updateResult = Result.ok(null);

  setUpAll(() {
    provideDummy<Result<void>>(Result.ok(null));
    provideDummy<Result<CareRecord>>(Result.ok(CareRecord(
      id: '',
      babyId: '',
      type: RecordType.diaper,
      detail: DiaperDetail(
        occurredAt: DateTime(2025),
        diaperType: DiaperType.pee,
      ),
      createdBy: '',
      createdAt: DateTime(2025),
    )));
    provideDummy<Result<Page<RecordMemo>>>(
      Result.ok(const Page(items: [], nextCursor: null, hasMore: false)),
    );
    provideDummy<Result<Page<CareRecord>>>(
      Result.ok(const Page(items: [], nextCursor: null, hasMore: false)),
    );
    provideDummy<Result<List<CareRecord>>>(
      Result.ok(const <CareRecord>[]),
    );
    provideDummy<Result<RecordMemo>>(Result.ok(RecordMemo(
      id: '',
      recordId: '',
      content: '',
      authorId: '',
      authorName: '',
      createdAt: DateTime(2025),
    )));
  });

  setUp(() {
    mockService = MockRecordService();
    repository = RecordRepositoryImpl(mockService);
    lastUpdateData = null;
    updateCallCount = 0;
    updateResult = Result.ok(null);

    // updateRecord stub with capture
    when(mockService.updateRecord(any, any)).thenAnswer((invocation) async {
      lastUpdateData = invocation.positionalArguments[1] as Map<String, dynamic>;
      updateCallCount++;
      return updateResult;
    });
  });

  group('getRecord', () {
    test('returns CareRecord when service returns Ok', () async {
      // given
      final record = CareRecord(
        id: 'record-1',
        babyId: 'baby-1',
        type: RecordType.breast,
        detail: BreastDetail(
          startedAt: DateTime(2025, 3, 30, 14, 30),
          endedAt: DateTime(2025, 3, 30, 14, 55),
          leftMinutes: 10,
          rightMinutes: 15,
        ),
        createdBy: 'user-1',
        createdAt: DateTime(2025, 3, 30, 14, 30),
      );
      when(mockService.getRecord('record-1'))
          .thenAnswer((_) async => Result.ok(record));

      // when
      final result = await repository.getRecord('record-1');

      // then
      expect(result, isA<Ok<CareRecord>>());
      expect((result as Ok<CareRecord>).value, same(record));
    });

    test('returns Error when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, '조회 실패');
      when(mockService.getRecord('record-1'))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.getRecord('record-1');
      // then
      expect(result, isA<Error<CareRecord>>());
      expect((result as Error<CareRecord>).error, same(exception));
    });
  });

  group('updateRecord', () {
    test('sends only the detail column (occurred_at derived via DB generated column)',
        () async {
      // given
      final detail = SleepDetail(
        startedAt: DateTime(2025, 3, 30, 14, 0),
        endedAt: DateTime(2025, 3, 30, 15, 0),
        sleepType: SleepType.nap,
      );

      // when
      final result = await repository.updateRecord('record-1', detail);

      // then
      expect(result, isA<Ok<void>>());
      expect(updateCallCount, 1);
      expect(lastUpdateData!.keys, ['detail']);
      expect(lastUpdateData!['detail'], detail.toJson());
    });

    test('returns Error when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, '수정 실패');
      updateResult = Result.error(exception);

      // when
      final result = await repository.updateRecord(
        'record-1',
        FormulaDetail(occurredAt: DateTime(2025), amountMl: 120),
      );

      // then
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, same(exception));
    });
  });

  group('deleteRecord', () {
    test('returns Ok when service returns Ok', () async {
      // given
      when(mockService.deleteRecord('record-1'))
          .thenAnswer((_) async => Result.ok(null));

      // when
      final result = await repository.deleteRecord('record-1');

      // then
      expect(result, isA<Ok<void>>());
    });

    test('returns Error when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, '삭제 실패');
      when(mockService.deleteRecord('record-1'))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.deleteRecord('record-1');

      // then
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, same(exception));
    });

    test('passthrough when service returns notFound', () async {
      // given
      final exception = AppException(ErrorCode.notFound, '존재하지 않음');
      when(mockService.deleteRecord('record-1'))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.deleteRecord('record-1');

      // then
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error.code, ErrorCode.notFound);
    });
  });

  group('getRecords', () {
    const babyId = 'baby-1';

    test('first page (cursor=null) passes through', () async {
      // given
      final items = [
        _record(
          id: 'r-2',
          type: RecordType.diaper,
          detail: DiaperDetail(
            occurredAt: DateTime(2025, 3, 30, 11),
            diaperType: DiaperType.pee,
          ),
        ),
        _record(
          id: 'r-1',
          type: RecordType.diaper,
          detail: DiaperDetail(
            occurredAt: DateTime(2025, 3, 30, 10),
            diaperType: DiaperType.poop,
          ),
        ),
      ];
      final page = Page<CareRecord>(
        items: items,
        nextCursor: 'r-1',
        hasMore: true,
      );
      when(mockService.getRecords(babyId, cursor: null, limit: 20))
          .thenAnswer((_) async => Result.ok(page));

      // when
      final result = await repository.getRecords(babyId);

      // then
      expect(result, isA<Ok<Page<CareRecord>>>());
      final value = (result as Ok<Page<CareRecord>>).value;
      expect(value.items, hasLength(2));
      expect(value.hasMore, isTrue);
      expect(value.nextCursor, 'r-1');
      verify(mockService.getRecords(babyId, cursor: null, limit: 20)).called(1);
    });

    test('next page (with cursor) passes cursor through', () async {
      // given
      final page = Page<CareRecord>(
        items: [
          _record(
            id: 'r-0',
            type: RecordType.diaper,
            detail: DiaperDetail(
              occurredAt: DateTime(2025, 3, 30, 9),
              diaperType: DiaperType.pee,
            ),
          ),
        ],
        nextCursor: null,
        hasMore: false,
      );
      when(mockService.getRecords(babyId, cursor: 'r-1', limit: 20))
          .thenAnswer((_) async => Result.ok(page));

      // when
      final result =
          await repository.getRecords(babyId, cursor: 'r-1');

      // then
      final value = (result as Ok<Page<CareRecord>>).value;
      expect(value.items, hasLength(1));
      expect(value.hasMore, isFalse);
      expect(value.nextCursor, isNull);
    });

    test('empty page returns empty items', () async {
      // given
      when(mockService.getRecords(babyId, cursor: null, limit: 20))
          .thenAnswer(
        (_) async => Result.ok(
          const Page<CareRecord>(
            items: [],
            nextCursor: null,
            hasMore: false,
          ),
        ),
      );

      // when
      final result = await repository.getRecords(babyId);

      // then
      final value = (result as Ok<Page<CareRecord>>).value;
      expect(value.items, isEmpty);
      expect(value.hasMore, isFalse);
      expect(value.nextCursor, isNull);
    });

    test('limit 경계 — 0 / 101 → ArgumentError', () {
      expect(
        () => repository.getRecords(babyId, limit: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.getRecords(babyId, limit: 101),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(
        mockService.getRecords(any, cursor: anyNamed('cursor'), limit: anyNamed('limit')),
      );
    });
  });

  group('getRecentFeedings', () {
    const babyId = 'baby-1';
    final feedingTypes = {
      RecordType.breast,
      RecordType.formula,
      RecordType.pumping,
      RecordType.pumpingFeed,
      RecordType.babyFood,
    };

    test('calls service with feeding type set + feedingEffectiveAt key',
        () async {
      // given
      final items = [
        _record(
          id: 'r-1',
          type: RecordType.formula,
          detail: FormulaDetail(
            occurredAt: DateTime(2025, 3, 30, 11),
            amountMl: 120,
          ),
        ),
        _record(
          id: 'r-2',
          type: RecordType.breast,
          detail: BreastDetail(
            startedAt: DateTime(2025, 3, 30, 10),
            endedAt: DateTime(2025, 3, 30, 10, 30),
          ),
        ),
      ];
      when(mockService.getRecentRecords(
        babyId,
        types: feedingTypes,
        orderKey: RecordOrderKey.feedingEffectiveAt,
        limit: 2,
      )).thenAnswer((_) async => Result.ok(items));

      // when
      final result = await repository.getRecentFeedings(babyId);

      // then
      expect(result, isA<Ok<List<CareRecord>>>());
      expect((result as Ok<List<CareRecord>>).value, hasLength(2));
      verify(mockService.getRecentRecords(
        babyId,
        types: feedingTypes,
        orderKey: RecordOrderKey.feedingEffectiveAt,
        limit: 2,
      )).called(1);
    });

    test('1건만 있을 때 길이 1 그대로', () async {
      // given
      final items = [
        _record(
          id: 'r-1',
          type: RecordType.water,
          detail: WaterDetail(
            occurredAt: DateTime(2025, 3, 30, 10),
            amountMl: 50,
          ),
        ),
      ];
      when(mockService.getRecentRecords(
        babyId,
        types: feedingTypes,
        orderKey: RecordOrderKey.feedingEffectiveAt,
        limit: 2,
      )).thenAnswer((_) async => Result.ok(items));

      // when
      final result = await repository.getRecentFeedings(babyId);

      // then
      expect((result as Ok<List<CareRecord>>).value, hasLength(1));
    });

    test('빈 결과 → Ok([])', () async {
      // given
      when(mockService.getRecentRecords(
        babyId,
        types: feedingTypes,
        orderKey: RecordOrderKey.feedingEffectiveAt,
        limit: 2,
      )).thenAnswer((_) async => Result.ok(const []));

      // when
      final result = await repository.getRecentFeedings(babyId);

      // then
      expect((result as Ok<List<CareRecord>>).value, isEmpty);
    });

    test('limit 경계 — 0 / 11 → ArgumentError', () {
      expect(
        () => repository.getRecentFeedings(babyId, limit: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.getRecentFeedings(babyId, limit: 11),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(mockService.getRecentRecords(
        any,
        types: anyNamed('types'),
        orderKey: anyNamed('orderKey'),
        limit: anyNamed('limit'),
      ));
    });
  });

  group('getRecentDiapers', () {
    const babyId = 'baby-1';

    test('calls service with {diaper} + occurredAt key', () async {
      // given
      final items = [
        _record(
          id: 'r-1',
          type: RecordType.diaper,
          detail: DiaperDetail(
            occurredAt: DateTime(2025, 3, 30, 12),
            diaperType: DiaperType.mixed,
          ),
        ),
      ];
      when(mockService.getRecentRecords(
        babyId,
        types: {RecordType.diaper},
        orderKey: RecordOrderKey.occurredAt,
        limit: 2,
      )).thenAnswer((_) async => Result.ok(items));

      // when
      final result = await repository.getRecentDiapers(babyId);

      // then
      expect((result as Ok<List<CareRecord>>).value, hasLength(1));
      verify(mockService.getRecentRecords(
        babyId,
        types: {RecordType.diaper},
        orderKey: RecordOrderKey.occurredAt,
        limit: 2,
      )).called(1);
    });

    test('limit 경계 — 0 / 11 → ArgumentError', () {
      expect(
        () => repository.getRecentDiapers(babyId, limit: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.getRecentDiapers(babyId, limit: 11),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('getRecentWakes', () {
    const babyId = 'baby-1';

    test('calls service with {sleep} + endedAt key', () async {
      // given
      final items = [
        _record(
          id: 'r-1',
          type: RecordType.sleep,
          detail: SleepDetail(
            startedAt: DateTime(2025, 3, 30, 9),
            endedAt: DateTime(2025, 3, 30, 11),
            sleepType: SleepType.nap,
          ),
        ),
      ];
      when(mockService.getRecentRecords(
        babyId,
        types: {RecordType.sleep},
        orderKey: RecordOrderKey.endedAt,
        limit: 2,
      )).thenAnswer((_) async => Result.ok(items));

      // when
      final result = await repository.getRecentWakes(babyId);

      // then
      expect((result as Ok<List<CareRecord>>).value, hasLength(1));
      verify(mockService.getRecentRecords(
        babyId,
        types: {RecordType.sleep},
        orderKey: RecordOrderKey.endedAt,
        limit: 2,
      )).called(1);
    });

    test('limit 경계 — 0 / 11 → ArgumentError', () {
      expect(
        () => repository.getRecentWakes(babyId, limit: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.getRecentWakes(babyId, limit: 11),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('createRecord', () {
    const babyId = 'baby-1';

    test('passes babyId + detail to service (userId 비전달)', () async {
      // given
      final detail = FormulaDetail(
        occurredAt: DateTime(2025, 3, 30, 11),
        amountMl: 120,
      );
      final created = _record(
        id: 'r-new',
        type: RecordType.formula,
        detail: detail,
      );
      when(mockService.createRecord(babyId, detail))
          .thenAnswer((_) async => Result.ok(created));

      // when
      final result = await repository.createRecord(babyId, detail);

      // then
      expect(result, isA<Ok<CareRecord>>());
      expect((result as Ok<CareRecord>).value, same(created));
      verify(mockService.createRecord(babyId, detail)).called(1);
    });

    test('returns Error when service returns Error', () async {
      // given
      final detail = WaterDetail(
        occurredAt: DateTime(2025, 3, 30, 13),
        amountMl: 60,
      );
      final exception = AppException(ErrorCode.unauthorized, 'no auth');
      when(mockService.createRecord(babyId, detail))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.createRecord(babyId, detail);

      // then
      expect(result, isA<Error<CareRecord>>());
      expect((result as Error<CareRecord>).error, same(exception));
    });
  });

  group('getMemos', () {
    const recordId = 'record-1';

    RecordMemo memo(int n) => RecordMemo(
          id: 'memo-$n',
          recordId: recordId,
          content: '메모 $n',
          authorId: 'user-1',
          authorName: '엄마',
          createdAt: DateTime(2025, 3, 30, 10, n),
        );

    test('first page (cursor=null) returns limit items with hasMore and nextCursor',
        () async {
      // given
      final items = List.generate(2, memo);
      final page = Page(
        items: items,
        nextCursor: items.last.createdAt.toIso8601String(),
        hasMore: true,
      );
      when(mockService.getMemos(recordId, cursor: null, limit: 2))
          .thenAnswer((_) async => Result.ok(page));

      // when
      final result = await repository.getMemos(recordId, limit: 2);

      // then
      expect(result, isA<Ok<Page<RecordMemo>>>());
      final value = (result as Ok<Page<RecordMemo>>).value;
      expect(value.items, hasLength(2));
      expect(value.hasMore, isTrue);
      expect(value.nextCursor, items.last.createdAt.toIso8601String());
    });

    test('next page (with cursor) returns subsequent items and ends with hasMore=false',
        () async {
      // given
      final cursor = DateTime(2025, 3, 30, 10, 0).toIso8601String();
      final items = [memo(3)];
      final page = Page<RecordMemo>(
        items: items,
        nextCursor: null,
        hasMore: false,
      );
      when(mockService.getMemos(recordId, cursor: cursor, limit: 2))
          .thenAnswer((_) async => Result.ok(page));

      // when
      final result =
          await repository.getMemos(recordId, cursor: cursor, limit: 2);

      // then
      expect(result, isA<Ok<Page<RecordMemo>>>());
      final value = (result as Ok<Page<RecordMemo>>).value;
      expect(value.items, hasLength(1));
      expect(value.hasMore, isFalse);
      expect(value.nextCursor, isNull);
    });

    test('empty result returns empty items, hasMore=false, nextCursor=null',
        () async {
      // given
      when(mockService.getMemos(recordId, cursor: null, limit: 20))
          .thenAnswer(
        (_) async => Result.ok(
          const Page<RecordMemo>(
            items: [],
            nextCursor: null,
            hasMore: false,
          ),
        ),
      );

      // when
      final result = await repository.getMemos(recordId);

      // then
      expect(result, isA<Ok<Page<RecordMemo>>>());
      final value = (result as Ok<Page<RecordMemo>>).value;
      expect(value.items, isEmpty);
      expect(value.hasMore, isFalse);
      expect(value.nextCursor, isNull);
    });

    test('exactly limit items returns hasMore=false (limit+1 trick)',
        () async {
      // given: service가 limit+1 트릭을 적용한 결과 — 정확히 limit 개일 때 hasMore=false
      final items = List.generate(2, memo);
      final page = Page<RecordMemo>(
        items: items,
        nextCursor: null,
        hasMore: false,
      );
      when(mockService.getMemos(recordId, cursor: null, limit: 2))
          .thenAnswer((_) async => Result.ok(page));

      // when
      final result = await repository.getMemos(recordId, limit: 2);

      // then
      final value = (result as Ok<Page<RecordMemo>>).value;
      expect(value.items, hasLength(2));
      expect(value.hasMore, isFalse);
      expect(value.nextCursor, isNull);
    });

    test('returns Error when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, '메모 조회 실패');
      when(mockService.getMemos(recordId, cursor: null, limit: 20))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.getMemos(recordId);

      // then
      expect(result, isA<Error<Page<RecordMemo>>>());
      expect((result as Error<Page<RecordMemo>>).error, same(exception));
    });
  });

  group('addMemo', () {
    const recordId = 'record-1';
    const content = '새 메모';

    test('returns RecordMemo when service returns Ok', () async {
      // given
      final memo = RecordMemo(
        id: 'memo-1',
        recordId: recordId,
        content: content,
        authorId: 'user-1',
        authorName: '엄마',
        createdAt: DateTime(2025, 3, 30, 10, 0),
      );
      when(mockService.createMemo(recordId, content))
          .thenAnswer((_) async => Result.ok(memo));

      // when
      final result = await repository.addMemo(recordId, content);

      // then
      expect(result, isA<Ok<RecordMemo>>());
      expect((result as Ok<RecordMemo>).value, same(memo));
    });

    test('returns Error when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, '메모 생성 실패');
      when(mockService.createMemo(recordId, content))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.addMemo(recordId, content);

      // then
      expect(result, isA<Error<RecordMemo>>());
      expect((result as Error<RecordMemo>).error, same(exception));
    });
  });

  group('updateMemo', () {
    const memoId = 'memo-1';
    const content = '수정된 메모';

    test('returns Ok when service returns Ok', () async {
      // given
      when(mockService.updateMemo(memoId, content))
          .thenAnswer((_) async => Result.ok(null));

      // when
      final result = await repository.updateMemo(memoId, content);

      // then
      expect(result, isA<Ok<void>>());
    });

    test('returns Error when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, '메모 수정 실패');
      when(mockService.updateMemo(memoId, content))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.updateMemo(memoId, content);

      // then
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, same(exception));
    });
  });

  group('deleteMemo', () {
    const memoId = 'memo-1';

    test('returns Ok when service returns Ok', () async {
      // given
      when(mockService.deleteMemo(memoId))
          .thenAnswer((_) async => Result.ok(null));

      // when
      final result = await repository.deleteMemo(memoId);

      // then
      expect(result, isA<Ok<void>>());
    });

    test('returns Error when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, '메모 삭제 실패');
      when(mockService.deleteMemo(memoId))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.deleteMemo(memoId);

      // then
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, same(exception));
    });
  });

  group('detail serialization (toJson)', () {
    test('BreastDetail', () {
      final detail = BreastDetail(
        startedAt: DateTime(2025, 3, 30, 14, 0),
        endedAt: DateTime(2025, 3, 30, 14, 25),
        leftMinutes: 10,
        rightMinutes: 15,
      );
      expect(detail.toJson(), {
        'started_at': DateTime(2025, 3, 30, 14, 0).toIso8601String(),
        'ended_at': DateTime(2025, 3, 30, 14, 25).toIso8601String(),
        'left_minutes': 10,
        'right_minutes': 15,
      });
      expect(detail.occurredAt, detail.startedAt);
    });

    test('SleepDetail', () {
      final detail = SleepDetail(
        startedAt: DateTime(2025, 3, 30, 13, 0),
        endedAt: DateTime(2025, 3, 30, 14, 30),
        sleepType: SleepType.nap,
      );
      expect(detail.toJson(), {
        'started_at': DateTime(2025, 3, 30, 13, 0).toIso8601String(),
        'ended_at': DateTime(2025, 3, 30, 14, 30).toIso8601String(),
        'sleep_type': 'nap',
      });
      expect(detail.occurredAt, detail.startedAt);
    });

    test('PumpingDetail (left + right amounts)', () {
      final detail = PumpingDetail(
        occurredAt: DateTime(2025, 3, 30, 10, 0),
        leftAmountMl: 60,
        rightAmountMl: 50,
      );
      expect(detail.toJson(), {
        'occurred_at': DateTime(2025, 3, 30, 10, 0).toIso8601String(),
        'left_amount_ml': 60,
        'right_amount_ml': 50,
      });
    });

    test('PumpingFeedDetail', () {
      final detail = PumpingFeedDetail(
        occurredAt: DateTime(2025, 3, 30, 11, 0),
        amountMl: 150,
      );
      expect(detail.toJson(), {
        'occurred_at': DateTime(2025, 3, 30, 11, 0).toIso8601String(),
        'amount_ml': 150,
      });
    });

    test('FormulaDetail', () {
      final detail = FormulaDetail(
        occurredAt: DateTime(2025, 3, 30, 11, 0),
        amountMl: 200,
      );
      expect(detail.toJson(), {
        'occurred_at': DateTime(2025, 3, 30, 11, 0).toIso8601String(),
        'amount_ml': 200,
      });
    });

    test('DiaperDetail', () {
      final detail = DiaperDetail(
        occurredAt: DateTime(2025, 3, 30, 12, 0),
        diaperType: DiaperType.poop,
      );
      expect(detail.toJson(), {
        'occurred_at': DateTime(2025, 3, 30, 12, 0).toIso8601String(),
        'diaper_type': 'poop',
      });
    });

    test('BabyFoodDetail', () {
      final detail = BabyFoodDetail(
        occurredAt: DateTime(2025, 3, 30, 12, 30),
        name: '단호박 이유식',
        amountMl: 80,
      );
      expect(detail.toJson(), {
        'occurred_at': DateTime(2025, 3, 30, 12, 30).toIso8601String(),
        'name': '단호박 이유식',
        'amount_ml': 80,
      });
    });

    test('SnackDetail', () {
      final detail = SnackDetail(
        occurredAt: DateTime(2025, 3, 30, 9, 0),
        name: '바나나',
      );
      expect(detail.toJson(), {
        'occurred_at': DateTime(2025, 3, 30, 9, 0).toIso8601String(),
        'name': '바나나',
      });
    });

    test('WaterDetail', () {
      final detail = WaterDetail(
        occurredAt: DateTime(2025, 3, 30, 15, 0),
        amountMl: 50,
      );
      expect(detail.toJson(), {
        'occurred_at': DateTime(2025, 3, 30, 15, 0).toIso8601String(),
        'amount_ml': 50,
      });
    });
  });

  group('detail deserialization (fromJson)', () {
    test('BreastDetail round-trip', () {
      final original = BreastDetail(
        startedAt: DateTime(2025, 3, 30, 14, 0),
        endedAt: DateTime(2025, 3, 30, 14, 25),
        leftMinutes: 10,
        rightMinutes: 15,
      );
      final decoded = RecordDetailData.fromJson(
        RecordType.breast,
        original.toJson(),
      ) as BreastDetail;
      expect(decoded.startedAt, original.startedAt);
      expect(decoded.endedAt, original.endedAt);
      expect(decoded.leftMinutes, original.leftMinutes);
      expect(decoded.rightMinutes, original.rightMinutes);
    });

    test('SleepDetail round-trip', () {
      final original = SleepDetail(
        startedAt: DateTime(2025, 3, 30, 13, 0),
        endedAt: DateTime(2025, 3, 30, 14, 30),
        sleepType: SleepType.night,
      );
      final decoded = RecordDetailData.fromJson(
        RecordType.sleep,
        original.toJson(),
      ) as SleepDetail;
      expect(decoded.startedAt, original.startedAt);
      expect(decoded.endedAt, original.endedAt);
      expect(decoded.sleepType, original.sleepType);
    });

    test('DiaperDetail round-trip', () {
      final original = DiaperDetail(
        occurredAt: DateTime(2025, 3, 30, 12, 0),
        diaperType: DiaperType.poop,
      );
      final decoded = RecordDetailData.fromJson(
        RecordType.diaper,
        original.toJson(),
      ) as DiaperDetail;
      expect(decoded.occurredAt, original.occurredAt);
      expect(decoded.diaperType, original.diaperType);
    });
  });
}
