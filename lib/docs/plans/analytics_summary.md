# Implementation Plan: 분석 탭 — Data Layer (통계 요약)

## Summary

- 분석 탭이 보여줄 통계 요약을 현재 선택된 아기에 대해 도메인 모델로 제공하는 데이터 레이어.
- 요약 계산의 주체는 백엔드(Supabase)이며 클라이언트는 계산된 요약(지표 값 + 월령 권장 범위 비교)을 조회한다.
- 클라이언트는 `AnalyticsRepository → AnalyticsService → 원격 백엔드(Supabase)` 계층으로 구성하고, ViewModel 에는 Repository 와 도메인 모델 + `Result<T>` 만 노출한다.
- spec 의 계산·비교 비즈니스 규칙(FR-010~FR-019)을 SSOT 로 삼아, 클라이언트는 안정적인 "요약 모델" 계약을 검증한다.

## Technical Context

- **Language/Version**: Dart (Flutter), strict typing
- **Primary Dependencies**: 기존 앱 공통 모듈(도메인 모델 `CareRecord`/`RecordDetailData`/`RecordType` 등 — `home_data.md` §3, `Result<T>`, `AppException`/`ErrorCode`), 인증 컨텍스트, Provider 기반 DI
- **Data Source**: Supabase (요약 계산·캐시·재계산은 서버 측 책임)
- **Storage**: 클라이언트 측 영속 저장 없음(읽기 전용 조회)
- **Testing**: `flutter_test` + `mockito` — Repository impl 단위 테스트(mockito mock 으로 조회 성공/각 실패 분기 검증) + 값 객체 불변식 단위 테스트. 기존 `test/data/repositories/*` 관행과 동일
- **Target Platform**: 모바일 앱(기존 앱과 동일)
- **Project Type**: Mobile app — `lib/data` 레이어
- **Performance Goals**: 분석 탭 진입~요약 표시 3초 이내(spec SC-001), 요약은 단일 아기·단일 행 규모로 경량
- **Constraints**: 읽기 전용(쓰기/커맨드 없음), 도메인 모델 경계 밖으로 DTO/`Map`/raw 응답 노출 금지, 로컬 타임존 입력 필수
- **Scale/Scope**: Repository 1, Service 1, 도메인 값 객체 4종(`AnalyticsSummary`/`MetricComparison`/`ReferenceRange`/`ComparisonPosition`), 조회 메서드 1, 지표 슬롯 5개

## Constitution Check

*GATE: 설계 전후로 점검한다. 원칙은 [`../constitution.md`](../constitution.md).*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | 레이어 경계 | ✅ PASS | ViewModel 은 `AnalyticsRepository` 만 의존. Service/Supabase 클라이언트 비노출. DTO/`Map`/raw 응답이 Repository·Service 경계 밖으로 나가지 않음. |
| II | 도메인 모델 정책 (immutable, UTC) | ✅ PASS | 모든 필드 `final`, 변경은 `copyWith`, 모델 내 `DateTime` 은 UTC. 요약 모델은 계산 없는 값 객체. |
| III | 오류 처리 (`Result<T>` + `AppException`) | ✅ PASS | 메서드는 throw 하지 않고 `Result<T>` 반환. 외부 실패는 `AppException(code)` 로 변환. `notFound` 는 행 없음 + 권한 차단 포함. |
| IV | 비즈니스 규칙 SSOT | ✅ PASS | 계산·비교 규칙의 정의는 spec(FR-010~FR-019)이 SSOT. 실제 집계는 백엔드. 클라이언트는 모델 계약만 검증. |
| V | 단순성 & 책임 분리 | ✅ PASS | 집계는 백엔드. 클라이언트가 raw 기록/권장치 테이블을 직접 받지 않음. 정성 라벨·표시 가공 수치는 Presentation 책임. |
| VI | 테스트 가능성 | ✅ PASS | 모델 불변식·비교 판정·조회 분기를 단위 테스트로 검증(AC-1~AC-19). 데이터 부재/부족을 정상 상태로 고정. |

