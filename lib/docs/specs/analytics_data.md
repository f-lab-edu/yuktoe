# 📊 분석 탭 — 통계 요약 Data Layer 스펙

본 문서는 분석 탭이 보여주는 **통계 요약(statistics summary)** 의 Data Layer 스펙이다.

---

## 1. 스코프

- **이 문서 범위**:
    - 분석 탭의 통계 요약이 필요로 하는 **Data Layer** (Repository / Service / 도메인 모델).
    - 요약 지표의 **계산 규칙**(무엇을 어떻게 집계하는지에 대한 비즈니스 규칙).
    - **월령 레퍼런스(권장치) 비교** 규칙.
    - 요약 데이터의 **캐시 / 재계산** 비즈니스 규칙.
- **이 문서 범위 아님**:
    - 분석 탭의 화면(위젯 / ViewModel) 등 Presentation Layer. §11 "호출자 동작 시퀀스" 는 호출자(= ViewModel) 관점 참고용.
    - AI 채팅 기능 전체.
    - 정성적 표현("살짝 짧음" 등) — Presentation 의 책임(§6.4).
    - 구체적 기술 스택 / 구현(별도 plan 문서).

---

## 2. 레이어 구조

```
┌───────────────────────────────┐
│  AnalyticsViewModel  (별도)   │
└──────────────┬────────────────┘
               │ depends on
               ▼
        ┌──────────────────┐
        │ AnalyticsRepo    │
        └────────┬─────────┘
                 ▼
        ┌──────────────────┐
        │ AnalyticsService │
        └────────┬─────────┘
                 ▼
        ┌─────────────────────────────┐
        │ 원격 백엔드                  │
        │  - 기록(care record) 집계    │
        │  - 월령 레퍼런스(권장치)     │
        └─────────────────────────────┘
```

- ViewModel 은 **`AnalyticsRepository`** 만 의존한다. Service / 백엔드 클라이언트는 ViewModel 에 노출되지 않는다.
- Repository 는 도메인 모델 + `Result<T>` 만 노출한다. DB 응답 원본 / `Map<String, dynamic>` / DTO 가 Repository 경계 밖으로 나가서는 안 된다. (기존 `home_data` 스펙과 동일한 경계 규칙.)
- **요약 계산의 주체는 백엔드다.** 클라이언트는 계산된 요약을 조회(GET)할 뿐, raw 기록을 받아 직접 집계하지 않는다.
    - **왜**: ①집계는 윈도우 스캔 + 월령 레퍼런스 조인이라 서버에서 처리하는 편이 자연스럽고, 클라이언트가 레퍼런스 테이블 전체나 대량의 raw 기록을 받을 필요가 없다. ②요약 값과 레퍼런스 비교가 한 곳(서버)에서 일관되게 산출된다. ③클라이언트는 "요약 모델" 이라는 안정적 계약만 검증하면 된다.
- **월령 레퍼런스(권장치) 데이터**는 운영자가 관리하는 정적 시드 데이터다(§4.6). 권위 있는 출처(NSF / AAP 가이드라인 등)를 근거로 구성하며, 갱신은 운영자가 시드를 업데이트하는 방식이다. 클라이언트는 이 테이블을 직접 조회하지 않는다 — 백엔드가 요약 응답에 비교 결과를 담아 내려준다(§6).

---

## 3. 용어 정의

문서 전체에서 아래 용어를 일관되게 사용한다.

| 용어 | 정의 |
|---|---|
| **로컬 날짜 / 로컬 자정** | 요청을 보낸 디바이스의 로컬 타임존 기준 날짜와 그 날의 00:00. 모든 "하루" 경계는 로컬 자정이다(§5.1 "왜"). 도메인 모델의 시각은 UTC 로 저장되지만, **일 단위 집계의 경계는 로컬 타임존을 적용**한다. |
| **오늘(today)** | 요청 시점의 로컬 날짜. |
| **완성된 날(completed day)** | 오늘보다 **이전**인 로컬 날짜. 오늘은 아직 진행 중이므로 일 단위 평균에서 제외한다. |
| **윈도우(window)** | 평균 계산의 대상이 되는 완성된 날들의 집합. 정의는 §5.0. |
| **수유(feeding)** | 분석 탭의 수유 지표가 대상으로 삼는 기록 카테고리. `breast`, `formula`, `pumpingFeed`, `babyFood` **4종**. `pumping`(유축) · `snack`(간식) · `water`(물)는 **어떤 요약 지표에도 포함하지 않는다**(§5). |
| **월령(month age)** | 비교 기준이 되는 아기의 개월 수. 미숙아는 교정연령을 사용한다(§4.5). |
| **월령 구간(month band)** | 레퍼런스 테이블에서 권장치를 찾기 위한 개월 수 구간(예: 4~11개월). 구체 경계는 시드 데이터가 정한다. |
| **권장 범위(reference range)** | 특정 월령 구간 × 특정 지표에 대한 권장치. 단일 값이 아니라 **`[min, max]` 범위**다(§4.4). |

