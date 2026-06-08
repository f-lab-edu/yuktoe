/// 진행 중인 액션 식별자 — Loading 상태에서 어느 spinner 를 띄울지 분기.
enum RecordDetailAction { update, delete }

sealed class RecordDetailUiState {
  const RecordDetailUiState();
}

class RecordDetailIdle extends RecordDetailUiState {
  const RecordDetailIdle();
}

/// 특정 액션이 진행 중. UI 는 해당 자리에 spinner.
class RecordDetailLoading extends RecordDetailUiState {
  final RecordDetailAction action;
  const RecordDetailLoading(this.action);
}

/// 어떤 액션이든 실패 → 동일 snackbar 표시 후 `clearError()` → idle 복귀.
class RecordDetailFailure extends RecordDetailUiState {
  final String message;
  const RecordDetailFailure(this.message);
}

/// 삭제 성공. UI 는 화면 pop.
class RecordDetailDeleted extends RecordDetailUiState {
  const RecordDetailDeleted();
}
