import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_list_ui_state.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_list_view_model.dart';

import 'memo_list_view_model_test.mocks.dart';

@GenerateMocks([RecordRepository])
void main() {
  const recordId = 'rec-1';
  late MockRecordRepository mockRepo;

  setUpAll(() {
    provideDummy<Result<Page<RecordMemo>>>(
      Result.ok(const Page(items: [], nextCursor: null, hasMore: false)),
    );
    provideDummy<Result<void>>(Result.ok(null));
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
    mockRepo = MockRecordRepository();
  });

  MemoListViewModel makeVm({int pageSize = 20}) => MemoListViewModel(
        recordRepository: mockRepo,
        recordId: recordId,
        pageSize: pageSize,
      );

  RecordMemo memo(int n) => RecordMemo(
        id: 'memo-$n',
        recordId: recordId,
        content: '메모 $n',
        authorId: 'user-1',
        authorName: '엄마',
        createdAt: DateTime(2025, 3, 30, 10, n),
      );

  group('refresh', () {
    test('success: memoList populated, cursor updated, state Idle→Loading→Idle',
        () async {
      final items = List.generate(2, memo);
      when(mockRepo.getMemos(recordId, cursor: null, limit: 2)).thenAnswer(
        (_) async => Result.ok(
          Page(
            items: items,
            nextCursor: items.last.createdAt.toIso8601String(),
            hasMore: true,
          ),
        ),
      );

      final vm = makeVm(pageSize: 2);
      final states = <MemoListUiState>[];
      vm.addListener(() => states.add(vm.state));

      await vm.refresh();

      expect(states.map((s) => s.runtimeType).toList(),
          [MemoListLoading, MemoListIdle]);
      expect(vm.memoList, hasLength(2));
      expect(vm.hasMore, isTrue);
    });

    test('failure: state becomes Failure', () async {
      when(mockRepo.getMemos(recordId, cursor: null, limit: 20))
          .thenAnswer((_) async => Result.error(AppException('조회 실패')));
      final vm = makeVm();

      await vm.refresh();

      expect(vm.state, isA<MemoListFailure>());
      expect((vm.state as MemoListFailure).message, '조회 실패');
      expect(vm.memoList, isEmpty);
    });
  });

  group('loadMore', () {
    test('appends items to existing memoList, updates cursor', () async {
      // first page
      final first = List.generate(2, memo);
      when(mockRepo.getMemos(recordId, cursor: null, limit: 2)).thenAnswer(
        (_) async => Result.ok(
          Page(
            items: first,
            nextCursor: first.last.createdAt.toIso8601String(),
            hasMore: true,
          ),
        ),
      );
      final vm = makeVm(pageSize: 2);
      await vm.refresh();

      // second page
      final next = [memo(3)];
      when(mockRepo.getMemos(
        recordId,
        cursor: first.last.createdAt.toIso8601String(),
        limit: 2,
      )).thenAnswer((_) async => Result.ok(
            Page(items: next, nextCursor: null, hasMore: false),
          ));

      await vm.loadMore();

      expect(vm.memoList, hasLength(3));
      expect(vm.hasMore, isFalse);
    });

    test('no-op when hasMore is false', () async {
      when(mockRepo.getMemos(recordId, cursor: null, limit: 20)).thenAnswer(
        (_) async => Result.ok(const Page(
          items: [],
          nextCursor: null,
          hasMore: false,
        )),
      );
      final vm = makeVm();
      await vm.refresh();

      await vm.loadMore();

      verify(mockRepo.getMemos(recordId, cursor: null, limit: 20)).called(1);
    });
  });

  group('addMemo', () {
    test('success: append to end, return true', () async {
      final newMemo = memo(99);
      when(mockRepo.addMemo(recordId, '새 메모'))
          .thenAnswer((_) async => Result.ok(newMemo));

      final vm = makeVm();
      final ok = await vm.addMemo('새 메모');

      expect(ok, isTrue);
      expect(vm.memoList, [newMemo]);
      expect(vm.state, isA<MemoListIdle>());
    });

    test('failure: list unchanged, state Failure, return false', () async {
      when(mockRepo.addMemo(recordId, '새 메모'))
          .thenAnswer((_) async => Result.error(AppException('추가 실패')));

      final vm = makeVm();
      final ok = await vm.addMemo('새 메모');

      expect(ok, isFalse);
      expect(vm.memoList, isEmpty);
      expect(vm.state, isA<MemoListFailure>());
    });
  });

  group('updateMemo', () {
    test('success: in-place content replacement', () async {
      // seed with first page
      final items = [memo(1), memo(2)];
      when(mockRepo.getMemos(recordId, cursor: null, limit: 20)).thenAnswer(
        (_) async => Result.ok(
          Page(items: items, nextCursor: null, hasMore: false),
        ),
      );
      final vm = makeVm();
      await vm.refresh();

      when(mockRepo.updateMemo('memo-1', '수정됨'))
          .thenAnswer((_) async => Result.ok(null));

      final ok = await vm.updateMemo('memo-1', '수정됨');

      expect(ok, isTrue);
      expect(vm.memoList[0].content, '수정됨');
      expect(vm.memoList[1].content, '메모 2');
      expect(vm.memoList, hasLength(2));
    });
  });

  group('deleteMemo', () {
    test('success: memo removed from list', () async {
      final items = [memo(1), memo(2)];
      when(mockRepo.getMemos(recordId, cursor: null, limit: 20)).thenAnswer(
        (_) async => Result.ok(
          Page(items: items, nextCursor: null, hasMore: false),
        ),
      );
      final vm = makeVm();
      await vm.refresh();

      when(mockRepo.deleteMemo('memo-1'))
          .thenAnswer((_) async => Result.ok(null));

      final ok = await vm.deleteMemo('memo-1');

      expect(ok, isTrue);
      expect(vm.memoList, hasLength(1));
      expect(vm.memoList[0].id, 'memo-2');
    });
  });

  group('clearError', () {
    test('Failure → Idle, notify', () async {
      when(mockRepo.getMemos(recordId, cursor: null, limit: 20))
          .thenAnswer((_) async => Result.error(AppException('fail')));
      final vm = makeVm();
      await vm.refresh();

      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.clearError();

      expect(vm.state, isA<MemoListIdle>());
      expect(notifications, 1);
    });
  });
}
