# 📋 Home Screen — Data Layer

## 0. 스코프

- **이 PR 범위**: 홈 화면이 필요로 하는 **Data Layer**
- **Presentation Layer 는 별도 PR**. 본 plan 의 §4 동작 방식은 호출자 관점 참고용

---

## 1. 클래스 관계도

```
                ┌──────────────────────────────┐
                │   HomeViewModel  (별도 PR)   │
                └───────────────┬──────────────┘
                                │ depends on
        ┌────────────┬──────────┴────────┬────────────────┐
        ▼            ▼                   ▼                ▼
┌──────────────┐ ┌──────────────────┐ ┌───────────────┐ ┌──────────────┐
│ BabyRepo     │ │ RecordRepo       │ │ SelectedBaby  │ │ SessionMgr   │
│ getMyBabies  │ │ getRecords       │ │ Repo          │ │ currentUser  │
│              │ │ createRecord     │ │ get/setId     │ │ Id           │
│              │ │ deleteRecord     │ │               │ └──────────────┘
│              │ │ getLatest*       │ └───────┬───────┘
└──────┬───────┘ └────────┬─────────┘         │
       ▼                  ▼                   ▼
┌──────────────┐ ┌──────────────────┐ ┌───────────────┐
│ BabyService  │ │ RecordService    │ │ SharedPrefs   │
│ (Supabase)   │ │ (Supabase)       │ │ (직접 사용)   │
└──────┬───────┘ └────────┬─────────┘ └───────────────┘
       └────────┬─────────┘
                ▼
       ┌─────────────────┐
       │ SupabaseClient  │
       └─────────────────┘
```

---

## 2. 도메인 모델

### 2.1 `Baby`

```dart
class Baby {
  final String id;
  final String name;
  final DateTime? birthDate;     // 출생 전이면 null (dueDate 만 있을 수 있음)
  final DateTime? dueDate;       // 출산 예정일
  final String gender;

  const Baby({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.dueDate,
    required this.gender,
  });

  /// 생후 일수. birthDate 가 null 이면 null.
  int? ageInDaysAt(DateTime asOf) {
    final b = birthDate;
    if (b == null) return null;
    return asOf.difference(b).inDays;
  }

  /// 출산 예정일까지 남은 일수. dueDate 가 null 이거나 이미 지났으면 null.
  int? daysUntilDueAt(DateTime asOf) {
    final d = dueDate;
    if (d == null) return null;
    final diff = d.difference(asOf).inDays;
    return diff < 0 ? null : diff;
  }
}
```

위치: `lib/domain/models/baby/baby.dart`

### 2.2 `CareRecord`

이미 정의되어 있다고 가정. 그대로 사용.

---

## 3. Repository / Service 인터페이스

### 3.1 `BabyRepository`

```dart
abstract interface class BabyRepository {
  /// 현재 로그인 사용자가 멤버인 아기 목록.
  Future<Result<List<Baby>>> getMyBabies();
}
```

위치: `lib/data/repositories/baby_repository/baby_repository.dart`

### 3.2 `SelectedBabyRepository` (신규 — v1 에 없었음)

```dart
/// 사용자가 마지막으로 보던 아기 ID 의 로컬 영속화.
/// 다중 아기 사용자가 홈 진입 시마다 선택하지 않도록.
abstract interface class SelectedBabyRepository {
  Future<String?> getSelectedBabyId();
  Future<void> setSelectedBabyId(String babyId);
  Future<void> clear();   // 로그아웃 시
}
```

위치: `lib/data/repositories/selected_baby_repository/selected_baby_repository.dart`

구현: `shared_preferences` 직접 사용.

```dart
class SharedPrefsSelectedBabyRepository implements SelectedBabyRepository {
  static const _key = 'selected_baby_id';
  final SharedPreferences _prefs;
  SharedPrefsSelectedBabyRepository(this._prefs);

  @override
  Future<String?> getSelectedBabyId() async => _prefs.getString(_key);

  @override
  Future<void> setSelectedBabyId(String babyId) async {
    await _prefs.setString(_key, babyId);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
```

### 3.3 `RecordRepository`

```dart
abstract interface class RecordRepository {
  // 리스트 (infinite scroll)
  Future<Result<Page<CareRecord>>> getRecords(
    String babyId, {
    String? cursor,
    int limit = 20,
  });

  // CRUD
  Future<Result<CareRecord>> createRecord({
    required String babyId,
    required RecordDetailData detail,
  });

  Future<Result<void>> deleteRecord(String recordId);

  // 홈 요약 — "마지막 X"
  /// breast / formula / pumpingFeed / babyFood 중 가장 최근.
  Future<Result<CareRecord?>> getLatestFeeding(String babyId);

  Future<Result<CareRecord?>> getLatestDiaper(String babyId);

  /// 가장 최근 sleep 의 endedAt 기준 (= 마지막으로 깬 시각).
  /// `ended_at` generated column 으로 정렬.
  Future<Result<CareRecord?>> getLatestWake(String babyId);
}
```

