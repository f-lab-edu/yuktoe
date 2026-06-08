import 'package:flutter/foundation.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/record/record_memo.dart';
import 'package:yuktoe/presentation/record_detail/view_models/memo_list_ui_state.dart';

class MemoListViewModel extends ChangeNotifier {
  final RecordRepository _recordRepository;
  final String _recordId;
  final int _pageSize;

  MemoListViewModel({
    required RecordRepository recordRepository,
    required String recordId,
    int pageSize = 20,
  })  : _recordRepository = recordRepository,
        _recordId = recordId,
        _pageSize = pageSize;

  // ===== 데이터 (UI 가 항상 읽어도 되는 현재 보유분) =====
  final List<RecordMemo> _memoList = [];
  List<RecordMemo> get memoList => List.unmodifiable(_memoList);

  String? _cursor;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  // ===== UI 상태 =====
  MemoListUiState _state = const MemoListIdle();
  MemoListUiState get state => _state;

  Future<void> refresh() async {
    if (_state is MemoListLoading) return;
    _state = const MemoListLoading();
    notifyListeners();

    final result = await _recordRepository.getMemos(
      _recordId,
      cursor: null,
      limit: _pageSize,
    );
    switch (result) {
      case Ok():
        _memoList
          ..clear()
          ..addAll(result.value.items);
        _cursor = result.value.nextCursor;
        _hasMore = result.value.hasMore;
        _state = const MemoListIdle();
      case Error():
        _state = MemoListFailure(result.error.message);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_state is MemoListLoading) return;
    if (!_hasMore) return;

    _state = const MemoListLoading();
    notifyListeners();

    final result = await _recordRepository.getMemos(
      _recordId,
      cursor: _cursor,
      limit: _pageSize,
    );
    switch (result) {
      case Ok():
        _memoList.addAll(result.value.items);
        _cursor = result.value.nextCursor;
        _hasMore = result.value.hasMore;
        _state = const MemoListIdle();
      case Error():
        _state = MemoListFailure(result.error.message);
    }
    notifyListeners();
  }

  Future<bool> addMemo(String content) async {
    if (_state is MemoListLoading) return false;

    _state = const MemoListLoading();
    notifyListeners();

    final result = await _recordRepository.addMemo(_recordId, content);
    switch (result) {
      case Ok<RecordMemo>():
        _memoList.add(result.value);
        _state = const MemoListIdle();
        notifyListeners();
        return true;
      case Error<RecordMemo>():
        _state = MemoListFailure(result.error.message);
        notifyListeners();
        return false;
    }
  }

  Future<bool> updateMemo(String memoId, String content) async {
    if (_state is MemoListLoading) return false;

    _state = const MemoListLoading();
    notifyListeners();

    final result = await _recordRepository.updateMemo(memoId, content);
    switch (result) {
      case Ok<void>():
        final index = _memoList.indexWhere((m) => m.id == memoId);
        if (index >= 0) {
          final existing = _memoList[index];
          _memoList[index] = RecordMemo(
            id: existing.id,
            recordId: existing.recordId,
            content: content,
            authorId: existing.authorId,
            authorName: existing.authorName,
            createdAt: existing.createdAt,
          );
        }
        _state = const MemoListIdle();
        notifyListeners();
        return true;
      case Error<void>():
        _state = MemoListFailure(result.error.message);
        notifyListeners();
        return false;
    }
  }

  Future<bool> deleteMemo(String memoId) async {
    if (_state is MemoListLoading) return false;

    _state = const MemoListLoading();
    notifyListeners();

    final result = await _recordRepository.deleteMemo(memoId);
    switch (result) {
      case Ok<void>():
        _memoList.removeWhere((m) => m.id == memoId);
        _state = const MemoListIdle();
        notifyListeners();
        return true;
      case Error<void>():
        _state = MemoListFailure(result.error.message);
        notifyListeners();
        return false;
    }
  }

  void clearError() {
    if (_state is! MemoListFailure) return;
    _state = const MemoListIdle();
    notifyListeners();
  }
}
