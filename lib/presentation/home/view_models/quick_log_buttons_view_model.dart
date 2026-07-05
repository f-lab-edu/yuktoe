import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/presentation/home/models/quick_log_button.dart';
import 'package:yuktoe/presentation/home/models/quick_log_kind.dart';

/// 빠른 기록 버튼 줄 `[B]` (spec §11.5, plan §1.5).
///
/// 네트워크/Repository 없이 [AppLocalStorage] 의 단일 키(`quick_log_buttons`)만
/// 소비한다. 리스트의 순서가 곧 화면 노출 순서이며, 변경은 즉시 로컬 영속된다.
class QuickLogButtonsViewModel extends ChangeNotifier {
  /// 커스터마이즈 전 기본 노출 순서 (spec §6.1).
  static const List<QuickLogKind> defaultOrder = [
    QuickLogKind.formula,
    QuickLogKind.breast,
    QuickLogKind.diaper,
    QuickLogKind.sleep,
    QuickLogKind.pumping,
    QuickLogKind.pumpingFeed,
    QuickLogKind.babyFood,
    QuickLogKind.snack,
    QuickLogKind.water,
  ];

  final AppLocalStorage _storage;

  List<QuickLogButton> _buttons = const [];

  QuickLogButtonsViewModel(this._storage);

  List<QuickLogButton> get buttons => List.unmodifiable(_buttons);
  List<QuickLogButton> get enabledButtons =>
      List.unmodifiable(_buttons.where((b) => b.enabled));

  /// 로컬에서 동기 로드. 없거나 깨졌으면 기본값.
  void init() {
    final raw = _storage.quickLogButtonsJson;
    _buttons = _parse(raw);
    notifyListeners();
  }

  List<QuickLogButton> _parse(String? raw) {
    if (raw == null) return _defaults();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return _defaults();

      final parsed = <QuickLogButton>[];
      final seen = <QuickLogKind>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final button = QuickLogButton.fromJson(Map<String, dynamic>.from(item));
        if (button == null || seen.contains(button.type)) continue;
        parsed.add(button);
        seen.add(button.type);
      }

      // 누락된 enum 은 default-on 으로 끝에 추가 (forward-compat, spec §6.2).
      for (final type in defaultOrder) {
        if (!seen.contains(type)) {
          parsed.add(QuickLogButton(type: type, enabled: true));
        }
      }
      return parsed;
    } catch (_) {
      return _defaults();
    }
  }

  List<QuickLogButton> _defaults() =>
      defaultOrder.map((t) => QuickLogButton(type: t, enabled: true)).toList();

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _buttons.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target > _buttons.length - 1) target = _buttons.length - 1;

    final next = [..._buttons];
    final moved = next.removeAt(oldIndex);
    next.insert(target, moved);
    _buttons = next;
    notifyListeners();
    await _persist();
  }

  /// enabled 토글 후 영속. 마지막 1개는 끄지 못한다 (spec §5.7).
  Future<void> toggle(QuickLogKind type) async {
    final index = _buttons.indexWhere((b) => b.type == type);
    if (index < 0) return;

    final button = _buttons[index];
    final enabledCount = _buttons.where((b) => b.enabled).length;
    if (button.enabled && enabledCount <= 1) return; // 마지막 1개 보호.

    final next = [..._buttons];
    next[index] = button.copyWith(enabled: !button.enabled);
    _buttons = next;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final json = jsonEncode(_buttons.map((b) => b.toJson()).toList());
    await _storage.setQuickLogButtonsJson(json);
  }
}