기록 도메인 모델(`CareRecord`, `RecordDetailData` 및 그 변종, `RecordType`, `DiaperType`, `SleepType`)의 정의는 `home_data.md` §3 을 따른다. 본 문서는 그 모델을 입력으로 삼는다.

---

## 4. 도메인 모델 요구사항

### 4.1 모델 공통 정책

기존 도메인 모델 정책(`home_data.md` §3.1)을 그대로 따른다.

- **immutable**: 모든 필드 `final`. 변경은 `copyWith`.
- **시각은 UTC**: 모델이 보유하는 모든 `DateTime` 은 UTC. 로컬 변환은 화면 계층 책임.
- 본 문서의 요약 모델은 **계산 결과를 담는 값 객체**다. 자체적으로 어떤 계산도 수행하지 않는다(계산은 백엔드, §2). 모델은 "이미 계산된 수치 + 비교 결과" 만 보유한다.

### 4.2 `AnalyticsSummary` — 분석 탭 요약 집계

한 아기에 대한, 현재 윈도우 기준의 요약 한 묶음.

| 필드 | 타입 | 의미 |
|---|---|---|
| `babyId` | String | 이 요약이 어떤 아기의 것인지. `Baby.id` 와 같은 종류의 id. |
| `feedingVolume` | `MetricComparison?` | 분유 + 유축수유 합산 1일 총량(ml)의 평균. §5.1. |
| `babyFoodVolume` | `MetricComparison?` | 이유식 1일 총량(ml)의 평균. §5.2. |
| `breastLeftMinutes` | `MetricComparison?` | 모유 왼쪽 1일 총 수유시간(분)의 평균. §5.3. |
| `breastRightMinutes` | `MetricComparison?` | 모유 오른쪽 1일 총 수유시간(분)의 평균. §5.3. |
| `peeCount` | `MetricComparison?` | 1일 소변 기저귀 횟수의 평균. §5.4. |
| `poopCount` | `MetricComparison?` | 1일 대변 기저귀 횟수의 평균. §5.4. |
| `awakeDuration` | `MetricComparison?` | 1회 깨어있던 구간 길이(분)의 평균. §5.5. |
| `totalSleepDuration` | `MetricComparison?` | 1일 총 수면시간(분)의 평균. §5.6. |

**지표 슬롯의 nullability 의미**:

- 각 지표 슬롯이 **`null`(absent)** 이면, 윈도우 안에 그 지표를 산출할 데이터가 없다는 뜻이다(예: 6개월 미만 아기의 `babyFoodVolume`, 수유 기록이 한 건도 없는 경우의 `feedingVolume`). 이때 Presentation 은 그 항목을 표시하지 않는다.
- 지표 슬롯이 존재(non-null)하면 `MetricComparison.value` 는 항상 산출된 값(non-null)이다.
- 지표 슬롯 8개는 **각각 독립적으로** 존재 / absent 가 결정된다. 한 지표가 absent 라고 다른 지표가 함께 사라지지 않는다.

**동일성**: 본 모델은 식별자 한 개로 환원되지 않는 집계 결과다. `==` / `hashCode` 의 구현 방식은 본 스펙이 강제하지 않는다(필요 시 구현 문서에서 결정).

### 4.3 `MetricComparison` — 한 지표의 값 + 권장 범위 비교

| 필드 | 타입 | 의미 |
|---|---|---|
| `value` | double | 윈도우에 대해 산출된 내 아기의 값. 단위는 지표마다 다름(§5). non-null. 평균이므로 정수 지표(횟수 등)도 소수가 될 수 있다. |
| `reference` | `ReferenceRange?` | 해당 월령 구간 × 이 지표의 권장 범위. **월령을 산출할 수 없거나(예: `birthDate` 없음) 매칭되는 월령 구간이 없으면 `null`** (§4.5, §6.2). |
| `position` | `ComparisonPosition?` | 내 값이 권장 범위 대비 어디에 있는지(below / within / above). **`reference == null` 이면 함께 `null`** (비교 불가). |

**규칙**:

