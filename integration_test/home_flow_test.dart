import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';

import 'support/fake_repositories.dart';
import 'support/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Baby baby(String id, String name) =>
      Baby(id: id, name: name, birthDate: DateTime.utc(2026, 3, 1), gender: Gender.male);

  CareRecord formula(String id, int ml, DateTime at) => CareRecord(
    id: id,
    babyId: 'b1',
    type: RecordType.formula,
    detail: FormulaDetail(occurredAt: at, amountMl: ml),
    createdBy: 'u',
    createdAt: at,
  );

  CareRecord diaper(String id, DateTime at) => CareRecord(
    id: id,
    babyId: 'b1',
    type: RecordType.diaper,
    detail: DiaperDetail(occurredAt: at, diaperType: DiaperType.pee),
    createdBy: 'u',
    createdAt: at,
  );

  late FakeBabyRepository babyRepo;
  late FakeRecordRepository recordRepo;
  late SharedPreferences prefs;

  Future<void> initPrefs({String? selected = 'b1'}) async {
    SharedPreferences.setMockInitialValues(
      selected == null ? {} : {'selected_baby_id': selected},
    );
    prefs = await SharedPreferences.getInstance();
  }

  setUp(() {
    babyRepo = FakeBabyRepository([baby('b1', 'Liam'), baby('b2', 'Noah')]);
    recordRepo = FakeRecordRepository();
  });

  testWidgets('첫 진입: 헤더에 아기 이름, 리스트에 기록이 보인다', (tester) async {
    await initPrefs();
    recordRepo.seed('b1', [
      formula('r1', 160, DateTime.utc(2026, 7, 5, 3, 0)),
      diaper('r2', DateTime.utc(2026, 7, 5, 2, 0)),
    ]);

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Liam'), findsOneWidget);
    // chip 텍스트는 리스트 항목에만 나타난다(버튼 라벨과 구분).
    expect(find.text('160ml'), findsWidgets);
    expect(find.text('소변'), findsWidgets);
  });

  testWidgets('빠른 기록 생성: formula dialog → 저장 → 리스트 맨 앞에 반영', (tester) async {
    await initPrefs();
    recordRepo.seed('b1', [diaper('r2', DateTime.utc(2026, 7, 5, 2, 0))]);

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
    ));
    await tester.pumpAndSettle();

    // 생성 전에는 분유 기록(160ml chip)이 없다.
    expect(find.text('160ml'), findsNothing);

    await tester.tap(find.byKey(const Key('quick_log_button_formula')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '160');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('input_save_button')));
    await tester.pumpAndSettle();

    // 생성 후 리스트에 분유 기록이 나타난다.
    expect(find.text('160ml'), findsWidgets);
  });

  testWidgets('삭제: swipe → 확인 dialog → 리스트에서 제거', (tester) async {
    await initPrefs();
    recordRepo.seed('b1', [
      formula('r1', 160, DateTime.utc(2026, 7, 5, 3, 0)),
    ]);

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
    ));
    await tester.pumpAndSettle();
    expect(find.text('160ml'), findsWidgets);

    await tester.drag(
      find.byKey(const Key('timeline_item_r1')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    // 삭제 확인 dialog.
    expect(find.text('이 기록을 삭제할까요?'), findsOneWidget);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('160ml'), findsNothing);
    expect(find.text('아직 기록이 없어요'), findsOneWidget);
  });

  testWidgets('baby 전환: bottom sheet 에서 다른 아기 선택 → 헤더/리스트 갱신',
      (tester) async {
    await initPrefs();
    recordRepo.seed('b1', [formula('r1', 160, DateTime.utc(2026, 7, 5, 3, 0))]);
    recordRepo.seed('b2', [diaper('r9', DateTime.utc(2026, 7, 5, 4, 0))]);

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Liam'), findsOneWidget);

    await tester.tap(find.byKey(const Key('baby_name_tap_area')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('baby_switch_b2')));
    await tester.pumpAndSettle();

    expect(find.text('Noah'), findsOneWidget);
    expect(find.text('소변'), findsWidgets); // b2 의 기저귀 기록 chip.
  });

  testWidgets('quick-log 커스터마이즈: 설정에서 water off → 홈 버튼 사라짐',
      (tester) async {
    await initPrefs();
    recordRepo.seed('b1', []);

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_log_button_water')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick_log_settings_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_log_setting_water')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick_log_button_water')), findsNothing);
  });

  testWidgets('수면 스탑워치: 시작 → 시간 경과 → 완료 → 리스트에 수면 기록', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initPrefs();
    recordRepo.seed('b1', []);
    final clock = TestClock(DateTime(2026, 7, 5, 14, 0, 0));
    final tick = StreamController<void>.broadcast();
    addTearDown(tick.close);

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
      clock: clock.now,
      stopwatchTicker: tick.stream,
    ));
    await tester.pumpAndSettle();

    // 수면 버튼 → 카드 노출.
    await tester.tap(find.byKey(const Key('quick_log_button_sleep')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stopwatch_card')), findsOneWidget);

    // Start → 시간 경과 → tick 으로 rebuild.
    await tester.tap(find.byKey(const Key('sleep_toggle')));
    await tester.pumpAndSettle();
    clock.advance(const Duration(minutes: 2));
    tick.add(null);
    await tester.pumpAndSettle();

    // 완료 → 저장 → 카드 사라지고 리스트에 수면 기록.
    await tester.tap(find.byKey(const Key('sleep_complete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stopwatch_card')), findsNothing);
    expect(find.text('2분'), findsWidgets); // 수면 기록 chip (2분 지속).
  });

  testWidgets('모유수유 완료 후 수면 버튼 → 수면 카드가 뜬다 (bug #2)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initPrefs();
    recordRepo.seed('b1', []);
    final clock = TestClock(DateTime(2026, 7, 5, 14, 0, 0));
    final tick = StreamController<void>.broadcast();
    addTearDown(tick.close);

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
      clock: clock.now,
      stopwatchTicker: tick.stream,
    ));
    await tester.pumpAndSettle();

    // 모유수유 시작 → 진행 → 완료.
    await tester.tap(find.byKey(const Key('quick_log_button_breast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('breast_toggle_left')));
    await tester.pumpAndSettle();
    clock.advance(const Duration(minutes: 2));
    tick.add(null);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('breast_complete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stopwatch_card')), findsNothing);

    // 완료 직후 수면 버튼 → 수면 카드가 떠야 한다.
    await tester.tap(find.byKey(const Key('quick_log_button_sleep')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stopwatch_card')), findsOneWidget);
    expect(find.text('수면 타이머'), findsOneWidget);
  });

  testWidgets('타이머 닫기(X): 시작 안 한 카드는 바로 닫힌다 (취소 루트)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initPrefs();
    recordRepo.seed('b1', []);

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick_log_button_sleep')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stopwatch_card')), findsOneWidget);

    // 누적 0초 → 확인 없이 바로 닫힘.
    await tester.tap(find.byKey(const Key('stopwatch_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stopwatch_card')), findsNothing);
  });

  testWidgets('타이머 닫기(X): 진행된 카드는 확인 후 종료', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initPrefs();
    recordRepo.seed('b1', []);
    final clock = TestClock(DateTime(2026, 7, 5, 14, 0, 0));
    final tick = StreamController<void>.broadcast();
    addTearDown(tick.close);

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
      clock: clock.now,
      stopwatchTicker: tick.stream,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick_log_button_sleep')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sleep_toggle'))); // start
    await tester.pumpAndSettle();
    clock.advance(const Duration(minutes: 1));
    tick.add(null);
    await tester.pumpAndSettle();

    // 진행 중 → 닫기 시 확인 dialog.
    await tester.tap(find.byKey(const Key('stopwatch_close')));
    await tester.pumpAndSettle();
    expect(find.text('종료'), findsOneWidget);
    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stopwatch_card')), findsNothing);
    // 기록되지 않았으므로 타임라인은 여전히 비어 있다.
    expect(find.text('아직 기록이 없어요'), findsOneWidget);
  });

  testWidgets('아기 목록이 비면 welcome 라우트로 전역 분기', (tester) async {
    await initPrefs(selected: null);
    babyRepo = FakeBabyRepository([]); // 빈 목록 = notFound.

    await tester.pumpWidget(buildHomeTestApp(
      babyRepo: babyRepo,
      recordRepo: recordRepo,
      prefs: prefs,
    ));
    await tester.pumpAndSettle();

    expect(find.text('WELCOME_ROUTE'), findsOneWidget);
  });
}
