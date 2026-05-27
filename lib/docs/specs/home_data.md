# 📋 Home Screen — Data Layer

본 문서는 **Part 1. 스펙** 과 **Part 2. 구현 방법** 으로 나뉜다.

- **Part 1** 은 "무엇이 필요한가 / 어떤 계약을 지켜야 하는가" — 기술 선택과 무관하다.
- **Part 2** 는 "어떻게 만들 것인가" — 본 프로젝트가 선택한 기술 스택에 맞춘 구현 메모.

Part 1 의 어떤 요구사항도 Part 2 의 특정 라이브러리 / 컬럼명 / 쿼리에 의존하지 않는다. 백엔드나 로컬 저장소를 바꾸더라도 Part 1 은 그대로 유지될 수 있다.

---

# Part 1. 스펙

## 1. 스코프

- **이 PR 범위**:
    - 홈 화면이 필요로 하는 **Data Layer** (Repository / Service / Model)
    - **선택된 아기 ID** 의 저장 / 노출을 담당하는 **앱 상태 클래스** (`AppState`)
- **이 PR 범위 아님**:
    - `HomeViewModel`, 홈 화면 위젯 등 Presentation Layer
    - 본 spec 의 §7 "호출자 동작 시퀀스" 는 호출자 (= ViewModel) 관점 참고용

---

## 2. 레이어 구조

```
┌──────────────────────────────┐
│  HomeViewModel  (별도 PR)    │
└──────────────┬───────────────┘
               │ depends on
       ┌───────┼───────────────┐
       ▼       ▼               ▼
   ┌────────┐ ┌────────────┐ ┌──────────┐
   │ Baby   │ │ Record     │ │ AppState │
   │ Repo   │ │ Repo       │ │          │
   └───┬────┘ └────┬───────┘ └────┬─────┘
       ▼           ▼              ▼
   ┌────────┐ ┌────────────┐ ┌──────────────┐
   │ Baby   │ │ Record     │ │ 로컬 영구    │
   │ Service│ │ Service    │ │ 저장소        │
   └───┬────┘ └────┬───────┘ └──────────────┘
       └─────┬─────┘
             ▼
       ┌────────────┐
       │ 원격 백엔드 │
       └────────────┘
```

- ViewModel 은 **Repository** 와 **AppState** 만 의존한다. Service / 백엔드 클라이언트 / 로컬 저장소는 ViewModel 에 노출되지 않는다.
- Repository 는 입력으로 `babyId` 를 받는다. "현재 선택된 아기" 의 판정은 `AppState` 의 책임이며, ViewModel 이 `AppState.selectedBabyId` 를 읽어 Repository 에 전달한다.
- Repository 는 도메인 모델 + `Result<T>` 만 노출한다. raw row / `Map<String, dynamic>` / DTO 가 Repository 경계 밖으로 새 나가서는 안 된다.

---

## 3. 도메인 모델 요구사항

### 3.1 아기 모델 — 두 가지 형태

각 쿼리가 필요로 하는 데이터의 폭이 다르므로 도메인 모델을 분리한다.

| 모델 | 필드 | 용도 |
|---|---|---|
| `BabyListItem` | `id`, `name` | "선택 후보 목록" 표시 — 사용자가 어떤 아기로 전환할지 고르는 화면. |
| `Baby` | `id`, `name`, `birthDate` (nullable), `dueDate` (nullable), `gender` | "현재 선택된 아기의 기본 정보" — 홈 상단의 이름 / D-day / D+N 계산의 원본. |

- `BabyListItem` 은 list view 용 가벼운 모델이다. 사용자가 한 명을 선택하면, 그 아기에 대해서는 별도로 `Baby` 를 조회한다.
- `birthDate` 와 `dueDate` 는 둘 다 null 일 수 있다 (출생 전 / 입양 등).
- D+N / D-day 같은 사용자에게 보여줄 문자열은 **ViewModel 이상에서 계산**한다. Data Layer 는 원본만 노출한다.

### 3.2 기록 모델

#### `CareRecord` (aggregate)

기록의 공통 헤더 + 세부 데이터.

| 필드 | 타입 | 비고 |
|---|---|---|
| `id` | String | DB 가 부여 |
| `babyId` | String | |
| `type` | `RecordType` | `detail.type` 과 일치해야 한다 |
| `occurredAt` | DateTime | 기록 시작 시각. non-null |
| `endedAt` | DateTime? | breast / sleep 만 사용. 그 외 null |
| `createdBy` | String | 생성한 사용자 ID |
| `createdAt` | DateTime | DB 가 부여 |
| `detail` | `RecordDetailData` | sealed |

