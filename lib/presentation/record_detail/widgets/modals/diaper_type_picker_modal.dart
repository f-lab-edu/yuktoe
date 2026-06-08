import 'package:flutter/material.dart';
import 'package:yuktoe/constants/enum/diaper_type.dart';

Future<DiaperType?> showDiaperTypePickerModal(
  BuildContext context, {
  required DiaperType initial,
}) {
  return showModalBottomSheet<DiaperType>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '기저귀 타입 선택',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text('소변'),
            trailing: initial == DiaperType.pee
                ? const Icon(Icons.check, color: Colors.deepPurple)
                : null,
            onTap: () => Navigator.pop(ctx, DiaperType.pee),
          ),
          ListTile(
            title: const Text('대변'),
            trailing: initial == DiaperType.poop
                ? const Icon(Icons.check, color: Colors.deepPurple)
                : null,
            onTap: () => Navigator.pop(ctx, DiaperType.poop),
          ),
          ListTile(
            title: const Text('대소변'),
            trailing: initial == DiaperType.mixed
                ? const Icon(Icons.check, color: Colors.deepPurple)
                : null,
            onTap: () => Navigator.pop(ctx, DiaperType.mixed),
          ),
        ],
      ),
    ),
  );
}
