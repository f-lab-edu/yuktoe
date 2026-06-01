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
    - **로컬 저장소 wrapper** (`AppLocalStorage`) — `selected_baby_id` 등 단순 KV 값을 다루는 얇은 래퍼. 변경 알림 책임 없음.
    - **현재 선택된 baby 의 application-scope state** (`CurrentBabyController`) — 메모리 보관 + 변경 알림 (`ChangeNotifier`).
- **이 PR 범위 아님**:
    - `HomeViewModel`, 홈 화면 위젯 등 **화면 단위 Presentation Layer**.
    - 본 spec 의 §8 "호출자 동작 시퀀스" 는 호출자 (= ViewModel) 관점 참고용.

---

## 2. 레이어 구조

```
┌──────────────────────────────┐
│  HomeViewModel  (별도 PR)    │
└──┬───────────┬───────────┬───┘
   │           │           │ depends on
   ▼           ▼           ▼
┌────────┐ ┌──────────┐ ┌─────────────────────┐
│ Baby   │ │ Record   │ │ CurrentBaby         │
│ Repo   │ │ Repo     │ │ Controller          │
└───┬────┘ └────┬─────┘ └────┬────────────────┘
    │           │            ▼
    │           │       ┌──────────────────┐
    │           │       │ AppLocalStorage  │
    │           │       └────┬─────────────┘
    ▼           ▼            ▼
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

- ViewModel 은 **Repository** 와 **`CurrentBabyController`** 만 의존한다. Service / 백엔드 클라이언트 / `AppLocalStorage` / 로컬 영구 저장소는 ViewModel 에 노출되지 않는다.
- Repository 는 입력으로 `babyId` 를 받는다. "현재 선택된 baby" 의 메모리 보관과 변경 알림은 `CurrentBabyController` 의 책임이며, 로컬 영속화는 `AppLocalStorage` 가 담당한다. ViewModel 은 `currentBabyController.selectedBabyId` 를 읽어 Repository 호출에 전달한다.
- "저장된 ID 가 현재 사용자에게 실제 접근 가능한가" 의 검증 책임은 **`BabyRepository.getBaby` 의 결과**가 진다 (도메인 규칙이 Data Layer 에 자연스럽게 위치). ViewModel 은 결과의 에러 코드 (`notFound` 등) 를 보고 fallback 을 결정한다 — ViewModel 에 도메인 판정 로직을 두지 않는다.
- Repository 는 도메인 모델 + `Result<T>` 만 노출한다. DB 응답 원본 / `Map<String, dynamic>` / DTO 가 Repository 경계 밖으로 새 나가서는 안 된다.

---

## 3. 도메인 모델 요구사항

### 3.1 모델 공통 정책

- **값을 바꾸지 않는다 (immutable)**: 본 spec 의 모든 도메인 모델은 한 번 만들어진 뒤 필드 값을 바꿀 수 없다. 모든 필드는 `final` 이며, 변경이 필요하면 `copyWith` 로 새 인스턴스를 만든다.
- **동일성 비교는 `id` 만 본다**: `==` / `hashCode` 는 `id` 만으로 정의한다. 같은 아기 / 같은 기록은 조회 시점이 달라 다른 필드 값을 갖더라도 같은 객체로 본다.
- **시각은 UTC**: 모델의 모든 `DateTime` 필드 (occurredAt, startedAt, endedAt, createdAt, birthDate, dueDate) 는 UTC 로 저장 / 표현한다. 로컬 시간대로의 변환은 화면 계층 (ViewModel 이상) 의 책임이다.
- **String 필드는 비어 있지 않다**: nullable 로 명시되지 않은 String 필드는 앞뒤 공백을 제거한 뒤 빈 문자열이 아니어야 한다. 구체적인 최대 길이는 백엔드 / DB CHECK 가 막아 준다.
- **enum 의 신규 값 대응**: 모든 enum (`RecordType`, `Gender`, `DiaperType`, `SleepType`) 의 SOT 는 백엔드다. 클라이언트가 모르는 새 값을 받으면 **그 행은 `parseFailed` 로 거부** 한다. 즉, 백엔드가 새 값을 추가해도 클라이언트가 같이 업데이트되기 전까지는 그 행을 다룰 수 없다.

### 3.2 아기 모델 — 두 가지 형태

각 쿼리가 필요로 하는 데이터의 폭이 다르므로 도메인 모델을 분리한다.

| 모델 | 필드 | 용도 |
|---|---|---|
| `BabyListItem` | `id`, `name` | "선택 후보 목록" 표시 — 사용자가 어떤 아기로 전환할지 고르는 화면. |
| `Baby` | `id`, `name`, `birthDate` (nullable), `dueDate` (nullable), `gender` | "현재 선택된 아기의 기본 정보" — 홈 상단의 이름 / D-day / D+N 계산의 원본. |

#### 두 모델의 id 관계

- **`BabyListItem.id` 와 `Baby.id` 는 같은 종류의 id** 다. 같은 `id` 값을 가진 두 모델은 같은 아기를 가리킨다.
- 같은 아기에 대해 `BabyListItem.name` 과 `Baby.name` 은 같은 시점의 DB 행에서 가져온 값이므로 같다. 단, **두 모델을 조회한 시점이 다르면 그 사이에 이름이 바뀌었을 수 있다** — 호출자가 최신 값을 원하면 다시 조회해야 한다.

#### 부가 규칙

- `BabyListItem` 은 리스트 화면용 가벼운 모델이다. 사용자가 한 명을 선택하면, 그 아기에 대해서는 별도로 `Baby` 를 조회한다.
- `birthDate` 와 `dueDate` 는 둘 다 null 일 수 있다 (출생 전 / 입양 등). 둘 다 null 인 상태도 정상이다. 두 값의 순서 관계 (예: birthDate ≥ dueDate) 는 본 spec 에서 다루지 않는다 — 입력 화면의 UX 책임이다.
- D+N / D-day 같은 사용자에게 보여줄 문자열은 ViewModel 이상에서 계산한다. Data Layer 는 원본 `DateTime?` 만 노출한다.

### 3.3 기록 모델

#### `CareRecord` — 여러 부분이 모인 모델

기록의 공통 헤더 + 세부 데이터.

| 필드 | 타입 | 비고 |
|---|---|---|
| `id` | String | 시스템 전체에서 유일. 백엔드가 부여. |
| `babyId` | String | `Baby.id` / `BabyListItem.id` 와 같은 종류의 id. |
| `createdBy` | String | 기록을 생성한 사용자 ID. |
| `createdAt` | DateTime (UTC) | 백엔드가 부여. |
| `detail` | `RecordDetailData` | sealed. 각 하위 클래스가 타입별 세부 데이터를 보유. **기록 카테고리 (type) 와 사건 시각도 모두 `detail` 안에 있다.** |

**type 의 SOT**: `CareRecord` 자체에는 `type` 필드가 없다. 기록 카테고리는 `detail` 의 실제 하위 클래스 (예: `BreastDetail`) 가 곧 표현이며, 호출자가 `RecordType` 으로 접근하고 싶을 때는 `record.detail.type` 으로 꺼내 쓴다. 호출자 편의를 위해 `CareRecord` 가 `RecordType get type => detail.type` 같은 위임 getter 를 둘 수는 있지만, 저장된 필드는 아니다. 같은 정보가 두 곳에 따로 저장되지 않으므로 구조적으로 짝이 어긋날 수 없다.

**사건 시각의 SOT**: `CareRecord` 자체에는 사건 시각 필드가 없다. 사건이 일어난 시각은 `detail.occurredAt` 한 곳에서만 관리한다 (§3.3 `RecordDetailData` 참조).

**값 변경 가능 여부**: `CareRecord` 도 다른 모델과 마찬가지로 값을 바꾸지 않는다. 의미 있는 부분 변경은 `detail` 교체 뿐 (`copyWith(detail: ...)`). 나머지 필드 (id, babyId, createdBy, createdAt) 는 한 번 정해지면 바뀌지 않는다.

#### `RecordType`

본 앱이 다루는 기록 카테고리는 **9 종**.

| 값 | 의미 |
|---|---|
| `breast` | 모유 수유 (구간 이벤트) |
| `formula` | 분유 |
| `pumping` | 유축 (구간이 아닌 시점 이벤트) |
| `pumpingFeed` | 유축한 모유를 먹임 |
| `babyFood` | 이유식 |
| `snack` | 간식 |
| `water` | 물 |
| `diaper` | 기저귀 |
| `sleep` | 수면 (구간 이벤트) |

이 중 **구간 이벤트** (시작 시각 + 종료 시각을 모두 가지는 것) 는 `breast`, `sleep` 두 종이다. 나머지는 단일 시점 이벤트.

#### `RecordDetailData` (sealed)

타입별 세부 데이터. **각 하위 클래스가 자기 자신의 직렬화 (`toJson` / `fromJson`) 를 직접 들고 있다** (필드만 가진 단순 값 객체이므로 데이터 소스에 의존하지 않는다).

**공통 약속**:
- `RecordDetailData` 는 `RecordType get type` 추상 getter 를 가진다. 각 하위 클래스가 자기 `RecordType` 값을 override 하여 노출한다 (예: `BreastDetail.type => RecordType.breast`). 기록 카테고리의 SOT 는 이 getter 다.
- `RecordDetailData` 는 `DateTime get occurredAt` 추상 getter 를 가진다. 이 값은 **"정렬과 표시의 기준이 되는 시각"** 이며, 구간 이벤트 (breast / sleep) 의 경우 `startedAt` 과 같은 값이다.
- `occurredAt` 은 UTC.
- 구간 이벤트는 `startedAt`, `endedAt` 두 필드를 모두 가지며 **항상 `startedAt < endedAt`** 이다. (반대로 끝나는 구간은 의미가 없어 도메인 단에서 거부.)
- 구간 이벤트의 `endedAt` 은 **null 불가**. "진행 중" 상태는 데이터로 존재하지 않는다 — UI 의 스톱워치는 시작과 종료 사이의 메모리 상태일 뿐이고, 사용자가 종료를 확정해야 비로소 도메인 모델이 만들어진다. 도중에 앱이 종료되면 데이터는 생성되지 않는다.

**변종별 필드 / 단위 / nullable 의미**:

| 변종 | 필드 | 단위 / 의미 |
|---|---|---|
| `BreastDetail` | `startedAt`, `endedAt`, `leftMinutes` (int?), `rightMinutes` (int?) | 분 단위. `null` = 해당 쪽을 수유하지 않음. `0` = 수유는 시도했으나 시간은 0 분. occurredAt = startedAt. |
| `SleepDetail` | `startedAt`, `endedAt`, `sleepType` (`SleepType`) | sleepType ∈ {nap, night}. occurredAt = startedAt. |
| `PumpingDetail` | `occurredAt`, `leftAmountMl` (int?), `rightAmountMl` (int?) | ml. `null` = 해당 쪽 유축 안 함. `0` = 유축했으나 양은 0 ml. |
| `PumpingFeedDetail` | `occurredAt`, `amountMl` (int) | ml. 필수. |
| `FormulaDetail` | `occurredAt`, `amountMl` (int) | ml. 필수. |
| `BabyFoodDetail` | `occurredAt`, `name` (String?), `amountMl` (int) | name 은 nullable (메뉴 미기입 허용). amountMl 은 필수. |
| `SnackDetail` | `occurredAt`, `name` (String?) | name 은 nullable. |
| `WaterDetail` | `occurredAt`, `amountMl` (int) | ml. 필수. |
| `DiaperDetail` | `occurredAt`, `diaperType` (`DiaperType`) | diaperType ∈ {pee, poop, mixed}. |

> ⚠️ **도메인 코드 변경 필요**: 현재 `BabyFoodDetail.name` / `SnackDetail.name` 은 non-null `String` 으로 구현되어 있다. 본 spec 의 결정 (nullable) 에 맞추는 도메인 코드 변경은 별도 PR 로 진행한다.

### 3.4 페이지네이션 모델

기록 리스트 조회의 응답은 다음 정보를 포함하는 **페이지** 형태여야 한다.

| 필드 | 타입 | 용도 |
|---|---|---|
| `items` | `List<T>` | 페이지에 포함된 항목 리스트. 모든 항목은 같은 타입 `T`. 페이지 크기 ≤ `limit`. |
| `nextCursor` | String? | 다음 페이지를 요청할 때 그대로 다시 넘겨주는 문자열. 호출자는 내부를 들여다볼 필요가 없다. 다음 페이지가 없으면 `null`. |
| `hasMore` | bool | 다음 페이지 존재 여부. |

**Cursor 의 표현과 계약**:
- Cursor 는 **호출자가 내부를 들여다볼 필요 없는** 문자열이다. 호출자는 cursor 를 해석하지 않고, 받은 그대로 다음 호출에 다시 넘기기만 한다.
- 내부적으로는 **"마지막으로 반환된 항목의 `id`"** 를 기반으로 한다 (구체 인코딩은 Part 2 의 구현 메모 참조).
- **`hasMore == true` 와 `nextCursor != null` 은 같은 의미** 다. 둘 중 하나만 검사해도 충분하다.

**Cursor 의 유효기간 / 다른 아기에게 재사용**: 본 spec 은 cursor 의 유효기간이나, 다른 아기의 cursor 를 재사용했을 때의 동작 등을 정의하지 않는다 — "의도된 사용 흐름 안에서만 동작이 보장된다" 가 기본 전제다.

---

## 4. AppLocalStorage 요구사항

> 본 PR 에서 `AppState` 는 두 컴포넌트로 분리된다: 로컬 영속화를 담당하는 **`AppLocalStorage`** (본 섹션) 와, 메모리 보관 + 변경 알림을 담당하는 **`CurrentBabyController`** (§4-bis).

### 4.1 책임

- 앱의 단순 KV 로컬 저장소 — 본 PR 에서는 `selectedBabyId` 한 키를 다루지만, 향후 다른 key 도 같은 패턴으로 추가될 수 있는 일반 wrapper.
- backend (`SharedPreferences`) 를 래핑하고, 호출자에게는 **키마다 도메인 의미를 가진 typed 인터페이스** 를 노출한다.
- **변경 알림 (`ChangeNotifier`) 책임 없음.** 호출자가 값을 바꾼 사실은 호출자 자신이 알아서 다른 곳에 전파한다.

### 4.2 노출 인터페이스

본 PR 범위의 메서드는 `selectedBabyId` 한 키에 대한 것뿐. 다른 키는 같은 패턴으로 wrapper 안에 추가된다.

| 멤버 | 동작 |
|---|---|
| `String? get selectedBabyId` | 저장된 `selected_baby_id` 값을 동기로 반환. 저장된 값이 없으면 `null`. |
| `Future<void> setSelectedBabyId(String babyId)` | 값을 로컬에 저장. |
| `Future<void> removeSelectedBabyId()` | 키를 로컬 저장소에서 제거. |

### 4.3 책임의 경계 — AppLocalStorage 가 하지 않는 일

- **변경 알림하지 않는다.** 값을 set 했다고 listener 를 호출하지 않는다.
- **저장된 ID 의 의미 / 권한 / 유효성을 검증하지 않는다.** "이 ID 가 현재 사용자에게 접근 가능한 baby 인지" 는 Data Layer (`BabyRepository.getBaby`) 의 결과로 알 일이며, Storage 의 관심사 밖.
- 로그아웃 자체는 Storage 의 책임이 아니다. `CurrentBabyController.clear()` 가 내부적으로 `removeSelectedBabyId()` 를 호출하는 형태로 간접적으로만 관여한다 (§4-bis.3 참조).

### 4.4 인스턴스 수 가정

- **DI 컨테이너에 단 하나** 등록. 앱 전체가 이 인스턴스를 공유.
- `SharedPreferences` 인스턴스는 본 wrapper 의 생성자에 주입된다 (§10 참조).

### 4.5 빈 / 실패 케이스

- 저장된 값이 없는 상태는 **에러가 아니다** — `selectedBabyId` 는 단순히 `null`.
- 로컬 저장소 자체의 read/write 실패는 본 PR 범위에서는 별도로 처리하지 않는다.

---

## 4-bis. CurrentBabyController 요구사항

### 4-bis.1 책임

- 앱 전체에서 공유되는 **"현재 선택된 baby" 의 application-scope state holder.** 메모리에 `selectedBabyId` 를 보관하고 변경을 listener (여러 ViewModel) 에 알린다.
- `AppLocalStorage` 를 의존하여 부팅 시 마지막 값을 복원하고, 변경 시 영속화한다.
- `ChangeNotifier` 를 extend 한다. (구체 구현은 §10-bis 참조.)

### 4-bis.2 노출 인터페이스

| 멤버 | 동작 |
|---|---|
| `String? get selectedBabyId` | 메모리에 보관 중인 현재 baby ID. 저장된 값이 없으면 `null`. 동기. |
| `Future<void> select(String babyId)` | 메모리 값을 갱신하고 `AppLocalStorage.setSelectedBabyId` 로 영속화한 뒤 `notifyListeners()`. |
| `Future<void> clear()` | 메모리 값을 `null` 로 비우고 `AppLocalStorage.removeSelectedBabyId` 호출 후 `notifyListeners()`. |

### 4-bis.3 책임의 경계 — Controller 가 하지 않는 일

- **저장된 ID 의 유효성 / 권한을 검증하지 않는다.** 그 판단은 호출자 (ViewModel) 가 `BabyRepository.getBaby` 결과의 에러 코드 (`notFound` 등) 로 받는다 (§5.6 참조).
- "저장된 ID 가 stale 이면 첫 번째 baby 로 fallback" 같은 정책은 **ViewModel 의 결과 분기** 로 처리한다. Controller 는 ViewModel 이 결정한 새 ID 를 `select(...)` 로 받기만 한다 (§8.1 step 3 참조).
- 로그아웃 자체는 Controller 의 책임이 아니다. **`AuthRepository.signOut()` 의 성공 후 처리의 일부** 로 호출자가 `currentBabyController.clear()` 를 명시적으로 호출해야 한다 (§8.4).

### 4-bis.4 인스턴스 수 가정

- **DI 컨테이너에 단 하나** 등록. 앱 전체가 이 인스턴스를 공유.
- 본 앱은 **한 디바이스에 한 사용자만 로그인** 되어 있다고 가정한다. 사용자를 바꾸는 흐름은 "로그아웃 → 다른 계정으로 로그인" 이며, 그 과정에서 `clear()` 가 호출되어 이전 사용자의 선택은 비워진다.

### 4-bis.5 빈 / 실패 케이스

- 저장된 값이 없는 부팅 상태는 **에러가 아니다** — `selectedBabyId == null`.
- `AppLocalStorage` 의 set/remove 실패에 대한 별도 처리는 본 PR 범위 아님 (§4.5 와 동일).

---

## 5. BabyRepository 요구사항

### 5.1 목적

홈 화면이 "어떤 아기를 보여줄 것인가" 를 결정하기 위한 **선택 후보 목록** 과, "현재 선택된 아기" 의 **기본 정보** 를 제공한다.

### 5.2 책임

- 현재 인증된 사용자가 **보호자로 등록된 아기들** 의 목록을 제공한다. ("보호자" 의 구체 권한 정의는 백엔드의 책임이고, 도메인 단에서는 "조회 결과가 곧 그 사용자가 볼 수 있는 아기" 라는 의미로만 다룬다.)
- 특정 아기 ID 에 대해 화면 표시에 필요한 **기본 정보** 를 제공한다.
- 결과를 도메인 모델 + `Result<T>` 형태로 ViewModel 에 제공한다.
- 화면 표시용 가공 (라벨, 마스킹, D-day, D+N 등) 은 수행하지 않는다.

### 5.3 호출자

- `HomeViewModel` — 홈 진입 시 목록 + 기본 정보 조회. 보호자 관계 변경 후 목록 재조회. 아기 전환 시 새 선택된 아기의 기본 정보 재조회.

### 5.4 주요 결정

- `userId` 를 인자로 받지 않는다. "현재 사용자" 는 인증 컨텍스트에서 자동 판단한다. 호출자가 잘못된 userId 를 주입할 가능성을 차단한다.
- **목록과 기본 정보 조회를 분리** 한다. 필요한 데이터의 폭이 다르고 (목록: 2필드, 기본 정보: 5필드), 무효화 시점도 다르다 (목록: 보호자 관계 변경, 기본 정보: 아기 전환 / 프로필 수정).
- Repository 는 자체 상태 (캐시 / 큐 / lock 등) 를 갖지 않는다. 따라서 동시에 호출해도 안전하다.

### 5.5 메서드 요구사항: 접근 가능한 아기 목록 조회

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈에서 "어떤 아기를 볼 것인가" 를 선택할 후보 목록을 제공한다. |
| 입력 | 없음. |
| 호출 시점 | 홈 진입 시 1회. 보호자 관계 변경 (아기 추가 / 탈퇴 / 초대 수락) 후 재조회. |
| 결과 데이터 | `List<BabyListItem>` — 각 항목은 `id`, `name` 만 포함한다. |
| 결과 정렬 | 생성일 내림차순 — "내가 가장 최근에 추가한 아기를 가장 위로" UX 요구. |
| 성공 조건 | 사용자가 인증되어 있고, 그 사용자가 보호자인 모든 아기를 조회 / 매핑할 수 있어야 한다. |
| 빈 데이터 | **빈 리스트는 에러로 표현한다 (`AppException(notFound)`).** 홈에 진입하려면 본인이 등록했거나 초대받은 아기가 최소 1명 있어야 하므로, 빈 리스트는 호출자가 다른 동작 (등록 화면으로 이동 등) 을 취해야 하는 신호다. |
| 실패 케이스 | 네트워크 / 호출 실패, 인증 만료 / 미로그인, 응답 파싱 실패 모두 `Result.error(AppException)`. |
| null 처리 | 결과 리스트, 각 항목의 두 필드 모두 non-null. |

### 5.6 메서드 요구사항: 단일 아기의 기본 정보 조회

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 상단에 표시할 아기 이름 / D+N / D-day 등의 계산 원본을 제공한다. |
| 입력 | `babyId` (필수). 호출자가 `CurrentBabyController.selectedBabyId` 로부터 가져온 값을 그대로 전달한다. |
| 호출 시점 | 홈 진입 시 (선택된 아기 결정 직후). 아기 전환 시. 본인이 아기 프로필을 수정한 직후. |
| 결과 데이터 | `Baby` — `id`, `name`, `birthDate` (nullable), `dueDate` (nullable), `gender` 5개 필드. |
| 성공 조건 | 사용자가 인증되어 있고, 해당 `babyId` 에 보호자로 접근 가능하며, 행이 존재해야 한다. |
| 빈 데이터 / 미존재 | 행이 없거나 권한이 없으면 `Result.error(AppException(notFound))`. "현재 선택된 아기" 의 정보 조회는 단일 대상에 대한 명확한 요청이며, 행 없음은 호출자가 후속 동작 (목록 재조회 + 다른 아기 선택) 을 취해야 하는 신호다. |
| 실패 케이스 | `notFound`, `unauthorized`, `networkError`, `parseFailed`. 모두 `Result.error(AppException)`. |
| `notFound` 의 정의 | "해당 `babyId` 의 baby 가 현재 사용자에게 보이지 않음." 행이 실제로 존재하지 않거나, RLS / 권한 정책에 의해 접근이 차단된 경우 **둘 다 포함** 한다. 호출자는 이 코드를 "저장된 selectedBabyId 가 stale 이므로 fallback (예: 목록의 첫 baby) 으로 정합화" 의 신호로 사용할 수 있다. "stale" 만을 위한 별도 코드는 두지 않는다. |
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

- 모든 메서드는 `babyId` 를 인자로 받는다. "현재 선택된 아기" 의 판정은 호출자 (`CurrentBabyController` / ViewModel) 의 책임.
- 기록 생성 시 호출자는 `userId` 를 전달하지 않는다. `createdBy` 는 인증 컨텍스트에서 자동 채워진다.
- 정렬 기준은 카테고리에 따라 달라질 수 있다 (수유 4종 중 `breast` 만 종료 시각 기준, 그 외 수유 3종은 시작 시각 / occurredAt 기준; 기상은 종료 시각 기준). 이 차이는 Repository 가 노출하는 **계약** 이며, 호출자는 정렬 규칙을 알 필요 없이 결과 순서를 신뢰할 수 있어야 한다.
- 본 PR 에서는 기록을 캐싱하지 않는다. 생성 / 삭제 후 ViewModel 이 메모리상 리스트를 직접 정합화한다.
- **최소 1회 보장 (재시도 시 중복 가능)**: `createRecord` 는 네트워크 실패 등으로 재시도되면 **중복 기록이 생성될 수 있다.** Repository 와 백엔드 모두 "같은 요청을 한 번만 처리" 같은 중복 방지 키를 다루지 않는다. 호출자 (ViewModel) 가 단일 클릭 제한 등 UX 단에서 중복 호출을 막는 책임을 진다.
- Repository 는 자체 상태 (캐시 / 큐 / lock 등) 를 갖지 않는다. 따라서 동시에 호출해도 안전하다.

### 6.5 메서드 요구사항: 기록 리스트 조회 (페이지 단위)

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈의 무한 스크롤 기록 리스트를 페이지 단위로 제공. |
| 입력 | `babyId` (필수), `cursor` (없으면 첫 페이지), `limit` (기본 20, 1 ≤ limit ≤ 100). |
| 호출 시점 | 첫 페이지 — 홈 진입 시 / 아기 전환 시 / 기록 생성·삭제 후 리스트 동기화. 다음 페이지 — 스크롤이 하단에 도달했을 때. |
| 결과 데이터 | 페이지 — `items: List<CareRecord>`, `nextCursor: String?`, `hasMore: bool`. `CareRecord` 의 모든 필드 (§3.3) 가 채워진다. 부분 모델은 사용하지 않는다. |
| 결과 정렬 | `detail.occurredAt` 내림차순. 시각이 같으면 `id` 내림차순으로 동률 처리. |
| 페이지네이션 보장 | `nextCursor` 와 `hasMore` 는 §3.4 의 관계 (둘이 같은 의미) 를 따른다. cursor 는 호출자가 내부를 들여다볼 필요 없는 문자열이다. |
| 페이지 크기 상한 | 1 ≤ `limit` ≤ 100. 범위 밖이면 `ArgumentError` (도메인 수준 거부). |
| 빈 데이터 | 기록이 없으면 빈 페이지 (`items = []`, `hasMore = false`, `nextCursor = null`) 를 성공으로 반환. 에러 아님. |
| 실패 케이스 | 네트워크 / 인증 / 권한 오류 → `Result.error(AppException)`. 호출자는 같은 cursor 로 재시도할 수 있어야 한다. |

### 6.6 메서드 요구사항: 최근 수유 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 요약 영역의 "마지막으로 N시간 전에 먹였어요" 및 직전 수유와의 간격 계산. |
| 포함 타입 | 수유 4종 — `breast`, `formula`, `pumping`, `pumpingFeed`, `babyFood`. |
| 입력 | `babyId`, `limit` (기본 2, 1 ≤ limit ≤ 10). |
| 호출 시점 | 홈 진입 시. 수유 기록 생성/삭제 후 재조회. |
| 결과 데이터 | `List<CareRecord>` (최대 `limit` 개). 각 항목은 §3.3 의 모든 필드 채워서 반환. |
| 기준 시각 정의 | "마지막으로 N시간 전에 먹였니" 의 자연스러운 해석은 *수유가 끝난 뒤* 의 경과 시간. 따라서: `breast` → `endedAt`, 그 외 수유 3종 → `detail.occurredAt` 을 기준 시각으로 사용. |
| 결과 정렬 | 위 기준 시각의 내림차순. 동일 시각이면 `id` 내림차순. |
| 페이지 크기 상한 | 1 ≤ `limit` ≤ 10. 범위 밖이면 `ArgumentError`. |
| 빈 데이터 | 빈 리스트. 1건만 있으면 1건만. |
| 실패 케이스 | `Result.error(AppException)`. |

### 6.7 메서드 요구사항: 최근 기저귀 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 요약 영역의 "마지막으로 N시간 전에 기저귀 갈았어요". |
| 포함 타입 | `diaper`. |
| 입력 | `babyId`, `limit` (기본 2, 1 ≤ limit ≤ 10). |
| 호출 시점 | 홈 진입 시. 기저귀 기록 생성/삭제 후 재조회. |
| 결과 데이터 | `List<CareRecord>` (최대 `limit` 개). 모든 항목의 `detail` 은 `DiaperDetail`. |
| 결과 정렬 | `detail.occurredAt` 내림차순. 동일 시각이면 `id` 내림차순. |
| 페이지 크기 상한 | 1 ≤ `limit` ≤ 10. 범위 밖이면 `ArgumentError`. |
| 빈 데이터 | 빈 리스트. 1건만 있으면 1건만. |
| 실패 케이스 | `Result.error(AppException)`. |

### 6.8 메서드 요구사항: 최근 기상 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 요약 영역의 "마지막으로 N시간 전에 일어났어요". "기상" 은 수면 기록의 종료 시점으로 정의. |
| 포함 타입 | `sleep`. |
| 입력 | `babyId`, `limit` (기본 2, 1 ≤ limit ≤ 10). |
| 호출 시점 | 홈 진입 시. 수면 기록 생성/삭제 후 재조회. |
| 결과 데이터 | `List<CareRecord>` (최대 `limit` 개). 모든 항목의 `detail` 은 `SleepDetail`. `SleepDetail.endedAt` 은 null 일 수 없다 (§3.3 의 규칙). |
| 기준 시각 | 수면 기록의 `endedAt` (= 기상 시각). |
| 결과 정렬 | `endedAt` 내림차순. 동일 시각이면 `id` 내림차순. |
| 페이지 크기 상한 | 1 ≤ `limit` ≤ 10. 범위 밖이면 `ArgumentError`. |
| 빈 데이터 | 빈 리스트. 1건만 있으면 1건만. |
| 실패 케이스 | `Result.error(AppException)`. |

### 6.9 메서드 요구사항: 기록 생성

| 항목 | 요구사항 |
|---|---|
| 목적 | 사용자의 새 기록을 영속화하고, 반영 결과를 즉시 도메인 모델로 반환. |
| 입력 | `babyId`, `detail` (`RecordDetailData`). |
| 호출 시점 | 사용자가 기록 작성 UI 에서 저장을 확정할 때. |
| 메타데이터 결정 | `type`, `occurredAt`, `startedAt`, `endedAt` 등 사건 메타데이터는 모두 `detail` 안에 있다 — `detail` 객체 하나가 SOT. Service 가 백엔드로 보낼 때 필요한 type 값은 `detail.type` 으로 꺼낸다. |
| `createdBy` 결정 | 호출자가 전달하지 않는다. Service 가 인증 컨텍스트의 현재 사용자로 자동 채운다. |
| 재시도 안전성 | **최소 1회 보장**. 재시도하면 중복 행이 생길 수 있다. ViewModel 이 단일 클릭 제한 등으로 중복을 막는다. (§6.4 주요 결정 참조) |
| 성공 조건 | 영속화 성공 후, 반영된 행을 다시 `CareRecord` 도메인 모델로 매핑할 수 있어야 한다. |
| 결과 데이터 | `Result.ok(CareRecord)` — 단일 `CareRecord`. 영속화 시 채워진 `id`, `createdAt` 까지 포함한 모든 필드. ViewModel 은 이 모델을 그대로 리스트 맨 앞에 append 할 수 있어야 한다. |
| 실패 케이스 | 미로그인/만료 → `unauthorized`. 권한 거부 (해당 아기의 보호자 아님) → `unauthorized`. 네트워크 실패 → `networkError`. 응답 파싱 실패 → `parseFailed`. 모두 `Result.error(AppException)`. |

### 6.10 메서드 요구사항: 기록 삭제

| 항목 | 요구사항 |
|---|---|
| 목적 | `recordId` 로 식별되는 기록을 영구 삭제. |
| 입력 | `recordId`. |
| 호출 시점 | 사용자가 기록 항목 삭제를 확정할 때. |
| 권한 | Repository 는 사전 검사하지 않는다. 권한 판정은 백엔드의 보안 정책에 위임한다. |
| 미존재 처리 | 존재하지 않거나 이미 삭제된 `recordId` 로 호출되면 `Result.error(AppException(notFound))` 로 명시 구분한다 ("같은 요청을 또 보내도 성공으로 처리" 하지 않는다). 호출자는 이를 보고 UI 메시지를 달리 처리할 수 있다. |
| 결과 데이터 | `Result.ok(null)`. 반환 페이로드 없음. 호출자가 삭제된 항목의 정보가 필요하면 자신이 들고 있는 메모리상 모델을 사용. |
| 실패 케이스 | `notFound`, `unauthorized`, `networkError`, 기타 모두 `Result.error(AppException)`. 실패 유형은 `AppException.code` 로 구분. |

---

## 7. Service Layer 요구사항

### 7.1 책임

- Repository 의 **하부 협력자**. 원격 백엔드 호출, raw 응답을 도메인 모델로 매핑, 인증 컨텍스트 주입 같은 외부 시스템 연동 책임.
- Repository 만이 Service 에 의존한다. ViewModel 은 Service 의 존재를 알지 못한다.
- 메서드는 `Result<T>` 를 반환한다. throw 하지 않으며, 모든 외부 실패는 `AppException` 으로 변환된다.
- 매핑 결과는 항상 도메인 모델이다. DB 응답 원본 / `Map<String, dynamic>` / DTO 는 Service 경계 밖으로 나가지 않는다.

### 7.2 BabyService 의 메서드 — 책임

| 메서드 | 책임 |
|---|---|
| 아기 목록 조회 | 현재 인증 사용자가 보호자인 아기들을 `BabyListItem` (id, name) 목록으로 반환. 생성일 내림차순 보장. |
| 단일 아기 정보 조회 | 주어진 `babyId` 의 기본 정보를 `Baby` (id, name, birthDate, dueDate, gender) 로 반환. 행이 없거나 권한이 없으면 `notFound` 로 변환. |

### 7.3 RecordService 의 메서드 — 책임

| 메서드 | 책임 |
|---|---|
| 페이지 단위 기록 조회 | 마지막 항목의 `id` 기반 cursor 로 다음 페이지를 조회. 다음 페이지 존재 여부 (hasMore) 와 다음 cursor 를 결과에 포함. |
| 카테고리별 최근 N건 조회 | 호출자가 지정한 타입 집합과 기준 시각 (occurredAt / endedAt / 수유용 합성 키 중 하나) 으로 정렬해 최대 N건을 반환. |
| 기록 생성 | 호출자가 전달한 `detail` 에 더해 `createdBy` 를 인증 컨텍스트의 현재 사용자로 자동 채운 뒤 영속화. 결과 행을 다시 `CareRecord` 로 매핑해 반환. |
| 기록 삭제 | `recordId` 로 삭제 요청. 영향 행 수를 확인해 0 이면 `notFound` 로 변환. |

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
                                                                // 빈 리스트일 가능성 없음 (notFound 가 됨)
2. savedId     = currentBabyController.selectedBabyId          // String? (sync, 메모리)
3. candidateId := savedId ?? babies.first.id
4. babyResult  = babyRepository.getBaby(candidateId)           // 기본 정보 + stale 판정 동시
     switch babyResult:
       ok(baby):
         currentBabyId = baby.id
         if savedId == null: currentBabyController.select(currentBabyId)  // 첫 진입 영속화
       error(notFound):
         // candidateId 가 stale (행 없음 / 권한 차단 둘 다 포함).
         // 첫 baby 로 fallback 후 재조회.
         currentBabyId = babies.first.id
         babyResult    = babyRepository.getBaby(currentBabyId)
         currentBabyController.select(currentBabyId)
       error(unauthorized): → 로그인 화면
       error(networkError): → "다시 시도" UI
       error(parseFailed):  → 에러 화면
5. currentBabyId 로 추가 데이터 병렬 조회:
   a. recordRepository.getRecords(currentBabyId, cursor: null, limit: 20)
   b. recordRepository.getRecentFeedings(currentBabyId)
   c. recordRepository.getRecentDiapers(currentBabyId)
   d. recordRepository.getRecentWakes(currentBabyId)
6. step 4 의 baby 정보 + step 5 결과를 합성 후 화면 렌더
```

