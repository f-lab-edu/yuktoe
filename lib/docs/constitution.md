# Project Constitution

**Version**: 1.0.0
**Ratified**: 2026-06-22
**Last Amended**: 2026-06-22
**Status**: Active

> 본 문서는 이 프로젝트의 모든 spec / plan / 구현이 따라야 하는 최상위 원칙이다. 개별 feature 의 plan 은 "Constitution Check" 게이트에서 아래 원칙 준수 여부를 점검하며, 위반이 불가피하면 해당 plan 의 Complexity Tracking 에 사유를 명시해 정당화해야 한다.

---

## Principle I — 레이어 경계 (Layered Boundaries)

데이터 흐름은 `ViewModel → Repository → Service → 데이터 소스` 의 단방향 계층을 따른다.

- ViewModel 은 **Repository 에만** 의존한다. Service 와 데이터 소스 클라이언트는 ViewModel 에 노출되지 않는다.
- Repository / Service 경계 밖으로는 **도메인 모델과 `Result<T>` 만** 나간다. DB 응답 원본, `Map<String, dynamic>`, DTO 는 경계를 넘지 못한다.
- 각 계층은 자신의 책임만 가진다: Repository 는 조회 계약, Service 는 외부 호출 + 도메인 매핑 + 인증 컨텍스트 주입.

**Rationale**: 경계가 명확해야 상위 계층이 데이터 소스 변경에 영향받지 않고, 모델 계약만으로 테스트가 가능하다.

---

## Principle II — 도메인 모델 정책 (Immutable, UTC)

모든 도메인 모델은 다음을 지킨다.

- **Immutable**: 모든 필드는 `final`. 변경은 `copyWith` 로만.
- **시각은 UTC**: 모델이 보유하는 모든 `DateTime` 은 UTC. 로컬 타임존 변환은 표시 계층의 책임이다.
- 계산 결과를 담는 값 객체는 **자체적으로 계산을 수행하지 않는다**. 이미 산출된 수치만 보유한다.

**Rationale**: 불변성은 예측 가능성과 동시성 안전을 보장하고, UTC 통일은 타임존 버그를 한 곳(표시 계층)에 격리한다.

---

## Principle III — 오류 처리 (Result + AppException)

- 모든 Repository / Service 메서드는 throw 하지 않고 **`Result<T>` 를 반환**한다.
- 모든 외부 실패는 `AppException(ErrorCode)` 로 변환한다. 오류 유형은 일관된 코드 집합(`networkError`, `unauthorized`, `parseFailed`, `notFound` 등)으로 구분한다.
- `notFound` 는 "행 없음" 과 "권한 차단(RLS 등)" 을 모두 포함한다. 호출자는 이를 stale 식별자의 fallback 신호로 쓸 수 있다.

**Rationale**: 예외를 값으로 다루면 호출자가 모든 실패 경로를 컴파일 타임에 인지하고 일관되게 처리할 수 있다.

---

## Principle IV — 비즈니스 규칙 SSOT (Single Source of Truth)

"무엇이 올바른 값인가"(집계 규칙, 비교 규칙, 경계 조건)는 **spec 이 단일 진실 공급원**이다.

- 실제 계산을 어디서(서버/클라이언트) 수행하든, 규칙의 정의는 spec 에 있고 그 규칙은 테스트로 검증 가능해야 한다.
- 동일한 규칙이 여러 문서에 중복 정의되어서는 안 된다. 다른 문서는 SSOT 를 참조한다.

**Rationale**: 계산 규칙이 분산되면 서버·클라이언트·테스트가 서로 어긋난다. 한 곳에서 정의하고 모두가 참조해야 일관성이 유지된다.

---

## Principle V — 단순성 & 책임 분리 (Simplicity & Separation of Concerns)

- 가능하면 **집계·조인 같은 무거운 처리는 데이터 소스(백엔드)에 둔다**. 클라이언트가 대량 raw 데이터나 참조 테이블 전체를 받아 직접 처리하지 않는다.
- 표시용 가공(정성 라벨, 퍼센트, 차이 수치 등)은 **표시 계층(Presentation)의 책임**이다. 데이터 계층은 수치와 분류만 제공한다.
- 새 추상화·의존성은 명확한 필요가 있을 때만 추가한다. 정당화되지 않은 복잡성은 거부한다.

**Rationale**: 책임이 한 계층에 모이면 변경 비용이 낮아지고, 각 계층이 독립적으로 테스트·교체 가능해진다.

---

## Principle VI — 테스트 가능성 (Testability)

- 모든 비즈니스 규칙(계산·비교·경계 조건)과 조회 계약(성공/각 실패 분기)은 **테스트로 검증 가능한 형태**로 명세된다.
- 모델 불변식(예: 범위는 항상 `min <= max`, 상호 의존 필드는 함께 존재하거나 함께 없음)은 단위 테스트로 보장한다.
- 데이터 부재·부족 같은 엣지는 오류가 아닌 정상 상태로 다루고, 그 동작을 테스트로 고정한다.

**Rationale**: 검증 가능하지 않은 요구사항은 회귀를 막을 수 없다. 명세 단계에서 테스트 가능성을 강제한다.

---

## Governance

- **개정**: 원칙 변경은 버전을 올리고(시맨틱 버저닝: 원칙 추가/제거는 MAJOR, 원칙 내용 확장은 MINOR, 문구 정정은 PATCH) Last Amended 일자를 갱신한다.
- **게이트**: 모든 plan 은 Phase 0 이전과 Phase 1 설계 이후 두 차례 Constitution Check 를 통과해야 한다.
- **정당화**: 원칙 위반이 불가피하면 plan 의 Complexity Tracking 에 "왜 필요한가 / 더 단순한 대안을 왜 기각했는가" 를 기록해야 한다. 기록 없는 위반은 허용되지 않는다.
- **우선순위**: 본 constitution 은 다른 문서·관행보다 우선한다. 충돌 시 constitution 이 이긴다.
