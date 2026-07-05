import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/domain/models/baby/baby_list_item.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';

/// 홈 첫 진입 부트스트랩 (spec §7.1). `getMyBabies` → candidate 결정 →
/// `select(candidate)`. select 이 stream 을 발화하면 `[A]`/`[C]`/`[E]` 가
/// 자기 로드를 시작한다 (plan §3.2).
///
/// StatelessWidget 규칙을 지키기 위해 화면 mount 시 이 VM 의 [bootstrap] 을
/// 트리거한다. 전역 라우팅 판정은 [redirect] 를 화면이 watch 해서 처리한다.
enum BootstrapRedirect { none, welcome, login }

class HomeBootstrapViewModel extends ChangeNotifier {
  final BabyRepository _babyRepository;
  final CurrentBabyController _currentBaby;

  ActionState _status = ActionState.idle;
  AppException? _error;
  BootstrapRedirect _redirect = BootstrapRedirect.none;

  HomeBootstrapViewModel({
    required BabyRepository babyRepository,
    required CurrentBabyController currentBaby,
  }) : _babyRepository = babyRepository,
       _currentBaby = currentBaby;

  ActionState get status => _status;
  AppException? get error => _error;
  BootstrapRedirect get redirect => _redirect;

  Future<void> bootstrap() async {
    if (_status == ActionState.loading) return;
    _status = ActionState.loading;
    _error = null;
    _redirect = BootstrapRedirect.none;
    notifyListeners();

    final result = await _babyRepository.getMyBabies();
    switch (result) {
      case Ok<List<BabyListItem>>(:final value):
        if (value.isEmpty) {
          _redirect = BootstrapRedirect.welcome; // notFound = 빈 리스트 (spec §4.2).
          _status = ActionState.success;
        } else {
          final candidate = _currentBaby.selectedBabyId ?? value.first.id;
          await _currentBaby.select(candidate);
          _status = ActionState.success;
        }
      case Error<List<BabyListItem>>(:final error):
        switch (error.code) {
          case ErrorCode.unauthorized:
            _redirect = BootstrapRedirect.login;
            _status = ActionState.success;
          case ErrorCode.notFound:
            _redirect = BootstrapRedirect.welcome;
            _status = ActionState.success;
          default:
            _error = error;
            _status = ActionState.error;
        }
    }
    notifyListeners();
  }

  Future<void> retry() => bootstrap();
}
