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
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';

import 'record_repository_impl_test.mocks.dart';

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
      recordedAt: DateTime(2025),
      detail: const DiaperDetail(diaperType: DiaperType.pee),
      createdBy: '',
      createdAt: DateTime(2025),
    )));
    provideDummy<Result<List<RecordMemo>>>(Result.ok([]));
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
        recordedAt: DateTime(2025, 3, 30, 14, 30),
        detail: const BreastDetail(leftMinutes: 10, rightMinutes: 15),
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
      final exception = AppException('조회 실패');
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
    test('sends serialized data when recordedAt and detail are provided',
        () async {
      // given
      final recordedAt = DateTime(2025, 3, 30, 15, 0);
      const detail = SleepDetail(sleepType: SleepType.nap);

      // when
      final result = await repository.updateRecord(
        'record-1',
        recordedAt: recordedAt,
        detail: detail,
      );

      // then
      expect(result, isA<Ok<void>>());
      expect(updateCallCount, 1);
      expect(lastUpdateData!['recorded_at'], recordedAt.toIso8601String());
      expect(lastUpdateData!['detail'], {
        'sleep_type': 'nap',
        'end_time': null,
      });
    });

    test('sends only detail when recordedAt is not provided', () async {
      // given
      const detail = DiaperDetail(diaperType: DiaperType.poop);

      // when
      await repository.updateRecord('record-1', detail: detail);

      // then
      expect(lastUpdateData!.containsKey('recorded_at'), isFalse);
      expect(lastUpdateData!['detail'], {'diaper_type': 'poop'});
    });

    test('does not call service when no fields are provided', () async {
      // when
      final result = await repository.updateRecord('record-1');

      // then
      expect(result, isA<Ok<void>>());
      expect(updateCallCount, 0);
    });

    test('returns Error when service returns Error', () async {
      // given
      final exception = AppException('수정 실패');
      updateResult = Result.error(exception);

      // when
      final result = await repository.updateRecord(
        'record-1',
        detail: const FormulaDetail(amountMl: 120),
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
      final exception = AppException('삭제 실패');
      when(mockService.deleteRecord('record-1'))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.deleteRecord('record-1');

      // then
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, same(exception));
    });
  });

  group('getMemos', () {
    const recordId = 'record-1';

    test('returns memo list when service returns Ok', () async {
      // given
      final memos = [
        RecordMemo(
          id: 'memo-1',
          recordId: recordId,
          content: '첫 번째 메모',
          authorId: 'user-1',
          authorName: '엄마',
          createdAt: DateTime(2025, 3, 30, 10, 0),
        ),
        RecordMemo(
          id: 'memo-2',
          recordId: recordId,
          content: '두 번째 메모',
          authorId: 'user-2',
          authorName: '아빠',
          createdAt: DateTime(2025, 3, 30, 11, 0),
        ),
      ];
      when(mockService.getMemos(recordId))
          .thenAnswer((_) async => Result.ok(memos));

      // when
      final result = await repository.getMemos(recordId);

      // then
      expect(result, isA<Ok<List<RecordMemo>>>());
      expect((result as Ok<List<RecordMemo>>).value, same(memos));
    });

    test('returns empty list when service returns Ok with no data', () async {
      // given
      when(mockService.getMemos(recordId))
          .thenAnswer((_) async => Result.ok(<RecordMemo>[]));

      // when
      final result = await repository.getMemos(recordId);

      // then
      expect(result, isA<Ok<List<RecordMemo>>>());
      expect((result as Ok<List<RecordMemo>>).value, isEmpty);
    });

    test('returns Error when service returns Error', () async {
      // given
      final exception = AppException('메모 조회 실패');
      when(mockService.getMemos(recordId))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.getMemos(recordId);

      // then
      expect(result, isA<Error<List<RecordMemo>>>());
      expect((result as Error<List<RecordMemo>>).error, same(exception));
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
      final exception = AppException('메모 생성 실패');
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
      final exception = AppException('메모 수정 실패');
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
      final exception = AppException('메모 삭제 실패');
      when(mockService.deleteMemo(memoId))
          .thenAnswer((_) async => Result.error(exception));

      // when
      final result = await repository.deleteMemo(memoId);

      // then
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, same(exception));
    });
  });

  group('updateRecord serialization', () {
    test('BreastDetail is serialized correctly', () async {
      // when
      await repository.updateRecord(
        'record-1',
        detail: const BreastDetail(leftMinutes: 10, rightMinutes: 15),
      );

      // then
      expect(lastUpdateData!['detail'], {
        'left_minutes': 10,
        'right_minutes': 15,
      });
    });

    test('PumpingDetail is serialized correctly', () async {
      // when
      await repository.updateRecord(
        'record-1',
        detail: const PumpingDetail(amountMl: 120),
      );

      // then
      expect(lastUpdateData!['detail'], {'amount_ml': 120});
    });

    test('FormulaDetail is serialized correctly', () async {
      // when
      await repository.updateRecord(
        'record-1',
        detail: const FormulaDetail(amountMl: 200),
      );

      // then
      expect(lastUpdateData!['detail'], {'amount_ml': 200});
    });

    test('SupplementDetail is serialized correctly', () async {
      // when
      await repository.updateRecord(
        'record-1',
        detail: const SupplementDetail(name: '비타민D'),
      );

      // then
      expect(lastUpdateData!['detail'], {'name': '비타민D'});
    });

    test('WaterDetail is serialized correctly', () async {
      // when
      await repository.updateRecord(
        'record-1',
        detail: const WaterDetail(amountMl: 50),
      );

      // then
      expect(lastUpdateData!['detail'], {'amount_ml': 50});
    });
  });
}
