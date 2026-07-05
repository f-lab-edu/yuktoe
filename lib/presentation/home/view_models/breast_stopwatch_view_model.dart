import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/formatters/timer_duration_formatter.dart';
import 'package:yuktoe/presentation/home/view_models/stopwatch_controller.dart';

/// 모유수유 스탑워치 `[D]` — 좌/우 2채널 (spec §11.4, plan §1.4.1).
///
/// 불변식: 좌/우가 **동시에 running 일 수 없다** (spec §5.3.1). 한쪽을 running
/// 으로 전환할 때 다른쪽이 running 이면 자동으로 paused.
class BreastStopwatchViewModel extends ChangeNotifier
    implements StopwatchController {
  final RecordRepository _recordRepository;
  final CurrentBabyController _currentBaby;
  final DateTime Function() _now;
  final Stream<void> _ticker;

  StreamSubscription<void>? _tickerSub;

  bool _active = false;
  int _leftBaseSeconds = 0;
  int _rightBaseSeconds = 0;
  StopwatchPhase _leftPhase = StopwatchPhase.idle;
  StopwatchPhase _rightPhase = StopwatchPhase.idle;
  DateTime? _leftRunningSince;
  DateTime? _rightRunningSince;
  bool _leftEverRan = false;
  bool _rightEverRan = false;
  DateTime? _startedAt;

  SaveStatus _saveStatus = SaveStatus.idle;
  AppException? _saveError;
  BreastDetail? _pendingDetail;
  String? _pendingBabyId;

  BreastStopwatchViewModel({
    required RecordRepository recordRepository,
    required CurrentBabyController currentBaby,
    DateTime Function()? now,
    Stream<void>? ticker,
  }) : _recordRepository = recordRepository,
       _currentBaby = currentBaby,
       _now = now ?? DateTime.now,
       _ticker =
           ticker ?? Stream<void>.periodic(const Duration(seconds: 1), (_) {}) {
    // 티커는 생성자에서 한 번만 구독한다. running 인 동안 매 tick 마다
    // 표시를 갱신(재구독하지 않으므로 단일 구독 스트림 재-listen 예외가 없다).
    _tickerSub = _ticker.listen((_) {
      if (_leftPhase == StopwatchPhase.running ||
          _rightPhase == StopwatchPhase.running) {
        notifyListeners();
      }
    });
  }

  @override
  bool get active => _active;
  StopwatchPhase get leftPhase => _leftPhase;
  StopwatchPhase get rightPhase => _rightPhase;
  @override
  SaveStatus get saveStatus => _saveStatus;
  @override
  AppException? get saveError => _saveError;

  int get leftSeconds => _secondsFor(_leftBaseSeconds, _leftRunningSince);
  int get rightSeconds => _secondsFor(_rightBaseSeconds, _rightRunningSince);

  String get leftDisplay => formatTimerDuration(leftSeconds);
  String get rightDisplay => formatTimerDuration(rightSeconds);

  /// 좌/우 중 한 쪽이라도 누적 ≥ 1초.
  @override
  bool get hasElapsed => leftSeconds >= 1 || rightSeconds >= 1;
  bool get completeEnabled => hasElapsed && _saveStatus != SaveStatus.saving;

  DateTime? get startedAt => _startedAt;

  int _secondsFor(int base, DateTime? runningSince) {
    if (runningSince == null) return base;
    final elapsed = _now().difference(runningSince).inSeconds;
    return base + (elapsed < 0 ? 0 : elapsed);
  }

  /// 카드 노출 (좌/우 idle).
  void enter() {
    _active = true;
    _leftBaseSeconds = 0;
    _rightBaseSeconds = 0;
    _leftPhase = StopwatchPhase.idle;
    _rightPhase = StopwatchPhase.idle;
    _leftRunningSince = null;
    _rightRunningSince = null;
    _leftEverRan = false;
    _rightEverRan = false;
    _startedAt = null;
    _saveStatus = SaveStatus.idle;
    _saveError = null;
    _pendingDetail = null;
    notifyListeners();
  }

  void toggleLeft() {
    if (_saveStatus == SaveStatus.saving) return;
    if (_leftPhase == StopwatchPhase.running) {
      _pauseLeft();
    } else {
      _pauseRight(); // 불변식: 다른쪽 running 이면 자동 paused.
      _startLeft();
    }
    notifyListeners();
  }

  void toggleRight() {
    if (_saveStatus == SaveStatus.saving) return;
    if (_rightPhase == StopwatchPhase.running) {
      _pauseRight();
    } else {
      _pauseLeft();
      _startRight();
    }
    notifyListeners();
  }

  void _startLeft() {
    _leftPhase = StopwatchPhase.running;
    _leftRunningSince = _now();
    _leftEverRan = true;
    _startedAt ??= _now().toUtc();
  }

  void _pauseLeft() {
    if (_leftPhase != StopwatchPhase.running) return;
    _leftBaseSeconds = leftSeconds;
    _leftRunningSince = null;
    _leftPhase = StopwatchPhase.paused;
  }

  void _startRight() {
    _rightPhase = StopwatchPhase.running;
    _rightRunningSince = _now();
    _rightEverRan = true;
    _startedAt ??= _now().toUtc();
  }

  void _pauseRight() {
    if (_rightPhase != StopwatchPhase.running) return;
    _rightBaseSeconds = rightSeconds;
    _rightRunningSince = null;
    _rightPhase = StopwatchPhase.paused;
  }

  /// Complete → 저장. 성공 시 생성된 기록을 돌려주고 카드가 사라진다.
  Future<CareRecord?> complete() async {
    if (!hasElapsed || _saveStatus == SaveStatus.saving) return null;

    // 진행 중인 쪽은 그 시점까지 누적으로 자동 stop (spec §5.3.4 step 0).
    _pauseLeft();
    _pauseRight();

    final detail = BreastDetail(
      startedAt: _startedAt ?? _now().toUtc(),
      endedAt: _now().toUtc(),
      leftMinutes: _leftEverRan ? _roundMinutes(_leftBaseSeconds) : null,
      rightMinutes: _rightEverRan ? _roundMinutes(_rightBaseSeconds) : null,
    );
    _pendingDetail = detail;
    _pendingBabyId = _currentBaby.selectedBabyId;
    return _save();
  }

  Future<CareRecord?> _save() async {
    final detail = _pendingDetail;
    final babyId = _pendingBabyId;
    if (detail == null || babyId == null) return null;

    _saveStatus = SaveStatus.saving;
    _saveError = null;
    notifyListeners();

    final result = await _recordRepository.createRecord(babyId, detail);
    switch (result) {
      case Ok<CareRecord>(:final value):
        _active = false;
        _saveStatus = SaveStatus.idle;
        _pendingDetail = null;
        notifyListeners();
        return value;
      case Error<CareRecord>(:final error):
        _saveStatus = SaveStatus.failed;
        _saveError = error;
        notifyListeners();
        return null;
    }
  }

  @override
  Future<CareRecord?> retry() => _save();

  @override
  Future<CareRecord?> completeForSwitch() async {
    if (!hasElapsed) {
      discard();
      return null;
    }
    return complete();
  }

  @override
  void discard() {
    _active = false;
    _saveStatus = SaveStatus.idle;
    _saveError = null;
    _pendingDetail = null;
    notifyListeners();
  }

  @override
  void keepForNavigate() {}

  void clearSaveError() {
    _saveError = null;
  }

  int _roundMinutes(int seconds) => (seconds / 60).round();

  @override
  void dispose() {
    _tickerSub?.cancel();
    super.dispose();
  }
}