- `reference != null ⟺ position != null`. 둘은 같이 존재하거나 같이 없다. 권장 범위가 있으면 비교 결과(position)도 반드시 계산되고, 없으면 둘 다 없다.
- `value` 만 있고 `reference`/`position` 이 없는 상태는 **정상**이다(값은 보여주되 권장치 비교는 못 하는 경우, §6.2).
- `MetricComparison` 은 **수치만** 보유한다. "살짝 짧음 / 충분함" 같은 **정성적 라벨은 보유하지 않는다** — 그 해석은 Presentation 의 책임이다(§6.4).

### 4.4 `ReferenceRange` — 권장 범위

| 필드 | 타입 | 의미 |
|---|---|---|
| `min` | double | 권장 범위 하한(포함). |
| `max` | double | 권장 범위 상한(포함). |

**불변식**: 항상 `min <= max`. 단위는 비교 대상 지표와 동일하다(예: `totalSleepDuration` 의 reference 는 분 단위). 권장치가 본질적으로 단일 값인 지표라도 본 모델에서는 `min == max` 인 범위로 표현한다 — 모든 지표의 권장치를 **범위로 통일**한다.

### 4.5 `ComparisonPosition` — 범위 대비 위치 (enum)

| 값 | 의미 |
|---|---|
| `below` | `value < reference.min`. 권장 범위보다 적음 / 짧음. |
| `within` | `reference.min <= value <= reference.max`. 권장 범위 안. |
| `above` | `value > reference.max`. 권장 범위보다 많음 / 김. |

- 경계값(`value == min` 또는 `value == max`)은 `within` 으로 본다(범위는 양 끝 포함).
- 본 enum 은 사실 분류이며 결정론적으로 계산된다. "얼마나" 의 정도(거리)는 Presentation 이 `value` 와 `reference` 로부터 직접 표현한다 — 본 Data Layer 는 별도의 거리 / 비율 필드를 노출하지 않는다.

### 4.6 월령 레퍼런스 데이터 (개념)

- **월령 구간 × 지표** 를 키로 하는 **권장 범위(`[min, max]`)의 정적 테이블**이다. 8개 요약 지표 전부에 대해 모든 월령 구간에 권장 범위가 존재한다.
- 운영자가 관리하는 시드 데이터이며, 권위 있는 출처(NSF / AAP 가이드라인 등)를 근거로 구성한다. 갱신은 운영자가 시드를 업데이트하는 방식이다.
- 클라이언트 도메인 모델에는 이 테이블 자체가 노출되지 않는다. 백엔드가 요약 계산 시 해당 아기의 월령 구간에 맞는 권장 범위를 조인하여 각 `MetricComparison.reference` 에 채워 내려준다(§6).
- 구간 경계(예: 0~3개월, 4~11개월 등)는 시드 데이터가 정의하며 본 스펙이 고정하지 않는다.

### 4.7 월령(비교 기준 나이) 산정 규칙

비교에 사용할 월령은 아기의 출생 정보로부터 다음과 같이 산정한다.

1. **미숙아 판정**: `birthDate` 와 `dueDate` 가 모두 존재하고 `dueDate − birthDate > 21일(3주)` 이면 **미숙아**로 본다(만삭 40주 기준, 37주 미만 출생).
2. **기준 시점(anchor)**:
    - 미숙아 → `dueDate` 기준(**교정연령**).
    - 미숙아 아님(또는 `dueDate` 가 `null` 이라 미숙아 판정 불가) → `birthDate` 기준.
3. **월령 = anchor 로부터 오늘(로컬)까지의 경과 개월 수**(완성된 개월, 내림).
4. **`birthDate` 가 `null`** 이면 월령을 산출할 수 없다 → 모든 지표의 `reference` / `position` 은 `null`(값만 산출, 비교 없음).
5. **교정연령이 음수**(예: 매우 이른 미숙아가 아직 출산 예정일 전)이면 월령 0(가장 어린 구간)으로 본다.
6. 산정된 월령에 **매칭되는 월령 구간이 테이블에 없으면**(예: 테이블 상한을 넘는 나이) 해당 비교는 불가 → `reference` / `position` 은 `null`.

> **왜 교정연령인가**: 미숙아는 같은 생후 개월이라도 발달이 만삭아와 다르므로, 권장 수면 / 수유 등의 비교 기준을 교정연령으로 맞춰야 비교가 의미를 가진다.

---

## 5. 지표별 계산 규칙

