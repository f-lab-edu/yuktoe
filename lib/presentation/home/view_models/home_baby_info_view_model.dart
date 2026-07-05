import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/formatters/date_label_formatter.dart';

/// 헤더 `[A]` — 현재 선택된 아기 1명의 기본 정보 (spec §11.1, plan §1.1).
///
/// babyId 는 인자로 받지 않는다. 생성자에서 [CurrentBabyController] 의 현재값을
/// 읽고, 이후 변경은 stream 으로 받아 자기 영역을 재호출한다 (plan §1.0).
class HomeBabyInfoViewModel extends ChangeNotifier {
  final BabyRepository _babyRepository;
  final CurrentBabyController _currentBaby;
  final DateTime Function() _now;

  StreamSubscription<String?>? _subscription;

  ActionState _status = ActionState.idle;
  Baby? _baby;
  AppException? _error;
  String? _babyId;

  HomeBabyInfoViewModel({
    required BabyRepository babyRepository,
    required CurrentBabyController currentBaby,
    DateTime Function()? now,
  }) : _babyRepository = babyRepository,
       _currentBaby = currentBaby,
       _now = now ?? DateTime.now {
    _babyId = _currentBaby.selectedBabyId;
    _subscription = _currentBaby.babyIdStream.listen(_onBabyChanged);
  }

  ActionState get status => _status;
  Baby? get baby => _baby;
  AppException? get error => _error;

  String? get name => _baby?.name;
  String? get dateLabel =>
      _baby == null ? null : formatDateLabel(_baby!, _now());

  void _onBabyChanged(String? babyId) {
    _babyId = babyId;
    if (babyId == null) {
      _status = ActionState.idle;
      _baby = null;
      _error = null;
      notifyListeners();
      return;
    }
    load();
  }

  Future<void> load() async {
    final requestedId = _babyId;
    if (requestedId == null) return;

    _status = ActionState.loading;
    _error = null;
    notifyListeners();

    final result = await _babyRepository.getBaby(requestedId);

    // baby 전환 race: 응답이 도착했을 때 대상이 바뀌었으면 폐기 (spec §8.7).
    if (_babyId != requestedId) return;

    switch (result) {
      case Ok<Baby>(:final value):
        _baby = value;
        _status = ActionState.success;
        _error = null;
      case Error<Baby>(:final error):
        _baby = null;
        _status = ActionState.error;
        _error = error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
