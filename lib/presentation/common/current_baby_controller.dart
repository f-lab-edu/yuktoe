import 'dart:async';

import 'package:yuktoe/data/local/app_local_storage.dart';

/// 현재 선택된 아기 id 의 단일 출처(single source of truth).
///
/// 동기 getter [selectedBabyId] 로 현재값을 즉시 읽을 수 있고,
/// 변경(select / clear)은 [babyIdStream] 으로 방송된다. 홈의 `[A]`/`[C]`/`[E]`
/// ViewModel 은 이 stream 을 구독해 baby 전환 시 자기 영역을 재호출한다.
class CurrentBabyController {
  final AppLocalStorage _storage;
  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();

  String? _selectedBabyId;

  CurrentBabyController(AppLocalStorage storage)
    : _storage = storage,
      _selectedBabyId = storage.selectedBabyId;

  /// 현재 선택된 아기 id (없으면 null). 동기 읽기.
  String? get selectedBabyId => _selectedBabyId;

  /// select / clear 시 새 값을 방송하는 broadcast stream.
  Stream<String?> get babyIdStream => _controller.stream;

  Future<void> select(String babyId) async {
    await _storage.setSelectedBabyId(babyId);
    _selectedBabyId = babyId;
    _controller.add(babyId);
  }

  Future<void> clear() async {
    await _storage.removeSelectedBabyId();
    _selectedBabyId = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