> ViewModel 은 `babies.any(...)` 같은 도메인 판정 로직을 두지 않는다. "savedId 가 stale 인지" 의 판단은 `babyRepository.getBaby` 결과의 `notFound` 코드 한 가지로만 받는다 (§5.6 의 `notFound` 정의 참조).
>
> Fallback 후 (`babies.first.id` 로 재조회) 또 `notFound` 가 나는 경우는 보호자 관계가 race condition 으로 깨진 매우 드문 케이스다. 이때는 추가 재시도 없이 에러 화면 또는 "이용 가능한 baby 가 없음" 안내로 전환한다.

**부분 실패 정책**: step 4 의 `getBaby` 와 step 5 의 4 개 호출은 **각각 독립적으로 성공/실패** 한다. 한 영역 (예: 기본 정보) 이 실패해도 다른 영역 (예: 기록 리스트) 이 성공했다면 화면은 그 부분만 정상 렌더링하고, 실패한 영역에는 해당 영역만의 "다시 시도" UI 를 표시한다. ViewModel 이 영역별 상태를 분리 관리한다. (단, step 4 의 `unauthorized` / `parseFailed` 처럼 전역 분기로 가는 코드는 부분 실패가 아니라 전체 화면 분기다.)

### 8.2 아기 전환

```
1. UI 가 chevron → BottomSheet 로 babies 목록 (BabyListItem) 표시
2. 사용자가 다른 baby 선택 → currentBabyController.select(newId)
3. ViewModel 이 CurrentBabyController 변경을 감지 → §8.1 의 step 4 부터 재실행 (candidateId = newId)
   ※ step 4 의 notFound 분기는 사용자가 목록에서 보던 사이에 보호자 관계가 깨진 race condition 일 때만 발생한다.
```

