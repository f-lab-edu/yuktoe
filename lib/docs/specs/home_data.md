# 📋 Home Screen — Data Layer

## 0. 스코프

- **이 PR 범위**:
    - 홈 화면이 필요로 하는 **Data Layer** (Repository / Service / Model)
    - **선택된 아기 ID**의 저장 / 노출을 담당하는 **앱 상태 클래스** (`AppState`)
- **이 PR 범위 아님**:
    - `HomeViewModel`, 홈 화면 위젯 등 Presentation Layer
    - 본 spec의 §6 "동작 방식"은 호출자(=ViewModel) 관점 참고용

---

## 1. 클래스 관계도

```
                ┌─────────────────────────────────┐
                │   HomeViewModel  (별도 PR)      │
                └───────────────┬─────────────────┘
                                │ depends on
                ┌────────────┬──┴────────────────┐
                ▼            ▼                   ▼               
        ┌──────────────┐ ┌──────────────────┐ ┌────────────────┐ 
        │ BabyRepo     │ │ RecordRepo       │ │ AppState       │ 
        │ -getMyBabies │ │ -getRecords      │ │ (ChangeNotif)  │ 
        │  → List<     │ │ -createRecord    │ │ -selectedBaby  │ 
        │   BabyList   │ │ -deleteRecord    │ │   Id           │ 
        │   Item>      │ │ -getRecent*      │ │ -selectBaby()  │ 
        │ -getBaby     │ │   (Feedings,     │ │ -clearSelected │ 
        │  → Baby      │ │    Diapers,      │ │   Baby()       │ 
        │              │ │    Wakes)        │ │                │ 
        └──────┬───────┘ └────────┬─────────┘ └────────┬───────┘ 
               ▼                  ▼                    ▼
        ┌──────────────┐ ┌──────────────────┐  ┌──────────────────┐
        │ BabyService  │ │ RecordService    │  │ SharedPreferences│
        │ (Supabase)   │ │ (Supabase)       │  │ (직접 사용)      │
        └──────┬───────┘ └────────┬─────────┘  └──────────────────┘
               └────────┬─────────┘
                        ▼
               ┌─────────────────┐
               │ SupabaseClient  │
               └─────────────────┘
```

- ViewModel은 **Repository** 와 **AppState** 만 의존한다. Service / SupabaseClient / SharedPreferences 는 노출하지 않는다.
- Repository는 입력으로 `babyId`를 받는다. "현재 선택된 아기"의 판정은 `AppState`의 책임이며, ViewModel이 `AppState.selectedBabyId`를 읽어 Repository에 전달한다.

---

## 2. 도메인 모델

### 2.1 아기 도메인 모델

홈 화면은 두 가지 다른 형태의 아기 정보를 사용한다. 각 쿼리가 필요로 하는 데이터의 폭이 다르므로, 도메인 모델을 분리해 책임을 명확히 한다.

| 모델 | 위치 | 필드 | 용도 |
|---|---|---|---|
| `BabyListItem` | `lib/domain/models/baby/baby_list_item.dart` | `id`, `name` | "선택 후보 목록" 표시 — 사용자가 어떤 아기로 전환할지 고르는 BottomSheet 등. 무거운 필드는 알 필요가 없다. |
| `Baby` | `lib/domain/models/baby/baby.dart` | `id`, `name`, `birthDate` (nullable), `dueDate` (nullable), `gender` | "현재 선택된 아기의 기본 정보" 표시 — 홈 상단의 이름 / D-day / D+N 등 계산의 원본. |

- `BabyListItem` 은 list view 에 들어가는 가벼운 모델이다. 사용자가 한 명만 선택하면 그 아기에 대해서는 별도로 `Baby` 를 조회한다.
- `Baby.birthDate` 와 `Baby.dueDate` 는 둘 다 null 일 수 있다 (출생 전 / 입양 등). 도메인 모델은 원본 값만 보유한다.
- D+N / D-N 등 사용자에게 보여줄 문자열은 **ViewModel 이상에서 계산**한다. Data Layer 는 원본만 노출한다.
- `Gender` 는 기존 `lib/constants/enum/gender.dart` 의 enum 을 그대로 사용한다.

### 2.2 `RecordsCursor`

cursor 기반 pagination. 위치: `lib/domain/models/common/page.dart` (제네릭이므로 Data 또는 Domain 중 도메인에 둠).

```dart
class RecordsCursor {
  final DateTime occurredAt;
  final String id;
  const RecordsCursor({required this.occurredAt, required this.id});
}
```

- 같은 `occurredAt`을 가진 행이 여러 개 있어도 누락되지 않도록 **(occurredAt, id) 복합 cursor**를 사용한다.
- ViewModel은 `nextCursor`를 그대로 들고 다음 호출 시 `getRecords(..., cursor: page.nextCursor)`로 넘긴다.

---

## 3. AppState (앱 상태 클래스)

Data Layer는 아니지만 본 PR에서 진행. 위치: `lib/common/app_state/app_state.dart`.

### 3.1 책임

- 사용자가 마지막으로 보던 아기 ID(`selectedBabyId`)를 **로컬에 저장**하고 앱 전체에 노출한다.
- ViewModel은 `AppState.selectedBabyId`를 읽어 Repository 호출 시 `babyId`로 사용한다.
- ViewModel은 아기 전환 시 `selectBaby(id)`를 호출하여 상태를 변경하고, 그 결과로 데이터 재조회를 트리거한다.
- 로그아웃 시 `clearSelectedBaby()` 호출.