> 본 절의 규칙은 **비즈니스 규칙**이다. 실제 집계는 백엔드가 수행하지만, "무엇이 옳은 값인가" 의 정의는 본 스펙이 SSOT 다. 각 규칙은 테스트로 검증 가능해야 한다(§12).

### 5.0 윈도우 정의 (모든 일 단위 지표 공통)

- **기본**: 윈도우 = **오늘(로컬)을 제외한 직전 7개 로컬 날** 중 데이터가 존재하는 날들. (`[오늘−7일, 오늘)` 의 완성된 날들.) 항상 **완성된 날만** 사용한다.
- **데이터가 7일 미만**: 아기의 **첫 기록**(가장 오래된 기록)의 로컬 날짜부터 어제까지가 7일 미만이면, 존재하는 그 일수만큼만 사용한다. 완성된 날이 하루뿐이면 그 하루로 계산한다("데이터가 하루치밖에 없을 때는 하루 데이터" 요구를 충족).
- **완성된 날이 하나도 없으면**(데이터가 전혀 없거나 **오늘 데이터만 존재**): 윈도우가 비고, 모든 지표 슬롯은 absent (§4.2). 이 경우 요약은 성공으로 반환되며, 화면 미표시 등의 처리는 **Presentation 의 책임**이다.

**"오늘 제외" 의 왜**: 오늘은 아직 진행 중이라 일 총량이 과소 집계되어 평균을 왜곡한다. 완성된 날만 평균에 넣어야 일 단위 비교가 정확하다.

**일 단위 지표의 분모(평균을 나누는 날 수)**: 각 지표는 **윈도우 날들 중 그 지표 타입의 기록이 1건 이상 있는 날의 수**로 나눈다(지표별 독립).
- **왜**: 기록 누락이 흔한 육아 앱 특성상, 그 활동을 기록하지 않은 날까지 0 으로 분모에 넣으면 평균이 부당하게 낮아진다. "기록한 날들의 평균" 이 사용자 직관("며칠동안 기록한 걸 평균")과 일치한다.
- 한 지표 타입의 기록이 윈도우에 1건도 없으면 그 지표 슬롯은 absent.

### 5.1 수유량 — 분유 + 유축수유 (ml)

| 항목 | 규칙 |
|---|---|
| 대상 타입 | `formula`, `pumpingFeed` **2종을 합산**. |
| 단위 | ml. |
| 일 집계 | 한 로컬 날의 모든 `formula.amountMl` + `pumpingFeed.amountMl` 합. (날짜 귀속: 각 기록의 `occurredAt` 로컬 날짜.) |
| 평균 | (윈도우 각 날의 일 합) 의 평균. 분모 = 윈도우 중 `formula` 또는 `pumpingFeed` 기록이 1건 이상 있는 날 수. |
| absent 조건 | 윈도우에 `formula`/`pumpingFeed` 기록이 한 건도 없음. |

### 5.2 수유량 — 이유식 (ml)

| 항목 | 규칙 |
|---|---|
| 대상 타입 | `babyFood` 단독(분유 / 유축수유와 **합산하지 않음**). |
| 단위 | ml(`babyFood.amountMl`). |
| 일 집계 | 한 로컬 날의 모든 `babyFood.amountMl` 합. 날짜 귀속: `occurredAt` 로컬 날짜. |
| 평균 | (윈도우 각 날의 일 합) 의 평균. 분모 = 윈도우 중 `babyFood` 기록이 1건 이상 있는 날 수. |
| absent 조건 | 윈도우에 `babyFood` 기록 없음. **보통 6개월 이후에야 시작**하므로 그 이전 아기는 자연히 absent (정상). |

### 5.3 모유 — 좌 / 우 수유시간 (분)

| 항목 | 규칙 |
|---|---|
| 대상 타입 | `breast`. |
| 단위 | 분(minute). 좌(`leftMinutes`) / 우(`rightMinutes`) **각각 별도 지표**. |
| null 처리 | `leftMinutes` / `rightMinutes` 가 `null`("해당 쪽 수유 안 함") 이면 **0분으로 포함**한다(`0`/`null` 구분 없이 0 취급). |
| 일 집계 | 한 로컬 날의 모든 `breast.leftMinutes` 합 / `rightMinutes` 합(각각). 날짜 귀속: `breast.occurredAt`(= `startedAt`) 로컬 날짜. |
| 평균 | (윈도우 각 날의 좌 / 우 일 합) 의 평균. 분모 = 윈도우 중 `breast` 기록이 1건 이상 있는 날 수(좌 / 우 동일 분모). |
| absent 조건 | 윈도우에 `breast` 기록 없음 → `breastLeftMinutes`, `breastRightMinutes` 둘 다 absent. |

