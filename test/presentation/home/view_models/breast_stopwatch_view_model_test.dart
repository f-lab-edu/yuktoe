import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/view_models/breast_stopwatch_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/stopwatch_controller.dart';

import 'breast_stopwatch_view_model_test.mocks.dart';

@GenerateMocks([RecordRepository, AppLocalStorage])
void main() {
  late MockRecordRepository repo;
  late MockAppLocalStorage storage;
  late CurrentBabyController controller;
  late DateTime current;

  CareRecord dummy() => CareRecord(
    id: 'created',
    babyId: 'b1',
    type: RecordType.feeding,
    detail: BreastDetail(
      startedAt: DateTime.utc(2026, 7, 5),
      endedAt: DateTime.utc(2026, 7, 5),
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
    current = DateTime.utc(2026, 7, 5, 10, 0, 0);
  });

  tearDown(() => controller.dispose());

  BreastStopwatchViewModel build() => BreastStopwatchViewModel(
    recordRepository: repo,
    currentBaby: controller,
    now: () => current,
    ticker: Stream<void>.empty(),
  );

  void advance(int seconds) =>
      current = current.add(Duration(seconds: seconds));

  test('enter 하면 좌/우 idle, 카드 노출', () {
    final vm = build();
    vm.enter();
    expect(vm.active, isTrue);
    expect(vm.leftPhase, StopwatchPhase.idle);
    expect(vm.rightPhase, StopwatchPhase.idle);
    expect(vm.completeEnabled, isFalse);
    addTearDown(vm.dispose);
  });

  test('한쪽 running 중 다른쪽 toggle → 기존쪽 자동 paused (동시 running 불가)', () {
    final vm = build();
    vm.enter();
    vm.toggleLeft();
    expect(vm.leftPhase, StopwatchPhase.running);

    vm.toggleRight();
    expect(vm.leftPhase, StopwatchPhase.paused);
    expect(vm.rightPhase, StopwatchPhase.running);
    // 동시에 running 인 쪽은 최대 1.
    final running = [vm.leftPhase, vm.rightPhase]
        .where((p) => p == StopwatchPhase.running)
        .length;
    expect(running, 1);
    addTearDown(vm.dispose);
  });

  test('startedAt 은 처음 running 진입 시 1회만 세팅', () {
    final vm = build();
    vm.enter();
    final t0 = current;
    vm.toggleLeft();
    advance(10);
    vm.toggleLeft(); // pause
    advance(5);
    vm.toggleRight(); // 우측 running — startedAt 은 그대로 t0
    expect(vm.startedAt, t0.toUtc());
    addTearDown(vm.dispose);
  });

  test('분 변환: 29초→0, 30초→1, 90초→2', () async {
    Future<int?> leftMinutesFor(int seconds) async {
      current = DateTime.utc(2026, 7, 5, 10, 0, 0);
      when(repo.createRecord(any, any)).thenAnswer((_) async => Ok(dummy()));
      final vm = build();
      vm.enter();
      vm.toggleLeft();
      advance(seconds);
      vm.toggleLeft(); // pause → base = seconds
      await vm.complete();
      final detail = verify(repo.createRecord('b1', captureAny)).captured.single
          as BreastDetail;
      vm.dispose();
      return detail.leftMinutes;
    }

    expect(await leftMinutesFor(29), 0);
    expect(await leftMinutesFor(30), 1);
    expect(await leftMinutesFor(90), 2);
  });

  test('running 안 한 쪽은 null, 한 쪽만 값', () async {
    when(repo.createRecord(any, any)).thenAnswer((_) async => Ok(dummy()));
    final vm = build();
    vm.enter();
    vm.toggleLeft();
    advance(60);
    vm.toggleLeft();

    await vm.complete();

    final detail =
        verify(repo.createRecord('b1', captureAny)).captured.single as BreastDetail;
    expect(detail.leftMinutes, 1);
    expect(detail.rightMinutes, isNull);
    addTearDown(vm.dispose);
  });

  test('저장 실패 → failed, retry 성공 → active false', () async {
    when(repo.createRecord(any, any)).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.networkError, 'x')),
    );
    final vm = build();
    vm.enter();
    vm.toggleLeft();
    advance(60);

    await vm.complete();
    expect(vm.saveStatus, SaveStatus.failed);
    expect(vm.active, isTrue);

    when(repo.createRecord(any, any)).thenAnswer((_) async => Ok(dummy()));
    await vm.retry();
    expect(vm.active, isFalse);
    addTearDown(vm.dispose);
  });

  test('running 중에는 tick 마다 notifyListeners + 표시 시간이 진행한다 (bug #1)',
      () async {
    final tick = StreamController<void>.broadcast();
    addTearDown(tick.close);
    final vm = BreastStopwatchViewModel(
      recordRepository: repo,
      currentBaby: controller,
      now: () => current,
      ticker: tick.stream,
    );
    vm.enter();
    vm.toggleLeft(); // running
    var notifies = 0;
    vm.addListener(() => notifies++);

    current = current.add(const Duration(seconds: 3));
    tick.add(null);
    await pumpEventQueue();

    expect(vm.leftDisplay, '00:03');
    expect(notifies, greaterThan(0));
    vm.dispose();
  });

  test('완료 후 재진입해도 예외 없이 카드가 다시 뜬다 (bug #2)', () async {
    when(repo.createRecord(any, any)).thenAnswer((_) async => Ok(dummy()));
    final vm = build();
    vm.enter();
    vm.toggleLeft();
    advance(60);
    await vm.complete();
    expect(vm.active, isFalse);

    // 재진입 — 단일 구독 스트림 재-listen 예외가 없어야 한다.
    vm.enter();

    expect(vm.active, isTrue);
    expect(vm.leftPhase, StopwatchPhase.idle);
    addTearDown(vm.dispose);
  });

  test('저장 실패 후 discard → active false, 저장 안 됨', () async {
    when(repo.createRecord(any, any)).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.networkError, 'x')),
    );
    final vm = build();
    vm.enter();
    vm.toggleLeft();
    advance(60);
    await vm.complete();

    vm.discard();

    expect(vm.active, isFalse);
    addTearDown(vm.dispose);
  });
}