#### `RecordType`

`breast`, `formula`, `pumping`, `babyFood`, `diaper`, `sleep` — 6종.

#### `RecordDetailData` (sealed, leaf)

타입별 세부 데이터. 각 sealed 변종이 자신의 직렬화를 직접 보유한다 (leaf value object 규칙).

| 변종 | 핵심 필드 |
|---|---|
| `BreastDetail` | `occurredAt`, `endedAt`, 좌/우 수유 시간 |
| `FormulaDetail` | `occurredAt`, 분유 양 |
| `PumpingDetail` | `occurredAt`, 유축량, 좌/우 |
| `BabyFoodDetail` | `occurredAt`, 메뉴 |
| `DiaperDetail` | `occurredAt`, 종류 (소변/대변/혼합) |
| `SleepDetail` | `occurredAt`, `endedAt` |

세부 필드는 Presentation PR 에서 확장될 수 있다. 본 spec 은 각 변종이 자기 직렬화를 직접 보유한다는 **규칙** 을 정의한다.

### 3.3 페이지네이션 모델

기록 리스트 조회의 응답은 다음 정보를 포함하는 **페이지** 형태여야 한다.

| 필드 | 용도 |
|---|---|
| `items` | 페이지에 포함된 기록 리스트 |
| `nextCursor` | 다음 페이지를 요청할 때 사용. nullable (다음 페이지 없으면 null) |
| `hasMore` | 다음 페이지 존재 여부 |

cursor 는 `(occurredAt, id)` 두 값으로 구성된다. 동일 `occurredAt` 을 가진 행이 여러 개 있어도 페이지 경계에서 누락되지 않도록 하기 위함이다.

---

## 4. AppState 요구사항

### 4.1 책임

- 사용자가 마지막으로 보던 아기 ID (`selectedBabyId`) 를 **로컬에 저장** 하고 앱 전체에 노출한다.
- ViewModel 은 `selectedBabyId` 를 읽어 Repository 호출 시 `babyId` 로 사용한다.
- 아기 전환 시 새 ID 로 갱신되고 저장된다.
- 로그아웃 시 비워진다.
- 값이 바뀌면 구독자 (= ViewModel) 에게 변경을 알린다.

### 4.2 노출 인터페이스

| 멤버 | 동작 |
|---|---|
| `selectedBabyId` (read) | 현재 선택된 아기 ID. 저장된 값이 없으면 null. |
| `selectBaby(babyId)` | 선택된 아기를 바꾸고 로컬에 저장한다. 구독자에게 변경을 알린다. |
| `clearSelectedBaby()` | 선택된 아기를 비우고 저장소에서도 지운다. 구독자에게 변경을 알린다. |

### 4.3 책임의 경계 — AppState 가 하지 않는 일

- **저장된 ID 가 현재 사용자의 접근 가능한 아기 목록에 들어 있는지 검증하지 않는다.** 그 판단에는 Data Layer 호출 결과가 필요하므로 ViewModel 의 책임이다.
- "저장된 ID 가 stale 이면 첫 번째 아기를 기본 선택" 같은 fallback 로직도 ViewModel 의 책임이다.

### 4.4 빈 / 실패 케이스

- 저장된 값이 없는 상태는 **에러가 아니다** — `selectedBabyId` 는 단순히 null.
- 로컬 저장소 자체의 read/write 실패는 본 PR 범위에서는 별도로 처리하지 않는다.

---

## 5. BabyRepository 요구사항

### 5.1 목적

홈 화면이 "어떤 아기를 보여줄 것인가" 를 결정하기 위한 **선택 후보 목록** 과, "현재 선택된 아기" 의 **기본 정보** 를 제공한다.

### 5.2 책임

- 현재 로그인 사용자가 멤버로 등록된 아기들의 **목록** 을 제공한다.
- 특정 아기 ID 에 대해 화면 표시에 필요한 **기본 정보** 를 제공한다.
- 결과를 도메인 모델 + `Result<T>` 형태로 ViewModel 에 제공한다.
- 화면 표시용 가공 (라벨, 마스킹, D-day, D+N 등) 은 수행하지 않는다.

### 5.3 호출자

- `HomeViewModel` — 홈 진입 시 목록 + 기본 정보 조회. 멤버십 변경 후 목록 재조회. 아기 전환 시 새 선택된 아기의 기본 정보 재조회.

### 5.4 주요 결정