### 5.4 기저귀 — 소변 / 대변 횟수

| 항목 | 규칙 |
|---|---|
| 대상 타입 | `diaper`. |
| 카운팅 | `DiaperType.pee` → 소변 +1. `DiaperType.poop` → 대변 +1. **`DiaperType.mixed` → 소변 +1 그리고 대변 +1**(양쪽 모두 카운트). |
| 단위 | 1일 횟수(평균이므로 소수 가능). 소변(`peeCount`) / 대변(`poopCount`) 각각 별도 지표. |
| 일 집계 | 한 로컬 날의 소변 카운트 / 대변 카운트(각각). 날짜 귀속: `diaper.occurredAt` 로컬 날짜. |
| 평균 | (윈도우 각 날의 소변 / 대변 카운트) 의 평균. 분모 = 윈도우 중 `diaper` 기록이 1건 이상 있는 날 수(소변 / 대변 동일 분모). |
| absent 조건 | 윈도우에 `diaper` 기록 없음 → `peeCount`, `poopCount` 둘 다 absent. |

### 5.5 깨어있는 시간 (분, 구간 평균)

| 항목 | 규칙 |
|---|---|
| 정의 | **수면과 수면 사이 1회 깨어있던 구간**들의 길이 평균. **일 단위 집계가 아니다**(구간 단위). |
| 대상 | `sleep` 기록. |
| 구간(gap) | 시간순으로 연속한 두 수면에 대해 `이전 수면.endedAt → 다음 수면.startedAt` 사이의 길이(분). |
| 윈도우 귀속 | 수면을 윈도우에 귀속시키는 날짜는 **`startedAt` 의 로컬 날짜**(§5.6 의 수면 날짜 귀속과 동일 기준). 윈도우에 귀속된 수면들로 gap 을 만든다. |
| 겹침 처리 | 두 수면이 겹쳐 gap 이 **음수**가 되면 그 gap 은 계산에서 **제외**한다. |
| 평균 | 유효한 gap 들의 평균. 분모 = 유효 gap 개수. |
| absent 조건 | 윈도우에 유효한 gap 이 **하나도 없으면**(수면이 0~1건이거나 모든 gap 이 음수) absent. |

### 5.6 총 수면시간 (분, 1일 평균)

| 항목 | 규칙 |
|---|---|
| 정의 | 낮잠(`nap`) + 밤잠(`night`) 을 포함한 1일 총 수면시간(분) 의 평균. |
| 대상 | `sleep` 기록(`sleepType` 무관, 둘 다 포함). |
| 1건의 길이 | `endedAt − startedAt`(분). (`SleepDetail.endedAt` 은 항상 non-null, `home_data.md` §3.3.) |
| 날짜 귀속 | 수면은 **`startedAt` 의 로컬 날짜**에 **전체 길이**를 귀속한다. 자정을 걸쳐도 분할하지 않는다. <br>예: 6/14 낮잠 2시간 + 6/14 20:00~6/15 08:00(12시간) → 6/14 총 수면 = 14시간. |
| 일 집계 | 한 로컬 날에 귀속된 모든 수면 길이의 합. |
| 평균 | (윈도우 각 날의 일 총 수면) 의 평균. 분모 = 윈도우 중 (`startedAt` 기준) `sleep` 기록이 1건 이상 귀속된 날 수. |
| absent 조건 | 윈도우에 `sleep` 기록 없음. |

---

## 6. 레퍼런스 비교 규칙

### 6.1 비교 결과의 위치

- 비교는 요약 **GET 응답에 함께 포함**된다. 백엔드가 해당 아기의 월령 구간(§4.7)에 맞는 권장 범위를 조인하여, 각 지표의 `MetricComparison.reference` 와 `position` 을 채워 내려준다.
- 클라이언트는 레퍼런스 테이블을 별도로 조회하지 않는다(§2).
- `position` 은 §4.5 의 규칙으로 결정된다.

### 6.2 비교 불가 케이스

다음 경우 `reference` / `position` 은 `null` 이며, `value` 만 노출된다(값은 보여주되 비교는 생략).

- `birthDate` 가 없어 월령을 산출할 수 없음(§4.7-4).
- 산출된 월령에 매칭되는 월령 구간이 테이블에 없음(§4.7-6).

지표 자체가 absent (§4.2) 인 경우는 `MetricComparison` 슬롯 전체가 `null` 이므로 reference 도 자연히 없다.

### 6.3 단위 정합

