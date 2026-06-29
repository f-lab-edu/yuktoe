import 'dart:async';

import 'package:yuktoe/data/local/app_local_storage.dart';

/// 앱 전체에서 공유되는 "현재 선택된 아기" 의 application-scope state holder.
///
/// 현재값은 동기 [selectedBabyId] getter 로 읽고, 이후 변화는
/// [selectedBabyIdStream] 으로 broadcast 한다. broadcast stream 은 늦게
/// 구독한 listener 에게 마지막 값을 재전송하지 않으므로, 구독자는 구독 시점에
/// [selectedBabyId] 로 현재값을 먼저 읽고 stream 으로 이후 변화를 받는다.
class CurrentBabyController {
  final AppLocalStorage _storage;
  String? _selectedBabyId;
  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();

  CurrentBabyController(AppLocalStorage storage)
    : _storage = storage,
      _selectedBabyId = storage.selectedBabyId;

  String? get selectedBabyId => _selectedBabyId;

  Stream<String?> get selectedBabyIdStream => _controller.stream;

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