- `userId` 를 인자로 받지 않는다. "현재 사용자" 는 인증 컨텍스트에서 자동 판단한다. 호출자가 잘못된 userId 를 주입할 가능성을 차단한다.
- **목록과 기본 정보 조회를 분리** 한다. 필요한 데이터의 폭이 다르고 (목록: 2필드, 기본 정보: 5필드), 무효화 시점도 다르다 (목록: 멤버십 변경, 기본 정보: 아기 전환 / 프로필 수정).

### 5.5 메서드 요구사항: 접근 가능한 아기 목록 조회

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈에서 "어떤 아기를 볼 것인가" 를 선택할 후보 목록을 제공한다. |
| 입력 | 없음. |
| 호출 시점 | 홈 진입 시 1회. 멤버십 변경 (아기 추가 / 탈퇴 / 초대 수락) 후 재조회. |
| 결과 데이터 | `List<BabyListItem>` — 각 항목은 `id`, `name` 만 포함한다. |
| 결과 정렬 | 생성일 내림차순 — "내가 가장 최근에 추가한 아기를 가장 위로" UX 요구. |
| 성공 조건 | 사용자가 인증되어 있고, 그 사용자가 멤버인 모든 아기를 조회 / 매핑할 수 있어야 한다. |
| 빈 데이터 | **빈 리스트는 에러로 표현한다 (`AppException(notFound)`).** 홈에 진입하려면 본인이 등록했거나 초대받은 아기가 최소 1명 있어야 하므로, 빈 리스트는 호출자가 다른 동작 (등록 화면으로 이동 등) 을 취해야 하는 신호다. |
| 실패 케이스 | 네트워크 / 호출 실패, 인증 만료 / 미로그인, 응답 파싱 실패 모두 `Result.error(AppException)`. |
| null 처리 | 결과 리스트, 각 항목의 두 필드 모두 non-null. |

### 5.6 메서드 요구사항: 단일 아기의 기본 정보 조회

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 상단에 표시할 아기 이름 / D+N / D-day 등의 계산 원본을 제공한다. |
| 입력 | `babyId` (필수). 호출자가 `AppState.selectedBabyId` 로부터 가져온 값을 그대로 전달한다. |
| 호출 시점 | 홈 진입 시 (선택된 아기 결정 직후). 아기 전환 시. 본인이 아기 프로필을 수정한 직후. |
| 결과 데이터 | `Baby` — `id`, `name`, `birthDate` (nullable), `dueDate` (nullable), `gender` 5개 필드. |
| 성공 조건 | 사용자가 인증되어 있고, 해당 `babyId` 에 멤버로 접근 가능하며, 행이 존재해야 한다. |
| 빈 데이터 / 미존재 | 행이 없거나 권한이 없으면 `Result.error(AppException(notFound))`. "현재 선택된 아기" 의 정보 조회는 단일 대상에 대한 명확한 요청이며, 행 없음은 호출자가 후속 동작 (목록 재조회 + 다른 아기 선택) 을 취해야 하는 신호다. |
| 실패 케이스 | `notFound`, `unauthorized`, `networkError`, `parseFailed`. 모두 `Result.error(AppException)`. |
| null 처리 | `birthDate` / `dueDate` 는 각각 독립적으로 null 가능. 둘 다 null 인 경우도 정상. |

---

## 6. RecordRepository 요구사항

### 6.1 목적

현재 선택된 아기에 대해 홈 화면이 보여줘야 하는 **모든 기록 데이터** 를 제공하고, 사용자의 기록 생성 / 삭제 의도를 영속화한다.

### 6.2 책임

- 기록 리스트 조회 — 홈 메인 영역의 무한 스크롤을 지원하는 페이지 단위 조회.
- 카테고리별 최근 요약 — 수유 / 기저귀 / 기상 카테고리에 대해 최근 2건을 제공.
- 기록 생성 — `RecordDetailData` 로 표현 가능한 모든 타입의 기록을 영속화하고 도메인 모델로 반환.
- 기록 삭제 — 기록 ID 로 식별되는 기록을 영구 삭제.
- 결과를 도메인 모델 + `Result<T>` 형태로 ViewModel 에 제공.

### 6.3 호출자

- `HomeViewModel`.

### 6.4 주요 결정

- 모든 메서드는 `babyId` 를 인자로 받는다. "현재 선택된 아기" 의 판정은 호출자 (AppState / ViewModel) 의 책임.
- 기록 생성 시 호출자는 `userId` 를 전달하지 않는다. `createdBy` 는 인증 컨텍스트에서 자동 채워진다.
- 정렬 기준은 카테고리에 따라 달라질 수 있다 (수유: `breast` 만 종료 시각 기준, 기상: 종료 시각 기준). 이 차이는 Repository 가 노출하는 **계약** 이며, 호출자는 정렬 규칙을 알 필요 없이 결과 순서를 신뢰할 수 있어야 한다.
- 본 PR 에서는 기록을 캐싱하지 않는다. 생성 / 삭제 후 ViewModel 이 in-memory 리스트를 직접 정합화한다.

