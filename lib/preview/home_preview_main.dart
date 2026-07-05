// 홈 화면 미리보기 실행 타깃 (개발용).
//
// 실제 백엔드/로그인 없이 인메모리 fake repository 로 [HomeScreen] 만 띄운다.
// 실행: `flutter run -t lib/preview/home_preview_main.dart`
//
// 프로덕션 코드가 아니며 앱 번들의 정상 진입점(main.dart)과 무관하다.
import 'package:flutter/material.dart' hide Page;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuktoe/constants/enum/diaper_type.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/baby/baby_list_item.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = AppLocalStorage(prefs);

  final babyRepo = _PreviewBabyRepository();
  final recordRepo = _PreviewRecordRepository()..seedDemo();

  runApp(_PreviewApp(
    babyRepo: babyRepo,
    recordRepo: recordRepo,
    storage: storage,
  ));
}

class _PreviewApp extends StatelessWidget {
  final BabyRepository babyRepo;
  final RecordRepository recordRepo;
  final AppLocalStorage storage;

  const _PreviewApp({
    required this.babyRepo,
    required this.recordRepo,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/welcome',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('welcome (preview)'))),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('login (preview)'))),
        ),
      ],
    );

    return MultiProvider(
      providers: [
        Provider<BabyRepository>.value(value: babyRepo),
        Provider<RecordRepository>.value(value: recordRepo),
        Provider<AppLocalStorage>.value(value: storage),
        Provider<CurrentBabyController>(
          create: (_) => CurrentBabyController(storage),
          dispose: (_, c) => c.dispose(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Yuktoe Home Preview',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        routerConfig: router,
      ),
    );
  }
}

class _PreviewBabyRepository implements BabyRepository {
  final _babies = [
    Baby(
      id: 'b1',
      name: '리암',
      birthDate: DateTime.utc(2026, 3, 5),
      gender: Gender.male,
    ),
    Baby(id: 'b2', name: '노아', birthDate: DateTime.utc(2026, 5, 20), gender: Gender.female),
  ];

  @override
  Future<Result<List<BabyListItem>>> getMyBabies() async =>
      Ok(_babies.map((b) => BabyListItem(id: b.id, name: b.name)).toList());

  @override
  Future<Result<Baby>> getBaby(String babyId) async {
    for (final b in _babies) {
      if (b.id == babyId) return Ok(b);
    }
    return Error(const AppException(ErrorCode.notFound, 'not found'));
  }
}

class _PreviewRecordRepository implements RecordRepository {
  final Map<String, List<CareRecord>> _store = {};
  int _seq = 0;

  void seedDemo() {
    final now = DateTime.now().toUtc();
    CareRecord r(RecordDetailData detail) => CareRecord(
      id: 'seed-${_seq++}',
      babyId: 'b1',
      type: detail.type,
      detail: detail,
      createdBy: 'demo',
      createdAt: detail.occurredAt,
    );

    _store['b1'] = [
      r(FormulaDetail(occurredAt: now.subtract(const Duration(hours: 1)), amountMl: 160)),
      r(DiaperDetail(occurredAt: now.subtract(const Duration(hours: 2)), diaperType: DiaperType.mixed)),
      r(SleepDetail(
        startedAt: now.subtract(const Duration(hours: 5)),
        endedAt: now.subtract(const Duration(hours: 3)),
        sleepType: SleepType.nap,
      )),
      r(BabyFoodDetail(occurredAt: now.subtract(const Duration(hours: 6)), name: '단호박', amountMl: 80)),
      r(PumpingDetail(occurredAt: now.subtract(const Duration(hours: 8)), leftAmountMl: 40, rightAmountMl: 50)),
      r(WaterDetail(occurredAt: now.subtract(const Duration(days: 1, hours: 2)), amountMl: 30)),
      r(SnackDetail(occurredAt: now.subtract(const Duration(days: 1, hours: 4)), name: '치즈')),
    ];
    _store['b2'] = [
      r(DiaperDetail(occurredAt: now.subtract(const Duration(minutes: 30)), diaperType: DiaperType.pee)),
    ];
  }

  List<CareRecord> _desc(String babyId) {
    final list = [...?_store[babyId]];
    list.sort((a, b) => b.detail.occurredAt.compareTo(a.detail.occurredAt));
    return list;
  }

  @override
  Future<Result<Page<CareRecord>>> getRecords(String babyId,
      {String? cursor, int limit = 20}) async {
    final all = _desc(babyId);
    final start = cursor == null ? 0 : int.parse(cursor);
    final slice = all.skip(start).take(limit).toList();
    final next = start + slice.length;
    final hasMore = next < all.length;
    return Ok(Page(
      items: slice,
      nextCursor: hasMore ? next.toString() : null,
      hasMore: hasMore,
    ));
  }

  Future<Result<List<CareRecord>>> _recent(
          String babyId, Set<RecordType> types, int limit) async =>
      Ok(_desc(babyId).where((r) => types.contains(r.type)).take(limit).toList());

  @override
  Future<Result<List<CareRecord>>> getRecentFeedings(String babyId, {int limit = 2}) =>
      _recent(babyId, {RecordType.feeding, RecordType.pumping}, limit);

  @override
  Future<Result<List<CareRecord>>> getRecentDiapers(String babyId, {int limit = 2}) =>
      _recent(babyId, {RecordType.diaper}, limit);

  @override
  Future<Result<List<CareRecord>>> getRecentWakes(String babyId, {int limit = 2}) =>
      _recent(babyId, {RecordType.sleep}, limit);

  @override
  Future<Result<CareRecord>> createRecord(String babyId, RecordDetailData detail) async {
    final record = CareRecord(
      id: 'gen-${_seq++}',
      babyId: babyId,
      type: detail.type,
      detail: detail,
      createdBy: 'demo',
      createdAt: DateTime.now().toUtc(),
    );
    _store.putIfAbsent(babyId, () => []).add(record);
    return Ok(record);
  }

  @override
  Future<Result<void>> deleteRecord(String recordId) async {
    for (final entry in _store.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((r) => r.id == recordId);
      if (entry.value.length != before) return const Ok(null);
    }
    return Error(const AppException(ErrorCode.notFound, 'not found'));
  }

  @override
  Future<Result<CareRecord>> getRecord(String recordId) async =>
      Error(const AppException(ErrorCode.notFound, 'unused'));
  @override
  Future<Result<void>> updateRecord(String recordId, RecordDetailData detail) async =>
      const Ok(null);
  @override
  Future<Result<Page<RecordMemo>>> getMemos(String recordId,
          {String? cursor, int limit = 20}) async =>
      Ok(const Page(items: [], nextCursor: null, hasMore: false));
  @override
  Future<Result<RecordMemo>> addMemo(String recordId, String content) async =>
      Error(const AppException(ErrorCode.unknown, 'unused'));
  @override
  Future<Result<void>> updateMemo(String memoId, String content) async => const Ok(null);
  @override
  Future<Result<void>> deleteMemo(String memoId) async => const Ok(null);
}
