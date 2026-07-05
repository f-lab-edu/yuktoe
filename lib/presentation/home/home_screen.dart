import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/presentation/home/models/quick_log_kind.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/modals/baby_switch_sheet.dart';
import 'package:yuktoe/presentation/home/modals/delete_confirmation_dialog.dart';
import 'package:yuktoe/presentation/home/modals/input/record_input_dialog.dart';
import 'package:yuktoe/presentation/home/modals/stopwatch_dialogs.dart';
import 'package:yuktoe/presentation/home/record_type_labels.dart';
import 'package:yuktoe/presentation/home/screens/quick_log_settings_screen.dart';
import 'package:yuktoe/presentation/home/view_models/breast_stopwatch_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/home_baby_info_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/home_bootstrap_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/quick_log_buttons_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/recent_snapshot_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/record_timeline_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/sleep_stopwatch_view_model.dart';
import 'package:yuktoe/presentation/home/view_models/stopwatch_controller.dart';
import 'package:yuktoe/presentation/home/widgets/baby_info_header.dart';
import 'package:yuktoe/presentation/home/widgets/quick_log_button_row.dart';
import 'package:yuktoe/presentation/home/widgets/recent_snapshot_row.dart';
import 'package:yuktoe/presentation/home/widgets/record_timeline_section.dart';
import 'package:yuktoe/presentation/home/widgets/stopwatch_card.dart';
import 'package:yuktoe/presentation/record_detail/record_detail_screen.dart';
import 'package:yuktoe/routing/router.dart';

/// 홈 화면 — 5개 독립 영역([A]~[E]) 을 6 ViewModel 로 구성 (spec Part 2, plan §3.2).
class HomeScreen extends StatelessWidget {
  /// 스탑워치 VM 의 시계 주입 (테스트 seam). null 이면 `DateTime.now`.
  final DateTime Function()? clock;

  /// 스탑워치 VM 의 ticker 주입 (테스트 seam). null 이면 1초 주기 stream.
  final Stream<void>? stopwatchTicker;

  const HomeScreen({super.key, this.clock, this.stopwatchTicker});

