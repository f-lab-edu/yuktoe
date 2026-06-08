# 📋 Record Detail Screen — Presentation Layer Plan

## 0. 스코프

- **이 PR 범위**: 기록 상세 화면의 **Presentation Layer만** (UI + ViewModel)
- SessionManager 전제 — 전역 Provider 로 등록되어 있고 currentUserId: String? 를 노출
- 아키텍처 원칙: Provider DI + ChangeNotifier ViewModel, StatelessWidget만 사용

## 1. 클래스 관계도

```
                ┌──────────────────────────────────────┐
                │       RecordDetailScreen             │  (StatelessWidget)
                │  - 진입점, CareRecord 받음           │
                │  - Provider scope 생성               │
                └──────────────┬───────────────────────┘
                               │ MultiProvider
            ┌──────────────────┴────────────────────┐
            ▼                                       ▼
┌─────────────────────────────────┐    ┌──────────────────────────────────┐
│ RecordDetailViewModel           │    │   MemoListViewModel              │
│ - record: 생성자 주입(불변 출발)│    │   - cursor 페이지네이션          │
│ - state: 단일 sealed UI state   │    │   - memoList + 별도 state        │
│ - draft 패턴 (체크 활성화)      │    │   - add/update/delete            │
└──────────────┬──────────────────┘    └──────────────┬───────────────────┘
               │                                  │
               │ depends on                       │ depends on
               ▼                                  ▼
        ┌────────────────────────────────────────────────┐
        │                RecordRepository                │
        └────────────────────────────────────────────────┘
        (아래는 전역 Provider — 두 ViewModel 모두 필요할 때 context.read<SessionManager>() 로 참조)
        ┌────────────────────────────────────────────────┐
        │       SessionManager  (currentUserId)          │
        └────────────────────────────────────────────────┘

RecordDetailScreen body
├── RecordDetailAppBar           (← / 체크 아이콘 / 삭제 아이콘)
├── RecordDetailBody             (Consumer<RecordDetailViewModel>)
│      └── _RecordTypeDetailView     ← type 별 분기
│             ├── DiaperDetailView          (시각 버튼 + 기저귀타입 버튼)
│             ├── SleepDetailView           (구간 버튼 + 수면타입 버튼)
│             ├── BreastDetailView          (구간 버튼 + L/R 분 버튼)
│             ├── FormulaDetailView         (시각 버튼 + ml 버튼)
│             ├── PumpingFeedDetailView     (시각 버튼 + ml 버튼)
│             ├── PumpingDetailView         (시각 버튼 + L/R ml 버튼)
│             ├── BabyFoodDetailView        (시각 + 종류 + ml 버튼)
│             ├── SnackDetailView           (시각 + 종류 버튼)
│             └── WaterDetailView           (시각 + ml 버튼)
└── MemoSection                  (Consumer<MemoListViewModel>)
       ├── MemoList              (ListView + 무한 스크롤)
       │     └── MemoItem        (내가 쓴 메모면 ⋮ 메뉴 표시)
       └── MemoInput             (텍스트 입력 + 전송)

각 detail view 가 공통으로 쓰는 위젯
- DetailFieldButton(label, valueText, onTap)   ← 클릭 가능한 행
- SpecificTimeButton(value, onChanged)
- TimeRangeButton(start, end, onChanged)
- TypePickerButton<T>(value, onChanged)

모달 (각 필드 편집용 — bottom sheet 또는 dialog)
- TimePickerModal
- TimeRangeEditModal
- DiaperTypeModal / SleepTypeModal
- AmountInputModal (ml)
- LeftRightAmountModal (L/R ml 또는 L/R 분)
- TextInputModal (이유식 종류, 간식 종류)
```

---

## 2. 클래스 설계

### 2.1 `RecordDetailViewModel`

