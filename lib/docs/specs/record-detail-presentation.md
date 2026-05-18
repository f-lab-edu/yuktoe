# 📋 Record Detail Screen — Presentation Layer Plan

## 0. 스코프

- **이 PR 범위**: 기록 상세 화면의 **Presentation Layer만** (UI + ViewModel)

## 1. 클래스 관계도

```
                ┌──────────────────────────────────────┐
                │       RecordDetailScreen             │  (StatelessWidget)
                │  - 진입점, Provider scope 생성       │
                └──────────────┬───────────────────────┘
                               │ MultiProvider
            ┌──────────────────┴────────────────────┐
            ▼                                       ▼
┌─────────────────────────────┐    ┌──────────────────────────────────┐
│ RecordDetailViewModel       │    │   MemoListViewModel              │
│ (ChangeNotifier)            │    │   (ChangeNotifier)               │
│ - load/delete/update record │    │   - cursor pagination            │
│ - draft 변경 추적/확정      │    │   - add/update/delete memo       │
└──────────────┬──────────────┘    └──────────────┬───────────────────┘
               │                                  │
               │ depends on                       │ depends on
               ▼                                  ▼
        ┌────────────────────────────────────────────────┐
        │       RecordRepository (+ AuthRepository)      │
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

### 2.1 ViewModels

#### `RecordDetailViewModel`

```dart
class RecordDetailViewModel extends ChangeNotifier {
  RecordDetailViewModel({
    required RecordRepository repository,
    required String recordId,
  });

  ActionState _state = ActionState.idle;
  ActionState get state => _state;
  
  CareRecord? _record;
  CareRecord? get record => _record;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ===== 수정 draft =====
  // 사용자가 모달에서 바꾼 값을 임시 저장. 실제 호출은 체크 아이콘 탭 시.
  RecordDetailData? _draftDetail;
  bool get hasPendingChanges => _draftDetail != null;

  // ===== 수정/삭제 액션 상태 =====
  ActionState _updateState = ActionState.idle;
  ActionState get _updateState => __updateState;

  ActionState _deleteState = ActionState.idle;
  ActionState get deleteState => _deleteState;

  // 액션
  void stageDetail(RecordDetailData value);   // draft 갱신 + notify
  Future<void> load();
  Future<bool> updateRecord({RecordDetailData? detail});
  Future<bool> deleteRecord();               // true 면 화면 pop 신호
}

sealed class RecordDetailUiState {
  const RecordDetailUiState();
}
class Loading extends RecordDetailUiState { const Loading(); }
class Data extends RecordDetailUiState { final CareRecord record; const Data(this.record); }
class LoadError extends RecordDetailUiState { final String message; const LoadError(this.message); }
class Deleted extends RecordDetailUiState { const Deleted(); }
```

- 생성 직후 `load()`가 자동 호출됨 (생성자 안에서 micro-task 로 트리거)
- `deleteRecord()` / `updateRecord()`는 성공 시 `record`/state 갱신, 실패 시 `errorMessage` 만 채우고 state 는 유지

#### `MemoListViewModel`

```dart
class MemoListViewModel extends ChangeNotifier {
  MemoListViewModel({
    required RecordRepository repository,
    required String recordId,
    int pageSize = 20,
  });

  // ===== 페이징 상태 =====
  ActionState _state = ActionState.idle;     // refresh/loadMore 공용
  ActionState get state => _state;

  final List<RecordMemo> _memoList = [];
  List<RecordMemo> get memoList => List.unmodifiable(_memoList);

  String? _cursor;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ===== 권한 헬퍼 =====
  bool canModify(RecordMemo memo);   // memo.authorId == currentUserId