각 지표의 `value` 와 `reference` 는 **반드시 같은 단위**다(분 ↔ 분, ml ↔ ml, 횟수 ↔ 횟수). 단위가 다른 비교는 잘못된 데이터다.

### 6.4 책임 경계 — Data Layer 가 하지 않는 일

- "살짝 짧음 / 충분함 / 많음" 같은 **정성적 라벨링**은 하지 않는다. Presentation 이 `value`, `reference`, `position` 으로부터 표현한다.
- "범위 대비 몇 % / 몇 분 차이" 같은 **표시용 가공 수치**도 노출하지 않는다(Presentation 이 직접 계산).

---

## 7. 캐시 / 재계산 규칙

### 7.1 저장 형태

- 요약은 **아기별로 현재 윈도우 기준 1행**만 유지한다. 과거 스냅샷 히스토리는 두지 않는다.
- 저장된 요약은 마지막 계산 시각 **`computedAt`(UTC)** 을 가진다. (이 값은 캐시 신선도 판정에 쓰이는 백엔드 측 속성이며, 클라이언트 도메인 모델이 반드시 노출해야 하는 값은 아니다.)

### 7.2 재계산 트리거 — "하루 1회, 로컬 자정 롤오버 시"

- 클라이언트는 요약을 요청할 때 **자신의 로컬 타임존(또는 오늘의 로컬 날짜)을 함께 전달**한다.
- 저장된 `computedAt` 이 **요청자의 현재 로컬 날짜의 자정 이전**이면, 백엔드는 응답 전에 **재계산**한 뒤 최신 요약을 반환한다. 그렇지 않으면 저장된 요약을 그대로 반환한다.
- **왜 24시간 고정이 아니라 로컬 자정 기준인가**: 요약은 "오늘 제외 + 직전 7일" 을 대상으로 하므로, 새 완성된 날은 로컬 자정에 생긴다. 24시간 고정 경과는 자정 롤오버와 어긋나(예: 오후에 계산하면 다음 날 데이터가 완성됐어도 다음 날 오후까지 stale) 윈도우 정의와 정합하지 않는다. 로컬 자정 기준이면 하루에 최대 1회, 새 날이 생긴 직후 첫 진입에서 재계산된다.

### 7.3 과거 기록 수정 / 삭제에 대한 stale 허용

- 윈도우(직전 7일) 안의 과거 기록을 사용자가 수정 / 삭제하면 요약이 즉시 부정확해질 수 있으나, **다음 로컬 자정 롤오버 시 재계산으로 자연히 반영**되며 그 전까지는 stale 을 허용한다.
- **왜**: 본 앱 특성상 최근 24시간 밖(=완성된 과거 날)의 기록을 수정 / 삭제하는 일은 드물다. 모든 기록 변경마다 요약을 무효화 / 재계산하는 복잡성과 비용 대비 이득이 작다. 단순한 "하루 1회 재계산" 규칙을 유지한다.
- (오늘 데이터의 생성 / 수정 / 삭제는 애초에 윈도우에서 제외되므로 요약에 영향이 없다.)

### 7.4 데이터 없음 / 부족

- 데이터가 전혀 없으면 요약은 모든 지표 슬롯이 absent 인 상태로 정상 반환된다(에러 아님).
- 데이터가 1~6일치이면 §5.0 의 규칙대로 그 일수만큼으로 계산한다.

---

## 8. AnalyticsRepository 요구사항

### 8.1 목적

분석 탭이 보여줄 통계 요약(지표 값 + 월령 레퍼런스 비교)을 현재 선택된 아기에 대해 제공한다.

### 8.2 책임

- 아기 1명의 요약을 도메인 모델(`AnalyticsSummary`) + `Result<T>` 형태로 제공한다.
- 화면 표시용 가공(라벨, 정성 표현, 퍼센트 등)은 하지 않는다.
- 자체 상태(캐시 / 큐 / lock)를 갖지 않는다. 동시에 호출해도 안전하다.

### 8.3 호출자

- `AnalyticsViewModel` — 분석 탭 진입 시 요약 조회. 아기 전환 시 새 아기의 요약 재조회.

### 8.4 주요 결정

- `userId` 를 인자로 받지 않는다. "현재 사용자" 는 인증 컨텍스트에서 자동 판단한다(`home_data.md` 의 Repository 결정과 동일).
- `babyId` 를 인자로 받는다. "현재 선택된 아기" 의 판정은 호출자(`CurrentBabyController` / ViewModel)의 책임이다.
- **로컬 타임존 / 오늘 날짜 정보를 입력으로 받는다.** 일 단위 집계 경계가 로컬 자정이고, 캐시 신선도 판정(§7.2)이 로컬 날짜 기준이기 때문. 백엔드는 디바이스의 로컬 타임존을 알 수 없으므로 호출자가 전달해야 한다.

