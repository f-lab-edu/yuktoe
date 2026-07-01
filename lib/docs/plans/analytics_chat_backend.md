# Implementation Plan: 분석 탭 AI 채팅 — Backend / Server Layer (Supabase)

## Summary

- 분석 탭 채팅의 **서버 측 책임**을 정의한다: 대화·메시지 영속(Postgres + RLS), LLM(Claude) 호출 프록시(Edge Function), 아기 컨텍스트 조립, 추천 질문 생성.
- LLM API 키는 **서버에만** 두고, 클라이언트는 Supabase 인증 토큰으로 Edge Function 을 호출한다(spec FR-035).
- Edge Function 이 요약 4지표 + 최근 N일 원본 기록 + 월령을 조립해 프롬프트를 구성하고, Claude 의 스트리밍 응답을 SSE 로 클라이언트에 중계한다(spec FR-004·FR-030).
- 계산 규칙의 SSOT 는 [`analytics_summary.md`](../specs/analytics_summary.md) FR-010~FR-019, 채팅 계약의 SSOT 는 [`analytics_chat.md`](../specs/analytics_chat.md) 다. 본 plan 은 그 규칙을 **재사용**하며 재정의하지 않는다.

## Technical Context

- **Language/Version**: Deno (Supabase Edge Functions, TypeScript) + Postgres(SQL/RLS). 클라이언트는 별도 plan.
- **Primary Dependencies**: Supabase (Postgres, Auth, Edge Functions), Anthropic Claude API (`@anthropic-ai/sdk` 또는 fetch 기반), 분석 요약 산출 로직([`analytics_data.md`](./analytics_data.md) 의 백엔드 요약 메커니즘 재사용).
- **Data Source**: Supabase Postgres — 신규 `chat_conversations` / `chat_messages` 테이블, 기존 `babies` / 기록 테이블(읽기) 재사용.
- **External Service**: Anthropic Claude API. 기본 모델 `claude-sonnet-5`(운영자 설정으로 교체 가능, spec FR-035). 1M 컨텍스트·128K 출력·adaptive thinking 지원, 스트리밍 호환.
- **Storage**: 대화·메시지는 Postgres 가 SSOT. 클라이언트 영속은 "현재 활성 세션 id" 포인터뿐(별도 plan).
- **Testing**: Edge Function 단위 테스트(Deno test) — 컨텍스트 조립/프롬프트 구성/오류 변환. SQL RLS 정책 테스트(권한 격리). LLM 호출은 더블로 대체.
- **Target Platform**: Supabase 클라우드(Edge Functions + Postgres).
- **Project Type**: Backend — `supabase/functions`, `supabase/migrations`.
- **Performance Goals**: 질문 전송 후 첫 토큰 스트리밍 시작 3초 이내(spec SC-001). 컨텍스트 조립은 단일 아기·소규모 조회로 경량.
- **Constraints**: API 키 등 비밀은 Edge Function 환경변수에만 존재(클라이언트 비노출). 모든 테이블은 RLS 로 사용자별 격리. 응답은 SSE 스트리밍.
- **Scale/Scope**: 테이블 2, Edge Function 1(액션 분기) 또는 2~3(전송/추천/내역), RLS 정책 세트, 마이그레이션 1.

## Constitution Check

*GATE: 설계 전후로 점검한다. 원칙은 [`../constitution.md`](../constitution.md).*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | 레이어 경계 | ✅ PASS | 서버는 데이터 소스 계층. 클라이언트는 Edge Function/테이블에 Service 를 통해서만 접근(별도 plan). 서버는 도메인 모델을 모르며 JSON 계약만 노출하고, JSON↔도메인 매핑은 클라이언트 Service 책임. |
| II | 도메인 모델 정책 (immutable, UTC) | ✅ PASS | 저장 `timestamptz` 는 UTC. 클라이언트가 받는 시각도 UTC(표시 변환은 Presentation). 서버는 값 객체 개념 없이 행을 보관. |
| III | 오류 처리 (`Result<T>` + `AppException`) | ✅ PASS | 서버는 HTTP 상태/에러 코드 JSON 으로 실패를 구분 표현(401/403/404/5xx, 스트림 에러 이벤트). 클라이언트 Service 가 이를 `AppException(ErrorCode)` 로 변환(별도 plan FR-042). |
| IV | 비즈니스 규칙 SSOT | ✅ PASS | 요약 계산 규칙은 `analytics_summary.md`, 채팅 계약은 `analytics_chat.md` 가 SSOT. 본 plan 은 재사용·구현만 한다. |
| V | 단순성 & 책임 분리 | ✅ PASS | 컨텍스트 조립·집계·LLM 호출 같은 무거운 처리를 백엔드에 둔다(클라이언트는 raw 기록을 직접 조합해 프롬프트를 만들지 않는다). |
| VI | 테스트 가능성 | ✅ PASS | 컨텍스트 조립·프롬프트 구성·오류 변환·RLS 격리를 단위/정책 테스트로 검증(BE-AC 참조). LLM 호출은 더블로 분리. |