### 8.3 기록 생성 / 삭제 / infinite scroll

- **생성**: `createRecord(babyId, detail)` → 성공 시 ViewModel 이 리스트 맨 앞 append + 해당 카테고리의 `getRecent*` 재호출. 호출 중에는 저장 버튼을 비활성화 (중복 생성 방지, §6.4 참조).
- **삭제**: `deleteRecord(id)` → 성공 시 리스트에서 제거 + 삭제된 기록이 해당 카테고리의 최근 2개 중 하나였다면 `getRecent*` 재호출. `notFound` 시에는 이미 삭제된 것으로 보고 메모리상 리스트도 제거.
- **infinite scroll**: 하단 도달 → `getRecords(babyId, cursor: page.nextCursor)` → append. `hasMore == false` 이후는 호출하지 않는다.

### 8.4 로그아웃

```
1. 사용자가 로그아웃 → authRepository.signOut()
2. signOut 성공 시 호출자가 명시적으로 currentBabyController.clear() 호출
   (Controller 가 내부적으로 AppLocalStorage.removeSelectedBabyId() 까지 처리)
3. 라우터가 로그인 화면으로 이동
```

---

# Part 2. 구현 방법

본 프로젝트가 선택한 기술 스택에 맞춘 구현 메모. Part 1 의 요구사항을 깨지 않는 범위에서 자유롭게 바뀔 수 있다.