**Gate Result**: PASS (constitution `../constitution.md` 기준). 정당화가 필요한 설계 선택은 Complexity Tracking 참조.

## Project Structure

### Documentation

```text
lib/docs/
├── constitution.md              # 프로젝트 최상위 원칙 (Constitution Check 기준)
├── specs/
│   └── analytics_summary.md     # 분석 탭 spec (요약 + 채팅 carve-out)
└── plans/
    └── analytics_summary.md     # 이 문서 (데이터 레이어 plan)
```

### Source Code (repository root)

> 기존 `home_data` / `record_repository` 와 동일한 디렉터리 관행을 따른다.

```text
lib/
├── domain/
│   └── models/
│       └── analytics/
│           ├── analytics_summary.dart       # AnalyticsSummary 값 객체
│           ├── metric_comparison.dart        # MetricComparison
│           ├── reference_range.dart           # ReferenceRange
│           └── comparison_position.dart       # ComparisonPosition enum
└── data/
    ├── repositories/
    │   └── analytics_repository/
    │       ├── analytics_repository.dart      # 조회 계약 (ViewModel 의존 대상)
    │       └── analytics_repository_impl.dart # 구현
    └── services/
        └── analytics_service/
            ├── analytics_service.dart         # 인터페이스
            └── supabase_analytics_service.dart # Supabase 호출 + 도메인 매핑

test/
├── domain/
│   └── models/
│       └── analytics/
│           └── metric_comparison_test.dart     # 값 객체 불변식 (AC-1~AC-4)
└── data/
    └── repositories/
        └── analytics_repository/
            ├── analytics_repository_impl_test.dart  # 조회 성공/실패 분기
            └── analytics_repository_impl_test.mocks.dart
```

**Structure Decision**: 도메인 값 객체는 기존 도메인 모델과 같은 `lib/domain/models/` 아래(`analytics/` 하위)에 둔다. Repository/Service 는 기존 `<name>_repository` / `<name>_service` 인터페이스+impl 패턴을 따르고, 백엔드 구현체는 `supabase_*` 접두사를 쓴다(기존 `supabase_record_service` 와 동일). 데이터 소스에 의존하는 aggregate 매핑(`AnalyticsSummary` 등)은 Service 구현체 내부에서 수행하고, 매핑 실패는 `AppException(parseFailed)` 로 변환한다.

## 도메인 모델

이 네 모델은 분석 탭이 받아 그리는 **요약 데이터의 클라이언트 측 표현**이다. 모두 [constitution Principle II](../constitution.md) 의 값 객체 정책(모든 필드 `final`, 변경은 `copyWith`, `DateTime` 은 UTC, **자체 계산 없음**)을 따른다. 계산은 백엔드(Supabase)가 수행하고, 이 모델들은 "이미 계산된 결과" 만 담는다.

**구성(포함) 관계**: `AnalyticsSummary` 는 여러 개의 `MetricComparison` 을 슬롯으로 담고, 각 `MetricComparison` 은 하나의 `ReferenceRange` 와 하나의 `ComparisonPosition` 을 (선택적으로) 담는다.

```
AnalyticsSummary
 ├─ babyId: String
 └─ <지표 슬롯> : MetricComparison?            // 5개 슬롯, 슬롯마다 독립적으로 null(absent) 가능
       ├─ value     : double                   // 산출된 평균값 (non-null)
       ├─ reference : ReferenceRange?           // 권장 범위 (없을 수 있음)
       │    ├─ min : double
       │    └─ max : double
       └─ position : ComparisonPosition?        // below | within | above (없을 수 있음)
```

### `AnalyticsSummary` — 한 아기의 요약 한 묶음

**역할**: 현재 선택된 아기에 대해, 현재 윈도우(오늘 제외 최대 7일) 기준으로 산출된 핵심 지표들을 한 객체로 묶는다. ViewModel 이 받아 화면에 뿌리는 최상위 단위다.

