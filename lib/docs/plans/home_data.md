# Implementation Plan: 홈 화면 데이터 레이어 (Home Screen Data Layer)

> 본 문서는 [spec](../specs/home_data.md)의 요구사항을 본 프로젝트의 기술 스택으로 구현하는 방법을 정의한다. spec 의 어떤 요구사항도 여기의 특정 라이브러리 / 컬럼명 / 쿼리에 의존하지 않으며, spec 을 깨지 않는 범위에서 이 plan 은 자유롭게 바뀔 수 있다.

## Summary

- 홈 화면이 필요로 하는 데이터를 현재 선택된 아기에 대해 도메인 모델 + `Result<T>` 형태로 제공하는 데이터 레이어.
- 두 Repository(`BabyRepository`, `RecordRepository`)와 그 하부 Service, 그리고 선택된 아기 상태를 다루는 두 컴포넌트(`AppLocalStorage`, `CurrentBabyController`)로 구성한다.
- 원격 백엔드는 Supabase(Auth + PostgREST + RLS), 로컬 KV 저장소는 `shared_preferences`, DI 는 `provider` 를 쓴다. "현재 선택된 아기" 전파는 broadcast `StreamController` 로 한다.
- ViewModel 에는 Repository 와 `CurrentBabyController`, 그리고 도메인 모델 + `Result<T>` 만 노출한다. Service / 백엔드 클라이언트 / 로컬 저장소는 노출하지 않는다.

## Technical Context

- **Language/Version**: Dart (Flutter), strict typing
- **Primary Dependencies**: 프로젝트 공통 모듈(`Result<T>` sealed `Ok`/`Error`, `AppException`/`ErrorCode`), 인증 컨텍스트, Provider 기반 DI
- **Data Source**: Supabase(Auth + PostgREST + RLS) — 권한은 RLS 가 강제
- **Storage**: 로컬 KV 는 `shared_preferences`(단일 key `selectedBabyId`). 기록/아기 데이터의 클라이언트 측 캐시는 본 PR 범위 아님
- **Testing**: `flutter_test` + `mockito` — Repository impl 단위 테스트(Service mock 으로 성공/실패 분기 검증), 도메인 값 객체 불변식·직렬화 round-trip 테스트, `shared_preferences` mock 으로 로컬 저장소·상태 홀더 검증
- **Target Platform**: 모바일 앱(기존 앱과 동일)
- **Project Type**: Mobile app — `lib/data` / `lib/domain` / `lib/presentation/common` 레이어
- **Constraints**: 도메인 모델 경계 밖으로 DTO / `Map` / raw 응답 노출 금지, 모델 시각은 UTC, 데이터 레이어는 무상태(선택 상태 홀더의 메모리 보관은 예외)
- **Scale/Scope**: Repository 2, Service 2, 로컬 저장소 1, 상태 홀더 1, 도메인 모델군(`BabyListItem` / `Baby` / `CareRecord` / `RecordDetailData` 변종 9종 / `Page<T>`), 조회·명령 메서드 다수

## Constitution Check

*GATE: 설계 전후로 점검한다. 본 프로젝트는 별도 constitution 문서를 두지 않으므로 아래 원칙을 인라인 기준으로 삼는다.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | **레이어 경계** — 데이터 흐름은 `ViewModel → Repository → Service → 데이터 소스` 단방향. ViewModel 은 Repository(+상태 홀더)에만 의존하고, 경계 밖으로는 도메인 모델 + `Result<T>` 만 나간다. | ✅ PASS | ViewModel 은 `BabyRepository`/`RecordRepository`/`CurrentBabyController` 만 의존. Service / Supabase 클라이언트 / `AppLocalStorage` / `shared_preferences` 비노출. DTO/`Map`/raw 응답이 경계를 넘지 않음. |
| II | **도메인 모델 정책(Immutable, UTC)** — 모든 필드 `final`, 변경은 `copyWith`, 모델의 모든 `DateTime` 은 UTC, 동일성은 `id` 기반. | ✅ PASS | 모든 도메인 모델 immutable, `==`/`hashCode` 는 `id` 기반, 시각 필드 UTC. D-day/D+N 등 계산은 표시 계층. |
| III | **오류 처리(`Result<T>` + `AppException`)** — 메서드는 throw 하지 않고 `Result<T>` 반환, 외부 실패는 `AppException(code)` 로 변환. `notFound` 는 행 없음 + 권한 차단을 모두 포함. | ✅ PASS | 모든 Repository/Service 메서드 `Result<T>` 반환. `notFound`/`unauthorized`/`networkError`/`parseFailed` 로 구분. stale 선택 식별자는 `notFound` 한 코드로 받음. |
| IV | **비즈니스 규칙 SSOT** — "무엇이 올바른가"(정렬 기준, 빈/오류 처리, 기준 시각)의 정의는 spec 이 단일 진실 공급원이고 테스트로 검증된다. | ✅ PASS | 정렬·기준 시각·빈/오류 규칙은 spec(FR)이 SSOT. 구현은 그 계약을 검증(Acceptance Criteria 참조). |
| V | **단순성 & 책임 분리** — 표시용 가공(라벨·마스킹·합산·D-day)은 데이터 레이어가 하지 않는다. 로컬 저장소 래퍼는 변경 통지/유효성 검증을 하지 않는다. | ✅ PASS | 표시 가공은 Presentation. `AppLocalStorage` 는 통지/검증 없는 KV 래퍼, `CurrentBabyController` 가 통지 담당. 캐시는 두지 않음. |
| VI | **테스트 가능성** — 모델 불변식·매핑·조회 분기를 단위 테스트로 검증하고, 데이터 부재를 정상 상태로 고정한다. | ✅ PASS | Service mock 으로 Repository 분기, `shared_preferences` mock 으로 저장소/상태 홀더, 값 객체 직렬화 round-trip 검증. 빈 데이터는 성공으로 고정. |

