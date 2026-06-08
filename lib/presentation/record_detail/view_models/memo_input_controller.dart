import 'package:flutter/widgets.dart';

/// 메모 입력창 전용 컨트롤러.
/// MemoInput 위젯을 StatelessWidget 으로 두기 위해 컨트롤러 자체를 ChangeNotifier 로
/// 분리 (글로벌 규칙: Provider 프로젝트는 StatelessWidget 만 사용).
class MemoInputController extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();

  MemoInputController() {
    textController.addListener(_onTextChanged);
  }

  bool get canSend => textController.text.trim().isNotEmpty;

  void clear() {
    textController.clear();
  }

  void _onTextChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    textController.removeListener(_onTextChanged);
    textController.dispose();
    super.dispose();
  }
}
