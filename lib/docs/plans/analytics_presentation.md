# Implementation Plan: 분석 탭 — Presentation Layer (요약 영역)

## Summary

- 분석 탭 **요약 영역**(핵심 4지표 카드)의 Presentation Layer(ViewModel + View) 구현 계획.
- 데이터는 [데이터 레이어 plan](./analytics_data.md)의 `AnalyticsRepository.getSummary` 로부터 받고, 화면은 그 `AnalyticsSummary` 를 카드로 그린다.
- ViewModel 은 **코디네이터 1개 + 카드별 ViewModel 4개**로 나눈다. 코디네이터(`AnalyticsViewModel`)가 요약을 **한 번** 조회해 네트워크 로딩/실패를 책임지고, 조회 결과를 4개 카드 ViewModel 에 나눠준다. 각 카드 ViewModel 은 자기 카드의 표시 내용(값·"데이터 없음"·비교 배지)을 만들어 보유한다.
- View 는 `StatelessWidget` 으로 Provider 를 통해 ViewModel 을 구독한다(`context.watch`).
- 정성 라벨(적음/적정/많음)·기저귀 합산·단위/시각 포맷 등 **표시용 가공은 모두 Presentation 책임**(spec FR-006·FR-002a). 채팅 영역은 본 plan 범위가 아니다.

## 이 화면이 보여주는 것 (개요)

분석 탭 요약 영역은 보호자에게 **"우리 아기의 요즘 평균적인 하루"** 를 카드 4장으로 보여준다. 각 카드는 한 지표의 최근 평균값을 큰 숫자로 보여주고, 그 값이 **월령별 권장 범위 대비 어디인지**(적음/적정/많음)를 작은 배지로 함께 보여준다.

```text
[분석 탭 — 요약 영역]

┌──────────────────────────┐   ┌──────────────────────────┐
│ 평균 하루 수유량          │   │ 평균 하루 기저귀          │
│  750 ml        [적정]     │   │  7.0 회                   │   ← 기저귀는 소변+대변 합산
│                          │   │  소변 5.2 / 대변 1.8      │   ← 보조 설명
└──────────────────────────┘   └──────────────────────────┘
┌──────────────────────────┐   ┌──────────────────────────┐
│ 평균 1회 깨어있는 시간     │   │ 평균 하루 총 수면         │
│  1시간 20분               │   │  13시간 30분    [적음]    │
│  (비교 배지 없음)          │   │                          │
└──────────────────────────┘   └──────────────────────────┘

(기록이 없는 카드는 숨기지 않고 "데이터 없음" 으로 보인다)
┌──────────────────────────┐
│ 평균 하루 수유량          │
│  데이터 없음              │
└──────────────────────────┘
```

- **카드 = 한 지표의 평균값**. "최근 며칠(오늘 제외, 최대 7일)의 평균" 이라는 계산은 데이터 레이어/백엔드가 끝낸 값이고, 화면은 그 값을 포맷해 보여줄 뿐이다.
- **비교 배지(적음/적정/많음)가 왜 있나**: 보호자가 "우리 아기가 또래 권장 범위 안에 있나" 를 한눈에 가늠하도록 돕는 것이 분석 탭의 핵심 가치다(spec FR-003). 배지는 아기 값과 월령별 권장 범위를 견준 결과다.
- **배지가 없는 경우도 정상**: 출생 정보가 없어 월령을 모르거나, 그 지표에 권장 범위가 없으면(특히 깨어있는 시간) 값만 보여주고 배지는 생략한다(spec FR-018·FR-019a).

## 카드 ↔ 지표 슬롯 관계

화면에 보이는 **카드는 4개**지만, 데이터 레이어가 주는 지표 슬롯은 **5개**다. **기저귀 카드 하나가 소변(`peeCount`)·대변(`poopCount`) 두 지표를 합쳐 보여주기 때문**이다(spec FR-002a).

| 카드(4) | 뒷받침 지표 슬롯 | 비교 배지 |
|---|---|---|
| 수유량 | `feedingVolume` | 있음(권장 범위 있을 때) |
| 기저귀 | `peeCount` + `poopCount` (2개) | 없음(합산값에 대응하는 단일 권장 범위가 없음) |
| 깨어있는 시간 | `awakeDuration` | 없음(설계상 권장치 비교 미제공, spec FR-019a) |
| 총 수면 | `totalSleepDuration` | 있음(권장 범위 있을 때) |

## 디자인 참조 (Figma) — 노드 매핑