### 6.5 메서드 요구사항: 기록 리스트 조회 (페이지 단위)

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈의 무한 스크롤 기록 리스트를 페이지 단위로 제공. |
| 입력 | `babyId` (필수), `cursor` (없으면 첫 페이지), `limit` (기본 20). |
| 호출 시점 | 첫 페이지 — 홈 진입 시 / 아기 전환 시 / 기록 생성·삭제 후 리스트 동기화. 다음 페이지 — 스크롤이 하단에 도달했을 때. |
| 결과 데이터 | 페이지 — `items: List<CareRecord>`, `nextCursor`, `hasMore`. `CareRecord` 의 모든 필드 (§3.2) 가 채워진다. 부분 모델은 사용하지 않는다. |
| 결과 정렬 | `occurredAt` 내림차순. 동일 시각이면 `id` 내림차순으로 tie-break. |
| 페이지네이션 보장 | 다음 페이지 존재 여부와 다음 cursor 가 결과에 포함되어야 한다. 같은 `occurredAt` 다중 행이 페이지 경계에서 누락되지 않아야 한다. |
| 페이지 크기 | 기본 20. 호출자가 override 가능. |
| 빈 데이터 | 기록이 없으면 빈 페이지 (items 비고, hasMore=false, nextCursor=null) 를 성공으로 반환. 에러 아님. |
| 실패 케이스 | 네트워크 / 인증 / 권한 오류 → `Result.error(AppException)`. 호출자는 같은 cursor 로 재시도할 수 있어야 한다. |

### 6.6 메서드 요구사항: 최근 수유 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 요약 영역의 "마지막으로 N시간 전에 먹였어요" 및 직전 수유와의 간격 계산. |
| 포함 타입 | 수유 4종 — `breast`, `formula`, `pumping`, `babyFood`. |
| 입력 | `babyId`, `limit` (기본 2). |
| 호출 시점 | 홈 진입 시. 수유 기록 생성/삭제 후 재조회. |
| 결과 데이터 | `List<CareRecord>` (최대 `limit` 개). 각 항목은 §3.2 의 모든 필드 채워서 반환. |
| 기준 시각 정의 | "마지막으로 N시간 전에 먹였니" 의 자연스러운 해석은 *수유가 끝난 뒤* 의 경과 시간. 따라서: `breast` → `endedAt`, 나머지 3종 → `occurredAt` 을 기준 시각으로 사용. |
| 결과 정렬 | 위 기준 시각의 내림차순. 동일 시각이면 `id` 내림차순. |
| 제외 조건 | `breast` 이면서 `endedAt` 이 null (= 수유 진행 중) 인 행은 본 PR 에서 제외. "진행 중 수유" UX 는 후속 PR. |
| 빈 데이터 | 빈 리스트. 1건만 있으면 1건만. |
| 실패 케이스 | `Result.error(AppException)`. |

### 6.7 메서드 요구사항: 최근 기저귀 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 요약 영역의 "마지막으로 N시간 전에 기저귀 갈았어요". |
| 포함 타입 | `diaper`. |
| 입력 | `babyId`, `limit` (기본 2). |
| 호출 시점 | 홈 진입 시. 기저귀 기록 생성/삭제 후 재조회. |
| 결과 데이터 | `List<CareRecord>` (최대 `limit` 개). 모든 항목 `type == diaper`, `endedAt` 은 항상 null. |
| 결과 정렬 | `occurredAt` 내림차순. 동일 시각이면 `id` 내림차순. |
| 빈 데이터 | 빈 리스트. 1건만 있으면 1건만. |
| 실패 케이스 | `Result.error(AppException)`. |

### 6.8 메서드 요구사항: 최근 기상 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 요약 영역의 "마지막으로 N시간 전에 일어났어요". "기상" 은 수면 기록의 종료 시점으로 정의. |
| 포함 타입 | `sleep`. |
| 입력 | `babyId`, `limit` (기본 2). |
| 호출 시점 | 홈 진입 시. 수면 기록 생성/삭제/종료 직후 재조회. |
| 결과 데이터 | `List<CareRecord>` (최대 `limit` 개). 모든 항목 `type == sleep`, **`endedAt` 은 항상 non-null** (= 이미 종료된 수면만 반환). |
| 기준 시각 | 수면 기록의 `endedAt` (= 기상 시각). |
| 결과 정렬 | `endedAt` 내림차순. 동일 시각이면 `id` 내림차순. |
| 제외 조건 | `endedAt` 이 null 인 수면 (= 진행 중) 은 조회 대상에서 제외. 본 메서드는 "기상 시점" 을 다루기 때문. |
| 빈 데이터 | 종료된 수면이 없으면 빈 리스트. 1건만 있으면 1건만. |
| 실패 케이스 | `Result.error(AppException)`. |

