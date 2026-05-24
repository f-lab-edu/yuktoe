import 'package:flutter/material.dart';
import 'package:yuktoe/constants/enum/record_type.dart';

/// 기록 타입별 시각 표현 (이모지, 헤더 그라데이션, 타이틀).
/// 디자인 토큰 — 디자이너 확정 시 색상 값만 갱신.
class RecordTypeStyle {
  final String emoji;
  final String title;
  final List<Color> headerGradient;

  const RecordTypeStyle({
    required this.emoji,
    required this.title,
    required this.headerGradient,
  });
}

const _palette = <RecordType, RecordTypeStyle>{
  RecordType.diaper: RecordTypeStyle(
    emoji: '👶',
    title: '기저귀 기록',
    headerGradient: [Color(0xFFFF7A45), Color(0xFFFFA940)],
  ),
  RecordType.breast: RecordTypeStyle(
    emoji: '🤱',
    title: '수유 기록',
    headerGradient: [Color(0xFFF759AB), Color(0xFFFF85C0)],
  ),
  RecordType.formula: RecordTypeStyle(
    emoji: '🍼',
    title: '분유수유 기록',
    headerGradient: [Color(0xFF2F54EB), Color(0xFF597EF7)],
  ),
  RecordType.pumpingFeed: RecordTypeStyle(
    emoji: '🍼',
    title: '유축수유 기록',
    headerGradient: [Color(0xFFFF7875), Color(0xFFFFA39E)],
  ),
  RecordType.pumping: RecordTypeStyle(
    emoji: '🥛',
    title: '유축 기록',
    headerGradient: [Color(0xFF13C2C2), Color(0xFF36CFC9)],
  ),
  RecordType.sleep: RecordTypeStyle(
    emoji: '😴',
    title: '수면 기록',
    headerGradient: [Color(0xFF722ED1), Color(0xFF9254DE)],
  ),
  RecordType.babyFood: RecordTypeStyle(
    emoji: '🥄',
    title: '이유식 기록',
    headerGradient: [Color(0xFF52C41A), Color(0xFF73D13D)],
  ),
  RecordType.snack: RecordTypeStyle(
    emoji: '🍪',
    title: '간식 기록',
    headerGradient: [Color(0xFFFAAD14), Color(0xFFFFC53D)],
  ),
  RecordType.water: RecordTypeStyle(
    emoji: '💧',
    title: '물 기록',
    headerGradient: [Color(0xFF1890FF), Color(0xFF40A9FF)],
  ),
};

extension RecordTypePalette on RecordType {
  RecordTypeStyle get style => _palette[this]!;
}
