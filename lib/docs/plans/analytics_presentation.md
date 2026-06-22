# Implementation Plan: 분석 탭 — Presentation Layer (요약 영역)

## Summary

- 분석 탭 **요약 영역**(핵심 4지표 카드)의 Presentation Layer(ViewModel + View) 구현 계획.
- 데이터는 [데이터 레이어 plan](./analytics_summary.md)의 `AnalyticsRepository.getSummary` 로부터 받고, 화면은 그 `AnalyticsSummary` 를 카드로 그린다.
- ViewModel(`AnalyticsViewModel`)은 `ChangeNotifier` 기반으로 공통 `ActionState` 와 카드 표시용 가공값을 보유하고, View 는 `StatelessWidget` 으로 Provider 를 통해 이를 구독한다.
- 정성 라벨(적음/적정/많음)·기저귀 합산·단위/시각 포맷 등 **표시용 가공은 모두 Presentation 책임**(spec FR-006·FR-002a). 채팅 영역은 본 plan 범위가 아니다.

## 카드 ↔ 지표 슬롯 관계 (먼저)

화면에 보이는 **카드는 4개**지만, 데이터 레이어가 주는 지표 슬롯은 **5개**다. **기저귀 카드 하나가 소변(`peeCount`)·대변(`poopCount`) 두 지표를 합쳐 보여주기 때문**이다(spec FR-002a).

| 카드(4) | 뒷받침 지표 슬롯 |
|---|---|
| 수유량 | `feedingVolume` |
| 기저귀 | `peeCount` + `poopCount` (2개) |
| 깨어있는 시간 | `awakeDuration` |
| 총 수면 | `totalSleepDuration` |

## Technical Context

- **Language/Version**: Dart (Flutter), strict typing
- **State management / DI**: Provider 기반 DI(`lib/core/config/dependencies.dart`, `lib/main.dart`). ViewModel 은 `ChangeNotifier`, 상태는 **공통 `ActionState`**(`lib/common/utils/action_state.dart`, `{ idle, loading, success, error }`) 재사용 — onboarding 뷰모델들과 동일
- **View 제약**: **`StatelessWidget` 만 사용**. `StatefulWidget`·`addListener` 금지 — ViewModel 구독은 `context.watch` / `context.select` / `Consumer` 로만 한다([feedback: no StatefulWidget with Provider])
- **의존**: `AnalyticsRepository`(데이터), `CurrentBabyController`(현재 선택 아기 — `home_data.md`), 디바이스 로컬 타임존/오늘 날짜
- **Testing**: `flutter_test` + `mockito` — `AnalyticsViewModel` 단위 테스트(Repository mock 으로 상태 전이·가공값 검증). 기존 `test/presentation/**/*_view_model_test.dart` 관행과 동일
- **Target Platform**: 모바일 앱
- **Project Type**: Mobile app — `lib/presentation` 레이어
- **Constraints**: ViewModel 은 Repository 에만 의존(Service/데이터 소스 비노출), 위젯에 비즈니스 로직 금지, 정성/가공 표현은 ViewModel(또는 매퍼)에서 산출하고 위젯은 표시만
- **Scale/Scope**: ViewModel 1, Screen 1, 카드 위젯 4 + 공통(비교 배지·에러) 위젯

## Constitution Check

*GATE: 원칙은 [`../constitution.md`](../constitution.md). Presentation 관점 점검.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | 레이어 경계 | ✅ PASS | ViewModel 은 `AnalyticsRepository` 만 의존. Service/Supabase 미접근. View 는 ViewModel 만 본다. |
| II | 도메인 모델 정책 | ✅ PASS | ViewModel 은 도메인 모델을 입력으로 받아 **표시용 가공값**만 추가로 만든다. UTC→로컬 변환은 표시 계층에서 수행(spec FR-008). |
| III | 오류 처리 | ✅ PASS | Repository 의 `Result<T>` 를 받아 `ActionState.error` + `ErrorCode` 로 환원. View 는 throw 를 다루지 않음. |
| IV | 비즈니스 규칙 SSOT | ✅ PASS | Presentation 은 계산을 하지 않는다. position→라벨 등 **표현 매핑만** 한다(규칙 SSOT 는 spec). |
| V | 단순성 & 책임 분리 | ✅ PASS | 위젯은 무상태·표시 전용. 가공은 ViewModel. 합산(기저귀)·라벨·포맷이 위젯에 흩어지지 않음. 상태는 공통 enum 재사용으로 신규 추상화 없음. |
| VI | 테스트 가능성 | ✅ PASS | ViewModel 상태 전이·가공값을 mockito 단위 테스트로 검증(AC-P1~P7). |

**Gate Result**: PASS.

## Project Structure