### 3.2 인터페이스

```dart
class AppState extends ChangeNotifier {
  static const _key = 'selected_baby_id';
  final SharedPreferences _prefs;

  AppState(this._prefs);

  /// 현재 선택된 아기 ID. 없으면 null.
  String? get selectedBabyId => _prefs.getString(_key);

  /// 선택된 아기를 변경하고 영속화한다.
  Future<void> selectBaby(String babyId) async {
    await _prefs.setString(_key, babyId);
    notifyListeners();
  }

  /// 선택된 아기를 비운다. 로그아웃 등에서 사용.
  Future<void> clearSelectedBaby() async {
    await _prefs.remove(_key);
    notifyListeners();
  }
}
```

### 3.3 주요 결정

- **Provider 프로젝트 규칙에 따라 `ChangeNotifier` + Provider로 노출**한다. 위젯은 `context.watch<AppState>()`로 구독한다.
- `SharedPreferences`는 동기 API(`getString`)이므로 `selectedBabyId` getter는 동기로 둔다.
- `init()` 같은 명시적 부트스트랩 단계는 두지 않는다. (DI 컨테이너에서 미리 awaited `SharedPreferences.getInstance()` 결과를 주입한다 — §7 참조.)
- **"저장된 ID 가 현재 사용자의 접근 가능한 아기 목록에 없으면 첫 번째 아기를 기본 선택" 로직은 `AppState`가 아닌 `HomeViewModel`(별도 PR)의 책임**이다. `AppState`는 단순히 값의 영속화 / 노출만 담당한다 — 목록 검증은 Data Layer 호출 결과를 알아야 하므로 ViewModel 영역.

### 3.4 빈 / 실패 케이스

- 저장된 값이 없으면 `selectedBabyId`는 `null`을 반환한다 (에러 아님).
- `SharedPreferences` 읽기/쓰기는 실패 케이스를 별도로 다루지 않는다 (플랫폼 의존이며 본 PR에서는 throw를 허용).

---

## 4. Repository

### 4.1 BabyRepository

#### 목적

홈 화면이 "어떤 아기를 보여줄 것인가"를 결정하기 위한 **선택 후보 목록**과, "현재 선택된 아기" 의 **기본 정보**를 제공한다.

#### 책임

- 현재 로그인 사용자가 멤버로 등록된 아기들의 **목록**을 제공한다.
- 특정 아기 ID 에 대해 화면 표시에 필요한 **기본 정보**를 제공한다.
- "내가 볼 수 있는 아기" 의 정의는 도메인적으로 `baby_members` 에 그 사용자가 멤버로 등록된 아기다. Repository 는 이 정의를 그대로 반영해 노출한다.
- 화면 표시용 가공 (라벨, 마스킹, D-day, D+N 등) 은 수행하지 않는다. 원본 값만 노출한다.

#### 호출자

- `HomeViewModel` — 홈 진입 시 목록 + 기본 정보 조회. 멤버십 변경 (아기 추가/탈퇴) 직후 목록 재조회. 아기 전환 시 새 선택된 아기의 기본 정보 조회.

#### 주요 결정

- `userId` 를 인자로 받지 않는다. 현재 사용자는 Service 가 Supabase Auth 로부터 판단한다. 호출자가 잘못된 userId 를 줄 가능성을 차단한다.
- **목록과 기본 정보 조회를 분리**한다. 둘은 필요한 데이터의 폭이 다르고 (목록: id+name, 기본 정보: 5필드), 무효화 시점도 다르다 (목록: 멤버십 변경, 기본 정보: 아기 전환 / 본인 프로필 수정). 도메인 모델도 분리한다 (`BabyListItem` vs `Baby` — §2.1).

#### 4.1.1 메서드 요구사항: 사용자가 접근 가능한 아기 목록 조회

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈에서 "어떤 아기를 볼 것인가" 를 선택할 후보 목록을 제공한다. |
| 입력 | 없음. 현재 사용자는 Service 가 Auth 로부터 판단한다. |
| 호출 시점 | 홈 진입 시 1회. 멤버십 변경 (아기 추가/탈퇴) 후 재조회. |
| 결과 데이터 | `List<BabyListItem>` — 각 항목은 **`id`** 와 **`name`** 만 포함한다. 생년월일 / 출산예정일 / 성별 같은 무거운 필드는 포함하지 않는다. |
| 결과 정렬 | 생성일 내림차순 (`babies.created_at desc`). UX 요구: "내가 가장 최근에 추가한 아기를 가장 위로". |
| 성공 조건 | 사용자가 인증되어 있고, 그 사용자가 멤버인 모든 babies 행을 조회/매핑할 수 있어야 한다. |
| 빈 데이터 | 접근 가능한 아기가 없으면 **빈 리스트를 에러로** 보고 `Result.error(AppException(notFound))`** 로 표현한다. 빈 결과를 성공으로 보지 않는 이유: 아기를 등록하거나 등록된 아기에 초대돼야 진입할 수 있으므로 빈 리스트는 에러를 throw한다. |
| 실패 케이스 | 네트워크/Supabase 호출 실패 → `unknown` 또는 `networkError`. 인증 만료/미로그인 → `unauthorized`. 응답 파싱 실패 → `parseFailed`. 모두 `Result.error(AppException)` 로 표현. |
| null 처리 | 결과 리스트 자체는 non-null. `BabyListItem` 의 두 필드 모두 non-null. |