이 화면은 **소스가 둘**이다: 이 문서(+[spec](../specs/analytics_summary.md))와 [Figma 디자인](https://www.figma.com/design/RfgJFyjzaWYerlwkrdMTIz/%EB%82%B4%EA%BF%88%EC%9D%80%EC%9C%A1%ED%87%B4?node-id=437-2). 헷갈리지 않도록 역할을 고정한다.

- **Figma** = 레이아웃·간격·색·아이콘·타이포 등 **시각(visual) 기준**.
- **이 문서 + spec** = 지표 정의·배지 의미·표시 규칙·계약 등 **동작/데이터/규칙의 SSOT**.
- **둘이 충돌하면 이 문서/spec 이 이긴다** (아래 [불일치 기록](#피그마--문서-불일치-기록)). Figma 목업은 초기안이라 spec 과 다른 지점이 있다.

- **파일 key**: `RfgJFyjzaWYerlwkrdMTIz` (내꿈은육퇴)
- **분석 탭 프레임**: `437:2` (448×992)
- 본 plan 범위는 **요약 카드 그리드(`437:32`)** 뿐. 헤더·채팅·하단 탭은 범위 밖(아래 표에 위치만 기록).

### 노드 매핑 — 요약 영역 (본 plan)

| plan 요소 / 위젯 | Figma 노드 | 비고 |
|---|---|---|
| 요약 카드 그리드(`_SummaryCards`) | `437:32` | 2×2 그리드 (400×320) |
| 수유량 카드(`FeedingCard`) | `437:33` | Total Feeding |
| 총 수면 카드(`SleepCard`) | `437:50` | Total Sleep |
| 기저귀 카드(`DiaperCard`) | `437:66` | Diapers — ⚠️ [불일치 C](#피그마--문서-불일치-기록) |
| 깨어있는 시간 카드(`AwakeCard`) | — (Figma 에 없음) | ⚠️ [불일치 B](#피그마--문서-불일치-기록): 그 자리엔 Activities 카드(`437:83`) |
| 카드 내부 — 아이콘 | 각 카드 첫 Container (수유량 예: `437:34`) | 시각 참조만 |
| 카드 내부 — 라벨 | 수유량 예: `437:39` ("Total Feeding") | 문구는 문서/spec 기준 |
| 카드 내부 — 값 + 단위 | 수유량 예: `437:42` ("850") / `437:44` ("ml") | |
| 비교 배지(`MetricComparisonBadge`) | 수유량 예: `437:45` (화살표 `437:46` + 텍스트 `437:49`) | ⚠️ [불일치 A](#피그마--문서-불일치-기록): Figma 는 "vs avg" 증감 표기 |

### 범위 밖 노드 (참조용)

| 요소 | Figma 노드 | 처리 |
|---|---|---|
| 화면 제목 "AI Daily Insights" | `437:26` / 텍스트 `437:28` | 제목 문구는 기획/spec 확정 대상 (문서 미규정) |
| Ask AI Nanny 채팅 영역 | `437:100` | Out of Scope — 별도 feature |
| 하단 탭 네비 (Home/Logs/Insights/Settings) | `437:3` | 앱 셸 — 범위 밖 |

### 피그마 ↔ 문서 불일치 기록

Figma 목업과 이 문서(spec)가 어긋나는 지점. **모두 문서/spec 을 따른다**(위 역할 고정 참조).

| # | Figma 목업 | 문서/spec (채택) | 근거 |
|---|---|---|---|
| A | 배지 = 자기 과거 평균 대비 증감 ("+15ml vs avg") | 배지 = 월령 권장범위 대비 정성 라벨 (적음/적정/많음) | spec FR-003, constitution IV(규칙 SSOT=spec) |
| B | 4번째 카드 = Activities(활동 세션 수, `437:83`) | 4번째 카드 = 깨어있는 시간(`awakeDuration`) | 데이터 레이어 `getSummary` 5슬롯에 Activities 없음 |
| C | 기저귀 = "6 changes" 단일 + 배지 있음 | 기저귀 = 소변+대변 합산 + "소변 n / 대변 m" 보조, 배지 없음 | spec FR-002a·FR-019a |

> **구현 주의**: Figma 노드의 텍스트 문구(배지 값·카드 라벨·단위)를 그대로 베끼지 말 것 — 표시 문구·의미·지표 구성은 이 문서와 spec 이 기준이다. Figma 에서는 **배치·간격·색·아이콘·타이포**만 참조한다.

## Technical Context

- **Language/Version**: Dart (Flutter), strict typing
- **State management / DI**: Provider 기반 DI(`lib/core/config/dependencies.dart`, `lib/main.dart`). ViewModel 은 `ChangeNotifier`, 비동기 상태는 **공통 `ActionState`**(`lib/common/utils/action_state.dart`, `{ idle, loading, success, error }`) 재사용 — onboarding/record_detail 뷰모델과 동일. 아기 전환에 반응하기 위해 화면에서 `ChangeNotifierProxyProvider<CurrentBabyController, AnalyticsViewModel>` 를 사용한다(아래 [Screen 진입점](#screen-진입점--provider-연결))
- **View 제약**: **`StatelessWidget` 만 사용**. `StatefulWidget`·`addListener` 금지 — ViewModel 구독은 `context.watch` / `context.select` 등 Provider 의 도구로만 한다([feedback: no StatefulWidget with Provider])
- **의존**: `AnalyticsRepository`(데이터), `CurrentBabyController`(현재 선택 아기 — `home_data.md`), 디바이스 로컬 타임존/오늘 날짜
- **Testing**: `flutter_test` + `mockito` — 코디네이터(`AnalyticsViewModel`) 단위 테스트(Repository mock 으로 조회·분배·아기 전환 검증) + 카드 ViewModel 단위 테스트(슬롯 → 표시 가공 검증). 기존 `test/presentation/**/*_view_model_test.dart` 관행과 동일
- **Target Platform**: 모바일 앱
- **Project Type**: Mobile app — `lib/presentation` 레이어
- **Constraints**: ViewModel 은 Repository 에만 의존(Service/데이터 소스 비노출), 위젯에 비즈니스 로직 금지, 정성/가공 표현은 ViewModel 에서 산출하고 위젯은 표시만
- **Scale/Scope**: 코디네이터 ViewModel 1 + 카드 ViewModel 4, Screen 1, 카드 위젯 4 + 공통(비교 배지·로딩·에러) 위젯

## Constitution Check

*GATE: 원칙은 [`../constitution.md`](../constitution.md). Presentation 관점 점검.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | 레이어 경계 | ✅ PASS | 코디네이터만 `AnalyticsRepository` 에 의존. 카드 ViewModel·View 는 Repository/Service 미접근. View 는 ViewModel 만 본다. |
| II | 도메인 모델 정책 | ✅ PASS | ViewModel 은 도메인 모델을 입력으로 받아 **표시용 가공값**만 추가로 만든다. UTC→로컬 변환은 표시 계층에서 수행(spec FR-008). |
| III | 오류 처리 | ✅ PASS | Repository 의 `Result<T>` 를 받아 코디네이터의 `ActionState.error` + `ErrorCode` 로 환원. View 는 throw 를 다루지 않음. |
| IV | 비즈니스 규칙 SSOT | ✅ PASS | Presentation 은 계산을 하지 않는다. position→라벨 등 **표현 매핑만** 한다(규칙 SSOT 는 spec). |
| V | 단순성 & 책임 분리 | ✅ PASS | 네트워크 조회/실패는 코디네이터 한 곳, 카드별 표시 가공은 각 카드 ViewModel 한 곳. 위젯은 무상태·표시 전용. 합산(기저귀)·라벨·포맷이 위젯에 흩어지지 않음. |
| VI | 테스트 가능성 | ✅ PASS | 코디네이터의 조회/분배/전환과 카드 ViewModel 의 가공을 mockito 단위 테스트로 검증(AC-P1~P8). |

**Gate Result**: PASS.

## Project Structure

```text
lib/presentation/analytics/
├── view_models/
│   ├── analytics_view_model.dart        # 코디네이터: 요약 1회 조회 + 네트워크 상태 + 카드 VM 4개 소유
│   ├── feeding_card_view_model.dart     # 수유량 카드 VM
│   ├── diaper_card_view_model.dart      # 기저귀 카드 VM (소변+대변 합산/보조)
│   ├── awake_card_view_model.dart       # 깨어있는 시간 카드 VM (배지 없음)
│   ├── sleep_card_view_model.dart       # 총 수면 카드 VM
│   └── metric_card_data.dart            # 카드 표시용 가공 값 객체 (+ MetricBadgeData / ComparisonTone)
├── views/
│   └── analytics_screen.dart            # 분석 탭 진입점 (요약 영역; 채팅 영역은 별도)
└── widgets/
    ├── feeding_card.dart                # 수유량 카드
    ├── diaper_card.dart                 # 기저귀 카드 (합산 + 소변/대변 보조)
    ├── awake_card.dart                  # 깨어있는 시간 카드 (비교 UI 없음)
    ├── sleep_card.dart                  # 총 수면 카드
    ├── metric_comparison_badge.dart     # 적음/적정/많음 배지 (공통)
    └── analytics_summary_states.dart    # 로딩/에러(재시도) 등 영역 단위 상태 위젯

test/presentation/analytics/
└── view_models/
    ├── analytics_view_model_test.dart
    ├── analytics_view_model_test.mocks.dart
    ├── feeding_card_view_model_test.dart
    ├── diaper_card_view_model_test.dart
    ├── awake_card_view_model_test.dart
    └── sleep_card_view_model_test.dart
```

> 별도 `analytics_ui_state.dart` 를 만들지 않는다 — 공통 `ActionState` 로 충분하다. "데이터 없음" 은 네트워크 상태가 아니라 **카드 내용**(아래)으로 다룬다.

**Structure Decision**: 기존 `lib/presentation/<feature>/{view_models,views,widgets}` 패턴(`record_detail`)을 따른다. 네트워크 조회는 코디네이터 1곳, 카드별 표시 가공은 각 카드 ViewModel 로 나눠 카드마다 독립적으로 테스트·확장할 수 있게 한다.

## ViewModel 설계

ViewModel 을 **코디네이터 1개 + 카드 4개**로 나눈다. 역할 경계는 단순하다:

- **코디네이터(`AnalyticsViewModel`)**: 네트워크와 대화하는 유일한 ViewModel. 요약을 **한 번** 조회하고, **로딩/실패 같은 네트워크 상태**를 책임진다. 성공하면 받은 요약을 4개 카드 ViewModel 에 나눠준다.
- **카드 ViewModel 4개**: 네트워크를 모른다. 코디네이터가 건네준 자기 지표 슬롯을 받아 **자기 카드의 표시 내용**(값 포맷·"데이터 없음"·비교 배지)만 만들어 보유한다.

> 데이터 레이어가 요약을 **한 번의 호출(`getSummary`)** 로 5개 지표를 모두 주므로, 네트워크 호출은 코디네이터 한 곳에서만 일어난다. 카드를 4개로 나눈 것은 카드별 **표시 내용**을 독립적으로 관리·테스트하기 위해서지, 카드마다 따로 네트워크를 부르기 위해서가 아니다.

### 코디네이터 — `AnalyticsViewModel`

**역할**: 분석 탭 진입/아기 전환 시 요약을 한 번 조회하고, 그 결과를 카드 ViewModel 들에 분배한다. `ChangeNotifier` 를 상속하고 변경 시 `notifyListeners()` 한다.

**의존성(생성자 주입)**: `AnalyticsRepository`, 로컬 타임존/오늘 날짜 제공자. (현재 선택 아기는 생성자가 아니라 `loadFor(babyId)` 인자로 받는다 — 아래.)

**소유**: 4개 카드 ViewModel(`feedingCard`, `diaperCard`, `awakeCard`, `sleepCard`)을 생성·보유하고 getter 로 노출한다.

**보유 상태(필드)**:

| 필드 | 타입 | 의미 |
|---|---|---|
| `state` | `ActionState` | **네트워크 조회 상태** — `idle` / `loading` / `success` / `error` |
| `errorCode` | `ErrorCode?` | `state == error` 일 때 분기용(`networkError`/`unauthorized`/`parseFailed`/`notFound`) |
| `isLoading` | `bool` (getter) | `state == loading` |
| `feedingCard`/`diaperCard`/`awakeCard`/`sleepCard` | 각 카드 ViewModel | 성공 시 채워지는 4개 카드 |

**동작**:
- `loadFor(String? babyId)` — 현재 선택된 아기 기준으로 요약을 조회한다. 진입 시 1회, **아기가 바뀔 때마다** 호출된다(호출 주체는 아래 Provider 연결). 같은 `babyId` 로 이미 로딩했으면 다시 부르지 않는다(중복 가드).
  - `babyId == null` → 조회하지 않고 빈/안내 상태 처리.
  - `state=loading` → `getSummary(babyId, 로컬 날짜)` → 결과를 상태로 환원하고, 성공 시 5개 슬롯을 4개 카드 ViewModel 에 분배.
- `retry()` — `networkError` 시 마지막 `babyId` 로 `loadFor` 재호출.

**Repository 결과 → 상태 매핑**:

| `Result` | 코디네이터 처리 |
|---|---|
| `ok(summary)` | `state=success`. `feedingCard.bind(summary.feedingVolume)`, `diaperCard.bind(summary.peeCount, summary.poopCount)`, `awakeCard.bind(summary.awakeDuration)`, `sleepCard.bind(summary.totalSleepDuration)` 로 슬롯 분배 |
| `error(notFound)` | `selectedBabyId` stale 신호로 보고 처리(목록 재조회/다른 아기 선택) 후 재로딩 |
| `error(unauthorized)` | `state=error`, `errorCode=unauthorized` → 로그인 유도 |
| `error(networkError)` | `state=error`, `errorCode=networkError` → 재시도 UI |
| `error(parseFailed)` | `state=error`, `errorCode=parseFailed` → 에러 화면 |

- **빈 데이터**(모든 지표 absent)도 **에러가 아니다**. `state == success` 이고 4개 카드 ViewModel 이 모두 "데이터 없음" 으로 채워진다(spec FR-005·FR-020).

### 카드 ViewModel 4개 — 표시 내용 보유

각 카드 ViewModel(`ChangeNotifier`)은 코디네이터가 건네준 도메인 슬롯을 받아 **표시 전용 `MetricCardData`** 로 가공해 보유한다. 네트워크를 호출하지 않으며 Repository 를 모른다.

| 카드 ViewModel | 입력(코디네이터가 `bind`) | 만들어 보유하는 것 |
|---|---|---|
| `FeedingCardViewModel` | `MetricComparison?` (`feedingVolume`) | "750 ml" + 비교 배지(reference 있으면) / 없으면 "데이터 없음" |
| `DiaperCardViewModel` | `MetricComparison?` 2개 (`peeCount`, `poopCount`) | 합산 타이틀("7.0 회") + 보조("소변 5.2 / 대변 1.8"). 배지 없음. 둘 다 absent → "데이터 없음" |
| `AwakeCardViewModel` | `MetricComparison?` (`awakeDuration`) | "1시간 20분". **배지 절대 없음**(spec FR-019a) / 없으면 "데이터 없음" |
| `SleepCardViewModel` | `MetricComparison?` (`totalSleepDuration`) | "13시간 30분" + 비교 배지(reference 있으면) / 없으면 "데이터 없음" |

**공통 표시 규칙**:
- **정성 라벨/배지**: `ComparisonPosition` → `below`="권장보다 적음/짧음", `within`="적정", `above`="권장보다 많음/김"(문구·색상은 디자인 토큰). 카드 ViewModel 이 이 매핑을 수행한다.
- **비교 생략**: `MetricComparison.reference == null`(=`position == null`)이면 배지를 만들지 않고 값만 보유. `awakeDuration` 은 항상 값만.
- **포맷**: 수면/깨어있는 시간은 분→"N시간 M분", 횟수는 평균이라 소수 1자리 등. 시각/날짜는 로컬 타임존 기준(spec FR-008). 모든 가공은 카드 ViewModel 이 만들고 위젯은 표시만.

## View 설계 — 위젯 구성과 UI 계약

여기서는 ① 화면이 어떤 위젯으로 구성되는지(**위젯 구성**)와 ② View 가 ViewModel 을 어떻게 구독/호출하는지(**View ↔ ViewModel 계약**)를 규정한다. "런타임에 무엇이 순서대로 일어나는가" 는 [동작 방식(시퀀스)](#동작-방식-시퀀스)를 본다.

### 위젯 구성 (composition)

화면 진입점은 `AnalyticsScreen` 이며, 그 아래 **요약 영역**(본 plan)과 **채팅 영역**(별도 feature)이 세로로 놓인다. 모든 위젯은 `StatelessWidget` 이고, ViewModel 구독은 `context.watch` 로만 한다([feedback: no StatefulWidget with Provider]).

```text
AnalyticsScreen (StatelessWidget)                       ← 진입점
└── ChangeNotifierProxyProvider<CurrentBabyController, AnalyticsViewModel>
    │                                                   ← 코디네이터를 만들어 화면에 제공.
    │                                                     선택 아기가 바뀌면 loadFor(새 babyId) 호출
    └── _AnalyticsView (StatelessWidget)                ← 요약/채팅 영역 배치
        ├── _AnalyticsSummarySection                    ← [본 plan] context.watch<AnalyticsViewModel>().state 로 분기
        │     ├── loading  → 로딩 인디케이터(영역 단위)
        │     ├── error    → AnalyticsErrorState(errorCode, onRetry: vm.retry)
        │     └── success  → _SummaryCards
        │            │      (코디네이터의 4개 카드 VM 을 ChangeNotifierProvider.value 로 제공)
        │            ├── FeedingCard   → watch<FeedingCardViewModel>()
        │            ├── DiaperCard    → watch<DiaperCardViewModel>()
        │            ├── AwakeCard     → watch<AwakeCardViewModel>()
        │            └── SleepCard     → watch<SleepCardViewModel>()
        │                   └── (수유량·총 수면 카드 내부) MetricComparisonBadge   // badge != null 일 때만
        └── _AnalyticsChatSection                       ← [별도 feature] 본 plan 범위 밖(placeholder)
```

- **로딩/에러는 영역 단위**(코디네이터 `state`)로 한 번 처리한다. 4개 카드는 조회가 **성공한 뒤에만** 그려지며, 그때 각 카드는 자기 카드 ViewModel 의 내용을 본다.
- 각 위젯의 시각(레이아웃·색·아이콘) 기준은 [디자인 참조(Figma) 노드 매핑](#디자인-참조-figma--노드-매핑)을 본다 — 단, 표시 문구·지표 구성은 이 문서/spec 이 기준이다.

### Screen 진입점 — Provider 연결

먼저 용어 정리:
- **전역 Provider**: 앱 시작 시 `dependencies.dart` 에서 한 번 등록되어 앱 어디서나 쓰는 객체들 — `AnalyticsRepository`, `CurrentBabyController` 등. 화면이 살아있는 동안만 필요한 게 아니라 앱 전체에서 공유된다.
- **화면 단위 ViewModel**: 이 화면에서만 쓰는 `AnalyticsViewModel` + 카드 VM 들. **`AnalyticsScreen` 이 만들고 소유**하며, 화면이 사라지면(dispose) 함께 정리된다.

`AnalyticsScreen` 이 `ChangeNotifierProxyProvider` 를 리턴하는 것 자체가 곧 **"이 화면 하위 위젯들이 `AnalyticsViewModel` 을 꺼내 쓸 수 있게 해주는" 행위**다(= 주입). 그래서 화면 단위 ViewModel 은 `dependencies.dart` 에 등록하지 않는다 — 화면이 직접 만든다. 그 ViewModel 이 필요로 하는 전역 객체(`AnalyticsRepository`)는 `context.read` 로 꺼내 생성자에 넘겨준다.

`ChangeNotifierProxyProvider` 를 쓰는 이유는 **선택된 아기가 바뀌면 자동으로 다시 조회**하기 위해서다. `create` 는 코디네이터를 한 번 만들고, `update` 는 진입 시 + `CurrentBabyController` 가 바뀔 때마다 실행되어 `loadFor(현재 babyId)` 를 호출한다. 즉 "조회"는 진입 1회로 끝나는 게 아니라 **항상 현재 선택된 아기를 따라간다**.

```dart
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<CurrentBabyController, AnalyticsViewModel>(
      create: (context) => AnalyticsViewModel(
        analyticsRepository: context.read<AnalyticsRepository>(),
        // 로컬 타임존/오늘 날짜 제공자 주입
      ),
      // 진입 시 + 선택 아기가 바뀔 때마다 호출됨
      update: (context, currentBaby, viewModel) =>
          viewModel!..loadFor(currentBaby.selectedBabyId),
      child: const _AnalyticsView(),
    );
  }
}
```

- `loadFor` 안의 중복 가드 덕분에, 아기와 무관한 rebuild 로 `update` 가 다시 불려도 같은 `babyId` 면 재조회하지 않는다.
- View 는 `AnalyticsRepository` 를 **직접 호출하지 않는다** — 코디네이터 생성자에 한 번 넘겨줄 뿐, 데이터 접근은 전적으로 ViewModel 책임.

### View ↔ ViewModel UI 계약

**View 가 ViewModel 에서 읽는 것 (구독, read-only):**

| 노출 위치 | 노출 | 타입 | View 의 사용 |
|---|---|---|---|
| 코디네이터 | `state` (또는 `isLoading`) | `ActionState` | 영역 단위 loading / error / success 분기 |
| 코디네이터 | `errorCode` | `ErrorCode?` | `error` 일 때 분기(로그인 유도 / 재시도 / 에러 화면) |
| 각 카드 VM | `card` | `MetricCardData` | 카드 1장의 값·"데이터 없음"·배지 렌더 |

**View 가 ViewModel 에 호출하는 것 (intent):**

| 호출 | 시점 | 비고 |
|---|---|---|
| `loadFor(babyId)` | `ProxyProvider.update` (진입 + 아기 전환) | View 코드가 명시적으로 부르지 않는다 — Provider 가 선택 아기 변화를 따라 호출 |
| `retry()` | `networkError` 화면의 "다시 시도" 탭 | 마지막 `babyId` 로 재조회 |

**계약 불변식 (경계 규칙):**

- View 는 `AnalyticsSummary`·`MetricComparison`·`ReferenceRange`·`ComparisonPosition` 등 **데이터/도메인 타입을 직접 만지지 않는다.** 카드 ViewModel 이 슬롯 → 표시 전용 `MetricCardData` 로 가공을 끝낸 뒤 노출하고, 위젯은 그 안의 값만 그린다([constitution Principle I·V](../constitution.md)).
- **아기 전환은 View 의 책임이 아니다.** 화면의 `ChangeNotifierProxyProvider` 가 `CurrentBabyController` 변화를 받아 코디네이터의 `loadFor` 를 부른다 — 위젯은 `addListener` 를 쓰지 않고, 갱신 결과(loading→success/error)만 `watch` 로 받는다.
- `error(notFound)` 는 화면에 직접 노출되지 않는다 — 코디네이터가 `selectedBabyId` stale 처리 후 재로딩하므로, View 는 그 사이의 loading/최종 상태만 본다.

### 표시 전용 계약 객체 — `MetricCardData` / `MetricBadgeData`

카드 위젯이 받는 표시 전용 불변 값 객체다. 합산·라벨·포맷·"데이터 없음" 판정은 **이미 카드 ViewModel 이 끝낸** 상태로 들어오며, 위젯은 분기 없이 그대로 그린다.

```dart
/// 카드 1개의 표시 데이터. 카드 ViewModel 이 만들어 보유하고 카드 위젯이 읽는다.
class MetricCardData {
  final String title;          // 카드 제목 (예: "평균 하루 수유량")
  final bool hasValue;         // false → 카드 안에서 "데이터 없음" 표시
  final String? valueText;     // 포맷된 대표 수치 (예: "750 ml", "13시간 30분"). hasValue=false면 null
  final String? subtitle;      // 보조 설명 (기저귀: "소변 5.2 / 대변 1.8"). 없으면 null
  final MetricBadgeData? badge;// 권장 범위 비교 배지. null → 배지 미표시(비교 불가 또는 깨어있는 시간/기저귀)
}

/// 권장 범위 비교 배지의 표시 데이터.
class MetricBadgeData {
  final ComparisonTone tone;   // below | within | above — 색/톤 결정용 표시 enum(도메인 비노출)
  final String label;          // 표시 문구 (예: "권장보다 적음" / "적정" / "권장보다 많음")
}
```

- `badge` 는 `MetricComparison.reference`(=`position`)가 있을 때만 카드 ViewModel 이 채운다. `awakeDuration`·기저귀 카드는 **항상 `badge == null`** — 위젯이 별도 분기하지 않아도 배지가 그려지지 않는다.
- `ComparisonTone` 은 도메인 `ComparisonPosition` 을 View 색상 토큰으로 옮긴 **표시 전용 enum** 이다 — View 가 도메인 enum 을 import 하지 않도록 카드 ViewModel 이 변환한다.

### 위젯별 책임

| 위젯 | 구독/입력 | 책임 (무상태·표시 전용) |
|---|---|---|
| `AnalyticsScreen` | — | 코디네이터 생성·제공, 선택 아기 변화에 `loadFor` 연결, 요약/채팅 영역 배치 |
| `_AnalyticsSummarySection` | `watch<AnalyticsViewModel>().state` | `state` 로 loading/error/success 분기, 성공 시 카드 VM 들을 제공 |
| `_SummaryCards` | — | 4개 카드 위젯을 **항상** 배치(absent 라고 숨기지 않음) |
| `FeedingCard` / `SleepCard` | `watch<…CardViewModel>().card` | 제목+`valueText`, `badge` 있으면 배지. `hasValue=false`면 "데이터 없음" |
| `DiaperCard` | `watch<DiaperCardViewModel>().card` | 합산 타이틀(`valueText`) + `subtitle`("소변 n / 대변 m"). 문구는 이미 가공됨 |
| `AwakeCard` | `watch<AwakeCardViewModel>().card` | 제목+`valueText` 만. 배지 자리 없음 |
| `MetricComparisonBadge` | `MetricBadgeData` | `tone` 색 + `label` 표시 |
| `AnalyticsErrorState` | `errorCode`, `onRetry` | 에러 문구 + (`networkError`) "다시 시도" 버튼 → `onRetry` |

## 동작 방식 (시퀀스)

```
[분석 탭 진입]
1. AnalyticsScreen 빌드 → ChangeNotifierProxyProvider 가 코디네이터 생성
2. update 콜백이 loadFor(현재 selectedBabyId) 호출
   → state=loading → getSummary(babyId, 로컬 날짜)
3. _AnalyticsSummarySection 이 state 로 렌더 분기:
   - loading              → 로딩 인디케이터(영역)
   - error(network)       → AnalyticsErrorState + 재시도(retry)
   - error(unauthorized)  → 로그인 화면 이동
   - error(parseFailed)   → 에러 화면
   - success              → 코디네이터가 4개 카드 VM 에 슬롯 분배 →
                            _SummaryCards 가 4개 카드 렌더(각 카드는 값 또는 "데이터 없음")
                            (모든 지표 absent 면 4개 카드 모두 "데이터 없음")

[아기 전환]
1. (다른 화면/위젯에서) CurrentBabyController.select(newId) → notifyListeners()
2. ProxyProvider.update 재실행 → 코디네이터.loadFor(newId)
3. babyId 가 바뀌었으므로 재조회 → 진입과 동일하게 state/카드 갱신
   (babyId 가 같으면 중복 가드로 재조회 안 함)
```

## 검증 / 테스트 (AC — Presentation 단위)

> 코디네이터는 `AnalyticsRepository` mock 으로, 카드 ViewModel 은 도메인 슬롯을 직접 주입해 검증한다.

**코디네이터(`AnalyticsViewModel`)**
- **AC-P1**: `loadFor(babyId)` 성공 시 `state == success` 이고, 4개 카드 VM 에 슬롯이 분배된다(수유량·기저귀(소변+대변)·깨어있는 시간·총 수면).
- **AC-P2**: 모든 지표 absent 인 성공 응답 → `state == success` 이고 4개 카드 VM 이 모두 `hasValue == false`(에러 아님, 카드 숨김 아님).
- **AC-P6**: Repository 가 `networkError`/`unauthorized`/`parseFailed` → `state == error` 이고 `errorCode` 가 그대로 노출된다(각 분기 화면 결정 가능).
- **AC-P7**: 선택 아기가 바뀌어 `loadFor(newId)` 가 호출되면 새 `babyId` 로 `getSummary` 가 재호출되고 상태/카드가 갱신된다. **같은 `babyId` 면 재조회하지 않는다**(중복 가드).
- **AC-P8**: `retry()` 는 마지막 `babyId` 로 `loadFor` 를 재호출한다.

**카드 ViewModel**
- **AC-P3**: `DiaperCardViewModel` 은 소변·대변 평균을 합산해 타이틀을, "소변 n / 대변 m" 보조를 만든다. 한쪽만 absent 면 있는 쪽만 표시하고 없는 쪽을 "데이터 없음" 표기, 둘 다 absent 면 `hasValue == false`.
- **AC-P4**: `AwakeCardViewModel` 은 reference 유무와 무관하게 비교 배지를 만들지 않는다(`badge == null`).
- **AC-P5**: 카드 ViewModel 은 `position` 이 `below`/`within`/`above` 일 때 각각의 라벨/톤 배지로 매핑하고, `position == null`(또는 reference 없음)이면 배지가 없다.

## 파일 추가/수정 예상 목록

**추가**
- `lib/presentation/analytics/view_models/analytics_view_model.dart` (코디네이터)
- `lib/presentation/analytics/view_models/{feeding,diaper,awake,sleep}_card_view_model.dart`
- `lib/presentation/analytics/view_models/metric_card_data.dart` (`MetricCardData`/`MetricBadgeData`/`ComparisonTone`)
- `lib/presentation/analytics/views/analytics_screen.dart`
- `lib/presentation/analytics/widgets/{feeding_card,diaper_card,awake_card,sleep_card,metric_comparison_badge,analytics_summary_states}.dart`
- `test/presentation/analytics/view_models/analytics_view_model_test.dart`
- `test/presentation/analytics/view_models/{feeding,diaper,awake,sleep}_card_view_model_test.dart`

**수정**
- `lib/core/config/dependencies.dart` — `AnalyticsService`/`AnalyticsRepository` **전역** 등록(화면 단위 ViewModel 은 `AnalyticsScreen` 이 직접 생성하므로 여기 등록하지 않음)
- `lib/routing/router.dart` — 분석 탭 라우트(요약 영역) 연결

## Out of Scope

- 분석 탭의 **AI 채팅 영역** — 별도 spec/plan.
- 데이터 레이어(Repository/Service/도메인 모델) — [analytics_data.md](./analytics_data.md).
- 권장치 수치/비교 규칙 자체 — spec(SSOT).
