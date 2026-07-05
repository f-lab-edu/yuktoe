import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/analytics/analytics_summary.dart';

/// Repository 의 하부 협력자. 원격 백엔드(Supabase) 호출 + 인증 컨텍스트 주입 +
/// raw 응답을 도메인 모델(`AnalyticsSummary`)로 매핑한다. Repository 만이 Service 에
/// 의존하며 ViewModel 은 Service 의 존재를 알지 못한다.
///
/// 메서드는 throw 하지 않고 `Result<T>` 를 반환하며, 모든 외부 실패(네트워크·인증·
/// 파싱)는 `AppException(ErrorCode)` 로 변환한다.
abstract interface class AnalyticsService {
  /// [babyId] 와 오늘 로컬 날짜([localDate])를 받아 (필요 시 재계산된) 요약을
  /// 조회하고 `AnalyticsSummary` 로 매핑해 반환한다.
  Future<Result<AnalyticsSummary>> getSummary(String babyId, DateTime localDate);
}