#### 4.1.2 메서드 요구사항: 현재 선택된 아기의 기본 정보 조회

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 상단에 표시할 아기 이름 / D+N / D-day 등의 계산 원본을 제공한다. |
| 입력 | `babyId` (필수). 호출자가 `AppState.selectedBabyId` 로부터 가져온 값을 그대로 전달한다. |
| 호출 시점 | 홈 진입 시 (선택된 아기 결정 직후). 아기 전환 시. 본인이 아기 프로필을 수정한 직후. |
| 결과 데이터 | `Baby` — **`id`**, **`name`**, **`birthDate`** (nullable), **`dueDate`** (nullable), **`gender`** 5개 필드. 모두 원본 값 그대로. |
| 결과 정렬 | 단일 항목이므로 정렬 무관. |
| 성공 조건 | 사용자가 인증되어 있고, 해당 `babyId` 에 멤버로 접근 가능하며, 행이 존재해야 한다. |
| 빈 데이터 / 미존재 | 호출 시점에 해당 `babyId` 가 존재하지 않거나 (삭제됨 등) 권한이 없을 수 있다. **본 PR 정책: `Result.error(AppException(notFound))`** 로 표현한다. 빈 결과를 성공으로 보지 않는 이유: "현재 선택된 아기" 의 정보 조회는 단일 대상에 대한 명확한 요청이며, 행이 없다는 것은 호출자가 다음 동작 (목록 재조회 + 다른 아기 선택) 을 취해야 하는 신호다. |
| 실패 케이스 | `notFound` (위), `unauthorized`, `networkError`, `parseFailed`. 모두 `Result.error(AppException)`. |
| null 처리 | `birthDate` 와 `dueDate` 는 각각 독립적으로 null 일 수 있다. 둘 다 null 인 경우도 정상이다. ViewModel 이 D-day/D+N 표시 가능 여부를 판단한다. |

---

### 4.2 RecordRepository

#### 목적

현재 선택된 아기에 대해 홈 화면이 보여줘야 하는 **모든 기록 데이터**를 제공하고, 사용자의 기록 생성/삭제 의도를 영속화한다.

#### 책임

- 기록 리스트 조회 — 홈 메인 영역의 무한 스크롤을 지원하는 페이지 단위 조회.
- 카테고리별 최근 요약 — 수유 / 기저귀 / 기상 카테고리에 대해 최근 2건을 제공해 "마지막으로 N시간 전에 ~했어요" 표시를 가능하게 한다.
- 기록 생성 — `RecordDetailData` 로 표현 가능한 모든 타입의 기록을 영속화하고, DB 반영 결과를 즉시 도메인 모델로 돌려준다.
- 기록 삭제 — 기록 ID 로 식별되는 기록을 영구 삭제한다.
- 모든 결과는 도메인 모델 + `Result` 형태로 ViewModel 에 제공한다.

#### 호출자

- `HomeViewModel`.

#### 주요 결정

- 모든 메서드는 `babyId` 를 인자로 받는다. "현재 선택된 아기" 의 판정은 `AppState` / `HomeViewModel` 의 책임이고, Repository 는 받은 `babyId` 를 그대로 신뢰한다.
- 기록 생성 시 호출자는 `userId` 를 전달하지 않는다. `createdBy` 는 Service 가 Supabase Auth 의 현재 사용자로 채운다.
- 정렬 기준은 카테고리에 따라 달라질 수 있다 (수유: `breast` 만 종료 시각 기준, 기상: 종료 시각 기준). 이 차이는 Repository 가 외부에 노출하는 **계약**이며, 호출자는 정렬 규칙을 알 필요 없이 결과의 순서를 신뢰할 수 있어야 한다.
- 본 PR 에서는 기록을 캐싱하지 않는다. 따라서 생성/삭제 후 ViewModel 이 in-memory 리스트를 직접 정합화한다.

#### 4.2.1 메서드 요구사항: 기록 리스트 조회 (페이지 단위)

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈의 무한 스크롤 기록 리스트를 페이지 단위로 제공한다. |
| 입력 | `babyId` (필수), `cursor` (없으면 첫 페이지), `limit` (기본 20). |
| 호출 시점 | 첫 페이지 — 홈 진입 시 / 아기 전환 시 / 기록 생성·삭제 후 리스트 동기화. 다음 페이지 — 스크롤이 하단에 도달했을 때. |
| 결과 데이터 | `Page<CareRecord>` — `items`, `nextCursor` (nullable), `hasMore`. 각 `CareRecord` 항목의 필드: **`id`**, **`babyId`**, **`type`**, **`occurredAt`**, **`endedAt`** (sleep/breast 만), **`createdBy`**, **`createdAt`**, **`detail`** (`RecordDetailData` sealed 변종). 리스트 / 상세 / 삭제 어떤 화면에서도 동일한 모델을 사용하므로 모든 필드를 채워서 반환한다. |
| 결과 정렬 | `occurredAt` 내림차순. 동일 시각이면 `id` 내림차순으로 tie-break. |
| 페이지네이션 보장 | 결과에는 다음 페이지 존재 여부와 다음 cursor 가 포함되어야 한다. 같은 `occurredAt` 을 가진 기록이 페이지 경계에 걸쳐 누락되지 않도록 **(occurredAt, id) 복합 cursor** 를 사용한다. |
| 페이지 크기 | 기본 20. 호출자가 override 가능. |
| 빈 데이터 | 기록이 없으면 빈 페이지 (`items = []`, `hasMore = false`, `nextCursor = null`) 를 성공으로 반환한다. 에러가 아니다. |
| 실패 케이스 | 네트워크 / 인증 / 권한 오류 → `Result.error(AppException)`. 호출자는 동일한 cursor 로 재시도할 수 있어야 한다. |
| null 처리 | 결과 행에서 `occurredAt`, `id`, `createdBy`, `detail` 은 모두 non-null (DB 보장). `endedAt` 은 breast / sleep 외에는 null. |

