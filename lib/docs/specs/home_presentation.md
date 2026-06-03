# 📋 Home Screen — Presentation Layer

본 문서는 **Part 1. 스펙** 과 **Part 2. 구현 방법** 으로 나뉜다.

- **Part 1** 은 "무엇을 보여주고 / 어떻게 반응해야 하는가" — 위젯 트리나 라이브러리 선택과 무관하다.
- **Part 2** 는 "어떻게 만들 것인가" — 본 프로젝트의 기술 스택 (Provider / ChangeNotifier / go_router / Result<T>) 에 맞춘 구현 메모.

본 spec 은 Data Layer 의 계약 (`home_data.md`) 을 **소비** 한다. Data Layer 결정 (Repository 인터페이스, 에러 코드, 시퀀스 §8) 은 본 spec 의 입력이며, 여기서 다시 정의하지 않고 인용한다.

---

# Part 1. 스펙

## 1. 스코프

### 1.1 본 PR 범위

- **`HomeScreen`** 한 화면의 위젯 트리 + 진입 시 / 인터랙션 시 동작.
- **홈 진입에 직접 매달려 있는 모달들**:
  - 일상기록 입력 dialog (Formula / Diaper / Water / BabyFood / Snack / Pumping / PumpingFeed).
  - 일상기록 버튼 수정 bottom sheet (순서 / 사용 안 함).
  - baby 전환 bottom sheet (가능한 babies 중 하나 선택).
  - 기록 삭제 확인 dialog.
  - 모유수유 / 수면 스탑워치 카드 (홈 안의 한 자리).
- **`HomeViewModel`** 과 영역별 sub-ViewModel (§11 참조).
- **로컬 영속화**: 일상기록 버튼의 사용자 커스터마이즈 (순서 / 사용 안 함) 를 위한 `AppLocalStorage` 확장.
- **라우팅**: 홈 → 기록 상세 / 아기 등록 (`welcome`) / 로그인 화면으로의 전환.

### 1.2 본 PR 범위 아님

- 아기 등록 / 초대 코드 / 아기 프로필 수정 화면 자체 (이미 onboarding 영역).
- 기록 상세 화면 자체 (이미 `record_detail` 영역). 본 spec 은 그 라우트로의 push 만 다룬다.
- Analysis / Settings 탭의 내용.
- 도메인 모델 변경 (`CareRecord.type` 제거 등 — home_data §11 의 후속 PR 항목).
- DB 스키마 변경 (home_data §12.4).

### 1.3 의존하는 외부 계약

- `BabyRepository` — `getMyBabies`, `getBaby` (home_data §5).
- `RecordRepository` — `getRecords`, `getRecentFeedings`, `getRecentDiapers`, `getRecentWakes`, `createRecord`, `deleteRecord` (home_data §6).
- `CurrentBabyController` — 현재 선택된 baby id 의 메모리 + 영속 (home_data §4-bis).
- `AppLocalStorage` — 디바이스 로컬 KV 저장 (home_data §4). 본 PR 에서 키 1 종 추가 (§6.2).
- `AuthRepository.signOut` (로그아웃 시 cleanup 흐름은 본 spec 의 §8 호출자 시퀀스에서 인용).

---

## 2. 화면 구성 — 위에서 아래

```
┌──────────────────────────────────────────────────┐
│  [A] Baby Info Header                            │
│      "D+123  ⌄"                                  │
│      "Liam"                                      │
├──────────────────────────────────────────────────┤
│  [B] Quick-log Button Row (가로 스크롤)           │
│      ⊙Formula  ⊙Nursing  ⊙Diaper  ⊙Sleep …  ⚙   │
├──────────────────────────────────────────────────┤
│  [C] Recent Snapshot Row                         │
│      LAST FEED 2h 15m ago │ LAST DIAPER 45m ago │
│      LAST SLEEP 3h ago                            │
├──────────────────────────────────────────────────┤
│  [D] Stopwatch Card  (조건부, [C] 와 [E] 사이)    │
│      FEEDING TIMER / SLEEP TIMER                  │
│      <시간 표시>                                   │
│      [Pause/Resume] [Complete]                    │
├──────────────────────────────────────────────────┤
│  [E] Record List (날짜 헤더 + 항목, 무한 스크롤)   │
│      3.2 Mon (D+123)                              │
│      • Diaper Change [PEE] 14:30 PM 메모…         │
│      • Formula Feed [160ML] 12:00 PM 메모…        │
│      …                                            │
└──────────────────────────────────────────────────┘
   하단 탭바: Home / Analysis / Settings  (Settings/Analysis 는 본 PR 외)
```

영역 식별자 `[A]`–`[E]` 를 본 문서 전반에서 인용한다.

---

## 3. 도메인 가공 규칙 (Presentation 책임)

Data Layer 는 raw 도메인 값만 노출한다 (home_data §3). 화면에 보여줄 문자열 / 색상 / 라벨 계산은 모두 본 layer 의 책임이다.

### 3.1 시간대 변환

- 모든 `DateTime` 필드는 UTC 로 도착한다 (home_data §3.1).
- 사용자에게 표시되는 시각 (`14:30 PM`, `3.2 Mon`, `2h 15m ago` 등) 은 **디바이스의 현재 timezone** 으로 변환한다.
- 변환 위치는 ViewModel 또는 그 산하의 formatter (§11.5).
- "오늘 / 어제 / N일 전" 의 경계는 **디바이스 로컬 자정** 기준.

### 3.2 D+N / D-day 라벨

`Baby.birthDate` / `Baby.dueDate` 둘 다 nullable. 라벨 선택 우선순위:

| 조건 | 라벨 |
|---|---|
| `birthDate != null` | **D+N** — 출생 후 경과 일수. 예: 출생 당일 = `D+1`. |
| `birthDate == null && dueDate != null` | **D-N** — 예정일까지 남은 일수. 예: 내일 = `D-1`. 당일 = `D-Day`. 지난 = `D+N` 로 전환되지 않고 `D-Day` 유지 (입력 화면이 birthDate 로 갱신해야 함). |
| 둘 다 null | 라벨 미표시. 이름만 표시. |

- 일수 계산은 디바이스 로컬 자정 기준. UTC 의 시각 부분은 무시하고 "날짜" 만으로 차이 계산.
- 라벨 색 / 폰트는 디자인 토큰 (단일 큰 글씨, AppColors).

### 3.3 "N시간 전" / "N분 전" 표기 (최근 row)

`now - 기준시각` 의 절대값:

| 차이 | 표기 |
|---|---|
| ≤ 60 초 | `방금` |
| < 60 분 | `N분 전` (예: `45분 전`) |
| < 24 시간 | `N시간 N분 전` (분이 0 이면 `N시간 전`. 예: `2시간 15분 전`, `3시간 전`) |
| ≥ 24 시간 | `N일 전` (일 단위. 예: `2일 전`) |

- 기준시각은 카테고리별로 다르다 (§5.4).
- "방금" 이후 자동으로 갱신되지는 않는다 — 다음 재호출 시 다시 계산.

### 3.4 기록 리스트의 날짜 헤더

- 형식: `M.D 요일 (D+N)` 또는 `(D-N)` 또는 `(D-Day)` 또는 라벨 없는 `M.D 요일`. 예: `3.2 월요일 (D+123)`.
- 요일: 한글 3자 — `월요일 / 화요일 / 수요일 / 목요일 / 금요일 / 토요일 / 일요일`.
- 같은 날짜의 첫 row 위에만 헤더 표시.

