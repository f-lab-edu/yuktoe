import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/analytics_repository/analytics_repository.dart';
import 'package:yuktoe/domain/models/analytics/analytics_summary.dart';
import 'package:yuktoe/presentation/analytics/view_models/awake_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/diaper_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/feeding_card_view_model.dart';
import 'package:yuktoe/presentation/analytics/view_models/sleep_card_view_model.dart';

/// 분석 탭 요약 영역의 코디네이터. 네트워크와 대화하는 유일한 ViewModel 로,
/// 요약을 **한 번** 조회하고 로딩/실패 같은 네트워크 상태를 책임진 뒤, 성공하면
/// 받은 요약을 4개 카드 ViewModel 에 나눠준다(bind). 카드 VM 들을 소유·정리한다.
class AnalyticsViewModel extends ChangeNotifier {
  final AnalyticsRepository _analyticsRepository;
  final DateTime Function() _now;

  AnalyticsViewModel({
    required AnalyticsRepository analyticsRepository,
    DateTime Function()? now,
  })  : _analyticsRepository = analyticsRepository,
        _now = now ?? DateTime.now;

  final FeedingCardViewModel feedingCard = FeedingCardViewModel();
  final DiaperCardViewModel diaperCard = DiaperCardViewModel();
  final AwakeCardViewModel awakeCard = AwakeCardViewModel();
  final SleepCardViewModel sleepCard = SleepCardViewModel();

  ActionState _state = ActionState.idle;
  ActionState get state => _state;
  bool get isLoading => _state == ActionState.loading;

  ErrorCode? _errorCode;
  ErrorCode? get errorCode => _errorCode;

  /// 마지막으로 조회를 시작한 babyId(중복 가드 및 retry 대상).
  String? _lastBabyId;

  /// 현재 선택된 아기 기준으로 요약을 조회한다. 진입 시 1회, 아기가 바뀔 때마다
  /// 호출된다. 같은 [babyId] 로 이미 로딩했으면 재조회하지 않는다(중복 가드).
  Future<void> loadFor(String? babyId) async {
    if (babyId == null) {
      _lastBabyId = null;
      _resetCards();
      _state = ActionState.idle;
      _errorCode = null;
      notifyListeners();
      return;
    }
    if (babyId == _lastBabyId) return; // 중복 가드
    _lastBabyId = babyId;
    await _load(babyId);
  }

  /// networkError 등 실패 후 "다시 시도". 마지막 babyId 로 재조회(가드 우회).
  Future<void> retry() async {
    final babyId = _lastBabyId;
    if (babyId == null) return;
    await _load(babyId);
  }

  Future<void> _load(String babyId) async {
    _state = ActionState.loading;
    _errorCode = null;
    notifyListeners();

    final result = await _analyticsRepository.getSummary(babyId, _today());

    // 조회 중 다른 아기로 전환됐다면 이 응답은 버린다(경쟁 방지).
    if (babyId != _lastBabyId) return;

    switch (result) {
      case Ok<AnalyticsSummary>():
        _distribute(result.value);
        _state = ActionState.success;
        _errorCode = null;
      case Error<AnalyticsSummary>():
        // notFound 는 stale selectedBabyId 신호이나, 목록 재조회/다른 아기 선택은
        // 상위(홈/아기 컨트롤러) 책임이라 여기서는 에러 상태로 노출한다(후속 과제).
        _state = ActionState.error;
        _errorCode = result.error.code;
    }
    notifyListeners();
  }

  void _distribute(AnalyticsSummary summary) {
    feedingCard.bind(summary.feedingVolume);
    diaperCard.bind(summary.peeCount, summary.poopCount);
    awakeCard.bind(summary.awakeDuration);
    sleepCard.bind(summary.totalSleepDuration);
  }

  void _resetCards() {
    feedingCard.bind(null);
    diaperCard.bind(null, null);
    awakeCard.bind(null);
    sleepCard.bind(null);
  }

  DateTime _today() {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    feedingCard.dispose();
    diaperCard.dispose();
    awakeCard.dispose();
    sleepCard.dispose();
    super.dispose();
  }
}
