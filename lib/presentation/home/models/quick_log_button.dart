import 'package:yuktoe/constants/enum/record_type.dart';

/// 빠른 기록 버튼 하나. 리스트에서의 **순서가 곧 화면 노출 순서**다 (spec §6.1).
///
/// leaf value object 로서 자신의 직렬화를 직접 소유한다. 미지의 enum 값은
/// `fromJson` 이 `null` 을 돌려주어 상위(ViewModel)에서 무시한다(forward-compat).
class QuickLogButton {
  final RecordType type;
  final bool enabled;

  const QuickLogButton({required this.type, required this.enabled});

  QuickLogButton copyWith({bool? enabled}) =>
      QuickLogButton(type: type, enabled: enabled ?? this.enabled);

  Map<String, dynamic> toJson() => {'type': type.name, 'enabled': enabled};

  /// 미지의 `type` 이면 `null` (forward-compat). enabled 누락 시 기본 `true`.
  static QuickLogButton? fromJson(Map<String, dynamic> json) {
    final typeName = json['type'];
    if (typeName is! String) return null;
    RecordType? type;
    for (final t in RecordType.values) {
      if (t.name == typeName) {
        type = t;
        break;
      }
    }
    if (type == null) return null;
    final enabled = json['enabled'];
    return QuickLogButton(
      type: type,
      enabled: enabled is bool ? enabled : true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuickLogButton &&
      other.type == type &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(type, enabled);
}
