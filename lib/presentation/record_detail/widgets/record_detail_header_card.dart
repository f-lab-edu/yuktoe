import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/theme/record_type_palette.dart';

class RecordDetailHeaderCard extends StatelessWidget {
  final RecordType type;
  final DateTime date;

  const RecordDetailHeaderCard({
    super.key,
    required this.type,
    required this.date,
  });

  static final _dateFormat = DateFormat('yyyy년 M월 d일', 'ko_KR');

  @override
  Widget build(BuildContext context) {
    final style = type.style;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(style.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dateFormat.format(date),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                style.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