### 3.5 기록 리스트 항목 row 의 메타 chip

각 항목 row 는 좌측 카테고리 dot + 제목 + 우측 메타 chip + 시각 + (옵션) 메모 본문 로 구성.

| RecordType | 제목 | chip | chip 없는 조건 |
|---|---|---|---|
| `breast` | `모유` | `왼쪽` / `오른쪽` / `양쪽` (시간이 더 긴 쪽; 동률 = `양쪽`; 한 쪽만 non-null = 그 쪽) | 한 쪽도 null 이면서 둘 다 0 분이면 chip 없음 (이론적 케이스) |
| `sleep` | `수면` | `N시간 N분` (분이 0 이면 `N시간`. 1시간 미만이면 `N분`. 지속 = endedAt − startedAt) | — |
| `formula` | `분유` | `Nml` | — |
| `pumpingFeed` | `유축수유` | `Nml` | — |
| `pumping` | `유축` | `Nml` (= leftAmountMl + rightAmountMl; null 은 0 으로 취급) | 둘 다 null 이면 chip 없음 |
| `babyFood` | `이유식` | name (있을 때) | name 이 null 이면 `Nml` |
| `snack` | `간식` | name (있을 때) | name 이 null 이면 chip 없음 |
| `water` | `물` | `Nml` | — |
| `diaper` | `기저귀` | `소변` / `대변` / `혼합` | — |

- chip 색은 카테고리 색의 옅은 배경 + 진한 글자. 카테고리 색은 `record_type_palette.dart` 의 토큰.
- 시각: `HH:mm a` (예: `14:30 PM`).
- 메모: `RecordMemo` 의 첫 메모를 한 줄 truncate 로 표시. 메모가 없으면 그 줄을 **생략** (row 높이가 줄어듦).
  - "첫 메모" 정의: 본 PR 에서는 메모를 별도 조회하지 않는다 — 기록 리스트 API 는 메모를 반환하지 않으므로 본 행에 메모 줄은 **항상 생략**. (메모 표시는 후속 PR. 본 spec 의 §1.3 "본 PR 외" 에 명시.)

> ⚠️ §3.5 의 "메모 첫 줄 표시" 는 Figma 의 디자인 의도지만, 데이터 레이어가 list 응답에 메모를 포함하지 않는다. 본 PR 에서는 항상 메모 줄 생략으로 결정.

### 3.6 카테고리 색 토큰

- 좌측 dot 색 / chip 색 / 스탑워치 Resume 버튼 색 / 일상기록 버튼 아이콘 색은 모두 동일 카테고리 색을 공유.
- 색 토큰은 기존 `lib/theme/record_type_palette.dart` 를 그대로 사용. 본 PR 에서 신규 정의 없음.

---

## 4. UI State 모델

홈은 **네 가지 독립 영역의 상태** 를 함께 보여준다. 한 영역의 실패가 다른 영역을 가리지 않는다 (home_data §8.1 의 부분 실패 정책).

### 4.1 영역별 상태 머신

#### [A] Baby Info Header

| 상태 | 트리거 | 표시 |
|---|---|---|
| `loading` | 초기 진입 / 새로고침 / baby 전환 | 스켈레톤 (라벨 자리 1줄, 이름 자리 1줄) |
| `success(Baby)` | `getBaby(currentBabyId)` 성공 | 라벨 + 이름 |
| `error(notFound)` | `getBaby` 결과 `notFound` (행 없음 / 권한 차단) | **전역 분기**: `welcome` 라우트로 `pushReplacement` (§4.2). fallback 시도 없음 |
| `error(unauthorized)` | 인증 만료 / 미로그인 | **전역 분기**: 로그인 화면으로 라우팅 |
| `error(other)` | 네트워크 / parse | 라벨 자리에 "다시 시도" 아이콘 + 스낵바 1회 |

#### [B] Quick-log Button Row

이 영역은 데이터 로딩 상태가 없다 — 로컬 영속 설정 (§6) 만 본다. 항상 즉시 렌더링.

- 진입 시 `AppLocalStorage` 에서 사용자 커스터마이즈 (순서 / 사용 안 함) 를 읽어 메모리에 보관.
- 디폴트 (값 없음) = "9 종 전부, §6.1 의 정해진 순서" (§6 참조).

#### [C] Recent Snapshot Row — 3 개의 독립 슬롯

세 슬롯 (`feed` / `diaper` / `sleep`) 각각 독립 상태.

| 상태 | 트리거 | 슬롯 표시 |
|---|---|---|
| `loading` | 초기 / 재호출 중 | 스켈레톤 텍스트 |
| `success(record)` | `getRecent*` 결과가 1건 이상 → 가장 최근 1건 | `Nh Nm ago` (§3.3) |
| `empty` | `getRecent*` 결과가 빈 리스트 | "기록 없음" 텍스트 |
| `error` | 네트워크 / 인증 / parse | "다시 시도" 아이콘 (탭 시 해당 슬롯만 재호출) |

세 슬롯은 한 row 안의 시각적 cell. 어떤 슬롯이 loading 이어도 다른 슬롯은 자기 상태대로 렌더.

#### [D] Stopwatch Card

조건부 노출. 데이터 로딩 상태 없음 — **순수 메모리 상태**.

| 상태 | 의미 | 표시 |
|---|---|---|
| `inactive` | 사용자가 모유수유 / 수면 버튼을 한 번도 누르지 않음 | 카드 자체 없음 |
| `breast.idle` | 모유수유 슬롯 활성, 한 쪽도 시작 전 | 좌/우 row 둘 다 `[▶ Start]` |
| `breast.running(side)` | 한 쪽이 진행 중 | 진행 중인 쪽 `<시간> [⏸ Pause]`, 다른 쪽 disabled `[▶ Start]` |
| `breast.paused(side)` | 한 쪽이 일시정지 | 그 쪽 `<시간> [▶ Resume] [✓ Complete]`, 다른 쪽 여전히 disabled |
| `breast.finished(side)` | 한 쪽 Complete 끝남, 다른 쪽 시작 가능 | 끝난 쪽 잠금 표시 + 시간, 다른 쪽 enabled `[▶ Start]` |
| `sleep.running` | 수면 슬롯 활성, 진행 중 | `<시간> [⏸ Pause]` |
| `sleep.paused` | 수면 슬롯 활성, 일시정지 | `<시간> [▶ Resume] [✓ Complete]` |

상태 전이의 정확한 정의는 §5.3 / §6.3 / §6.4 참조.

#### [E] Record List

| 상태 | 트리거 | 표시 |
|---|---|---|
| `loading` (첫 페이지) | 진입 / 새로고침 / baby 전환 | 스켈레톤 row 5 개 |
| `success(items, hasMore)` | `getRecords` 성공 | 날짜별 그룹핑 + 항목 row. 하단 prefetch trigger |
| `loadingNext` | 무한 스크롤 trigger 발화 후 응답 전 | 기존 리스트 + 하단 footer 로더 |
| `empty` | `getRecords` 성공이지만 items=[] | 화면 중앙 안내 — "아직 기록이 없어요" (큰) + "버튼을 눌러 기록을 추가해보세요" (작) |
| `error` (첫 페이지) | 첫 페이지 실패 | 스낵바 1회 + 중앙 "다시 시도" 버튼 |
| `errorNext` | 다음 페이지 실패 | 기존 리스트 + 하단 inline 실패 메시지 + "다시 시도" |