```text
lib/presentation/analytics/
├── view_models/
│   ├── analytics_view_model.dart      # AnalyticsViewModel (ChangeNotifier, 공통 ActionState 사용)
│   └── metric_card_data.dart           # 카드 표시용 가공 값 객체 (presentation 모델)
├── views/
│   └── analytics_screen.dart           # 분석 탭 진입점 (요약 영역; 채팅 영역은 별도)
└── widgets/
    ├── feeding_card.dart               # 수유량 카드
    ├── diaper_card.dart                # 기저귀 카드 (합산 + 소변/대변 보조)
    ├── awake_card.dart                 # 깨어있는 시간 카드 (비교 UI 없음)
    ├── sleep_card.dart                 # 총 수면 카드
    ├── metric_comparison_badge.dart    # 적음/적정/많음 배지 (공통)
    └── analytics_error_state.dart      # 에러 + 재시도

test/presentation/analytics/
└── view_models/
    ├── analytics_view_model_test.dart
    └── analytics_view_model_test.mocks.dart
```

> 별도 `analytics_ui_state.dart` 를 만들지 않는다 — 공통 `ActionState` 로 충분하고, "데이터 없음" 은 상태가 아니라 **카드 단위 표시**(아래)로 다룬다. 빈 상태 전용 위젯도 두지 않는다(4개 카드가 항상 떠 있고 값이 없으면 카드 안에서 안내).

**Structure Decision**: 기존 `lib/presentation/<feature>/{view_models,views,widgets}` 패턴(`record_detail`)을 따른다. 카드 표시용 가공은 위젯이 아니라 `metric_card_data.dart` 값 객체 + ViewModel 에서 만든다.

## ViewModel 설계 — `AnalyticsViewModel`

**역할**: 분석 탭 진입/아기 전환 시 요약을 조회하고, View 가 그대로 그릴 수 있는 **상태 + 4개 카드 표시용 가공값**을 보유한다. `ChangeNotifier` 를 상속하고 변경 시 `notifyListeners()` 한다.

**의존성(생성자 주입)**: `AnalyticsRepository`, `CurrentBabyController`(현재 선택 아기), 로컬 타임존/오늘 날짜 제공자.

**보유 상태(필드)** — onboarding 뷰모델과 동일한 형태:

| 필드 | 타입 | 의미 |
|---|---|---|
| `state` | `ActionState` | `idle` / `loading` / `success` / `error` |
| `cards` | `List<MetricCardData>` | 성공 시 항상 **4개**(수유량·기저귀·깨어있는 시간·총 수면). 값 없는 카드는 `hasValue == false` 로 표시 |
| `errorCode` | `ErrorCode?` | `state == error` 일 때 분기용(`networkError`/`unauthorized`/`parseFailed`/`notFound`) |
| `isLoading` | `bool` (getter) | `state == loading` |

- **빈 데이터**(모든 지표 absent)도 **에러가 아니다**. `state == success` 이고 4개 카드가 모두 "데이터 없음"(`hasValue == false`)으로 채워진다(spec FR-005·FR-020).

**동작**:
- `load()` — 분석 탭 진입 시. `state=loading` → `babyId = currentBabyController.selectedBabyId` + 로컬 날짜로 `getSummary` 호출 → 결과를 상태로 환원.
- 아기 전환 — `CurrentBabyController` 의 선택 변경을 ViewModel 이 감지(구독)하여 `load()` 재실행. (View 는 `addListener` 를 쓰지 않는다.)
- `retry()` — `networkError` 시 동일 입력으로 `load()` 재호출.

**Repository 결과 → 상태 매핑**:

| `Result` | 상태 |
|---|---|
| `ok(summary)` | `state=success`, `cards` = 4개 카드(absent 지표는 "데이터 없음") |
| `error(notFound)` | `selectedBabyId` stale 처리(목록 재조회/다른 아기) 후 재로딩 |
| `error(unauthorized)` | `state=error`, `errorCode=unauthorized` → 로그인 유도 |
| `error(networkError)` | `state=error`, `errorCode=networkError` → 재시도 UI |
| `error(parseFailed)` | `state=error`, `errorCode=parseFailed` → 에러 화면 |

## 카드 매핑 & 표시 가공 (`MetricCardData`)

ViewModel 이 `AnalyticsSummary` 의 5개 지표 슬롯을 **항상 4개 카드**로 변환한다. `MetricCardData` 는 위젯이 그대로 그릴 표시값(라벨·포맷된 수치·`hasValue`·비교 배지)을 담는 불변 값 객체다.