## 9. 기술 스택 선택

| 영역 | 선택 | 이유 / 비고 |
|---|---|---|
| 원격 백엔드 | **Supabase** (Auth + PostgREST + RLS) | 프로젝트 전반의 기존 선택. 인증 / DB / 권한이 통합되어 있다. |
| 로컬 저장소 | **`shared_preferences`** 패키지 | 단일 key-value 만 필요 (`selectedBabyId`). 추가 의존성 최소화. |
| 상태 관리 / DI | **`provider`** + `ChangeNotifier` | 프로젝트 전반의 기존 선택. `CurrentBabyController` 는 `ChangeNotifier` 로 변경 알림. `AppLocalStorage` 는 변경 알림 없는 일반 `Provider`. |
| 비동기 결과 표현 | 프로젝트 내부 `Result<T>` (sealed `Ok` / `Error`) | 기존 패턴 재사용. throw 대신 명시적 분기. |
| 테스트 mock | **`mockito`** | 프로젝트 전반의 기존 선택. Service 를 mock 해 Repository 단위 테스트. |

---

## 10. AppLocalStorage 구현

### 10.1 상세 동작

- 일반 클래스. `ChangeNotifier` 가 아니다.
- 생성자에서 `SharedPreferences` 를 주입받는다. `init()` 같은 별도 부트스트랩 메서드는 두지 않는다.
- `selectedBabyId` getter 는 동기. `SharedPreferences.getString` 이 동기 API 이기 때문.
- `setSelectedBabyId` / `removeSelectedBabyId` 는 `SharedPreferences.setString` / `remove` 결과의 `Future` 를 그대로 반환.
- key: `'selected_baby_id'` — 클래스 내부의 `static const` 로 두어 외부에 노출하지 않는다.