### 4.2 전역 상태 분기

다음 케이스는 영역별 분기가 아니라 화면 전체를 다른 곳으로 전환한다.

| 트리거 | 동작 |
|---|---|
| `getMyBabies` 결과 `notFound` (= 빈 리스트, home_data §5.5) | `welcome` 라우트로 `pushReplacement` |
| `getBaby` 결과 `notFound` (행 없음 / 권한 차단) | `welcome` 라우트로 `pushReplacement`. fallback (다른 baby 로 재조회) 시도하지 않음 |
| 모든 영역에서 `unauthorized` 한 번이라도 발생 | `login` 라우트로 `pushReplacement` + `currentBabyController.clear()` |

> 본 결정은 home_data §8.1 의 "candidateId 가 stale 이면 babies.first.id 로 fallback" 흐름을 채택하지 않는다. 사용자가 봤던 baby 가 사라졌거나 권한이 끊긴 상황을 조용히 다른 baby 로 갈아끼우는 대신, 명시적으로 등록/초대 진입점인 `welcome` 으로 보낸다.

### 4.3 부분 실패 정책 — 영역별 독립

home_data §8.1 의 정책을 그대로 적용한다.

- `[A]` 의 실패는 `[C]` / `[E]` 의 표시를 막지 않는다.
- `[C]` 세 슬롯은 서로 독립.
- `[E]` 의 실패는 `[A]` / `[C]` 를 막지 않는다.
- 단, §4.2 의 전역 분기 코드 (`unauthorized` 등) 는 부분 실패가 아니라 전체 전환.

---

## 5. 사용자 인터랙션 — 영역별

### 5.1 [A] Baby Info Header

| 인터랙션 | 동작 |
|---|---|
| 이름 우측 chevron 탭 | baby 전환 bottom sheet 노출 (§5.6) |
| 이름 자체 탭 | (없음) |

- 라벨 / 이름 자체에는 별도 인터랙션 없음.
- 스탑워치가 진행 중 (`breast.running` / `breast.paused` / `sleep.running` / `sleep.paused` 모두 포함, `breast.finished` 는 제외) 일 때 chevron 탭 → 먼저 §5.3.6 의 "스탑워치 진행 중 baby 전환" 확인 dialog.

### 5.2 [B] Quick-log Button Row

| 인터랙션 | 동작 |
|---|---|
| row 좌/우 스와이프 | 자유 가로 스크롤. snap 없음. |
| 버튼 탭 — `breast` | `[D]` 의 `breast.idle` 진입. `[D]` 가 inactive 였으면 카드 노출 |
| 버튼 탭 — `sleep` | `[D]` 의 `sleep.running` 진입 (즉시 시작) |
| 버튼 탭 — 그 외 7 종 | 해당 카테고리의 입력 dialog (§5.5) |
| row 끝 ⚙ 아이콘 탭 | 버튼 수정 bottom sheet (§5.7) |

- 다른 스탑워치 슬롯이 active 일 때 `breast` / `sleep` 버튼을 누르면 → §5.3.5 의 "이미 진행 중인 다른 스탑워치 확인 dialog".
- 한 카테고리 저장 진행 중 (생성 API 호출 in flight) 그 버튼은 비활성 (중복 생성 방지 — home_data §6.4).

### 5.3 [D] Stopwatch Card

#### 5.3.1 모유수유 — 좌/우 row 의 동작

```
┌───────────────────────────────────┐
│  FEEDING TIMER                    │
├───────────────────────────────────┤
│  LEFT   <시간>   [▶/⏸]             │
│  RIGHT  <시간>   [▶/⏸]             │
│             [✓ Complete]            │
└───────────────────────────────────┘
```

- 좌 / 우 각각 자체 stopwatch 메모리 상태.
- **동시 진행 불가** — 한 쪽 시작 (`running`) 또는 일시정지 (`paused`) 인 동안 다른 쪽 `[▶]` 는 disabled.
- 한 쪽이 `finished` 가 되면 다른 쪽 enabled.
- 좌/우 각자 `running ↔ paused` 자유 전환.
- **Complete 버튼**: 진행 중 / 일시정지 중인 쪽이 있으면 그 쪽을 자동 `finished` 로 만든 뒤 저장 흐름 진입 (§5.3.4).
- Complete 버튼은 좌/우 둘 다 `초 단위 누적 시간 == 0` 일 때 disabled. 즉, 한쪽이라도 시작했고 1초라도 흘렀으면 활성.

#### 5.3.2 수면 — 단일 row

```
┌───────────────────────────────────┐
│  SLEEP TIMER                      │
├───────────────────────────────────┤
│             <시간>                  │
│      [▶ Resume] [✓ Complete]        │
└───────────────────────────────────┘
```

- 버튼 탭 시 즉시 `running` 으로 진입 (별도 Start 단계 없음).
- `running ↔ paused` 자유 전환.
- Complete = 즉시 저장 흐름 (§5.3.4).
- Complete 는 누적 시간 == 0 일 때 disabled.

#### 5.3.3 시간 단위와 표시

- 화면 표시: `Hh Mm Ss` 동적 (예: `0m 1s`, `15m 32s`, `1h 5m 12s`). 시간 단위는 첫 단위가 0 이 되는 시점에 사라진다.
- 1 초 단위로 갱신 (Stream / Ticker).
- 일시정지 중인 표시는 "그 시점까지의 누적 경과 시간" 고정.

#### 5.3.4 Complete 시 저장 흐름

저장 트리거 직후 흐름:

1. UI 상 Complete 버튼 비활성 (중복 호출 방지).
2. 누적 경과 시간을 카테고리별로 `RecordDetailData` 로 매핑:
   - **breast**: 양쪽 누적 초를 `round(seconds/60)` 로 변환해 `leftMinutes` / `rightMinutes`. 한 번도 시작 안 한 쪽 = `null`. 시작은 했지만 0 분 (0초~29초 누적) = `0`. `startedAt` = `min(좌 시작, 우 시작)` 중 먼저. `endedAt` = `max(좌 종료, 우 종료)` 중 나중. **시작·종료 시각은 UTC**.
   - **sleep**: `startedAt` = 처음 `running` 진입 시각, `endedAt` = Complete 누른 시각, `sleepType` = §6.4 의 디폴트 규칙.
3. `RecordRepository.createRecord(currentBabyId, detail)` 호출.
4. 응답에 따라:
   - **Ok(record)** → 리스트 맨 앞에 prepend + 해당 카테고리의 `getRecent*` 재호출 (home_data §8.3). 카드 사라짐 (`inactive` 로 복귀).
   - **Error(`unauthorized`)** → §4.2 전역 분기.
   - **Error(그 외)** → 카드는 유지 (`finished` 상태로 잠금) + 스낵바 "저장 실패. 다시 시도해주세요." + 카드에 "다시 시도" 버튼 노출. 사용자가 "다시 시도" 누르면 step 3 반복.

#### 5.3.5 이미 진행 중인 다른 스탑워치

`[D]` 가 sleep 진행 중일 때 사용자가 `breast` 버튼을 누른 경우 (또는 그 반대):