위치: `lib/data/repositories/record_repository/record_repository.dart`

### 3.4 `BabyService` / `RecordService` (Supabase 어댑터)

```dart
abstract interface class BabyService {
  Future<Result<List<Baby>>> getMyBabies();
}

abstract interface class RecordService {
  Future<Result<Page<CareRecord>>> getRecords(
    String babyId, {
    String? cursor,
    int limit,
  });

  Future<Result<CareRecord>> createRecord({
    required String babyId,
    required RecordType type,
    required Map<String, dynamic> detailJson,
  });

  Future<Result<void>> deleteRecord(String recordId);

  Future<Result<CareRecord?>> getLatestRecord(
    String babyId, {
    required Set<RecordType> types,
    String orderColumn = 'occurred_at',
  });
}
```

- Repository 가 `getLatestFeeding / Diaper / Wake` 를 Service 의 generic `getLatestRecord(types, orderColumn)` 로 매핑
- `getLatestWake` 만 `orderColumn: 'ended_at'`

### 3.5 `createdBy` 채우는 방식: **Service 가 `_client.auth.currentUser!.id` 로 자동**

이유:
- Supabase 의 auth 가 single source of truth. SessionManager 는 그 위의 reactive 표면이고, 쓰기 시점의 `currentUser` 는 supabase client 가 보장
- Repository / ViewModel 이 userId 를 명시 전달할 필요 없음 — caller 가 잘못된 user id 를 줄 가능성 차단
- 이미 memo `createMemo` 가 같은 패턴 → 일관성

### 3.6 Supabase 핵심 쿼리

```dart
// getMyBabies — RLS 가 멤버십을 강제하면 단순 select
final data = await _client.from('babies').select();
return Result.ok(data.map(_mapBaby).toList());
```

```dart
// getRecords — cursor 페이지네이션 (memo 와 동일 +1 트릭)
var q = _client.from('care_records').select().eq('baby_id', babyId);
if (cursor != null) q = q.lt('occurred_at', cursor);
final data = await q.order('occurred_at', ascending: false).limit(limit + 1);
final hasMore = data.length > limit;
final pageData = hasMore ? data.sublist(0, limit) : data;
final items = pageData.map(_mapRecord).toList();
final nextCursor = hasMore ? items.last.detail.occurredAt.toIso8601String() : null;
return Result.ok(Page(items: items, nextCursor: nextCursor, hasMore: hasMore));
```

```dart
// createRecord
final userId = _client.auth.currentUser!.id;
final data = await _client.from('care_records').insert({
  'baby_id': babyId,
  'type': type.name,
  'detail': detailJson,
  'created_by': userId,
}).select().single();
return Result.ok(_mapRecord(data));
```

```dart
// deleteRecord
await _client.from('care_records').delete().eq('id', recordId);
return Result.ok(null);
```

```dart
// getLatestRecord
final data = await _client
    .from('care_records')
    .select()
    .eq('baby_id', babyId)
    .inFilter('type', types.map((t) => t.name).toList())
    .order(orderColumn, ascending: false)
    .limit(1)
    .maybeSingle();
return Result.ok(data == null ? null : _mapRecord(data));
```

---

## 4. 동작 방식 (호출자 관점)

### 4.1 진입 — 홈 화면 초기 로드

```
1. HomeViewModel 생성
2. babyRepository.getMyBabies()                   → 아기 목록
3. selectedBabyRepository.getSelectedBabyId()     → 저장된 id
4. selectedId 가 valid (목록에 존재) 면 그 아기, 아니면 목록 첫 번째 → currentBabyId
   (선택 결과를 setSelectedBabyId() 로 저장)
5. 병렬:
   a. recordRepository.getRecords(currentBabyId, limit: 20)
   b. recordRepository.getLatestFeeding(currentBabyId)
   c. recordRepository.getLatestDiaper(currentBabyId)
   d. recordRepository.getLatestWake(currentBabyId)
6. 화면 렌더
```

### 4.2 아기 전환 (상단 chevron)

```
1. UI 가 chevron 탭 → BottomSheet 로 babies 목록 표시
2. 사용자가 다른 baby 선택 → selectedBabyRepository.setSelectedBabyId(newId)
3. HomeViewModel 이 §4.1 의 step 5 부터 재실행 (record 리스트/요약 재fetch)
```

### 4.3 기록 생성 / 삭제 / infinite scroll

- **생성**: `recordRepository.createRecord(babyId, detail)` → 성공 시 리스트 맨 앞 append + 영향 받는 `latest*` 재호출 (옵션 7-a)
- **삭제**: `recordRepository.deleteRecord(id)` → 성공 시 리스트에서 제거 + 만약 삭제된 게 `latest*` 였다면 재호출
- **infinite scroll**: 하단 도달 → `getRecords(babyId, cursor: lastOccurredAtIso, limit: 20)` → append. `hasMore=false` 이후 무시