#### 4.2.2 메서드 요구사항: 최근 수유 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 요약 영역의 "마지막으로 N시간 전에 먹였어요" 표시 및 그 직전 수유와의 간격 계산에 필요한 최근 수유 기록을 제공한다. |
| 포함 타입 | 수유 4종 — `breast`, `formula`, `pumping`, `babyFood`. |
| 입력 | `babyId`, `limit` (기본 2). |
| 호출 시점 | 홈 진입 시. 수유 기록 생성/삭제 후 재조회. |
| 결과 데이터 | `List<CareRecord>` (최대 `limit` 개). 각 항목은 §4.2.1 과 동일한 `CareRecord` 모델 — 모든 필드(`id`, `babyId`, `type`, `occurredAt`, `endedAt`, `createdBy`, `createdAt`, `detail`) 가 채워진다. 호출자가 같은 모델로 리스트 동기화 / 삭제 호출 등을 이어갈 수 있도록 부분 모델은 사용하지 않는다. |
| 기준 시각 정의 | "마지막으로 N시간 전에 먹였니" 의 자연스러운 해석은 *수유가 끝난 뒤* 의 경과 시간이다. 이에 맞춰: `breast` → `endedAt`, 나머지 3종 → `occurredAt` 을 기준 시각으로 삼는다. |
| 결과 정렬 | 위에서 정의한 기준 시각의 내림차순. 동일 시각이면 `id` 내림차순. |
| 제외 조건 | `breast` 이면서 `endedAt` 이 null 인 행 (= 수유 진행 중) 은 본 PR 에서는 조회 대상에서 제외한다. "진행 중 수유" UX 는 후속 PR. |
| 빈 데이터 | 수유 기록이 없으면 빈 리스트. 1건만 있으면 1건만. |
| 실패 케이스 | `Result.error(AppException)`. |
| null 처리 | 결과 리스트는 non-null. 결과 항목들의 `endedAt` 은 breast 외 3종에서는 null. |

#### 4.2.3 메서드 요구사항: 최근 기저귀 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 요약 영역의 "마지막으로 N시간 전에 기저귀 갈았어요" 표시에 필요한 최근 기저귀 기록을 제공한다. |
| 포함 타입 | `diaper`. |
| 입력 | `babyId`, `limit` (기본 2). |
| 호출 시점 | 홈 진입 시. 기저귀 기록 생성/삭제 후 재조회. |
| 결과 데이터 | `List<CareRecord>` (최대 `limit` 개). 모든 항목의 `type == diaper`. 모든 필드 채워서 반환. `endedAt` 은 항상 null. |
| 결과 정렬 | `occurredAt` 내림차순. 동일 시각이면 `id` 내림차순. |
| 빈 데이터 | 없으면 빈 리스트. 1건만 있으면 1건만. |
| 실패 케이스 | `Result.error(AppException)`. |

#### 4.2.4 메서드 요구사항: 최근 기상 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 요약 영역의 "마지막으로 N시간 전에 일어났어요" 표시에 필요한 최근 기상 시점을 제공한다. "기상" 은 수면 기록의 종료 시점으로 정의된다. |
| 포함 타입 | `sleep`. |
| 입력 | `babyId`, `limit` (기본 2). |
| 호출 시점 | 홈 진입 시. 수면 기록 생성/삭제/종료 직후 재조회. |
| 결과 데이터 | `List<CareRecord>` (최대 `limit` 개). 모든 항목의 `type == sleep`, **`endedAt` 은 항상 non-null** (= 이미 종료된 수면만 반환). 그 외 필드는 모두 채워져 있다. |
| 기준 시각 | 수면 기록의 `endedAt` (= 기상 시각). |
| 결과 정렬 | `endedAt` 내림차순. 동일 시각이면 `id` 내림차순. |
| 제외 조건 | `endedAt` 이 null 인 수면 (= 수면 진행 중) 은 조회 대상에서 제외한다. 본 메서드는 "기상 시점" 을 다루기 때문이다. |
| 빈 데이터 | 종료된 수면이 없으면 빈 리스트. 1건만 있으면 1건만. |
| 실패 케이스 | `Result.error(AppException)`. |

#### 4.2.5 메서드 요구사항: 기록 생성