```
"수면 타이머가 진행 중이에요. 종료하고 모유수유를 시작할까요?"
[취소] [종료하고 시작]
```

- 취소 = dismiss, 기존 스탑워치 유지.
- 종료하고 시작 = 기존 스탑워치를 §5.3.4 의 Complete 와 동일하게 저장 진행 → 성공 시 새 카테고리로 진입. 저장 실패 시 새 카테고리 진입 안 함.

#### 5.3.6 스탑워치 진행 중 baby 전환 / 라우트 push

- chevron 탭 (§5.1) 시점 또는 사용자가 다른 라우트로 이동할 때 (`[E]` 항목 탭 → 상세 화면 등) 스탑워치 진행 중이면:

```
"타이머가 진행 중이에요. 종료하지 않고 이동할까요?"
[취소] [종료하고 이동] [유지하고 이동]
```

- 취소 = dismiss.
- 종료하고 이동 = §5.3.4 의 Complete 흐름 → 성공 시 라우트 전환.
- 유지하고 이동 = 스탑워치 메모리 상태 그대로 두고 라우트 전환. 홈 라우트는 stack 에 남아 있으므로 돌아오면 스탑워치도 그대로 보임.

- **`finished` 단계 (양쪽 또는 한쪽 Complete 만 끝낸 상태) 에서는 이 dialog 가 뜨지 않는다.** 이미 도메인 모델로 저장된 상태이므로 자유 이동.

### 5.4 [C] Recent Snapshot Row

- 세 슬롯의 기준시각 (home_data §6.6/§6.7/§6.8 인용):
  - `feed`: breast → `endedAt`, 그 외 수유 4종 → `occurredAt`.
  - `diaper`: `occurredAt`.
  - `sleep`: `endedAt`.
- 각 슬롯의 `[다시 시도]` 아이콘 탭 → 그 슬롯만 재호출.
- 슬롯 자체에는 인터랙션 없음 — 탭해도 상세 화면으로 이동하지 않는다.

### 5.5 [B] 일반 카테고리 버튼 → 입력 dialog

`breast` / `sleep` 외 7 종 (`formula`, `pumpingFeed`, `pumping`, `babyFood`, `snack`, `water`, `diaper`) 의 버튼 탭 시.

#### 공통 dialog 골격

```
┌────────────────────────────────┐
│   <카테고리 이름>                │
├────────────────────────────────┤
│   시각 [<HH:mm a> ▼]             │  ← 탭 시 time picker, 미래 시각 거부
│   <카테고리별 입력 필드>           │
│   [취소] [저장]                  │
└────────────────────────────────┘
```

- dialog 형식 (`AlertDialog`). bottom sheet 아님.
- 시각 기본값 = 현재 시각. 사용자가 변경 가능. **미래 시각은 저장 비활성**.
- 메모 필드 **없음** — 메모는 기록 상세 화면에서 추가.

#### 카테고리별 입력 필드

| RecordType | 필드 |
|---|---|
| `formula` | `amountMl` (필수, int ≥ 0) |
| `pumpingFeed` | `amountMl` (필수, int ≥ 0) |
| `water` | `amountMl` (필수, int ≥ 0) |
| `pumping` | `leftAmountMl` (옵션, int), `rightAmountMl` (옵션, int). 둘 다 비우면 저장 비활성 |
| `babyFood` | `name` (옵션, 1..30 char trim), `amountMl` (필수, int ≥ 0) |
| `snack` | `name` (옵션, 1..30 char trim). 비울 수 있음 |
| `diaper` | `diaperType` 단일 선택 — 3 버튼 `PEE` / `POOP` / `MIXED` |

- 빈 필드의 표현:
  - `pumping.left/rightAmountMl` 의 빈 입력 = `null` (= 그 쪽 유축 안 함). `0` 입력 = `0` (유축은 했으나 양 0).
  - `babyFood.name` / `snack.name` 의 빈 입력 = `null`.

#### 저장 흐름

1. 저장 버튼 탭 → dialog 잠금 (입력 비활성, 저장 버튼 spinner).
2. 입력값으로 `RecordDetailData` 변종 생성. `occurredAt` = dialog 의 시각 (UTC 변환).
3. `RecordRepository.createRecord(currentBabyId, detail)` 호출.
4. 응답:
   - **Ok** → dialog 닫기 + `[E]` 의 리스트 맨 앞에 prepend + 해당 카테고리가 `[C]` 의 슬롯에 속하면 그 슬롯 재호출 (`feed` ⊃ formula/pumpingFeed/pumping/babyFood, `diaper` ⊃ diaper).
   - **Error(`unauthorized`)** → §4.2 전역 분기.
   - **Error(그 외)** → dialog 잠금 해제 + 스낵바 "저장 실패. 다시 시도해주세요.".

### 5.6 baby 전환 bottom sheet

- 진입: `[A]` chevron 탭 (§5.1).
- 호출: `babyRepository.getMyBabies()` (홈 진입 시 캐시된 결과 재사용. 단, baby 전환 직후라면 다시 새로고침).
- 표시: `BabyListItem` 목록 (생성일 내림차순). 현재 선택된 baby 에는 체크 표시.
- 선택 시:
  1. bottom sheet 닫기.
  2. `currentBabyController.select(newId)` 호출.
  3. `[A]` `[C]` `[E]` 모두 `loading` 으로 복귀 후 재호출. 스탑워치 (§5.3.6) 처리는 §5.1 의 dialog 가 이미 거름.

### 5.7 버튼 수정 bottom sheet

- 진입: `[B]` 의 ⚙ 아이콘 탭.
- 화면 진입이 아니라 bottom sheet (modal).
- 표시: 9 종 RecordType 모두 리스트로 보여줌. 각 항목:
  - 토글 (on/off, 사용 안 함 처리).
  - 드래그 핸들 (순서 변경).
- 변경은 **즉시 로컬 영속화** (§6.2). 닫기 버튼만, 별도 "저장" 버튼 없음.
- 모든 항목을 off 로 만들 수는 없다 — 마지막 1 개의 토글은 off 비활성.

### 5.8 [E] Record List

| 인터랙션 | 동작 |
|---|---|
| 상/하 스크롤 | 자유 스크롤 |
| 하단 prefetch trigger | 마지막에서 5 row 이내로 진입하면 자동으로 `getRecords(cursor=nextCursor)` 호출 (`hasMore == true` 일 때만; 호출 중이면 재발화 안 함) |
| pull-to-refresh | `[A]` + `[C]` 3슬롯 + `[E]` 첫 페이지 모두 동시 재호출 |
| 항목 row 탭 | `record_detail` 라우트로 push. push 전 §5.3.6 의 dialog (스탑워치 진행 중) |
| 항목 row 좌→우 swipe | swipe 거리 임계치 초과 시 삭제 확인 dialog (§5.9) |

### 5.9 삭제 확인 dialog

```
"이 기록을 삭제할까요?"
"삭제하면 되돌릴 수 없어요."
[취소] [삭제]
```

- `AlertDialog` 형식.
- 취소 → swipe 되돌리기.
- 삭제 → `RecordRepository.deleteRecord(record.id)`.
  - **Ok** → 리스트에서 즉시 제거 + 그 기록이 `[C]` 의 어느 슬롯이었으면 그 슬롯 재호출.
  - **Error(`notFound`)** → 이미 삭제된 것으로 보고 리스트에서 즉시 제거 (home_data §8.3 그대로).
  - **Error(`unauthorized`)** → §4.2 전역 분기.
  - **Error(그 외)** → swipe 되돌리기 + 스낵바 "삭제 실패. 다시 시도해주세요.".