### 8.5 메서드 요구사항: 요약 조회

| 항목 | 요구사항 |
|---|---|
| 목적 | 한 아기의 분석 탭 통계 요약(지표 값 + 레퍼런스 비교)을 조회. |
| 입력 | `babyId`(필수), 요청자의 **로컬 타임존(또는 오늘의 로컬 날짜)**(필수). |
| 호출 시점 | 분석 탭 진입 시. 아기 전환 시. |
| 동작 | 저장된 요약이 stale(§7.2)이면 백엔드가 재계산 후 반환. 아니면 저장본 반환. |
| 결과 데이터 | `AnalyticsSummary` — 8개 지표 슬롯 각각 `MetricComparison?`. 데이터가 없는 지표는 absent. |
| 빈 데이터 | 기록이 전혀 없어도 **에러가 아니다.** 모든 지표가 absent 인 `AnalyticsSummary` 를 성공으로 반환. |
| 성공 조건 | 사용자가 인증되어 있고, 해당 `babyId` 에 보호자로 접근 가능해야 한다. |
| 실패 케이스 | 접근 불가 / 미존재 → `notFound`. 미로그인 / 만료 → `unauthorized`. 네트워크 실패 → `networkError`. 응답 파싱 실패 → `parseFailed`. 모두 `Result.error(AppException)`. |
| null 처리 | 각 지표 슬롯은 독립적으로 absent 가능. `MetricComparison.reference`/`position` 은 비교 불가 시 null(§6.2). |

> `notFound` 의 의미는 `home_data.md` §5.6 과 동일하다: 행 없음과 권한 차단(RLS 등)을 모두 포함한다. 호출자는 이를 stale 한 `selectedBabyId` 의 fallback 신호로 쓸 수 있다.

---

## 9. AnalyticsService 요구사항

### 9.1 책임

- Repository 의 하부 협력자. 원격 백엔드 호출, raw 응답을 도메인 모델(`AnalyticsSummary`)로 매핑, 인증 컨텍스트 주입.
- Repository 만이 Service 에 의존한다. ViewModel 은 Service 의 존재를 알지 못한다.
- 메서드는 `Result<T>` 를 반환한다. throw 하지 않으며, 모든 외부 실패는 `AppException` 으로 변환한다.
- 매핑 결과는 항상 도메인 모델이다. DB 응답 원본 / `Map` / DTO 는 Service 경계 밖으로 나가지 않는다.

### 9.2 메서드 — 책임

| 메서드 | 책임 |
|---|---|
| 요약 조회 | `babyId` 와 로컬 날짜 / 타임존을 받아, 백엔드의 (필요 시 재계산된) 요약을 `AnalyticsSummary` 로 매핑해 반환. 지표별 값 + 레퍼런스 범위 + position 을 채운다. 응답에 비교가 불가한 지표는 reference / position 을 null 로 매핑. 매핑 실패는 `AppException(parseFailed)`. |

### 9.3 매핑 책임의 위치

- `AnalyticsSummary` / `MetricComparison` / `ReferenceRange` 의 매핑은 Service 내부가 담당한다(데이터 소스에 의존하는 aggregate 매핑).
- 매핑 실패는 Service 안에서 catch 하여 `AppException(parseFailed)` 로 변환한다.

---

## 10. 에러 / 엣지 / 검증 종합

`AppException.code`(`ErrorCode`)로 실패 유형을 구분한다. 가능한 코드: `networkError`, `unauthorized`, `parseFailed`, `notFound`.

| 상황 | 처리 |
|---|---|
| 인증 만료 / 미로그인 | `unauthorized`. |
| 해당 아기 접근 불가 / 미존재 | `notFound`(행 없음 + 권한 차단 포함). |
| 네트워크 / 호출 실패 | `networkError`. 호출자는 동일 입력으로 재시도 가능. |
| 응답 / 매핑 실패, 모르는 enum 값 | `parseFailed`. |
| 기록 0건 | 에러 아님. 모든 지표 absent 인 요약 성공 반환(§7.4). |
| 특정 지표만 데이터 없음 | 그 지표만 absent (§4.2). |
| `birthDate` 없음 | 값은 계산, 모든 지표 비교 생략(reference/position null, §4.7-4). |
| 월령이 테이블 범위 밖 | 해당 지표 비교 생략(§4.7-6). |
| 수면 구간 겹쳐 깨시 gap 음수 | 그 gap 제외(§5.5). |
| 완성된 날 없음(데이터 없음 / 오늘 데이터만) | 모든 지표 absent, 요약은 성공 반환. 화면 미표시는 Presentation 책임(§5.0). |

