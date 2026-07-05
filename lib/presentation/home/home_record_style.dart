import 'package:flutter/material.dart';
import 'package:yuktoe/constants/enum/record_type.dart';

/// 홈 화면의 카테고리별 시각 토큰 (Figma "홈-메인" 기준).
///
/// - [dot]: 타임라인 항목 좌측 점 / 빠른 기록 아이콘 색.
/// - [chipBackground] / [chipForeground]: 메타 chip 알약 배경/글자색.
class HomeRecordStyle {
  final Color dot;
  final Color chipBackground;
  final Color chipForeground;

  const HomeRecordStyle({
    required this.dot,
    required this.chipBackground,
    required this.chipForeground,
  });
}

/// Figma 에서 확정된 4종(formula/breast/diaper/sleep)과, 동일 팔레트 계열로
/// 맞춘 나머지 5종.
const Map<RecordType, HomeRecordStyle> _styles = {
  RecordType.formula: HomeRecordStyle(
    dot: Color(0xFF2B7FFF),
    chipBackground: Color(0xFFDBEAFE),
    chipForeground: Color(0xFF155DFC),
  ),
  RecordType.breast: HomeRecordStyle(
    dot: Color(0xFFFB64B6),
    chipBackground: Color(0xFFFCE7F3),
    chipForeground: Color(0xFFE60076),
  ),
  RecordType.diaper: HomeRecordStyle(
    dot: Color(0xFFFDC700),
    chipBackground: Color(0xFFFEF9C2),
    chipForeground: Color(0xFFD08700),
  ),
  RecordType.sleep: HomeRecordStyle(
    dot: Color(0xFF7C86FF),
    chipBackground: Color(0xFFE0E7FF),
    chipForeground: Color(0xFF4F39F6),
  ),
  RecordType.pumping: HomeRecordStyle(
    dot: Color(0xFF06B6D4),
    chipBackground: Color(0xFFCFFAFE),
    chipForeground: Color(0xFF0E7490),
  ),
  RecordType.pumpingFeed: HomeRecordStyle(
    dot: Color(0xFFFB7185),
    chipBackground: Color(0xFFFFE4E6),
    chipForeground: Color(0xFFE11D48),
  ),
  RecordType.babyFood: HomeRecordStyle(
    dot: Color(0xFF22C55E),
    chipBackground: Color(0xFFDCFCE7),
    chipForeground: Color(0xFF15803D),
  ),
  RecordType.snack: HomeRecordStyle(
    dot: Color(0xFFF59E0B),
    chipBackground: Color(0xFFFEF3C7),
    chipForeground: Color(0xFFB45309),
  ),
  RecordType.water: HomeRecordStyle(
    dot: Color(0xFF38BDF8),
    chipBackground: Color(0xFFE0F2FE),
    chipForeground: Color(0xFF0369A1),
  ),
};

extension RecordTypeHomeStyle on RecordType {
  HomeRecordStyle get homeStyle => _styles[this]!;
}

/// 홈 화면 공통 색/치수 토큰 (Figma).
abstract class HomeColors {
  static const textPrimary = Color(0xFF101828);
  static const textSecondary = Color(0xFF6A7282);
  static const textMuted = Color(0xFF99A1AF);
  static const border = Color(0xFFE5E7EB);
  static const accent = Color(0xFF2B7FFF);
  static const scaffold = Color(0xFFF9FAFB);
  static const timerAccent = Color(0xFFE60076); // 수유 타이머 핑크.
  static const complete = Color(0xFF10B981); // 완료 버튼 그린.
}
