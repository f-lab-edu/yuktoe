# Implementation Plan: 분석 탭 AI 채팅 — Data Layer

## Summary

- 분석 탭 채팅이 쓰는 **클라이언트 데이터 레이어**를 정의한다: 도메인 모델, `ChatRepository`(조회·전송·생성 계약), `ChatService`(Supabase Edge Function 호출 + 테이블 조회 + 스트림 매핑), 로컬 "현재 활성 세션 포인터".
- ViewModel 에는 도메인 모델 + `Result<T>`(+ 스트리밍용 도메인 이벤트 스트림)만 노출한다. Edge Function/테이블/JSON 은 경계 밖으로 나가지 않는다([constitution Principle I](../constitution.md)).
- 서버 계약은 [`analytics_chat_backend.md`](./analytics_chat_backend.md), 채팅 요구사항 SSOT 는 [`analytics_chat.md`](../specs/analytics_chat.md) 다.

## Technical Context

- **Language/Version**: Dart (Flutter), strict typing.
- **Primary Dependencies**: 기존 공통 모듈(`Result<T>`, `AppException`/`ErrorCode`, 인증 컨텍스트, Provider DI), `supabase_flutter`(Edge Function invoke + 테이블 select), `CurrentBabyController`, `AppLocalStorage`(SharedPreferences) — 모두 기존 자산 재사용.
- **Data Source**: Supabase — Edge Function `analytics_chat`(전송/추천), `chat_conversations`/`chat_messages` 테이블(내역/메시지 조회), RLS.
- **Storage(클라이언트)**: SharedPreferences — **아기별 "현재 활성 세션 id" 포인터만**(spec FR-025). 대화·메시지 본문은 서버 SSOT(로컬 저장 없음 → sqflite/hive 신규 의존성 도입하지 않음).
- **Testing**: `flutter_test` + `mockito` — Repository impl 단위 테스트(조회/전송 성공·각 실패 분기, 스트림 delta/done/error), 도메인 모델 불변식 단위 테스트. 기존 `test/data/repositories/*` 관행과 동일.
- **Target Platform**: 모바일 앱(기존과 동일).
- **Project Type**: Mobile app — `lib/data` + `lib/domain/models` 레이어.
- **Performance Goals**: 전송 후 첫 delta 표시까지 서버 SC-001(3초) 내. 내역/메시지 조회는 단일 아기·페이지네이션으로 경량.
- **Constraints**: 도메인 모델 경계 밖으로 DTO/`Map`/raw 응답 노출 금지. 스트리밍 실패도 throw 금지 — 스트림의 종료 이벤트(`error`)로 표현. 로컬 타임존(`localDate`)을 전송/추천 호출에 전달.
- **Scale/Scope**: Repository 1, Service 1, 도메인 모델 4종(`ChatMessage`/`ChatConversation`/`ChatStreamEvent`/`SuggestedQuestions`), 조회 메서드 2 + 전송(스트림) 1 + 추천 1 + 포인터 read/write.

## Constitution Check

*GATE: 설계 전후로 점검한다. 원칙은 [`../constitution.md`](../constitution.md).*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | 레이어 경계 | ✅ PASS | ViewModel 은 `ChatRepository` 만 의존. Service/Supabase 클라이언트/Edge Function/JSON 비노출. 경계 밖은 도메인 모델·`Result<T>`·도메인 스트림 이벤트만. |
| II | 도메인 모델 정책 (immutable, UTC) | ✅ PASS | 모든 필드 `final`, 변경은 `copyWith`, 모델 내 `DateTime` 은 UTC. 메시지·대화 모델은 계산 없는 값 객체. |
| III | 오류 처리 (`Result<T>` + `AppException`) | ✅ PASS | 동기 결과는 `Result<T>`. 스트리밍은 throw 대신 `ChatStreamEvent.error(AppException)` 종료 이벤트. 모든 외부 실패는 `AppException(code)` 로 변환. `notFound` ⊇ 권한 차단. |
| IV | 비즈니스 규칙 SSOT | ✅ PASS | 컨텍스트 조립·집계·프롬프트는 서버(backend plan). 클라이언트는 모델·계약만 검증하며 규칙을 재구현하지 않음. |
| V | 단순성 & 책임 분리 | ✅ PASS | 무거운 처리(컨텍스트·LLM)는 서버. 클라이언트는 조회·전송·표시 데이터 운반만. 신규 로컬 DB 의존성 추가 안 함(포인터만 SharedPreferences). |
| VI | 테스트 가능성 | ✅ PASS | 모델 불변식·조회/전송 분기·스트림 이벤트 시퀀스를 단위 테스트로 검증(D-AC). 빈/부족 상태를 정상으로 고정. |