| 필드 | 타입 | 의미 |
|---|---|---|
| `babyId` | `String` | 이 요약이 어느 아기의 것인지(현재 선택된 아기 식별자) |
| `feedingVolume` | `MetricComparison?` | 평균 하루 수유량(분유+유축수유 ml) |
| `peeCount` | `MetricComparison?` | 평균 하루 소변 기저귀 횟수 |
| `poopCount` | `MetricComparison?` | 평균 하루 대변 기저귀 횟수 |
| `awakeDuration` | `MetricComparison?` | 평균 1회 깨어있는 시간(분) |
| `totalSleepDuration` | `MetricComparison?` | 평균 하루 총 수면시간(분) |

- **권장치 매핑**: 각 지표의 권장 범위·구간은 spec [부록 A](../specs/analytics_summary.md#부록-a--권장치-시드-데이터-reference-seed)를 따른다(수유량 AAP, 소변 AAP, 대변 MSD, 총 수면 NSF — 단위는 모델 단위와 동일). `awakeDuration` 은 권장치 비교를 제공하지 않으므로(설계 결정) `reference`/`position` 이 **항상 null** 이며, 표시 계층도 비교 UI를 노출하지 않는다.
- **슬롯 nullability**: 각 지표 슬롯은 **독립적으로 `null`(absent)** 일 수 있다. `null` 은 "윈도우 안에 그 지표를 산출할 기록이 한 건도 없었다" 는 뜻이며(spec FR-004·FR-010), 한 지표가 absent 라고 다른 지표가 함께 사라지지 않는다.
- 모든 슬롯이 `null` 인 요약(기록 전혀 없음)도 **정상적인 성공 결과**다(spec FR-020). 화면에서 "요약 없음" 빈 상태로 처리한다.
- 자체적으로 평균·비교를 계산하지 않는다. 표시용 가공(기저귀 카드의 소변+대변 합산 등)은 Presentation 책임.

### `MetricComparison` — 한 지표의 값 + 권장 범위 비교

**역할**: 지표 하나에 대해 "내 아기 값" 과 "그 값이 권장 범위 대비 어디인지" 를 한 묶음으로 표현한다. 슬롯이 존재(non-null)하면 값은 반드시 있고, 권장 범위 비교는 가능할 때만 채워진다.

| 필드 | 타입 | 의미 |
|---|---|---|
| `value` | `double` | 윈도우 기준 산출된 평균값. **non-null**. 단위는 지표별(ml·분·횟수). 평균이므로 횟수 지표도 소수일 수 있음 |
| `reference` | `ReferenceRange?` | 해당 월령 구간 × 이 지표의 권장 범위. 비교 불가 시 `null` |
| `position` | `ComparisonPosition?` | `value` 가 권장 범위 대비 어디인지. 비교 불가 시 `null` |

- **핵심 불변식**: `reference != null ⟺ position != null`(둘은 항상 함께 존재하거나 함께 없음, spec FR-016). `value` 만 있고 비교(`reference`/`position`)가 없는 상태는 **정상**이다 — 출생 정보가 없거나 월령이 권장치 테이블 범위 밖일 때 발생(spec FR-018).
- 정성 라벨("살짝 짧음")·표시용 가공 수치(차이 %)는 **보유하지 않는다**. 그것은 Presentation 이 `value`·`reference`·`position` 으로부터 만든다(spec FR-006).

### `ReferenceRange` — 권장 범위

**역할**: 특정 월령 구간 × 특정 지표에 대한 권장치를 하한·상한 범위로 표현한다. 백엔드가 운영자 시드 권장치 테이블에서 조인해 채운다.

| 필드 | 타입 | 의미 |
|---|---|---|
| `min` | `double` | 권장 범위 하한(포함) |
| `max` | `double` | 권장 범위 상한(포함) |

- **불변식**: 항상 `min <= max`(spec FR-019). 단위는 비교 대상 지표와 동일(ml↔ml, 분↔분, 횟수↔횟수).
- 권장치가 본질적으로 단일 값인 지표라도 `min == max` 인 범위로 통일해 표현한다(비교 로직 단일화, [Complexity Tracking](#complexity-tracking) 참조).

### `ComparisonPosition` — 범위 대비 위치 (enum)

**역할**: `value` 가 `reference` 대비 어디에 있는지를 세 분류로 나타낸다. 표시 계층이 "적음/적정/많음" 라벨이나 색상을 결정하는 입력이 된다.

| 값 | 판정 조건 | 의미 |
|---|---|---|
| `below` | `value < reference.min` | 권장보다 적음/짧음 |
| `within` | `reference.min <= value <= reference.max` | 권장 범위 안 |
| `above` | `value > reference.max` | 권장보다 많음/김 |

- **경계값(`value == min` 또는 `value == max`)은 `within`** 으로 판정한다(범위는 양 끝 포함, spec FR-016).
- "얼마나 차이 나는가" 의 정도(거리·비율)는 보유하지 않는다 — 필요하면 Presentation 이 `value`·`reference` 로부터 직접 계산한다.

## AnalyticsRepository

**역할**: 분석 탭이 보여줄 통계 요약을 **현재 선택된 아기에 대해** 도메인 모델(`AnalyticsSummary`) + `Result<T>` 형태로 제공한다. ViewModel 이 유일하게 의존하는 데이터 진입점이며(다른 계층은 ViewModel 에 노출되지 않음, [constitution Principle I](../constitution.md)), Service 를 협력자로 호출한다.

### 책임

- 아기 1명의 요약을 `AnalyticsSummary` 로 노출한다. raw 응답 / `Map` / DTO 는 경계 밖으로 내보내지 않는다.
- 화면 표시용 가공(라벨·정성 표현·퍼센트·합산)을 하지 않는다 — 그것은 Presentation 책임(spec FR-006).
- **자체 상태(캐시·큐·lock)를 갖지 않는다.** 캐시/재계산은 백엔드 책임이므로 Repository 는 무상태이고, 동시에 여러 번 호출해도 안전하다.

### 호출자

- `AnalyticsViewModel` — 분석 탭 진입 시 요약 조회, 아기 전환 시 새 아기 기준으로 재조회.

### 주요 결정

- **`userId` 를 인자로 받지 않는다.** "현재 사용자" 는 인증 컨텍스트에서 자동 판단한다(`home_data` 의 Repository 결정과 동일).
- **`babyId` 를 인자로 받는다.** "현재 선택된 아기" 의 판정은 호출자(`CurrentBabyController` / ViewModel)의 책임이다.
- **로컬 타임존(또는 오늘의 로컬 날짜)을 인자로 받는다.** 일 단위 집계 경계가 로컬 자정(spec FR-011)이고 캐시 신선도 판정이 로컬 날짜 기준(spec FR-022)인데, 백엔드는 디바이스의 로컬 타임존을 알 수 없으므로 호출자가 전달해야 한다.

### 메서드: 요약 조회 (`getSummary`)

| 항목 | 내용 |
|---|---|
| 목적 | 한 아기의 분석 탭 통계 요약(지표 값 + 레퍼런스 비교) 조회 |
| 입력 | `babyId`(필수), 요청자의 **로컬 타임존(또는 오늘의 로컬 날짜)**(필수) |
| 호출 시점 | 분석 탭 진입 시, 아기 전환 시 |
| 동작 | Service 를 통해 백엔드 요약을 가져온다. 저장된 요약이 stale(spec FR-022)이면 백엔드가 재계산 후 반환, 아니면 저장본 반환 |
| 결과(성공) | `AnalyticsSummary` — 5개 지표 슬롯 각각 `MetricComparison?`. 데이터 없는 지표는 absent, 비교 불가 지표는 `reference`/`position` null |
| 빈 데이터 | 기록이 전혀 없어도 **에러가 아니다.** 모든 지표가 absent 인 `AnalyticsSummary` 를 성공으로 반환(spec FR-020) |
| 성공 조건 | 사용자가 인증되어 있고, 해당 `babyId` 에 보호자로 접근 가능 |
| 실패 | 접근 불가/미존재 → `notFound`, 미로그인/만료 → `unauthorized`, 네트워크 실패 → `networkError`, 응답/매핑 실패 → `parseFailed`. 모두 `Result.error(AppException)` (spec FR-021) |

> `notFound` 는 "행 없음" 과 "권한 차단(RLS 등)" 을 모두 포함한다([constitution Principle III](../constitution.md)). 호출자는 이를 stale 한 `selectedBabyId` 의 fallback 신호로 쓸 수 있다(`home_data.md` §5.6 과 동일).

## AnalyticsService

**역할**: Repository 의 하부 협력자. **원격 백엔드(Supabase) 호출 + 인증 컨텍스트 주입 + raw 응답을 도메인 모델로 매핑** 한다. Repository 만이 Service 에 의존하며, ViewModel 은 Service 의 존재를 알지 못한다([constitution Principle I](../constitution.md)). 인터페이스(`analytics_service.dart`)와 Supabase 구현(`supabase_analytics_service.dart`)을 분리해 백엔드 교체·테스트 더블 주입이 가능하게 한다(기존 `record_service` / `supabase_record_service` 패턴과 동일).

### 책임

- `babyId` 와 로컬 날짜/타임존을 받아 Supabase 의 (필요 시 재계산된) 요약을 호출한다.
- **응답을 `AnalyticsSummary` 로 매핑** 한다. 지표별 `value`, 그리고 가능한 경우 `ReferenceRange`·`ComparisonPosition` 을 채운다. 비교가 불가한 지표는 `reference`/`position` 을 null 로 매핑한다.
- 메서드는 **throw 하지 않고 `Result<T>` 를 반환** 한다. 모든 외부 실패(네트워크·인증·파싱)는 `AppException(ErrorCode)` 로 변환한다([constitution Principle III](../constitution.md)).
- 매핑 결과는 항상 도메인 모델이다. DB 응답 원본 / `Map` / DTO 는 Service 경계 밖으로 나가지 않는다.

### 메서드: 요약 조회

| 항목 | 내용 |
|---|---|
| 입력 | `babyId`, 로컬 타임존/오늘 날짜 |
| 동작 | Supabase 요약 엔드포인트(예: Postgres RPC / view) 호출 → 응답을 `AnalyticsSummary` 로 매핑해 반환 |
| 성공 | `Result.ok(AnalyticsSummary)` |
| 실패 | 네트워크/호출 실패 → `networkError`, 인증 만료/미로그인 → `unauthorized`, 접근 불가/미존재 → `notFound`, 응답·매핑 실패·모르는 enum 값 → `parseFailed` |

### 매핑 책임의 위치

- `AnalyticsSummary` / `MetricComparison` / `ReferenceRange` / `ComparisonPosition` 의 매핑은 **Service 구현체(`supabase_analytics_service.dart`) 내부** 가 담당한다(데이터 소스에 의존하는 aggregate 매핑).
- 매핑 중 형식 오류·null 조합 위반·모르는 enum 값은 Service 안에서 catch 하여 `AppException(parseFailed)` 로 변환한다. 매핑 시 모델 불변식(`reference != null ⟺ position != null`, `min <= max`)을 만족하지 못하는 응답은 `parseFailed` 로 처리한다.

## 캐시 / 재계산 (백엔드 측 메커니즘)

- 요약은 아기별 현재 윈도우 기준 1행만 유지(히스토리 없음). 백엔드가 마지막 계산 시각 보유.
- 저장된 계산 시각이 요청자 로컬 날짜의 자정 이전이면 재계산 후 반환, 아니면 저장본 반환(하루 1회 갱신, spec FR-022).
- 윈도우 내 과거 기록 수정/삭제는 다음 로컬 자정 갱신 전까지 stale 허용(비용 대비 단순성 선택, [constitution Principle V](../constitution.md)).

## 호출자 동작 시퀀스 (참고용)

> ViewModel 관점 참고용이며 Presentation Layer 스펙이 아니다.

```
[분석 탭 진입]
1. babyId    = currentBabyController.selectedBabyId        // String? (sync)
2. localDate = (디바이스 로컬 타임존 / 오늘 날짜)
3. result    = analyticsRepository.getSummary(babyId, localDate)   // Result<AnalyticsSummary>
     ok(summary):        absent 가 아닌 슬롯만 렌더. position 기반 정성 라벨은 Presentation 결정.
     error(notFound):    selectedBabyId stale 처리(목록 재조회/다른 아기 선택). home_data §8.1
     error(unauthorized):로그인 화면
     error(networkError):"다시 시도" UI
     error(parseFailed): 에러 화면

[아기 전환]
1. currentBabyController.select(newId) → 2. ViewModel 변경 감지 → 진입 시퀀스 step 3 부터 newId 로 재실행.
```

## Acceptance Criteria (data 레이어 단위 검증)

> spec 의 Success Criteria(사용자/비즈니스 성과)와 달리, 아래는 데이터 레이어 내부 불변식의 개발자 검증 기준이다. 각 항목은 spec FR 을 구현 단위로 환원한다.

- **AC-1**: `reference != null` ⟺ `position != null`. (FR-016)
- **AC-2**: `value == min` 또는 `value == max` → `within`. (FR-016)
- **AC-3**: `value < min` → `below`, `value > max` → `above`. (FR-016)
- **AC-4**: `ReferenceRange` 는 항상 `min <= max`. (FR-019)
- **AC-5**: 미숙아(`dueDate − birthDate > 21일`) anchor 는 `dueDate`(교정연령). (FR-017)
- **AC-6**: 비미숙아 또는 `dueDate == null` → anchor 는 `birthDate`. (FR-017)
- **AC-7**: `birthDate == null` → 모든 지표 reference/position null(값은 산출). (FR-018)
- **AC-8**: 교정연령 음수 → 월령 0 구간으로 비교. (FR-017)
- **AC-9**: 월령이 테이블 구간 밖 → 해당 지표 비교 생략. (FR-018)
- **AC-10**: `feedingVolume` 은 윈도우 각 날 (`formula`+`pumpingFeed`) ml 합을, 해당 기록 있는 날 수로 나눈 평균. (FR-010·FR-012)
- **AC-11**: `DiaperType.mixed` 1건 → 소변·대변 각각 +1. (FR-013)
- **AC-12**: 자정 걸친 수면 → `startedAt` 날짜에 전체 길이 귀속(분할 없음). (FR-014)
- **AC-13**: `awakeDuration` 은 연속 수면 gap 평균, 음수 gap 제외, 유효 gap 0개면 absent. (FR-015)
- **AC-14**: 윈도우는 오늘 제외 직전 최대 7개 완성된 날. 완성된 날 0개면 모든 지표 absent. (FR-010)
- **AC-15**: 지표 타입 기록이 윈도우에 0건이면 그 슬롯 absent. (FR-004·FR-010)
- **AC-16**: 계산 시각이 요청자 로컬 자정 이전이면 재계산 후 반환, 아니면 저장본. (FR-022)
- **AC-17**: 윈도우 내 과거 기록 수정/삭제는 다음 로컬 자정 전까지 재계산하지 않음(stale 허용). (FR-022)
- **AC-18**: 기록 0건이어도 모든 지표 absent 인 요약을 성공 반환(에러 아님). (FR-020)
- **AC-19**: 접근 불가/미존재 → `notFound`, 미로그인 → `unauthorized`, 네트워크 실패 → `networkError`, 매핑 실패 → `parseFailed`. (FR-021)

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 모든 권장치를 단일 값이 아닌 `[min, max]` 범위로 통일 | 지표별로 권장치 형태가 다르나(단일/범위) 모델을 하나로 유지 | 단일 값 + 범위 두 표현을 두면 비교 로직이 분기되어 복잡 |
| 로컬 타임존을 클라이언트가 백엔드에 전달 | 백엔드가 디바이스 타임존을 알 수 없음 | 서버 UTC 기준 집계는 로컬 자정 윈도우 정의와 어긋남 |