| 항목 | 요구사항 |
|---|---|
| 목적 | 사용자의 새 기록 (수유 / 기저귀 / 수면) 을 영속화하고, DB 반영 결과를 즉시 도메인 모델로 반환한다. |
| 입력 | `babyId`, `detail` (`RecordDetailData`). |
| 호출 시점 | 사용자가 기록 작성 UI 에서 저장을 확정할 때. |
| 메타데이터 결정 | `type`, `occurredAt`, `endedAt` 은 호출자가 별도로 전달하지 않는다. 모두 `detail` 객체 안에 내재되어 있으며, 그 객체 하나를 source of truth 로 본다. |
| `createdBy` | 호출자가 전달하지 않는다. Service 가 Supabase Auth 의 현재 사용자로 채운다. 잘못된 userId 가 전파될 위험을 차단하기 위함이다. |
| 성공 조건 | DB insert 가 성공하고, insert 결과 행이 다시 `CareRecord` 도메인 모델로 매핑된다. |
| 결과 데이터 | `Result.ok(CareRecord)` — 단일 `CareRecord`. DB 가 채운 **`id`**, **`createdAt`** 과, generated column 으로 채워진 **`endedAt`** (sleep/breast 일 때) 를 포함한 모든 필드 (`babyId`, `type`, `occurredAt`, `createdBy`, `detail`) 가 채워져 있다. ViewModel 은 이 모델을 그대로 리스트 맨 앞에 append 할 수 있어야 한다. |
| 빈 데이터 | 해당 없음 (생성은 항상 한 건). |
| 실패 케이스 | 미로그인/만료 → `unauthorized`. RLS 거부 (해당 아기의 멤버 아님) → `unauthorized`. 네트워크 실패 → `networkError`. 응답 파싱 실패 → `parseFailed`. 모두 `Result.error(AppException)`. |
| null 처리 | `endedAt` 은 sleep / breast 외에는 null. 정상 값이다. |

#### 4.2.6 메서드 요구사항: 기록 삭제

| 항목 | 요구사항 |
|---|---|
| 목적 | `recordId` 로 식별되는 기록을 영구 삭제한다. |
| 입력 | `recordId`. |
| 호출 시점 | 사용자가 기록 항목 삭제를 확정할 때. |
| 권한 | Repository 는 권한을 확인하지 않는다. 삭제 권한 판정은 전적으로 Supabase RLS 가 수행한다. |
| 성공 조건 | DB delete 가 정상 응답을 반환했을 때. |
| 결과 데이터 | `Result.ok(null)`. 반환 페이로드 없음. 호출자는 삭제된 항목의 정보가 필요하면 자신이 들고 있는 in-memory 모델을 사용한다. |
| 실패 케이스 | RLS 거부 / 네트워크 실패 / 존재하지 않는 ID / 기타 Supabase 오류 모두 `Result.error(AppException)` 로 통일된다. 호출자는 실패 유형 (권한 vs. 네트워크) 을 `AppException.code` 로 구분한다. |
| 부작용 | Repository 내부 캐시가 없으므로 내부 정리는 없다. ViewModel 이 자신의 in-memory 리스트에서 해당 항목을 제거한다. |

---

## 5. Service

### 5.0 레이어 위치 / 공통 계약

- Service 는 Repository 의 **하부 협력 클래스**다. Supabase SDK 호출, raw 응답 매핑, 인증 사용자 ID 주입 같은 외부 시스템 연동 책임을 담당한다.
- Service 는 ViewModel 에 노출되지 않는다. 오직 Repository 만이 Service 에 의존한다.
- Service 메서드도 `Result<T>` 를 반환한다. throw 하지 않으며, 네트워크/파싱/인증 오류 등 모든 실패는 `AppException` 으로 변환된다.
- Service 의 모든 매핑 결과는 도메인 모델이다. Supabase row / `Map<String, dynamic>` / DTO 는 Service 경계 밖으로 새 나가지 않는다.

---

### 5.1 BabyService

#### 목적

`BabyRepository` 가 도메인 정의 ("내가 멤버인 아기", "이 아기의 기본 정보") 만 신경 쓸 수 있도록, Supabase 의 `babies` 테이블 조회와 row → 도메인 모델 매핑을 책임진다.

#### 책임

- Supabase Auth 의 현재 사용자 컨텍스트 안에서 `babies` 를 조회한다.
- "내가 멤버인 아기" 의 필터링은 Supabase RLS 정책에 위임한다. Service 는 별도로 `baby_members` 와 join 하지 않는다.
- 목록 조회 결과를 `BabyListItem` (id, name) 으로 매핑한다 — 불필요한 컬럼은 select 단계에서 제외하여 응답 크기를 최소화한다.
- 단건 조회 결과를 `Baby` (id, name, birthDate, dueDate, gender) 로 매핑한다.
- 목록 정렬 기준 (생성일 내림차순) 을 보장한다.

#### 호출자

- `BabyRepository` 만 호출한다.

#### 5.1.1 메서드 요구사항: 사용자의 아기 목록 조회

| 항목 | 요구사항 |
|---|---|
| 입력 | 없음. |
| 동작 | `babies` 에서 **`id`, `name` 컬럼만 select** 하고 `created_at desc` 로 정렬한 결과를 row → `BabyListItem` 매핑하여 반환한다. |
| 인증 컨텍스트 | Supabase 클라이언트에 설정된 현재 세션을 사용한다. RLS 가 멤버십을 강제하므로 별도의 user 필터는 추가하지 않는다. |
| 결과 데이터 | `List<BabyListItem>` — 각 항목 `id`, `name`. |
| 빈 데이터 | 빈 리스트를 성공으로 반환한다. |
| 실패 | Supabase 예외 / 파싱 실패 모두 `Result.error(AppException)` 로 변환한다. |

#### 5.1.2 메서드 요구사항: 단일 아기의 기본 정보 조회

