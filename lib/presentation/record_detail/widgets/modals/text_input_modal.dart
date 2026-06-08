import 'package:flutter/material.dart';

Future<String?> showTextInputModal(
  BuildContext context, {
  required String title,
  required String initial,
  String? hint,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TextInputDialog(
      title: title,
      initial: initial,
      hint: hint,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String? hint;

  const _TextInputDialog({
    required this.title,
    required this.initial,
    this.hint,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

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
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            final v = _controller.text.trim();
            if (v.isNotEmpty) Navigator.pop(context, v);
          },
          child: const Text('확인'),
        ),
      ],
    );
  }
}