---

## 6. 영역별 데이터 / 정책 명세

### 6.1 일상기록 버튼의 기본 노출 / 순서

기본 순서 (사용자가 한 번도 커스터마이즈 안 한 상태):

1. `formula`
2. `breast` (Nursing)
3. `diaper`
4. `sleep`
5. `pumping`
6. `pumpingFeed`
7. `babyFood`
8. `snack`
9. `water`

- 사용자 커스터마이즈가 있으면 그 순서를 따른다.
- 한 종류가 `off` 면 row 에 표시하지 않는다.
- 모든 종류가 새로 추가될 경우 (현재 9 종 외 미래 enum 추가) → 사용자 설정 끝에 추가, default `on`.

### 6.2 `AppLocalStorage` 의 확장 키

`AppLocalStorage` 에 **하나의 새 키만** 추가 (home_data §4.1 의 패턴):

| 키 | typed getter / setter | 값 |
|---|---|---|
| `quick_log_buttons` | `String? get quickLogButtonsJson` / `Future<void> setQuickLogButtonsJson(String json)` / `Future<void> removeQuickLogButtonsJson()` | JSON 문자열. 형식: `[{"type":"formula","enabled":true}, ...]`. 디바이스 로컬. 다른 디바이스와 동기화 안 됨 |

- ViewModel 이 직렬화 / 역직렬화를 담당. `AppLocalStorage` 는 raw 문자열만 다룬다 (KV wrapper 의 책임 경계, home_data §4.1).
- 미지의 enum 값이 JSON 에 들어 있으면 그 항목은 무시 (forward-compat). 누락된 enum 값은 default `on` 으로 채워서 끝에 추가.

### 6.3 모유수유 스탑워치 — 시간 변환 정밀 규칙

- 좌 / 우 각자 누적 초 (`leftSeconds`, `rightSeconds`).
- "누적" 의 의미: `running` 구간들의 합. `paused` 동안은 증가 안 함.
- Complete 시 `round(seconds / 60)` 으로 분 변환. 즉 0–29 초 = 0 분, 30–89 초 = 1 분, …
- `null` vs `0` 의 구별:
  - 한 번도 `running` 으로 진입한 적 없는 쪽 = `null`.
  - `running` 으로 진입한 적이 있는 쪽 = `0` 이상의 int (0 도 허용).

- 좌 / 우 각자 시작 시각도 메모리에 보관:
  - `leftFirstStartedAt`, `rightFirstStartedAt` — 처음 `running` 진입 시각 (UTC). 한 번도 진입 안 했으면 `null`.
  - `leftLastEndedAt`, `rightLastEndedAt` — 마지막 `paused` / `finished` 진입 시각 (UTC). 진입 후 변경 가능.
- `BreastDetail.startedAt` = 두 시작 시각 중 더 이른 것 (둘 다 null 이면 Complete 비활성이므로 도달 불가).
- `BreastDetail.endedAt` = 두 끝 시각 중 더 나중. 둘 다 있어야 한다 (한 쪽도 시작한 경우만 Complete 가능 → 끝 시각도 정의됨).

### 6.4 수면 스탑워치 — sleepType 자동 결정

- Complete 시점의 **디바이스 로컬 시각** 기준:
  - 시각이 `22:00`–`05:59` → `night`.
  - 그 외 → `nap`.
- 사용자가 수정하려면 기록 상세 화면에서 변경 (본 PR 범위 외).

### 6.5 무한 스크롤 / 페이지네이션

- 첫 페이지 limit = 20 (home_data §6.5 의 기본).
- 다음 페이지 trigger: 마지막에서 **5 row** 이내로 스크롤이 진입하면 자동 발화.
- 진행 중 (`loadingNext`) 일 때 또 발화하지 않음.
- `hasMore == false` 이후 발화하지 않음.
- baby 전환 / pull-to-refresh 시 첫 페이지부터 다시.

### 6.6 캐시 / 무효화 정책

- 본 PR 에서 **Repository 결과를 별도로 캐시하지 않는다.** ViewModel 의 메모리 상태가 곧 캐시.
- 무효화 시점:
  - 기록 생성 성공 → 리스트 prepend + 해당 카테고리의 recent slot 재호출.
  - 기록 삭제 성공 → 리스트에서 제거 + 그 기록이 recent slot 의 1번이었으면 그 슬롯 재호출 (기록 모델의 `record.detail.type` / id 비교).
  - baby 전환 → 모든 영역 메모리 비우고 재호출.
  - pull-to-refresh → 모든 영역 메모리 비우고 재호출. (다음 페이지의 cursor 도 무효.)
  - 화면 떠났다 돌아옴 (라우트 push 후 pop) → **재호출 안 함**. 메모리 그대로.

### 6.7 baby 전환 시 스탑워치 처리

- §5.3.6 의 dialog 가 우선 처리. "종료하고 이동" / "유지하고 이동" 의 두 결정에 따라 스탑워치 상태가 달라진다.
- "유지하고 이동" 후 baby 전환이 끝나면 스탑워치 메모리 상태는 그대로 (다른 baby 의 컨텍스트에서 같은 메모리 슬롯). 다음 Complete 의 `createRecord` 호출은 **변경된 currentBabyId** 로 향한다 → 즉 사용자가 "유지하고 이동" 을 선택하면 그 시점부터 다른 baby 의 기록으로 잡힌다. 이 위험을 사용자가 인지하도록 dialog 의 카피에서 명시 (§9 카피 정의).

---

## 7. 화면 전체 흐름 시퀀스

### 7.1 첫 진입

home_data §8.1 시퀀스를 그대로 따른다. 본 spec 으로 다시 풀어쓴 흐름:

```
1. 화면 mount
2. babyRepository.getMyBabies() 호출 (영역 [A]/[E] 모두 loading)
   - notFound → §4.2 전역 분기: welcome 라우트
   - unauthorized → §4.2 전역 분기: login 라우트
   - other error → 전체 화면 에러
   - ok(babies) → step 3
3. currentBabyController.selectedBabyId 읽기
   - null → candidateId = babies.first.id
   - non-null → candidateId = 그 값
4. babyRepository.getBaby(candidateId) 호출
   - ok(baby) → currentBabyId = baby.id. selectedBabyId 가 null 이었으면 currentBabyController.select(currentBabyId)
   - notFound → §4.2 전역 분기: `welcome` 으로 pushReplacement. fallback 시도하지 않음
   - unauthorized → §4.2
   - other → [A] 영역 error 상태 (다시 시도 가능)
5. currentBabyId 로 [C] + [E] 병렬 호출 (각자 영역별 error 가능):
   - recordRepository.getRecords(currentBabyId, cursor=null, limit=20)
   - recordRepository.getRecentFeedings(currentBabyId, limit=1)
   - recordRepository.getRecentDiapers(currentBabyId, limit=1)
   - recordRepository.getRecentWakes(currentBabyId, limit=1)
6. 각 응답이 도착하는 대로 해당 영역만 렌더
```

> 각 `getRecent*` 의 `limit` 을 **1 로 호출** 하는 이유: 본 화면은 각 슬롯에 가장 최근 1건만 보여주면 된다 (home_data §6.6 의 기본 2 와 다름. 호출자가 결정한다고 §6.6 에 명시).