| 항목 | 요구사항 |
|---|---|
| 입력 | `babyId`. |
| 동작 | `babies` 에서 **`id`, `name`, `birth_date`, `due_date`, `gender` 5개 컬럼**을 `eq('id', babyId).maybeSingle()` 로 조회한 결과를 row → `Baby` 매핑하여 반환한다. |
| 인증 컨텍스트 | Supabase 클라이언트에 설정된 현재 세션을 사용한다. RLS 가 멤버십을 강제하므로 별도의 user 필터는 추가하지 않는다 — 멤버가 아니면 결과가 비어 있을 것이다. |
| 결과 데이터 | `Baby` 또는 미존재. |
| 미존재 처리 | `maybeSingle()` 이 null 을 반환 (행 없음 = 삭제됨 / 멤버 아님 / id 오타) 하면 Service 가 `Result.error(AppException(notFound))` 로 변환한다. Repository 가 별도 변환 없이 그대로 전달한다. |
| 실패 | Supabase 예외 / 파싱 실패 모두 `Result.error(AppException)` 로 변환한다. |

---

### 5.2 RecordService

#### 목적

`RecordRepository` 가 도메인 계약만 노출할 수 있도록, Supabase `care_records` 테이블의 조회 / 생성 / 삭제 와 row → `CareRecord` 매핑을 책임진다.

#### 책임

- 페이지 단위 조회 — (occurredAt, id) 복합 cursor 와 `limit + 1` 트릭으로 `hasMore` 를 판정해 `Page<CareRecord>` 로 돌려준다.
- 카테고리별 최근 N 건 조회 — 호출자가 지정한 타입 집합과 정렬 기준 컬럼에 따라 단일 쿼리로 처리한다. (정렬 기준 컬럼 후보: `occurred_at`, `ended_at`, `feeding_effective_at` — §7 참조)
- 기록 생성 — 호출자가 전달한 메타데이터에 더해 `createdBy` 를 Supabase Auth 의 현재 사용자 ID 로 자동 채운다. 인증 사용자가 없으면 `unauthorized` 로 실패한다.
- 기록 삭제 — RLS 가 권한을 강제하므로 Service 는 단순 delete 만 수행한다.
- row → `CareRecord` 매핑 — aggregate 매핑은 Service 가 책임진다. (leaf `RecordDetailData` 의 매핑은 sealed `fromJson(type, json)` 에 위임한다.)

#### 호출자

- `RecordRepository` 만 호출한다.

#### 5.2.1 메서드 요구사항: 페이지 단위 조회

| 항목 | 요구사항 |
|---|---|
| 입력 | `babyId`, `cursor` (옵션), `limit`. |
| 정렬 | `occurred_at desc, id desc`. |
| 페이지네이션 | `cursor` 가 주어지면 `(occurred_at, id) < cursor` 조건을 추가한다. 동일 `occurred_at` 다중 행 누락 방지. |
| `hasMore` 판정 | `limit + 1` 개를 조회해 초과분이 있으면 `hasMore = true` 로 표시하고, 초과분은 결과에서 제거한다. |
| `nextCursor` | `hasMore` 일 때 마지막 항목의 `occurredAt` 과 `id` 로 구성한다. |
| 빈 데이터 | 빈 페이지를 성공으로 반환한다. |
| 실패 | Supabase 예외 / 파싱 실패 모두 `Result.error(AppException)`. |

#### 5.2.2 메서드 요구사항: 카테고리별 최근 N 건 조회

| 항목 | 요구사항 |
|---|---|
| 입력 | `babyId`, `types` (`Set<RecordType>`), `orderColumn` (열거형: `occurred_at` / `ended_at` / `feeding_effective_at`), `limit`. |
| 동작 | `type in types` 로 필터링하고, `orderColumn` 컬럼이 null 이 아닌 행만 대상으로 `orderColumn desc, id desc` 정렬 후 `limit` 개를 가져온다. |
| 누가 어느 인자로 호출하나 | Repository 의 매핑 — 수유 최근: `(types = {breast, formula, pumping, babyFood}, orderColumn = feeding_effective_at)`. 기저귀 최근: `(types = {diaper}, orderColumn = occurred_at)`. 기상 최근: `(types = {sleep}, orderColumn = ended_at)`. |
| null 제외 | `orderColumn IS NOT NULL` 조건이 곧 "진행 중 breast / sleep 자동 제외" 효과를 낸다. |
| 빈 데이터 | 빈 리스트를 성공으로 반환한다. |
| 실패 | Supabase 예외 / 파싱 실패 모두 `Result.error(AppException)`. |

#### 5.2.3 메서드 요구사항: 기록 생성

| 항목 | 요구사항 |
|---|---|
| 입력 | `babyId`, `type`, `detailJson` (`Map<String, dynamic>`), `occurredAt`, `endedAt`. Repository 가 `detail` 을 분해해 전달한다. |
| `createdBy` 결정 | Supabase Auth 의 `currentUser.id`. 없으면 `unauthorized` 로 즉시 실패. |
| DB 매핑 | `baby_id`, `type`, `occurred_at`, `ended_at`, `detail` (jsonb), `created_by` 컬럼에 매핑하여 insert. `ended_at` 컬럼은 generated 이지만 명시적으로 넣지 않는다 — `detail.ended_at` 으로부터 generated column 이 채운다 (§7.2). |
| 응답 처리 | insert 결과 행을 다시 `_mapRecord` 로 변환해 `CareRecord` 를 돌려준다. |
| 실패 | Supabase 예외 / RLS 거부 / 파싱 실패 모두 `Result.error(AppException)`. |

#### 5.2.4 메서드 요구사항: 기록 삭제