**Gate Result**: PASS. 정당화가 필요한 설계 선택은 [Complexity Tracking](#complexity-tracking) 참조.

## Project Structure

### Documentation

```text
lib/docs/
├── specs/
│   └── home_data.md     # 홈 화면 데이터 레이어 spec (계약/요구사항)
└── plans/
    └── home_data.md     # 이 문서 (데이터 레이어 plan)
```

### Source Code (repository root)

```text
lib/
├── domain/
│   └── models/
│       ├── baby/
│       │   ├── baby_list_item.dart   # 목록용 가벼운 모델 (id, name)
│       │   └── baby.dart             # 기본 정보 모델 (id, name, birthDate?, dueDate?, gender)
│       ├── record/
│       │   ├── care_record.dart      # 공통 헤더 + detail (기존 모델, 본 PR 에서 보완)
│       │   └── record_detail_data.dart  # sealed 변종 9종 (기존 모델, 본 PR 에서 보완)
│       └── common/
│           └── page.dart             # 제네릭 Page<T> (이미 구현됨)
├── data/
│   ├── local/
│   │   └── app_local_storage.dart    # KV 래퍼 (ChangeNotifier 아님)
│   ├── repositories/
│   │   ├── baby_repository/
│   │   │   ├── baby_repository.dart
│   │   │   └── baby_repository_impl.dart
│   │   └── record_repository/
│   │       ├── record_repository.dart
│   │       └── record_repository_impl.dart
│   └── services/
│       ├── baby_service/
│       │   ├── baby_service.dart
│       │   └── supabase_baby_service.dart
│       └── record_service/
│           ├── record_service.dart
│           └── supabase_record_service.dart
├── presentation/
│   └── common/
│       └── current_baby_controller.dart  # application-scope state holder (broadcast StreamController)
└── core/
    └── config/
        └── dependencies.dart         # DI 등록 (수정)
```

**Structure Decision**: 도메인 모델은 기존 `lib/domain/models/` 관행을 따른다. Repository/Service 는 `<name>_repository` / `<name>_service` 인터페이스 + impl 패턴을 쓰고 백엔드 구현체는 `supabase_*` 접두사를 쓴다(기존 `supabase_record_service` 와 동일). 로컬 저장소는 `lib/data/local/`, application-scope 상태 홀더는 `lib/presentation/common/` 에 둔다.

## 레이어 구조

```text
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

- ViewModel 은 **Repository** 와 **`CurrentBabyController`** 만 의존한다(Constitution I). ViewModel 은 `currentBabyController.selectedBabyId` 를 읽어 Repository 호출에 `babyId` 로 전달한다.
- "저장된 ID 가 현재 사용자에게 실제 접근 가능한가" 의 검증 책임은 **`BabyRepository.getBaby` 의 결과**(`notFound`)가 진다. ViewModel 은 결과 오류 코드로 fallback 을 결정하며, 도메인 판정 로직을 두지 않는다.

## 도메인 모델

> 모든 도메인 모델은 Constitution II 의 정책을 따른다: 모든 필드 `final`, 변경은 `copyWith`, `==`/`hashCode` 는 `id` 기반(같은 아기/같은 기록은 조회 시점이 달라 필드 값이 달라도 같은 객체), 모든 `DateTime` 은 UTC. nullable 로 명시되지 않은 String 필드는 앞뒤 공백 제거 후 비어 있지 않다(최대 길이는 백엔드/DB CHECK 가 강제). enum 의 SSOT 는 백엔드이며 모르는 값은 그 행을 `parseFailed` 로 거부한다.

### 아기 모델 — 두 형태

각 쿼리가 필요로 하는 데이터 폭이 달라 모델을 분리한다.

| 모델 | 필드 | 용도 |
|---|---|---|
| `BabyListItem` | `id`, `name` | "선택 후보 목록" 표시 — 어떤 아기로 전환할지 고르는 화면. |
| `Baby` | `id`, `name`, `birthDate`(nullable), `dueDate`(nullable), `gender` | "현재 선택된 아기 기본 정보" — 홈 상단 이름 / D-day / D+N 계산의 원본. |

- `BabyListItem.id` 와 `Baby.id` 는 같은 종류의 id 다. 같은 `id` 는 같은 아기를 가리킨다.
- 같은 아기의 `BabyListItem.name` 과 `Baby.name` 은 같은 시점의 행에서 온 값이면 같다. 두 모델 조회 시점이 다르면 그 사이 이름이 바뀌었을 수 있다 — 최신 값이 필요하면 다시 조회한다.
- `birthDate`/`dueDate` 는 둘 다 null 가능(출생 전/입양 등). 두 값의 순서 관계는 본 plan 이 다루지 않는다(입력 화면 UX 책임). D-day/D+N 등 표시 문자열은 표시 계층이 계산한다.

### 기록 모델

#### `CareRecord` — 공통 헤더 + 세부 데이터

| 필드 | 타입 | 비고 |
|---|---|---|
| `id` | String | 시스템 전체에서 유일. 백엔드가 부여. |
| `babyId` | String | `Baby.id` / `BabyListItem.id` 와 같은 종류의 id. |
| `createdBy` | String | 기록을 생성한 사용자 ID. |
| `createdAt` | DateTime(UTC) | 백엔드가 부여. |
| `detail` | `RecordDetailData` | sealed. 타입별 세부 데이터 + **기록 종류(type) + 사건 시각** 을 모두 보유. |

- **type 의 SSOT**: `CareRecord` 에 `type` 필드를 두지 않는다. 기록 종류는 `detail` 의 실제 하위 클래스가 곧 표현이며, 호출자는 `record.detail.type` 으로 접근한다(편의 위임 getter `RecordType get type => detail.type` 은 선택). 같은 정보가 두 곳에 저장되지 않아 짝이 어긋날 수 없다.
- **사건 시각의 SSOT**: 사건 시각은 `detail.occurredAt` 한 곳에서만 관리한다.
- **값 변경**: 의미 있는 부분 변경은 `detail` 교체뿐(`copyWith(detail: ...)`). 나머지 필드는 한 번 정해지면 바뀌지 않는다.

#### `RecordType` — 6종

| 값 | 의미 | 구간 이벤트 |
|---|---|---|
| `feeding` | 수유 (세부는 `FeedingType`) | 모유수유만 ✅ (시작+종료) |
| `pumping` | 유축 | |
| `sleep` | 수면 | ✅ (시작+종료) |
| `diaper` | 기저귀 | |
| `snack` | 간식 | |
| `water` | 물 | |

`feeding` 은 단일 카테고리이고 세부 종류는 `FeedingType` 으로 구분한다. **유축(`pumping`)은 수유가 아니다** — feeding 과 별개 카테고리.

#### `FeedingType` — 4종 (feeding 내부 세부 종류)

| 값 | 의미 | 구간 이벤트 |
|---|---|---|
| `breast` | 모유 수유 | ✅ (시작+종료) |
| `formula` | 분유 | |
| `pumpingFeed` | 유축한 모유를 먹임 | |
| `babyFood` | 이유식 | |

#### `RecordDetailData` (sealed)

타입별 세부 데이터. **각 하위 클래스가 자기 직렬화(`toJson`/`fromJson`)를 직접 보유**한다(필드만 가진 단순 값 객체라 데이터 소스에 의존하지 않음 — leaf value object 의 직렬화는 모델이 소유).

계층:

```text
RecordDetailData (sealed)
├─ FeedingDetail (sealed)            type = RecordType.feeding
│   ├─ BreastDetail                  feedingType = breast      (구간)
│   ├─ FormulaDetail                 feedingType = formula
│   ├─ PumpingFeedDetail             feedingType = pumpingFeed
│   └─ BabyFoodDetail                feedingType = babyFood
├─ PumpingDetail                     type = RecordType.pumping
├─ SleepDetail                       type = RecordType.sleep   (구간)
├─ DiaperDetail                      type = RecordType.diaper
├─ SnackDetail                       type = RecordType.snack
└─ WaterDetail                       type = RecordType.water
```

**공통 약속**:
- `RecordType get type` 추상 getter — 각 하위 클래스가 자기 종류를 override. feeding 4종은 sealed `FeedingDetail` 이 공통으로 `type => RecordType.feeding` 을 노출한다. 기록 종류의 SSOT.
- sealed `FeedingDetail` 은 `FeedingType get feedingType` 추상 getter 를 추가로 노출(feeding 내부 종류의 SSOT). 이 sealed 중간 클래스 덕분에 "feeding 멤버는 이 4개뿐" 이 타입 수준에서 강제된다.
- feeding leaf 의 `toJson` 은 `feeding_type` 을 함께 직렬화하고, 역직렬화는 `FeedingDetail.fromJson` 이 `feeding_type` 으로 leaf 를 분기한다(모르는 값은 `parseFailed`).
- `DateTime get occurredAt` 추상 getter — "정렬·표시 기준 시각"(UTC). 구간 이벤트는 `startedAt` 과 같은 값.
- 구간 이벤트는 `startedAt`, `endedAt` 을 모두 가지며 **항상 `startedAt < endedAt`**(반대 구간은 도메인 단에서 거부). 구간 이벤트의 `endedAt` 은 **null 불가** — "진행 중" 상태는 데이터로 존재하지 않는다(스톱워치는 메모리 상태일 뿐, 종료 확정 시에만 모델이 생성).

**변종별 필드 / 단위 / nullable 의미** (feeding 4종은 `FeedingDetail` 하위):

| 변종 | 그룹 | 필드 | 단위 / 의미 |
|---|---|---|---|
| `BreastDetail` | feeding | `startedAt`, `endedAt`, `leftMinutes`(int?), `rightMinutes`(int?) | 분. `null`=해당 쪽 수유 안 함. `0`=시도했으나 0분. occurredAt = startedAt. |
| `FormulaDetail` | feeding | `occurredAt`, `amountMl`(int) | ml. 필수. |
| `PumpingFeedDetail` | feeding | `occurredAt`, `amountMl`(int) | ml. 필수. |
| `BabyFoodDetail` | feeding | `occurredAt`, `name`(String?), `amountMl`(int) | name nullable(메뉴 미기입 허용). amountMl 필수. |
| `PumpingDetail` | — | `occurredAt`, `leftAmountMl`(int?), `rightAmountMl`(int?) | ml. `null`=해당 쪽 유축 안 함. `0`=유축했으나 0ml. |
| `SleepDetail` | — | `startedAt`, `endedAt`, `sleepType`(`SleepType`) | sleepType ∈ {nap, night}. occurredAt = startedAt. |
| `DiaperDetail` | — | `occurredAt`, `diaperType`(`DiaperType`) | diaperType ∈ {pee, poop, mixed}. |
| `SnackDetail` | — | `occurredAt`, `name`(String?) | name nullable. |
| `WaterDetail` | — | `occurredAt`, `amountMl`(int) | ml. 필수. |

### 페이지네이션 모델 — `Page<T>`

| 필드 | 타입 | 용도 |
|---|---|---|
| `items` | `List<T>` | 페이지 항목(모두 같은 타입 T). 크기 ≤ `limit`. |
| `nextCursor` | String? | 다음 페이지 요청에 그대로 넘기는 불투명 문자열. 없으면 `null`. |
| `hasMore` | bool | 다음 페이지 존재 여부. |

- Cursor 는 호출자가 내부를 해석할 필요 없는 문자열이며, 받은 그대로 다시 넘긴다. 내부적으로는 "마지막으로 반환된 항목의 `id`" 기반이다(구체 인코딩은 [Service 구현](#service-구현-supabase) 참조).
- **`hasMore == true` 와 `nextCursor != null` 은 같은 의미**다. cursor 의 유효기간이나 다른 아기의 cursor 재사용 동작은 정의하지 않는다("의도된 사용 흐름 안에서만 동작 보장").

## AppLocalStorage

**역할**: 앱의 단순 KV 로컬 저장소 래퍼. 본 PR 에서는 `selectedBabyId` 한 키를 다루지만, 향후 다른 키도 같은 패턴으로 추가할 수 있는 일반 wrapper. 백엔드(`shared_preferences`)를 래핑하고 호출자에게는 키마다 도메인 의미를 가진 typed 인터페이스를 노출한다.

### 노출 인터페이스

| 멤버 | 동작 |
|---|---|
| `String? get selectedBabyId` | 저장된 값을 **동기** 로 반환. 없으면 `null`. |
| `Future<void> setSelectedBabyId(String babyId)` | 값을 로컬에 저장. |
| `Future<void> removeSelectedBabyId()` | 키를 로컬 저장소에서 제거. |

### 책임의 경계 (하지 않는 일)

- **변경 통지하지 않는다**(Constitution V). 값을 set 해도 listener 를 호출하지 않는다.
- **저장된 ID 의 의미/권한/유효성을 검증하지 않는다.** "접근 가능한 baby 인지" 는 `BabyRepository.getBaby` 의 결과로 알 일이다.
- 로그아웃 자체는 Storage 책임이 아니다. `CurrentBabyController.clear()` 가 내부적으로 `removeSelectedBabyId()` 를 호출하는 형태로만 간접 관여한다.

### 구현 메모

- 일반 클래스(ChangeNotifier 아님). 생성자에서 `SharedPreferences` 를 주입받으며 별도 `init()` 부트스트랩 메서드는 두지 않는다.
- `selectedBabyId` getter 는 동기(`SharedPreferences.getString` 이 동기 API). set/remove 는 `shared_preferences` 의 `Future` 를 그대로 반환.
- key 문자열은 클래스 내부 private const 로 두어 외부에 노출하지 않는다.
- `shared_preferences` 의 read/write 실패는 본 PR 에서 별도로 catch 하지 않는다(플랫폼 의존, 실제 실패 드묾).
- 인스턴스는 DI 에 단 하나 등록(앱 전체 공유).

### 향후 키 추가 패턴

새 로컬 키가 필요하면 같은 wrapper 에 (1) key 문자열 private const, (2) 도메인 의미를 가진 typed getter, (3) 영속화 setter, (4) 필요 시 remove 를 추가한다. 별도 도메인별 `Store` 클래스를 만들지 않는다. 변경 전파가 필요한 reactive 값은 wrapper 가 아니라 application-scope state holder(`CurrentBabyController` 처럼 broadcast `StreamController` 를 가진 클래스)가 담당한다.

## CurrentBabyController

**역할**: 앱 전체에서 공유되는 "현재 선택된 아기" 의 application-scope state holder. 메모리에 `selectedBabyId` 를 보관하고 변경을 **broadcast stream** 으로 여러 구독자(ViewModel)에게 전파한다. `AppLocalStorage` 를 의존해 부팅 시 마지막 값을 복원하고 변경 시 영속화한다. `ChangeNotifier` 가 아니라 내부에 `StreamController<String?>.broadcast()` 를 보유하는 일반 클래스다.

### 노출 인터페이스

| 멤버 | 동작 |
|---|---|
| `String? get selectedBabyId` | 메모리에 보관 중인 현재 baby ID(동기). 없으면 `null`. 구독 시점의 현재값을 읽는 용도. |
| `Stream<String?> get selectedBabyIdStream` | 선택 변경을 broadcast 하는 stream. broadcast 라 늦게 구독한 listener 에게 마지막 값을 재전송하지 않으므로, 구독자는 `selectedBabyId` 로 현재값을 먼저 읽고 stream 으로 이후 변화를 받는다. |
| `Future<void> select(String babyId)` | 메모리 값 갱신 → `AppLocalStorage.setSelectedBabyId` 로 영속화 → stream 에 새 ID `add`. |
| `Future<void> clear()` | 메모리 값을 `null` 로 → `AppLocalStorage.removeSelectedBabyId` → stream 에 `null` `add`. |
| `void dispose()` | 내부 `StreamController` 를 닫는다(DI 가 인스턴스 폐기 시 호출). |

### 책임의 경계 (하지 않는 일)

- **저장된 ID 의 유효성/권한을 검증하지 않는다.** 그 판단은 호출자가 `BabyRepository.getBaby` 결과의 `notFound` 로 받는다.
- "저장된 ID 가 stale 이면 첫 baby 로 fallback" 같은 정책은 ViewModel 의 결과 분기로 처리한다. Controller 는 ViewModel 이 결정한 새 ID 를 `select(...)` 로 받기만 한다.
- 로그아웃 자체는 Controller 책임이 아니다. `AuthRepository.signOut()` 성공 후 호출자가 명시적으로 `clear()` 를 호출한다(Controller 가 AuthRepository 를 구독하지 않음 — 의존성 방향 단순화).

### 구현 메모

- ViewModel 은 init 시 `selectedBabyId` 로 현재값을 읽고 `selectedBabyIdStream.listen(...)` 으로 이후 변화를 구독한다. 구독 해지는 ViewModel 의 `dispose` 에서 한다.
- 생성자에서 `AppLocalStorage` 를 주입받고, `_selectedBabyId = appLocalStorage.selectedBabyId` 로 메모리 변수를 **동기 초기화**(Storage getter 가 동기이므로 가능). 별도 `init()` 부트스트랩은 두지 않는다.
- 내부 `StreamController` 는 `broadcast()` 로 만들어 여러 ViewModel 이 동시에 구독할 수 있게 한다. DI 가 인스턴스를 폐기할 때 `dispose()` 로 controller 를 닫는다.
- `AppLocalStorage` 의 set/remove 실패는 본 PR 에서 별도로 catch 하지 않는다.
- 본 앱은 한 디바이스에 한 사용자만 로그인된다고 가정한다. 사용자 변경은 "로그아웃 → 다른 계정 로그인" 이며 그 과정에서 `clear()` 로 이전 선택이 비워진다.
- 인스턴스는 DI 에 단 하나 등록(앱 전체 공유).

## BabyRepository

**역할**: 홈 화면이 "어떤 아기를 보여줄 것인가" 를 결정할 **선택 후보 목록** 과, "현재 선택된 아기" 의 **기본 정보** 를 도메인 모델 + `Result<T>` 로 제공한다. ViewModel 이 유일하게 의존하는 진입점이며 Service 를 협력자로 호출한다.

### 책임

- 현재 인증 사용자가 보호자로 등록된 아기 목록 제공("보호자" 권한 정의는 백엔드 책임, 도메인 단에서는 "조회 결과 = 볼 수 있는 아기").
- 특정 아기 ID 의 기본 정보 제공.
- 화면 표시용 가공(라벨/마스킹/D-day/D+N)은 하지 않는다(Constitution V).
- 자체 상태(캐시/큐/lock)를 갖지 않아 동시 호출에 안전하다.

### 호출자

- `HomeViewModel` — 홈 진입 시 목록 + 기본 정보 조회, 보호자 관계 변경 후 목록 재조회, 아기 전환 시 새 선택 아기의 기본 정보 재조회.

### 주요 결정

- `userId` 를 인자로 받지 않는다("현재 사용자" 는 인증 컨텍스트로 자동 판단 — 잘못된 userId 주입 차단).
- **목록과 기본 정보 조회를 분리**한다. 필요 데이터 폭이 다르고(목록 2필드 / 기본 정보 5필드) 무효화 시점도 다르다(목록: 보호자 관계 변경, 기본 정보: 아기 전환/프로필 수정).

### 메서드: 접근 가능한 아기 목록 조회

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈에서 "어떤 아기를 볼 것인가" 후보 목록 제공. |
| 입력 | 없음. |
| 호출 시점 | 홈 진입 시 1회. 보호자 관계 변경(추가/탈퇴/초대 수락) 후 재조회. |
| 결과 데이터 | `List<BabyListItem>`(각 `id`, `name`). |
| 결과 정렬 | 생성일 내림차순(spec FR-002). |
| 빈 데이터 | **빈 리스트는 에러로 표현**(`AppException(notFound)`). 홈 진입에는 아기가 최소 1명 필요하므로 빈 리스트는 호출자가 다른 동작(등록 화면 이동 등)을 취해야 하는 신호(spec FR-003). |
| 실패 케이스 | 네트워크/호출 실패, 인증 만료/미로그인, 파싱 실패 모두 `Result.error(AppException)`. |
| null 처리 | 결과 리스트와 각 항목의 두 필드 모두 non-null. |

### 메서드: 단일 아기 기본 정보 조회

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 상단 이름 / D+N / D-day 계산의 원본 제공. |
| 입력 | `babyId`(필수). 호출자가 `CurrentBabyController.selectedBabyId` 값을 그대로 전달. |
| 호출 시점 | 홈 진입 시(선택 아기 결정 직후), 아기 전환 시, 본인이 프로필 수정 직후. |
| 결과 데이터 | `Baby`(`id`, `name`, `birthDate?`, `dueDate?`, `gender`). |
| 빈 데이터 / 미존재 | 행 없음 또는 권한 없음이면 `Result.error(AppException(notFound))`. 호출자가 후속 동작(목록 재조회 + 다른 아기 선택)을 취해야 하는 신호. |
| `notFound` 정의 | "해당 `babyId` 의 baby 가 현재 사용자에게 보이지 않음" — 행 미존재와 RLS/권한 차단을 **둘 다 포함**. 호출자는 이를 "저장된 selectedBabyId 가 stale 이므로 fallback" 신호로 쓴다. stale 전용 코드는 두지 않는다(spec FR-005). |
| 실패 케이스 | `notFound`, `unauthorized`, `networkError`, `parseFailed` 모두 `Result.error(AppException)`. |
| null 처리 | `birthDate`/`dueDate` 각각 독립 null 가능. 둘 다 null 도 정상. |

## RecordRepository

**역할**: 현재 선택된 아기에 대해 홈이 보여줘야 하는 **모든 기록 데이터** 를 제공하고, 사용자의 기록 생성/삭제 의도를 영속화한다.

### 책임

- 기록 리스트 페이지 단위 조회(무한 스크롤 지원).
- 카테고리별 최근 요약(수유/기저귀/기상 최근 N건).
- 기록 생성(모든 타입) 및 삭제.
- 결과를 도메인 모델 + `Result<T>` 로 제공.

### 호출자

- `HomeViewModel`.

### 주요 결정

- 모든 메서드는 `babyId` 를 인자로 받는다("현재 선택된 아기" 판정은 호출자 책임).
- 기록 생성 시 `userId` 를 전달하지 않는다(`createdBy` 는 인증 컨텍스트에서 자동).
- 정렬 기준은 카테고리에 따라 다를 수 있다(아래 메서드별 참조). 이 차이는 Repository 가 노출하는 **계약**이며, 호출자는 규칙을 몰라도 결과 순서를 신뢰할 수 있다(spec FR-016).
- 본 PR 에서는 기록을 캐싱하지 않는다. 생성/삭제 후 ViewModel 이 메모리상 리스트를 직접 정합화한다.
- **최소 1회 보장(재시도 시 중복 가능)**: `createRecord` 는 네트워크 실패 등으로 재시도되면 중복 기록이 생길 수 있다. Repository/백엔드 모두 중복 방지 키를 다루지 않으며, 중복 호출 방지는 호출자(UX)의 책임(spec FR-022).
- 자체 상태를 갖지 않아 동시 호출에 안전하다.

### 메서드: 기록 리스트 조회 (페이지 단위)

| 항목 | 요구사항 |
|---|---|
| 목적 | 홈 무한 스크롤 리스트를 페이지 단위로 제공. |
| 입력 | `babyId`(필수), `cursor`(없으면 첫 페이지), `limit`(기본 20, 1 ≤ limit ≤ 100). |
| 호출 시점 | 첫 페이지 — 홈 진입/아기 전환/기록 생성·삭제 후 동기화. 다음 페이지 — 스크롤 하단 도달 시. |
| 결과 데이터 | `Page<CareRecord>` — `items`, `nextCursor`, `hasMore`. `CareRecord` 의 모든 필드가 채워진다(부분 모델 없음). |
| 결과 정렬 | `detail.occurredAt` 내림차순, 동률은 `id` 내림차순(spec FR-012). |
| 페이지 크기 상한 | 1 ≤ `limit` ≤ 100. 범위 밖이면 `ArgumentError`(도메인 수준 거부, spec FR-013). |
| 빈 데이터 | 기록 없으면 빈 페이지(`items=[]`, `hasMore=false`, `nextCursor=null`)를 성공으로 반환(spec FR-014). |
| 실패 케이스 | 네트워크/인증/권한 오류 → `Result.error(AppException)`. 호출자는 같은 cursor 로 재시도 가능. |

### 메서드: 최근 수유 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | "마지막으로 N시간 전에 먹였어요" 및 직전 수유 간격 계산. |
| 포함 타입 | `RecordType.feeding` 한 카테고리(세부 `FeedingType` 4종 — `breast`/`formula`/`pumpingFeed`/`babyFood`). **유축(`pumping`)은 제외** — feeding 이 단일 타입이라 자연 제외된다. |
| 입력 | `babyId`, `limit`(기본 2, 1 ≤ limit ≤ 10). |
| 결과 데이터 | `List<CareRecord>`(최대 `limit` 개), 모든 필드 채움. |
| 기준 시각 | "수유가 끝난 뒤" 의 경과 시간 해석 → 모유수유(`breast`)는 `endedAt`, 그 외 3종은 `detail.occurredAt`(spec FR-016). |
| 결과 정렬 | 기준 시각 내림차순, 동률은 `id` 내림차순. |
| 페이지 크기 상한 | 1 ≤ `limit` ≤ 10. 범위 밖이면 `ArgumentError`. |
| 빈 데이터 | 빈 리스트(1건만 있으면 1건). |
| 실패 케이스 | `Result.error(AppException)`. |

### 메서드: 최근 기저귀 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | "마지막으로 N시간 전에 기저귀 갈았어요". |
| 포함 타입 | `diaper`. |
| 입력 | `babyId`, `limit`(기본 2, 1 ≤ limit ≤ 10). |
| 결과 데이터 | `List<CareRecord>`(최대 `limit` 개), 모든 항목의 `detail` 은 `DiaperDetail`. |
| 결과 정렬 | `detail.occurredAt` 내림차순, 동률은 `id` 내림차순. |
| 페이지 크기 상한 | 1 ≤ `limit` ≤ 10. 범위 밖이면 `ArgumentError`. |
| 빈 데이터 | 빈 리스트. |
| 실패 케이스 | `Result.error(AppException)`. |

### 메서드: 최근 기상 기록

| 항목 | 요구사항 |
|---|---|
| 목적 | "마지막으로 N시간 전에 일어났어요". "기상" 은 수면 기록의 종료 시점으로 정의. |
| 포함 타입 | `sleep`. |
| 입력 | `babyId`, `limit`(기본 2, 1 ≤ limit ≤ 10). |
| 결과 데이터 | `List<CareRecord>`(최대 `limit` 개), 모든 항목의 `detail` 은 `SleepDetail`(`endedAt` null 불가). |
| 기준 시각 | 수면 기록의 `endedAt`(= 기상 시각). |
| 결과 정렬 | `endedAt` 내림차순, 동률은 `id` 내림차순. |
| 페이지 크기 상한 | 1 ≤ `limit` ≤ 10. 범위 밖이면 `ArgumentError`. |
| 빈 데이터 | 빈 리스트. |
| 실패 케이스 | `Result.error(AppException)`. |

### 메서드: 기록 생성

| 항목 | 요구사항 |
|---|---|
| 목적 | 새 기록을 영속화하고 반영 결과를 즉시 도메인 모델로 반환. |
| 입력 | `babyId`, `detail`(`RecordDetailData`). |
| 메타데이터 결정 | `type`/`occurredAt`/`startedAt`/`endedAt` 등 사건 메타데이터는 모두 `detail` 안에 있다(`detail` 하나가 SSOT). 백엔드로 보낼 type 값은 `detail.type` 에서 꺼낸다(spec FR-021). |
| `createdBy` 결정 | 호출자가 전달하지 않는다. Service 가 인증 컨텍스트의 현재 사용자로 자동 채운다. |
| 재시도 안전성 | **최소 1회 보장**. 재시도하면 중복 행 가능. 중복 방지는 ViewModel 책임(spec FR-022). |
| 결과 데이터 | `Result.ok(CareRecord)` — 영속화 시 채워진 `id`, `createdAt` 까지 포함한 모든 필드. ViewModel 이 리스트 맨 앞에 그대로 append 가능(spec FR-020). |
| 실패 케이스 | 미로그인/만료 → `unauthorized`, 권한 거부(보호자 아님) → `unauthorized`, 네트워크 실패 → `networkError`, 파싱 실패 → `parseFailed`. 모두 `Result.error(AppException)`. |

### 메서드: 기록 삭제

| 항목 | 요구사항 |
|---|---|
| 목적 | `recordId` 로 식별되는 기록을 영구 삭제. |
| 입력 | `recordId`. |
| 권한 | Repository 는 사전 검사하지 않는다. 권한 판정은 백엔드 보안 정책에 위임. |
| 미존재 처리 | 존재하지 않거나 이미 삭제된 `recordId` 이면 `Result.error(AppException(notFound))` 로 명시 구분("같은 요청을 또 보내도 성공" 처리하지 않음, spec FR-023). |
| 결과 데이터 | `Result.ok(null)`. 반환 페이로드 없음(필요 시 호출자가 메모리상 모델 사용). |
| 실패 케이스 | `notFound`, `unauthorized`, `networkError`, 기타 모두 `Result.error(AppException)`. |

## Service Layer

**역할**: Repository 의 하부 협력자. 원격 백엔드 호출, raw 응답을 도메인 모델로 매핑, 인증 컨텍스트 주입 같은 외부 시스템 연동 책임(Constitution I). Repository 만이 Service 에 의존하며 ViewModel 은 Service 의 존재를 모른다. 메서드는 `Result<T>` 를 반환하고 throw 하지 않으며, 모든 외부 실패는 `AppException` 으로 변환한다. 매핑 결과는 항상 도메인 모델이다(DB 응답 원본/`Map`/DTO 는 경계 밖으로 나가지 않음).

### BabyService — 책임

| 메서드 | 책임 |
|---|---|
| 아기 목록 조회 | 현재 인증 사용자가 보호자인 아기들을 `BabyListItem`(id, name)으로 반환. 생성일 내림차순 보장. |
| 단일 아기 정보 조회 | 주어진 `babyId` 의 기본 정보를 `Baby`(id, name, birthDate, dueDate, gender)로 반환. 행 없음/권한 없음이면 `notFound` 로 변환. |

### RecordService — 책임

| 메서드 | 책임 |
|---|---|
| 페이지 단위 기록 조회 | 마지막 항목의 `id` 기반 cursor 로 다음 페이지 조회. `hasMore` 와 다음 cursor 를 결과에 포함. |
| 카테고리별 최근 N건 조회 | 호출자가 지정한 타입 집합과 기준 시각(occurredAt / endedAt / 수유용 합성 키 중 하나)으로 정렬해 최대 N건 반환. |
| 기록 생성 | 호출자의 `detail` 에 더해 `createdBy` 를 인증 컨텍스트 현재 사용자로 자동 채워 영속화. 결과 행을 다시 `CareRecord` 로 매핑해 반환. |
| 기록 삭제 | `recordId` 로 삭제 요청. 영향 행 수가 0 이면 `notFound` 로 변환. |

### 매핑 책임의 위치

- **Leaf value object(`RecordDetailData` 변종)** 의 `toJson`/`fromJson` 은 도메인 모델이 직접 보유한다(데이터 소스에 의존하지 않는 자명한 직렬화).
- **Aggregate(`CareRecord`)** 와 **`BabyListItem`/`Baby`** 의 매핑은 Service 구현체 내부가 담당한다(향후 cross-table 필드 가능성 등 데이터 소스에 의존).
- 매핑 실패는 Service 안에서 catch 하여 `AppException(parseFailed)` 로 변환한다.

## 기술 스택 선택

| 영역 | 선택 | 이유 / 비고 |
|---|---|---|
| 원격 백엔드 | Supabase(Auth + PostgREST + RLS) | 프로젝트 전반의 기존 선택. 인증/DB/권한 통합. |
| 로컬 저장소 | `shared_preferences` | 단일 key-value(`selectedBabyId`)만 필요. 추가 의존성 최소화. |
| 상태 관리 / DI | `provider` + `dart:async` `StreamController` | DI 는 `provider`. `CurrentBabyController` 는 broadcast `StreamController` 로 선택 변화를 전파, `AppLocalStorage` 는 통지 없는 일반 `Provider`. |
| 비동기 결과 표현 | 프로젝트 내부 `Result<T>`(sealed `Ok`/`Error`) | 기존 패턴 재사용. throw 대신 명시적 분기. |
| 테스트 mock | `mockito` | 프로젝트 기존 선택. Service 를 mock 해 Repository 단위 테스트. |

## Service 구현 (Supabase)

> 아래는 백엔드 동작을 산문으로 기술한 것이며, 구체 API 호출 형태는 spec 을 깨지 않는 범위에서 바뀔 수 있다.

### BabyService

- **아기 목록 조회**: `babies` 테이블에서 식별자·이름 두 컬럼만 선택하고 생성일 내림차순으로 정렬한다. RLS 가 보호자 관계를 강제하므로 별도 사용자 필터를 두지 않는다.
- **단일 아기 정보 조회**: `babies` 에서 5컬럼(식별자·이름·출생일·예정일·성별)을 해당 식별자 단건으로 조회한다. 결과가 없으면 `notFound` 로 변환한다.

### RecordService

- **페이지 조회**: 아기 식별자로 필터하고, cursor 가 있으면 "식별자가 cursor 미만" 조건을 더한 뒤, 사건 시각 내림차순 + 식별자 내림차순으로 정렬해 `limit + 1` 개를 가져온다. `limit + 1` 트릭으로 다음 페이지 존재 여부(`hasMore`)를 판정하고, cursor 는 반환된 마지막 행의 식별자로 만든다.
- **최근 N건 조회**: 아기 식별자로 필터하고 타입 집합으로 한정한 뒤, 카테고리에 맞는 기준 시각 컬럼(사건 시각 / 수면 종료 시각 / 수유 4종용 합성 키) 내림차순 + 식별자 내림차순으로 정렬해 최대 N건을 가져온다.
- **생성**: 인증 컨텍스트의 현재 사용자 식별자로 `createdBy` 를 결정한다(없으면 `unauthorized`). 아기 식별자·기록 종류(`detail.type.name` — sealed 가 강제하므로 별도 매핑 함수 불필요)·세부 데이터(JSON, feeding 은 `feeding_type` 포함)·생성자를 삽입하고, 결과 행을 다시 `CareRecord` 로 매핑한다.
- **삭제**: 식별자로 삭제하고 영향 행 수를 확인한다. 0 이면 `notFound` 로 변환한다.

### cursor 직렬화

cursor 는 호출자가 내부를 해석할 필요 없는 문자열이지만, 실제로는 마지막 행의 식별자(UUID 문자열) 그대로다. 다음 페이지 조회는 "식별자 < cursor" 조건 + (사건 시각 내림차순, 식별자 내림차순) 정렬로 이어진다.

> 같은 사건 시각을 가진 행이 페이지 경계에 걸칠 때 누락/중복 가능성은 매우 낮지만 0 은 아니다. UUID v4 는 시간 정보를 담지 않아 정렬 키와 cursor 의 의미가 완벽히 일치하지는 않는다 — 단순한 id cursor 결정 하에서 감수하는 트레이드오프([Complexity Tracking](#complexity-tracking)).

### DB 약속 (마이그레이션 PR 의 책임)

본 PR 코드가 정상 동작하려면 다음 DB 변경이 선행되어야 한다(별도 마이그레이션 PR).

| 변경 | 용도 |
|---|---|
| `care_records` 의 사건 시각 generated column(세부 데이터의 `occurred_at` 또는 `started_at` 에서 파생) | 정렬 / 인덱스 활용. |
| `care_records` 의 종료 시각 generated column(세부 데이터의 `ended_at` 에서 파생, 구간 이벤트만 non-null) | 기상 정렬 / 인덱스 활용. |
| `care_records` 의 수유 합성 시각 generated column(`type='feeding'` 일 때 `feeding_type='breast' → 종료 시각`, 그 외 feeding 3종 → 사건 시각; feeding 이 아니면 null) | 수유 4종을 단일 정렬 키로 처리. **유축(`pumping`)은 더 이상 이 컬럼에 기여하지 않는다.** |
| (아기 식별자, 사건 시각 내림차순, 식별자 내림차순) 인덱스 | 페이지 단위 리스트 조회 최적화. |
| 위 generated column 에 대한 partial 인덱스(해당 컬럼이 non-null 인 행만) | 최근 N건 조회 최적화. |
| `babies` 의 생성일 컬럼 | 목록 정렬 기준. |
| `babies` 의 성별·출생일·예정일 컬럼 | 단일 아기 조회. |

## 매핑 함수

Service 구현체 내부의 순수 함수로 구현한다.

| 함수 | 동작 |
|---|---|
| 아기 목록 항목 매핑 | 식별자·이름. |
| 아기 기본 정보 매핑 | 식별자·이름·출생일(파싱 → UTC)·예정일(파싱 → UTC)·성별(enum). 생성일은 도메인 모델에 없으므로 매핑하지 않음. |
| 기록 매핑 | 식별자·아기 식별자·생성자·생성시각(파싱 → UTC)·세부 데이터를 채운다. 기록 종류(`RecordType`)를 enum 으로 변환(모르는 값이면 `parseFailed`)한 뒤 `RecordDetailData.fromJson(type, json)` 으로 변종을 생성한다. `feeding` 이면 `FeedingDetail.fromJson` 이 JSON 의 `feeding_type` 으로 leaf 를 분기한다(모르는 `feeding_type` → `parseFailed`). 생성된 세부 데이터가 종류 정보를 보유한다(`detail.type`). |

파싱 실패 / enum lookup 실패는 catch 하여 `AppException(parseFailed)` 로 변환한다.

## DI 등록

`lib/core/config/dependencies.dart` 에 다음을 등록한다.

- `SharedPreferences` — `main.dart` 부트스트랩에서 인스턴스를 await 한 뒤 동기 주입할 수 있도록 DI 컨테이너에 전달한다.
- `AppLocalStorage` — `SharedPreferences` 를 주입받는 일반 `Provider`(통지 없음).
- `CurrentBabyController` — `AppLocalStorage` 를 주입받는 일반 `Provider`(`ChangeNotifier` 아님). `dispose` 콜백에서 `controller.dispose()` 로 내부 `StreamController` 를 닫는다.
- `BabyService` / `BabyRepository` — Supabase 클라이언트를 주입받는 Service 와 그 위의 Repository.
- `RecordService` / `RecordRepository` — 동일 패턴.

`AppLocalStorage` 와 `CurrentBabyController` 는 앱 전체에 한 인스턴스만 등록한다.

## 도메인 코드의 spec 맞춤 작업

본 spec 의 규칙을 충족하려면 현재 도메인 코드에 다음 변경이 필요하다(별도 PR 가능).

| 항목 | 결정 | 상태 |
|---|---|---|
| `RecordType` 구조 | 9 평면 종류 → 6종(`feeding`/`pumping`/`sleep`/`diaper`/`snack`/`water`)으로 축소. | ✅ 본 PR |
| `FeedingType` 신설 | feeding 내부 세부 4종(`breast`/`formula`/`pumpingFeed`/`babyFood`) enum. | ✅ 본 PR |
| sealed `FeedingDetail` 도입 | feeding 4 leaf 를 sealed 중간 클래스 아래로. `feedingType` getter + `feeding_type` 직렬화. | ✅ 본 PR |
| `RecordDetailData.type` getter | `RecordType get type` 추상 getter 추가, 각 하위 클래스 override(`_typeOf` 대체). | ✅ 본 PR |
| `CareRecord.type` 필드 | **필드 제거**. type 은 `detail.type` 에서 꺼냄(편의 getter 는 선택). | ⬜ 별도 PR |
| `BabyFoodDetail.name` / `SnackDetail.name` | null 불가 String → nullable `String?`. | ⬜ 별도 PR |
| 구간 이벤트의 `startedAt < endedAt` | 생성자에 시작 < 종료 assert 추가. | ⬜ 별도 PR |
| 필수 String 의 공백 제거 후 비어있지 않음 | `Baby.name` 등에 trim 후 비어있지 않음 assert 추가. | ⬜ 별도 PR |
| 모델 `==` / `hashCode` | `id` 기반 구현. | ⬜ 별도 PR |

## 테스트 방식

### 도메인 단위 테스트

- `RecordDetailData` 각 하위 클래스 `toJson`/`fromJson` round-trip("단순 값 객체가 자기 직렬화를 직접 가진다" 검증). feeding leaf 는 `feeding_type` 직렬화도 확인.
- 각 하위 클래스의 `type` getter 가 자기 `RecordType` 을 반환하는지(feeding 4종은 `RecordType.feeding`), feeding leaf 의 `feedingType` getter.
- `RecordDetailData.fromJson(RecordType.feeding, ...)` 가 `feeding_type` 으로 올바른 leaf 로 분기하는지, 모르는 `feeding_type` → throw.
- 구간 이벤트(`BreastDetail`/`SleepDetail`)의 시작 < 종료 assert.
- 필수 String 필드에 공백만 들어왔을 때 assert.
- 모델 `==`/`hashCode` 가 id 기반인지.
- D-day/D+N 계산은 Presentation 책임이므로 단위 테스트 대상 아님.

### Repository 단위 테스트 (Service 를 mockito 로 mock)

| 메서드 | 시나리오 | 검증 |
|---|---|---|
| `BabyRepository.getMyBabies` | 정상 | `Result.ok(List<BabyListItem>)` passthrough |
| 〃 | 빈 리스트 → 에러 변환 | `Result.ok([])` → `Result.error(notFound)` |
| 〃 | 에러 | passthrough |
| `BabyRepository.getBaby` | 정상 / 미존재 | passthrough(미존재는 `notFound`) |
| `RecordRepository.getRecords` | 첫 페이지 / 다음 페이지 / 빈 페이지 | cursor·limit 전달, nextCursor 반영, 빈 페이지 passthrough |
| 〃 | limit 경계 | limit=0, limit=101 → `ArgumentError` |
| `RecordRepository.getRecentFeedings` | 정상 / 1건 / 빈 결과 | `{RecordType.feeding}`(유축 미포함) + 수유 합성 키로 호출 |
| 〃 | limit 경계 | limit=0, limit=11 → `ArgumentError` |
| `RecordRepository.getRecentDiapers` | 정상 | `{diaper}` + 사건 시각 |
| `RecordRepository.getRecentWakes` | 정상 | `{sleep}` + 종료 시각 |
| `RecordRepository.createRecord` | 정상 / 에러 | `babyId, detail` 로 호출(type 은 detail 에서), userId 미전달 |
| `RecordRepository.deleteRecord` | 정상 / 미존재 / 기타 에러 | 성공 시 `Result.ok(null)`, 미존재는 `notFound` passthrough |

### Service 테스트

Supabase SDK 의존성으로 Service 단위 테스트는 본 PR 에서 강제하지 않는다. 단, 매핑 함수가 헬퍼로 분리 가능하면 순수 함수 테스트 추가를 권장한다.

- 아기 목록 항목 매핑: 식별자/이름 보존.
- 아기 기본 정보 매핑: 출생일/예정일 null·non-null 케이스, 성별 enum 매핑.
- 기록 매핑 round-trip: 각 `RecordType` 에 대해 row → `CareRecord` → row 핵심 필드 보존, 미지 type 값 → `parseFailed`.

### AppLocalStorage / CurrentBabyController 테스트

`shared_preferences` 의 mock 초기값 기능으로 메모리상 동작을 검증한다.

| 컴포넌트 | 시나리오 | 검증 |
|---|---|---|
| `AppLocalStorage` | 초기(값 없음) / set / set 후 재set / remove | getter 가 각각 `null` / 저장값 / 갱신값 / `null`. ChangeNotifier 아니므로 listener 검증 없음. |
| `CurrentBabyController` | 초기(Storage `null`/`'a'` 반환) | `selectedBabyId` 가 각각 `null`/`'a'`(부팅 복원) |
| 〃 | `select(x)` | `Storage.setSelectedBabyId(x)` 1회 + `selectedBabyId==x` + `selectedBabyIdStream` 이 `x` 1회 emit |
| 〃 | `clear()` | `Storage.removeSelectedBabyId()` 1회 + `selectedBabyId==null` + `selectedBabyIdStream` 이 `null` 1회 emit |

## Acceptance Criteria (data 레이어 단위 검증)

> spec 의 Success Criteria(사용자/비즈니스 성과)와 달리, 아래는 데이터 레이어 내부 계약의 개발자 검증 기준이다.

- **AC-1**: `getMyBabies` 정상은 생성일 내림차순 `List<BabyListItem>` 을 반환한다. (FR-001·FR-002)
- **AC-2**: `getMyBabies` 의 빈 리스트는 `notFound` 오류로 변환된다. (FR-003)
- **AC-3**: `getBaby` 의 행 없음/권한 차단은 모두 `notFound` 한 코드로 반환된다. (FR-005)
- **AC-4**: `getRecords` 는 `occurred_at` 내림차순, 동률은 `id` 내림차순으로 정렬된다. (FR-012)
- **AC-5**: `getRecords` 의 `limit` 이 1 미만 또는 100 초과면 `ArgumentError`. (FR-013)
- **AC-6**: 기록 없는 아기의 `getRecords` 는 빈 페이지를 성공으로 반환한다. (FR-014)
- **AC-7**: `hasMore == true ⟺ nextCursor != null`. (FR-011)
- **AC-8**: 최근 수유는 `RecordType.feeding` 만 조회하며(유축 제외), 모유수유(`breast`) 종료 시각 / 그 외 feeding 사건 시각 기준으로 정렬된다. (FR-015·FR-016)
- **AC-9**: 최근 기상은 수면 `endedAt` 기준으로 정렬되며 `endedAt` 은 null 이 아니다. (FR-016)
- **AC-10**: `createRecord` 는 `id`·`createdAt` 까지 채워진 `CareRecord` 를 반환하고 `createdBy` 는 호출자가 전달하지 않는다. (FR-020·FR-021)
- **AC-11**: `deleteRecord` 의 미존재 대상은 `notFound` 로 구분되며 성공으로 위장하지 않는다. (FR-023)
- **AC-12**: 모든 메서드는 throw 하지 않고 `Result<T>` 를 반환하며 외부 실패는 구분된 `AppException` 으로 변환된다. (FR-040)
- **AC-13**: `AppLocalStorage` 는 값이 없으면 `null` 을 반환하고 변경 통지를 하지 않는다. (FR-030·FR-032)
- **AC-14**: `CurrentBabyController.select`/`clear` 는 메모리 갱신 + 영속화(또는 제거) + `selectedBabyIdStream` 1회 emit(새 ID / `null`)을 수행한다. (FR-031)
- **AC-15**: 모델의 시각 필드는 UTC 이고 `==`/`hashCode` 는 `id` 기반이다. (FR-041, Constitution II)

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 아기 모델을 `BabyListItem` / `Baby` 두 형태로 분리 | 목록(2필드)과 기본 정보(5필드)의 데이터 폭·무효화 시점이 다름 | 단일 모델은 목록 조회 시 불필요한 컬럼을 끌고 오고, 무효화 시점이 섞임 |
| cursor 를 단순 `id`(UUID) 로 사용 | 호출자에게 불투명 문자열만 노출하며 구현 단순 | 복합 cursor(시각+id 인코딩)는 페이지 경계 정확도를 약간 높이나 직렬화/검증 복잡도 증가. 누락/중복 가능성이 극히 낮아 단순 id 채택 |
| 수유 4종을 단일 정렬 키(generated column)로 처리 | 카테고리별 기준 시각이 다른데 한 번의 조회로 정렬 | 클라이언트 측 병합 정렬은 페이지네이션과 어긋나고 일관성 보장이 어려움 |
| feeding 을 sealed `FeedingDetail` 중간 클래스로 묶음 | "feeding 은 이 4종뿐" 을 타입 수준에서 강제(컴파일 타임 망라성) | 9개 평면 enum 은 feeding 멤버십을 코드로 강제하지 못해 신규 feeding 기능마다 4종을 수동으로 끌고 다녀야 함 |
| 선택 아기 전파를 `ChangeNotifier` 가 아닌 broadcast `StreamController` 로 | 여러 ViewModel 이 선택 변화를 stream 으로 구독, 현재값은 동기 getter | `ChangeNotifier`+`addListener` 는 값 전달이 아닌 신호만 주고, 프로젝트 컨벤션상 stream 구독을 선호. dispose 필요는 감수 |