### 10.2 부트스트랩

- `main.dart` 에서 `SharedPreferences.getInstance()` 를 await 한 결과를 DI 컨테이너에 주입.
- DI 에서 **앱 전체에 한 인스턴스만** 등록 (§4.4).

### 10.3 실패 처리

- 본 PR 에서는 `SharedPreferences` 의 read/write 실패를 별도로 catch 하지 않는다. 플랫폼 의존 영역이며 실제로는 거의 실패하지 않는다.

### 10.4 향후 키 추가 시 패턴

새 로컬 키가 필요해지면 같은 wrapper 에 다음 패턴으로 메서드를 추가한다:
- `static const _<key>Key = '...'` — 키 문자열을 private const 로.
- 도메인 의미를 가진 typed getter (`T? get <name>` 또는 default 가 있는 경우 `T get <name>`).
- 영속화 setter (`Future<void> set<Name>(T value)`).
- 필요 시 remove 메서드.

별도의 도메인별 `Store` 클래스를 만드는 대신, 같은 wrapper 에 메서드를 추가하는 것이 본 spec 의 결정 (§4.1). 변경 알림이 필요한 reactive 한 값은 wrapper 가 아니라 application-scope `ChangeNotifier` (`CurrentBabyController` 와 동일 패턴) 가 담당한다.