**Gate Result**: PASS. 정당화가 필요한 선택은 [Complexity Tracking](#complexity-tracking) 참조.

## Project Structure

### Documentation

```text
lib/docs/
├── constitution.md
├── specs/
│   └── analytics_chat.md
└── plans/
    ├── analytics_chat_backend.md
    ├── analytics_chat_data.md         # 이 문서
    └── analytics_chat_presentation.md
```

### Source Code (repository root)

> 기존 `record_repository` / `analytics_repository` 디렉터리 관행을 따른다.

```text
lib/
├── domain/
│   └── models/
│       └── chat/
│           ├── chat_message.dart           # ChatMessage 값 객체 (+ ChatRole enum)
│           ├── chat_conversation.dart       # ChatConversation (세션 메타)
│           ├── chat_stream_event.dart       # ChatStreamEvent sealed (meta/delta/done/error)
│           └── suggested_questions.dart      # SuggestedQuestions (질문 풀)
└── data/
    ├── local/
    │   └── app_local_storage.dart           # (기존) activeConversationId 포인터 추가
    ├── repositories/
    │   └── chat_repository/
    │       ├── chat_repository.dart          # 조회/전송/추천 계약 (ViewModel 의존 대상)
    │       └── chat_repository_impl.dart      # 구현
    └── services/
        └── chat_service/
            ├── chat_service.dart             # 인터페이스
            └── supabase_chat_service.dart     # Edge Function invoke + 테이블 select + 매핑

test/
├── domain/models/chat/
│   ├── chat_message_test.dart
│   └── chat_stream_event_test.dart
└── data/repositories/chat_repository/
    ├── chat_repository_impl_test.dart
    └── chat_repository_impl_test.mocks.dart
```

**Structure Decision**: 도메인 값 객체는 `lib/domain/models/chat/` 아래. Repository/Service 는 기존 `<name>_repository`/`<name>_service` 인터페이스+impl 패턴, 백엔드 구현체는 `supabase_*` 접두사(기존 `supabase_record_service` 와 동일). JSON↔도메인 매핑은 Service 구현체 내부에서 수행하고, 매핑 실패는 `AppException(parseFailed)` 로 변환한다. 로컬 포인터는 신규 저장소 없이 기존 `AppLocalStorage`(SharedPreferences) 를 확장한다.

## 도메인 모델

모두 [constitution Principle II](../constitution.md) 의 값 객체 정책(모든 필드 `final`, 변경은 `copyWith`, `DateTime` 은 UTC, 자체 계산 없음)을 따른다. [leaf 값 객체는 자체 직렬화를 보유](사용자 규칙)하므로, sealed 변종(`ChatStreamEvent`)·메시지 모델은 필요한 `fromJson`/`toJson` 을 직접 가진다. 집합/매핑은 Service 가 담당한다.

```
ChatConversation                         ChatMessage
 ├─ id: String                            ├─ id: String
 ├─ babyId: String                        ├─ conversationId: String
 ├─ title: String?                        ├─ role: ChatRole (user | assistant)
 ├─ createdAt: DateTime (UTC)             ├─ content: String
 └─ lastMessageAt: DateTime? (UTC)        └─ createdAt: DateTime (UTC)

ChatStreamEvent (sealed)                 SuggestedQuestions
 ├─ Meta(conversationId)                  └─ questions: List<String>  // 정확히 5개
 ├─ Delta(text)
 ├─ Done()
 └─ Err(AppException)
```

### `ChatMessage` — 한 발화

| 필드 | 타입 | 의미 |
|---|---|---|
| `id` | `String` | 메시지 식별자 |
| `conversationId` | `String` | 소속 세션 |
| `role` | `ChatRole` | `user` \| `assistant` |
| `content` | `String` | 본문 |
| `createdAt` | `DateTime` | 생성 시각(UTC) |

- 환영 메시지는 **이 모델로 표시만** 하고 저장하지 않는다(Presentation 이 임시 id 로 생성, spec FR-002). 영속 메시지와 임시 메시지의 구분은 Presentation 책임.

### `ChatConversation` — 세션 메타

| 필드 | 타입 | 의미 |
|---|---|---|
| `id` | `String` | 세션 식별자 |
| `babyId` | `String` | 귀속 아기(spec FR-024) |
| `title` | `String?` | 첫 사용자 메시지 파생. `null` 이면 Presentation 이 시각으로 대체(spec FR-022) |
| `createdAt` | `DateTime` | 시작 시각(UTC) |
| `lastMessageAt` | `DateTime?` | 마지막 활동 시각(정렬/표시용, UTC) |

- 내역 리스트(`ChatConversation` 목록)는 사용자 메시지 1건 이상인 세션만 포함(서버 보장, spec FR-021). 클라이언트는 받은 목록을 그대로 신뢰.

### `ChatStreamEvent` — 전송 스트림 이벤트 (sealed)

전송(`sendMessage`)의 반환은 동기 `Result` 가 아니라 **이벤트 스트림**이다. 실패도 throw 하지 않고 종료 이벤트로 표현한다([constitution Principle III](../constitution.md) 의 정신을 스트림에 적용).

| 변종 | 페이로드 | 의미 |
|---|---|---|
| `Meta` | `conversationId: String` | 신규 세션이면 서버가 부여한 식별자 회신(spec FR-020). 첫 이벤트. |
| `Delta` | `text: String` | 토큰 조각(점진 표시, spec FR-004). 0회 이상 반복. |
| `Done` | — | 정상 완료. assistant 메시지가 서버에 확정 저장됨(spec FR-041). |
| `Err` | `error: AppException` | 중도 실패. 부분 누적 본문은 폐기 대상(spec Edge Case). 스트림은 여기서 종료. |

- 불변식: 스트림은 `Meta` 로 시작하고, `Done` **또는** `Err` 중 하나로만 종료한다(둘 다/없음 불가).

### `SuggestedQuestions` — 추천 질문 풀

| 필드 | 타입 | 의미 |
|---|---|---|
| `questions` | `List<String>` | 세션 시작 시 생성된 후보. 정확히 5개(spec FR-010). 표시 전용, 미저장. |

- 버튼 순환은 Presentation 의 인덱스 상태로 처리(spec FR-011) — 모델은 풀만 보유.

## ChatRepository

**역할**: 채팅이 쓰는 데이터를 도메인 모델 + `Result<T>`/스트림으로 제공한다. ViewModel 이 유일하게 의존하는 진입점이며([constitution Principle I](../constitution.md)), Service 를 협력자로 호출한다. **자체 상태(캐시·lock)를 갖지 않는다** — 진행 중 단일성·세션 포인터 상태는 ViewModel/로컬 저장소 책임.

### 메서드

| 메서드 | 입력 | 출력 | 동작/실패 |
|---|---|---|---|
| `getConversations` | `babyId`, (cursor/limit) | `Result<List<ChatConversation>>` | 그 아기의 내역(최신순). 빈 목록은 정상(spec FR-043). 실패: `unauthorized`/`notFound`/`networkError`/`parseFailed`(FR-042) |
| `getMessages` | `conversationId`, (cursor/limit) | `Result<List<ChatMessage>>` | 한 세션의 메시지(시간순). 빈 목록 정상. 실패 동일 |
| `sendMessage` | `babyId`, `conversationId?`, `text`, `localDate` | `Stream<ChatStreamEvent>` | Edge Function `send` 호출 → `Meta`→`Delta`*→`Done`/`Err`. throw 하지 않음 |
| `getSuggestions` | `babyId`, `localDate` | `Result<SuggestedQuestions>` | Edge Function `suggest` 호출 → 5개. 실패 시 호출자(ViewModel)가 추천만 비노출(FR-013). 채팅 차단 안 함 |

### 주요 결정

- **`userId` 를 인자로 받지 않는다** — "현재 사용자" 는 인증 컨텍스트가 자동 판단(기존 Repository 결정과 동일).
- **`babyId`/`conversationId` 를 인자로 받는다** — 현재 선택 아기·활성 세션 판정은 호출자(ViewModel + `CurrentBabyController` + 포인터) 책임.
- **`localDate`(로컬 날짜/타임존)를 전송/추천에 전달** — 서버가 요약 윈도우·월령을 로컬 자정 기준으로 산정해야 함([`analytics_chat_backend.md`](./analytics_chat_backend.md) 와 동일 이유).
- **활성 세션 포인터의 read/write 는 `AppLocalStorage` 가** 담당(아기별 `activeConversationId`). Repository 는 서버 데이터만, 포인터 영속은 로컬 저장소 — 책임 분리.

## ChatService

**역할**: Repository 의 하부 협력자. **Edge Function 호출 + 테이블 select + 인증 컨텍스트 주입 + JSON→도메인 매핑**. Repository 만이 Service 에 의존하며, ViewModel 은 Service 를 모른다([constitution Principle I](../constitution.md)). 인터페이스(`chat_service.dart`)와 Supabase 구현(`supabase_chat_service.dart`) 분리(기존 패턴 동일).

### 책임

- `getConversations`/`getMessages`: `supabase.from('chat_conversations'/'chat_messages').select(...)` (RLS 보호) → 도메인 모델 리스트 매핑.
- `sendMessage`: Edge Function `analytics_chat`(action=send) SSE 호출 → SSE 라인을 `ChatStreamEvent` 로 매핑(meta/delta/done/error). 네트워크·인증·파싱 실패를 `Err(AppException)` 종료 이벤트로 변환.
- `getSuggestions`: Edge Function(action=suggest) 호출 → `SuggestedQuestions` 매핑(5개 아니면 `parseFailed`).
- 모든 외부 실패는 `AppException(ErrorCode)` 로 변환. DB 응답/`Map`/SSE raw 라인은 경계 밖으로 나가지 않는다.

### 오류 매핑

- 네트워크/호출 실패 → `networkError`, 인증 만료/미로그인(401) → `unauthorized`, 접근 불가/미존재(403·404·행 없음) → `notFound`, 응답·매핑·SSE 파싱 실패·모르는 이벤트/역할 enum → `parseFailed`.
- 스트림 중도 실패: 누적 delta 는 매핑하지 않고 `Err` 로 종료(부분 응답 미확정, spec Edge Case).

## 로컬 저장소 (활성 세션 포인터)

- `AppLocalStorage` 에 아기별 `activeConversationId` get/set/remove 추가(SharedPreferences). 키 예: `chat_active_conversation_<babyId>`.
- **콜드 스타트 = 새 세션(spec FR-020)**: 앱 프로세스 시작 시 포인터를 비운다(또는 ViewModel 진입 시 "콜드 스타트 1회" 플래그로 새 세션 시작). 즉 포인터는 프로세스 수명 내에서만 유효 → 콜드 스타트 후 첫 진입은 항상 빈 새 세션.
- 내역에서 대화 선택 시 포인터를 그 `conversationId` 로 갱신(spec FR-023).
- 신규 세션의 첫 전송에서 서버가 `Meta(conversationId)` 를 회신하면 포인터에 기록.

## Acceptance Criteria (data 레이어 단위 검증)

- **D-AC-1**: `ChatMessage`/`ChatConversation` 의 `DateTime` 은 모두 UTC, 모든 필드 `final`, 변경은 `copyWith`. ([constitution Principle II](../constitution.md))
- **D-AC-2**: `sendMessage` 스트림은 `Meta` 로 시작하고 `Done` 또는 `Err` 중 정확히 하나로 종료한다(둘 다/없음 불가). (spec FR-004)
- **D-AC-3**: 신규 세션 전송에서 `Meta.conversationId` 가 방출되고, 이후 호출자가 포인터를 갱신할 수 있다. (spec FR-020)
- **D-AC-4**: 스트림 중도 네트워크/서버 실패는 throw 하지 않고 `Err(AppException(networkError|parseFailed))` 로 종료한다. (spec FR-042·Edge Case)
- **D-AC-5**: `getSuggestions` 가 5개가 아닌 응답을 받으면 `Result.error(parseFailed)`, 호출자는 추천만 비노출한다(채팅 차단 없음). (spec FR-010·FR-013)
- **D-AC-6**: `getConversations`/`getMessages` 의 빈 목록은 성공으로 반환한다(에러 아님). (spec FR-043)
- **D-AC-7**: 접근 불가/미존재 → `notFound`, 미로그인/만료 → `unauthorized`, 네트워크 실패 → `networkError`, 매핑/SSE 파싱 실패 → `parseFailed`. (spec FR-042)
- **D-AC-8**: `getConversations` 결과는 호출한 `babyId` 의 대화만 포함한다(아기 분리, 서버 RLS+필터). (spec FR-024)
- **D-AC-9**: 활성 세션 포인터는 아기별로 보관되며, 콜드 스타트 후 첫 진입에서 비어 있어 새 세션이 시작된다. (spec FR-020·FR-025)
- **D-AC-10**: 전송/추천 호출에 `localDate` 가 전달된다(요약 윈도우·월령 산정 입력). (spec FR-030)
- **D-AC-11**: 환영 메시지·추천 질문은 어떤 Repository 메서드에서도 저장 경로를 거치지 않는다(표시 전용). (spec FR-002)

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 전송 결과를 `Result<T>` 가 아닌 `Stream<ChatStreamEvent>` 로 노출 | 토큰 스트리밍(spec FR-004)을 점진 표시하려면 단일 값 반환으로 불가 | 완료 후 한번에 반환은 스트리밍 체감(SC-001)을 포기 → 거부. 실패는 `Err` 종료 이벤트로 throw-free 유지 |
| 활성 세션 포인터를 로컬(SharedPreferences)에 보관 | 콜드 스타트=새 세션(spec FR-020)·아기별 활성 세션 추적에 경량 포인터 필요 | 본문까지 로컬 저장(sqflite/hive)은 신규 의존성·서버 SSOT 중복으로 거부(spec FR-025) |
| 내역/메시지 조회를 Edge Function 이 아닌 테이블 직접 select | LLM 불필요한 단순 조회를 Function 으로 감싸면 불필요한 레이턴시·비용 | 모든 경로를 Function 경유는 단순 조회까지 과한 추상화로 거부([constitution Principle V](../constitution.md)) |