```dart
/// AppBar 의 어느 아이콘이 spinner 가 될지 분기하기 위한 액션 식별자.
/// Loading 상태에만 적용. Failure 는 동일 snackbar 라 action 불필요.
enum RecordDetailAction { update, delete }

sealed class RecordDetailUiState {
  const RecordDetailUiState();
}

class RecordDetailIdle extends RecordDetailUiState {
  const RecordDetailIdle();
}

/// 특정 액션이 진행 중. UI 는 해당 아이콘에 spinner.
class RecordDetailLoading extends RecordDetailUiState {
  final RecordDetailAction action;
  const RecordDetailLoading(this.action);
}

/// 어떤 액션이든 실패 → 동일 snackbar 표시 후 idle 복귀.
class RecordDetailFailure extends RecordDetailUiState {
  final String message;
  const RecordDetailFailure(this.message);
}

/// 삭제 성공. UI 는 화면 pop.
class RecordDetailDeleted extends RecordDetailUiState {
  const RecordDetailDeleted();
}
```

ViewModel:
```dart
class RecordDetailViewModel extends ChangeNotifier {
  RecordDetailViewModel({
    required RecordRepository recordRepository,
    required CareRecord initialRecord,
  }) : _record = initialRecord;

  // ===== 원본 데이터 =====
  CareRecord _record;
  CareRecord get record => _record;

  // ===== UI 상태 =====
  RecordDetailUiState _state = const RecordDetailIdle();
  RecordDetailUiState get state => _state;

  // ===== 수정 draft =====
  RecordDetailData? _draftDetail;
  bool get hasPendingChanges => _draftDetail != null;
  RecordDetailData get displayedDetail => _draftDetail ?? _record.detail;

  // ===== 액션 =====
  void stageDetail(RecordDetailData detail);
  void discardDraft();

  Future<void> commitChanges();      // Idle → Loading(update) → Idle/Failure
  Future<void> deleteRecord();       // Idle → Loading(delete) → Deleted/Failure

  void clearError();                  // Failure → Idle
}
```

### 2.1.1 UI 측 패턴 매핑
| ViewModel.state | UI 처리 |
| --- | --- |
| `RecordDetailIdle` | 체크 아이콘은 `hasPendingChanges` 만 보고 활성/비활성, 휴지통 활성 |
| `RecordDetailLoading(update)` | **체크 아이콘 자리 spinner**, 휴지통 disable |
| `RecordDetailLoading(delete)` | **휴지통 아이콘 자리 spinner**, 체크 disable |
| `RecordDetailFailure(message)` | snackbar 로 message 표시 후 `vm.clearError()` 호출 → Idle |
| `RecordDetailDeleted` | `addPostFrameCallback((_) => Navigator.maybePop(context))` |

```dart
Widget buildCheckAction(RecordDetailViewModel vm) {
  final state = vm.state;
  if (state is RecordDetailLoading && state.action == RecordDetailAction.update) {
    return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
  }
  return IconButton(
    icon: const Icon(Icons.check),
    onPressed: vm.hasPendingChanges ? vm.commitChanges : null,
  );
}
```

### 2.2 `MemoListViewModel`

```dart
sealed class MemoListUiState {
  const MemoListUiState();
}
class MemoListIdle extends MemoListUiState { const MemoListIdle(); }
class MemoListLoading extends MemoListUiState { const MemoListLoading(); }
class MemoListFailure extends MemoListUiState {
  final String message;
  const MemoListFailure(this.message);
}
```

```dart
class MemoListViewModel extends ChangeNotifier {
  MemoListViewModel({
    required RecordRepository recordRepository,
    required String recordId,
    int pageSize = 20,
  });

  // ===== 데이터 =====
  final List<RecordMemo> _memoList = [];
  List<RecordMemo> get memoList => List.unmodifiable(_memoList);

  String? _cursor;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  // ===== UI 상태 =====
  MemoListUiState _state = const MemoListIdle();
  MemoListUiState get state => _state;

  // ===== 액션 =====
  Future<void> refresh();
  Future<void> loadMore();
  Future<bool> addMemo(String content);
  Future<bool> updateMemo(String memoId, String content);
  Future<bool> deleteMemo(String memoId);

  void clearError();
}
```