---

## 10-bis. CurrentBabyController 구현

### 10-bis.1 상세 동작

- `ChangeNotifier` 를 extend 한다. 위젯 / ViewModel 은 `context.watch<CurrentBabyController>()` 등 Provider 의 도구로 구독한다.
- 메모리 변수 `_selectedBabyId: String?` 를 보관한다.
- `selectedBabyId` getter 는 메모리 변수를 반환 (동기).
- `select(babyId)` — `AppLocalStorage.setSelectedBabyId(babyId)` await → `_selectedBabyId = babyId` → `notifyListeners()`.
- `clear()` — `AppLocalStorage.removeSelectedBabyId()` await → `_selectedBabyId = null` → `notifyListeners()`.

### 10-bis.2 부트스트랩

- 생성자에서 `AppLocalStorage` 를 주입받는다.
- 생성자에서 `_selectedBabyId = appLocalStorage.selectedBabyId` 로 메모리 변수를 **동기 초기화** (Storage 의 getter 가 동기이므로 가능). `init()` 같은 별도 부트스트랩 메서드는 두지 않는다.
- DI 에서 **앱 전체에 한 인스턴스만** 등록 (§4-bis.4).

### 10-bis.3 실패 처리

- 본 PR 에서는 `AppLocalStorage` 의 set/remove 실패를 별도로 catch 하지 않는다.