---

## 5. 데이터베이스 약속

### 5.1 `care_records` — `ended_at` generated column 추가

```sql
alter table public.care_records
  add column ended_at timestamptz
    generated always as ((detail->>'ended_at')::timestamptz) stored;

-- partial index (sleep 외에는 null 이라 효율적)
create index care_records_baby_ended_at_idx
  on public.care_records (baby_id, ended_at desc)
  where ended_at is not null;
```

### 5.2 `care_records` — 홈 리스트 정렬 인덱스 (이미 있다고 가정 — 없으면 추가)

```sql
create index if not exists care_records_baby_occurred_at_idx
  on public.care_records (baby_id, occurred_at desc);
```

### 5.3 `shared_preferences` 패키지 추가

`pubspec.yaml` 에 `shared_preferences: ^2.x.x` 추가.

### 5.4 `babies` 스키마 (전제)

```sql
-- 가정:
create table public.babies (
  id          uuid        primary key default gen_random_uuid(),
  name        text        not null,
  birth_date  date        null,
  due_date    date        null,
  gender      text        not null
);
```

`getMyBabies` 매핑:
```dart
Baby _mapBaby(Map<String, dynamic> d) => Baby(
  id: d['id'] as String,
  name: d['name'] as String,
  birthDate: d['birth_date'] != null ? DateTime.parse(d['birth_date'] as String) : null,
  dueDate: d['due_date'] != null ? DateTime.parse(d['due_date'] as String) : null,
  gender: d['gender'] as String,
);
```

---

## 6. 검증 / 테스트

### 6.1 도메인 단위 테스트 — `Baby`

| 시나리오 | 검증 |
|---|---|
| `ageInDaysAt` — birthDate 있음 | 정확한 일수 (생일 당일 = 0, +1, -1 케이스) |
| `ageInDaysAt` — birthDate null | null |
| `daysUntilDueAt` — dueDate 미래 | 양수 일수 |
| `daysUntilDueAt` — dueDate 지남 / null | null |

### 6.2 Repository 단위 테스트 (mockito 로 Service mock)

**`BabyRepository`** — getMyBabies passthrough (Ok/Error)

**`SelectedBabyRepository`** — 직접 shared_preferences mock 또는 in-memory fake 로 set/get/clear 검증

**`RecordRepository`**

| 시나리오 | 검증 |
|---|---|
| `getRecords` 첫 페이지 | Service 호출 시 cursor=null, limit 전달 / 결과 passthrough |
| `getRecords` 다음 페이지 | cursor 전달 |
| `createRecord` | Service `createRecord(babyId, type, detailJson)` — type 은 detail 의 runtime type 에서 derive, detailJson 은 detail.toJson() |
| `deleteRecord` | passthrough |
| `getLatestFeeding` | Service `getLatestRecord(types: {breast, formula, pumpingFeed, babyFood})` 호출 |
| `getLatestDiaper` | Service `getLatestRecord(types: {diaper})` 호출 |
| `getLatestWake` | Service `getLatestRecord(types: {sleep}, orderColumn: 'ended_at')` 호출 |
| `getLatest*` 결과 없음 | null 그대로 |

---

## 7. 파일 추가/수정 예상 목록

**신규 도메인**
- `lib/domain/models/baby/baby.dart`

**신규 Repository / Service**
- `lib/data/repositories/baby_repository/baby_repository.dart`
- `lib/data/repositories/baby_repository/baby_repository_impl.dart`
- `lib/data/services/baby_service/baby_service.dart`
- `lib/data/services/baby_service/supabase_baby_service.dart`
- `lib/data/repositories/record_repository/record_repository.dart`
- `lib/data/repositories/record_repository/record_repository_impl.dart`
- `lib/data/services/record_service/record_service.dart`
- `lib/data/services/record_service/supabase_record_service.dart`
- `lib/data/repositories/selected_baby_repository/selected_baby_repository.dart`
- `lib/data/repositories/selected_baby_repository/shared_prefs_selected_baby_repository.dart`

**DI 등록**
- `lib/core/config/dependencies.dart` — SharedPreferences instance, BabyService/Repo, RecordService/Repo, SelectedBabyRepo 추가

**테스트**
- `test/domain/models/baby/baby_test.dart`
- `test/data/repositories/baby_repository/baby_repository_impl_test.dart`
- `test/data/repositories/record_repository/record_repository_impl_test.dart`
- `test/data/repositories/selected_baby_repository/shared_prefs_selected_baby_repository_test.dart`

**DB 마이그레이션 (별도 PR 가능)**
- `care_records.ended_at` generated column + partial index

**`pubspec.yaml`**
- `shared_preferences` 추가
