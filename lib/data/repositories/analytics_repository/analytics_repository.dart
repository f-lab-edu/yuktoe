import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/analytics/analytics_summary.dart';

/// 분석 탭이 보여줄 통계 요약을 현재 선택된 아기에 대해 도메인 모델
/// (`AnalyticsSummary`) + `Result<T>` 형태로 제공한다. ViewModel 이 유일하게
/// 의존하는 데이터 진입점이며(다른 계층은 ViewModel 에 노출되지 않음), Service 를
/// 협력자로 호출한다.
///
/// 자체 상태(캐시·큐·lock)를 갖지 않는다 — 캐시/재계산은 백엔드 책임이므로
/// 무상태이고, 동시에 여러 번 호출해도 안전하다.
abstract interface class AnalyticsRepository {
  /// 한 아기의 분석 탭 통계 요약(지표 값 + 레퍼런스 비교)을 조회한다.
  ///
  /// - [babyId] 현재 선택된 아기. "현재 사용자"는 인증 컨텍스트에서 자동 판단한다.
  /// - [localDate] 요청자의 오늘 로컬 날짜. 일 단위 집계 경계가 로컬 자정이고
  ///   캐시 신선도 판정이 로컬 날짜 기준이므로 호출자가 전달한다(spec FR-011·FR-022).
  ///
  /// 기록이 전혀 없어도 에러가 아니며, 모든 지표가 absent 인 `AnalyticsSummary`
  /// 를 성공으로 반환한다(spec FR-020). 실패는 `notFound`/`unauthorized`/
  /// `networkError`/`parseFailed` 로 `Result.error(AppException)` 반환(spec FR-021).
  Future<Result<AnalyticsSummary>> getSummary(String babyId, DateTime localDate);
}