  @override
  Widget build(BuildContext context) {
    final babyRepo = context.read<BabyRepository>();
    final recordRepo = context.read<RecordRepository>();
    final currentBaby = context.read<CurrentBabyController>();
    final storage = context.read<AppLocalStorage>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HomeBootstrapViewModel(
            babyRepository: babyRepo,
            currentBaby: currentBaby,
          )..bootstrap(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => HomeBabyInfoViewModel(
            babyRepository: babyRepo,
            currentBaby: currentBaby,
          ),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => RecentSnapshotViewModel(
            recordRepository: recordRepo,
            currentBaby: currentBaby,
          ),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => RecordTimelineViewModel(
            recordRepository: recordRepo,
            currentBaby: currentBaby,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BreastStopwatchViewModel(
            recordRepository: recordRepo,
            currentBaby: currentBaby,
            now: clock,
            ticker: stopwatchTicker,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SleepStopwatchViewModel(
            recordRepository: recordRepo,
            currentBaby: currentBaby,
            now: clock,
            ticker: stopwatchTicker,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => QuickLogButtonsViewModel(storage)..init(),
        ),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final bootstrap = context.watch<HomeBootstrapViewModel>();
    final babyInfo = context.watch<HomeBabyInfoViewModel>();

    _handleBootstrapRedirect(context, bootstrap);
    _handleGlobalBranch(context, babyInfo.error);

    if (bootstrap.status == ActionState.error) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('불러오지 못했어요'),
              ElevatedButton(
                onPressed: bootstrap.retry,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BabyInfoHeader(onTapName: () => _onTapName(context)),
            QuickLogButtonRow(
              onTapButton: (type) => _onTapButton(context, type),
              onTapSettings: () => _onTapSettings(context),
            ),
            const RecentSnapshotRow(),
            StopwatchCard(
              onSaved: (record) => _reflectCreated(context, record),
              onUnauthorized: (_) => _goLogin(context),
            ),
            Expanded(
              child: RecordTimelineSection(
                onTapRecord: (record) => _onTapRecord(context, record),
                onSwipeDelete: (record) => _onSwipeDelete(context, record),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2B7FFF),
        unselectedItemColor: const Color(0xFF99A1AF),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '홈'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded), label: '분석'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded), label: '설정'),
        ],
      ),
    );
  }

  // ── 전역 분기 ──────────────────────────────────────────────

  void _handleBootstrapRedirect(
    BuildContext context,
    HomeBootstrapViewModel bootstrap,
  ) {
    final redirect = bootstrap.redirect;
    if (redirect == BootstrapRedirect.none) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      switch (redirect) {
        case BootstrapRedirect.welcome:
          context.go(AppRoutes.welcome);
        case BootstrapRedirect.login:
          _goLogin(context);
        case BootstrapRedirect.none:
          break;
      }
    });
  }

  void _handleGlobalBranch(BuildContext context, AppException? error) {
    if (error == null) return;
    if (error.code == ErrorCode.notFound) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.welcome);
      });
    } else if (error.code == ErrorCode.unauthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _goLogin(context);
      });
    }
  }

  void _goLogin(BuildContext context) {
    context.read<CurrentBabyController>().clear();
    context.go(AppRoutes.login);
  }

  // ── 인터랙션 ──────────────────────────────────────────────

  Future<void> _onTapName(BuildContext context) async {
    if (!await _confirmLeaveWithStopwatch(context)) return;
    if (context.mounted) await showBabySwitchSheet(context);
  }

  Future<void> _onTapSettings(BuildContext context) async {
    final vm = context.read<QuickLogButtonsViewModel>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,
          child: const QuickLogSettingsScreen(),
        ),
      ),
    );
  }

  Future<void> _onTapButton(BuildContext context, QuickLogKind type) async {
    if (type.isStopwatch) {
      await _startStopwatch(context, type);
      return;
    }
    final detail = await showRecordInputDialog(context: context, type: type);
    if (detail == null || !context.mounted) return;

    final babyId = context.read<CurrentBabyController>().selectedBabyId;
    if (babyId == null) return;

    final result =
        await context.read<RecordRepository>().createRecord(babyId, detail);
    if (!context.mounted) return;
    switch (result) {
      case Ok<CareRecord>(:final value):
        _reflectCreated(context, value);
      case Error<CareRecord>(:final error):
        if (error.code == ErrorCode.unauthorized) {
          _goLogin(context);
        } else {
          _snack(context, '저장에 실패했어요. 다시 시도해주세요.');
        }
    }
  }

  Future<void> _startStopwatch(BuildContext context, QuickLogKind type) async {
    final breast = context.read<BreastStopwatchViewModel>();
    final sleep = context.read<SleepStopwatchViewModel>();
    final isBreast = type == QuickLogKind.breast;
    final StopwatchController target = isBreast ? breast : sleep;
    final StopwatchController other = isBreast ? sleep : breast;

    if (target.active) return;

    if (other.active) {
      final proceed = await showStopwatchConflictDialog(
        context,
        currentLabel: isBreast ? '수면' : '모유',
        nextLabel: isBreast ? '모유' : '수면',
      );
      if (!proceed || !context.mounted) return;
      final saved = await other.completeForSwitch();
      if (!context.mounted) return;
      if (saved != null) {
        _reflectCreated(context, saved);
      } else if (other.saveError?.code == ErrorCode.unauthorized) {
        _goLogin(context);
        return;
      } else if (other.saveStatus == SaveStatus.failed) {
        return; // 저장 실패 → 새 카테고리 진입 안 함.
      }
    }

    if (isBreast) {
      breast.enter();
    } else {
      sleep.enter();
    }
  }

  Future<void> _onTapRecord(BuildContext context, CareRecord record) async {
    if (!await _confirmLeaveWithStopwatch(context)) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecordDetailScreen(record: record)),
    );
  }

  Future<void> _onSwipeDelete(BuildContext context, CareRecord record) async {
    final confirmed = await showDeleteConfirmationDialog(context);
    if (!confirmed || !context.mounted) return;

    final timeline = context.read<RecordTimelineViewModel>();
    await timeline.deleteRecord(record.id);
    if (!context.mounted) return;

    final error = timeline.deleteError;
    if (error != null) {
      if (error.code == ErrorCode.unauthorized) {
        _goLogin(context);
      } else {
        _snack(context, '삭제에 실패했어요. 다시 시도해주세요.');
        timeline.clearDeleteError();
      }
      return;
    }
    context.read<RecentSnapshotViewModel>().notifyAfterRecordDeleted(record);
  }

  /// 스탑워치 진행 중 라우트 이동 dialog (spec §5.3.6). 이동 가능하면 true.
  Future<bool> _confirmLeaveWithStopwatch(BuildContext context) async {
    final breast = context.read<BreastStopwatchViewModel>();
    final sleep = context.read<SleepStopwatchViewModel>();
    final StopwatchController? active =
        breast.active ? breast : (sleep.active ? sleep : null);
    if (active == null || !active.hasElapsed) return true;

    final choice = await showStopwatchNavigationDialog(context);
    if (!context.mounted) return false;
    switch (choice) {
      case StopwatchNavigateChoice.cancel:
        return false;
      case StopwatchNavigateChoice.completeAndGo:
        final saved = await active.completeForSwitch();
        if (!context.mounted) return false;
        if (saved != null) {
          _reflectCreated(context, saved);
          return true;
        }
        if (active.saveError?.code == ErrorCode.unauthorized) {
          _goLogin(context);
          return false;
        }
        return active.saveStatus != SaveStatus.failed;
      case StopwatchNavigateChoice.keepAndGo:
        active.keepForNavigate();
        return true;
    }
  }

  void _reflectCreated(BuildContext context, CareRecord record) {
    context.read<RecordTimelineViewModel>().prepend(record);
    context.read<RecentSnapshotViewModel>().notifyAfterRecordChanged(record);
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
