import 'package:yuktoe/common/utils/action_state.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/domain/models/record/care_record.dart';

/// 최근 요약 `[C]` 의 한 슬롯 상태 (spec §4.1 [C]).
///
/// "빈 상태" 는 별도 값이 아니라 `status == success && record == null`.
class RecentSlotState {
  final ActionState status;
  final CareRecord? record;
  final AppException? error;

  const RecentSlotState({
    this.status = ActionState.idle,
    this.record,
    this.error,
  });

  const RecentSlotState.idle() : this();

  const RecentSlotState.loading() : this(status: ActionState.loading);

  const RecentSlotState.success(CareRecord? record)
    : this(status: ActionState.success, record: record);

  const RecentSlotState.failure(AppException error)
    : this(status: ActionState.error, error: error);

  bool get isEmpty => status == ActionState.success && record == null;
}