- 정렬: `created_at` ASC (오래된 메모가 위) — Data Layer 결정 사항 그대로 따름
- `addMemo` 성공 시 리스트 **맨 뒤에 append**
- `updateMemo` / `deleteMemo` 는 in-place 갱신/삭제 (전체 새로고침 안 함)
- 에러는 `errorMessage` 한 슬롯으로 노출 → View 가 snackbar 로 표시 후 클리어
- `canModify`같은 별도 변수는 ViewModel 의 책임에서 빼고 View 가 SessionManager.currentUserId == memo.authorId 로 직접 판정 (혹은 작은 helper 위젯 / extension 으로 캡슐화).

### 2.2.1 데이터/UI state 분리

- `_memoList`와 `_state`는 독립
- `loadMore` 진행 중 (`state == Loading`) 에도 기존 `memoList` 그대로 화면에 보임
- UI 가 "어디에 spinner 를 표시할지" 는 컨텍스트로 결정:
  - `memoList.isEmpty && state == Loading` → 메모 영역 중앙 spinner (초기 fetch)
  - `memoList.isNotEmpty && state == Loading` → 리스트 끝 작은 spinner 또는 표시 안 함
  - 추가/수정/삭제는 별도 spinner 없음 (낙관적 보이기) — 실패 시에만 snackbar

### 2.3 `RecordDetailScreen` (진입점)

```dart
class RecordDetailScreen extends StatelessWidget {
  final CareRecord record;
  const RecordDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final recordRepo = context.read<RecordRepository>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RecordDetailViewModel(
            recordRepository: recordRepo,
            initialRecord: record,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoListViewModel(
            recordRepository: recordRepo,
            recordId: record.id,
          )..refresh(),
        ),
      ],
      child: const _RecordDetailView(),
    );
  }
}
```

- ViewModel 의 **소유권은 Screen** 이 가짐 → 화면이 dispose 되면 자동 정리

#### `_RecordDetailView`

- `RecordDetailViewModel.state` 를 보고 분기 렌더링
  - `Loading` → 중앙 progress
  - `Data` → AppBar + `_RecordTypeDetailView(record)` + `MemoSection`
  - `LoadError` → 재시도 버튼
  - `Deleted` → `Navigator.maybePop` (listener 로 처리)

#### `_RecordTypeDetailView`

```dart
class _RecordTypeDetailView extends StatelessWidget {
  final RecordDetailData detail;
  const _RecordTypeDetailView(this.record);

  @override
  Widget build(BuildContext context) {
    return switch (detail) {
      DiaperDetail d        => DiaperDetailView(detail: d),
      SleepDetail d         => SleepDetailView(detail: d),
      BreastDetail d        => BreastDetailView(detail: d),
      FormulaDetail d       => FormulaDetailView(detail: d),
      PumpingFeedDetail d   => PumpingFeedDetailView(detail: d),
      PumpingDetail d       => PumpingDetailView(detail: d),
      BabyFoodDetail d      => BabyFoodDetailView(detail: d),
      SnackDetail d         => SnackDetailView(detail: d),
      WaterDetail d         => WaterDetailView(detail: d),
    };
  }
}
```

- `switch` 가 모든 sealed variant 를 망라 → 새 타입 추가 시 컴파일 에러로 강제 처리
각 XxxDetailView 는 내부에서:
- DetailFieldButton 들을 세로로 배치
- 각 버튼 onTap → 모달 띄움 → 결과 받으면 context.read<RecordDetailViewModel>().stageXxx(newValue) 호출

#### 메모 위젯들

```dart
class MemoItem extends StatelessWidget {
  final RecordMemo memo;
  final bool canModify;          // viewModel.canModify(memo)
  const MemoItem({required this.memo, required this.canModify});

  // 작성자명 + 내용 + 시간
  // canModify == true 이면 trailing 에 IconButton(Icons.more_vert)
  //   → 탭 시 showModalBottomSheet 로 "수정" / "삭제" 액션 시트
}
```

