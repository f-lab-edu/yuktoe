import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';

/// Complete 후 저장 진행 상태 (spec §4.1 [D], plan §1.4).
enum SaveStatus { idle, saving, failed }

/// 스탑워치 진행 단계.
enum StopwatchPhase { idle, running, paused }

/// 두 스탑워치 ViewModel(모유수유 / 수면)을 화면이 동일하게 다루기 위한
/// 얇은 공통 인터페이스 (plan §1.4).
///
/// "스탑워치는 한 번에 하나만" 이라는 단일 활성 보장은 화면이 이 인터페이스로
/// 활성 VM 하나를 골라 중재한다.
abstract interface class StopwatchController {
  /// 카드가 떠 있는지. false 면 화면에 카드 없음.
  bool get active;

  /// 누적 ≥ 1초 (충돌/이동 dialog 에서 저장 여부 판단).
  bool get hasElapsed;

  /// 저장 상태.
  SaveStatus get saveStatus;

  /// 저장 실패 시의 에러(전역 분기 / 스낵바 판정용).
  AppException? get saveError;

  /// 다른 모드로 전환하기 위한 정리: 누적 ≥ 1초면 저장, 0초면 그냥 정리한다.
  /// 저장 성공 시 생성된 기록을 돌려준다(화면이 리스트/최근 요약에 반영).
  Future<CareRecord?> completeForSwitch();

  /// 저장 실패 후 재시도.
  Future<CareRecord?> retry();

  /// 저장 없이 카드 폐기.
  void discard();

  /// 메모리 상태를 그대로 두고 라우트 이동 (아무 것도 하지 않음).
  void keepForNavigate();
}