  // ===== 액션 =====
  Future<void> refresh();
  Future<void> loadMore();
  Future<bool> addMemo(String content);
  Future<bool> updateMemo(String memoId, String content);
  Future<bool> deleteMemo(String memoId);
}
```

- 정렬: `created_at` ASC (오래된 메모가 위) — Data Layer 결정 사항 그대로 따름
- `addMemo` 성공 시 리스트 **맨 뒤에 append**
- `updateMemo` / `deleteMemo` 는 in-place 갱신/삭제 (전체 새로고침 안 함)
- `canModify` 는 View 가 케밥(⋮) 메뉴 노출 여부를 결정할 때 사용
- 에러는 `errorMessage` 한 슬롯으로 노출 → View 가 snackbar 로 표시 후 클리어

### 2.2 Screens / Widgets

#### `RecordDetailScreen` (진입점)

```dart
class RecordDetailScreen extends StatelessWidget {
  final String recordId;
  const RecordDetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<RecordRepository>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RecordDetailViewModel(repository: repo, recordId: recordId),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoListViewModel(repository: repo, recordId: recordId)..refresh(),
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

1. 홈에서 리스트 아이템 탭 → `Navigator.push(RecordDetailScreen(recordId: ...))`
2. `RecordDetailViewModel.load()` 가 자동 실행, `state = Loading`
3. Repository 응답:
   - `Ok` → `state = Data(record)`
   - `Error` → `state = LoadError(message)`
4. 병렬로 `MemoListViewModel.refresh()` 가 첫 페이지 fetch

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
    └─> viewModel.updateRecord()
        └─> 성공: draft 초기화 + load() 로 server truth 재동기화, snackbar "저장됨"
            실패: errorMessage 세팅, snackbar 표시, draft 는 유지(재시도 가능)
[뒤로가기 (draft 있을 때)]
    └─> "저장하지 않은 변경사항이 있습니다. 나갈까요?" 확인 다이얼로그
```

### 3.3 기록 삭제

AppBar 휴지통 아이콘 → 확인 다이얼로그
확인 → viewModel.deleteRecord()
성공 → deleteState = success 를 listener 가 아닌 Consumer 의 build 분기 에서 감지 → WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.maybePop(context))
실패 → snackbar

### 3.4 메모 CRUD

- 추가:
  - MemoInput 전송 버튼 → MemoListViewModel.addMemo(content)
  - 성공 → 리스트 맨 뒤 append → 입력창 클리어 → 자동 스크롤 맨 아래
  - 실패 → snackbar
- 수정 (작성자만):
  - MemoItem 의 ⋮ 메뉴 → "수정" 선택
  - 텍스트 편집 다이얼로그 (기존 content prefill)
  - 확인 → updateMemo(memoId, content) → 해당 아이템 in-place 갱신
- 삭제 (작성자만):
  - ⋮ 메뉴 → "삭제" 선택 → 확인 다이얼로그
  - 확인 → deleteMemo(memoId) → 리스트에서 제거
- 페이지네이션: 스크롤이 하단 근처(80%) 도달 → loadMore(). hasMore=false 면 무시
- 빈 상태: 메모 0건이면 "메모를 남겨보세요" placeholder + 입력창

### 3.5 에러 / 로딩 상태 매핑

| 영역 | 상태 소스 | UI 표현 |
| --- | --- | --- |
| 화면 전체 로드 | `RecordDetailViewModel.state` | `loading` → 중앙 progress, `error` → 재시도 버튼 |
| 기록 저장 | `updateState` | `loading` → 체크 아이콘 자리에 spinner, `error` → snackbar |
| 기록 삭제 | `deleteState` | `loading` → AppBar 휴지통 자리에 spinner, `success` → pop, `error` → snackbar |
| 메모 페이지 로드 | `MemoListViewModel.state` | 리스트 끝 작은 spinner |

---

## 4. 검증 / 테스트

### 4.1 `RecordDetailViewModel` 단위 테스트

| 시나리오 | 검증 |
| --- | --- |
| `load()` 성공 | `state: idle → loading → success`, `record` 채워짐, listener 호출됨 |
| `load()` 실패 | `state: error`, `errorMessage` 세팅 |
| `stageRecordedAt(t)` | `hasPendingChanges == true`, listener notify |
| `stageDetail(d)` | `hasPendingChanges == true` |
| `discardDraft()` | draft 필드 모두 null 로, `hasPendingChanges == false` |
| `updateRecord()` 성공 | `updateState: loading → success`, draft 초기화, `load()` 재호출되어 record 갱신 |
| `updateRecord()` 실패 | `updateState: error`, draft 유지, `errorMessage` 세팅, return false |
| `deleteRecord()` 성공 | `deleteState: loading → success`, return true |
| `deleteRecord()` 실패 | `deleteState: error`, `errorMessage` 세팅, return false |

### 4.2 `MemoListViewModel` 단위 테스트

| 시나리오 | 검증 |
| --- | --- |
| `refresh()` 첫 페이지 (`hasMore=true`) | `memoList` 채워짐, `cursor` 갱신됨, `hasMore == true` |
| `loadMore()` 다음 페이지 | 기존 뒤에 append, cursor 갱신 |
| `loadMore()` 마지막 페이지 | `hasMore == false`, 이후 호출은 repo 호출 안 함 |
| `loadMore()` 동시 호출 가드 | `loadState == loading` 중에는 중복 호출 무시 |
| `refresh()` 후 cursor 리셋 | 기존 `memoList` 초기화 후 첫 페이지로 교체 |
| `addMemo` 성공 | 리스트 맨 뒤 append, return true |
| `addMemo` 실패 | 리스트 변경 없음, `errorMessage` 세팅, return false |
| `updateMemo` 성공 | 해당 memoId 의 content 만 in-place 교체, 길이/순서 동일 |
| `updateMemo` 실패 | 리스트 변경 없음, `errorMessage` 세팅 |
| `deleteMemo` 성공 | 해당 memoId 가 리스트에서 제거 |
| `deleteMemo` 실패 | 리스트 변경 없음, `errorMessage` 세팅 |
| `canModify` | `currentUserId == memo.authorId` 면 true, 다르면 false |
| `clearError` | `errorMessage == null`, notify |

### 4.3 테스트 도구

- `mockito` + `@GenerateMocks([RecordRepository, AuthRepository])`
- Mock 의 `getMemos` 는 named param (`cursor`, `limit`) 매처(`any` / 명시값) 둘 다 시나리오별로 사용
- listener 호출 횟수 검증을 위해 `addListener(() => count++)` 헬퍼 사용

---

## 5. 파일 추가/수정 예상 목록

**신규**
- `lib/ui/record_detail/record_detail_screen.dart`
- `lib/ui/record_detail/view_models/record_detail_view_model.dart`
- `lib/ui/record_detail/view_models/memo_list_view_model.dart`
- `lib/ui/record_detail/widgets/record_detail_app_bar.dart`
- `lib/ui/record_detail/widgets/record_type_detail_view.dart`
- `lib/ui/record_detail/widgets/details/{diaper,sleep,breast,formula,pumping_feed,pumping,baby_food,snack,water}_detail_view.dart` (9개)
- `lib/ui/record_detail/widgets/common/{specific_time_row,time_range_row,detail_field}.dart`
- `lib/ui/record_detail/widgets/memo/{memo_section,memo_list,memo_item,memo_input}.dart`

**테스트**
- `test/ui/record_detail/view_models/record_detail_view_model_test.dart`
- `test/ui/record_detail/view_models/memo_list_view_model_test.dart`
- `test/ui/record_detail/widgets/record_type_detail_view_test.dart`
- 필요 시 각 detail view 의 widget test

**홈 화면 수정**
- 리스트 아이템 탭 → `RecordDetailScreen` push 코드 한 줄 추가