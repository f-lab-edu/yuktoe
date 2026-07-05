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
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/view_models/recent_snapshot_view_model.dart';

import 'recent_snapshot_view_model_test.mocks.dart';

@GenerateMocks([RecordRepository, AppLocalStorage])
void main() {
  late MockRecordRepository repo;
  late MockAppLocalStorage storage;
  late CurrentBabyController controller;

  CareRecord record(RecordType type) => CareRecord(
    id: 'r-${type.name}',
    babyId: 'b1',
    type: type,
    detail: DiaperDetail(
      occurredAt: DateTime.utc(2026, 7, 5),
      diaperType: DiaperType.pee,
    ),
    createdBy: 'u',
    createdAt: DateTime.utc(2026, 7, 5),
  );

  setUpAll(() {
    provideDummy<Result<List<CareRecord>>>(
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

  RecentSnapshotViewModel build() => RecentSnapshotViewModel(
    recordRepository: repo,
    currentBaby: controller,
  );

  void stubAll({
    List<CareRecord>? feed,
    List<CareRecord>? diaper,
    List<CareRecord>? wake,
  }) {
    when(repo.getRecentFeedings('b1', limit: 1))
        .thenAnswer((_) async => Ok(feed ?? []));
    when(repo.getRecentDiapers('b1', limit: 1))
        .thenAnswer((_) async => Ok(diaper ?? []));
    when(repo.getRecentWakes('b1', limit: 1))
        .thenAnswer((_) async => Ok(wake ?? []));
  }

  test('loadAll: 슬롯별 success / empty', () async {
    stubAll(feed: [record(RecordType.feeding)], diaper: [], wake: [record(RecordType.sleep)]);
    final vm = build();

    await vm.loadAll();

    expect(vm.feed.status, ActionState.success);
    expect(vm.feed.record, isNotNull);
    expect(vm.diaper.isEmpty, isTrue);
    expect(vm.wake.record, isNotNull);
    addTearDown(vm.dispose);
  });

  test('슬롯 error 후 retry 는 그 슬롯만 재호출', () async {
    when(repo.getRecentFeedings('b1', limit: 1)).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.networkError, 'x')),
    );
    when(repo.getRecentDiapers('b1', limit: 1)).thenAnswer((_) async => Ok([]));
    when(repo.getRecentWakes('b1', limit: 1)).thenAnswer((_) async => Ok([]));
    final vm = build();
    await vm.loadAll();
    expect(vm.feed.status, ActionState.error);

    when(repo.getRecentFeedings('b1', limit: 1))
        .thenAnswer((_) async => Ok([record(RecordType.feeding)]));
    await vm.retryFeed();

    expect(vm.feed.status, ActionState.success);
    addTearDown(vm.dispose);
  });

  test('타입 → 슬롯 매핑: formula → feed 슬롯 재호출', () async {
    stubAll();
    final vm = build();
    await vm.loadAll();

    vm.notifyAfterRecordChanged(record(RecordType.feeding));
    await pumpEventQueue();

    verify(repo.getRecentFeedings('b1', limit: 1)).called(2); // loadAll + notify
    addTearDown(vm.dispose);
  });

  test('타입 → 슬롯 매핑: sleep → wake, diaper → diaper', () async {
    stubAll();
    final vm = build();
    await vm.loadAll();

    vm.notifyAfterRecordChanged(record(RecordType.sleep));
    vm.notifyAfterRecordChanged(record(RecordType.diaper));
    await pumpEventQueue();

    verify(repo.getRecentWakes('b1', limit: 1)).called(2);
    verify(repo.getRecentDiapers('b1', limit: 1)).called(2);
    addTearDown(vm.dispose);
  });

  test('water / snack 는 어느 슬롯에도 영향 없음', () async {
    stubAll();
    final vm = build();
    await vm.loadAll();

    vm.notifyAfterRecordChanged(record(RecordType.water));
    vm.notifyAfterRecordChanged(record(RecordType.snack));
    await pumpEventQueue();

    verify(repo.getRecentFeedings('b1', limit: 1)).called(1);
    verify(repo.getRecentDiapers('b1', limit: 1)).called(1);
    verify(repo.getRecentWakes('b1', limit: 1)).called(1);
    addTearDown(vm.dispose);
  });
}