- `MemoSection` — pagination 트리거(`NotificationListener<ScrollNotification>` 또는 `ScrollController`)와 입력창 배치
- `MemoItem` — `onTap` → 텍스트 편집 다이얼로그, `onLongPress` → 삭제 확인 다이얼로그
- `MemoInput` — 텍스트 컨트롤러는 위젯 내부 `StatefulWidget` 으로 두지 않고, **간단한 `StatelessWidget` + 작은 전용 `ChangeNotifier`(`MemoInputController`)** 로 처리해 글로벌 규칙(Provider 프로젝트 = StatelessWidget) 준수

```dart
class MemoInputController extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();
  bool get canSend => textController.text.trim().isNotEmpty;
  void clear() { textController.clear(); notifyListeners(); }
  @override void dispose() { textController.dispose(); super.dispose(); }
}
```

---

## 3. 동작 방식

### 3.1 진입 / 초기 로딩

1. 홈에서 리스트 아이템 탭 → `Navigator.push(RecordDetailScreen(record: ...))`
2. `RecordDetailViewModel` 은 생성과 동시에 record 보유, state = Idle (로딩 단계 없음)
3. MemoListViewModel.refresh() 가 첫 페이지 fetch (state: Loading → Idle)
4. 화면은 즉시 record 본문 렌더 + 메모 영역은 첫 fetch 동안 spinner

### 3.2 기록 수정 — 인플레이스 모달 + 체크 확정

```
[화면 진입]
    └─> 각 필드는 현재값을 보여주는 버튼 형태
[필드 버튼 탭]
    └─> 해당 필드 전용 모달 (bottom sheet/dialog)
        └─> 사용자가 값 변경 후 확인
            └─> viewModel.stageXxx(newValue)
                └─> hasPendingChanges == true → AppBar 체크 아이콘 활성화
                    화면은 새 값으로 즉시 다시 그려짐
[체크 아이콘 탭]
    └─> vm.commitChanges()
        ├─> state = Loading(update)   ← 체크 자리 spinner
        ├─> repository.updateRecord(recordId, draftDetail)
        └─> 성공: _record 로컬 갱신, draft = null, state = Idle
            실패: state = Failure(message), draft 유지
                  → UI snackbar 후 vm.clearError() → Idle
[뒤로가기 (draft 있을 때)]
    └─> "저장하지 않은 변경사항이 있습니다. 나갈까요?" 확인 다이얼로그
```

### 3.3 기록 삭제

- AppBar 휴지통 아이콘 → 확인 다이얼로그
- 확인 → viewModel.deleteRecord()
  - 성공: state = `Deleted` → WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.maybePop(context))
  - 실패: state = `Failure(message)` → snackbar 후 idle

### 3.4 메모 CRUD

- 권한 판정: 메모 ⋮ 메뉴는 View 가 `SessionManager.currentUserId == memo.authorId` 로 판정. (ViewModel 책임 아님)
- 추가: 입력창 전송 → `vm.addMemo(content)` → state = `Loading` (특별한 spinner 표시 없음, 또는 입력창 disable). 성공 시 리스트 맨 뒤 append + 입력창 클리어. 실패 시 snackbar
- 수정: ⋮ → 수정 → 다이얼로그 → `vm.updateMemo(id, content)` → state = `Loading` (별도 spinner UI 없음). 성공 시 in-place 갱신
- 삭제: ⋮ → 삭제 → 확인 → `vm.deleteMemo(id)` → state = `Loading`. 성공 시 리스트에서 제거
- 페이지네이션: 하단 80% 도달 → `loadMore()`. `hasMore=false` 면 무시. 로딩 중에도 기존 `memoList` 그대로 보임

### 3.5 에러 / 일시 success 메시지 채널

- Failure state + clearError:
  - 실패 시 state = Failure(message)
  - UI가 snackbar 표시 후 `vm.clearError()` 호출

