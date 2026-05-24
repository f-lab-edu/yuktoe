import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 정수 입력 모달 (수유량 ml, 분 등 공통).
/// 라벨/접미사만 다르게 사용. 확인 시 입력 값, 취소/dismiss 시 null.
Future<int?> showNumberInputModal(
  BuildContext context, {
  required String title,
  required int initial,
  String suffix = '',
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _NumberInputDialog(
      title: title,
      initial: initial,
      suffix: suffix,
    ),
  );
}

class _NumberInputDialog extends StatefulWidget {
  final String title;
  final int initial;
  final String suffix;

  const _NumberInputDialog({
    required this.title,
    required this.initial,
    required this.suffix,
  });

  @override
  State<_NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<_NumberInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial.toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofocus: true,
        decoration: InputDecoration(suffixText: widget.suffix),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            final v = int.tryParse(_controller.text.trim());
            if (v != null) Navigator.pop(context, v);
          },
          child: const Text('확인'),
        ),
      ],
    );
  }
}