---

## 11. 호출자 동작 시퀀스 (참고용)

> 본 절은 호출자(ViewModel) 관점의 참고용이며, Presentation Layer 스펙이 아니다.

### 11.1 분석 탭 진입

```
1. babyId    = currentBabyController.selectedBabyId        // String? (sync)
2. localDate = (디바이스 로컬 타임존 / 오늘 날짜)
3. result    = analyticsRepository.getSummary(babyId, localDate)   // Result<AnalyticsSummary>
     switch result:
       ok(summary):
         각 지표 슬롯을 순회하며 absent 가 아닌 것만 렌더.
         MetricComparison.position 에 따라 정성 라벨은 Presentation 이 결정.
       error(notFound):     → selectedBabyId stale 처리(목록 재조회 / 다른 아기 선택). (home_data §8.1 참조)
       error(unauthorized): → 로그인 화면.
       error(networkError): → "다시 시도" UI.
       error(parseFailed):  → 에러 화면.
```

### 11.2 아기 전환

```
1. currentBabyController.select(newId)
2. ViewModel 이 변경 감지 → 11.1 의 step 3 부터 newId 로 재실행.
```

---

## 12. Acceptance Criteria (검증 기준)

각 요구사항은 테스트로 검증 가능해야 한다. 대표 기준:

**도메인 모델 / 비교**
- AC-1: `reference != null` 인 `MetricComparison` 은 항상 `position != null` 이고, 그 역도 성립한다.
- AC-2: `value == reference.min` 또는 `value == reference.max` 이면 `position == within`.
- AC-3: `value < reference.min` → `below`, `value > reference.max` → `above`.
- AC-4: `ReferenceRange` 는 항상 `min <= max`.

**월령 산정**
- AC-5: `dueDate − birthDate > 21일` 이면 월령 산정 anchor 는 `dueDate`(교정연령).
- AC-6: `dueDate − birthDate <= 21일` 이거나 `dueDate == null` 이면 anchor 는 `birthDate`.
- AC-7: `birthDate == null` 이면 모든 지표의 `reference`/`position` 은 null(값은 산출).
- AC-8: 교정연령 음수 → 월령 0 구간으로 비교.
- AC-9: 월령이 테이블 구간에 없으면 해당 지표 비교 생략.

**지표 계산**
- AC-10: `feedingVolume` 은 윈도우 각 날의 (`formula`+`pumpingFeed`) ml 합을, 그 두 타입 기록이 있는 날 수로 나눈 평균이다.
- AC-11: `babyFoodVolume` 은 `formula`/`pumpingFeed` 와 합산되지 않는다.
- AC-12: `breast.leftMinutes`/`rightMinutes` 가 null 이면 0분으로 집계된다.
- AC-13: `DiaperType.mixed` 1건은 소변 카운트와 대변 카운트에 각각 +1 한다.
- AC-14: 자정을 걸친 수면은 `startedAt` 날짜에 전체 길이가 귀속된다(분할 없음).
- AC-15: `awakeDuration` 은 연속 수면의 `endedAt→다음 startedAt` gap 평균이며, 음수 gap 은 제외한다. 유효 gap 0개면 absent.
- AC-16: 윈도우는 오늘(로컬)을 제외한 직전 최대 7개 완성된 날이다. 완성된 날이 하나도 없으면(오늘 데이터만 있어도) 모든 지표가 absent 다.
- AC-17: 어떤 지표 타입의 기록이 윈도우에 1건도 없으면 그 지표 슬롯은 absent.

**캐시 / 재계산**
- AC-18: 저장된 `computedAt` 이 요청자 로컬 날짜의 자정 이전이면 재계산 후 반환, 아니면 저장본 반환.
- AC-19: 윈도우 내 과거 기록을 수정 / 삭제해도 다음 로컬 자정 전까지는 재계산하지 않는다(stale 허용).

**조회 계약**
- AC-20: 기록 0건이어도 `getSummary` 는 모든 지표 absent 인 `AnalyticsSummary` 를 성공 반환한다(에러 아님).
- AC-21: 접근 불가 / 미존재 → `notFound`, 미로그인 → `unauthorized`, 네트워크 실패 → `networkError`, 매핑 실패 → `parseFailed`.
