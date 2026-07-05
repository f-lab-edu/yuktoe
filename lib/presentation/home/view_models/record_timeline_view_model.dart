import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/common/page.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';

/// 기록 리스트 `[E]` — 무한 스크롤 타임라인 (spec §11.3, plan §1.3).
///
/// 첫 페이지와 다음 페이지가 동시에 다른 상태일 수 있어 [ActionState] 두 개를
/// 둔다. babyId 는 [CurrentBabyController] 에서 읽는다.
class RecordTimelineViewModel extends ChangeNotifier {
  static const _pageSize = 20;

  final RecordRepository _recordRepository;
  final CurrentBabyController _currentBaby;

  StreamSubscription<String?>? _subscription;

  ActionState _firstPageStatus = ActionState.idle;
  ActionState _nextPageStatus = ActionState.idle;
  final List<CareRecord> _items = [];
  String? _nextCursor;
  bool _hasMore = false;
  AppException? _firstPageError;
  AppException? _nextPageError;
  AppException? _deleteError;
  String? _babyId;

  RecordTimelineViewModel({
    required RecordRepository recordRepository,
    required CurrentBabyController currentBaby,
  }) : _recordRepository = recordRepository,
       _currentBaby = currentBaby {
    _babyId = _currentBaby.selectedBabyId;
    _subscription = _currentBaby.selectedBabyIdStream.listen(_onBabyChanged);
  }

  ActionState get firstPageStatus => _firstPageStatus;
  ActionState get nextPageStatus => _nextPageStatus;
  List<CareRecord> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  AppException? get firstPageError => _firstPageError;
  AppException? get nextPageError => _nextPageError;
  AppException? get deleteError => _deleteError;

  bool get isEmpty =>
      _firstPageStatus == ActionState.success && _items.isEmpty;

  void _onBabyChanged(String? babyId) {
    _babyId = babyId;
    if (babyId == null) {
      _resetData();
      _firstPageStatus = ActionState.idle;
      notifyListeners();
      return;
    }
    refresh();
  }

  void _resetData() {
    _items.clear();
    _nextCursor = null;
    _hasMore = false;
    _nextPageStatus = ActionState.idle;
    _nextPageError = null;
  }

  Future<void> loadFirstPage() async {
    final requestedId = _babyId;
    if (requestedId == null) return;

    _firstPageStatus = ActionState.loading;
    _firstPageError = null;
    notifyListeners();

    final result = await _recordRepository.getRecords(
      requestedId,
      cursor: null,
      limit: _pageSize,
    );
    if (_babyId != requestedId) return;

    switch (result) {
      case Ok<Page<CareRecord>>(:final value):
        _items
          ..clear()
          ..addAll(_dedupe(value.items));
        _nextCursor = value.nextCursor;
        _hasMore = value.hasMore;
        _firstPageStatus = ActionState.success;
        _firstPageError = null;
      case Error<Page<CareRecord>>(:final error):
        _firstPageStatus = ActionState.error;
        _firstPageError = error;
    }
    notifyListeners();
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || _nextPageStatus == ActionState.loading) return;
    final requestedId = _babyId;
    if (requestedId == null) return;

    _nextPageStatus = ActionState.loading;
    _nextPageError = null;
    notifyListeners();

    final result = await _recordRepository.getRecords(
      requestedId,
      cursor: _nextCursor,
      limit: _pageSize,
    );
    if (_babyId != requestedId) return;

    switch (result) {
      case Ok<Page<CareRecord>>(:final value):
        // 빈 페이지 방어: hasMore=true 인데 items=[] 면 그 자리에서 멈춤 (spec §8.4).
        if (value.items.isEmpty) {
          _hasMore = false;
        } else {
          _items.addAll(_dedupe(value.items));
          _nextCursor = value.nextCursor;
          _hasMore = value.hasMore;
        }
        _nextPageStatus = ActionState.success;
      case Error<Page<CareRecord>>(:final error):
        _nextPageStatus = ActionState.error;
        _nextPageError = error;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _resetData();
    await loadFirstPage();
  }

  /// 생성 반영 — 맨 앞에 추가 (id dedupe, spec §8.4).
  void prepend(CareRecord record) {
    if (_items.any((r) => r.id == record.id)) return;
    _items.insert(0, record);
    notifyListeners();
  }

  /// 삭제 요청 + 결과 분기 (spec §5.9, plan §1.3).
  ///
  /// `Ok`/`notFound` → 리스트에서 제거, `unauthorized` / 그 외 → [deleteError]
  /// 세팅(화면이 전역 분기 / 스낵바 판단). 리스트 제거는 내부 헬퍼로만.
  Future<void> deleteRecord(String recordId) async {
    _deleteError = null;
    final result = await _recordRepository.deleteRecord(recordId);

    switch (result) {
      case Ok<void>():
        _removeById(recordId);
      case Error<void>(:final error):
        if (error.code == ErrorCode.notFound) {
          _removeById(recordId);
        } else {
          _deleteError = error;
          notifyListeners();
        }
    }
  }

  void clearDeleteError() {
    _deleteError = null;
  }

  void _removeById(String recordId) {
    _items.removeWhere((r) => r.id == recordId);
    notifyListeners();
  }

  List<CareRecord> _dedupe(List<CareRecord> incoming) {
    final existing = _items.map((r) => r.id).toSet();
    final seen = <String>{};
    return incoming
        .where((r) => !existing.contains(r.id) && seen.add(r.id))
        .toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
