import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/view_models/record_timeline_view_model.dart';

import 'record_timeline_view_model_test.mocks.dart';

@GenerateMocks([RecordRepository, AppLocalStorage])
void main() {
  late MockRecordRepository repo;
  late MockAppLocalStorage storage;
  late CurrentBabyController controller;

  CareRecord rec(String id) => CareRecord(
    id: id,
    babyId: 'b1',
    type: RecordType.diaper,
    detail: DiaperDetail(
      occurredAt: DateTime.utc(2026, 7, 5),
      diaperType: DiaperType.pee,
    ),
    createdBy: 'u',
    createdAt: DateTime.utc(2026, 7, 5),
  );

  Page<CareRecord> page(List<String> ids, {String? cursor, required bool hasMore}) =>
      Page(items: ids.map(rec).toList(), nextCursor: cursor, hasMore: hasMore);

  setUpAll(() {
    provideDummy<Result<Page<CareRecord>>>(
      Error(const AppException(ErrorCode.unknown, 'dummy')),
    );
    provideDummy<Result<void>>(
      Error(const AppException(ErrorCode.unknown, 'dummy')),
    );
  });

  setUp(() {
    repo = MockRecordRepository();
    storage = MockAppLocalStorage();
    when(storage.selectedBabyId).thenReturn('b1');
    when(storage.setSelectedBabyId(any)).thenAnswer((_) async {});
    controller = CurrentBabyController(storage);
  });

  tearDown(() => controller.dispose());

  RecordTimelineViewModel build() => RecordTimelineViewModel(
    recordRepository: repo,
    currentBaby: controller,
  );

  test('첫 페이지 로드', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1', 'r2'], cursor: 'c1', hasMore: true)));
    final vm = build();

    await vm.loadFirstPage();

    expect(vm.firstPageStatus, ActionState.success);
    expect(vm.items.length, 2);
    expect(vm.hasMore, isTrue);
    addTearDown(vm.dispose);
  });

  test('다음 페이지 append', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1'], cursor: 'c1', hasMore: true)));
    when(repo.getRecords('b1', cursor: 'c1', limit: 20))
        .thenAnswer((_) async => Ok(page(['r2'], cursor: null, hasMore: false)));
    final vm = build();
    await vm.loadFirstPage();

    await vm.loadNextPage();

    expect(vm.items.map((r) => r.id), ['r1', 'r2']);
    expect(vm.hasMore, isFalse);
    addTearDown(vm.dispose);
  });

  test('hasMore=false 이후 loadNextPage 는 호출하지 않는다', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1'], cursor: null, hasMore: false)));
    final vm = build();
    await vm.loadFirstPage();

    await vm.loadNextPage();

    // 첫 페이지(cursor:null) 한 번만 호출되고 다음 페이지는 호출되지 않는다.
    verify(repo.getRecords('b1', cursor: null, limit: 20)).called(1);
    verifyNoMoreInteractions(repo);
    addTearDown(vm.dispose);
  });

  test('빈 페이지 방어: hasMore=true 인데 items=[] → 멈춤', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1'], cursor: 'c1', hasMore: true)));
    when(repo.getRecords('b1', cursor: 'c1', limit: 20))
        .thenAnswer((_) async => Ok(page([], cursor: 'c2', hasMore: true)));
    final vm = build();
    await vm.loadFirstPage();

    await vm.loadNextPage();

    expect(vm.items.length, 1);
    expect(vm.hasMore, isFalse);
    addTearDown(vm.dispose);
  });

  test('prepend dedupe', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1'], cursor: null, hasMore: false)));
    final vm = build();
    await vm.loadFirstPage();

    vm.prepend(rec('new'));
    vm.prepend(rec('r1')); // 이미 존재 → 무시.

    expect(vm.items.map((r) => r.id), ['new', 'r1']);
    addTearDown(vm.dispose);
  });

  test('deleteRecord Ok → 제거', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1', 'r2'], cursor: null, hasMore: false)));
    when(repo.deleteRecord('r1')).thenAnswer((_) async => const Ok(null));
    final vm = build();
    await vm.loadFirstPage();

    await vm.deleteRecord('r1');

    expect(vm.items.map((r) => r.id), ['r2']);
    expect(vm.deleteError, isNull);
    addTearDown(vm.dispose);
  });

  test('deleteRecord notFound → 제거', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1'], cursor: null, hasMore: false)));
    when(repo.deleteRecord('r1')).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.notFound, 'x')),
    );
    final vm = build();
    await vm.loadFirstPage();

    await vm.deleteRecord('r1');

    expect(vm.items, isEmpty);
    addTearDown(vm.dispose);
  });

  test('deleteRecord 그 외 에러 → 리스트 유지 + deleteError', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1'], cursor: null, hasMore: false)));
    when(repo.deleteRecord('r1')).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.networkError, 'x')),
    );
    final vm = build();
    await vm.loadFirstPage();

    await vm.deleteRecord('r1');

    expect(vm.items.length, 1);
    expect(vm.deleteError?.code, ErrorCode.networkError);
    addTearDown(vm.dispose);
  });

  test('deleteRecord unauthorized → deleteError code unauthorized, 유지', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1'], cursor: null, hasMore: false)));
    when(repo.deleteRecord('r1')).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.unauthorized, 'x')),
    );
    final vm = build();
    await vm.loadFirstPage();

    await vm.deleteRecord('r1');

    expect(vm.items.length, 1);
    expect(vm.deleteError?.code, ErrorCode.unauthorized);
    addTearDown(vm.dispose);
  });

  test('refresh 는 첫 페이지부터 다시', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1'], cursor: 'c1', hasMore: true)));
    final vm = build();
    await vm.loadFirstPage();

    await vm.refresh();

    expect(vm.items.map((r) => r.id), ['r1']);
    verify(repo.getRecords('b1', cursor: null, limit: 20)).called(2);
    addTearDown(vm.dispose);
  });

  test('진행 중 loadNextPage 는 중복 호출을 차단한다', () async {
    when(repo.getRecords('b1', cursor: null, limit: 20))
        .thenAnswer((_) async => Ok(page(['r1'], cursor: 'c1', hasMore: true)));
    final gate = Completer<Result<Page<CareRecord>>>();
    when(repo.getRecords('b1', cursor: 'c1', limit: 20))
        .thenAnswer((_) => gate.future);
    final vm = build();
    await vm.loadFirstPage();

    final first = vm.loadNextPage(); // in-flight
    await vm.loadNextPage(); // 즉시 반환(차단)

    gate.complete(Ok(page(['r2'], cursor: null, hasMore: false)));
    await first;
    await pumpEventQueue();

    verify(repo.getRecords('b1', cursor: 'c1', limit: 20)).called(1);
    addTearDown(vm.dispose);
  });
}
