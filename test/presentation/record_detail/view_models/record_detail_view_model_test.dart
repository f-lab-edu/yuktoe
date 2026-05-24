import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_ui_state.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_view_model.dart';

import 'record_detail_view_model_test.mocks.dart';

@GenerateMocks([RecordRepository])
void main() {
  late MockRecordRepository mockRepo;
  late CareRecord initialRecord;

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
    initialRecord = CareRecord(
      id: 'rec-1',
      babyId: 'baby-1',
      type: RecordType.diaper,
      detail: DiaperDetail(
        occurredAt: DateTime(2025, 3, 30, 14, 30),
        diaperType: DiaperType.pee,
      ),
      createdBy: 'user-1',
      createdAt: DateTime(2025, 3, 30, 14, 30),
    );
  });

  RecordDetailViewModel makeVm() => RecordDetailViewModel(
        recordRepository: mockRepo,
        initialRecord: initialRecord,
      );

  group('initial state', () {
    test('record == initialRecord, state == Idle, no draft', () {
      final vm = makeVm();
      expect(vm.record, same(initialRecord));
      expect(vm.state, isA<RecordDetailIdle>());
      expect(vm.hasPendingChanges, isFalse);
      expect(vm.displayedDetail, same(initialRecord.detail));
    });
  });

  group('draft pattern', () {
    test('stageDetail sets pending change and displayedDetail', () {
      final vm = makeVm();
      var notifications = 0;
      vm.addListener(() => notifications++);

      final newDetail = DiaperDetail(
        occurredAt: DateTime(2025, 3, 30, 15, 0),
        diaperType: DiaperType.poop,
      );
      vm.stageDetail(newDetail);

      expect(vm.hasPendingChanges, isTrue);
      expect(vm.displayedDetail, same(newDetail));
      expect(vm.state, isA<RecordDetailIdle>());
      expect(notifications, 1);
    });

    test('discardDraft restores original detail', () {
      final vm = makeVm();
      vm.stageDetail(DiaperDetail(
        occurredAt: DateTime(2025, 3, 30, 15, 0),
        diaperType: DiaperType.poop,
      ));

      vm.discardDraft();

      expect(vm.hasPendingChanges, isFalse);
      expect(vm.displayedDetail, same(initialRecord.detail));
    });
  });

  group('commitChanges', () {
    test('without draft: no repo call, state unchanged', () async {
      final vm = makeVm();
      await vm.commitChanges();
      verifyNever(mockRepo.updateRecord(any, any));
      expect(vm.state, isA<RecordDetailIdle>());
    });

    test('success: Idle → Loading(update) → Idle, record updated, draft cleared',
        () async {
      final newDetail = DiaperDetail(
        occurredAt: DateTime(2025, 3, 30, 15, 0),
        diaperType: DiaperType.poop,
      );
      when(mockRepo.updateRecord('rec-1', newDetail))
          .thenAnswer((_) async => Result.ok(null));

      final vm = makeVm();
      vm.stageDetail(newDetail);

      final states = <RecordDetailUiState>[];
      vm.addListener(() => states.add(vm.state));

      await vm.commitChanges();

      expect(
        states.map((s) => s.runtimeType).toList(),
        [RecordDetailLoading, RecordDetailIdle],
      );
      final loading = states.first as RecordDetailLoading;
      expect(loading.action, RecordDetailAction.update);
      expect(vm.hasPendingChanges, isFalse);
      expect(vm.record.detail, same(newDetail));
    });

    test('failure: Idle → Loading(update) → Failure, draft retained', () async {
      final newDetail = DiaperDetail(
        occurredAt: DateTime(2025, 3, 30, 15, 0),
        diaperType: DiaperType.poop,
      );
      when(mockRepo.updateRecord('rec-1', newDetail))
          .thenAnswer((_) async => Result.error(AppException('수정 실패')));

      final vm = makeVm();
      vm.stageDetail(newDetail);
      await vm.commitChanges();

      expect(vm.state, isA<RecordDetailFailure>());
      expect((vm.state as RecordDetailFailure).message, '수정 실패');
      expect(vm.hasPendingChanges, isTrue);
      expect(vm.record.detail, same(initialRecord.detail));
    });
  });

  group('deleteRecord', () {
    test('success: Idle → Loading(delete) → Deleted', () async {
      when(mockRepo.deleteRecord('rec-1'))
          .thenAnswer((_) async => Result.ok(null));

      final vm = makeVm();
      final states = <RecordDetailUiState>[];
      vm.addListener(() => states.add(vm.state));

      await vm.deleteRecord();

      expect(states.length, 2);
      expect(states[0], isA<RecordDetailLoading>());
      expect((states[0] as RecordDetailLoading).action,
          RecordDetailAction.delete);
      expect(states[1], isA<RecordDetailDeleted>());
    });

    test('failure: Idle → Loading(delete) → Failure', () async {
      when(mockRepo.deleteRecord('rec-1'))
          .thenAnswer((_) async => Result.error(AppException('삭제 실패')));

      final vm = makeVm();
      await vm.deleteRecord();

      expect(vm.state, isA<RecordDetailFailure>());
      expect((vm.state as RecordDetailFailure).message, '삭제 실패');
    });
  });

  group('clearError', () {
    test('Failure → Idle, notify', () async {
      when(mockRepo.deleteRecord('rec-1'))
          .thenAnswer((_) async => Result.error(AppException('삭제 실패')));
      final vm = makeVm();
      await vm.deleteRecord();
      expect(vm.state, isA<RecordDetailFailure>());

      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.clearError();

      expect(vm.state, isA<RecordDetailIdle>());
      expect(notifications, 1);
    });

    test('no-op when state is not Failure', () {
      final vm = makeVm();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.clearError();

      expect(vm.state, isA<RecordDetailIdle>());
      expect(notifications, 0);
    });
  });
}
