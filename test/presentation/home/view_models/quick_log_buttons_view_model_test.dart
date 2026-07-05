import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/presentation/home/models/quick_log_kind.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/presentation/home/view_models/quick_log_buttons_view_model.dart';

import 'quick_log_buttons_view_model_test.mocks.dart';

@GenerateMocks([AppLocalStorage])
void main() {
  late MockAppLocalStorage storage;

  setUp(() {
    storage = MockAppLocalStorage();
    when(storage.setQuickLogButtonsJson(any)).thenAnswer((_) async {});
  });

  QuickLogButtonsViewModel build() => QuickLogButtonsViewModel(storage);

  test('저장값 없으면 기본 9종 전부 enabled, 정해진 순서', () {
    when(storage.quickLogButtonsJson).thenReturn(null);
    final vm = build()..init();

    expect(vm.buttons.length, 9);
    expect(vm.enabledButtons.length, 9);
    expect(vm.buttons.first.type, QuickLogKind.formula);
    expect(vm.buttons[1].type, QuickLogKind.breast);
  });

  test('저장된 JSON 로드 (순서 + enabled 반영)', () {
    final json = jsonEncode([
      {'type': 'water', 'enabled': false},
      {'type': 'formula', 'enabled': true},
    ]);
    when(storage.quickLogButtonsJson).thenReturn(json);
    final vm = build()..init();

    expect(vm.buttons.first.type, QuickLogKind.water);
    expect(vm.buttons.first.enabled, isFalse);
    expect(vm.buttons[1].type, QuickLogKind.formula);
    // 누락된 enum 들이 뒤에 default-on 으로 추가되어 총 9개.
    expect(vm.buttons.length, 9);
  });

  test('reorder 후 즉시 영속', () async {
    when(storage.quickLogButtonsJson).thenReturn(null);
    final vm = build()..init();

    await vm.reorder(0, 2); // formula 를 뒤로.

    expect(vm.buttons.first.type, QuickLogKind.breast);
    verify(storage.setQuickLogButtonsJson(any)).called(1);
  });

  test('toggle 후 영속', () async {
    when(storage.quickLogButtonsJson).thenReturn(null);
    final vm = build()..init();

    await vm.toggle(QuickLogKind.water);

    final water =
        vm.buttons.firstWhere((b) => b.type == QuickLogKind.water);
    expect(water.enabled, isFalse);
    verify(storage.setQuickLogButtonsJson(any)).called(1);
  });

  test('마지막 1개는 끄지 못한다', () async {
    final json = jsonEncode([
      {'type': 'formula', 'enabled': true},
      {'type': 'breast', 'enabled': false},
      {'type': 'diaper', 'enabled': false},
      {'type': 'sleep', 'enabled': false},
      {'type': 'pumping', 'enabled': false},
      {'type': 'pumpingFeed', 'enabled': false},
      {'type': 'babyFood', 'enabled': false},
      {'type': 'snack', 'enabled': false},
      {'type': 'water', 'enabled': false},
    ]);
    when(storage.quickLogButtonsJson).thenReturn(json);
    final vm = build()..init();
    expect(vm.enabledButtons.length, 1);

    await vm.toggle(QuickLogKind.formula); // 마지막 1개 → 무시.

    expect(vm.enabledButtons.length, 1);
    verifyNever(storage.setQuickLogButtonsJson(any));
  });

  test('미지의 enum 은 무시 (forward-compat)', () {
    final json = jsonEncode([
      {'type': 'teleport', 'enabled': true},
      {'type': 'formula', 'enabled': true},
    ]);
    when(storage.quickLogButtonsJson).thenReturn(json);
    final vm = build()..init();

    expect(vm.buttons.any((b) => b.type == QuickLogKind.formula), isTrue);
    expect(vm.buttons.length, 9); // 미지 항목 제외 + 누락 보충.
  });

  test('누락된 enum 은 default-on 으로 끝에 추가', () {
    final json = jsonEncode([
      {'type': 'formula', 'enabled': false},
    ]);
    when(storage.quickLogButtonsJson).thenReturn(json);
    final vm = build()..init();

    expect(vm.buttons.length, 9);
    expect(vm.buttons.first.enabled, isFalse); // formula 유지.
    expect(vm.buttons.skip(1).every((b) => b.enabled), isTrue); // 추가분 on.
  });
}
