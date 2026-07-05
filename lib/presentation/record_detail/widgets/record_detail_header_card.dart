import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';
import 'package:yuktoe/theme/record_type_palette.dart';

class RecordDetailHeaderCard extends StatelessWidget {
  final RecordDetailData detail;
  final DateTime date;

  const RecordDetailHeaderCard({
    super.key,
    required this.detail,
    required this.date,
  });

  static final _dateFormat = DateFormat('yyyy년 M월 d일', 'ko_KR');

  @override
  Widget build(BuildContext context) {
    final style = detail.style;
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