**Gate Result**: PASS. 정당화가 필요한 선택은 [Complexity Tracking](#complexity-tracking) 참조.

## Project Structure

### Documentation

```text
lib/docs/
├── constitution.md
├── specs/
│   ├── analytics_summary.md          # 요약 규칙 SSOT (재사용)
│   └── analytics_chat.md             # 채팅 spec SSOT
└── plans/
    ├── analytics_chat_backend.md     # 이 문서 (서버 레이어)
    ├── analytics_chat_data.md        # 클라이언트 data 레이어
    └── analytics_chat_presentation.md
```

### Source Code (repository root)

```text
supabase/
├── migrations/
│   └── <ts>_chat.sql                 # chat_conversations / chat_messages + RLS + 인덱스
└── functions/
    └── analytics_chat/
        ├── index.ts                  # 진입점: 액션 라우팅(send / suggest)
        ├── context.ts                # 아기 컨텍스트 조립(요약 4지표 + 최근 N일 기록 + 월령)
        ├── prompt.ts                 # system/user 프롬프트 구성 + 안전 가드레일 문구
        ├── claude.ts                 # Claude API 호출(스트리밍) 래퍼
        ├── persist.ts                # 대화/메시지 upsert(인증 컨텍스트 기반)
        └── errors.ts                 # 실패→에러 코드 JSON/스트림 이벤트 변환

supabase/functions/analytics_chat/tests/   # Deno test
    ├── context_test.ts
    ├── prompt_test.ts
    └── errors_test.ts
```

**Structure Decision**: 채팅 관련 서버 코드는 단일 Edge Function `analytics_chat` 아래 모듈로 분리하고, `index.ts` 가 `action` 파라미터로 **메시지 전송(send)** 과 **추천 질문 생성(suggest)** 을 라우팅한다. 내역·메시지 조회는 LLM 이 필요 없으므로 Edge Function 이 아닌 **Postgres 직접 조회(RLS 보호)** 로 처리한다(클라이언트 Service 가 `supabase.from(...)` 사용). 즉 Edge Function 은 **LLM 이 개입하는 쓰기/생성 경로**만 담당한다.

## 데이터베이스 스키마 (Postgres + RLS)

> 시각은 모두 `timestamptz`(UTC 저장). 클라이언트의 로컬 자정/타임존 변환은 표시 계층 책임([constitution Principle II](../constitution.md)).

### `chat_conversations` — 대화 세션

| 컬럼 | 타입 | 의미 |
|---|---|---|
| `id` | `uuid` PK | 세션 식별자 |
| `user_id` | `uuid` | 소유 사용자(`auth.uid()`), RLS 기준 |
| `baby_id` | `uuid` FK→`babies` | 귀속 아기(spec FR-024) |
| `title` | `text?` | 식별 표시용. 첫 사용자 메시지에서 파생(없으면 클라이언트가 시각으로 대체, spec FR-022) |
| `created_at` | `timestamptz` | 세션 시작 시각 |
| `last_message_at` | `timestamptz?` | 마지막 활동 시각(정렬·표시용) |

- **빈 세션 비노출(spec FR-021)**: 사용자 메시지가 없으면 행을 만들지 않거나 내역 조회에서 제외한다. 구현은 **첫 사용자 메시지 전송 시점에 conversation 행을 생성**(lazy insert)하는 방식으로 빈 세션이 애초에 저장되지 않게 한다([Complexity Tracking](#complexity-tracking)).

### `chat_messages` — 메시지

| 컬럼 | 타입 | 의미 |
|---|---|---|
| `id` | `uuid` PK | 메시지 식별자 |
| `conversation_id` | `uuid` FK→`chat_conversations` | 소속 세션 |
| `user_id` | `uuid` | 소유 사용자, RLS 기준(denormalized) |
| `role` | `text` (`user`\|`assistant`) | 발화 주체 |
| `content` | `text` | 본문 |
| `created_at` | `timestamptz` | 생성 시각(UTC) |

- 환영 메시지·추천 질문은 **저장하지 않는다**(spec FR-002·Key Entities) — 표시 전용.
- 인덱스: `chat_messages(conversation_id, created_at)`, `chat_conversations(user_id, baby_id, last_message_at desc)`.

### RLS 정책

- 두 테이블 모두 RLS 활성. `user_id = auth.uid()` 인 행만 select/insert/update 허용.
- `chat_messages` insert 시 `conversation_id` 의 소유자가 본인인지 검사(서브쿼리 또는 trigger). 접근 불가 행은 클라이언트에 **404 의미**(행 없음 ⊇ 권한 차단)로 귀결([constitution Principle III](../constitution.md), 클라이언트는 `notFound` 로 처리).

> **`user_id` 를 왜 두 테이블에 두는가(설계 결정)**: 대화는 **생성자 본인에게만 사적**이며, 초대코드로 연결된 공동양육자와도 공유하지 않는다(제품 결정). 따라서 소유권의 SSOT 를 `user_id` 로 두고 RLS 를 `user_id = auth.uid()` 단일 조건으로 **조인 없이** 적용한다. `baby_id`(chat_conversations)·`conversation_id`(chat_messages)만으로 소유자를 유도할 수도 있으나, ① 조인/서브쿼리 없는 단순·고속 정책, ② "아기 접근권 기반 공유(공동양육자 열람)" 가 아니라 "생성자 사적" 임을 스키마에서 명확히 드러내기 위해 `user_id` 를 명시 보유한다. 향후 공동양육자 공유로 정책이 바뀌면 RLS 를 아기 접근권 기반 조인으로 교체하고 `user_id` 는 생성자 표기용으로 격하한다([Complexity Tracking](#complexity-tracking)).

## Edge Function `analytics_chat`

**역할**: LLM 이 개입하는 두 경로를 인증 컨텍스트 위에서 처리한다. 비밀(API 키)을 보관하고, 아기 컨텍스트를 조립해 Claude 를 호출하며, 결과를 스트리밍/JSON 으로 반환하고 필요한 메시지를 영속한다.

**인증**: 클라이언트의 Supabase JWT 를 검증해 `user_id` 를 확정한다. 컨텍스트 조립·영속은 이 사용자 권한(RLS)으로 수행한다(미인증 → 401).

### 액션 1 — 메시지 전송 (`action: "send"`)

| 항목 | 내용 |
|---|---|
| 입력 | `babyId`(필수), `conversationId`(없으면 신규 세션 lazy 생성), `message`(사용자 입력), `localDate`(로컬 날짜/타임존 — 요약 윈도우·월령 산정용, [`analytics_data.md`](./analytics_data.md) 와 동일 이유) |
| 동작 | (1) 컨텍스트 조립(`context.ts`) → (2) 프롬프트 구성(`prompt.ts`, 최근 N턴 윈도우 포함, spec FR-032) → (3) 사용자 메시지 영속(`persist.ts`, conversation lazy insert 포함) → (4) Claude 스트리밍 호출(`claude.ts`) → (5) SSE 로 토큰 중계 → (6) 스트림 완료 시 assistant 메시지 확정 영속(spec FR-041) |
| 출력 | `text/event-stream`(SSE). 이벤트: `meta`(conversationId 등 신규 세션 식별자 회신) → `delta`(토큰 조각 반복) → `done`(완료) / `error`(중도 실패) |
| 실패 | 미인증 401, 접근 불가 아기/대화 403·404, 컨텍스트/프롬프트 조립 실패 5xx, LLM 호출/스트림 실패는 SSE `error` 이벤트로 종료(부분 스트림은 클라이언트가 폐기, spec Edge Case) |

### 액션 2 — 추천 질문 생성 (`action: "suggest"`)

| 항목 | 내용 |
|---|---|
| 입력 | `babyId`(필수), `localDate` |
| 동작 | 컨텍스트 조립 → "이 아기 보호자가 궁금해할 질문 5개" 생성 프롬프트로 Claude **비스트리밍** 호출 → 질문 배열 파싱 |
| 출력 | JSON `{ questions: string[] }` (정확히 5개, spec FR-010). 저장하지 않음(세션 한정 표시용). |
| 실패 | 미인증 401, 그 외 실패는 5xx. **추천 실패는 채팅을 막지 않는다**(클라이언트가 추천만 비노출, spec FR-013). |

### 스트리밍 응답 방식 — SSE(Server-Sent Events) 란?

> **한 줄 요약**: LLM 답변을 다 만들 때까지 기다렸다가 한 번에 주는 게 아니라, **생성되는 대로 토큰 조각을 조금씩 흘려보내** 화면에 타이핑되듯 표시하는 방식이다.

- **일반 HTTP 응답**: 클라이언트가 요청 → 서버가 답변을 **전부 완성** → 한 덩어리로 반환. 답변이 길면 사용자는 그동안 빈 화면을 본다.
- **SSE 스트리밍**: 하나의 HTTP 연결을 **열어둔 채**, 서버가 준비되는 조각을 순서대로 여러 번 밀어 보낸다(단방향: 서버→클라이언트). `Content-Type: text/event-stream` 으로 응답하며, 각 조각은 `data: ...\n\n` 형태의 이벤트로 전송된다. Claude API 자체가 이 방식의 스트리밍을 지원하므로, Edge Function 은 **Claude 로부터 받은 토큰 조각을 그대로 클라이언트로 다시 밀어주는(중계) 역할**만 한다.
- **"토큰 중계"의 의미**: Edge Function 은 답변을 자체 생성하지 않는다. `Claude(스트리밍) → Edge Function → 앱` 경로에서 Function 은 파이프처럼 조각을 전달하고, 완료 시점에만 전체 본문을 모아 DB 에 1건 저장한다.
- **본 설계의 이벤트 순서**: `meta`(신규 세션 id 회신) → `delta`(토큰 조각, 0회 이상 반복) → `done`(정상 종료) / `error`(중도 실패). 클라이언트(별도 plan)는 `delta` 를 받을 때마다 화면 버블에 이어 붙인다.
- **왜 쓰나**: 첫 토큰까지 3초 이내(spec SC-001)라는 체감 목표를 만족시키고, 긴 답변에서도 "살아있는" 느낌을 준다. WebSocket 과 달리 단방향·HTTP 기반이라 구현이 가볍다(요청은 일반 POST, 응답만 스트림).

### 컨텍스트 조립 (`context.ts`)

- **요약 4지표**: [`analytics_data.md`](./analytics_data.md) 의 백엔드 요약 메커니즘(RPC/view) 결과를 재사용한다(중복 계산 금지, [constitution Principle IV](../constitution.md)).
- **최근 N일 원본 기록**: `babyId` 의 최근 N일(`localDate` 기준 로컬 자정 경계) `CareRecord` 를 조회해 LLM 가독 형태로 요약 직렬화한다. 기본 N=7(운영자 조정 가능, spec FR-030).
- **월령**: `birthDate`/`dueDate` 로 비교 기준 월령(미숙아는 교정연령, [`analytics_summary.md`](../specs/analytics_summary.md) FR-017)을 산출한다. `birthDate` 없으면 월령 항목을 생략하고, 프롬프트에 **"답변 말미에 출생일 입력 시 월령 맞춤 답변이 가능함을 안내" 하라는 지시**를 포함한다(spec FR-034·FR-036).
- 컨텍스트의 어떤 부분이 비어도 오류가 아니다 — 가능한 범위로 조립한다.

### 프롬프트 구성 (`prompt.ts`)

- **system**: 역할(육아 기록 기반 상담), 톤, **안전 가드레일**(의료 진단 단정 금지·전문의 상담 권유·근거 없는 단정 회피) + 답변은 한국어. `birthDate` 부재 시 답변 말미 출생일 입력 안내(spec FR-036)를 지시.
- **user/context**: 아기 이름·월령·요약 4지표·최근 N일 기록 요약 + 이번 질문 + 최근 N턴 대화 이력(spec FR-032).
- 안전 가드레일 문구는 본 plan 의 프롬프트 정책으로 관리한다(spec Assumptions).

### Claude 호출 (`claude.ts`)

- 모델 ID 는 환경변수(`CHAT_MODEL`, 기본 `claude-sonnet-5`)로 주입(spec FR-035). API 키는 환경변수(`ANTHROPIC_API_KEY`). adaptive thinking(`thinking: {type: "adaptive"}`)·`effort`(기본 `high`)로 상담 품질/비용 조절 가능.
- 전송 액션은 스트리밍, 추천 액션은 비스트리밍.
- LLM 호출/네트워크 실패는 `errors.ts` 가 일관된 형태로 변환(전송: SSE `error` 이벤트, 추천: 5xx JSON).

## 동작 시퀀스 (참고용)

```
[메시지 전송]
client(JWT) → Edge Function analytics_chat (action=send)
  1. verify JWT → user_id
  2. context.ts: 요약4 + 최근N일 기록 + 월령
  3. persist.ts: conversation lazy insert(신규면) + user message insert
  4. claude.ts: stream
  5. SSE: meta(conversationId) → delta* → done
  6. persist.ts: assistant message insert (스트림 누적 본문)
  (LLM/네트워크 실패 시: SSE error → 클라이언트가 부분 스트림 폐기 + 재시도 버튼)

[추천 질문]
client(JWT) → Edge Function (action=suggest)
  1. verify JWT → user_id
  2. context.ts
  3. claude.ts(non-stream) → 5개 파싱
  4. JSON { questions }

[내역/메시지 조회]  ← Edge Function 아님
client → supabase.from('chat_conversations'/'chat_messages').select() (RLS 보호)
```

## Acceptance Criteria (서버 레이어 검증)

> 클라이언트 단위 검증은 [`analytics_chat_data.md`](./analytics_chat_data.md), 화면 검증은 presentation plan. 아래는 서버 측 계약·격리의 개발자 검증 기준이다.

- **BE-AC-1**: 미인증(JWT 없음/만료) 호출은 401 을 반환한다. (spec FR-042)
- **BE-AC-2**: 타 사용자의 `babyId`/`conversationId` 접근은 행 없음(404 의미)으로 귀결한다(RLS). (spec FR-042)
- **BE-AC-3**: `conversationId` 없이 첫 전송 시 conversation 이 lazy insert 되고, SSE `meta` 로 새 conversationId 가 회신된다. (spec FR-020·FR-021)
- **BE-AC-4**: 사용자 메시지 없이 세션 행이 만들어지지 않는다(빈 세션 미저장). (spec FR-021)
- **BE-AC-5**: 전송 응답은 SSE 로 `meta`→`delta`*→`done` 순서이며, 완료 후 assistant 메시지가 1건 저장된다. (spec FR-004·FR-041)
- **BE-AC-6**: LLM/스트림 중도 실패 시 SSE `error` 로 종료하고 assistant 메시지를 저장하지 않는다(부분 응답 미확정). (spec Edge Case)
- **BE-AC-7**: 컨텍스트는 요약4 + 최근 N일 기록 + 월령으로 구성되며, 일부가 비어도(기록/출생정보 없음) 오류 없이 조립된다. (spec FR-030·FR-034)
- **BE-AC-8**: 전송 시 대화 이력은 최근 N턴 윈도우로 제한되어 프롬프트에 포함된다. (spec FR-032)
- **BE-AC-9**: 추천 액션은 정확히 5개의 질문 배열을 반환하고 아무것도 저장하지 않는다. (spec FR-010)
- **BE-AC-10**: 모델 ID·API 키는 환경변수에서만 읽으며 응답/로그에 키가 노출되지 않는다. (spec FR-035·SC-006)
- **BE-AC-11**: 요약 지표 계산은 `analytics_data.md` 메커니즘을 재사용하며 본 Function 이 규칙을 재구현하지 않는다. (spec FR-031, [constitution Principle IV](../constitution.md))

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Edge Function 도입(클라이언트 직접 LLM 호출 대신) | API 키 보호 + 컨텍스트 조립을 서버에서(spec FR-035, [constitution Principle V](../constitution.md)) | 클라이언트 직접 호출은 키 노출·집계 로직의 클라이언트 누수로 거부 |
| conversation lazy insert(전송 시점 생성) | 빈 세션 미저장 불변식(spec FR-021)을 저장 단계에서 보장 | 진입마다 빈 행 생성 후 정리(GC)는 가비지·경합·복잡도 증가로 거부 |
| `localDate`(로컬 날짜/타임존)를 클라이언트가 전달 | 서버가 디바이스 타임존을 모름(요약 윈도우·월령 경계가 로컬 자정 기준) | 서버 UTC 기준 집계는 로컬 자정 정의와 어긋남([`analytics_data.md`](./analytics_data.md) 와 동일 결정) |
| `user_id` 를 `chat_messages` 에 denormalize | RLS 정책을 조인 없이 행 단위로 단순·고속 적용 | 매 검사 시 conversation 조인은 정책 복잡·성능 부담 |
