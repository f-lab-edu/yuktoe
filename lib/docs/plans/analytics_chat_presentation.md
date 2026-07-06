# Implementation Plan: 분석 탭 AI 채팅 — Presentation Layer

## Summary

- 분석 탭의 요약 카드 4개 아래에 놓이는 **AI 채팅 UI**를 구현한다: 환영 메시지, 메시지 리스트(스트리밍 표시), 입력창(전송·추천 질문 새로고침), 시계 버튼의 지난 대화 바텀시트.
- ViewModel 은 `ChatRepository` 만 의존하고([constitution Principle I](../constitution.md)), 표시용 가공(시각 로컬 변환, 환영 문구 생성, 추천 순환 인덱스, 첫 메시지 기반 제목 대체)은 Presentation 책임이다.
- 채팅 요구사항 SSOT 는 [`analytics_chat.md`](../specs/analytics_chat.md), 데이터 계약은 [`analytics_chat_data.md`](./analytics_chat_data.md).

## 이 화면이 보여주는 것

```text
┌─ 분석 탭 (AnalyticsScreen) ────────────────┐
│  [요약 카드 4개]  ← 별도 feature (analytics_*)│
│  ────────────────────────────────────────  │
│  ┌─ 채팅 영역 (ChatSection) ──────────[🕐]┐ │  🕐 = 지난 대화 내역 바텀시트
│  │  (assistant) 물결이에 대해 궁금한…       │ │     (환영 메시지 = UI 전용, 미저장)
│  │  (user)      새벽 5시에 깨는 이유?       │ │
│  │  (assistant) ▌(스트리밍 중…)            │ │
│  │  …                                      │ │
│  │  ──────────────────────────────────────│ │
│  │  [추천: "낮잠이 적정한가요?"]  [🔄]      │ │  🔄 = 추천 풀 로컬 순환
│  │  [ 입력창……………… ]            [전송]  │ │     (전송: 스트리밍 중 비활성)
│  └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

## Technical Context

- **Language/Version**: Dart (Flutter), strict typing.
- **Primary Dependencies**: `provider`(ChangeNotifier DI), `ChatRepository`(data plan), `CurrentBabyController`(기존), `Baby`(이름·월령 표시), `ActionState`(기존 공통). 메모/입력 UI 패턴은 기존 `record_detail/widgets/memo/*` 참고.
- **State Management**: `ChangeNotifier` 기반 ViewModel + `context.watch`/`context.read`. **StatelessWidget 만 사용**(프로젝트 규칙) — `StatefulWidget`/수동 `addListener` 사용 안 함. `TextEditingController` 등 컨트롤러는 ViewModel 또는 별도 Inherited/Provider 로 보유.
- **Data Source**: ViewModel → `ChatRepository`(유일 의존). Service/Supabase/Edge Function 비노출.
- **Testing**: ViewModel 단위 테스트(Repository mock 주입) — 전송 스트림 누적·전송 잠금·세션 전환·추천 순환·환영 표시·오류 버블. Widget 테스트는 핵심 상호작용(전송 비활성, 추천 탭, 내역 선택) 위주.
- **Target Platform**: 모바일 앱(기존과 동일).
- **Performance Goals**: 전송 후 첫 delta 표시까지 SC-001(3초) 내, 스트리밍 중 부드러운 점진 렌더.
- **Constraints**: 위젯 안에 비즈니스 로직 금지(View/ViewModel 책임 분리). 시각은 로컬 타임존 표시(도메인 UTC). 진행 중 단일성(전송 잠금)은 ViewModel 상태로 강제.
- **Scale/Scope**: 코디네이터 ViewModel 1(+필요 시 입력 컨트롤러 분리), View 1(채팅 섹션), 위젯 약 6종, 바텀시트 1.

## Constitution Check

*GATE: 설계 전후로 점검한다. 원칙은 [`../constitution.md`](../constitution.md).*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | 레이어 경계 | ✅ PASS | ViewModel 은 `ChatRepository` 만 의존. View 는 ViewModel 만 구독. Service/Edge Function/JSON 미접근. |
| II | 도메인 모델 정책 (immutable, UTC) | ✅ PASS | 도메인 모델은 그대로 사용. 로컬 시각 변환·환영 문구·제목 대체 등 표시 가공만 Presentation 에서 산출. |
| III | 오류 처리 | ✅ PASS | Repository 의 `Result`/`Err` 이벤트를 받아 상태로 환원(에러 버블·재시도·로그인 유도). UI 가 예외를 직접 throw/처리하지 않음. |
| IV | 비즈니스 규칙 SSOT | ✅ PASS | 컨텍스트·답변 규칙은 서버. Presentation 은 표시만. 규칙 재구현 없음. |
| V | 단순성 & 책임 분리 | ✅ PASS | 위젯은 표시·입력만, 상태·전이는 ViewModel. 추천 순환·전송 잠금 같은 표시 로직만 Presentation 에 둠. |
| VI | 테스트 가능성 | ✅ PASS | ViewModel 상태 전이를 Repository mock 으로 단위 검증(P-AC). 빈/부족/오류를 정상 상태로 고정. |

**Gate Result**: PASS. 정당화가 필요한 선택은 [Complexity Tracking](#complexity-tracking) 참조.

## Project Structure

```text
lib/presentation/analytics/
├── view_models/
│   ├── chat_view_model.dart           # 코디네이터: 세션·메시지·전송 스트림·전송잠금·오류
│   ├── chat_input_controller.dart      # 입력 텍스트 + 추천 순환 인덱스 + 글자수 상한
│   └── chat_history_view_model.dart    # 지난 대화 내역(바텀시트) 조회·선택
├── views/
│   └── (analytics_screen.dart 내 ChatSection 통합 — 요약 카드 아래)
└── widgets/
    └── chat/
        ├── chat_section.dart           # 채팅 영역 컨테이너(헤더+리스트+입력)
        ├── chat_message_list.dart       # 메시지 리스트(스트리밍 표시 포함)
        ├── chat_message_bubble.dart     # user/assistant 버블 + 시각(로컬)
        ├── chat_welcome_bubble.dart     # 환영 메시지(표시 전용)
        ├── chat_error_bubble.dart       # 실패 + "다시 시도"
        ├── chat_input_bar.dart          # 입력창 + 전송(잠금) + 추천 새로고침
        ├── suggested_question_chip.dart # 추천 질문 노출/탭
        └── chat_history_sheet.dart      # 시계 버튼 → 지난 대화 바텀시트

test/presentation/analytics/view_models/
├── chat_view_model_test.dart
├── chat_input_controller_test.dart
└── chat_history_view_model_test.dart
```

**Structure Decision**: 채팅 위젯은 분석 탭 화면 아래 `widgets/chat/` 로 묶고, 요약 카드(별도 feature)와 같은 `AnalyticsScreen` 안에서 세로로 배치한다. ViewModel 은 화면 진입점에서 `ChangeNotifierProvider(create: ... context.read<ChatRepository>())` 로 주입한다(기존 패턴). 바텀시트는 기존 `record_detail/widgets/modals/*` 의 `showModalBottomSheet` 함수형 패턴을 따른다. 모든 위젯은 `StatelessWidget` 이며 상태는 ViewModel/컨트롤러가 보유한다(프로젝트 규칙).

## ViewModel 설계

세 ViewModel 은 수명·갱신 주기가 다르므로 분리한다(자세한 정당화는 [Complexity Tracking](#complexity-tracking)).

- `ChatViewModel` — 지금 채팅창에 떠 있는 **한 세션**의 메시지·전송·전이를 총괄(코디네이터).
- `ChatInputController` — **입력창** 텍스트와 추천 질문 순환만 담당(전송 중에도 자유롭게 타이핑되므로 분리).
- `ChatHistoryViewModel` — **바텀시트**가 열릴 때만 사는 지난 대화 목록.

---

### `ChatViewModel` — 코디네이터

**역할**: 현재 활성 세션의 메시지 목록을 화면에 제공하고, 전송 스트림(`Stream<ChatStreamEvent>`)을 소비해 점진 표시로 누적하며, 전송 잠금·세션 전환·오류 상태를 관리한다.
**협력자**: `ChatRepository`(유일한 데이터 의존), `CurrentBabyController`(현재 선택 아기 감지), `Baby`(환영 문구의 아기 이름).
**수명**: 분석 탭 화면 진입점에서 생성되어 화면과 함께 산다. `CurrentBabyController` 변경을 감지해(리스너 등록이 아닌 `context` 구독으로 전달받아) 아기 전환 시 재초기화한다.

**보유 상태(getter 로 노출, 필드는 모두 private)**

| getter | 타입 | 의미 | View 에서의 쓰임 |
|---|---|---|---|
| `messages` | `List<ChatMessage>` | 현재 세션의 확정 메시지(시간순). 환영·스트리밍 중 버블은 별도 상태로 분리 | 리스트 본문 렌더 |
| `showWelcome` | `bool` | 환영 버블 노출 여부(사용자 메시지 0건인 새 세션에서 `true`) | 리스트 최상단 환영 버블 |
| `isStreaming` | `bool` | AI 응답 진행 중 = **전송 잠금**(spec FR-005) | 전송 버튼 활성/비활성, 로딩 인디케이터 |
| `streamingText` | `String` | 현재 누적 중인 assistant 본문(`Delta` 마다 증가). 완료 전까지의 임시 표시 | 마지막 assistant 버블에 타이핑 표시 |
| `errorMessageId` | `String?` | 실패한 사용자 메시지 식별자(그 아래 에러 버블+재시도 부착 대상, spec FR-042) | 해당 버블 아래 에러 버블 |
| `state` | `ActionState` | idle/loading/success/error — 초기 메시지 로드 상태(기존 공통 enum 재사용) | 로딩/에러 상태 위젯 |
| `activeConversationId` | `String?` | 현재 활성 세션 id. `null` 이면 아직 서버 미저장 신규 세션(첫 전송의 `Meta` 로 확정) | (내부 상태, 직접 렌더 안 함) |

**메서드(View 가 `context.read` 로 호출)**

| 메서드 | 트리거 | 동작(상태 전이) |
|---|---|---|
| `enterTab()` | 탭 진입 / 아기 전환 시 | 콜드 스타트 후 첫 진입이면 → 빈 새 세션 시작(`messages=[]`, `showWelcome=true`, `activeConversationId=null`). 아니면 로컬 포인터의 세션을 `repo.getMessages` 로 로드(`state=loading→success/error`). 아기 전환이면 새 아기 기준으로 전부 재초기화(spec FR-007). |
| `send(String text)` | 전송 버튼 탭 / 입력창 제출 | ① `isStreaming` 이면 즉시 무시(단일 진행 보장, FR-005). ② optimistic: `text` 로 만든 임시 `user` 메시지를 `messages` 에 추가하고 `showWelcome=false`, `isStreaming=true`, `notify`. ③ `repo.sendMessage(babyId, activeConversationId, text, localDate)` 구독 시작. 이벤트별: `Meta`→`activeConversationId` 갱신 + 로컬 포인터 저장, `Delta`→`streamingText += text` + `notify`, `Done`→누적본을 확정 `assistant` 메시지로 `messages` 에 추가하고 `streamingText=''`·`isStreaming=false`, `Err`→`errorMessageId` 설정(부분 누적 폐기)·`isStreaming=false`. |
| `retry(String messageId)` | 에러 버블의 "다시 시도" 탭 | 해당 사용자 메시지 본문으로 `send` 를 재실행(같은 질문 재전송, spec Edge Case). |
| `openConversation(String id)` | 내역 바텀시트에서 항목 선택 | 진행 중이던 세션이 비어 있으면(사용자 메시지 0) 폐기, 비어있지 않으면 그대로 두면 서버 저장분이 내역에 남는다. 선택한 `id` 를 활성 포인터로 바꾸고 `repo.getMessages(id)` 로 로드해 채팅창에 표시(이어서 입력 가능, spec FR-023). |

- **왜 `streamingText` 를 `messages` 와 분리하나**: 스트리밍 중 매 토큰마다 리스트 전체를 갱신하지 않고 마지막 버블만 다시 그리기 위함. `Done` 시점에만 확정 메시지로 편입한다.
- **오류 처리**: `repo` 결과의 `Err(AppException)` 는 코드별로 분기 — `unauthorized`→로그인 유도, `notFound`→선택 아기 stale 처리, `networkError`/`parseFailed`→에러 버블+재시도. UI 가 예외를 직접 throw 하지 않는다([constitution Principle III](../constitution.md)).

### `ChatInputController` — 입력·추천

**역할**: 입력창의 텍스트 상태와 추천 질문 풀·순환 인덱스만 담당한다. `ChatViewModel` 과 분리한 이유는 **AI 응답 중에도 입력창 타이핑은 허용**되므로(FR-005), 전송 스트림 상태 변화가 입력 상태를 오염시키지 않게 하기 위함이다.
**협력자**: `ChatRepository`(추천 풀 로드).
**수명**: 세션 시작마다 추천 풀을 1회 로드하고 세션 동안 유지.

| getter / 메서드 | 의미 | View 에서의 쓰임 |
|---|---|---|
| `text` (getter) | 현재 입력 본문 | 입력 필드 표시(양방향은 아래 `onChanged` 로) |
| `onChanged(String)` | 입력 변경 반영. **글자수 상한**(spec FR-033, 기본 1000자) 초과분은 잘라내 저장 | `TextField.onChanged` 바인딩 |
| `remaining` (getter) | 남은 입력 가능 글자수 | 입력창 하단 카운터 |
| `canSend` (getter) | 공백 제외 1자 이상 ∧ `!isStreaming` → 전송 가능(FR-003·FR-005) | 전송 버튼 활성 여부 |
| `suggestions` / `currentSuggestion` (getter) | 세션 시작 시 생성된 추천 풀(5개)과 현재 노출 1개 | 추천 칩 텍스트 |
| `loadSuggestions()` | 세션 시작 시 `repo.getSuggestions` 1회 호출. 실패 시 풀을 빈 채로 두어 추천 영역 비노출(FR-013, 채팅 차단 없음) | (진입 시 호출) |
| `cycleSuggestion()` | 순환 인덱스를 다음으로 이동(**네트워크 호출 없음**, FR-011) | 🔄 버튼 |
| `applySuggestion()` | `currentSuggestion` 을 `text` 에 채움(이후 사용자가 전송/수정, FR-012) | 추천 칩 탭 |
| `clear()` | 전송 성공 후 입력 비우기 | `ChatViewModel.send` 성공 시 호출 |

### `ChatHistoryViewModel` — 지난 대화 바텀시트

**역할**: 시계 버튼으로 바텀시트가 열릴 때 그 아기의 대화 목록을 조회·표시하고, 선택을 `ChatViewModel` 로 위임한다.
**협력자**: `ChatRepository`(`getConversations`), `ChatViewModel`(선택 위임).
**수명**: 바텀시트가 열려 있는 동안만.

| getter / 메서드 | 의미 |
|---|---|
| `state` | 조회 로딩/성공/에러(`ActionState`) |
| `conversations` | 그 아기의 대화 목록(최신순). 표시 라벨 = `title`(첫 사용자 메시지)이며 `null` 이면 시각으로 대체, 우측에 `lastMessageAt` 로컬 표시(FR-022) |
| `load(babyId)` | 시트 오픈 시 `repo.getConversations(babyId)` 호출 |
| `select(id)` | 선택된 대화 id 를 반환/위임 → 호출부가 `ChatViewModel.openConversation(id)` 실행 후 시트 닫기 |

## View 설계

> **바인딩 규칙**: 위젯은 전부 `StatelessWidget`(프로젝트 규칙 — `StatefulWidget`·수동 `addListener` 금지). 상태 구독은 `context.watch<T>()`(변경 시 rebuild), 이벤트 위임은 `context.read<T>().메서드()`(rebuild 불필요할 때). 부분 구독으로 불필요한 rebuild 를 줄인다(예: `context.select((ChatViewModel vm) => vm.isStreaming)`).

**Provider 주입(화면 진입점)** — `AnalyticsScreen` 하위에 채팅 3개 ViewModel 을 주입한다:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (ctx) => ChatViewModel(
        repository: ctx.read<ChatRepository>(),
        currentBaby: ctx.read<CurrentBabyController>(),
      )..enterTab(),
    ),
    ChangeNotifierProvider(
      create: (ctx) => ChatInputController(repository: ctx.read<ChatRepository>())..loadSuggestions(),
    ),
  ],
  child: const ChatSection(),
)
```

**위젯별 ViewModel 사용**

- **`ChatSection`** (컨테이너): 카드 셸(흰 배경, radius 16, 구분선 `0xFFF0F0F0` — 기존 `memo_section` 스타일 재사용) 안에 헤더 + `ChatMessageList`(Expanded) + `ChatInputBar` 를 세로 배치. 헤더 우측 시계 버튼은 `onTap: () => showChatHistorySheet(context)` 로 바텀시트를 연다. 자체 상태 없음.
- **`ChatMessageList`**: `final vm = context.watch<ChatViewModel>();` 로 `vm.state`·`vm.showWelcome`·`vm.messages`·`vm.streamingText`·`vm.errorMessageId` 를 읽어 다음 순서로 렌더 — (`state==loading`) 로딩 → 환영 버블(`showWelcome`) → 확정 메시지 버블들(`messages`) → 스트리밍 중이면 마지막에 `streamingText` 버블 → `errorMessageId` 가 붙은 사용자 메시지 아래 에러 버블. 모든 시각은 로컬 타임존으로 변환해 표시(FR-006).
- **`chat_message_bubble.dart`**: 순수 표시 위젯. `ChatMessage`(또는 임시 텍스트)를 받아 role 별 좌/우 정렬·색을 그린다. ViewModel 을 직접 구독하지 않고 부모가 주입(테스트 용이).
- **`chat_welcome_bubble.dart`**: `context.read<ChatViewModel>()`(또는 상위에서 받은 `Baby`)로 아기 이름을 채운 고정 문구를 assistant 버블 형태로 표시. 저장·전송 없음(FR-002).
- **`chat_error_bubble.dart`**: "다시 시도" 버튼 → `context.read<ChatViewModel>().retry(messageId)`.
- **`ChatInputBar`**: `context.watch<ChatInputController>()` 로 `text`/`remaining`/`currentSuggestion` 을, `context.select((ChatViewModel vm) => vm.isStreaming)` 로 잠금 상태를 구독. 구성 — 추천 칩(`applySuggestion` on tap) + 🔄(`cycleSuggestion`) + `TextField`(`onChanged: controller.onChanged`) + 남은 글자수 카운터 + 전송 버튼. 전송 버튼 `onPressed` 는 `controller.canSend` 일 때만 활성이며, 탭 시 `context.read<ChatViewModel>().send(controller.text)` → 성공 시 `controller.clear()`. 스트리밍 중이면 `canSend==false` 로 자동 비활성(FR-005).
- **`suggested_question_chip.dart`**: `currentSuggestion` 을 칩으로 표시, 탭하면 `ChatInputController.applySuggestion()`.
- **`chat_history_sheet.dart`**: `showChatHistorySheet(context)` 함수가 `showModalBottomSheet` 로 열고, 시트 내부에서 `ChangeNotifierProvider(create: ... ..load(babyId))` 로 `ChatHistoryViewModel` 을 주입. `context.watch` 로 목록을 그리고, 항목 탭 → `context.read<ChatViewModel>().openConversation(id)` 실행 후 `Navigator.pop`(기존 `record_detail/widgets/modals/*` 함수형 패턴과 동일).
- **오프라인(Edge Case)**: 네트워크 불가 시 입력바 전송을 비활성화하고 안내를 표시하되, 이미 로드된 과거 대화는 그대로 열람 가능.

## 동작 방식 (시퀀스)

```
[탭 진입]
1. ChatViewModel.enterTab()
   - 콜드 스타트 첫 진입 → 새 빈 세션, showWelcome=true(환영 버블), ChatInputController 추천 로드
   - 아니면 활성 세션 메시지 로드

[질문 전송]
1. 입력 → canSend(유효∧!streaming) → ChatViewModel.send(text)
2. optimistic user 버블 추가, isStreaming=true (전송 버튼 비활성)
3. repo.sendMessage 스트림:
     Meta(convId)  → activeConversationId/포인터 갱신, showWelcome=false
     Delta(t)*     → streamingText += t (스트리밍 표시)
     Done          → assistant 확정 버블로 치환, isStreaming=false
     Err(e)        → 에러 버블(errorMessageId), isStreaming=false (부분 폐기)
4. (Err) "다시 시도" → retry(messageId)

[추천 새로고침]  🔄 → cycleSuggestion() (로컬 순환), 칩 탭 → applySuggestion()

[지난 대화]
1. 🕐 → showChatHistorySheet → ChatHistoryViewModel.load(babyId)
2. 항목 선택 → ChatViewModel.openConversation(id)
   - 선택 세션을 활성으로 로드, 진행중이던 비어있지 않은 세션은 내역에 남음(서버), 빈 세션은 폐기
```

## 검증 / 테스트 (Acceptance Criteria)

- **P-AC-1**: 새 빈 세션 진입 시 환영 버블이 아기 이름으로 채워져 표시되고, 저장 호출은 일어나지 않는다. (spec FR-002)
- **P-AC-2**: 유효 텍스트가 없거나 `isStreaming` 이면 전송 버튼이 비활성이다. (spec FR-003·FR-005)
- **P-AC-3**: 전송 시 사용자 버블이 즉시(optimistic) 추가되고, `Delta` 누적이 점진 표시되며, `Done` 에 assistant 버블이 확정된다. (spec FR-004·FR-008)
- **P-AC-4**: 스트리밍 중 추가 `send` 는 무시된다(단일 진행). (spec FR-005)
- **P-AC-5**: `Err` 수신 시 해당 사용자 메시지에 에러 버블+재시도가 붙고, 재시도는 같은 본문을 재전송한다. (spec FR-042·Edge Case)
- **P-AC-6**: 추천 풀 로드 성공 시 칩 1개 노출, 🔄 는 추가 호출 없이 풀을 순환, 칩 탭은 입력창을 채운다. (spec FR-010~FR-012)
- **P-AC-7**: 추천 로드 실패 시 추천 영역만 비노출되고 채팅은 정상 동작한다. (spec FR-013)
- **P-AC-8**: 시계 버튼은 그 아기의 대화만 최신순으로, "첫 사용자 메시지/시각 + 마지막 활동 시각(로컬)" 으로 표시한다. (spec FR-022·FR-024)
- **P-AC-9**: 내역에서 대화 선택 시 그 세션이 활성으로 뜨고 이어서 입력 가능하며, 직전 진행 세션은 내역에 남고 빈 진행 세션은 폐기된다. (spec FR-023·Edge Case)
- **P-AC-10**: 아기 전환 시 세션·내역·추천이 새 아기 기준으로 갱신된다. (spec FR-007·FR-024)
- **P-AC-11**: 모든 시각 표시는 로컬 타임존 기준이다. (spec FR-006)
- **P-AC-12**: 입력 글자수가 상한을 넘지 못하고 남은 글자수가 안내된다. (spec FR-033)

## 파일 추가/수정 예상 목록

- 추가: `lib/presentation/analytics/view_models/chat_view_model.dart`, `chat_input_controller.dart`, `chat_history_view_model.dart`
- 추가: `lib/presentation/analytics/widgets/chat/*`(8개 위젯/시트)
- 수정: `lib/presentation/analytics/views/analytics_screen.dart`(요약 카드 아래 `ChatSection` 통합)
- 수정: `lib/core/config/dependencies.dart`(`ChatService`/`ChatRepository` 등록), 화면 진입점 `ChangeNotifierProvider`(ChatViewModel 등) 주입
- 추가: 위 테스트 파일

## Out of Scope

- 요약 카드 4개의 계산·표시(별도 feature: `analytics_summary.md`/`analytics_presentation.md`).
- 서버 측 컨텍스트 조립·프롬프트·LLM 호출·DB 스키마([`analytics_chat_backend.md`](./analytics_chat_backend.md)).
- 도메인 모델·Repository·Service·로컬 포인터 계약([`analytics_chat_data.md`](./analytics_chat_data.md)).
- 답변 문장 자체의 의학적 정확성·안전 가드레일 정책(프롬프트 정책 = backend plan).
- 대화 검색·즐겨찾기·삭제·다중 동시 세션 등 확장 기능.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| ViewModel 을 코디네이터/입력/내역 3개로 분리 | 전송 스트림 상태, 입력·추천 순환, 내역 조회는 수명·갱신 주기가 달라 한 클래스에 묶으면 책임 과밀 | 단일 ViewModel 은 전송 중 입력 상태·내역 로드가 서로 notify 오염 → 거부([constitution Principle V](../constitution.md)) |
| 환영 버블을 메시지 모델로 표시하되 저장 안 함 | UI 일관성(같은 버블 컴포넌트) + 미저장 불변식(spec FR-002) 동시 충족 | 별도 표시 타입 신설은 버블 렌더 분기 증가, 저장까지 하면 FR-002 위반 → 임시 표시 플래그로 처리 |
