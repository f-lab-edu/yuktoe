import 'package:flutter/foundation.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/presentation/record_detail/view_models/record_detail_ui_state.dart';

class RecordDetailViewModel extends ChangeNotifier {
  final RecordRepository _recordRepository;

  RecordDetailViewModel({
    required RecordRepository recordRepository,
    required CareRecord initialRecord,
  })  : _recordRepository = recordRepository,
        _record = initialRecord;

  // ===== 원본 데이터 =====
  CareRecord _record;
  CareRecord get record => _record;

  // ===== UI 상태 =====
  RecordDetailUiState _state = const RecordDetailIdle();
  RecordDetailUiState get state => _state;

  // ===== draft (체크 활성화 조건) =====
  RecordDetailData? _draftDetail;
  bool get hasPendingChanges => _draftDetail != null;
  RecordDetailData get displayedDetail => _draftDetail ?? _record.detail;

  void stageDetail(RecordDetailData detail) {
    _draftDetail = detail;
    notifyListeners();
  }

  void discardDraft() {
    _draftDetail = null;
    notifyListeners();
  }

  Future<void> commitChanges() async {
    final draft = _draftDetail;
    if (draft == null) return;
    if (_state is RecordDetailLoading) return;

    _state = const RecordDetailLoading(RecordDetailAction.update);
    notifyListeners();

    final result = await _recordRepository.updateRecord(_record.id, draft);
    switch (result) {
      case Ok<void>():
        _record = _record.copyWith(detail: draft);
        _draftDetail = null;
        _state = const RecordDetailIdle();
      case Error<void>():
        _state = RecordDetailFailure(result.error.message);
    }
    notifyListeners();
  }

  Future<void> deleteRecord() async {
    if (_state is RecordDetailLoading) return;

    _state = const RecordDetailLoading(RecordDetailAction.delete);
    notifyListeners();

    final result = await _recordRepository.deleteRecord(_record.id);
    switch (result) {
      case Ok<void>():
        _state = const RecordDetailDeleted();
      case Error<void>():
        _state = RecordDetailFailure(result.error.message);
    }
    notifyListeners();
  }

  void clearError() {
    if (_state is! RecordDetailFailure) return;
    _state = const RecordDetailIdle();
    notifyListeners();
  }
}