| 카드 | 입력 지표 | 값 있을 때 | 값 없을 때(absent) |
|---|---|---|---|
| 수유량 | `feedingVolume` | "평균 하루 수유량 N ml" + 비교 배지(reference 있으면) | "데이터 없음" |
| 기저귀 | `peeCount` + `poopCount` | **타이틀**: 소변+대변 합산 평균 / **보조**: "소변 n / 대변 m"(FR-002a) | 둘 다 absent → "데이터 없음". 한쪽만 있으면 있는 쪽만 표시하고 없는 쪽은 "데이터 없음" 표기 |
| 깨어있는 시간 | `awakeDuration` | "평균 1회 깨어있는 시간 N분". **비교 배지 없음**(spec FR-019a) | "데이터 없음" |
| 총 수면 | `totalSleepDuration` | "평균 하루 총 수면 N시간 M분" + 비교 배지(reference 있으면) | "데이터 없음" |

**핵심 표시 규칙**:
- **4개 카드는 항상 렌더** 한다. 지표가 absent 라고 카드를 숨기지 않는다 — 카드 영역은 유지하고 그 안에서 "기록이 없어 보여줄 수 없음"(데이터 없음)을 알린다(spec FR-004).
- **정성 라벨/배지**: `ComparisonPosition` → `below`="권장보다 적음/짧음", `within`="적정", `above`="권장보다 많음/김"(문구·색상은 디자인 토큰).
- **비교 생략**: `MetricComparison.reference == null`(=`position == null`)이면 배지를 그리지 않고 값만 표시. `awakeDuration` 은 항상 값만 표시.
- **포맷**: 수면은 분→"N시간 M분", 횟수는 평균이라 소수 1자리 등. 단위는 지표별. 시각/날짜는 로컬 타임존 기준(spec FR-008). 모든 가공은 ViewModel 이 만들고 위젯은 표시만.

## 동작 방식 (시퀀스)

```
[분석 탭 진입]
1. AnalyticsScreen 빌드 → context.watch<AnalyticsViewModel>()
2. ViewModel.load() (최초 1회): state=loading → getSummary → success(cards) | error(code)
3. 렌더:
   - loading              → 로딩 인디케이터
   - success              → 항상 4개 카드 렌더. 각 카드는 값 또는 "데이터 없음"
                            (모든 지표 absent 면 4개 카드 모두 "데이터 없음")
   - error(network)       → AnalyticsErrorState + 재시도(retry)
   - error(unauthorized)  → 로그인 화면 이동
   - error(parseFailed)   → 에러 화면

[아기 전환]
1. CurrentBabyController.select(newId)
2. ViewModel 이 변경 감지 → load() 재실행(newId 기준)
```

## 검증 / 테스트 (AC — Presentation 단위)

> `AnalyticsViewModel` 을 `AnalyticsRepository` mock 으로 감싸 상태 전이·가공을 검증한다.

- **AC-P1**: `load()` 성공 시 `cards` 는 **항상 4개**다. absent 지표 카드는 `hasValue == false`("데이터 없음")로, 값 있는 지표는 포맷된 수치로 채워진다.
- **AC-P2**: 모든 지표 absent 인 성공 응답 → `state == success` 이고 4개 카드가 모두 `hasValue == false` 다(에러 아님, 카드 숨김 아님).
- **AC-P3**: 기저귀 카드는 소변·대변 평균을 합산해 타이틀을, "소변 n / 대변 m" 보조를 만든다. 한쪽만 absent 면 있는 쪽만 표시하고 없는 쪽을 "데이터 없음" 표기, 둘 다 absent 면 카드 전체가 "데이터 없음".
- **AC-P4**: `awakeDuration` 카드는 reference 유무와 무관하게 비교 배지를 만들지 않는다.
- **AC-P5**: `MetricComparison.position` 이 `below`/`within`/`above` 일 때 각각의 라벨/배지로 매핑되고, `position == null` 이면 배지가 없다.
- **AC-P6**: Repository 가 `networkError`/`unauthorized`/`parseFailed` → `state == error` 이고 `errorCode` 가 그대로 전달된다(각 분기 화면 결정 가능).
- **AC-P7**: 아기 전환 시 새 `babyId` 로 `getSummary` 가 재호출되고 상태/카드가 새 결과로 갱신된다.

## 파일 추가/수정 예상 목록

**추가**
- `lib/presentation/analytics/view_models/analytics_view_model.dart`
- `lib/presentation/analytics/view_models/metric_card_data.dart`
- `lib/presentation/analytics/views/analytics_screen.dart`
- `lib/presentation/analytics/widgets/{feeding_card,diaper_card,awake_card,sleep_card,metric_comparison_badge,analytics_error_state}.dart`
- `test/presentation/analytics/view_models/analytics_view_model_test.dart`

**수정**
- `lib/core/config/dependencies.dart` — `AnalyticsViewModel`/`AnalyticsRepository` 등록
- `lib/routing/router.dart` — 분석 탭 라우트(요약 영역) 연결

## Out of Scope

- 분석 탭의 **AI 채팅 영역** — 별도 spec/plan.
- 데이터 레이어(Repository/Service/도메인 모델) — [analytics_summary.md](./analytics_summary.md).
- 권장치 수치/비교 규칙 자체 — spec(SSOT).