### 10-bis.4 로그아웃 hook

- `AuthRepository.signOut()` 의 성공 분기를 처리하는 호출자 (라우터 또는 로그아웃을 트리거한 ViewModel) 가 명시적으로 `currentBabyController.clear()` 를 호출한다. Controller 가 AuthRepository 를 구독하지는 않는다 — 의존성 방향을 단순하게 유지.

---

## 11. 도메인 코드의 spec 맞춤 작업

본 spec 의 규칙을 충족하려면 현재 도메인 코드에 다음 변경이 필요하다 (별도 PR 가능).

| 항목 | 현재 코드 | spec 결정 |
|---|---|---|
| `CareRecord.type` 필드 | `final RecordType type` 필드 보유 | **필드 제거**. type 은 `detail.type` 에서 꺼내 쓴다 (호출자 편의 getter 는 선택). |
| `RecordDetailData.type` getter | 추상 getter 없음 | `RecordType get type` 추상 getter 추가. 각 하위 클래스가 자기 RecordType 을 override 하여 노출. |
| `BabyFoodDetail.name` | null 불가 `String` | nullable `String?` 로 변경. |
| `SnackDetail.name` | null 불가 `String` | nullable `String?` 로 변경. |
| `BreastDetail` / `SleepDetail` 의 `startedAt < endedAt` 조건 | 생성자에 assert 없음 | 생성자에서 `assert(startedAt.isBefore(endedAt))` 추가. |
| String 필드의 앞뒤 공백 제거 후 비어 있지 않음 | 검증 없음 | `Baby.name` 등 필수 string 필드에 `assert(value.trim().isNotEmpty)` 추가. |
| 모델 == / hashCode | 자동 (참조 비교) | `id` 기반 `==` / `hashCode` 구현. |

---

## 12. Service 구현 (Supabase)

### 12.1 BabyService

| 메서드 | Supabase 동작 |
|---|---|
| 아기 목록 조회 | `babies` 에서 `id`, `name` 컬럼만 select, `created_at desc` 정렬. RLS 가 보호자 관계를 강제하므로 별도 user 필터 없음. |
| 단일 아기 정보 조회 | `babies` 에서 5컬럼 (`id`, `name`, `birth_date`, `due_date`, `gender`) 을 `eq('id', babyId).maybeSingle()` 로 조회. null 이면 `notFound` 로 변환. |

### 12.2 RecordService

| 메서드 | Supabase 동작 |
|---|---|
| 페이지 조회 | `care_records` 를 `eq('baby_id', babyId)` + (cursor 있으면) `lt('id', cursor)` 조건 + `order('occurred_at' desc).order('id' desc).limit(limit + 1)`. `limit + 1` 트릭으로 `hasMore` 판정. cursor 는 마지막 행의 `id`. |
| 최근 N건 조회 | `eq('baby_id', babyId).inFilter('type', types).order(orderColumn desc).order('id' desc).limit(limit)`. `orderColumn` 은 카테고리에 따라 `occurred_at`, `ended_at` (sleep), 또는 수유 4종을 위한 합성 generated column. |
| 생성 | `_client.auth.currentUser?.id` 로 `createdBy` 결정 (null 이면 `unauthorized`). `baby_id`, `type`, `detail` (jsonb), `created_by` insert. 결과 행을 `_mapRecord` 로 다시 매핑. `occurred_at` / `ended_at` 컬럼은 generated 로 jsonb 에서 추출. |
| 삭제 | `_client.from('care_records').delete().eq('id', recordId).select()`. 영향 행 수가 0 이면 `notFound` 로 변환. |

### 12.3 cursor 직렬화

cursor 는 호출자가 내부를 들여다볼 필요 없는 `String` 이지만, 실제로는 마지막 행의 `id` (UUID 문자열) 그대로다. 다음 페이지 쿼리는:

```
.lt('id', cursor).order('occurred_at', desc).order('id', desc)
```

> 같은 `occurred_at` 을 가진 행이 페이지 경계에 걸칠 때 누락 / 중복 가능성은 매우 낮지만 0 은 아니다 (§3.4 cursor lifetime 참조). UUID v4 는 시간 정보를 담지 않으므로 정렬 키와 cursor 의 의미가 완벽히 일치하지는 않는다. 본 spec 의 결정 (단순한 id cursor) 하에서 감수하는 트레이드오프.

### 12.4 DB 약속 (마이그레이션 PR 의 책임)

본 PR 의 코드가 정상 동작하려면 다음 DB 변경이 선행되어야 한다 (별도 마이그레이션 PR).

| 변경 | 용도 |
|---|---|
| `care_records.occurred_at` generated column — `detail->>'occurred_at'` 또는 `detail->>'started_at'` 으로부터 파생 | 정렬 / 인덱스 활용. |
| `care_records.ended_at` generated column — `detail->>'ended_at'` 으로부터 파생 (구간 이벤트만 non-null) | 기상 정렬 / 인덱스 활용. |
| `care_records.feeding_effective_at` generated column — `breast → ended_at`, `formula/pumping/pumpingFeed/babyFood → occurred_at`, 그 외 null | 수유 4종을 단일 정렬 키로 처리. |
| `(baby_id, occurred_at desc, id desc)` 인덱스 | 페이지 단위 리스트 조회 최적화. |
| 위 두 generated column 에 대한 `(baby_id, col desc, id desc) where col is not null` partial 인덱스 | 최근 N건 조회 최적화. |
| `babies.created_at` 존재 | 목록 정렬 기준. |
| `babies.gender`, `babies.birth_date`, `babies.due_date` 컬럼 | 단일 아기 조회. |

---

## 13. 매핑 함수

Service 내부의 순수 함수로 구현한다.

| 함수 | 동작 |
|---|---|
| `_mapBabyListItem(row) → BabyListItem` | `id`, `name`. |
| `_mapBaby(row) → Baby` | `id`, `name`, `birth_date` (parse → UTC), `due_date` (parse → UTC), `gender` (enum). `created_at` 은 도메인 모델에 없으므로 매핑하지 않음. |
| `_mapRecord(row) → CareRecord` | `id`, `baby_id`, `created_by`, `created_at` (parse → UTC), `detail` 의 5 개를 채운다. `detail` 은 `row['type']` 으로 RecordType 을 enum 변환 (모르는 값이면 `parseFailed`) 한 뒤 `RecordDetailData.fromJson(type, jsonb)` 로 하위 클래스를 분기해 생성. 생성된 `detail` 이 type 정보를 보유하므로 CareRecord 에는 별도로 넘기지 않는다. |

파싱 실패 / enum lookup 실패는 catch 하여 `AppException(parseFailed)` 로 변환.

---

## 14. DI 등록

`lib/core/config/dependencies.dart` 에 추가:

```dart
// main.dart 에서:
//   final prefs = await SharedPreferences.getInstance();
//   runApp(MultiProvider(providers: buildDependencies(prefs: prefs), ...));

Provider<SharedPreferences>(create: (_) => prefs),
Provider<AppLocalStorage>(
  create: (context) => AppLocalStorage(context.read<SharedPreferences>()),
),
ChangeNotifierProvider<CurrentBabyController>(
  create: (context) => CurrentBabyController(context.read<AppLocalStorage>()),
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

`SharedPreferences` 인스턴스를 동기 주입할 수 있도록 `main.dart` 의 부트스트랩에서 await 후 전달한다. `AppLocalStorage` 는 일반 `Provider`, `CurrentBabyController` 는 `ChangeNotifierProvider` 로 등록한다.

---

## 15. 테스트 방식

### 15.1 도메인 단위 테스트

- `RecordDetailData` 각 하위 클래스별 `toJson` / `fromJson` 왕복 (round-trip) 테스트. "단순 값 객체가 자기 직렬화를 직접 가진다" 규칙 검증.
- 각 `RecordDetailData` 하위 클래스의 `type` getter 가 자기 `RecordType` 값을 반환하는지 (예: `BreastDetail().type == RecordType.breast`).
- 구간 이벤트 (BreastDetail / SleepDetail) 의 `startedAt < endedAt` assert.
- `Baby.name` 등 필수 string 필드에 앞뒤 공백만 들어왔을 때 assert 가 터지는지 확인.
- 모델의 `==` / `hashCode` 가 id 기반인지.
- `Baby` 의 D-day / D+N 같은 계산 로직은 본 PR 의 도메인에 두지 않으므로 (Presentation 책임) 단위 테스트 대상 아님.

### 15.2 Repository 단위 테스트 — Service 를 mockito 로 mock

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
| 〃 | limit 경계 | limit=0, limit=101 → ArgumentError |
| `RecordRepository.getRecentFeedings` | 정상 | Service 가 `{breast, formula, pumping, pumpingFeed, babyFood}` + 수유 합성 키로 호출됨 |
| 〃 | 1건만 | 길이 1 그대로 |
| 〃 | 빈 결과 | `Result.ok([])` |
| 〃 | limit 경계 | limit=0, limit=11 → ArgumentError |
| `RecordRepository.getRecentDiapers` | 정상 | `{diaper}` + `occurredAt` |
| `RecordRepository.getRecentWakes` | 정상 | `{sleep}` + `endedAt` |
| `RecordRepository.createRecord` | 정상 | Service 가 `babyId, detail` 로 호출됨 (type 은 detail 의 하위 클래스에서 끌어냄). userId 는 호출자가 전달하지 않음 |
| 〃 | 에러 | passthrough |
| `RecordRepository.deleteRecord` | 정상 | Service 호출 후 `Result.ok(null)` |
| 〃 | 미존재 (notFound) | Service `Result.error(notFound)` passthrough |
| 〃 | 기타 에러 | passthrough |

### 15.3 Service 테스트

Supabase SDK 의존성으로 Service 단위 테스트는 본 PR 에서 강제하지 않는다. 단, 매핑 함수 (`_mapBabyListItem`, `_mapBaby`, `_mapRecord`) 가 헬퍼로 분리 가능하면 순수 함수 테스트 추가 권장:

- `_mapBabyListItem`: id / name 보존.
- `_mapBaby`: `birth_date` / `due_date` null / non-null 케이스, gender enum 매핑.
- `_mapRecord` round-trip: 각 `RecordType` 에 대해 row → CareRecord → row 의 핵심 필드 보존. 미지 type 값 → `parseFailed`.

### 15.4 AppLocalStorage / CurrentBabyController 테스트

#### AppLocalStorage 테스트

`SharedPreferences.setMockInitialValues({...})` 활용한 메모리상 동작 검증.

| 시나리오 | 검증 |
|---|---|
| 초기 상태 (mock 값 없음) | `selectedBabyId == null` |
| `setSelectedBabyId('a')` 후 getter | `selectedBabyId == 'a'` |
| `setSelectedBabyId('a')` → `setSelectedBabyId('b')` | `selectedBabyId == 'b'` |
| `removeSelectedBabyId()` 후 getter | `selectedBabyId == null` |

> Storage 는 `ChangeNotifier` 가 아니므로 listener notification 검증은 **하지 않는다**.

#### CurrentBabyController 테스트

`AppLocalStorage` 를 mockito 로 mock 하여 메모리 / notify 동작 검증.

| 시나리오 | 검증 |
|---|---|
| 초기 상태 (Storage 가 `null` 반환) | `selectedBabyId == null` |
| 초기 상태 (Storage 가 `'a'` 반환 — 부팅 시 복원) | `selectedBabyId == 'a'` |
| `select('b')` | `Storage.setSelectedBabyId('b')` 1회 호출 + `selectedBabyId == 'b'` + listener 1회 notified |
| 재호출 `select('c')` | `Storage.setSelectedBabyId('c')` 1회 호출 + `selectedBabyId == 'c'` + listener 1회 notified |
| `clear()` | `Storage.removeSelectedBabyId()` 1회 호출 + `selectedBabyId == null` + listener 1회 notified |

---

## 16. 파일 추가 / 수정 예상 목록

**신규 도메인 모델**
- `lib/domain/models/baby/baby_list_item.dart`
- `lib/domain/models/baby/baby.dart`

(기존 모델 — 본 PR 에서 수정 / 보완 가능)
- `lib/domain/models/record/care_record.dart` — `type` 필드 제거 (`detail.type` 으로 위임), `==` / `hashCode` 추가
- `lib/domain/models/record/record_detail_data.dart` — `RecordType get type` 추상 getter 추가 + 각 하위 클래스 override, `BabyFoodDetail.name` / `SnackDetail.name` nullable 화, 구간 이벤트의 `startedAt < endedAt` assert
- `lib/domain/models/common/page.dart` — 추가 사항 없음 (이미 제네릭 `Page<T>` + String? cursor 형태로 구현되어 있음)

**신규 Repository / Service**
- `lib/data/repositories/baby_repository/baby_repository.dart`
- `lib/data/repositories/baby_repository/baby_repository_impl.dart`
- `lib/data/services/baby_service/baby_service.dart`
- `lib/data/services/baby_service/supabase_baby_service.dart`
- `lib/data/repositories/record_repository/record_repository.dart` — 본 spec 의 6.5 ~ 6.10 메서드를 노출 (현재 `record_repository_impl.dart` 의 메서드와 정합 확인 필요)
- `lib/data/services/record_service/record_service.dart` — 본 spec 의 7.3 메서드 추가
- (record_repository_impl, supabase_record_service 의 기존 메서드는 별도 spec 의 책임)

**신규 로컬 저장소 / application state**
- `lib/data/local/app_local_storage.dart` — KV wrapper. `ChangeNotifier` 아님.
- `lib/presentation/common/current_baby_controller.dart` — application-scope `ChangeNotifier`.

**수정**
- `lib/core/config/dependencies.dart` — `SharedPreferences` / `AppLocalStorage` / `CurrentBabyController` / Baby* / Record* 등록
- `lib/main.dart` — `SharedPreferences.getInstance()` await 후 DI 주입

**테스트**
- `test/domain/models/care_record/care_record_test.dart` (== / hashCode 는 id 기반, `record.detail.type` 으로 카테고리 노출)
- `test/domain/models/care_record/record_detail_data_test.dart` (직렬화 왕복, 각 하위 클래스의 `type` getter, 구간 이벤트 시각 순서)
- `test/data/repositories/baby_repository/baby_repository_impl_test.dart`
- `test/data/repositories/record_repository/record_repository_impl_test.dart`
- `test/data/local/app_local_storage_test.dart`
- `test/presentation/common/current_baby_controller_test.dart`

**`pubspec.yaml`**
- `shared_preferences` 추가
