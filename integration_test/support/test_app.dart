import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/home_screen.dart';

/// 통합 테스트에서 시각을 제어하기 위한 이동 가능한 시계.
class TestClock {
  DateTime value;
  TestClock(this.value);
  DateTime now() => value;
  void advance(Duration d) => value = value.add(d);
}

/// 실제 [HomeScreen] 을 fake repository / 실제 협력자와 함께 띄우는 테스트 앱.
///
/// `[/welcome]` / `[/login]` 라우트는 전역 분기 검증용 placeholder 이며,
/// 화면에 'WELCOME_ROUTE' / 'LOGIN_ROUTE' 텍스트를 노출한다.
Widget buildHomeTestApp({
  required BabyRepository babyRepo,
  required RecordRepository recordRepo,
  required SharedPreferences prefs,
  DateTime Function()? clock,
  Stream<void>? stopwatchTicker,
}) {
  final storage = AppLocalStorage(prefs);

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => HomeScreen(
          clock: clock,
          stopwatchTicker: stopwatchTicker ?? Stream<void>.empty(),
        ),
      ),
      GoRoute(
        path: '/welcome',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('WELCOME_ROUTE'))),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('LOGIN_ROUTE'))),
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
    child: MaterialApp.router(routerConfig: router),
  );
}
