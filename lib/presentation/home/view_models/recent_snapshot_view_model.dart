import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';
import 'package:yuktoe/presentation/home/models/recent_slot_state.dart';

/// 최근 요약 `[C]` — 서로 독립인 3 슬롯 (feed / diaper / wake) (spec §11.2, plan §1.2).
///
/// 각 슬롯은 해당 카테고리의 최근 1건만 보여준다. babyId 는 인자가 아니라
/// [CurrentBabyController] 에서 읽고, 변경 시 세 슬롯을 재호출한다.
class RecentSnapshotViewModel extends ChangeNotifier {
  final RecordRepository _recordRepository;
  final CurrentBabyController _currentBaby;

  StreamSubscription<String?>? _subscription;

  RecentSlotState _feed = const RecentSlotState.idle();
  RecentSlotState _diaper = const RecentSlotState.idle();
  RecentSlotState _wake = const RecentSlotState.idle();
  String? _babyId;

  RecentSnapshotViewModel({
    required RecordRepository recordRepository,
    required CurrentBabyController currentBaby,
  }) : _recordRepository = recordRepository,
       _currentBaby = currentBaby {
    _babyId = _currentBaby.selectedBabyId;
    _subscription = _currentBaby.babyIdStream.listen(_onBabyChanged);
  }

  RecentSlotState get feed => _feed;
  RecentSlotState get diaper => _diaper;
  RecentSlotState get wake => _wake;

  void _onBabyChanged(String? babyId) {
    _babyId = babyId;
    if (babyId == null) {
      _feed = const RecentSlotState.idle();
      _diaper = const RecentSlotState.idle();
      _wake = const RecentSlotState.idle();
      notifyListeners();
      return;
    }
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([retryFeed(), retryDiaper(), retryWake()]);
  }

  Future<void> retryFeed() => _loadSlot(
    fetch: (id) => _recordRepository.getRecentFeedings(id, limit: 1),
    assign: (state) => _feed = state,
  );

  Future<void> retryDiaper() => _loadSlot(
    fetch: (id) => _recordRepository.getRecentDiapers(id, limit: 1),
    assign: (state) => _diaper = state,
  );

  Future<void> retryWake() => _loadSlot(
    fetch: (id) => _recordRepository.getRecentWakes(id, limit: 1),
    assign: (state) => _wake = state,
  );

  Future<void> _loadSlot({
    required Future<Result<List<CareRecord>>> Function(String babyId) fetch,
    required void Function(RecentSlotState state) assign,
  }) async {
    final requestedId = _babyId;
    if (requestedId == null) return;

    assign(const RecentSlotState.loading());
    notifyListeners();

    final result = await fetch(requestedId);
    if (_babyId != requestedId) return;

    switch (result) {
      case Ok<List<CareRecord>>(:final value):
        assign(RecentSlotState.success(value.isEmpty ? null : value.first));
      case Error<List<CareRecord>>(:final error):
        assign(RecentSlotState.failure(error));
    }
    notifyListeners();
  }

  /// 생성/삭제 후 영향받는 슬롯만 재호출 (spec §6.6).
  void notifyAfterRecordChanged(CareRecord record) =>
      _refreshSlotFor(record.type);

  void notifyAfterRecordDeleted(CareRecord record) =>
      _refreshSlotFor(record.type);

  void _refreshSlotFor(RecordType type) {
    switch (_slotForType(type)) {
      case _Slot.feed:
        retryFeed();
      case _Slot.diaper:
        retryDiaper();
      case _Slot.wake:
        retryWake();
      case null:
        break;
    }
  }

  /// 타입 → 슬롯 매핑 (plan §1.2). water / snack 은 어느 슬롯에도 속하지 않음.
  static _Slot? _slotForType(RecordType type) {
    return switch (type) {
      RecordType.breast ||
      RecordType.formula ||
      RecordType.pumpingFeed ||
      RecordType.pumping ||
      RecordType.babyFood => _Slot.feed,
      RecordType.diaper => _Slot.diaper,
      RecordType.sleep => _Slot.wake,
      RecordType.snack || RecordType.water => null,
    };
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

enum _Slot { feed, diaper, wake }