| 항목 | 요구사항 |
|---|---|
| 입력 | `recordId`. |
| 동작 | `delete().eq('id', recordId)`. |
| 권한 | RLS 가 결정한다. Service 는 사전 검사를 하지 않는다. |
| 성공 조건 | Supabase 가 예외 없이 응답했을 때. 영향 받은 행 수는 별도로 확인하지 않는다. |
| 실패 | RLS 거부 / 네트워크 / 기타 모두 `Result.error(AppException)`. |

---

### 5.3 매핑 책임 분리

- **`BabyListItem` 매핑** — Service 내부 `_mapBabyListItem` 가 row → `BabyListItem` 변환을 담당한다. `id`, `name` 만 다룬다.
- **`Baby` 매핑** — Service 내부 `_mapBaby` 가 row → `Baby` 변환을 담당한다. `id`, `name`, `birth_date`, `due_date`, `gender` 를 변환한다. `created_at` 은 도메인 모델에 없으므로 매핑하지 않는다.
- **`CareRecord` 매핑** — Service 내부 `_mapRecord` 가 row → `CareRecord` 변환을 담당한다. `CareRecord` 는 aggregate 이며, 향후 cross-table 필드 (예: `baby_members.nickname` 임베딩) 가 추가될 가능성이 있으므로 매핑은 Data Layer 의 책임으로 둔다.
- **`RecordDetailData` 매핑** — leaf value object 규칙에 따라 각 sealed 변종이 `toJson()` / `fromJson(json)` 을 직접 보유한다. base 클래스의 `RecordDetailData.fromJson(type, json)` 이 `type` 에 따라 dispatch 한다. Service 의 `_mapRecord` 는 이 dispatcher 만 호출한다.
- 매핑 실패는 Service 안에서 catch 하여 `AppException(parseFailed)` 로 변환한다.

---

## 6. 동작 방식 (호출자 관점, 참고용)

### 6.1 진입 — 홈 화면 초기 로드 (ViewModel 의사 코드)

```
1. babies = babyRepository.getMyBabies()                    // Result<List<BabyListItem>>
2. savedId = appState.selectedBabyId                        // String? (sync)
3. currentBabyId :=
     if savedId != null && babies.any(b => b.id == savedId) then savedId
     else if babies.isNotEmpty                              then babies.first.id
     else                                                        null
   (savedId 가 stale 였다면 appState.selectBaby(currentBabyId) 로 정합화)
4. currentBabyId 가 null 이면 "아기 없음" 상태로 종료
5. 병렬:
   a. babyRepository.getBaby(currentBabyId)                  // 기본 정보
   b. recordRepository.getRecords(currentBabyId, cursor: null, limit: 20)
   c. recordRepository.getRecentFeedings(currentBabyId)
   d. recordRepository.getRecentDiapers(currentBabyId)
   e. recordRepository.getRecentWakes(currentBabyId)
6. 결과 합성 후 화면 렌더
```

### 6.2 아기 전환

```
1. UI 가 chevron → BottomSheet 로 babies 목록 (BabyListItem) 표시
2. 사용자가 다른 baby 선택 → appState.selectBaby(newId)
3. ViewModel 이 appState 의 변경을 감지(Provider) → §6.1 의 step 5 부터 재실행 (getBaby + getRecords + getRecent*)
```

### 6.3 기록 생성 / 삭제 / infinite scroll

- **생성**: `recordRepository.createRecord(babyId, detail)` → 성공 시 ViewModel 이 리스트 맨 앞 append + 해당 카테고리의 `getRecent*` 재호출.
- **삭제**: `recordRepository.deleteRecord(id)` → 성공 시 리스트에서 제거 + 삭제된 기록이 해당 카테고리의 최근 2개 중 하나였다면 `getRecent*` 재호출.
- **infinite scroll**: 하단 도달 → `getRecords(babyId, cursor: page.nextCursor)` → append. `hasMore == false` 이후는 호출하지 않는다.

---

## 7. 검증 / 테스트

### 7.1 도메인 단위 테스트

- `Baby` 모델: 현재 spec 의 `Baby` 는 birthDate/dueDate 를 보관만 한다. **계산 로직(생후 일수 / D-day) 은 본 PR 도메인에 두지 않는다** → Baby 단위 테스트는 본 PR 범위 아님.
  - 만약 ViewModel 단계에서 같은 계산이 여러 곳에 반복된다고 판단되면 후속 PR 에서 도메인으로 끌어올리고 그 시점에 테스트 추가.
- `RecordDetailData` 변종: `toJson` / `fromJson` round-trip 테스트 (각 변종별 1개씩). leaf value object 규칙 검증.

### 7.2 Repository 단위 테스트 (Service 를 mockito 로 mock)

위치: `test/data/repositories/...`.