### 7.2 baby 전환

```
1. chevron 탭 → (스탑워치 진행 중이면 §5.3.6 dialog)
2. bottom sheet 노출 → 사용자 선택
3. currentBabyController.select(newId)
4. 본 화면이 currentBabyController 변경 감지 → §7.1 의 step 4 부터 재실행 (candidateId = newId)
   - notFound 가 발생하면 §4.2 전역 분기: `welcome` 으로 pushReplacement.
```

### 7.3 기록 생성 / 삭제 / 무한 스크롤

home_data §8.3 의 정책을 그대로 따른다. 본 spec 의 §5.3.4 / §5.5 / §5.8 / §5.9 가 구체 시점.

### 7.4 로그아웃

본 화면이 직접 트리거하지 않는다 (Settings 탭 책임). 그러나 본 화면이 active 일 때 다른 곳에서 로그아웃이 일어나면 (`AuthRepository.signOut` 후 `currentBabyController.clear()`), `currentBabyId == null` 이 되며 본 화면은 `loading` 상태에서 §7.1 의 step 2 부터 다시 (가 아니라, `unauthorized` 처리와 동일하게 §4.2 전역 분기로 처리). 라우터 가드가 먼저 받아내는 게 일반적이므로 본 spec 에서 별도 분기 코드를 두지 않는다.

---

## 8. Edge Case

### 8.1 모유수유 스탑워치

- **양쪽 둘 다 0 초 누적**: Complete 비활성.
- **한 쪽만 시작했다가 일시정지 상태로 Complete**: 그 쪽만 분 변환, 다른 쪽 = null. 정상 저장.
- **사용자가 Pause 안 누르고 Complete 누름**: 진행 중이던 쪽은 자동으로 그 시점까지 누적된 초로 stop 후 분 변환.
- **앱 백그라운드 → 포그라운드 (홈 라우트 유지)**: ticker 가 멈춰 있었어도 wall-clock 비교로 누적 초 재계산 — 실제 시간 흐름을 반영해야 함. 정확도: 초 단위.
- **앱 종료 → 재실행**: 메모리 휘발. 스탑워치 사라짐. 데이터 모델로도 저장 안 됨 (home_data §3.3 의 결정).
- **저장 (createRecord) 실패 → 사용자가 다시 시도 안 누르고 화면 떠남**: 스탑워치 카드의 `finished` 상태 유지. 다음 진입 시에도 잠금 상태로 보임. 사용자가 명시적으로 "다시 시도" 또는 "버리기" (= 카드 닫기 X 버튼) 를 누를 때까지.
- **저장 실패 후 "버리기"**: 카드 닫고 데이터 폐기. 도메인 모델 만들지 않음 (home_data §3.3 와 일관).

### 8.2 수면 스탑워치

- 모유수유 8.1 의 정책을 단일 슬롯으로 적용.

### 8.3 입력 dialog

- **저장 중 dialog 외부 탭 / back 제스처**: dialog 잠금 동안 무시 (back / dismiss 불가).
- **시각을 미래로 변경 시도**: 저장 버튼 비활성.
- **시각을 매우 과거로 (예: 3일 전) 변경**: 허용 (사용자가 늦게 입력하는 케이스). 단, 입력 가능한 최소값은 **현재 시각 - 24h** 로 제한 (UI 단위; 도메인은 거부 안 함).

### 8.4 기록 리스트

- **삭제 swipe 직후 도착한 새 페이지에 그 기록이 있음**: 클라이언트 id 비교로 dedupe.
- **무한 스크롤로 받은 페이지가 빈 페이지 (서버가 nextCursor 만 잘못 줌)**: hasMore=false 이면 멈춤. true 인데 items=[] 면 한 번 더 시도하지 말고 그 자리에서 멈춤 (방어).
- **같은 기록을 두 번 prepend**: createRecord 의 응답이 도착하기 전에 다른 클라이언트가 같은 기록을 생성해 새로고침으로 들어오는 케이스. id 비교로 dedupe.
- **`unauthorized` 가 무한 스크롤 도중 발생**: §4.2 전역 분기. 누적된 리스트는 메모리에서 정리.

### 8.5 카테고리 / 영역 간 동기화

- 기록 생성 후 해당 `[C]` 슬롯 재호출이 실패: 슬롯만 error 상태. 리스트 prepend 는 그대로.
- 기록 삭제 후 해당 `[C]` 슬롯 재호출이 실패: 슬롯만 error 상태. 리스트 제거는 그대로.
- 한 카테고리 버튼의 저장 진행 중 (in flight) 다른 카테고리 버튼은 정상 활성.

### 8.6 라우팅 race

- 본 화면 진입 도중 `currentBabyController` 가 외부 (다른 화면 / 라우터 가드) 에서 변경 (`select` / `clear`):
  - `select(newId)` → §7.1 의 step 4 부터 재실행.
  - `clear()` → §4.2 전역 분기 (로그인 화면) — 라우터 가드가 보통 먼저 잡지만 안 잡혔을 경우 본 화면이 직접.

### 8.7 baby 전환 도중 사용자가 또 다른 baby 선택

- 첫 번째 전환의 응답들이 도착하기 전에 두 번째 전환:
  - `currentBabyController.selectedBabyId` 가 두 번째 값으로 바뀜.
  - 첫 번째 전환의 응답이 도착하면 응답의 baby id 와 `currentBabyController.selectedBabyId` 를 비교. 다르면 **응답 폐기**.
  - 두 번째 전환의 호출이 새로 시작.

### 8.8 시계 / 시간대 변경

- 사용자가 앱 사용 중 디바이스 timezone 변경 → 다음 렌더 시점부터 새 timezone 적용. 진행 중 스탑워치의 누적 시간은 wall-clock (`DateTime.now()` 의 UTC 부분) 기준이라 영향 없음.
- 디바이스 시계가 임의로 점프 (사용자가 수동 변경) → 진행 중 스탑워치의 누적 시간이 점프할 수 있다. 본 PR 범위에서 별도 보정 안 함.

---

## 9. 표시 카피 (한국어)

| 위치 | 카피 |
|---|---|
| `[C]` 빈 슬롯 | `기록 없음` |
| `[C]` 에러 슬롯 (다시 시도 아이콘 위 hover 시 없음, 그냥 아이콘만 표시) | (텍스트 없음) |
| `[E]` 빈 상태 큰 글씨 | `아직 기록이 없어요` |
| `[E]` 빈 상태 작은 글씨 | `버튼을 눌러 기록을 추가해보세요` |
| `[E]` 첫 페이지 실패 중앙 버튼 | `다시 시도` |
| `[E]` 다음 페이지 실패 inline | `불러오기에 실패했어요  [다시 시도]` |
| 스탑워치 진행 중 다른 카테고리 (§5.3.5) | `{진행중카테고리} 타이머가 진행 중이에요.\n종료하고 {새카테고리}를 시작할까요?` 버튼: `[취소] [종료하고 시작]` |
| 스탑워치 진행 중 라우트 이동 (§5.3.6) | `타이머가 진행 중이에요.\n종료하지 않고 이동할까요?` 버튼: `[취소] [종료하고 이동] [유지하고 이동]` |
| 삭제 확인 (§5.9) | `이 기록을 삭제할까요?\n삭제하면 되돌릴 수 없어요.` 버튼: `[취소] [삭제]` |
| 저장 실패 스낵바 | `저장에 실패했어요. 다시 시도해주세요.` |
| 삭제 실패 스낵바 | `삭제에 실패했어요. 다시 시도해주세요.` |