---

## 4. 검증 / 테스트

### 4.1 `RecordDetailViewModel` 단위 테스트

| 시나리오 | 검증 |
| --- | --- |
| 생성자 주입된 record 가 그대로 노출 | `vm.record == initialRecord`, state == `Idle` |
| `stageDetail(d)` | `hasPendingChanges == true`, `displayedDetail == d`, listener notify, state Idle 유지 |
| `discardDraft()` | draft null, displayed 는 record.detail 로 복귀 |
| `commitChanges()` (draft 없음) | repo 호출 안 함, state 유지 |
| `commitChanges()` 성공 | state 전이: `Idle → Loading(update) → Idle`. `_record.detail` 가 draft 로 갱신, draft = null |
| `commitChanges()` 실패 | state 전이: `Idle → Loading(update) → Failure(msg)`. draft 유지 |
| `clearError()` | state == `Idle`, listener notify |
| `deleteRecord()` 성공 | state 전이: `Idle → Loading(delete) → Deleted` |
| `deleteRecord()` 실패 | state 전이: `Idle → Loading(delete) → Failure(msg)` |

### 4.2 `MemoListViewModel` 단위 테스트

| 시나리오 | 검증 |
| --- | --- |
| `refresh()` 성공 | `memoList` 채워짐, `cursor` 갱신, state 전이: `Idle → Loading → Idle` |
| `loadMore()` 누적 | append, **state 변동 중에도 기존 memoList 보존** |
| `loadMore()` 마지막 페이지 | `hasMore == false`, 이후 호출은 repo 호출 안 함 |
| `loadMore()` 동시 호출 가드 | state == `Loading` 중에는 중복 호출 무시 |
| `addMemo` 성공 | state: Loading → Idle, 리스트 맨 뒤 append |
| `addMemo` 실패 | state: Failure(msg), 리스트 변경 없음 |
| `updateMemo` 성공 | state: Loading → Idle, 해당 memo content in-place 교체 |
| `deleteMemo` 성공 | state: Loading → Idle, 해당 memo 제거 |

### 4.3 테스트 도구

- `mockito` + `@GenerateMocks([RecordRepository])`
- `SessionManager` 는 ViewModel 책임 아니므로 ViewModel 테스트 의존성에 포함 안 됨
- listener 호출 횟수: `addListener(() => count++)` 헬퍼

---

## 5. 파일 추가/수정 예상 목록

**신규** (`lib/presentation/record_detail/`)

- `record_detail_screen.dart`
- `view_models/record_detail_view_model.dart`
- `view_models/record_detail_ui_state.dart` — sealed class + `RecordDetailAction` enum
- `view_models/memo_list_view_model.dart`
- `view_models/memo_list_ui_state.dart` — sealed class (action 식별자 없음)
- `view_models/memo_input_controller.dart`
- `widgets/record_detail_app_bar.dart`
- `widgets/record_type_detail_view.dart`
- `widgets/details/{diaper, sleep, breast, formula, pumping_feed, pumping, baby_food, snack, water}_detail_view.dart`
- `widgets/common/{detail_field_button, specific_time_button, time_range_button, type_picker_button}.dart`
- `widgets/memo/{memo_section, memo_list, memo_item, memo_input}.dart`
- `widgets/modals/{time_picker_modal, time_range_edit_modal, diaper_type_modal, sleep_type_modal, amount_input_modal, left_right_amount_modal, text_input_modal}.dart`

**도메인 추가**

- `lib/domain/models/record/care_record.dart` 에 `copyWith` 추가 (`commitChanges` 후 `_record` 로컬 갱신용)

**테스트**

- `test/presentation/record_detail/view_models/record_detail_view_model_test.dart`
- `test/presentation/record_detail/view_models/memo_list_view_model_test.dart`

**홈 화면 수정**

- 리스트 아이템 탭 → `RecordDetailScreen(record: tappedRecord)` push