| 메서드 | 시나리오 | 검증 |
|---|---|---|
| `BabyRepository.getMyBabies` | 정상 | Service `Result.ok(List<BabyListItem>)` → Repository `Result.ok` passthrough |
| 〃 | 빈 리스트 | `Result.ok([])` 그대로 |
| 〃 | 에러 | `Result.error` passthrough |
| `BabyRepository.getBaby` | 정상 | Service `getBaby(babyId)` 호출, `Result.ok(Baby)` passthrough |
| 〃 | 미존재 | Service `Result.error(notFound)` → Repository 동일 passthrough |
| 〃 | 에러 | passthrough |
| `RecordRepository.getRecords` | 첫 페이지 (cursor null) | Service 호출 인자 cursor=null, limit 전달 |
| 〃 | 다음 페이지 | cursor 그대로 전달, 결과의 nextCursor 가 Page 에 반영 |
| 〃 | 빈 페이지 | items 비고 hasMore=false 그대로 |
| 〃 | 에러 | passthrough |
| `RecordRepository.getRecentFeedings` | 정상 | Service `getRecentRecords(types={breast,formula,pumping,babyFood}, orderColumn=feedingEffectiveAt, limit=2)` 호출 |
| 〃 | 1개만 | 길이 1 그대로 |
| 〃 | 빈 결과 | `Result.ok([])` |
| `RecordRepository.getRecentDiapers` | 정상 | `getRecentRecords(types={diaper}, orderColumn=occurredAt, limit=2)` |
| `RecordRepository.getRecentWakes`   | 정상 | `getRecentRecords(types={sleep}, orderColumn=endedAt, limit=2)` |
| `RecordRepository.createRecord` | 정상 | Service `createRecord(babyId, type=detail.type, detailJson=detail.toJson(), occurredAt, endedAt)` 호출. ViewModel 은 userId 를 전달하지 않음 |
| 〃 | 에러 | passthrough |
| `RecordRepository.deleteRecord` | 정상 | Service 호출 후 `Result.ok(null)` |
| 〃 | 에러 | passthrough |

### 7.3 Service 테스트

- Service 는 Supabase SDK 의존성이 있어 단위 테스트가 어렵다. **본 PR 에서는 Service 단위 테스트를 강제하지 않는다**.
- 단, **매핑 함수 (`_mapBabyListItem`, `_mapBaby`, `_mapRecord`)** 는 순수 함수이므로 별도 헬퍼로 노출 가능하면 단위 테스트 추가 권장:
  - `_mapBabyListItem`: id / name 보존.
  - `_mapBaby`: birthDate / dueDate null / non-null 케이스, gender 매핑.
  - `_mapRecord` round-trip: 각 RecordType 에 대해 row → CareRecord → row 의 핵심 필드 보존.

### 7.4 AppState 테스트

- `SharedPreferences.setMockInitialValues({})` 활용한 in-memory 동작 검증.

| 시나리오 | 검증 |
|---|---|
| 초기 상태 | `selectedBabyId == null` |
| `selectBaby('a')` 호출 | `selectedBabyId == 'a'`, listener notified |
| 재호출 `selectBaby('b')` | `selectedBabyId == 'b'`, listener notified |
| `clearSelectedBaby()` | `selectedBabyId == null`, listener notified |

---

## 8. DI 등록 (`lib/core/config/dependencies.dart`)

추가 항목:

```dart
// 앱 부트스트랩 시점에 await 로 SharedPreferences 인스턴스를 받아 buildDependencies 에 주입.
// main.dart 에서:
//   final prefs = await SharedPreferences.getInstance();
//   runApp(MultiProvider(providers: buildDependencies(prefs: prefs), ...));

Provider<SharedPreferences>(create: (_) => prefs),
ChangeNotifierProvider<AppState>(
  create: (context) => AppState(context.read<SharedPreferences>()),
),

Provider<BabyService>(
  create: (context) => SupabaseBabyService(client: context.read<SupabaseClient>()),
),
Provider<BabyRepository>(
  create: (context) => BabyRepositoryImpl(context.read<BabyService>()),
),

Provider<RecordService>(
  create: (context) => SupabaseRecordService(client: context.read<SupabaseClient>()),
),
Provider<RecordRepository>(
  create: (context) => RecordRepositoryImpl(context.read<RecordService>()),
),
```

`SharedPreferences` 를 동기 주입할 수 있도록 `main.dart` 의 부트스트랩에서 await 후 전달한다.

---

## 9. 파일 추가 / 수정 예상 목록

**신규 도메인 모델**
- `lib/domain/models/baby/baby_list_item.dart` (id, name)
- `lib/domain/models/baby/baby.dart` (id, name, birthDate, dueDate, gender)
- `lib/domain/models/care_record/care_record.dart`
- `lib/domain/models/care_record/record_detail_data.dart` (sealed + 변종 6종)
- `lib/domain/models/common/page.dart` (`Page<T>`, `RecordsCursor`)
- `lib/constants/enum/record_type.dart`

**신규 Repository / Service**
- `lib/data/repositories/baby_repository/baby_repository.dart`
- `lib/data/repositories/baby_repository/baby_repository_impl.dart`
- `lib/data/services/baby_service/baby_service.dart`
- `lib/data/services/baby_service/supabase_baby_service.dart`
- `lib/data/repositories/record_repository/record_repository.dart`
- `lib/data/repositories/record_repository/record_repository_impl.dart`
- `lib/data/services/record_service/record_service.dart`
- `lib/data/services/record_service/supabase_record_service.dart`

**신규 앱 상태**
- `lib/common/app_state/app_state.dart`

**수정**
- `lib/core/config/dependencies.dart` — SharedPreferences / AppState / Baby* / Record* 등록
- `lib/main.dart` — `SharedPreferences.getInstance()` await 후 DI 주입

**테스트**
- `test/domain/models/care_record/record_detail_data_test.dart` (변종별 round-trip)
- `test/data/repositories/baby_repository/baby_repository_impl_test.dart`
- `test/data/repositories/record_repository/record_repository_impl_test.dart`
- `test/common/app_state/app_state_test.dart`

**`pubspec.yaml`**
- `shared_preferences` 추가