### 6.9 메서드 요구사항: 기록 생성

| 항목 | 요구사항 |
|---|---|
| 목적 | 사용자의 새 기록 (수유 / 기저귀 / 수면) 을 영속화하고, 반영 결과를 즉시 도메인 모델로 반환. |
| 입력 | `babyId`, `detail` (`RecordDetailData`). |
| 호출 시점 | 사용자가 기록 작성 UI 에서 저장을 확정할 때. |
| 메타데이터 결정 | `type`, `occurredAt`, `endedAt` 은 호출자가 별도로 전달하지 않는다. 모두 `detail` 안에 내재되어 있다 — `detail` 객체 하나가 source of truth. |
| `createdBy` 결정 | 호출자가 전달하지 않는다. Service 가 인증 컨텍스트의 현재 사용자로 자동 채운다. |
| 성공 조건 | 영속화 성공 후, 반영된 행을 다시 `CareRecord` 도메인 모델로 매핑할 수 있어야 한다. |
| 결과 데이터 | `Result.ok(CareRecord)` — 단일 `CareRecord`. 영속화 시 채워진 `id`, `createdAt`, (sleep/breast 면) `endedAt` 까지 포함한 모든 필드. ViewModel 은 이 모델을 그대로 리스트 맨 앞에 append 할 수 있어야 한다. |
| 실패 케이스 | 미로그인/만료 → `unauthorized`. 권한 거부 (해당 아기의 멤버 아님) → `unauthorized`. 네트워크 실패 → `networkError`. 응답 파싱 실패 → `parseFailed`. 모두 `Result.error(AppException)`. |

### 6.10 메서드 요구사항: 기록 삭제

| 항목 | 요구사항 |
|---|---|
| 목적 | `recordId` 로 식별되는 기록을 영구 삭제. |
| 입력 | `recordId`. |
| 호출 시점 | 사용자가 기록 항목 삭제를 확정할 때. |
| 권한 | Repository 는 사전 검사하지 않는다. 권한 판정은 백엔드의 보안 정책에 위임한다. |
| 결과 데이터 | `Result.ok(null)`. 반환 페이로드 없음. 호출자가 삭제된 항목의 정보가 필요하면 자신이 들고 있는 in-memory 모델을 사용. |
| 실패 케이스 | 권한 거부 / 네트워크 / 존재하지 않는 ID / 기타 모두 `Result.error(AppException)`. 실패 유형은 `AppException.code` 로 구분. |

---

## 7. Service Layer 요구사항

### 7.1 책임

- Repository 의 **하부 협력자**. 원격 백엔드 호출, raw 응답을 도메인 모델로 매핑, 인증 컨텍스트 주입 같은 외부 시스템 연동 책임.
- Repository 만이 Service 에 의존한다. ViewModel 은 Service 의 존재를 알지 못한다.
- 메서드는 `Result<T>` 를 반환한다. throw 하지 않으며, 모든 외부 실패는 `AppException` 으로 변환된다.
- 매핑 결과는 항상 도메인 모델이다. raw row / `Map<String, dynamic>` / DTO 는 Service 경계 밖으로 나가지 않는다.

### 7.2 BabyService 의 메서드 — 책임

| 메서드 | 책임 |
|---|---|
| 아기 목록 조회 | 현재 인증 사용자가 멤버인 아기들을 `BabyListItem` (id, name) 목록으로 반환. 생성일 내림차순 보장. |
| 단일 아기 정보 조회 | 주어진 `babyId` 의 기본 정보를 `Baby` (id, name, birthDate, dueDate, gender) 로 반환. 행이 없거나 권한이 없으면 `notFound` 로 변환. |

### 7.3 RecordService 의 메서드 — 책임

| 메서드 | 책임 |
|---|---|
| 페이지 단위 기록 조회 | `(occurredAt, id)` cursor 기반으로 페이지를 조회. 다음 페이지 존재 여부와 다음 cursor 를 결과에 포함. |
| 카테고리별 최근 N건 조회 | 호출자가 지정한 타입 집합과 기준 시각 (occurredAt / endedAt / 수유용 합성 키 중 하나) 으로 정렬해 최대 N건을 반환. 기준 시각이 없는 행은 제외. |
| 기록 생성 | 호출자가 전달한 메타데이터에 더해 `createdBy` 를 인증 컨텍스트의 현재 사용자로 자동 채운 뒤 영속화. 결과 행을 다시 `CareRecord` 로 매핑해 반환. |
| 기록 삭제 | `recordId` 로 삭제 요청. 권한 판정은 백엔드에 위임. |

