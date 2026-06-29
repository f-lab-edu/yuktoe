import 'package:flutter/material.dart';
import 'package:yuktoe/constants/enum/feeding_type.dart';
import 'package:yuktoe/constants/enum/record_type.dart';
import 'package:yuktoe/domain/models/record/record_detail_data.dart';

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

/// feeding 은 단일 [RecordType] 이지만 화면에서는 세부 종류([FeedingType])마다
/// 다른 제목·이모지로 표시하므로 별도 팔레트를 둔다.
const _feedingPalette = <FeedingType, RecordTypeStyle>{
  FeedingType.breast: RecordTypeStyle(
    emoji: '🤱',
    title: '수유 기록',
    headerGradient: [Color(0xFFF759AB), Color(0xFFFF85C0)],
  ),
  FeedingType.formula: RecordTypeStyle(
    emoji: '🍼',
    title: '분유수유 기록',
    headerGradient: [Color(0xFF2F54EB), Color(0xFF597EF7)],
  ),
  FeedingType.pumpingFeed: RecordTypeStyle(
    emoji: '🍼',
    title: '유축수유 기록',
    headerGradient: [Color(0xFFFF7875), Color(0xFFFFA39E)],
  ),
  FeedingType.babyFood: RecordTypeStyle(
    emoji: '🥄',
    title: '이유식 기록',
    headerGradient: [Color(0xFF52C41A), Color(0xFF73D13D)],
  ),
};

const _palette = <RecordType, RecordTypeStyle>{
  RecordType.feeding: RecordTypeStyle(
    emoji: '🍼',
    title: '수유 기록',
    headerGradient: [Color(0xFFF759AB), Color(0xFFFF85C0)],
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
  RecordType.diaper: RecordTypeStyle(
    emoji: '👶',
    title: '기저귀 기록',
    headerGradient: [Color(0xFFFF7A45), Color(0xFFFFA940)],
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

extension FeedingTypePalette on FeedingType {
  RecordTypeStyle get style => _feedingPalette[this]!;
}

/// detail 의 실제 종류에 맞는 스타일을 해석한다.
/// feeding 은 세부 [FeedingType] 팔레트를, 그 외는 [RecordType] 팔레트를 쓴다.
extension RecordDetailPalette on RecordDetailData {
  RecordTypeStyle get style => switch (this) {
        FeedingDetail d => d.feedingType.style,
        _ => type.style,
      };
}
