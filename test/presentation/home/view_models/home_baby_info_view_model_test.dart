import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/view_models/home_baby_info_view_model.dart';

import 'home_baby_info_view_model_test.mocks.dart';

@GenerateMocks([BabyRepository, AppLocalStorage])
void main() {
  late MockBabyRepository repo;
  late MockAppLocalStorage storage;
  late CurrentBabyController controller;

  Baby baby(String id) =>
      Baby(id: id, name: 'Liam', gender: Gender.male);

  setUpAll(() {
    provideDummy<Result<Baby>>(
      Error(const AppException(ErrorCode.unknown, 'dummy')),
    );
  });

  setUp(() {
    repo = MockBabyRepository();
    storage = MockAppLocalStorage();
    when(storage.selectedBabyId).thenReturn('b1');
    when(storage.setSelectedBabyId(any)).thenAnswer((_) async {});
    when(storage.removeSelectedBabyId()).thenAnswer((_) async {});
    controller = CurrentBabyController(storage);
  });

  tearDown(() => controller.dispose());

  HomeBabyInfoViewModel build() => HomeBabyInfoViewModel(
    babyRepository: repo,
    currentBaby: controller,
  );

  test('load 성공 시 success + baby', () async {
    when(repo.getBaby('b1')).thenAnswer((_) async => Ok(baby('b1')));
    final vm = build();

    await vm.load();

    expect(vm.status, ActionState.success);
    expect(vm.baby, baby('b1'));
    addTearDown(vm.dispose);
  });

  test('notFound 시 error + code notFound', () async {
    when(repo.getBaby('b1')).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.notFound, 'x')),
    );
    final vm = build();

    await vm.load();

    expect(vm.status, ActionState.error);
    expect(vm.error?.code, ErrorCode.notFound);
    addTearDown(vm.dispose);
  });

  test('unauthorized 시 error + code unauthorized', () async {
    when(repo.getBaby('b1')).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.unauthorized, 'x')),
    );
    final vm = build();

    await vm.load();

    expect(vm.error?.code, ErrorCode.unauthorized);
    addTearDown(vm.dispose);
  });

  test('retry 는 재조회한다', () async {
    when(repo.getBaby('b1')).thenAnswer(
      (_) async => Error(const AppException(ErrorCode.networkError, 'x')),
    );
    final vm = build();
    await vm.load();
    expect(vm.status, ActionState.error);

    when(repo.getBaby('b1')).thenAnswer((_) async => Ok(baby('b1')));
    await vm.retry();

    expect(vm.status, ActionState.success);
    addTearDown(vm.dispose);
  });

  test('babyId 는 인자 없이 controller 에서 읽는다 (stream 변경 시 재로드)',
      () async {
    when(repo.getBaby('b1')).thenAnswer((_) async => Ok(baby('b1')));
    when(repo.getBaby('b2')).thenAnswer((_) async => Ok(baby('b2')));
    final vm = build();
    await vm.load();
    expect(vm.baby, baby('b1'));

    await controller.select('b2');
    await pumpEventQueue();

    expect(vm.baby, baby('b2'));
    verify(repo.getBaby('b2')).called(1);
    addTearDown(vm.dispose);
  });

  test('stale 응답은 폐기된다 (전환 race, spec §8.7)', () async {
    final slow = Completer<Result<Baby>>();
    when(repo.getBaby('b1')).thenAnswer((_) => slow.future);
    when(repo.getBaby('b2')).thenAnswer((_) async => Ok(baby('b2')));
    final vm = build();

    // b1 로드 in-flight.
    final loadFuture = vm.load();
    // 그 사이 b2 로 전환 → b2 로드가 먼저 끝남.
    await controller.select('b2');
    await pumpEventQueue();
    expect(vm.baby, baby('b2'));

    // 뒤늦게 b1 응답 도착 → 폐기되어야 함.
    slow.complete(Ok(baby('b1')));
    await loadFuture;
    await pumpEventQueue();

    expect(vm.baby, baby('b2'));
    addTearDown(vm.dispose);
  });
}