### 7.4 매핑 책임의 위치

- **Leaf value object (`RecordDetailData` 변종)** 의 `toJson` / `fromJson` 은 도메인 모델이 직접 보유한다. 데이터 소스에 의존하지 않는 자명한 직렬화이기 때문.
- **Aggregate (`CareRecord`)** 의 매핑은 Data Layer (Service 내부) 가 담당한다. 향후 cross-table 필드가 추가될 가능성이 있어 데이터 소스에 의존하기 때문.
- **`BabyListItem` / `Baby`** 매핑도 Service 내부에서 담당한다.
- 매핑 실패는 Service 안에서 catch 하여 `AppException(parseFailed)` 로 변환한다.

---

## 8. 호출자 동작 시퀀스 (참고용)

### 8.1 진입 — 홈 화면 초기 로드

```
1. babies      = babyRepository.getMyBabies()                  // Result<List<BabyListItem>>
2. savedId     = appState.selectedBabyId                       // String? (sync)
3. currentBabyId :=
     if savedId != null && babies.any(b => b.id == savedId) then savedId
     else if babies.isNotEmpty                              then babies.first.id
     else                                                        null
   (savedId 가 stale 이면 appState.selectBaby(currentBabyId) 로 정합화)
4. currentBabyId 가 null 이면 "아기 없음" 상태로 종료
5. 병렬:
   a. babyRepository.getBaby(currentBabyId)                    // 기본 정보
   b. recordRepository.getRecords(currentBabyId, cursor: null, limit: 20)
   c. recordRepository.getRecentFeedings(currentBabyId)
   d. recordRepository.getRecentDiapers(currentBabyId)
   e. recordRepository.getRecentWakes(currentBabyId)
6. 결과 합성 후 화면 렌더
```

### 8.2 아기 전환

```
1. UI 가 chevron → BottomSheet 로 babies 목록 (BabyListItem) 표시
2. 사용자가 다른 baby 선택 → appState.selectBaby(newId)
3. ViewModel 이 AppState 변경을 감지 → §8.1 의 step 5 부터 재실행
```

### 8.3 기록 생성 / 삭제 / infinite scroll

- **생성**: `createRecord(babyId, detail)` → 성공 시 ViewModel 이 리스트 맨 앞 append + 해당 카테고리의 `getRecent*` 재호출.
- **삭제**: `deleteRecord(id)` → 성공 시 리스트에서 제거 + 삭제된 기록이 해당 카테고리의 최근 2개 중 하나였다면 `getRecent*` 재호출.
- **infinite scroll**: 하단 도달 → `getRecords(babyId, cursor: page.nextCursor)` → append. `hasMore == false` 이후는 호출하지 않는다.

---

# Part 2. 구현 방법

본 프로젝트가 선택한 기술 스택에 맞춘 구현 메모. Part 1 의 요구사항을 깨지 않는 범위에서 자유롭게 바뀔 수 있다.

## 9. 기술 스택 선택

| 영역 | 선택 | 이유 / 비고 |
|---|---|---|
| 원격 백엔드 | **Supabase** (Auth + PostgREST + RLS) | 프로젝트 전반의 기존 선택. 인증 / DB / 권한이 통합되어 있다. |
| 로컬 저장소 | **`shared_preferences`** 패키지 | 단일 key-value 만 필요 (`selectedBabyId`). 추가 의존성 최소화. |
| 상태 관리 / DI | **`provider`** + `ChangeNotifier` | 프로젝트 전반의 기존 선택. AppState 는 `ChangeNotifier` 로 변경 알림. |
| 비동기 결과 표현 | 프로젝트 내부 `Result<T>` (sealed `Ok` / `Error`) | 기존 패턴 재사용. throw 대신 명시적 분기. |
| 테스트 mock | **`mockito`** | 프로젝트 전반의 기존 선택. Service 를 mock 해 Repository 단위 테스트. |

---

## 10. AppState 구현

### 10.1 상세 동작

- `ChangeNotifier` 를 extend 한다. 위젯은 `context.watch<AppState>()` 등 Provider 의 도구로 구독한다.
- `selectedBabyId` getter 는 동기. `SharedPreferences.getString` 이 동기 API 이기 때문.
- `selectBaby` / `clearSelectedBaby` 는 `SharedPreferences.setString` / `remove` 후 `notifyListeners()`.
- key: `'selected_baby_id'`.

