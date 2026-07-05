import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/formatters/sleep_type_inferrer.dart';
import 'package:yuktoe/presentation/home/formatters/timer_duration_formatter.dart';
import 'package:yuktoe/presentation/home/view_models/stopwatch_controller.dart';

/// 수면 스탑워치 `[D]` — 단일 채널 (spec §11.4, plan §1.4.2).
class SleepStopwatchViewModel extends ChangeNotifier
    implements StopwatchController {
  final RecordRepository _recordRepository;
  final CurrentBabyController _currentBaby;
  final DateTime Function() _now;
  final Stream<void> _ticker;

  StreamSubscription<void>? _tickerSub;

  bool _active = false;
  int _baseSeconds = 0;
  StopwatchPhase _phase = StopwatchPhase.idle;
  DateTime? _runningSince;
  DateTime? _startedAt;

  SaveStatus _saveStatus = SaveStatus.idle;
  AppException? _saveError;
  SleepDetail? _pendingDetail;
  String? _pendingBabyId;

  SleepStopwatchViewModel({
    required RecordRepository recordRepository,
    required CurrentBabyController currentBaby,
    DateTime Function()? now,
    Stream<void>? ticker,
  }) : _recordRepository = recordRepository,
       _currentBaby = currentBaby,
       _now = now ?? DateTime.now,
       _ticker =
           ticker ?? Stream<void>.periodic(const Duration(seconds: 1), (_) {}) {
    // 티커는 생성자에서 한 번만 구독한다(재-listen 예외 방지). running 인
    // 동안 매 tick 마다 표시를 갱신한다.
    _tickerSub = _ticker.listen((_) {
      if (_phase == StopwatchPhase.running) notifyListeners();
    });
  }

  @override
  bool get active => _active;
  StopwatchPhase get phase => _phase;
  @override
  SaveStatus get saveStatus => _saveStatus;
  @override
  AppException? get saveError => _saveError;

  int get seconds {
    if (_runningSince == null) return _baseSeconds;
    final elapsed = _now().difference(_runningSince!).inSeconds;
    return _baseSeconds + (elapsed < 0 ? 0 : elapsed);
  }

  String get display => formatTimerDuration(seconds);

  @override
  bool get hasElapsed => seconds >= 1;
  bool get completeEnabled => hasElapsed && _saveStatus != SaveStatus.saving;

  DateTime? get startedAt => _startedAt;

  /// 카드 노출 (idle, Start 대기).
  void enter() {
    _active = true;
    _baseSeconds = 0;
    _phase = StopwatchPhase.idle;
    _runningSince = null;
    _startedAt = null;
    _saveStatus = SaveStatus.idle;
    _saveError = null;
    _pendingDetail = null;
    notifyListeners();
  }

  /// idle → running (Start), running ↔ paused (Pause / Resume).
  void toggle() {
    if (_saveStatus == SaveStatus.saving) return;
    switch (_phase) {
      case StopwatchPhase.running:
        _baseSeconds = seconds;
        _runningSince = null;
        _phase = StopwatchPhase.paused;
      case StopwatchPhase.idle:
      case StopwatchPhase.paused:
        _phase = StopwatchPhase.running;
        _runningSince = _now();
        _startedAt ??= _now().toUtc();
    }
    notifyListeners();
  }

  Future<CareRecord?> complete() async {
    if (!hasElapsed || _saveStatus == SaveStatus.saving) return null;

    if (_phase == StopwatchPhase.running) {
      _baseSeconds = seconds;
      _runningSince = null;
      _phase = StopwatchPhase.paused;
    }

    final endedAt = _now().toUtc();
    final detail = SleepDetail(
      startedAt: _startedAt ?? endedAt,
      endedAt: endedAt,
      sleepType: inferSleepType(endedAt),
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

  @override
  void dispose() {
    _tickerSub?.cancel();
    super.dispose();
  }
}
