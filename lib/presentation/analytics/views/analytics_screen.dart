import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/data/repositories/analytics_repository/analytics_repository.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/presentation/analytics/view_models/analytics_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/awake_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_input_controller.dart';
import 'package:yuktoe/presentation/analytics/view_models/chat_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/diaper_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/feeding_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/sleep_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/widgets/analytics_summary_states.dart';
import 'package:yuktoe/presentation/analytics/widgets/awake_card.dart';
import 'package:yuktoe/presentation/analytics/widgets/chat/chat_section.dart';
import 'package:yuktoe/presentation/analytics/widgets/diaper_card.dart';
import 'package:yuktoe/presentation/analytics/widgets/feeding_card.dart';
import 'package:yuktoe/presentation/analytics/widgets/sleep_card.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';

/// 분석 탭 진입점. 코디네이터(`AnalyticsViewModel`)를 만들어 하위에 제공하고,
/// 선택 아기가 바뀌면 `loadFor` 를 연결한다. 요약 영역(본 화면)과 채팅 영역
/// (별도 feature) 을 세로로 배치한다.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 요약 코디네이터 + 채팅 3개 ViewModel 을 화면 단위로 제공한다. 선택 아기가
    // 바뀌면 각 VM 의 진입/재초기화 메서드를 호출한다(build 중 notifyListeners 를
    // 피하려 프레임 종료 후 호출, 각 VM 의 중복 가드가 재조회를 방지).
    return MultiProvider(
      providers: [
        ChangeNotifierProxyProvider<CurrentBabyController, AnalyticsViewModel>(
          create: (context) => AnalyticsViewModel(
            analyticsRepository: context.read<AnalyticsRepository>(),
          ),
          update: (context, currentBaby, viewModel) {
            final vm = viewModel!;
            final babyId = currentBaby.selectedBabyId;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => vm.loadFor(babyId));
            return vm;
          },
        ),
        ChangeNotifierProxyProvider<CurrentBabyController, ChatViewModel>(
          create: (context) => ChatViewModel(
            chatRepository: context.read<ChatRepository>(),
            babyRepository: context.read<BabyRepository>(),
          ),
          update: (context, currentBaby, viewModel) {
            final vm = viewModel!;
            final babyId = currentBaby.selectedBabyId;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => vm.enterTab(babyId));
            return vm;
          },
        ),
        ChangeNotifierProxyProvider<CurrentBabyController, ChatInputController>(
          create: (context) => ChatInputController(
            chatRepository: context.read<ChatRepository>(),
          ),
          update: (context, currentBaby, controller) {
            final ctrl = controller!;
            final babyId = currentBaby.selectedBabyId;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => ctrl.loadFor(babyId));
            return ctrl;
          },
        ),
      ],
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('분석')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AnalyticsSummarySection(),
            SizedBox(height: 16),
            ChatSection(),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsSummarySection extends StatelessWidget {
  const _AnalyticsSummarySection();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnalyticsViewModel>();
    return switch (vm.state) {
      ActionState.loading => const AnalyticsSummaryLoading(),
      ActionState.error => AnalyticsErrorState(
          errorCode: vm.errorCode ?? ErrorCode.unknown,
          onRetry: vm.retry,
        ),
      ActionState.idle || ActionState.success => _SummaryCards(vm: vm),
    };
  }
}

/// 4개 카드 VM 을 코디네이터로부터 제공하고 2×2 그리드로 배치한다.
/// (idle/success 에서 그린다 — 카드 VM 이 "데이터 없음" 을 스스로 표현하므로
/// 빈 데이터도 동일 경로로 렌더된다.)
class _SummaryCards extends StatelessWidget {
  final AnalyticsViewModel vm;

  const _SummaryCards({required this.vm});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FeedingCardViewModel>.value(value: vm.feedingCard),
        ChangeNotifierProvider<SleepCardViewModel>.value(value: vm.sleepCard),
        ChangeNotifierProvider<DiaperCardViewModel>.value(value: vm.diaperCard),
        ChangeNotifierProvider<AwakeCardViewModel>.value(value: vm.awakeCard),
      ],
      child: Column(
        children: const [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: FeedingCard()),
                SizedBox(width: 12),
                Expanded(child: SleepCard()),
              ],
            ),
          ),
          SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: DiaperCard()),
                SizedBox(width: 12),
                Expanded(child: AwakeCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