### 10.2 부트스트랩

- `main.dart` 에서 `SharedPreferences.getInstance()` 를 await 한 결과를 DI 컨테이너에 주입.
- AppState 는 생성자에서 `SharedPreferences` 를 주입받는다. `init()` 같은 별도 부트스트랩 메서드는 두지 않는다.

### 10.3 실패 처리

- 본 PR 에서는 `SharedPreferences` 의 read/write 실패를 별도로 catch 하지 않는다. 플랫폼 의존 영역이며 실제로는 거의 실패하지 않는다.

---

## 11. Service 구현 (Supabase)

### 11.1 BabyService

| 메서드 | Supabase 동작 |
|---|---|
| 아기 목록 조회 | `babies` 에서 `id`, `name` 컬럼만 select, `created_at desc` 정렬. RLS 가 멤버십을 강제하므로 별도 user 필터 없음. |
| 단일 아기 정보 조회 | `babies` 에서 5컬럼 (`id`, `name`, `birth_date`, `due_date`, `gender`) 을 `eq('id', babyId).maybeSingle()` 로 조회. null 이면 `notFound` 로 변환. |

### 11.2 RecordService

| 메서드 | Supabase 동작 |
|---|---|
| 페이지 조회 | `care_records` 를 `eq('baby_id', babyId)` + (cursor 있으면) `(occurred_at, id) < cursor` 조건 + `order('occurred_at' desc).order('id' desc).limit(limit + 1)`. `limit + 1` 트릭으로 `hasMore` 판정. |
| 최근 N건 조회 | `eq('baby_id', babyId).inFilter('type', types).not(orderColumn, 'is', null).order(orderColumn desc).order('id' desc).limit(limit)`. `orderColumn IS NOT NULL` 조건이 곧 "진행 중 breast/sleep 자동 제외" 효과를 낸다. |
| 생성 | `_client.auth.currentUser?.id` 로 `createdBy` 결정 (null 이면 `unauthorized`). `baby_id`, `type`, `occurred_at`, `ended_at`, `detail` (jsonb), `created_by` insert. `ended_at` 컬럼은 generated 이지만 명시적으로 채워도 충돌 없음. 결과 행을 `_mapRecord` 로 다시 매핑. |
| 삭제 | `_client.from('care_records').delete().eq('id', recordId)`. RLS 가 권한 판정. |

### 11.3 cursor 직렬화

`(occurredAt, id)` cursor 는 Supabase 쿼리 식 `(occurred_at, id) < (cursor.occurredAt, cursor.id)` 로 구현한다. Supabase Dart SDK 에서 복합 비교는 `.or(...)` 로 다음과 같이 풀어 쓴다:

```
occurred_at.lt.<iso>,and(occurred_at.eq.<iso>,id.lt.<id>)
```

### 11.4 DB 약속 (마이그레이션 PR 의 책임)

본 PR 의 코드가 정상 동작하려면 다음 DB 변경이 선행되어야 한다 (별도 마이그레이션 PR).

| 변경 | 용도 |
|---|---|
| `care_records.ended_at` generated column — `detail->>'ended_at'` 으로부터 파생 | 수면/breast 정렬과 partial 인덱스 활용. |
| `care_records.feeding_effective_at` generated column — `breast → ended_at`, `formula/pumping/baby_food → occurred_at`, 그 외 null | 수유 4종을 단일 정렬 키로 처리. |
| `(baby_id, occurred_at desc, id desc)` 인덱스 | 페이지 단위 리스트 조회 최적화. |
| 위 두 generated column 에 대한 `(baby_id, col desc, id desc) where col is not null` partial 인덱스 | 최근 N건 조회 최적화. |
| `babies.created_at` 존재 | 목록 정렬 기준. |

---

## 12. 매핑 함수

Service 내부의 순수 함수로 구현한다.

| 함수 | 동작 |
|---|---|
| `_mapBabyListItem(row) → BabyListItem` | `id`, `name`. |
| `_mapBaby(row) → Baby` | `id`, `name`, `birth_date` (parse), `due_date` (parse), `gender` (enum). `created_at` 은 도메인 모델에 없으므로 매핑하지 않음. |
| `_mapRecord(row) → CareRecord` | `id`, `baby_id`, `type` (enum), `occurred_at` (parse), `ended_at` (parse, nullable), `created_by`, `created_at` (parse), `detail` (jsonb → `RecordDetailData.fromJson(type, json)` sealed dispatch). |

파싱 실패 / enum lookup 실패는 catch 하여 `AppException(parseFailed)` 로 변환.

