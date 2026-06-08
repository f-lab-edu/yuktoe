import 'package:flutter/material.dart';
import 'package:yuktoe/constants/enum/sleep_type.dart';

Future<SleepType?> showSleepTypePickerModal(
  BuildContext context, {
  required SleepType initial,
}) {
  return showModalBottomSheet<SleepType>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '수면 타입 선택',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text('낮잠'),
            trailing: initial == SleepType.nap
                ? const Icon(Icons.check, color: Colors.deepPurple)
                : null,
            onTap: () => Navigator.pop(ctx, SleepType.nap),
          ),
          ListTile(
            title: const Text('밤잠'),
            trailing: initial == SleepType.night
                ? const Icon(Icons.check, color: Colors.deepPurple)
                : null,
            onTap: () => Navigator.pop(ctx, SleepType.night),
          ),
        ],
      ),
    ),
  );
}