i18n 은 본 PR 범위 외 — 한국어로 hardcode. 후속 PR 에서 `AppStrings` 화.

---

# Part 2. 구현 방법

본 프로젝트의 기술 스택 (`provider` + `ChangeNotifier` + `go_router` + `Result<T>`) 에 맞춘 구현 메모. Part 1 의 요구사항을 깨지 않는 한 자유롭게 바뀔 수 있다.

## 10. 레이어 구조 / DI

```
HomeScreen (StatelessWidget)
  └─ MultiProvider (화면 scope)
       ├─ ChangeNotifierProvider<HomeBabyInfoViewModel>
       ├─ ChangeNotifierProvider<RecentSnapshotViewModel>
       ├─ ChangeNotifierProvider<RecordTimelineViewModel>
       ├─ ChangeNotifierProvider<StopwatchViewModel>
       └─ ChangeNotifierProvider<QuickLogButtonsViewModel>
```

- 각 ViewModel 은 `BabyRepository` / `RecordRepository` / `CurrentBabyController` / `AppLocalStorage` 를 생성자 주입.
- 화면 mount 시 각 ViewModel 의 `init()` 또는 생성자에서 첫 호출 시작.
- `CurrentBabyController` 의 변경을 각 ViewModel 이 구독. 변경 시 자기 영역 재호출.

> StatefulWidget 은 사용하지 않는다 (Provider 프로젝트의 규칙).

## 11. ViewModel 분리

### 11.1 `HomeBabyInfoViewModel` ([A])

- 상태:
  - `_status: ActionState<Baby>` (Idle / Loading / Success(Baby) / Failure(AppException))
- 메서드:
  - `load(babyId)` — 호출자 (HomeScreen / CurrentBabyController 리스너) 가 babyId 전달.
  - `retry()` — 마지막 babyId 로 재호출.
- 노출 derived 값:
  - `String? get name`
  - `String? get dateLabel` — D+N / D-N / D-Day / null (§3.2)

### 11.2 `RecentSnapshotViewModel` ([C])

- 상태:
  - `_feedState: ActionState<CareRecord?>` (null = empty)
  - `_diaperState: ActionState<CareRecord?>`
  - `_wakeState: ActionState<CareRecord?>`
- 메서드:
  - `loadAll(babyId)`
  - `retryFeed()` / `retryDiaper()` / `retryWake()` — 각자 슬롯.
  - `notifyAfterRecordChanged(record)` — 생성/삭제 후 어느 슬롯에 영향이 있는지 결정 후 그 슬롯 재호출.

### 11.3 `RecordTimelineViewModel` ([E])

- 상태:
  - `_items: List<CareRecord>`
  - `_pageState: ActionState<void>` (첫 페이지)
  - `_nextPageState: ActionState<void>` (다음 페이지)
  - `_nextCursor: String?`
  - `_hasMore: bool`
- 메서드:
  - `loadFirstPage(babyId)`
  - `loadNextPage(babyId)`
  - `refresh(babyId)` — pull-to-refresh
  - `prepend(record)`
  - `remove(recordId)` — 삭제 동기
  - `removeAndDelete(recordId, babyId)` — 삭제 요청 + 결과 분기
- prefetch trigger 는 위젯 (ScrollController) 에서 결정 → ViewModel.`loadNextPage` 호출.

### 11.4 `StopwatchViewModel` ([D])

- 메모리 상태:
  - `_mode: StopwatchMode` (`inactive` / `breast` / `sleep`)
  - 모유수유: `_leftSeconds`, `_rightSeconds`, `_leftRunning`, `_rightRunning`, `_leftPhase` (idle / running / paused / finished), `_rightPhase`, 시작/끝 시각.
  - 수면: `_sleepSeconds`, `_sleepRunning`, `_sleepPhase`, 시작/끝 시각.
  - `_saveState: ActionState<CareRecord>` — Complete 후 저장 진행.
- Ticker — `Stream.periodic(1s)` 또는 위젯이 보유한 `Ticker` 가 ViewModel 의 `tick()` 호출.
- 메서드:
  - `startBreast()` / `startSleep()`
  - `toggleLeft()` / `toggleRight()` / `toggleSleep()` (start ↔ pause)
  - `completeBreast()` / `completeSleep()` — 저장 흐름 (§5.3.4)
  - `discardAfterFailure()` — §8.1 의 "버리기"
  - `tryNavigate()` / `tryRouteChange()` — §5.3.6 dialog 트리거 결과를 위젯이 받아 처리

### 11.5 `QuickLogButtonsViewModel` ([B])

- 상태:
  - `_buttons: List<QuickLogButton>` (type + enabled + 순서). 9 종 + 사용자 커스텀.
- 메서드:
  - `init()` — `AppLocalStorage.quickLogButtonsJson` 읽어 메모리에 보관. 없으면 default (§6.1).
  - `reorder(from, to)` — 순서 변경 후 영속.
  - `toggle(type)` — enabled 토글 후 영속. 마지막 1 개 끌 수 없음.

### 11.6 시간 / 라벨 formatter

ViewModel 외부의 순수 함수 (또는 정적 헬퍼 클래스). 테스트 용이성을 위해 ViewModel 안에 두지 않는다.

- `formatDateLabel(baby, now)` → `D+N` / `D-N` / `D-Day` / null
- `formatRelativeTime(then, now)` → `방금` / `Nm ago` / `Nh Nm ago` / `Nd ago`
- `formatTimerDuration(seconds)` → `Nh Nm Ns`
- `formatRecordChip(record)` → `(label, color)` (§3.5)
- `formatHeaderDate(date, baby, now)` → `M.D Mon (D+N)`
- `inferSleepType(at)` → `nap` / `night` (§6.4)

## 12. 위젯 트리 / 파일 구조

```
lib/presentation/home/
├─ home_screen.dart                       — Scaffold + bottom nav + body
├─ widgets/
│   ├─ baby_info_header.dart              — [A]
│   ├─ quick_log_button_row.dart          — [B]
│   ├─ recent_snapshot_row.dart           — [C]
│   ├─ stopwatch_card.dart                — [D] (조건부)
│   ├─ stopwatch/
│   │   ├─ breast_timer_view.dart         — 좌/우 row
│   │   └─ sleep_timer_view.dart
│   ├─ record_timeline_list.dart          — [E]
│   ├─ record_timeline_item.dart          — 한 row
│   ├─ record_timeline_date_header.dart   — 날짜 헤더
│   ├─ record_timeline_empty.dart
│   ├─ record_timeline_error.dart
│   └─ skeletons/                         — 영역별 skeleton 위젯
├─ modals/
│   ├─ baby_switch_sheet.dart
│   ├─ quick_log_settings_sheet.dart
│   ├─ delete_confirmation_dialog.dart
│   ├─ stopwatch_conflict_dialog.dart     — §5.3.5
│   ├─ stopwatch_navigation_dialog.dart   — §5.3.6
│   └─ input/
│       ├─ formula_input_dialog.dart
│       ├─ pumping_feed_input_dialog.dart
│       ├─ water_input_dialog.dart
│       ├─ pumping_input_dialog.dart
│       ├─ baby_food_input_dialog.dart
│       ├─ snack_input_dialog.dart
│       └─ diaper_input_dialog.dart
├─ view_models/
│   ├─ home_baby_info_view_model.dart
│   ├─ recent_snapshot_view_model.dart
│   ├─ record_timeline_view_model.dart
│   ├─ stopwatch_view_model.dart
│   └─ quick_log_buttons_view_model.dart
├─ models/
│   ├─ quick_log_button.dart              — type + enabled + 순서
│   ├─ stopwatch_mode.dart                — sealed (inactive / breast / sleep)
│   └─ recent_slot_state.dart
└─ formatters/
    ├─ date_label_formatter.dart
    ├─ relative_time_formatter.dart
    ├─ timer_duration_formatter.dart
    ├─ record_chip_formatter.dart
    └─ sleep_type_inferrer.dart
```

