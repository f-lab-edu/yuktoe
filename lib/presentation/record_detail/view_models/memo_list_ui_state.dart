sealed class MemoListUiState {
  const MemoListUiState();
}

class MemoListIdle extends MemoListUiState {
  const MemoListIdle();
}

class MemoListLoading extends MemoListUiState {
  const MemoListLoading();
}

class MemoListFailure extends MemoListUiState {
  final String message;
  const MemoListFailure(this.message);
}