---

## 13. DI 등록

`lib/core/config/dependencies.dart` 에 추가:

```dart
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

`SharedPreferences` 인스턴스를 동기 주입할 수 있도록 `main.dart` 의 부트스트랩에서 await 후 전달한다.

---

## 14. 테스트 방식

### 14.1 도메인 단위 테스트

- `RecordDetailData` 변종별 `toJson` / `fromJson` round-trip. leaf value object 규칙 검증.
- `Baby` 의 D-day / D+N 같은 계산 로직은 본 PR 의 도메인에 두지 않으므로 (Presentation 책임) 단위 테스트 대상 아님.

### 14.2 Repository 단위 테스트 — Service 를 mockito 로 mock

| 메서드 | 시나리오 | 검증 |
|---|---|---|
| `BabyRepository.getMyBabies` | 정상 | Service `Result.ok(List<BabyListItem>)` passthrough |
| 〃 | 빈 리스트 → 에러 변환 | Service `Result.ok([])` → Repository `Result.error(notFound)` |
| 〃 | 에러 | passthrough |
| `BabyRepository.getBaby` | 정상 | Service 결과 passthrough |
| 〃 | 미존재 | Service `Result.error(notFound)` passthrough |
| `RecordRepository.getRecords` | 첫 페이지 | cursor=null, limit 전달 |
| 〃 | 다음 페이지 | cursor 전달, nextCursor 가 결과에 반영 |
| 〃 | 빈 페이지 | items=[], hasMore=false passthrough |
| `RecordRepository.getRecentFeedings` | 정상 | Service 가 `{breast, formula, pumping, babyFood}` + 수유 합성 키로 호출됨 |
| 〃 | 1건만 | 길이 1 그대로 |
| 〃 | 빈 결과 | `Result.ok([])` |
| `RecordRepository.getRecentDiapers` | 정상 | `{diaper}` + `occurredAt` |
| `RecordRepository.getRecentWakes` | 정상 | `{sleep}` + `endedAt` |
| `RecordRepository.createRecord` | 정상 | Service 가 `babyId, type=detail.type, detailJson=detail.toJson(), occurredAt, endedAt` 으로 호출됨. userId 는 호출자가 전달하지 않음 |
| 〃 | 에러 | passthrough |
| `RecordRepository.deleteRecord` | 정상 | Service 호출 후 `Result.ok(null)` |
| 〃 | 에러 | passthrough |

### 14.3 Service 테스트

Supabase SDK 의존성으로 Service 단위 테스트는 본 PR 에서 강제하지 않는다. 단, 매핑 함수 (`_mapBabyListItem`, `_mapBaby`, `_mapRecord`) 가 헬퍼로 분리 가능하면 순수 함수 테스트 추가 권장:

- `_mapBabyListItem`: id / name 보존.
- `_mapBaby`: `birth_date` / `due_date` null / non-null 케이스, gender enum 매핑.
- `_mapRecord` round-trip: 각 `RecordType` 에 대해 row → CareRecord → row 의 핵심 필드 보존.

### 14.4 AppState 테스트

`SharedPreferences.setMockInitialValues({})` 활용한 in-memory 동작 검증.

| 시나리오 | 검증 |
|---|---|
| 초기 상태 | `selectedBabyId == null` |
| `selectBaby('a')` | `selectedBabyId == 'a'`, listener notified |
| 재호출 `selectBaby('b')` | `selectedBabyId == 'b'`, listener notified |
| `clearSelectedBaby()` | `selectedBabyId == null`, listener notified |

---

## 15. 파일 추가 / 수정 예상 목록

**신규 도메인 모델**
- `lib/domain/models/baby/baby_list_item.dart`
- `lib/domain/models/baby/baby.dart`
- `lib/domain/models/care_record/care_record.dart`
- `lib/domain/models/care_record/record_detail_data.dart` (sealed + 변종 6종)
- `lib/domain/models/common/records_cursor.dart` (그리고 `Page<T>` 가 별도 타입으로 필요하면 같은 폴더)
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
- `lib/core/config/dependencies.dart` — `SharedPreferences` / `AppState` / Baby* / Record* 등록
- `lib/main.dart` — `SharedPreferences.getInstance()` await 후 DI 주입

**테스트**
- `test/domain/models/care_record/record_detail_data_test.dart`
- `test/data/repositories/baby_repository/baby_repository_impl_test.dart`
- `test/data/repositories/record_repository/record_repository_impl_test.dart`
- `test/common/app_state/app_state_test.dart`

**`pubspec.yaml`**
- `shared_preferences` 추가
