import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/view_models/sleep_stopwatch_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/stopwatch_controller.dart';

import 'sleep_stopwatch_view_model_test.mocks.dart';

@GenerateMocks([RecordRepository, AppLocalStorage])
void main() {
  late MockRecordRepository repo;
  late MockAppLocalStorage storage;
  late CurrentBabyController controller;
  late DateTime current;

  CareRecord dummy() => CareRecord(
    id: 'created',
    babyId: 'b1',
    type: RecordType.sleep,
    detail: SleepDetail(
      startedAt: DateTime.utc(2026, 7, 5),
      endedAt: DateTime.utc(2026, 7, 5),
      sleepType: SleepType.nap,
    ),
    createdBy: 'u',
    createdAt: DateTime.utc(2026, 7, 5),
  );

  setUpAll(() {
    provideDummy<Result<CareRecord>>(
      Error(const AppException(ErrorCode.unknown, 'dummy')),
    );
  });

  setUp(() {
    repo = MockRecordRepository();
    storage = MockAppLocalStorage();
    when(storage.selectedBabyId).thenReturn('b1');
    when(storage.setSelectedBabyId(any)).thenAnswer((_) async {});
    controller = CurrentBabyController(storage);
    // 낮 시각(로컬) → nap 기본.
    current = DateTime(2026, 7, 5, 14, 0, 0);
  });

  tearDown(() => controller.dispose());

  SleepStopwatchViewModel build() => SleepStopwatchViewModel(
    recordRepository: repo,
    currentBaby: controller,
    now: () => current,
    ticker: Stream<void>.empty(),
  );

  void advance(int seconds) =>
      current = current.add(Duration(seconds: seconds));

  test('idle → Start → running → pause → resume', () {
    final vm = build();
    vm.enter();
    expect(vm.phase, StopwatchPhase.idle);
    expect(vm.completeEnabled, isFalse);

    vm.toggle(); // start
    expect(vm.phase, StopwatchPhase.running);
    advance(10);
    expect(vm.seconds, 10);

    vm.toggle(); // pause
    expect(vm.phase, StopwatchPhase.paused);
    advance(5); // paused 동안 증가 안 함
    expect(vm.seconds, 10);

    vm.toggle(); // resume
    expect(vm.phase, StopwatchPhase.running);
    addTearDown(vm.dispose);
  });

  test('sleepType 자동 결정 (낮 = nap)', () async {
    when(repo.createRecord(any, any)).thenAnswer((_) async => Ok(dummy()));
    final vm = build();
    vm.enter();
    vm.toggle();
    advance(60);

    await vm.complete();

    final detail =
        verify(repo.createRecord('b1', captureAny)).captured.single as SleepDetail;
    expect(detail.sleepType, SleepType.nap);
    addTearDown(vm.dispose);
  });

  test('밤 시각이면 night', () async {
    current = DateTime(2026, 7, 5, 23, 0, 0);
    when(repo.createRecord(any, any)).thenAnswer((_) async => Ok(dummy()));
    final vm = build();
    vm.enter();
    vm.toggle();
    advance(60);

    await vm.complete();

    final detail =
        verify(repo.createRecord('b1', captureAny)).captured.single as SleepDetail;
    expect(detail.sleepType, SleepType.night);
    addTearDown(vm.dispose);
  });

  test('누적 0초에서 discard → 저장 없이 dismiss', () {
    final vm = build();
    vm.enter();

    vm.discard();

    expect(vm.active, isFalse);
    verifyNever(repo.createRecord(any, any));
    addTearDown(vm.dispose);
  });

  test('저장 실패 → retry / discard', () async {
    when(repo.createRecord(any, any)).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.networkError, 'x')),
    );
    final vm = build();
    vm.enter();
    vm.toggle();
    advance(60);

    await vm.complete();
    expect(vm.saveStatus, SaveStatus.failed);

    when(repo.createRecord(any, any)).thenAnswer((_) async => Ok(dummy()));
    await vm.retry();
    expect(vm.active, isFalse);
    addTearDown(vm.dispose);
  });
}