## 13. 라우팅 / DI 등록

### 13.1 라우트

`lib/routing/router.dart` 에 추가:

- `home` 라우트는 이미 존재 — body 를 새 `HomeScreen` 으로 교체.
- `getMyBabies` 가 `notFound` 일 때 `context.go(AppRoutes.welcome)` 호출.

### 13.2 DI

`dependencies.dart` 변경 없음 — `HomeScreen` 의 sub-ViewModel 들은 화면 scope 의 `MultiProvider` 가 만든다. 전역 의존성 (`BabyRepository`, `RecordRepository`, `CurrentBabyController`, `AppLocalStorage`) 은 이미 등록되어 있다.

### 13.3 `AppLocalStorage` 신규 키

§6.2 의 `quick_log_buttons` 키 — `AppLocalStorage` 에 3 메서드 추가 (getter / setter / remove). 기존 `selected_baby_id` 와 같은 패턴 (home_data §10.4).

## 14. 테스트 방식

### 14.1 Formatter 단위 테스트

순수 함수라 단일 spec 케이스 다수.

- `formatDateLabel`: birthDate 만 / dueDate 만 / 둘 다 / 둘 다 null / D-Day 경계.
- `formatRelativeTime`: 경계 (60초 / 60분 / 24시간), 분이 0 인 경우.
- `formatTimerDuration`: 0초, 59초, 60초, 3600초, 3601초.
- `formatRecordChip`: 9 종 RecordType × 주요 분기 (Breast 의 LEFT/RIGHT/BOTH/no-chip, BabyFood 의 name/null, Snack 의 name/null, Pumping 의 둘 다 null).
- `formatHeaderDate`: 같은 날 / 다른 날 헤더 분기.
- `inferSleepType`: 22:00 / 06:00 경계.

### 14.2 ViewModel 단위 테스트

각 ViewModel 별 Repository mockito mock.

- `HomeBabyInfoViewModel`: load 성공 / notFound / unauthorized / 그 외 에러 / retry.
- `RecentSnapshotViewModel`: 세 슬롯 각각 success / empty / error / retry 개별 동작. `notifyAfterRecordChanged` 가 type → 슬롯 매핑을 정확히 한다.
- `RecordTimelineViewModel`: 첫 페이지 / 다음 페이지 / 빈 페이지 / hasMore=false 이후 호출 안 함 / prepend / remove / refresh / 중복 호출 차단.
- `StopwatchViewModel`: 모든 §4.1 의 state 전이, Complete 시 분 변환 (`leftSeconds = 29 → 0min`, `30 → 1min`, `90 → 2min` 등), `null` vs `0` 분기, 한 쪽 진행 중 다른 쪽 비활성, sleep 의 sleepType 자동 결정, baby 전환 dialog 결과별 동작.
- `QuickLogButtonsViewModel`: default / 저장된 JSON 로드 / reorder 후 영속 / toggle / 마지막 1 개 비활성 / 미지 enum 무시 / 누락 enum 추가.

### 14.3 위젯 테스트

`HomeScreen` 의 영역별 부분 테스트.

- 각 영역의 상태별 위젯 렌더 (Loading / Success / Empty / Error).
- 입력 dialog 의 시각 변경 / 미래 거부 / 빈 필드 분기.
- swipe-to-delete 의 dialog 노출.
- 무한 스크롤 prefetch trigger (가짜 스크롤 controller).

### 14.4 통합 테스트

본 PR 에서는 강제하지 않음.

## 15. 파일 추가 / 수정 예상 목록

### 신규
- `lib/presentation/home/` 전체 (§12).
- `lib/docs/specs/home_presentation.md` — 본 문서.

### 수정
- `lib/data/local/app_local_storage.dart` — `quick_log_buttons` 키 3 메서드 추가.
- `lib/routing/router.dart` — `home` 라우트의 body 교체.
- `lib/routing/app_routes.dart` (있는 경우) — 변경 없음 (기존 `home`/`welcome` 사용).

### 테스트
- `test/presentation/home/formatters/*_test.dart` (6 개)
- `test/presentation/home/view_models/home_baby_info_view_model_test.dart`
- `test/presentation/home/view_models/recent_snapshot_view_model_test.dart`
- `test/presentation/home/view_models/record_timeline_view_model_test.dart`
- `test/presentation/home/view_models/stopwatch_view_model_test.dart`
- `test/presentation/home/view_models/quick_log_buttons_view_model_test.dart`
- `test/data/local/app_local_storage_test.dart` — `quick_log_buttons` 케이스 추가.

### `pubspec.yaml`
- 추가 의존성 없음.

---

## 16. 본 PR 에서 채택한 결정 요약 — 한눈 표

| 항목 | 결정 |
|---|---|
| D+N / D-Day 규칙 | birthDate 우선, 없으면 dueDate. 둘 다 null = 라벨 미표시 |
| 일상기록 버튼 default | 9 종 전부 노출, §6.1 순서 |
| 일상기록 버튼 커스터마이즈 영속 | `AppLocalStorage` 디바이스 로컬 |
| 스탑워치 동시성 | 단일 슬롯 (breast OR sleep). 메모리 상태만 |
| 모유수유 좌/우 동작 | 동시 진행 불가. 한 쪽 finished 후 다른 쪽 가능 |
| 스탑워치 단위 변환 | UI 초, 저장 round 분 |
| Complete 후 입력 모달 | 없음 (즉시 저장) |
| sleepType 결정 | 시각 22:00–05:59 = night, 그 외 = nap |
| 입력 dialog 형식 | AlertDialog. 시각 변경 가능, 미래 거부, 메모 없음 |
| 메타 chip 규칙 | §3.5 |
| 메모 리스트 row 표시 | 본 PR 에서 항상 생략 (list API 가 메모 미포함) |
| 무한 스크롤 trigger | 마지막에서 5 row 이내 |
| Pull-to-refresh | 4 영역 모두 새로고침 |
| 캐시 | 별도 캐시 없음, ViewModel 메모리 |
| baby 전환 시 스탑워치 | dialog: 취소 / 종료하고 이동 / 유지하고 이동 |
| `getMyBabies` notFound / `getBaby` notFound | `welcome` 라우트로 push replacement. fallback 없음 |
| baby 전환 BottomSheet 진입 | 이름 우측 chevron |
| 버튼 수정 진입 | row 끝 ⚙ 아이콘, bottom sheet |
| 삭제 확인 형식 | AlertDialog |
